<div align="center">
  <h1>latto</h1>
  <p><strong>A dynamic island for Linux</strong></p>
  <p>Media, alerts and notifications in a compact Quickshell interface.</p>
  <p>
    <a href="https://quickshell.org">Quickshell</a>
    &nbsp;•&nbsp;
    <a href="https://github.com/Fadilix/latto">Source</a>
  </p>

https://github.com/user-attachments/assets/74d95953-1032-440e-93c5-30213e43e6aa


</div>

One island sits at the top centre of each monitor and expands on hover into
tabs for media, notifications, stats, timers, clipboard, calendar and an
overview.

## Install

```sh
git clone https://github.com/Fadilix/latto.git
cd latto
./install.sh
```

The installer checks dependencies, then asks before each optional step:

1. **Dependencies:** reports anything missing and the command to install it.
   Only Quickshell is required; every other tool powers a single feature.
2. **The `latto` command:** links `~/.local/bin/latto` to this repo, so
   `git pull` updates your install.
3. **Your config:** creates `~/.config/latto/config.json` if you have none.
4. **Notifications:** if another daemon (swaync, mako, dunst) handles
   notifications, offers to stop it and mask its systemd unit so it cannot
   come back. latto can only receive notifications once it is gone.
5. **Hyprland:** writes `~/.config/hypr/latto.conf` (autostart, plus a
   Do Not Disturb keybind on the first free one of Super+Shift+N,
   Super+Alt+N and Super+Ctrl+Shift+N) and sources it from `hyprland.conf`.
6. **Claude Code:** installs hooks so Claude Code notifies you on the island
   when it needs input or finishes, using the Claude app icon downloaded from
   claude.ai.
7. **Start:** (re)starts latto and sends a test notification.

Other options:

```sh
./install.sh --check      # only check dependencies
./install.sh --yes        # accept every step without asking
./install.sh --no-start   # set up, but don't start latto now
./install.sh --uninstall  # undo everything the installer set up
```

Re-running the installer is safe: it skips what is already in place. Every
file it edits is backed up next to the original first (`*.bak-latto-<date>`).
Uninstalling keeps your config in `~/.config/latto`.

On Arch, all dependencies are available with:

```sh
sudo pacman -S --needed quickshell brightnessctl libpulse networkmanager \
    curl libnotify jq cliphist wl-clipboard khal
```

`brightnessctl` needs write access to the backlight (usually membership of the
`video` group).

## Usage

```sh
latto              # start (does nothing if it is already running)
latto stop
latto restart
latto status       # running? and the Do Not Disturb state
latto dnd          # toggle Do Not Disturb (also: latto dnd on / off)
latto logs
```

Hover the island to open it; move the pointer away to close it.

## What it shows

- **Idle:** the clock, with the date or status indicators on the left:
  music playing, microphone in use (orange), camera in use (green), screen recording,
  keep-awake, a running timer, downloads in progress, and Do Not Disturb with
  the number of waiting notifications.
- **Privacy:** alerts when the microphone is muted or unmuted, when an app
  starts or stops using the microphone, and when the camera turns on or off.
  While media plays, small orange and green dots show the microphone or
  camera is in use. Monitor captures (audio visualizers, screen recorders
  capturing system sound) don't count as microphone use.
- **Media:** when playback starts or the track changes, the island shows the
  album art, title and an equaliser for a few seconds (`nowPlayingDuration`),
  then returns to idle with a music icon in place of the date. Set
  `mediaAlwaysShown` to `true` to keep the song on the island while it plays.
