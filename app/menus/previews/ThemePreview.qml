import QtQuick

// A small live picture of the launcher in the look in use (⚙ > Colors): the app background with
// two tiles on it, each with three apps, one of them selected. It is drawn from the very same
// colours the real launcher resolves (shell.paint / pick / inkColor), so any change in this tab —
// the accent, the border, the tile or app background, their opacity, or switching Dark / Light —
// shows here at once, on top of what would really be behind a see-through launcher.
Rectangle {
    id: prev
    property var shell

    readonly property color desk: Qt.rgba(shell.deskRgb.r, shell.deskRgb.g, shell.deskRgb.b, 1)
    readonly property bool tileLight: shell.tileIsLight(null)
    readonly property color ink: shell.inkColor(tileLight, false)
    readonly property color inkDim: shell.inkColor(tileLight, true)
    readonly property var sample: [
        { name: "Files", c: shell.palette[6] },
        { name: "Music", c: shell.palette[0] },
        { name: "Notes", c: shell.palette[3] }
    ]

    height: 104
    radius: 0
    color: desk
    border.width: 1
    border.color: shell.mBorder
    clip: true

    Rectangle { // the launcher's own background, over the desktop
        anchors.fill: parent
        color: shell.bgColor
    }

    Row {
        anchors { fill: parent; margins: 10 }
        spacing: 8
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                width: (prev.width - 20 - 8) / 2
                height: parent.height
                radius: Math.min(shell.tileRadius * 0.6, height / 2) // the tiles' own roundness
                color: shell.paint("bg", null)
                border.width: Math.min(shell.tileBorderWidth, 3)
                border.color: shell.paint("border", null)

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: prev.sample
                        delegate: Rectangle {
                            id: cellBox
                            required property int index
                            required property var modelData
                            readonly property bool selected: index === 1
                            width: 46; height: 52
                            radius: shell.corner * 0.6 // the selection rounds with the tiles
                            color: selected ? shell.accentSoft : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: shell.accent
                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 24; height: 24; radius: 0
                                    color: cellBox.modelData.c
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cellBox.modelData.name
                                    color: cellBox.selected ? prev.ink : prev.inkDim
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
