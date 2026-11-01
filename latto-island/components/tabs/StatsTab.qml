import QtQuick
import "../../services"
import "../../theme"
import ".."

// System metrics, each with a value, a detail line and a short history graph.
// Clicking the CPU or Memory card swaps the grid for the apps using the most
// of it.
Item {
    id: root

    // "" for the grid, or the ranking shown: "cpu" or "memory".
    property string ranking: ""
    // The ranking last shown, kept while the list fades out.
    property string lastRanking: "memory"
    onRankingChanged: if (ranking !== "") lastRanking = ranking

    readonly property real spacing: 10
    readonly property real cellWidth: (width - spacing) / 2
    readonly property real cellHeight: (height - spacing) / 2


    function formatRate(bytes) {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024) return (bytes / 1024).toFixed(0) + " KB/s";
        return Math.round(bytes) + " B/s";
    }

    // A metric card: value and detail on the left, graph or bar on the right.
    component Metric: Card {
        id: metric

        property string value: ""
        property string detail: ""
        property color tint: Theme.accent
        property var history: []
        property real maximum: 0
        property real level: -1     // shows a bar instead of a graph when >= 0
        property bool clickable: false
        signal clicked()

        width: root.cellWidth
        height: root.cellHeight
        color: clickable && metricHover.hovered ? Theme.surfaceRaised : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }

        HoverHandler {
            id: metricHover
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            enabled: metric.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: metric.clicked()
        }

        Label {
            id: valueLabel
            text: metric.value
            font.pixelSize: Theme.fontTitle + 4
            font.weight: Font.DemiBold
        }
        Label {
            anchors.top: valueLabel.bottom
            anchors.topMargin: 1
            width: parent.width / 2
            text: metric.detail
            color: Theme.textSecondary
            font.pixelSize: Theme.fontCaption + 1
            elide: Text.ElideRight
        }
        Sparkline {
            visible: metric.level < 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.48
            values: metric.history
            maximum: metric.maximum
            lineColor: metric.tint
        }
        IslandBar {
            visible: metric.level >= 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.48
            implicitHeight: 8
            value: metric.level
            fillColor: metric.tint
        }
    }

    Swappable {
        anchors.fill: parent
        shown: root.ranking === ""

        Grid {
            anchors.fill: parent
            columns: 2
            spacing: root.spacing

            Metric {
                title: "CPU  \u203A"
                clickable: true
                onClicked: root.ranking = "cpu"
                value: Math.round(SystemStats.cpu) + "%"
                detail: SystemStats.temperature > 0 ? Math.round(SystemStats.temperature) + "°C" : ""
                tint: Theme.accent
                history: SystemStats.cpuHistory
                maximum: 100
            }

            Metric {
                title: "Memory  \u203A"
                clickable: true
                onClicked: root.ranking = "memory"
                value: Math.round(SystemStats.memory) + "%"
                detail: SystemStats.memoryUsedGiB.toFixed(1) + " / " + SystemStats.memoryTotalGiB.toFixed(1) + " GiB"
                tint: Theme.green
                history: SystemStats.memoryHistory
                maximum: 100
            }

            Metric {
                title: "Network"
                value: "↓ " + root.formatRate(SystemStats.downRate)
                detail: "↑ " + root.formatRate(SystemStats.upRate)
                tint: Theme.cyan
                history: SystemStats.downHistory
            }

            Metric {
                title: "Disk"
                value: Math.round(SystemStats.disk) + "%"
                detail: SystemStats.diskUsedGiB.toFixed(0) + " / " + SystemStats.diskTotalGiB.toFixed(0) + " GiB"
                tint: Theme.orange
                level: SystemStats.disk / 100
            }
        }
    }

    // Kept alive while it fades out, then destroyed so sampling stops.
    Swappable {
        id: processLayer
        anchors.fill: parent
        shown: root.ranking !== ""

        Loader {
            anchors.fill: parent
            active: root.ranking !== "" || processLayer.opacity > 0.01
            sourceComponent: ProcessList {
                kind: root.lastRanking
                onBack: root.ranking = ""
            }
        }
    }
}
