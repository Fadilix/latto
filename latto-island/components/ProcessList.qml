import QtQuick
import "../services"
import "../theme"

// Apps ranked by memory use ("memory") or current CPU use ("cpu"), each with
// its share of the machine. Shown by the Stats tab when the Memory or CPU card
// is clicked; sampling runs only while shown.
Item {
    id: root

    signal back()

    property string kind: "memory"
    readonly property bool isCpu: kind === "cpu"
    readonly property var apps: isCpu ? Processes.byCpu : Processes.byMemory
    readonly property real totalKib: SystemStats.memoryTotalGiB * 1048576
    readonly property color tint: isCpu ? Theme.accent : Theme.green

    // 0..1 of the machine: of all CPU time, or of total RAM.
    function shareOf(app) {
        if (isCpu)
            return app.percent / 100;
        return totalKib > 0 ? app.kib / totalKib : 0;
    }

    function amountOf(app) {
        return isCpu ? app.percent.toFixed(1) + "%" : formatKib(app.kib);
    }

    function formatKib(kib) {
        if (kib >= 1048576) return (kib / 1048576).toFixed(1) + " GiB";
        if (kib >= 1024) return Math.round(kib / 1024) + " MiB";
        return kib + " KiB";
    }

    // The ranking this view keeps sampling. Moves along if `kind` changes.
    property string watching: ""

    function rewatch() {
        if (watching !== "")
            Processes.unwatch(watching);
        watching = kind;
        Processes.watch(kind);
    }

    Component.onCompleted: rewatch()
    onKindChanged: if (watching !== "") rewatch()
    Component.onDestruction: if (watching !== "") Processes.unwatch(watching)

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 28

        IslandButton {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevronLeft"
            iconSize: 16
            color: Theme.textSecondary
            onClicked: root.back()
        }
        Label {
            anchors.left: backButton.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.isCpu ? "CPU" : "Memory"
            font.pixelSize: Theme.fontBody + 1
            font.weight: Font.DemiBold
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.isCpu
                ? Math.round(SystemStats.cpu) + "% in use" + (SystemStats.temperature > 0 ? "  ·  " + Math.round(SystemStats.temperature) + "°C" : "")
                : SystemStats.memoryUsedGiB.toFixed(1) + " / " + SystemStats.memoryTotalGiB.toFixed(1) + " GiB used"
            color: Theme.textTertiary
            font.pixelSize: Theme.fontSmall
            font.weight: Font.Medium
        }
    }

    Label {
        anchors.centerIn: list
        visible: root.apps.length === 0
        text: root.isCpu ? "Measuring…" : "Reading processes…"
        color: Theme.textTertiary
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.apps

        delegate: Item {
            id: row

            required property var modelData
            required property int index
            readonly property real share: root.shareOf(modelData)

            width: ListView.view.width
            height: 30

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rowHover.hovered ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            }
            HoverHandler {
                id: rowHover
            }

            // App icon, or its initial when the icon theme has none.
            Item {
                id: iconBox
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: row.modelData.icon
                    sourceSize.width: 40
                    sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: source != "" && status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !appIcon.visible
                    radius: 6
                    color: Theme.surfaceRaised

                    Label {
                        anchors.centerIn: parent
                        text: row.modelData.name.charAt(0).toUpperCase()
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontCaption + 1
                        font.weight: Font.DemiBold
                    }
                }
            }

            Label {
                id: nameLabel
                anchors.left: iconBox.right
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 3
                width: Math.min(implicitWidth, parent.width - 230)
                text: row.modelData.name
                font.pixelSize: Theme.fontSmall + 1
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Label {
                anchors.left: nameLabel.right
                anchors.leftMargin: 6
                anchors.verticalCenter: nameLabel.verticalCenter
                visible: row.modelData.count > 1
                text: "×" + row.modelData.count
                color: Theme.textTertiary
                font.pixelSize: Theme.fontCaption
            }

            // Share of the machine.
            IslandBar {
                anchors.left: nameLabel.left
                anchors.right: sizeLabel.left
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                implicitHeight: 3
                value: row.share
                fillColor: row.share > 0.25 ? Theme.orange : root.tint
            }

            Label {
                id: sizeLabel
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                horizontalAlignment: Text.AlignRight
                text: root.amountOf(row.modelData)
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        // Apps moving up or down the ranking slide into place.
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
    }
}
