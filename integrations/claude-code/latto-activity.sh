#!/usr/bin/env bash
# Claude Code hook: keep latto's live activity in step with this session.
# install.sh copies this to ~/.claude/hooks/ and registers it for these events:
#
#   latto-activity.sh prompt      # UserPromptSubmit: a new task starts
#   latto-activity.sh tool        # PreToolUse: about to use a tool
#   latto-activity.sh tool-done   # PostToolUse: back to thinking
#   latto-activity.sh input       # Notification: waiting for permission or a reply
#   latto-activity.sh stop        # Stop: finished the turn
#   latto-activity.sh end         # SessionEnd: session closed
#
# The hook's JSON payload arrives on stdin. Does nothing if latto isn't running.

# When the event happened, taken first: the hooks run asynchronously, and latto
# uses this to put events back in order.
at="$(date +%s%3N)"
event="${1:-}"
input="$(cat)"

field() {
    jq -r "$1 // empty" <<<"$input" 2>/dev/null
}

# Where latto lives: $LATTO_DIR, else latto.env next to this script (written by
# install.sh), else the `latto` command's repo.
latto_dir() {
    if [ -n "${LATTO_DIR:-}" ]; then
        echo "$LATTO_DIR"
        return
    fi
    local env_file
    env_file="$(dirname "$(readlink -f "$0")")/latto.env"
    if [ -f "$env_file" ]; then
        # shellcheck disable=SC1090
        . "$env_file"
        [ -n "${LATTO_DIR:-}" ] && echo "$LATTO_DIR" && return
    fi
    local launcher
    launcher="$(command -v latto 2>/dev/null)" || return 1
    dirname "$(dirname "$(readlink -f "$launcher")")"
}

# What a tool call is doing, in a few words.
describe_tool() {
    local tool file
    tool="$(field .tool_name)"
    file="$(field '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path')"
    file="${file##*/}"
    case "$tool" in
        Bash|PowerShell) echo "Running a command" ;;
        Edit|MultiEdit|Write|NotebookEdit) echo "Editing ${file:-a file}" ;;
        Read) echo "Reading ${file:-a file}" ;;
        Grep|Glob|LSP) echo "Searching the code" ;;
        WebFetch|WebSearch) echo "Browsing the web" ;;
        Agent|Task) echo "Running an agent" ;;
        "") echo "Working" ;;
        mcp__*)
            local server="${tool#mcp__}"
            echo "Using ${server%%__*}"
            ;;
        *) echo "$tool" ;;
    esac
}

# The current turn, from Claude Code's transcript: when its prompt was sent
# (epoch ms) and the output tokens written since, as "<start> <tokens>".
# Read backwards and stopped at the prompt, so long transcripts stay cheap.
turn_stats() {
    local transcript stats start tokens
    transcript="$(field .transcript_path)"
    [ -f "$transcript" ] || { echo "0 0"; return; }
    stats="$(tac "$transcript" \
        | awk '{ print } /"type":"user"/ && !/"tool_result"/ && !/"isMeta":true/ { exit }' \
        | jq -rs '
            (map(select(.type == "user")) | last | .timestamp // "") as $start
            | (map(select(.type == "assistant" and .message.usage != null))
                | unique_by(.message.id)
                | map(.message.usage.output_tokens // 0)
                | add // 0) as $tokens
            | "\($start) \($tokens)"' 2>/dev/null)"
    start="${stats% *}"
    tokens="${stats##* }"
    start="$(date -d "$start" +%s%3N 2>/dev/null || echo 0)"
    echo "${start:-0} ${tokens:-0}"
}

session="$(field .session_id)"
[ -n "$session" ] || exit 0
dir="$(latto_dir)" || exit 0
[ -f "$dir/shell.qml" ] || exit 0
project="$(basename "$(field .cwd)")"

ipc() {
    qs -p "$dir" ipc call claude "$@" >/dev/null 2>&1
}

report() {
    local stats
    stats="$(turn_stats)"
    ipc update "$session" "$1" "$project" "$2" "$at" "${stats% *}" "${stats##* }"
}

case "$event" in
    prompt) ipc prompt "$session" "$project" "$at" ;;
    tool) report working "$(describe_tool)" ;;
    tool-done) report working "Thinking" ;;
    input)
        detail="$(field .message)"
        report input "${detail:-Waiting for you}"
        ;;
    stop) ipc update "$session" done "$project" "" "$at" 0 0 ;;
    end) ipc update "$session" end "$project" "" "$at" 0 0 ;;
esac
exit 0
