import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../latto-island/components" as Latto
import "../../latto-island/theme"

PopupWindow {
    id: popup
    required property var hostWindow
    required property var anchorItem
    property bool network: false
    property bool audio: false
    property bool bluetooth: false
    property bool agents: false
    property string title: "Actions"
    property var actions: []
    signal dismissed()
    anchor.window: hostWindow
    readonly property point buttonPosition: anchorItem.mapToItem(hostWindow.contentItem, 0, anchorItem.height)
    anchor.rect.x: Math.max(8, Math.min(hostWindow.width - implicitWidth - 8, buttonPosition.x + anchorItem.width - implicitWidth))
    anchor.rect.y: buttonPosition.y + 8
    implicitWidth: agents ? 430 : network || bluetooth ? 380 : audio ? 300 : 246
    implicitHeight: agents ? Math.min(hostWindow.screen.height - 70, agentsLoader.item ? agentsLoader.item.implicitHeight + 28 : 178) : network || bluetooth ? Math.min(410, hostWindow.screen.height - 70) : audio ? audioLoader.item ? audioLoader.item.implicitHeight + 28 : 250 : menuColumn.implicitHeight + 24
    color: "transparent"
    visible: true
    // PopupWindow's xdg-popup backend owns keyboard input, independently of
    // the island's password hold and hover state.
    HyprlandFocusGrab {
        windows: [popup]
        active: popup.visible
        onCleared: popup.dismissed()
    }
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 16
        color: "#101013"
        border.color: Theme.border
        border.width: 1
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: popup.dismissed()
        opacity: 0
        transform: Translate { id: rise; y: -6 }
        ParallelAnimation {
            running: true
            NumberAnimation { target: surface; property: "opacity"; to: 1; duration: 140 }
            NumberAnimation { target: rise; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: 14
            active: popup.network
            sourceComponent: Component {
                Latto.WifiList {
                    manageIslandHold: false
                    onBack: popup.dismissed()
                }
            }
        }
        Loader {
            id: audioLoader
            anchors.fill: parent
            anchors.margins: 14
            active: popup.audio
            sourceComponent: Component { VolumePanel {} }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: 14
            active: popup.bluetooth
            sourceComponent: Component { BluetoothPanel {} }
        }
        Loader {
            id: agentsLoader
            anchors.fill: parent
            anchors.margins: 14
            active: popup.agents
            sourceComponent: Component { AgentsPanel {} }
        }
        Column {
            id: menuColumn
            visible: !popup.network && !popup.audio && !popup.bluetooth && !popup.agents
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 3
            Text {
                text: popup.title
                color: Theme.textTertiary
                font.family: Theme.fontFamily
                font.pixelSize: 10
                height: 25
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
            }
            Repeater {
                model: popup.actions
                delegate: Rectangle {
                    id: actionRow
                    required property var modelData
                    width: menuColumn.width
                    height: 34
                    radius: 8
                    color: pointer.containsMouse ? Theme.surfaceRaised : "transparent"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        spacing: 10
                        BarIcon {
                            name: actionRow.modelData.icon || "settings"
                            color: Theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: actionRow.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const action = actionRow.modelData.run;
                            popup.dismissed();
                            action();
                        }
                    }
                }
            }
        }
    }
}