- **Claude Code live activity:** while a Claude Code session works, the
  island shows a coral spinner, the project, what it is doing ("Editing
  Foo.qml", "Running a command"), and the same elapsed time and output tokens
  as Claude Code's own status line ("2m 10s · ↓ 9.3k"), read from its
  transcript so they stay right even if latto restarts mid-task. Waiting for
  permission or a reply turns it into a pulsing dot with "Needs input" for 10
  seconds (`claudeInputDuration`), then the island steps back; it returns only
  for a new wait, not for the same one signalled again. Several
  sessions show as "+N". Set `claudeActivity` to `false` to turn it off.
- **Alerts:** volume, brightness, charging, low battery, Bluetooth connect
  and disconnect, timer finished, Do Not Disturb changes, and Caps Lock (shown
  while it is on). Brightness and charger alerts react to udev events, so they
  appear instantly.
- **Notifications:** a banner with the app icon, summary and body.
  - Hovering pauses it.
  - Clicking runs the app's default action, or opens the Notifications tab if
    there is none.
  - The cross dismisses it.
  - Critical notifications are tinted red and stay until handled.
- **Fullscreen:** when a window is fullscreen on a monitor, that monitor's
  island shrinks into a dot and disappears, and clicks pass through to the
  app. A notification brings it back: a dot pops in, stretches into a pill
  and grows into the banner, then shrinks back into a dot and vanishes when
  it is done. Set `hideInFullscreen` to `false` to keep the island visible.
  (Hyprland only.)
- **Already in the app:** a notification from the app whose window is focused
  gets no banner (it still goes to the history), since you're already looking
  at it. Claude Code's notifications stay quiet while its terminal is focused,
  tmux included. Set `quietWhenFocused` to `false` to always show banners.
- **Do Not Disturb:** banners are held back and notifications go straight to
  the history. Critical ones still show, unless `dndAllowCritical` is
  `false`. The setting survives restarts.
- **Expanded tabs:**
  - **Media:** art, title, synced lyrics, seek bar, shuffle and transport
    controls.
  - **Notifications:** history, newest first, with each app's action
    buttons, dismiss, clear all, and the Do Not Disturb switch.
  - **Stats:** CPU, memory, network and disk, with history graphs. Click
    the CPU or Memory card to see the apps using the most of it, with every
    process of an app (browser tabs, Electron helpers) counted together.
    CPU use is measured over the last two seconds, as a share of the whole
    machine.
  - **Timers:** a countdown with presets, a stopwatch, and Pomodoro: "Focus"
    starts a cycle of focus sessions and breaks (25/5 minutes, a 15-minute
    break after every fourth). Focus turns on Do Not Disturb and restores it
    afterwards; the idle island shows the time left in red, or green on a
    break.
  - **Clipboard:** cliphist history; click to copy again.
  - **Calendar:** a month grid, plus upcoming events from khal if enabled.
  - **Overview:** quick toggles for Wi-Fi, Bluetooth, Do Not Disturb, night
    light (hyprsunset) and the microphone. The Wi-Fi toggle (or the network
    tile) opens nearby networks: click a saved or open one to connect, or
    type the password for a new secured one. Enterprise (802.1X) networks
    must be set up once in your system settings. Then battery (with a keep-awake
    toggle), network, Bluetooth, weather, and adjustable volume and
    brightness.

## Configuration

`~/.config/latto/config.json` holds only the settings you change; everything
else uses its default. `config.example.json` lists every option with its
default. Changes apply live, without a restart.

- `fontFamily`: empty uses the system's default Qt font (from qt6ct, KDE or
  your platform theme). Set it to change the island's font only, for example
  `"JetBrains Mono"`.
- `accentColor`: the highlight colour.
- `tabs`: which expanded tabs to show, and in what order.
- `hideInFullscreen`: hide the island over fullscreen windows (default
  `true`).
- `notificationsEnabled`: set to `false` to keep using another notification
  daemon.
- `weatherLatitude`, `weatherLongitude`: set both to enable weather.
- `showLyrics`: set to `false` to stop fetching lyrics.

Privacy:
- **Lyrics:** fetched from lrclib.net with the current track's title, artist
  and album.
- **Weather:** your coordinates are sent to Open-Meteo.

## Claude Code integration

`integrations/claude-code/latto-notify.sh` is a Claude Code hook. The
installer copies it to `~/.claude/hooks/` and registers it in
`~/.claude/settings.json`, keeping your other settings and hooks.

| Event | Island shows |
|---|---|
| Claude needs permission | **Needs your input · project**, for 12 seconds |
| Claude is waiting for you | **Needs your input · project**, for 8 seconds |

The same "needs your input" message for a session is sent once, not again
within five minutes, so dismissing it is final.
| Claude finished a response | **Finished · project**, with the start of its reply |

A second hook, `latto-activity.sh`, feeds the live activity. It runs
asynchronously on every prompt and tool call, so it never slows Claude Code
down, and finds latto through `~/.claude/hooks/latto.env` (written by the
installer). `qs -p <latto> ipc call claude status` prints what the island
shows.

The Claude icon is Anthropic's, so it is not shipped in this repo. The
installer downloads it from claude.ai; without it, a generic icon is used.

## Layout

- `install.sh`: installer and uninstaller.
- `bin/latto`: the `latto` command.
- `integrations/claude-code/`: the Claude Code hook.
- `shell.qml`: starts the background services and creates one island per
  screen.
- `IslandWindow.qml`: the pill, its states and animations, and which view is
  shown.
- `theme/Theme.qml`: font, palette, sizes, and the bezier curves and durations
  used by every animation.
- `components/`: the collapsed view, the expanded view with its tab bar, the
  notification banner and card, shared widgets, and `tabs/` with one file per
  tab.
- `services/`: one singleton per data source.
  - `Activities`: the alert queue.
  - `Hud`: turns hardware events into alerts.
  - `Notifications`: the notification daemon, its history and Do Not Disturb.
  - `UdevMonitor`: the shared udev listener.

## Known limitations

- Keep-awake runs `systemd-inhibit`. If it ever stays active after being
  turned off, find it with `systemd-inhibit --list` and kill the leftover
  `sleep infinity`.
- CPU temperature is read from `thermal_zone0`, which is not always the CPU
  sensor.
- The khal calendar integration has not been tested against a real khal
  setup.
