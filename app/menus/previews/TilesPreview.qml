import QtQuick

// A small live picture of the tiles (⚙ > Tiles): two tiles with three apps each, drawn with the
// real icon size, gap, padding, corner roundness, border width and "Show names" (at half scale) and the
// colours the launcher resolves, so every slider of the tab shows its effect at once.
Rectangle {
    id: prev
    property var shell

    readonly property real k: 0.5 // the picture's scale against the real launcher
    readonly property color desk: Qt.rgba(shell.deskRgb.r, shell.deskRgb.g, shell.deskRgb.b, 1)
    readonly property bool tileLight: shell.tileIsLight(null)
    readonly property real iconPx: shell.iconSize * k
    readonly property real gapPx: Math.min(shell.tileGap * k, 40) // the picture stays readable at a 100 px gap
    readonly property var apps: [shell.palette[6], shell.palette[0], shell.palette[3]]

    height: 128
    radius: 0
    color: desk
    border.width: 1
    border.color: shell.mBorder
    clip: true

    Rectangle { anchors.fill: parent; color: shell.bgColor } // the launcher's own background

    Row {
        anchors { fill: parent; margins: Math.max(8, prev.gapPx / 2) }
        spacing: prev.gapPx
        Repeater {
            model: 2
            delegate: Rectangle {
                width: (parent.width - prev.gapPx) / 2
                height: parent.height
                radius: Math.min(shell.tileRadius * 0.6, height / 2)
                color: shell.paint("bg", null)
                border.width: Math.max(1, shell.tileBorderWidth * 0.6)
                border.color: shell.paint("border", null)
                clip: true
                Row { // from the top left corner, as in a tile: its padding, then each icon's own
                    x: (shell.tilePadding + (shell.showLabels ? 0 : shell.cellPad)) * prev.k
                    y: (shell.tilePadTop({}) + (shell.showLabels ? 6 : shell.cellPad)) * prev.k
                    spacing: (4 + (shell.showLabels ? shell.iconSize : 2 * shell.cellPad)) * prev.k
                    Repeater {
                        model: prev.apps
                        delegate: Column {
                            required property var modelData
                            spacing: 3
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: prev.iconPx; height: prev.iconPx
                                radius: 0
                                color: parent.modelData
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: shell.showLabels
                                text: "App"
                                color: shell.inkColor(prev.tileLight, false)
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}
