import QtQuick

// A consistent, font-independent outline family for bar controls.
Item {
    id: root
    property string name: ""
    property color color: "#a1a1a6"
    property real size: 16
    implicitWidth: size
    implicitHeight: size
    readonly property var drawings: ({
        agents: '<rect x="6" y="6" width="12" height="12" rx="3"/><path d="M9 2v4m6-4v4M9 18v4m6-4v4M2 9h4m-4 6h4m12-6h4m-4 6h4"/><circle cx="10" cy="11" r=".6"/><circle cx="14" cy="11" r=".6"/><path d="M10 15h4"/>',
        grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
        bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
        moon: '<path d="M20.5 13A8.5 8.5 0 0 1 11 3.5 8.5 8.5 0 1 0 20.5 13Z"/>',
        wifi: '<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8.5 15.5a5.5 5.5 0 0 1 7 0"/><circle cx="12" cy="19" r=".8" fill="currentColor" stroke="none"/>',
        wifiOff: '<path d="m3 3 18 18M2 8a16 16 0 0 1 3-1.8M10 4.8A16 16 0 0 1 22 8M5 12a11 11 0 0 1 4-2M14 10a11 11 0 0 1 5 2M8.5 15.5a5.5 5.5 0 0 1 7 0"/><circle cx="12" cy="19" r=".8"/>',
        bluetooth: '<path d="m7 7 10 10-5 4V3l5 4L7 17"/>',
        volume: '<path d="M11 4 6 8H3v8h3l5 4ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14"/>',
        volumeOff: '<path d="M11 4 6 8H3v8h3l5 4ZM16 9l6 6m0-6-6 6"/>',
        battery: '<rect x="2" y="6" width="17" height="12" rx="3"/><path d="M22 10v4M6 10v4m4-4v4m4-4v4"/>',
        bolt: '<path d="m13 2-9 12h7l-1 8 10-13h-7Z"/>',
        coffee: '<path d="M4 8h12v9a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3ZM16 9h2a3 3 0 0 1 0 6h-2M7 2v2m4-2v2M3 23h15"/>',
        close: '<path d="m6 6 12 12M18 6 6 18"/>',
        terminal: '<rect x="2" y="4" width="20" height="16" rx="3"/><path d="m6 9 3 3-3 3m7 0h4"/>',
        folder: '<path d="M3 7V5a2 2 0 0 1 2-2h5l3 3h6a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
        settings: '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',
        globe: '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
        mic: '<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3m-4 0h8"/>',
        refresh: '<path d="M20 7V2m0 5h-5M4 17v5m0-5h5M20 7a9 9 0 0 0-16 2m0 8a9 9 0 0 0 16-2"/>',
        barChart: '<path d="M5 20v-6m7 6V4m7 16V9"/>',
        lock: '<rect x="4" y="10" width="16" height="12" rx="3"/><path d="M8 10V6a4 4 0 0 1 8 0v4"/>'
    })
    Image {
        anchors.fill: parent
        sourceSize.width: Math.ceil(root.size * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(root.size * Screen.devicePixelRatio)
        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" color="' + root.color + '" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + (root.drawings[root.name] || root.drawings.settings) + '</svg>')
    }
}
