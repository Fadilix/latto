pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland

// The notification daemon (org.freedesktop.Notifications) and Do Not Disturb.
// New notifications pop up on the island unless Do Not Disturb is on; critical
// ones still do when dndAllowCritical is set. Every notification stays in the
// history until it is dismissed. Only one daemon can run at a time, so stop
// any other (swaync, mako, dunst) first.
QtObject {
    id: root

    // Null when notificationsEnabled is false.
    readonly property var server: serverInstance.object

    // Newest first.
    readonly property var history: server ? server.trackedNotifications.values.slice().reverse() : []
    readonly property int count: history.length

    readonly property bool doNotDisturb: stateAdapter.doNotDisturb

    // Arrival time (epoch ms) by notification id; the protocol carries none.
    property var receivedAt: ({})

    // Transient notifications (volume scripts and the like) are dropped from
    // the history once their popup time is over: [{ notification, at }].
    property var pendingExpiry: []

    function setDoNotDisturb(on) {
        if (stateAdapter.doNotDisturb === on)
            return;
        stateAdapter.doNotDisturb = on;
        Activities.show("dnd", 72, { label: on ? "Do Not Disturb on" : "Do Not Disturb off", value: -1 }, 1600);
    }

    function toggleDoNotDisturb() {
        setDoNotDisturb(!doNotDisturb);
    }

    function isCritical(notification) {
        return notification.urgency === NotificationUrgency.Critical;
    }

    // The action a click on the notification should run, if the app offered one.
    function defaultAction(notification) {
        for (const action of notification.actions) {
            if (action.identifier === "default")
                return action;
        }
        return null;
    }

    // Actions shown as buttons (everything except the click action).
    function buttonActions(notification) {
        return notification.actions.filter(action => action.identifier !== "default");
    }

    function activate(notification) {
        const action = defaultAction(notification);
        if (action)
            action.invoke();
        else
            notification.dismiss();
    }

    function clearAll() {
        for (const notification of history)
            notification.dismiss();
    }

    // Body text without markup. Markup is not advertised, but some apps send it anyway.
    function plainText(text) {
        return (text || "")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'")
            .replace(/&amp;/g, "&")
            .trim();
    }

    // "now", "5m", "2h" or "3d" since the notification arrived.
    function age(notification, now) {
        const at = receivedAt[notification.id];
        if (!at)
            return "";
        const minutes = Math.floor((now - at) / 60000);
        if (minutes < 1) return "now";
        if (minutes < 60) return minutes + "m";
        if (minutes < 1440) return Math.floor(minutes / 60) + "h";
        return Math.floor(minutes / 1440) + "d";
    }

    function popupDuration(notification) {
        if (isCritical(notification))
            return 0;    // critical stays until handled
        if (notification.expireTimeout > 0)
            return Math.max(2000, Math.min(15000, notification.expireTimeout * 1000));
        return Settings.notificationDuration;
    }

    // True when the notification comes from the app whose window is focused:
    // you are already looking at it, so a banner would only get in the way.
    // Matched on the window's app id and its desktop entry (VS Code's window
    // is "code", its notifications say "Visual Studio Code"), never on partial
    // names, so "Claude Code" doesn't match a focused VS Code.
    function fromFocusedApp(notification) {
        const focused = ToplevelManager.activeToplevel;
        return !!(focused && focused.activated) && isFromApp(notification, focused.appId);
    }

    // Whether a notification was sent by the app with this window app id.
    function isFromApp(notification, appId) {
        if (!appId)
            return false;
        const plain = text => (text || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const appNames = [plain(appId)];
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry)
            appNames.push(plain(entry.id), plain(entry.name), plain(entry.icon));

        return [notification.desktopEntry, notification.appName, notification.appIcon]
            .map(plain)
            .filter(name => name !== "")
            .some(name => appNames.includes(name));
    }

    // Window list and desktop entries load lazily; touching them starts that.
    readonly property int knownWindows: ToplevelManager.toplevels.values.length
    readonly property int knownApps: DesktopEntries.applications.values.length

    function receive(notification) {
        notification.tracked = true;

        const times = Object.assign({}, receivedAt);
        times[notification.id] = Date.now();
        receivedAt = times;

        notification.closed.connect(() => forget(notification));

        // Notifications re-sent after a config reload were already shown.
        if (notification.lastGeneration)
            return;

        if (notification.transient)
            pendingExpiry = pendingExpiry.concat([{ notification: notification, at: Date.now() + popupDuration(notification) }]);

        const muted = (doNotDisturb && !(Settings.dndAllowCritical && isCritical(notification)))
            || (Settings.quietWhenFocused && fromFocusedApp(notification));
        if (!muted) {
            Activities.show("notification", isCritical(notification) ? 95 : 65,
                { notification: notification, label: notification.summary, value: -1 },
                popupDuration(notification));
        }
    }

    function forget(notification) {
        const shown = Activities.current;
        if (shown && shown.kind === "notification" && shown.data.notification === notification)
            Activities.dismiss("notification");
        pendingExpiry = pendingExpiry.filter(entry => entry.notification !== notification);
    }

    property Instantiator serverInstance: Instantiator {
        active: Settings.notificationsEnabled

        delegate: NotificationServer {
            keepOnReload: true
            actionsSupported: true
            imageSupported: true
            persistenceSupported: true
            bodyMarkupSupported: false
            onNotification: notification => root.receive(notification)
        }
    }

    property Timer expiryTimer: Timer {
        interval: 1000
        repeat: true
        running: root.pendingExpiry.length > 0
        onTriggered: {
            const now = Date.now();
            for (const entry of root.pendingExpiry) {
                if (entry.at <= now && entry.notification)
                    entry.notification.expire();
            }
        }
    }

    // Do Not Disturb survives restarts: ~/.local/state/latto/notifications.json.
    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/latto"

    property Process mkdir: Process {
        command: ["mkdir", "-p", root.stateDirectory]
        running: true
    }

    property FileView stateFile: FileView {
        path: root.stateDirectory + "/notifications.json"
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: stateAdapter
            property bool doNotDisturb: false
        }
    }

    // Keybind hooks, e.g. in hyprland.conf:
    //   bind = SUPER, N, exec, qs -p ~/projects/android/latto ipc call notifications toggleDnd
    property IpcHandler ipc: IpcHandler {
        target: "notifications"

        function toggleDnd(): void { root.toggleDoNotDisturb(); }
        function setDnd(on: bool): void { root.setDoNotDisturb(on); }
        function isDnd(): bool { return root.doNotDisturb; }
        function clear(): void { root.clearAll(); }
        function count(): int { return root.count; }
    }
}
