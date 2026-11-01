#!/usr/bin/env bash
# Claude Code hook: send "needs your input" and "finished" events to the desktop
# notification daemon (latto's island). install.sh copies this to
# ~/.claude/hooks/ and registers it in ~/.claude/settings.json.
#
#   latto-notify.sh notification   # Notification hook (permission or idle prompt)
#   latto-notify.sh stop           # Stop hook (Claude finished responding)
#
# The hook's JSON payload arrives on stdin. Nothing is sent while the terminal
# running this session is the focused window (set LATTO_NOTIFY_WHEN_FOCUSED=1
# to always notify).

event="${1:-}"
input="$(cat)"

field() {
    jq -r "$1 // empty" <<<"$input" 2>/dev/null
}

project="$(basename "$(field .cwd)")"
suffix="${project:+ · $project}"

case "$event" in
    notification)
        summary="Needs your input$suffix"
        body="$(field .message)"
        body="${body:-Claude is waiting for you}"
        # Permission prompts block Claude, so they stay up a little longer,
        # but still leave on their own.
        urgency=normal
        timeout=8000
        [ "$(field .notification_type)" = "permission_prompt" ] && timeout=12000
        ;;
    stop)
        # A Stop hook that itself made Claude continue would loop; stay quiet then.
        [ "$(field .stop_hook_active)" = "true" ] && exit 0
        summary="Finished$suffix"
        body="$(field .last_assistant_message | tr '\n' ' ' | cut -c1-160)"
        body="${body:-Claude finished responding}"
        urgency=normal
        timeout=6000
        ;;
    *)
        exit 0
        ;;
esac

# Stay quiet when you're already looking at this session: the focused window
# is the terminal this Claude Code runs in. Needs Hyprland; elsewhere it always
# notifies.

# True if `target` is `pid` or one of its ancestors.
has_ancestor() {
    local pid="$1" target="$2"
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
        [ "$pid" = "$target" ] && return 0
        pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    done
    return 1
}

session_focused() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    local focused session client
    focused="$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' 2>/dev/null)"
    [ -n "$focused" ] && [ "$focused" -gt 0 ] || return 1

    # Inside tmux the terminal isn't an ancestor (tmux's server is): Claude's
    # pane must be the one on show, and a client attached to its session must
    # run in the focused terminal.
    if [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then
        [ "$(tmux display -p -t "$TMUX_PANE" '#{window_active}#{pane_active}' 2>/dev/null)" = 11 ] || return 1
        session="$(tmux display -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)"
        for client in $(tmux list-clients -t "$session" -F '#{client_pid}' 2>/dev/null); do
            has_ancestor "$client" "$focused" && return 0
        done
        return 1
    fi

    has_ancestor $$ "$focused"
}

if [ "${LATTO_NOTIFY_WHEN_FOCUSED:-0}" != 1 ] && session_focused; then
    exit 0
fi

# Say "needs your input" once per wait: the same message for the same session
# within five minutes is not sent again.
if [ "$event" = notification ]; then
    seen_dir="${XDG_CACHE_HOME:-$HOME/.cache}/latto/claude-notify"
    session="$(field .session_id)"
    seen="$seen_dir/${session:-unknown}"
    key="$(printf '%s' "$(field .notification_type)|$body" | md5sum | cut -d' ' -f1)"
    now="$(date +%s)"
    if [ -f "$seen" ]; then
        read -r last_key last_time <"$seen"
        [ "$last_key" = "$key" ] && [ $((now - ${last_time:-0})) -lt 300 ] && exit 0
    fi
    mkdir -p "$seen_dir"
    echo "$key $now" >"$seen"
    # Forget sessions untouched for a day.
    find "$seen_dir" -type f -mtime +1 -delete 2>/dev/null
fi

# The Claude app icon, which install.sh downloads from claude.ai next to this
# script. Fall back to a generic icon if it is missing.
icon="$(dirname "$(readlink -f "$0")")/claude.png"
[ -f "$icon" ] || icon="utilities-terminal"

notify-send -a "Claude Code" -i "$icon" -u "$urgency" -t "$timeout" "$summary" "$body"
