import QtQuick
import QtQuick.Shapes
import "../theme"

// A small rotating arc on a faint ring, for work in progress.
Item {
    id: root

    property real size: 16
    property color color: Theme.accent
    property bool running: true

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.22)
            strokeWidth: 2
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.size / 2 - 1.5
                radiusY: root.size / 2 - 1.5
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.size / 2 - 1.5
                radiusY: root.size / 2 - 1.5
                startAngle: -90
                sweepAngle: 110
            }
        }
    }

    RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.running && root.visible
    }
}
