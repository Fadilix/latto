import QtQuick
import "../theme"

// Line graph of a history array with a soft gradient fill underneath.
// Values are scaled to `maximum`, or to the largest value when it is 0.
Canvas {
    id: root

    property var values: []
    property real maximum: 0
    property color lineColor: Theme.text

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (values.length < 2)
            return;

        let top = maximum;
        if (top <= 0) {
            top = 1;
            for (const value of values)
                top = Math.max(top, value);
        }

        const pointAt = i => ({
            x: i / (values.length - 1) * width,
            y: height - 1 - Math.min(1, values[i] / top) * (height - 2)
        });

        ctx.beginPath();
        for (let i = 0; i < values.length; i++) {
            const point = pointAt(i);
            if (i === 0)
                ctx.moveTo(point.x, point.y);
            else
                ctx.lineTo(point.x, point.y);
        }

        // Stroke the line, then close the same path along the bottom to fill it.
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        ctx.stroke();

        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        const gradient = ctx.createLinearGradient(0, 0, 0, height);
        gradient.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.32));
        gradient.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0));
        ctx.fillStyle = gradient;
        ctx.fill();
    }
}
