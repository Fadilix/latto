import Quickshell
import "services"

ShellRoot {
    // Services with background work. Referencing them here starts their
    // polling even when no island is currently showing their data.
    readonly property var background: [Hud, Lyrics, Clipboard, Caffeine, Privacy, Downloads, Timers, Bluetooth, Network, Calendar, Notifications, Claude, NightLight]

    Variants {
        model: Quickshell.screens

        delegate: IslandWindow {}
    }
}
