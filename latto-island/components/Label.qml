import QtQuick
import "../theme"

// Text in the island's font and palette. Used in place of Text everywhere.
Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
}
