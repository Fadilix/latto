package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func loadAdapter(t *testing.T, name string) *adapter {
	t.Helper()
	content, err := os.ReadFile(name + ".json")
	if err != nil {
		t.Fatal(err)
	}
	var a adapter
	if err := json.Unmarshal(content, &a); err != nil {
		t.Fatal(err)
	}
	return &a
}
func TestNativeAdapters(t *testing.T) {
	for _, tc := range []struct {
		name, event, want string
		payload           object
	}{
		{"codex", "agent-turn-complete", "done", object{"type": "agent-turn-complete", "thread-id": "a"}},
		{"kiro", "UserPromptSubmit", "prompt", object{"session_id": "a"}},
		{"kiro", "preToolUse", "working", object{"session_id": "a"}},
		{"codex-hooks", "PermissionRequest", "input", object{"session_id": "a"}},
		{"codex-hooks", "Stop", "end", object{"session_id": "a"}},
		{"codex-hooks", "Interrupt", "end", object{"session_id": "a"}},
	} {
		data := normalize(tc.payload, loadAdapter(t, tc.name), tc.event)
		if data["session"] != "a" || data["event"] != tc.want {
			t.Errorf("%s: %v", tc.name, data)
		}
	}
}
func TestCommands(t *testing.T) {
	repo, _ := filepath.Abs("../..")
	detail := "$(touch /tmp/never-execute) <b>hello</b>"
	for _, agent := range []string{"Codex", "Kiro"} {
		commands := commands(object{"agent": agent, "session": "a", "event": "done", "cwd": "/tmp/project", "detail": detail, "tokens": json.Number("9007199254740993")}, repo, 123)
		ipc, notify := commands[0], commands[1]
		if ipc[11] != detail || ipc[12] != "123" || ipc[14] != "9007199254740993" {
			t.Fatalf("IPC: %v", ipc)
		}
		if !strings.Contains(notify[len(notify)-1], "&lt;b&gt;hello&lt;/b&gt;") {
			t.Fatal(notify)
		}
		expected := filepath.Join(repo, "integrations/agents/icons", strings.ToLower(agent)+".svg")
		if notify[4] != expected {
			t.Fatalf("icon %s != %s", notify[4], expected)
		}
	}
}
func TestInvalidEvents(t *testing.T) {
	for _, data := range []object{nil, {}, {"agent": "A", "event": "prompt"}, {"agent": "A", "session": "a", "event": "other"}} {
		if got := commands(data, "/tmp", 1); len(got) != 0 {
			t.Fatal(got)
		}
	}
	for _, input := range []string{"broken", "[]", "null", "{} {}"} {
		data, err := readObject(strings.NewReader(input))
		if err == nil && data != nil {
			t.Fatalf("accepted %s", input)
		}
	}
}
func TestConfiguration(t *testing.T) {
	repo, _ := filepath.Abs("../..")
	for _, provider := range []string{"codex-hooks", "kiro"} {
		text, err := configuration(provider, repo)
		if err != nil {
			t.Fatal(err)
		}
		var data object
		if json.Unmarshal([]byte(text), &data) != nil {
			t.Fatal(text)
		}
		if strings.Contains(text, "python") || !strings.Contains(text, "latto-agent") {
			t.Fatal(text)
		}
	}
	config, err := configuration("codex", repo)
	if err != nil || !strings.Contains(config, "notify = [") || strings.Contains(config, "python") {
		t.Fatal(config, err)
	}
	if _, err := configuration("invalid", repo); err == nil {
		t.Fatal("invalid provider accepted")
	}
	if shellQuote("a'b") != "'a'\"'\"'b'" {
		t.Fatal("shell quoting")
	}
}
func TestNormalizedCustomIcon(t *testing.T) {
	got := commands(object{"agent": "Other", "session": "a", "event": "done", "icon": "custom-icon"}, "/tmp", 1)
	if got[1][4] != "custom-icon" {
		t.Fatal(got)
	}
}

func TestReportRunsAdapterAndNotification(t *testing.T) {
	dir := t.TempDir()
	log := filepath.Join(dir, "calls")
	for _, name := range []string{"qs", "notify-send"} {
		// Arguments are logged literally; payloads must never become shell code.
		script := "#!/bin/sh\nprintf '%s\\n' \"$0\" \"$@\" >> \"$LATTO_AGENT_TEST_LOG\"\n"
		if err := os.WriteFile(filepath.Join(dir, name), []byte(script), 0700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("LATTO_AGENT_TEST_LOG", log)
	repo, _ := filepath.Abs("../..")
	report([]string{"--adapter", "codex.json", `{"type":"agent-turn-complete","thread-id":"go-test","cwd":"/tmp/project","last-assistant-message":"<test> $(false)"}`}, repo)
	content, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"agents\nreport\nCodex\ngo-test\ndone", filepath.Join(repo, "integrations/agents/icons/codex.svg"), "&lt;test&gt; $(false)"} {
		if !strings.Contains(string(content), expected) {
			t.Fatalf("missing %q in %s", expected, content)
		}
	}
}
