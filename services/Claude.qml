pragma Singleton

import QtQuick
import Quickshell.Io

// Claude Code sessions, for the island's live activity. Claude Code hooks
// (integrations/claude-code/latto-activity.sh) report each session's progress:
//
//   qs -p <latto> ipc call claude update <session> <state> <project> <detail> <at> <turnStart> <tokens>
//   qs -p <latto> ipc call claude prompt <session> <project> <at>
//
// with state "working", "input" (waiting for permission or a reply), "done"
// (finished its turn) or "end" (session closed), and `at` the time the hook
// fired, in epoch milliseconds. turnStart (when the turn's prompt was sent)
// and tokens (output tokens since) come from Claude Code's transcript, so the
// clock matches Claude Code's even if latto restarted mid-turn; 0 if unknown.
//
// The hooks run asynchronously, so events can arrive out of order (a tool's
// "back to thinking" landing after "done"). Each session therefore keeps the
// time of the last event applied, ignores anything older, and a finished
// session is remembered for a while so late events can't bring it back.
QtObject {
    id: root

    // [{ id, project, state, detail, startedAt, updatedAt, tokens }]
    property var sessions: []
    // Session id -> time it finished, to drop events that arrive after.
    property var finishedAt: ({})

    // The session to show: one waiting for input first, else the most recent.
    readonly property var current: {
        let best = null;
        for (const session of sessions) {
            if (session.state === "input")
                return session;
            if (!best || session.updatedAt > best.updatedAt)
                best = session;
        }
        return best;
    }

    readonly property int count: sessions.length

    // Claude Code's style: "14s", "2m 10s", "1h 5m".
    function elapsedText(ms) {
        const seconds = Math.max(0, Math.floor(ms / 1000));
        if (seconds < 60) return seconds + "s";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return minutes + "m " + (seconds % 60) + "s";
        return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
    }

    // "↓ 9.3k", or "" before any output.
    function tokensText(tokens) {
        if (!(tokens > 0)) return "";
        return "\u2193 " + (tokens >= 1000 ? (tokens / 1000).toFixed(1).replace(/\.0$/, "") + "k" : tokens);
    }

    // `at` is when the hook fired; without one (an older hook) it is now.
    function update(id, state, project, detail, at, turnStart, tokens) {
        if (!id)
            return;
        const time = Number(at) > 0 ? Number(at) : Date.now();
        const existing = sessions.find(session => session.id === id);

        // Stale: older than what was already applied, or from a finished turn.
        if (existing && time < existing.updatedAt)
            return;
        if (!existing && finishedAt[id] && time <= finishedAt[id])
            return;

        if (state === "done" || state === "end") {
            const finished = Object.assign({}, finishedAt);
            finished[id] = time;
            finishedAt = finished;
            sessions = sessions.filter(session => session.id !== id);
            return;
        }

        const entry = {
            id: id,
            project: project || (existing ? existing.project : ""),
            state: state,
            detail: detail,
            // From the transcript when known; otherwise the clock runs from
            // the first event seen, and a new prompt restarts it.
            startedAt: Number(turnStart) > 0 ? Number(turnStart) : existing ? existing.startedAt : time,
            updatedAt: time,
            tokens: Number(tokens) > 0 ? Number(tokens) : existing ? existing.tokens : 0
        };
        sessions = sessions.filter(session => session.id !== id).concat([entry]);
    }

    // A new task: the clock starts at the prompt, as Claude Code's does.
    function prompt(id, project, at) {
        const time = Number(at) > 0 ? Number(at) : Date.now();
        update(id, "working", project, "Thinking", time, time, 0);
        sessions = sessions.map(session => session.id === id
            ? Object.assign({}, session, { startedAt: time, tokens: 0 })
            : session);
    }

    // The session and state last put on the island, e.g. "abc:input".
    property string shownKey: ""

    // Keep the island's activity queue in step with the shown session. Work
    // stays up while it runs; "needs input" shows for a while when Claude
    // starts waiting, then gets out of the way. Repeated wait signals don't
    // bring it back; only a new wait (after more work) does.
    onCurrentChanged: {
        if (!current || !Settings.claudeActivity) {
            Activities.dismiss("claude");
            shownKey = "";
            return;
        }
        const key = current.id + ":" + current.state;
        if (current.state === "input") {
            if (key !== shownKey)
                Activities.show("claude", 66, { label: current.project, value: -1 }, Settings.claudeInputDuration);
        } else {
            Activities.show("claude", 45, { label: current.project, value: -1 }, 0);
        }
        shownKey = key;
    }

    property IpcHandler ipc: IpcHandler {
        target: "claude"

        function update(session: string, state: string, project: string, detail: string, at: string, turnStart: string, tokens: string): void {
            root.update(session, state, project, detail, at, turnStart, tokens);
        }
        function prompt(session: string, project: string, at: string): void {
            root.prompt(session, project, at);
        }
        function clear(): void {
            root.sessions = [];
        }
        // What the island shows, e.g. "latto | working | Editing Foo.qml | 2 sessions".
        function status(): string {
            const s = root.current;
            if (!s)
                return "idle";
            return [s.project, s.state, s.detail, root.elapsedText(Date.now() - s.startedAt), root.tokensText(s.tokens),
                root.count + (root.count === 1 ? " session" : " sessions")].join(" | ");
        }
    }

    // A session that crashed or was killed never says "end"; drop it after
    // half an hour without news.
    property Timer staleTimer: Timer {
        interval: 60000
        repeat: true
        running: root.sessions.length > 0 || Object.keys(root.finishedAt).length > 0
        onTriggered: {
            const cutoff = Date.now() - 30 * 60000;
            const alive = root.sessions.filter(session => session.updatedAt > cutoff);
            if (alive.length !== root.sessions.length)
                root.sessions = alive;

            // Late events arrive within seconds; forget finished turns after ten minutes.
            const recent = {};
            for (const id in root.finishedAt) {
                if (root.finishedAt[id] > Date.now() - 10 * 60000)
                    recent[id] = root.finishedAt[id];
            }
            root.finishedAt = recent;
        }
    }
}
