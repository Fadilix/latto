import QtQuick

// Filled area outside a quarter circle: tangent to the horizontal bar at
// the outer edge and tangent to the notch's vertical wall at the inner edge.
Canvas {
    id: root
    property color surfaceColor: "#08080a"
    width: 28
    height: 28
    antialiasing: true
    onSurfaceColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = surfaceColor;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(width, 0);
        ctx.lineTo(width, height);
        // Exact quarter circle with its center at the outer bottom corner.
        ctx.bezierCurveTo(width, height * 0.447715, width * 0.552285, 0, 0, 0);
        ctx.closePath();
        ctx.fill();
    }
}
