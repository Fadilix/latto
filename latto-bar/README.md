# Latto bar

A minimal Quickshell / Hyprland top bar based on your black, rounded Waybar.
Latto is the center component of the bar: the same window hosts its compact
clock, media, live activities, notifications and expanding control panel.

## Install and run

From the monorepo root, install the bar and island as a copy in Quickshell's
named config directory:

```sh
./latto-island/install.sh --bar
```

Choose `--island` instead to install the standalone dynamic island. Then start
the installed bar with `latto` or:

```sh
qs -p ~/.config/quickshell/latto
```

The path form matters when `~/.config/quickshell/shell.qml` already exists:
Quickshell then skips named config discovery. Re-run the installer after
updating the repo to refresh the installed copy.

To run directly from the checkout instead:

From the monorepo root:

```sh
./latto-bar/run
```

Or use `quickshell -p /home/fadilix/projects/android/latto/latto-bar/bar.qml`.
The entry point imports the island from the sibling `latto-island/` directory.
Keep both project directories together.

For a clean desktop, stop your existing Waybar and standalone Latto instances
before starting this bar. Do not stop an unrelated Quickshell shell. This
launcher does not modify your running desktop or autostart settings.

For autostart, use:

```ini
exec-once = latto start
```

## Controls

- Workspaces: click to switch; scroll to move between workspaces on that monitor.
- Coffee: keep the computer awake.
- Agent chip: opens an overview of every active agent session. The badge counts sessions and turns amber when any session needs input. Waiting sessions appear first, with project, activity, elapsed time, available token counts and a short session ID. Completion removes a session from the overview. Existing live agent hooks are required; completion-only integrations cannot show ongoing work.
- Center: Latto's existing hover/click expansion, media and activity animations.
- Bell: notifications; right click for Do Not Disturb and clearing history.
- Network: opens a dedicated Wi-Fi popup beneath the icon. Choose saved/open networks directly, or enter credentials for a new secured network. Includes rescan, radio toggle, connection errors and disconnect.
- Bluetooth: opens its own nearby/paired device popup with power, pairing, connect/disconnect and device settings. Discovery started by the popup stops when it closes.
- Volume: opens its own popup with an output slider, speaker and microphone mute, and sound settings.
- Bluetooth: right click for the adapter toggle and device manager.
- Volume: scroll changes volume by 5%; right click for output/microphone mute and mixer settings.
- Battery: informational only; percentage, charging/low battery colors and a status tooltip. No click action or menu.
- Calendar remains available inside Latto, without a separate bar button.
- Right-click menus and the Wi-Fi popup dismiss on outside click or Escape.
- Hover tooltips use compact, dark styling. Bar icons use a consistent outline family; tray icons retain their application branding.
- Tray: left, middle, right click and scrolling are forwarded to the app.

The bar appears on every monitor, sits flush against the screen edges, reserves 32 logical pixels at the top, and
hides in fullscreen according to Latto's existing setting. Notifications can
still appear in fullscreen. Secondary labels and controls disappear on smaller
screens; the expanded island still provides those controls.

## Customize

`BarContent.qml` owns the layout and dark surface; `components/BarButton.qml`
owns hover styling and sizing. Latto's existing `~/.config/latto/config.json`
continues to control its font, accent, tabs, services and behavior.
The bar uses Latto's services directly, without another notification daemon or
audio/network polling layer. Running standalone Latto separately is unnecessary.

Keyboard / script integration uses the combined configuration path:

```sh
qs -p ~/.config/quickshell/latto ipc call island open overview
qs -p ~/.config/quickshell/latto ipc call island close
```

Dependencies are the same as Latto's, plus Hyprland. System tray support uses Quickshell's native SystemTray module.

## Validation

QML lint passes for the new files and the modified `latto-island/IslandWindow.qml`.
The bar component also loads and renders successfully in an offscreen Qt window. Full
Wayland rendering and live desktop interactions need testing in your session:
the build sandbox cannot connect to Wayland, DBus, Hyprland or PipeWire.

API references: [PanelWindow](https://quickshell.org/docs/v0.2.0/types/Quickshell/PanelWindow/),
[Hyprland](https://quickshell.org/docs/v0.2.0/types/Quickshell.Hyprland/Hyprland/),
[SystemTrayItem](https://quickshell.org/docs/v0.2.0/types/Quickshell.Services.SystemTray/SystemTrayItem/).

Agent integrations automatically target this bar while it is running, falling
back to standalone Latto otherwise. `LATTO_SHELL=/absolute/path/to/latto-bar/bar.qml`
overrides detection. The native agent reporter binary must be rebuilt after
changing its Go source (`latto-island/integrations/agents/build.sh`). Existing provider
hooks are still required; a completion-only hook cannot report live work.
