import QtQuick
import Quickshell
import "../latto-island" as Latto
import "../latto-island/services"
import "." as Bar

ShellRoot {
    readonly property var background: [Hud, Lyrics, Clipboard, Caffeine, Privacy,
        Downloads, Timers, Bluetooth, Network, Calendar, Notifications, Claude, NightLight]

    Variants {
        model: Quickshell.screens
        delegate: Latto.IslandWindow {
            id: island
            barComponent: Component {
                Bar.BarContent {
                    monitor: island.hyprMonitor
                    centerWidth: island.centerWidth
                    panelWindow: island
                    onOpenTab: tab => IslandState.openRequested(tab)
                }
            }
        }
    }
}
