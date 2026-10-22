#!/usr/bin/env bash
# latto installer.
#
#   ./install.sh              interactive setup (asks before each optional step)
#   ./install.sh --yes        accept every step without asking
#   ./install.sh --check      only report missing dependencies
#   ./install.sh --uninstall  undo what the installer set up
#   ./install.sh --no-start   set up, but do not (re)start latto
#
# Safe to re-run: every step checks what is already in place. Files it changes
# are backed up first, and what it changed is recorded so --uninstall can undo it.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/latto"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/latto"
USER_CONFIG="$CONFIG_HOME/latto/config.json"
HYPR_DIR="$CONFIG_HOME/hypr"
HYPR_MAIN="$HYPR_DIR/hyprland.conf"
HYPR_LATTO="$HYPR_DIR/latto.conf"
HYPR_SOURCE_LINE="source = $HYPR_LATTO"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_HOOKS="$CLAUDE_DIR/hooks"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_ICON_URL="https://claude.ai/apple-touch-icon.png"
MASKED_RECORD="$STATE_DIR/masked-units"

ASSUME_YES=0
START=1
MODE=install

for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        --check) MODE=check ;;
        --uninstall) MODE=uninstall ;;
        --no-start) START=0 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

# --- output helpers ----------------------------------------------------------

if [ -t 1 ]; then
    BOLD=$'\e[1m' DIM=$'\e[2m' GREEN=$'\e[32m' YELLOW=$'\e[33m' RED=$'\e[31m' RESET=$'\e[0m'
else
    BOLD="" DIM="" GREEN="" YELLOW="" RED="" RESET=""
fi

step() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$RESET"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail() { printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; }
note() { printf '    %s%s%s\n' "$DIM" "$1" "$RESET"; }

# ask "question" -> 0 for yes. Defaults to yes; --yes answers yes to everything.
ask() {
    [ "$ASSUME_YES" = 1 ] && return 0
    [ -t 0 ] || return 1
    local answer
    read -r -p "  $1 [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

backup() {
    [ -e "$1" ] && cp -p "$1" "$1.bak-latto-$(date +%Y%m%d-%H%M%S)"
    return 0
}

# --- dependencies ------------------------------------------------------------

# command | what needs it | Arch package
DEPENDENCIES=(
    "qs|everything (Quickshell)|quickshell"
    "udevadm|instant brightness and charger alerts|systemd"
    "systemd-inhibit|keep-awake|systemd"
    "brightnessctl|brightness alerts and slider|brightnessctl"
    "pactl|microphone-in-use indicator|libpulse"
    "paplay|timer sound|libpulse"
    "nmcli|network tile|networkmanager"
    "curl|lyrics, weather, Claude icon download|curl"
    "notify-send|Claude Code notifications, testing|libnotify"
    "jq|Claude Code hook setup|jq"
    "hyprsunset|night light|hyprsunset"
    "cliphist|clipboard history|cliphist"
    "wl-paste|clipboard history|wl-clipboard"
    "wl-copy|clipboard history|wl-clipboard"
    "khal|calendar events (optional)|khal"
)

check_dependencies() {
    step "Checking dependencies"
    local missing_packages=() entry cmd purpose package
    for entry in "${DEPENDENCIES[@]}"; do
        IFS='|' read -r cmd purpose package <<<"$entry"
        if have "$cmd"; then
            ok "$cmd"
        elif [ "$cmd" = "qs" ]; then
            fail "$cmd: needed for $purpose"
            missing_packages+=("$package")
        else
            warn "$cmd missing: $purpose won't work"
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        local unique
        unique="$(printf '%s\n' "${missing_packages[@]}" | sort -u | tr '\n' ' ')"
        if have pacman; then
            note "Install with: sudo pacman -S --needed $unique"
            note "(quickshell and cliphist may come from the AUR on older setups)"
        else
            note "Arch package names: $unique (names may differ on your distro)"
        fi
    fi

    have qs
}

# --- install steps -----------------------------------------------------------

install_launcher() {
    step "Installing the latto command"
    mkdir -p "$BIN_DIR"
    chmod +x "$REPO/bin/latto" "$REPO/integrations/claude-code/latto-notify.sh"
    if [ -L "$LAUNCHER" ] && [ "$(readlink -f "$LAUNCHER")" = "$REPO/bin/latto" ]; then
        ok "$LAUNCHER already points here"
    else
        [ -e "$LAUNCHER" ] && backup "$LAUNCHER" && rm -f "$LAUNCHER"
        ln -s "$REPO/bin/latto" "$LAUNCHER"
        ok "linked $LAUNCHER -> $REPO/bin/latto"
    fi
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) warn "$BIN_DIR is not on your PATH; add it, or call $LAUNCHER directly" ;;
    esac
}

