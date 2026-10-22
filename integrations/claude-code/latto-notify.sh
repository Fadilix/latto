#!/usr/bin/env bash
# Claude Code hook: send "needs your input" and "finished" events to the desktop
# notification daemon (latto's island). install.sh copies this to
# ~/.claude/hooks/ and registers it in ~/.claude/settings.json.
#
#   latto-notify.sh notification   # Notification hook (permission or idle prompt)
#   latto-notify.sh stop           # Stop hook (Claude finished responding)
#
# The hook's JSON payload arrives on stdin.

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
        # Permission prompts block Claude, so they stay on screen until handled
        # and still show during Do Not Disturb.
        urgency=normal
        [ "$(field .notification_type)" = "permission_prompt" ] && urgency=critical
        ;;
    stop)
        # A Stop hook that itself made Claude continue would loop; stay quiet then.
        [ "$(field .stop_hook_active)" = "true" ] && exit 0
        summary="Finished$suffix"
        body="$(field .last_assistant_message | tr '\n' ' ' | cut -c1-160)"
        body="${body:-Claude finished responding}"
        urgency=normal
        ;;
    *)
        exit 0
        ;;
esac

# The Claude app icon, which install.sh downloads from claude.ai next to this
# script. Fall back to a generic icon if it is missing.
icon="$(dirname "$(readlink -f "$0")")/claude.png"
[ -f "$icon" ] || icon="utilities-terminal"

notify-send -a "Claude Code" -i "$icon" -u "$urgency" "$summary" "$body"
