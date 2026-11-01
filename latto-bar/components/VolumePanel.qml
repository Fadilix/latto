import QtQuick
import QtQuick.Controls
import Quickshell
import "../../latto-island/services"
import "../../latto-island/theme"

Column {
    id: root
    spacing: 12
    Row {
        width: parent.width
        spacing: 8
        BarIcon {
            name: "volume"
            color: Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            width: parent.width - 24
            text: "Volume"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
    Text {
        width: parent.width
        text: Audio.sink ? (Audio.sink.description || Audio.sink.name || "Audio output") : "No output device"
        elide: Text.ElideRight
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    Row {
        width: parent.width
        spacing: 12
        Slider {
            id: volumeSlider
            width: parent.width - 48
            height: 26
            enabled: !!(Audio.sink && Audio.sink.audio)
            from: 0
            to: 1
            value: Audio.volume
            onMoved: Audio.setVolume(value)
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: (volumeSlider.height - height) / 2
                width: volumeSlider.availableWidth
                height: 5
                radius: 2.5
                color: Theme.surfaceRaised
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Audio.muted ? Theme.textTertiary : Theme.accent
                }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: (volumeSlider.height - height) / 2
                width: 13
                height: 13
                radius: 6.5
                color: volumeSlider.pressed ? Theme.accent : Theme.text
            }
        }
        Text {
            width: 36
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Audio.volume * 100) + "%"
            horizontalAlignment: Text.AlignRight
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.textSecondary
        }
    }
    BarButton {
        width: parent.width
        icon: Audio.muted ? "volumeOff" : "volume"
        text: Audio.muted ? "Unmute output" : "Mute output"
        active: Audio.muted
        enabled: !!(Audio.sink && Audio.sink.audio)
        onClicked: Audio.toggleMute()
    }
    BarButton {
        width: parent.width
        visible: Audio.hasMicrophone
        icon: "mic"
        text: Audio.microphoneMuted ? "Unmute microphone" : "Mute microphone"
        active: Audio.microphoneMuted
        onClicked: Audio.toggleMicrophone()
    }
    BarButton {
        width: parent.width
        icon: "settings"
        text: "Sound settings"
        onClicked: Quickshell.execDetached(["pavucontrol"])
    }
}
