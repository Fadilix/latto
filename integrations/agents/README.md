# Agent integrations

One protocol handles any coding agent. A Go binary translates native payloads
using JSON mapping files; adding a tool requires no new QML service or display.
Existing Claude Code shell hooks and the `claude` IPC endpoint remain compatible.

## Build

From the repository root:

```sh
./integrations/agents/build.sh
```

Requires Go 1.22 or later to build; no external Go dependencies. The generated
`bin/latto-agent` needs only `qs` and `notify-send` at runtime. Rebuild after source
updates. The generated binary is ignored by Git. Keep it in `bin/`, or set
`LATTO_DIR` to the repository path when installing it elsewhere.

Set `agentActivity` to false in `~/.config/latto/config.json` to disable new agent
live activity. `claudeActivity` still controls Claude. Waiting uses the existing
`claudeInputDuration` setting. Completion banners follow normal notification/DND
settings. A crashed session expires after 30 minutes without events.

Spinners, waiting dots and completion notification tiles use orange for Claude,
purple for Kiro and blue for Codex. Override colors using lowercase agent names:

```json
{"agentColors": {"claude": "#d97757", "kiro": "#9046ff", "codex": "#7a9dff"}}
```

## Codex

```sh
bin/latto-agent configure codex
bin/latto-agent configure codex-hooks > /tmp/latto-codex-hooks.json
```

Copy the generated `notify` line into the **top level** of your user
`~/.codex/config.toml` (or `$CODEX_HOME/config.toml`), before any `[table]`.
Preserve other settings. If you already have a notification command, combine
both commands in a wrapper rather than adding a duplicate key.

Merge the generated lifecycle `hooks` entries into `~/.codex/hooks.json`, keeping
other hooks. Start Codex, open `/hooks`, and review and trust the Latto commands.
Changing a command (including migrating from Python to Go) requires trusting its
new definition. Untrusted hooks are skipped.

Lifecycle hooks report prompt starts, tool activity and approval waits, and clear
activity on stop, interruption or exit. The `notify` command supplies completion
banners, reply excerpts and the Codex icon. No token counts are inferred from
private session files.

Sources: [Codex lifecycle hooks](https://learn.chatgpt.com/docs/hooks),
[configuration reference](https://developers.openai.com/codex/config-reference).

## Kiro CLI V3

```sh
bin/latto-agent configure kiro > /tmp/latto-hooks.json
```

Copy that file to `~/.kiro/hooks/latto.json` to enable it globally, or to
`.kiro/hooks/latto.json` in a workspace. Keep other hook files. Restart Kiro.
It reports prompts, tool activity and completion. The adapter accepts CLI 2.x
event names too, but those require registering commands in the legacy agent
`hooks` object. No approval/input hook is assumed.

Source: [Kiro hook formats](https://kiro.dev/docs/cli/v3/hooks-migration/).

## Any other agent

Send normalized JSON to stdin (or as the final command argument):

```sh
printf '%s\n' '{"agent":"My Agent","session":"abc","event":"prompt","project":"latto"}' \
  | bin/latto-agent
```

Required fields: `agent`, `session`, `event`. Events: `prompt` (reset the turn
clock), `working`, `input`, `done`, `end`. Optional: `cwd`, `project`, `detail`,
`at` and `startedAt` (epoch milliseconds), `tokens` (output count), `icon`
(absolute file path or themed icon name). `done` clears activity and sends a
completion notification; `end` clears silently. Sessions from different agents
are isolated even with identical IDs. Waiting sessions take priority; otherwise
the most recently updated session is shown. Supply `at` from the event source
when running hooks asynchronously so late events can be ignored.

For native payloads, copy `kiro.json`, change `agent`, map event names to the
protocol in `events`, and map fields using dot paths in `fields`. Set
`event_field` if the event name is not in `hook_event_name`. Set adapter-level
`icon` to a theme name or file path relative to the adapter JSON. Codex and Kiro
ship with SVG logos; unknown agents fall back to the terminal icon.

Register this command in the tool's hook settings:

```sh
/absolute/path/to/latto/bin/latto-agent --adapter /absolute/path/to/my-agent.json
```

`--event NativeEvent` overrides the payload event name. Hooks stay silent on
invalid input, missing dependencies or offline Latto. Commands have two-second
timeouts and never execute payload text. Generated settings refer to this
checkout; regenerate them if it moves. Remove the Codex `notify` entry and Latto
lifecycle commands, or Kiro `latto.json`, to disconnect an integration.

Run tests with `cd integrations/agents && go test ./...`.
