import QtQuick
import Quickshell
import "../theme"

// A notification's artwork, in order of preference:
//   - the image it carries (avatar, album art), filling the tile
//   - an app icon given as an image file (e.g. Claude's app tile), filling the tile
//   - a themed app icon name, drawn small on a tinted tile
//   - a bell
Item {
    id: root

    property var notification: null
    property real radius: 12
    property color tint: Theme.accent

    readonly property string appIcon: notification && notification.appIcon ? notification.appIcon : ""
    readonly property bool appIconIsFile: appIcon.startsWith("/") || appIcon.includes("://")

    readonly property string imageSource: notification && notification.image ? notification.image
        : appIconIsFile ? appIcon
        : ""
    readonly property string iconSource: appIcon === "" || appIconIsFile ? "" : Quickshell.iconPath(appIcon, true)

    RoundedImage {
        anchors.fill: parent
        visible: root.imageSource !== ""
        radius: root.radius
        source: root.imageSource
    }

    Rectangle {
        anchors.fill: parent
        visible: root.imageSource === ""
        radius: root.radius
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.16)

        Image {
            id: appImage
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: width
            visible: root.iconSource !== "" && status === Image.Ready
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Icon {
            anchors.centerIn: parent
            visible: !appImage.visible
            name: "bell"
            size: parent.width * 0.5
            color: root.tint
        }
    }
}
