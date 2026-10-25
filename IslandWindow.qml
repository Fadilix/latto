import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "services"
import "components"
import "theme"

// One island per monitor, anchored top-centre. The window spans the full width
// so the pill can grow, while the input mask limits the pointer to the pill.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    // Optional host surface. Standalone Latto keeps its original geometry;
    // a shell can supply a bar without duplicating the island or its services.
    property Component barComponent: null
    property color barColor: "#08080a"
    readonly property bool integrated: barComponent !== null
    readonly property real centerWidth: pill.width
    readonly property int hostTopMargin: integrated ? 0 : Theme.topMargin
    readonly property int hostCompactHeight: integrated ? 32 : Theme.compactHeight
    readonly property int hostNotificationWidth: integrated ? 320 : Theme.notificationWidth

    anchors {
        top: true
        left: true
        right: true
    }
    // Room for the expanded pill plus its shadow.
    implicitHeight: hostTopMargin + Theme.expandedHeight + 48
    exclusiveZone: integrated && !fullscreen ? hostCompactHeight : 0
    // The keyboard only while a field is being typed into (a Wi-Fi password);
    // Hyprland won't hand an "on demand" overlay the keyboard, so it is taken
    // exclusively for that moment and given straight back.
    WlrLayershell.keyboardFocus: IslandState.heldOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    WlrLayershell.namespace: "latto-island"
    WlrLayershell.layer: WlrLayer.Overlay
    // While hidden the island takes no input, so clicks reach the fullscreen app.
    mask: Region {
        item: window.mode === "hidden" ? null : pill
        Region { item: barLoader.visible ? barLoader : null }
        Region { item: leftShoulder.visible ? leftShoulder : null }
        Region { item: rightShoulder.visible ? rightShoulder : null }
    }

    Loader {
        id: barLoader
        anchors.top: parent.top
        anchors.topMargin: window.hostTopMargin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        height: window.hostCompactHeight
        visible: window.integrated && !window.fullscreen
        sourceComponent: window.barComponent
    }

    // `open` follows the pointer with a short delay each way: brushing past
    // does not open the island, and leaving it always closes it.
    property bool open: false

    // A fullscreen window on this monitor hides the island; only notifications
    // bring it back, growing out of a dot and shrinking back into one.
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: Settings.hideInFullscreen === true
        && !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)

    readonly property bool expanded: open
    readonly property string mode: {
        if (expanded)
            return "expanded";
        // In fullscreen only notifications come through.
        if (fullscreen)
            return Activities.find("notification") ? "notification" : "hidden";
        if (Activities.current)
            return modeFor(Activities.current.kind);
        return Settings.mediaAlwaysShown === true && Media.playing ? "media" : "idle";
    }

    // The notification banner takes the pointer: hovering it pauses it
    // instead of opening the island, so it can be clicked.
    readonly property bool bannerMode: mode === "notification"

    function modeFor(kind) {
        if (kind === "notification") return "notification";
        if (kind === "nowPlaying") return "media";
        if (kind === "claude") return "claude";
        return "alert";
    }



    Timer {
        id: openTimer
        interval: Theme.hoverOpenDelay
        onTriggered: window.open = true
    }

    // When a view lets go, close if the pointer has already left. Opening on
    // request (keybind, script) stays open until the pointer passes over the
    // island and leaves, or a close request arrives.
    Connections {
        target: IslandState
        function onHeldOpenChanged() {
            if (!IslandState.heldOpen && !hover.hovered)
                closeTimer.restart();
        }
        function onOpenRequested(tab) {
            if (tab !== "")
                expandedView.selectTab(tab);
            openTimer.stop();
            closeTimer.stop();
            window.open = true;
        }
        function onCloseRequested() {
            openTimer.stop();
            closeTimer.stop();
            window.open = false;
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.hoverCloseDelay
        // A view typing into a field keeps the island open; see IslandState.
        onTriggered: if (!IslandState.heldOpen) window.open = false
    }

    Connections {
        target: hyprMonitor ?? null
        ignoreUnknownSignals: true
        function onActiveWorkspaceChanged() {
            const ws = hyprMonitor ? hyprMonitor.activeWorkspace : null;
            if (!ws) return;
            const label = ws.name && ws.name !== String(ws.id) ? ws.name : String(ws.id);
            Activities.show("workspace", 30, { label: label, value: -1 }, Settings.hudDuration);
        }
    }

    // Concave shoulders join the growing notch to the bar's bottom edge.
    // Follow the animated pill geometry so opening, closing and banners all
    // share one continuous silhouette, including interrupted transitions.
    NotchShoulder {
        id: leftShoulder
        readonly property real growth: Math.max(0, Math.min(1,
            (pill.height - window.hostCompactHeight) / 40))
        width: 16 * growth
        height: width
        x: pill.x - width + 0.5
        y: window.hostCompactHeight - 0.5
        surfaceColor: window.barColor
        visible: window.integrated && !window.fullscreen && growth > 0
        opacity: pill.opacity
    }
    NotchShoulder {
        id: rightShoulder
        width: leftShoulder.width
        height: width
        x: pill.x + pill.width - 0.5
        y: leftShoulder.y
        surfaceColor: window.barColor
        visible: leftShoulder.visible
        opacity: pill.opacity
        transform: Scale { origin.x: rightShoulder.width / 2; xScale: -1 }
    }

    RectangularShadow {
        anchors.fill: pill
        radius: pill.radius
        blur: window.expanded ? 36 : 14
        offset.y: window.expanded ? 12 : 3
        color: Qt.rgba(0, 0, 0, window.expanded ? 0.55 : 0.35)
        opacity: window.integrated && !window.fullscreen ? 0 : pill.opacity
        scale: pill.scale
        transformOrigin: Item.Top

        Behavior on blur { NumberAnimation { duration: Theme.expandDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve } }
    }

    Rectangle {
        id: pill

        anchors.top: parent.top
        anchors.topMargin: window.hostTopMargin
        anchors.horizontalCenter: parent.horizontalCenter
        transformOrigin: Item.Top

        width: window.integrated ? 156 : Theme.idleWidth
        height: window.hostCompactHeight
        radius: window.hostCompactHeight / 2
        // The top remains attached to the bar throughout the spring morph.
        topLeftRadius: window.integrated && !window.fullscreen ? 0 : radius
        topRightRadius: window.integrated && !window.fullscreen ? 0 : radius
        color: window.integrated ? window.barColor : Theme.island
        border.color: Theme.border
        border.width: window.integrated && !window.fullscreen ? 0 : 1
        clip: true

        // 1 while shown; 0 shrinks the dot to nothing as the island hides.
        property real reveal: 1
        // A quick squeeze when the collapsed pill is pressed.
        property real pressScale: !window.integrated && tap.pressed && !window.expanded ? 0.95 : 1
        Behavior on pressScale {
            NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }

        opacity: reveal
        scale: pressScale * (0.3 + 0.7 * reveal)

        state: window.mode
        states: [
            State {
                name: "hidden"
                PropertyChanges {
                    target: pill
                    width: Theme.dotSize
                    height: Theme.dotSize
                    radius: Theme.dotSize / 2
                    reveal: 0
                }
                PropertyChanges { target: compact; opacity: 0; scale: 0.92; blur: Theme.hiddenBlur }
            },
            State {
                name: "idle"
                PropertyChanges { target: pill; width: window.integrated ? 156 : Theme.idleWidth }
            },
            State {
                name: "media"
                PropertyChanges { target: pill; width: Theme.activityWidth }
            },
            State {
                name: "alert"
                PropertyChanges { target: pill; width: Theme.activityWidth }
            },
            State {
                name: "claude"
                PropertyChanges { target: pill; width: Theme.activityWidth }
            },

            State {
                name: "notification"
                PropertyChanges {
                    target: pill
                    width: window.hostNotificationWidth
                    height: Theme.notificationHeight
                    radius: Theme.notificationRadius
                }
                PropertyChanges { target: compact; opacity: 0; scale: 0.92; blur: Theme.hiddenBlur }
                PropertyChanges { target: popup; opacity: 1; scale: 1; blur: 0 }
            },
            State {
                name: "expanded"
                PropertyChanges {
                    target: pill
                    width: Theme.expandedWidth
                    height: Theme.expandedHeight
                    radius: Theme.expandedRadius
                }
                PropertyChanges { target: compact; opacity: 0; scale: 1.08; blur: Theme.hiddenBlur }
                PropertyChanges { target: expandedView; opacity: 1; scale: 1; blur: 0 }
            }
        ]

        transitions: [
            // Into hiding: the content leaves, the island flattens and draws in
            // to a dot, and the dot fades away.
            Transition {
                to: "hidden"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation {
                            targets: [compact, popup, expandedView]
                            properties: "opacity,scale,blur"
                            duration: 160
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.exitCurve
                        }
                        NumberAnimation {
                            target: pill
                            properties: "height,radius"
                            duration: 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.smoothCurve
                        }
                    }
                    NumberAnimation {
                        target: pill
                        property: "width"
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.smoothCurve
                    }
                    NumberAnimation {
                        target: pill
                        property: "reveal"
                        duration: 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                }
            },
            // Out of hiding: a dot pops in, stretches into a pill, then grows
            // to full size while its content sharpens in.
            Transition {
                from: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: pill
                        property: "reveal"
                        duration: 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.springCurve
                    }
                    PauseAnimation { duration: 70 }
                    NumberAnimation {
                        target: pill
                        property: "width"
                        duration: 440
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.springCurve
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: pill
                            properties: "height,radius"
                            duration: 440
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.springCurve
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 120 }
                            NumberAnimation {
                                targets: [compact, popup, expandedView]
                                properties: "opacity,scale,blur"
                                duration: 340
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.smoothCurve
                            }
                        }
                    }
                }
            },
            // Open: the pill springs out, the compact row fades away first and
            // the expanded content blooms in once the pill has some room.
            Transition {
                from: "idle,media,alert,notification,claude"
                to: "expanded"
                ParallelAnimation {
                    NumberAnimation {
                        target: pill
                        properties: "width,height,radius"
                        duration: Theme.expandDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.springCurve
                    }
                    NumberAnimation {
                        targets: [compact, popup]
                        properties: "opacity,scale,blur"
                        duration: 160
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 110 }
                        NumberAnimation {
                            target: expandedView
                            properties: "opacity,scale,blur"
                            duration: 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.smoothCurve
                        }
                    }
                }
            },
            // Close: content leaves quickly, then the pill settles back.
            Transition {
                from: "expanded"
                to: "idle,media,alert,notification,claude"
                ParallelAnimation {
                    NumberAnimation {
                        target: pill
                        properties: "width,height,radius"
                        duration: Theme.collapseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.settleCurve
                    }
                    NumberAnimation {
                        target: expandedView
                        properties: "opacity,scale,blur"
                        duration: 140
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 170 }
                        NumberAnimation {
                            targets: [compact, popup]
                            properties: "opacity,scale,blur"
                            duration: 280
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.smoothCurve
                        }
                    }
                }
            },
            // Between collapsed modes (idle, media, alert, notification): a
            // springy morph while the compact row and the banner cross-fade.
            Transition {
                ParallelAnimation {
                    NumberAnimation {
                        target: pill
                        properties: "width,height,radius"
                        duration: Theme.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.springCurve
                    }
                    NumberAnimation {
                        targets: [compact, popup]
                        properties: "opacity,scale,blur"
                        duration: 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.smoothCurve
                    }
                }
            }
        ]

        HoverHandler {
            id: hover
            onHoveredChanged: {
                // Over a notification banner the pointer pauses it instead of
                // opening the island, so the banner can be clicked.
                if (window.bannerMode) {
                    Activities.hold("notification", hovered);
                    if (hovered)
                        return;
                }
                if (hovered) {
                    closeTimer.stop();
                    if (Settings.hoverToExpand)
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    closeTimer.restart();
                }
            }
        }

        // Clicking opens the island (needed when hoverToExpand is off). It does
        // not pin it: leaving with the pointer still closes it.
        TapHandler {
            id: tap
            onTapped: {
                openTimer.stop();
                window.open = true;
            }
        }

        CompactView {
            id: compact
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: window.hostCompactHeight
            transformOrigin: Item.Top
            mode: window.mode
            visible: opacity > 0
            enabled: !window.expanded
        }


        NotificationPopup {
            id: popup
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: window.hostNotificationWidth
            height: Theme.notificationHeight
            transformOrigin: Item.Top
            opacity: 0
            scale: 0.92
            blur: Theme.hiddenBlur
            visible: opacity > 0
            enabled: window.mode === "notification"
            onOpenRequested: {
                Activities.dismiss("notification");
                expandedView.selectTab("notifications");
                window.open = true;
            }
        }

        // Fixed-size content, revealed by the growing pill instead of being
        // squeezed by it.
        ExpandedView {
            id: expandedView
            anchors.top: parent.top
            anchors.topMargin: Theme.padding
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.expandedWidth - 2 * Theme.padding
            height: Theme.expandedHeight - 2 * Theme.padding
            transformOrigin: Item.Top
            opacity: 0
            scale: 0.92
            blur: Theme.hiddenBlur
            visible: opacity > 0
            enabled: window.expanded
        }
    }
}
