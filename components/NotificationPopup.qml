import QtQuick
import Quickshell
import "../services"
import "../theme"

// The island's notification banner. Clicking runs the app's default action,
// or opens the Notifications tab when there is none. The cross dismisses it.
// IslandWindow pauses its timer while the pointer is over it.
Item {
    id: root

    signal openRequested()

    // The queued notification, even when another alert outranks it (in
    // fullscreen only notifications show, so it can be on screen anyway).
    readonly property var shown: {
        const entry = Activities.find("notification");
        return entry ? entry.data.notification : null;
    }

    // Keep the last notification on screen while the banner fades out.
    property var notification: null
    onShownChanged: {
        if (!shown)
            return;
        // A new notification replacing one already on screen blurs in.
        if (notification && visible && notification !== shown)
            swapIn.restart();
        notification = shown;
    }

    // `blur` is animated by IslandWindow as the banner appears and leaves;
    // `swapBlur` by swapIn when one notification replaces another.
    property real blur: 0
    property real swapBlur: 0
    layer.enabled: Math.max(blur, swapBlur) > 0.01
    layer.effect: BlurEffect { amount: Math.max(root.blur, root.swapBlur) }

    NumberAnimation {
        id: swapIn
        target: root
        property: "swapBlur"
        from: Theme.swapBlur
        to: 0
        duration: Theme.swapDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.smoothCurve
    }

    readonly property bool critical: notification ? Notifications.isCritical(notification) : false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.notification)
                return;
            if (Notifications.defaultAction(root.notification))
                Notifications.activate(root.notification);
            else
                root.openRequested();
        }
    }

    NotificationIcon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: 14
        notification: root.notification
        tint: root.critical ? Theme.red : Theme.accent
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: closeButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
            width: parent.width
            text: root.notification
                ? (root.notification.appName || "Notification") + "  ·  " + Notifications.age(root.notification, clock.date.getTime())
                : ""
            color: root.critical ? Theme.red : Theme.textTertiary
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: root.notification ? root.notification.summary : ""
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: root.notification ? Notifications.plainText(root.notification.body) : ""
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall + 1
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    IslandButton {
        id: closeButton
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        opacity: hover.hovered ? 1 : 0
        icon: "close"
        iconSize: 13
        color: Theme.textSecondary
        onClicked: if (root.notification) root.notification.dismiss()
        Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
    }
}