install_user_config() {
    step "User configuration"
    if [ -f "$USER_CONFIG" ]; then
        ok "keeping existing $USER_CONFIG"
    else
        mkdir -p "$(dirname "$USER_CONFIG")"
        echo "{}" >"$USER_CONFIG"
        ok "created $USER_CONFIG (empty: every setting uses its default)"
    fi
    note "Every option, with its default: $REPO/config.example.json"
}

# Make latto the notification daemon: stop whichever daemon owns the name and
# mask its systemd unit so D-Bus cannot start it again.
take_over_notifications() {
    step "Notifications"
    local owner
    owner="$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^Comm=//p' || true)"

    if [ -z "$owner" ]; then
        ok "no other notification daemon is running; latto will take the role"
        return
    fi
    if [ "$owner" = "qs" ] || [ "$owner" = "quickshell" ]; then
        ok "a Quickshell instance already handles notifications"
        return
    fi

    warn "$owner currently handles notifications; latto can't receive any while it runs"
    if ! ask "Stop $owner and let latto handle notifications?"; then
        note "Skipped. Or set \"notificationsEnabled\": false in $USER_CONFIG to keep $owner."
        return
    fi

    mkdir -p "$STATE_DIR"
    if systemctl --user cat "$owner.service" >/dev/null 2>&1; then
        systemctl --user mask --now "$owner.service" >/dev/null 2>&1 || true
        grep -qx "$owner.service" "$MASKED_RECORD" 2>/dev/null || echo "$owner.service" >>"$MASKED_RECORD"
        ok "masked $owner.service (D-Bus can no longer restart $owner)"
    fi
    pkill -x "$owner" 2>/dev/null || true
    ok "stopped $owner"

    # Autostart lines that would bring it back on the next login.
    if [ -d "$HYPR_DIR" ]; then
        local lines
        lines="$(grep -rn --include='*.conf' -E "^[^#]*exec(-once)?.*\b$owner\b" "$HYPR_DIR" 2>/dev/null | grep -v '/backup' || true)"
        if [ -n "$lines" ]; then
            warn "these Hyprland lines still start $owner; comment them out:"
            while IFS= read -r line; do note "$line"; done <<<"$lines"
        fi
    fi
}

# Keybinds tried for Do Not Disturb, in order: "MODS|modmask|KEY".
# Hyprland modmask bits: SHIFT 1, CTRL 4, ALT 8, SUPER 64.
DND_BIND_CANDIDATES=(
    "SUPER SHIFT|65|N"
    "SUPER ALT|72|N"
    "SUPER CTRL SHIFT|69|N"
)

# Prints the first candidate not already bound (to something other than latto)
# in the running Hyprland. Without hyprctl it can't tell, so it prints the first.
free_dnd_bind() {
    local candidate mods mask key binds=""
    if have hyprctl && have jq; then
        binds="$(hyprctl binds -j 2>/dev/null || true)"
    fi
    for candidate in "${DND_BIND_CANDIDATES[@]}"; do
        IFS='|' read -r mods mask key <<<"$candidate"
        if [ -z "$binds" ] || ! jq -e --argjson m "$mask" --arg k "$key" \
            'any(.[]; .modmask == $m and (.key | ascii_upcase) == $k and (.arg | contains("latto") | not))' \
            <<<"$binds" >/dev/null 2>&1; then
            echo "$mods|$key"
            return 0
        fi
    done
    return 1
}

install_hyprland() {
    step "Hyprland"
    if [ ! -f "$HYPR_MAIN" ]; then
        ok "no $HYPR_MAIN; start latto with 'latto' from your compositor's autostart"
        return
    fi
    local chosen bind mods key
    if chosen="$(free_dnd_bind)"; then
        IFS='|' read -r mods key <<<"$chosen"
        bind="bind = $mods, $key, exec, $LAUNCHER dnd"
    else
        mods=""
        bind="# bind = SUPER ALT, N, exec, $LAUNCHER dnd   # every candidate key was taken; pick one"
    fi

    local question="Start latto at login"
    [ -n "$mods" ] && question+=" and bind ${mods// /+}+$key to Do Not Disturb"
    if ! ask "$question?"; then
        note "Skipped. To do it yourself: exec-once = $LAUNCHER start"
        return
    fi
    [ -n "$mods" ] || warn "no free keybind found for Do Not Disturb; it is written commented out"

    cat >"$HYPR_LATTO" <<EOF
# Generated by latto's install.sh ($REPO).
# Remove the 'source' line for this file in hyprland.conf to disable it.

exec-once = $LAUNCHER start
$bind
EOF
    ok "wrote $HYPR_LATTO"
    [ -n "$mods" ] && note "Do Not Disturb: ${mods// /+}+$key"

    if grep -qxF "$HYPR_SOURCE_LINE" "$HYPR_MAIN"; then
        ok "hyprland.conf already sources it"
    else
        backup "$HYPR_MAIN"
        # Start on a fresh line without adding blank lines uninstall would leave behind.
        [ -n "$(tail -c 1 "$HYPR_MAIN")" ] && echo >>"$HYPR_MAIN"
        printf '# latto dynamic island\n%s\n' "$HYPR_SOURCE_LINE" >>"$HYPR_MAIN"
        ok "added '$HYPR_SOURCE_LINE' to hyprland.conf (backup saved next to it)"
    fi
}

# The jq filter that removes latto's hook entries, leaving everything else.
JQ_DROP_LATTO_HOOKS='
  if .hooks then
    .hooks |= (with_entries(.value |= (map(.hooks |= map(select((.command // "") | test("latto-(notify|activity)\\.sh") | not)))
                                       | map(select(.hooks | length > 0))))
               | with_entries(select(.value | length > 0)))
    | if (.hooks | length) == 0 then del(.hooks) else . end
  else . end'

install_claude_code() {
    step "Claude Code"
    if ! have claude && [ ! -d "$CLAUDE_DIR" ]; then
        ok "Claude Code not found; skipping"
        return
    fi
    if ! have jq; then
        warn "jq is missing; install it and re-run to set up Claude Code notifications"
        return
    fi
    if ! ask "Show Claude Code on the island (live activity, plus notifications when it needs input or finishes)?"; then
        note "Skipped."
        return
    fi

    mkdir -p "$CLAUDE_HOOKS"
    local script
    for script in latto-notify.sh latto-activity.sh; do
        cp "$REPO/integrations/claude-code/$script" "$CLAUDE_HOOKS/$script"
        chmod +x "$CLAUDE_HOOKS/$script"
    done
    # Tells latto-activity.sh where latto lives, for `qs -p <dir> ipc`.
    printf 'LATTO_DIR=%q\n' "$REPO" >"$CLAUDE_HOOKS/latto.env"
    ok "installed the latto hooks in $CLAUDE_HOOKS"

    # The Claude app icon is Anthropic's, so it is fetched here instead of
    # being shipped in the repo.
    if [ -f "$CLAUDE_HOOKS/claude.png" ]; then
        ok "Claude icon already present"
    elif have curl && curl -fsSL --max-time 15 -o "$CLAUDE_HOOKS/claude.png.tmp" "$CLAUDE_ICON_URL" \
        && [ "$(head -c 4 "$CLAUDE_HOOKS/claude.png.tmp" | tail -c 3)" = "PNG" ]; then
        mv "$CLAUDE_HOOKS/claude.png.tmp" "$CLAUDE_HOOKS/claude.png"
        ok "downloaded the Claude icon from claude.ai"
    else
        rm -f "$CLAUDE_HOOKS/claude.png.tmp"
        warn "could not download the Claude icon; notifications use a generic icon"
    fi

    [ -f "$CLAUDE_SETTINGS" ] || echo "{}" >"$CLAUDE_SETTINGS"
    if ! jq -e . "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
        fail "$CLAUDE_SETTINGS is not valid JSON; fix it and re-run (left untouched)"
        return
    fi
    backup "$CLAUDE_SETTINGS"

    # Notifications run in line; the live activity runs async so it never
    # slows Claude Code down.
    if jq --arg dir "$CLAUDE_HOOKS" "$JQ_DROP_LATTO_HOOKS"' |
        def hook($event; $script; $arg; $async):
            .hooks[$event] = ((.hooks[$event] // []) + [{hooks: [
                {type: "command", command: "\($dir)/\($script) \($arg) 2>/dev/null || true", timeout: 10}
                + (if $async then {async: true} else {} end)
            ]}]);
        hook("Notification"; "latto-notify.sh"; "notification"; false)
        | hook("Stop"; "latto-notify.sh"; "stop"; false)
        | hook("UserPromptSubmit"; "latto-activity.sh"; "prompt"; true)
        | hook("PreToolUse"; "latto-activity.sh"; "tool"; true)
        | hook("PostToolUse"; "latto-activity.sh"; "tool-done"; true)
        | hook("Notification"; "latto-activity.sh"; "input"; true)
        | hook("Stop"; "latto-activity.sh"; "stop"; true)
        | hook("SessionEnd"; "latto-activity.sh"; "end"; true)' \
        "$CLAUDE_SETTINGS" >"$CLAUDE_SETTINGS.tmp"; then
        mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
        ok "added latto's hooks to $CLAUDE_SETTINGS (other settings kept)"
    else
        rm -f "$CLAUDE_SETTINGS.tmp"
        fail "could not update $CLAUDE_SETTINGS (left untouched)"
        return
    fi
    note "Running Claude Code sessions pick this up after /hooks or a restart."
}

start_latto() {
    step "Starting latto"
    if [ "$START" = 0 ]; then
        ok "skipped (--no-start); run 'latto' to start it"
        return
    fi
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        warn "not in a Wayland session; latto will start at your next login"
        return
    fi
    "$LAUNCHER" restart
    sleep 1
    if "$LAUNCHER" status >/dev/null 2>&1; then
        ok "latto is running"
        if have notify-send; then
            notify-send -a latto "latto is set up" "Notifications now arrive on the island." 2>/dev/null || true
        fi
    else
        warn "latto did not start; see 'latto logs'"
    fi
}

# --- uninstall ---------------------------------------------------------------

uninstall() {
    step "Uninstalling latto"

    [ -x "$LAUNCHER" ] && "$LAUNCHER" stop 2>/dev/null || true
    ok "stopped latto"

    if [ -L "$LAUNCHER" ] && [ "$(readlink -f "$LAUNCHER")" = "$REPO/bin/latto" ]; then
        rm -f "$LAUNCHER"
        ok "removed $LAUNCHER"
    fi

    if [ -f "$HYPR_MAIN" ] && grep -qxF "$HYPR_SOURCE_LINE" "$HYPR_MAIN"; then
        backup "$HYPR_MAIN"
        grep -vxF -e "$HYPR_SOURCE_LINE" -e "# latto dynamic island" "$HYPR_MAIN" >"$HYPR_MAIN.tmp"
        mv "$HYPR_MAIN.tmp" "$HYPR_MAIN"
        ok "removed the latto line from hyprland.conf"
    fi
    if [ -f "$HYPR_LATTO" ]; then
        rm -f "$HYPR_LATTO"
        ok "removed $HYPR_LATTO"
    fi

    if [ -f "$CLAUDE_SETTINGS" ] && have jq && grep -q -E "latto-(notify|activity)\.sh" "$CLAUDE_SETTINGS"; then
        backup "$CLAUDE_SETTINGS"
        if jq "$JQ_DROP_LATTO_HOOKS" "$CLAUDE_SETTINGS" >"$CLAUDE_SETTINGS.tmp"; then
            mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
            ok "removed latto's hooks from $CLAUDE_SETTINGS"
        else
            rm -f "$CLAUDE_SETTINGS.tmp"
            fail "could not update $CLAUDE_SETTINGS (left untouched)"
        fi
    fi
    rm -f "$CLAUDE_HOOKS/latto-notify.sh" "$CLAUDE_HOOKS/latto-activity.sh" "$CLAUDE_HOOKS/latto.env" "$CLAUDE_HOOKS/claude.png"

    if [ -f "$MASKED_RECORD" ]; then
        local unit
        while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            if ask "Unmask $unit so it can handle notifications again?"; then
                systemctl --user unmask "$unit" >/dev/null 2>&1 || true
                ok "unmasked $unit (it starts again with the next notification)"
            fi
        done <"$MASKED_RECORD"
        rm -f "$MASKED_RECORD"
    fi

    note "Kept your settings in $(dirname "$USER_CONFIG") and state in $STATE_DIR."
}

# --- main --------------------------------------------------------------------

printf '%slatto%s dynamic island %s(%s)%s\n' "$BOLD" "$RESET" "$DIM" "$REPO" "$RESET"

case "$MODE" in
    check)
        check_dependencies
        ;;
    uninstall)
        uninstall
        ;;
    install)
        if ! check_dependencies; then
            printf '\n%sQuickshell is required. Install it, then run this again.%s\n' "$RED" "$RESET"
            exit 1
        fi
        install_launcher
        install_user_config
        take_over_notifications
        install_hyprland
        install_claude_code
        start_latto
        printf '\n%sDone.%s Hover the island at the top of the screen. Try: latto status, latto dnd\n' "$BOLD" "$RESET"
        ;;
esac
