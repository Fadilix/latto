// latto-agent translates coding agent lifecycle events into Latto IPC calls.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"html"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type object = map[string]any
type adapter struct {
	Agent      string            `json:"agent"`
	Icon       string            `json:"icon"`
	EventField string            `json:"event_field"`
	Events     map[string]string `json:"events"`
	Fields     map[string]string `json:"fields"`
}

func value(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprint(v)
}

func lookup(data object, path string) any {
	var current any = data
	for _, part := range strings.Split(path, ".") {
		fields, ok := current.(map[string]any)
		if !ok {
			return nil
		}
		current = fields[part]
	}
	return current
}

func normalize(data object, a *adapter, event string) object {
	if a == nil {
		return data
	}
	result := object{"agent": a.Agent}
	for key, path := range a.Fields {
		result[key] = lookup(data, path)
	}
	if a.Icon != "" {
		result["icon"] = a.Icon
	}
	if event == "" {
		field := a.EventField
		if field == "" {
			field = "hook_event_name"
		}
		event = value(lookup(data, field))
	}
	result["event"] = a.Events[event]
	return result
}

func fileExists(path string) bool { info, err := os.Stat(path); return err == nil && !info.IsDir() }

func repoDir() string {
	if dir := os.Getenv("LATTO_DIR"); dir != "" {
		return dir
	}
	executable, err := os.Executable()
	if err != nil {
		return "."
	}
	if resolved, err := filepath.EvalSymlinks(executable); err == nil {
		executable = resolved
	}
	return filepath.Dir(filepath.Dir(executable))
}

// Keep hooks pointed at the active host without changing provider configs.
func ipcPath(repo string) string {
	if path := os.Getenv("LATTO_SHELL"); path != "" {
		return path
	}
	bar := filepath.Join(filepath.Dir(repo), "bar.qml")
	if fileExists(bar) {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		output, err := exec.CommandContext(ctx, "qs", "list", "-p", bar).Output()
		if err == nil && strings.Contains(string(output), "Process ID:") {
			return bar
		}
	}
	return repo
}

func fallback(data object, key, defaultValue string) string {
	if s := value(data[key]); s != "" && s != "0" {
		return s
	}
	return defaultValue
}

func commands(data object, repo string, now int64) [][]string {
	agent, session, event := value(data["agent"]), value(data["session"]), value(data["event"])
	if agent == "" || session == "" {
		return nil
	}
	switch event {
	case "prompt", "working", "input", "done", "end":
	default:
		return nil
	}
	cwd, _ := os.Getwd()
	project := fallback(data, "project", filepath.Base(fallback(data, "cwd", cwd)))
	defaults := map[string]string{"prompt": "Thinking", "working": "Working", "input": "Waiting for you"}
	detail := fallback(data, "detail", defaults[event])
	result := [][]string{{"qs", "-p", repo, "ipc", "call", "agents", "report", agent, session, event, project, detail,
		fallback(data, "at", fmt.Sprint(now)), fallback(data, "startedAt", "0"), fallback(data, "tokens", "0")}}
	if event == "done" {
		icon := "utilities-terminal"
		// Only a simple agent name may select a bundled asset.
		name := strings.ToLower(agent)
		if filepath.Base(name) == name {
			bundled := filepath.Join(repo, "integrations", "agents", "icons", name+".svg")
			if fileExists(bundled) {
				icon = bundled
			}
		}
		icon = fallback(data, "icon", icon)
		body := []rune(detail)
		if len(body) > 240 {
			body = body[:240]
		}
		result = append(result, []string{"notify-send", "-a", agent, "-i", icon, "-t", "8000", "--",
			agent + " · Finished · " + project, html.EscapeString(string(body))})
	}
	return result
}

func run(command []string) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_ = exec.CommandContext(ctx, command[0], command[1:]...).Run()
}

func readObject(input io.Reader) (object, error) {
	var data object
	decoder := json.NewDecoder(input)
	decoder.UseNumber()
	err := decoder.Decode(&data)
	if err == nil {
		var extra any
		if decoder.Decode(&extra) != io.EOF {
			return nil, fmt.Errorf("trailing JSON")
		}
	}
	return data, err
}

func report(args []string, repo string) {
	flags := flag.NewFlagSet("report", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	path := flags.String("adapter", "", "JSON adapter file")
	event := flags.String("event", "", "Native event override")
	if flags.Parse(args) != nil || flags.NArg() > 1 {
		return
	}
	var input io.Reader = os.Stdin
	if flags.NArg() == 1 {
		input = strings.NewReader(flags.Arg(0))
	}
	data, err := readObject(input)
	if err != nil || data == nil {
		return
	}
	var a *adapter
	if *path != "" {
		content, err := os.ReadFile(*path)
		if err != nil {
			return
		}
		a = &adapter{}
		if json.Unmarshal(content, a) != nil {
			return
		}
	}
	data = normalize(data, a, *event)
	if *path != "" && value(data["icon"]) != "" {
		icon := value(data["icon"])
		if !filepath.IsAbs(icon) {
			absolute, _ := filepath.Abs(*path)
			icon = filepath.Join(filepath.Dir(absolute), icon)
		}
		if fileExists(icon) {
			data["icon"] = icon
		}
	}
	for index, command := range commands(data, repo, time.Now().UnixMilli()) {
		if index == 0 {
			command[2] = ipcPath(repo)
		}
		run(command)
	}
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'" }

func hookCommand(binary, adapterPath, event string) string {
	return shellQuote(binary) + " --adapter " + shellQuote(adapterPath) + " --event " + shellQuote(event)
}

func configuration(provider, repo string) (string, error) {
	root := filepath.Join(repo, "integrations", "agents")
	binary := filepath.Join(repo, "bin", "latto-agent")
	path := filepath.Join(root, provider+".json")
	var config any
	switch provider {
	case "codex":
		args, _ := json.Marshal([]string{binary, "--adapter", path})
		return "# Add at the top level of ~/.codex/config.toml, before any [table].\nnotify = " + string(args) + "\n", nil
	case "codex-hooks":
		content, err := os.ReadFile(path)
		if err != nil {
			return "", err
		}
		var a adapter
		if err := json.Unmarshal(content, &a); err != nil {
			return "", err
		}
		hooks := object{}
		events := []string{}
		for event := range a.Events {
			events = append(events, event)
		}
		sort.Strings(events)
		for _, event := range events {
			hooks[event] = []any{object{"hooks": []any{object{"type": "command", "command": hookCommand(binary, path, event), "timeout": 3}}}}
		}
		config = object{"description": "Latto live agent activity", "hooks": hooks}
	case "kiro":
		hooks := []any{}
		for _, event := range []string{"UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop"} {
			hooks = append(hooks, object{"name": "latto-" + event, "trigger": event, "enabled": true, "timeout": 5,
				"action": object{"type": "command", "command": hookCommand(binary, path, event)}})
		}
		config = object{"version": "v1", "hooks": hooks}
	default:
		return "", fmt.Errorf("usage: latto-agent configure codex|codex-hooks|kiro")
	}
	content, err := json.MarshalIndent(config, "", "  ")
	return string(content) + "\n", err
}

func main() {
	args := os.Args[1:]
	if len(args) > 0 && args[0] == "configure" {
		if len(args) != 2 {
			fmt.Fprintln(os.Stderr, "usage: latto-agent configure codex|codex-hooks|kiro")
			os.Exit(1)
		}
		config, err := configuration(args[1], repoDir())
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Print(config)
		return
	}
	// Hooks must remain silent and never fail the agent's tool call.
	report(args, repoDir())
}
