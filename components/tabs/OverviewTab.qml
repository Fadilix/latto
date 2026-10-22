import QtQuick
import "../../services"
import "../../theme"
import ".."

// Quick toggles along the top, then at-a-glance tiles: battery (with
// keep-awake), network, Bluetooth, weather, and adjustable volume and
// brightness. The Wi-Fi toggle and the network tile open a list of nearby
// networks to connect to.
Item {
    id: root

    property bool showWifi: false

    readonly property real spacing: 8
    readonly property real cellWidth: (width - 2 * spacing) / 3
    readonly property real cellHeight: (tiles.height - spacing) / 2

    Swappable {
        anchors.fill: parent
        shown: !root.showWifi

        Row {
            id: toggles
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            QuickToggle {
                icon: Network.wifiEnabled ? "wifi" : "wifiOff"
                label: "Wi-Fi"
                checked: Network.wifiEnabled
                tint: Theme.blue
                onClicked: root.showWifi = true
            }
            QuickToggle {
                icon: "bluetooth"
                label: "Bluetooth"
                available: Bluetooth.available
                checked: Bluetooth.enabled
                tint: Theme.blue
                onClicked: Bluetooth.toggle()
            }
            QuickToggle {
                icon: "moon"
                label: "Focus"
                checked: Notifications.doNotDisturb
                tint: Theme.indigo
                onClicked: Notifications.toggleDoNotDisturb()
            }
            QuickToggle {
                icon: "nightLight"
                label: "Night light"
                checked: NightLight.active
                tint: Theme.orange
                onClicked: NightLight.toggle()
            }
            QuickToggle {
                // Lit while the microphone is live, like a hardware mute light.
                icon: Audio.microphoneMuted ? "micOff" : "mic"
                label: Audio.microphoneMuted ? "Mic off" : "Mic on"
                available: Audio.hasMicrophone
                checked: !Audio.microphoneMuted
                tint: Theme.green
                onClicked: Audio.toggleMicrophone()
            }
        }

        // Badge on the left; a value with a detail line, or with an adjustable bar.
        component Tile: Card {
            id: tile

            property string icon: ""
            property color tint: Theme.text
            property string value: ""
            property string detail: ""
            property real level: -1            // shows a draggable bar when >= 0
            property bool clickable: false
            signal levelPicked(real fraction)
            signal clicked()

            width: root.cellWidth
            height: root.cellHeight
            color: clickable && tileHover.hovered ? Theme.surfaceRaised : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }

            HoverHandler {
                id: tileHover
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -12
                enabled: tile.clickable
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.clicked()
            }

            Rectangle {
                id: badge
                anchors.left: parent.left
                anchors.leftMargin: -2
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: Qt.rgba(tile.tint.r, tile.tint.g, tile.tint.b, 0.16)

                Icon {
                    anchors.centerIn: parent
                    name: tile.icon
                    size: 15
                    color: tile.tint
                }
            }
            Label {
                id: valueLabel
                anchors.left: badge.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -2
                text: tile.value
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                anchors.left: valueLabel.left
                anchors.right: parent.right
                anchors.top: valueLabel.bottom
                anchors.topMargin: 1
                visible: tile.level < 0
                text: tile.detail
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption + 1
                elide: Text.ElideRight
            }
            IslandBar {
                anchors.left: valueLabel.left
                anchors.right: parent.right
                anchors.top: valueLabel.bottom
                anchors.topMargin: 6
                visible: tile.level >= 0
                implicitHeight: barMouse.containsMouse ? 8 : 6
                value: tile.level
                fillColor: tile.tint

                MouseArea {
                    id: barMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => tile.levelPicked((mouse.x - 8) / (width - 16))
                    onPositionChanged: mouse => {
                        if (pressed)
                            tile.levelPicked((mouse.x - 8) / (width - 16));
                    }
                }
            }
        }

        Grid {
            id: tiles
            anchors.top: toggles.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            columns: 3
            spacing: root.spacing

            Tile {
                icon: Battery.charging ? "bolt" : "battery"
                tint: !Battery.available ? Theme.textSecondary
                    : Battery.charging ? Theme.green
                    : Battery.percent <= Settings.lowBatteryPercent ? Theme.red
                    : Theme.green
                value: Battery.available ? Battery.percent + "%" : "No battery"
                detail: Battery.available ? Battery.status : ""

                // Keep-awake toggle lives with power.
                IslandButton {
                    anchors.right: parent.right
                    anchors.rightMargin: -8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "coffee"
                    iconSize: 14
                    subtle: Caffeine.active
                    color: Caffeine.active ? Theme.yellow : Theme.textTertiary
                    onClicked: Caffeine.toggle()
                }
            }

            Tile {
                icon: Network.wifiEnabled ? "wifi" : "wifiOff"
                tint: Network.connections.length > 0 ? Theme.blue : Theme.textSecondary
                value: Network.connections.length > 0 ? Network.connections[0].name : "Offline"
                clickable: true
                onClicked: root.showWifi = true
                detail: Network.connections.length > 1 ? "+" + (Network.connections.length - 1) + " more" : "Network"
            }

            Tile {
                readonly property var first: Bluetooth.connected.length > 0 ? Bluetooth.connected[0] : null

                icon: "bluetooth"
                tint: first ? Theme.blue : Theme.textSecondary
                value: first ? (first.name || first.deviceName) : Bluetooth.enabled ? "Not connected" : "Off"
                detail: first && first.batteryAvailable ? Math.round(first.battery * 100) + "% battery"
                    : Bluetooth.connected.length > 1 ? Bluetooth.connected.length + " devices" : "Bluetooth"
            }

            Tile {
                icon: "cloud"
                tint: Theme.cyan
                value: Weather.enabled ? (Weather.temperature || "…") : "Weather"
                detail: Weather.enabled ? Weather.condition : "Not set up"
            }

            Tile {
                icon: Audio.muted ? "volumeOff" : "volume"
                tint: Theme.text
                value: Audio.muted ? "Muted" : "Volume " + Math.round(Audio.volume * 100) + "%"
                level: Audio.muted ? 0 : Audio.volume
                onLevelPicked: fraction => Audio.setVolume(fraction)
            }

            Tile {
                icon: "brightness"
                tint: Theme.yellow
                value: Brightness.available ? "Brightness " + Math.round(Brightness.level * 100) + "%" : "Brightness"
                level: Brightness.available ? Brightness.level : -1
                detail: Brightness.available ? "" : "Unavailable"
                onLevelPicked: fraction => Brightness.set(fraction)
            }
        }
    }

    // Kept alive while it fades out, then destroyed so scanning stops.
    Swappable {
        id: wifiLayer
        anchors.fill: parent
        shown: root.showWifi

        Loader {
            anchors.fill: parent
            active: root.showWifi || wifiLayer.opacity > 0.01
            sourceComponent: WifiList {
                onBack: root.showWifi = false
            }
        }
    }
}
