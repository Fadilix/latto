import QtQuick
import "../../services"
import "../../theme"
import ".."

// Now playing: artwork, title and live lyrics, a seek bar and transport controls.
Item {
    id: root

    readonly property bool hasPlayer: Media.player !== null
    readonly property string nextLyric: Lyrics.currentIndex + 1 < Lyrics.lines.length
        ? Lyrics.lines[Lyrics.currentIndex + 1].text : ""

    // Empty state
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !root.hasPlayer

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "music"
            size: 30
            color: Theme.textTertiary
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            color: Theme.textSecondary
            font.weight: Font.Medium
        }
    }

    Item {
        anchors.fill: parent
        visible: root.hasPlayer

        RoundedImage {
            id: art
            width: 96
            height: 96
            radius: 16
            source: Media.art
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.top: art.top
            anchors.topMargin: 4
            spacing: 3

            Label {
                width: parent.width
                text: Media.title
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: Media.artist || Media.source
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall + 1
                elide: Text.ElideRight
            }
            Item {
                width: 1
                height: 8
            }
            Label {
                id: lyric
                width: parent.width
                visible: Settings.showLyrics && text !== ""
                text: Lyrics.currentText
                color: Theme.accent
                font.pixelSize: Theme.fontBody
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight

                // Each new line blurs and fades in.
                property real blur: 0
                layer.enabled: blur > 0.01
                layer.effect: BlurEffect { amount: lyric.blur }

                onTextChanged: lyricIn.restart()
                ParallelAnimation {
                    id: lyricIn
                    NumberAnimation {
                        target: lyric
                        property: "opacity"
                        from: 0.2
                        to: 1
                        duration: 320
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.smoothCurve
                    }
                    NumberAnimation {
                        target: lyric
                        property: "blur"
                        from: Theme.swapBlur
                        to: 0
                        duration: Theme.swapDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.smoothCurve
                    }
                }
            }
            Label {
                width: parent.width
                visible: lyric.visible && text !== ""
                text: root.nextLyric
                color: Theme.textTertiary
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }

        Item {
            id: progressRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: art.bottom
            anchors.topMargin: 14
            height: 16

            Label {
                id: elapsed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                text: Timers.formatTime(Media.position * 1000, false)
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption + 1
            }
            Label {
                id: remaining
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: Media.length > 0 ? "-" + Timers.formatTime((Media.length - Media.position) * 1000, false) : ""
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption + 1
            }
            IslandBar {
                anchors.left: elapsed.right
                anchors.right: remaining.left
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: seekArea.containsMouse ? 8 : 5
                value: Media.progress
            }
            MouseArea {
                id: seekArea
                anchors.left: elapsed.right
                anchors.right: remaining.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => Media.seek(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        Media.seek(mouse.x / width);
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: progressRow.bottom
            anchors.bottom: parent.bottom

            IslandButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.shuffleSupported
                icon: "shuffle"
                iconSize: 16
                color: Media.shuffle ? Theme.accent : Theme.textSecondary
                onClicked: Media.toggleShuffle()
            }

            Row {
                anchors.centerIn: parent
                spacing: 14

                IslandButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "previous"
                    iconSize: 22
                    onClicked: Media.previous()
                }
                IslandButton {
                    anchors.verticalCenter: parent.verticalCenter
                    primary: true
                    icon: Media.playing ? "pause" : "play"
                    iconSize: 22
                    onClicked: Media.toggle()
                }
                IslandButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "next"
                    iconSize: 22
                    onClicked: Media.next()
                }
            }

            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 110
                horizontalAlignment: Text.AlignRight
                text: Media.source
                color: Theme.textTertiary
                font.pixelSize: Theme.fontCaption + 1
                elide: Text.ElideRight
            }
        }
    }
}
