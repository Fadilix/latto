import QtQuick
import Quickshell
import "../../services"
import "../../theme"
import ".."

// Month grid (Monday first) beside today's date and upcoming khal events.
Item {
    id: root

    // Any date inside the month being shown.
    property date shownMonth: new Date()

    readonly property int year: shownMonth.getFullYear()
    readonly property int monthIndex: shownMonth.getMonth()
    readonly property int leadingBlanks: (new Date(year, monthIndex, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, monthIndex + 1, 0).getDate()
    readonly property var today: clock.date
    readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function shiftMonth(delta) {
        shownMonth = new Date(year, monthIndex + delta, 1);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: month
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 300

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            height: 26

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                font.pixelSize: Theme.fontBody + 1
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                IslandButton {
                    icon: "chevronLeft"
                    iconSize: 16
                    color: Theme.textSecondary
                    onClicked: root.shiftMonth(-1)
                }
                IslandButton {
                    icon: "chevronRight"
                    iconSize: 16
                    color: Theme.textSecondary
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        Grid {
            id: grid
            anchors.top: header.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7

            Repeater {
                model: root.weekdays
                Label {
                    required property string modelData
                    width: grid.width / 7
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textTertiary
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: 42

                Item {
                    id: cell

                    required property int index
                    readonly property int day: index - root.leadingBlanks + 1
                    readonly property bool inMonth: day >= 1 && day <= root.daysInMonth
                    readonly property bool isToday: inMonth
                        && day === root.today.getDate()
                        && root.monthIndex === root.today.getMonth()
                        && root.year === root.today.getFullYear()

                    width: grid.width / 7
                    height: 24

                    Rectangle {
                        anchors.centerIn: parent
                        width: 23
                        height: 23
                        radius: width / 2
                        color: Theme.accent
                        visible: cell.isToday
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.day : ""
                        color: cell.isToday ? Theme.text : (cell.index % 7 >= 5 ? Theme.textSecondary : Theme.text)
                        font.pixelSize: Theme.fontSmall
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    Card {
        anchors.left: month.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        title: "Today"

        Label {
            id: weekday
            text: Qt.formatDate(root.today, "dddd")
            color: Theme.accent
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }
        Label {
            id: dayNumber
            anchors.top: weekday.bottom
            text: Qt.formatDate(root.today, "d MMMM")
            font.pixelSize: Theme.fontTitle + 4
            font.weight: Font.DemiBold
        }

        Column {
            anchors.top: dayNumber.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            Repeater {
                model: Settings.calendarEnabled ? Calendar.events : []

                Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 14
                        radius: 1.5
                        color: Theme.accent
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 11
                        text: modelData.time + "  " + modelData.title
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                }
            }

            Label {
                width: parent.width
                visible: !Settings.calendarEnabled || Calendar.events.length === 0
                text: Settings.calendarEnabled ? "No events in the next three days"
                    : "Install khal and set calendarEnabled to see events"
                color: Theme.textTertiary
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
            }
        }
    }
}
