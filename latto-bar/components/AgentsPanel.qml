import QtQuick
import "../../latto-island/services"
import "../../latto-island/theme"
import "../../latto-island/components" as Latto

Item {
    id: root
    property var sessions: Claude.sessions
    readonly property var ordered: sessions.slice().sort((a, b) =>
        (a.state === "input" ? 0 : 1) - (b.state === "input" ? 0 : 1) || b.updatedAt - a.updatedAt)
    readonly property int waiting: sessions.filter(session => session.state === "input").length
    property real now: Date.now()
    implicitHeight: Math.max(150, 62 + sessions.length * 94)
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }
    function agentName(session) { return session.agent || "Claude"; }
    function projectName(session) {
        const prefix = agentName(session) + " · ";
        return (session.project || "").startsWith(prefix)
            ? session.project.slice(prefix.length) : session.project || "Untitled project";
    }
    function shortId(session) {
        let id = session.id || "";
        if (id.startsWith("agent:")) {
            try { id = JSON.parse(id.slice(6))[1]; } catch (error) {}
        }
        return String(id).slice(-6);
    }
    Column {
        id: heading
        width: parent.width
        spacing: 6
        Text {
            text: "Agent activity"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            text: root.sessions.length === 0 ? "Your active sessions, in one place"
                : (root.sessions.length - root.waiting) + " working" + (root.waiting ? "  ·  " + root.waiting + " need your input" : "")
            color: root.waiting ? Theme.orange : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
    ListView {
        id: list
        anchors.top: heading.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 8
        model: root.ordered
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property bool waiting: modelData.state === "input"
            readonly property color tint: Theme.agentColor(root.agentName(modelData))
            width: list.width
            height: 86
            radius: 12
            color: "#19191d"
            border.width: waiting ? 1 : 0
            border.color: Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.3)
            Rectangle {
                x: 12; y: 14
                width: 28; height: 28; radius: 9
                color: Qt.rgba(card.tint.r, card.tint.g, card.tint.b, 0.13)
                Latto.Spinner {
                    anchors.centerIn: parent
                    size: 14
                    color: card.tint
                    running: !card.waiting && root.visible
                    visible: !card.waiting
                }
                Text {
                    anchors.centerIn: parent
                    visible: card.waiting
                    text: "!"
                    color: Theme.orange
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }
            Text {
                id: elapsed
                anchors.top: parent.top
                anchors.topMargin: 15
                anchors.right: parent.right
                anchors.rightMargin: 12
                text: Claude.elapsedText(root.now - card.modelData.startedAt)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            Text {
                x: 50; y: 12
                width: Math.max(0, elapsed.x - x - 12)
                text: root.agentName(card.modelData) + " · " + root.projectName(card.modelData)
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                x: 50; y: 33
                width: parent.width - x - 12
                text: card.waiting ? "Needs your input" : card.modelData.detail || "Working"
                elide: Text.ElideRight
                color: card.waiting ? Theme.orange : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            Text {
                x: 50; y: 60
                width: parent.width - x - 12
                text: ["#" + root.shortId(card.modelData),
                    Claude.tokensText(card.modelData.tokens),
                    "updated " + Claude.elapsedText(root.now - card.modelData.updatedAt) + " ago"].filter(part => part !== "").join("  ·  ")
                elide: Text.ElideRight
                color: Theme.textTertiary
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
        add: Transition {
            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 160 }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
        }
    }
    Text {
        anchors.centerIn: list
        visible: root.sessions.length === 0
        text: "No agents running"
        color: Theme.textTertiary
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
