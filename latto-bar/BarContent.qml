import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import "../latto-island/services"
import "../latto-island/theme"
import "components"

Rectangle {
    id: root
    property var monitor
    property var panelWindow
    property real centerWidth: 340
    signal openTab(string tab)
    color: panelWindow ? panelWindow.barColor : "#08080a"
    radius: 0
    border.width: 0
    border.color: Theme.border
    // Both wings stay outside Latto's animated footprint. Optional labels
    // disappear first on smaller screens; controls remain available in Latto.
    readonly property real wingWidth: Math.max(0, (width - centerWidth - 24) / 2)
    readonly property bool roomy: wingWidth > 430

    property string popupKind: ""
    property var popupAnchor: null
    property string menuTitle: ""
    property var menuActions: []

    function dismissPopup() { popupKind = ""; }
    function showControl(kind, button) {
        if (popupKind === kind && popupAnchor === button) {
            dismissPopup();
            return;
        }
        IslandState.closeRequested();
        popupAnchor = button;
        popupKind = kind;
    }
    function showWifi(button) { showControl("network", button); }
    function showAudio(button) { showControl("audio", button); }
    function showActions(button, title, actions) {
        dismissPopup();
        IslandState.closeRequested();
        popupAnchor = button;
        menuTitle = title;
        menuActions = actions;
        popupKind = "actions";
    }
    function launch(command) { Quickshell.execDetached(command); }
    function script(relative) {
        launch(["bash", Quickshell.env("HOME") + "/.config/hypr/" + relative]);
    }
    Connections {
        target: root.panelWindow
        function onFullscreenChanged() { root.dismissPopup(); }
        function onOpenChanged() { if (root.panelWindow.open) root.dismissPopup(); }
    }
    Loader {
        active: root.popupKind !== "" && !!root.panelWindow
        sourceComponent: Component {
            BarPopover {
                hostWindow: root.panelWindow
                anchorItem: root.popupAnchor
                network: root.popupKind === "network"
                audio: root.popupKind === "audio"
                bluetooth: root.popupKind === "bluetooth"
                agents: root.popupKind === "agents"
                title: root.menuTitle
                actions: root.menuActions
                onDismissed: root.dismissPopup()
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.leftMargin: 6
        height: parent.height
        width: root.wingWidth
        clip: true
        Row {
            id: leftRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Rectangle {
                width: workspaces.width + 8
                height: 28
                radius: 9
                color: "#111114"
                Row {
                    id: workspaces
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: Hyprland.workspaces
                        delegate: BarButton {
                            required property var modelData
                            visible: modelData.id > 0 && (!root.monitor || modelData.monitor === root.monitor)
                            readonly property bool selected: root.monitor && root.monitor.activeWorkspace === modelData
                            implicitWidth: selected ? 32 : 25
                            text: modelData.name
                            tint: selected ? Theme.text : Theme.textTertiary
                            active: selected
                            tooltip: "Workspace " + modelData.name
                            onClicked: Hyprland.dispatch("workspace " + modelData.name)
                            onScrolled: delta => Hyprland.dispatch("workspace " + (delta > 0 ? "m-1" : "m+1"))
                            Behavior on implicitWidth { NumberAnimation { duration: 180 } }
                        }
                    }
                }
            }
            BarButton {
                id: caffeineButton
                icon: "coffee"
                active: Caffeine.active
                tint: Caffeine.active ? Theme.accent : Theme.textTertiary
                tooltip: Caffeine.active ? "Keep awake · on" : "Keep awake · off"
                onClicked: Caffeine.toggle()
                onSecondaryClicked: root.showActions(caffeineButton, "Keep awake", [
                    {label: Caffeine.active ? "Allow sleep" : "Keep awake", icon: "coffee", run: () => Caffeine.toggle()},
                    {label: "Lock screen", icon: "lock", run: () => root.launch(["hyprlock"])}
                ])
            }
            BarButton {
                id: agentsButton
                readonly property int waiting: Claude.sessions.filter(session => session.state === "input").length
                icon: "agents"
                text: Claude.count > 0 ? String(Claude.count) : ""
                tint: waiting > 0 ? Theme.orange : Claude.count > 0 ? Theme.accent : Theme.textTertiary
                active: root.popupKind === "agents"
                tooltip: "Agent activity · " + Claude.count + " active" + (waiting > 0 ? " · " + waiting + " need input" : "")
                onClicked: root.showControl("agents", agentsButton)
            }
        }

    }

    Item {
        anchors.right: parent.right
        anchors.rightMargin: 6
        height: parent.height
        width: root.wingWidth
        clip: true
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
                visible: root.roomy
                spacing: 2
                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        // Network is handled by the bar's dedicated Wi-Fi
                        // control; don't duplicate NetworkManager's applet.
                        visible: !/nm-applet|nm-tray|networkmanager|network manager/i.test(
                            (modelData.id || "") + " " + (modelData.title || ""))
                        width: visible ? 28 : 0
                        height: 28
                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: trayItem.modelData.icon
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                const pos = trayItem.mapToItem(root, 0, trayItem.height);
                                if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu)
                                    trayItem.modelData.display(root.panelWindow, pos.x, pos.y);
                                else if (mouse.button === Qt.MiddleButton)
                                    trayItem.modelData.secondaryActivate();
                                else trayItem.modelData.activate();
                            }
                            onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                        }
                    }
                }
            }
            BarButton {
                id: notificationsButton
                icon: Notifications.doNotDisturb ? "moon" : "bell"
                text: Notifications.count > 0 ? String(Notifications.count) : ""
                tooltip: "Notifications · right click for actions"
                onClicked: root.openTab("notifications")
                onSecondaryClicked: root.showActions(notificationsButton, "Notifications", [
                    {label: Notifications.doNotDisturb ? "Disable Do Not Disturb" : "Do Not Disturb", icon: "moon", run: () => Notifications.toggleDoNotDisturb()},
                    {label: "Clear notifications", icon: "close", run: () => Notifications.clearAll()}
                ])
            }
            BarButton {
                id: networkButton
                visible: root.wingWidth > 260
                icon: Network.connections.length > 0 ? "wifi" : "wifiOff"
                tooltip: Network.connections.map(c => c.name).join(", ") || "Disconnected"
                active: root.popupKind === "network"
                onClicked: root.showWifi(networkButton)
                onSecondaryClicked: root.showActions(networkButton, "Network", [
                    {label: "Wi-Fi networks", icon: "wifi", run: () => root.showWifi(networkButton)},
                    {label: Network.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on", icon: "wifiOff", run: () => Network.toggleWifi()},
                    {label: "Connection settings", icon: "settings", run: () => root.launch(["kitty", "nmtui"])}
                ])
            }
            BarButton {
                id: bluetoothButton
                visible: root.roomy && Bluetooth.available
                icon: "bluetooth"
                tint: Bluetooth.enabled ? Theme.textSecondary : Theme.textTertiary
                tooltip: "Bluetooth · right click for actions"
                active: root.popupKind === "bluetooth"
                onClicked: root.showControl("bluetooth", bluetoothButton)
                onSecondaryClicked: root.showActions(bluetoothButton, "Bluetooth", [
                    {label: Bluetooth.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on", icon: "bluetooth", run: () => Bluetooth.toggle()},
                    {label: "Manage devices", icon: "settings", run: () => root.launch(["blueman-manager"])}
                ])
            }
            BarButton {
                id: audioButton
                icon: Audio.muted ? "volumeOff" : "volume"
                text: root.roomy ? Math.round(Audio.volume * 100) + "%" : ""
                tooltip: "Volume · scroll to adjust · right click for actions"
                active: root.popupKind === "audio"
                onClicked: root.showAudio(audioButton)
                onSecondaryClicked: root.showActions(audioButton, "Audio", [
                    {label: Audio.muted ? "Unmute output" : "Mute output", icon: "volumeOff", run: () => Audio.toggleMute()},
                    {label: Audio.microphoneMuted ? "Unmute microphone" : "Mute microphone", icon: "mic", run: () => Audio.toggleMicrophone()},
                    {label: "Output settings", icon: "settings", run: () => root.launch(["pavucontrol", "-t", "3"])},
                    {label: "Input settings", icon: "mic", run: () => root.launch(["pavucontrol", "-t", "4"])}
                ])
                onScrolled: delta => Audio.setVolume(Audio.volume + (delta > 0 ? 0.05 : -0.05))
            }
            BarButton {
                id: batteryButton
                visible: Battery.available
                icon: Battery.charging ? "bolt" : "battery"
                text: Battery.percent + "%"
                tint: Battery.percent <= 15 && !Battery.charging ? Theme.red : Battery.charging ? Theme.green : Theme.textSecondary
                tooltip: Battery.status
                interactive: false

            }

        }
    }
}
