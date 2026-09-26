import QtQuick
import "../../launcher"

// A small live picture of the launcher's button strip (⚙ > Buttons): the app background with one
// tile and the strip of all-apps / power buttons on the side the launcher really puts it
// (shell.powerSide), with the chosen style, size and background. While no button is switched on the
// four of them show faded, so the style and size can still be judged before turning any on.
Rectangle {
    id: prev
    property var shell

    readonly property string side: shell.powerSide // "bottom" | "top" | "left" | "right"
    readonly property bool vertical: side === "left" || side === "right"
    readonly property bool ghost: !shell.stripOn
    readonly property real gap: 6
    // the buttons at 62 % of their real size (a vertical strip is also kept inside the picture)
    // how many buttons the strip has (all four faded while none is on)
    readonly property int count: ghost ? 4 : (shell.allAppsButton ? 1 : 0) + (shell.powerOffButton ? 1 : 0) + (shell.restartButton ? 1 : 0)
                                            + (shell.logoutButton ? 1 : 0) + shell.profileButtons.length
    readonly property real btn: Math.min(shell.powerButtonSize * 0.62, vertical ? (height - 20 - (Math.max(count, 1) - 1) * gap) / Math.max(count, 1) : 99)
    readonly property real thick: btn + 12
    readonly property color desk: Qt.rgba(shell.deskRgb.r, shell.deskRgb.g, shell.deskRgb.b, 1)
    readonly property bool tileLight: shell.tileIsLight(null)

    height: 104
    radius: 0
    color: desk
    border.width: 1
    border.color: shell.mBorder
    clip: true

    Rectangle { anchors.fill: parent; color: shell.bgColor } // the launcher's own background

    Rectangle { // one tile, in the room the strip leaves
        id: tile
        x: 10 + (prev.side === "left" ? prev.thick : 0)
        y: 10 + (prev.side === "top" ? prev.thick : 0)
        width: prev.width - 20 - (prev.vertical ? prev.thick : 0)
        height: prev.height - 20 - (prev.vertical ? 0 : prev.thick)
        radius: 0
        color: shell.paint("bg", null)
        border.width: Math.min(shell.tileBorderWidth, 3)
        border.color: shell.paint("border", null)
        Row {
            anchors.centerIn: parent
            spacing: 8
            visible: !prev.ghost
            Repeater {
                model: 3
                delegate: Rectangle {
                    width: 22; height: 22; radius: 0
                    color: shell.inkColor(prev.tileLight, true)
                    opacity: 0.35
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: prev.ghost
            text: "Turn a button on to show it in the launcher"
            color: shell.inkColor(prev.tileLight, true)
            font.pixelSize: 11
        }
    }

    Grid { // the strip
        id: strip
        columns: prev.vertical ? 1 : 9
        spacing: prev.gap
        opacity: prev.ghost ? 0.3 : 1
        // centred in the band of `thick` px the strip has along its side of the picture
        x: prev.vertical ? (prev.side === "left" ? 10 : prev.width - 10 - prev.thick) + (prev.thick - width) / 2
                         : (prev.width - width) / 2
        y: prev.vertical ? (prev.height - height) / 2
                         : (prev.side === "top" ? 10 : prev.height - 10 - prev.thick) + (prev.thick - height) / 2
        Repeater {
            model: [
                { name: "all-apps", on: shell.allAppsButton },
                { name: "power-off", on: shell.powerOffButton },
                { name: "restart", on: shell.restartButton },
                { name: "logout", on: shell.logoutButton }
            ]
            delegate: Item {
                required property var modelData
                visible: prev.ghost || modelData.on
                width: prev.btn; height: prev.btn
                Rectangle { anchors.fill: parent; radius: shell.stripRadius(prev.btn); color: shell.paint("powerBg", null) }
                Image {
                    anchors.fill: parent
                    source: shell.stripIcon(parent.modelData.name)
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }
        }
        Repeater { // the profiles
            model: shell.profileButtons
            delegate: ProfileButton {
                required property string modelData
                required property int index
                shell: prev.shell
                name: modelData
                label: prev.shell.profileLabel(index)
                s: prev.btn
                preview: true
            }
        }
    }
}
