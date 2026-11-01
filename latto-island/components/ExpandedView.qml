import QtQuick
import "../services"
import "../theme"

// Expanded island: a segmented tab bar with a sliding highlight, over one
// page per enabled tab. Pages blur, fade and rise in when they change.
Item {
    id: root

    // Animated by IslandWindow: blurred while closed, sharp once open.
    property real blur: 0
    layer.enabled: blur > 0.01
    layer.effect: BlurEffect { amount: root.blur }

    // Tab definitions: icon, name (for screen readers) and the page file in
    // components/tabs.
    readonly property var tabs: ({
        media: { icon: "music", label: "Media", file: "MediaTab.qml" },
        notifications: { icon: "bell", label: "Notifications", file: "NotificationsTab.qml" },
        stats: { icon: "barChart", label: "Stats", file: "StatsTab.qml" },
        timers: { icon: "timer", label: "Timers", file: "TimersTab.qml" },
        clipboard: { icon: "clipboard", label: "Clipboard", file: "ClipboardTab.qml" },
        calendar: { icon: "calendar", label: "Calendar", file: "CalendarTab.qml" },
        overview: { icon: "grid", label: "Overview", file: "OverviewTab.qml" }
    })

    readonly property var enabledTabs: Settings.tabs.filter(name => tabs[name] !== undefined)

    property string requestedTab: ""
    readonly property string activeTab: enabledTabs.includes(requestedTab) ? requestedTab : (enabledTabs[0] || "")
    readonly property int activeIndex: enabledTabs.indexOf(activeTab)

    function selectTab(name) {
        requestedTab = name;
    }

    Item {
        id: tabBar
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: tabRow.width + 8
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }

        Rectangle {
            id: highlight

            readonly property Item target: tabRepeater.count > root.activeIndex && root.activeIndex >= 0
                ? tabRepeater.itemAt(root.activeIndex) : null

            x: target ? tabRow.x + target.x : 4
            y: 4
            width: target ? target.width : 0
            height: parent.height - 8
            radius: height / 2
            color: Theme.surfaceRaised

            Behavior on x {
                NumberAnimation { duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
            }
            Behavior on width {
                NumberAnimation { duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
            }
        }

        Row {
            id: tabRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: tabRepeater
                model: root.enabledTabs

                IslandTab {
                    required property string modelData
                    icon: root.tabs[modelData].icon
                    text: root.tabs[modelData].label
                    selected: modelData === root.activeTab
                    onActivated: root.requestedTab = modelData
                }
            }
        }
    }

    Loader {
        id: page
        anchors.top: tabBar.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        source: root.activeTab !== "" ? "tabs/" + root.tabs[root.activeTab].file : ""
        transform: Translate { id: pageShift }
        onLoaded: pageIn.restart()

        property real blur: 0
        layer.enabled: blur > 0.01
        layer.effect: BlurEffect { amount: page.blur }
    }

    ParallelAnimation {
        id: pageIn
        NumberAnimation {
            target: page
            property: "blur"
            from: Theme.swapBlur
            to: 0
            duration: Theme.swapDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.smoothCurve
        }
        NumberAnimation {
            target: page.item
            property: "opacity"
            from: 0
            to: 1
            duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.smoothCurve
        }
        NumberAnimation {
            target: pageShift
            property: "y"
            from: 10
            to: 0
            duration: 460
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.springCurve
        }
    }
}
