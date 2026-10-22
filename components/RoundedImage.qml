import QtQuick
import QtQuick.Effects
import "../theme"

// Image clipped to a rounded rectangle, with a music-note placeholder until it loads.
Item {
    id: root

    property alias source: image.source
    property real radius: 8

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surfaceRaised
        visible: image.status !== Image.Ready

        Icon {
            anchors.centerIn: parent
            name: "music"
            size: Math.min(parent.width, parent.height) * 0.45
            color: Theme.textTertiary
        }
    }

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        visible: false
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: image.status === Image.Ready
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
}
