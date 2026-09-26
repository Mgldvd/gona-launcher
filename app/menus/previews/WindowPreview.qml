import QtQuick

// A small live picture of where the launcher opens (⚙ > Window): a mini screen with the launcher
// drawn where it will sit (a centred window, a panel on an edge with its size and offset, or the whole
// screen), and the numbers that go with it on the right.
Rectangle {
    id: prev
    property var shell

    readonly property string edge: shell.edge
    readonly property bool docked: edge !== "" && edge !== "full"
    readonly property real sw: shell.targetScreen ? shell.targetScreen.width : 1920
    readonly property real sh: shell.targetScreen ? shell.targetScreen.height : 1080
    readonly property real mh: height - 20
    readonly property real mw: mh * sw / sh
    readonly property real k: mw / sw
    readonly property color desk: Qt.rgba(shell.deskRgb.r, shell.deskRgb.g, shell.deskRgb.b, 1)
    readonly property var modeNames: ({ "": "Centered window", top: "Top panel", bottom: "Bottom panel",
                                        left: "Left panel", right: "Right panel", full: "Full screen" })
    readonly property var facts: [
        { k: "Mode", v: modeNames[edge] || "" },
        { k: "Size", v: edge === "full" ? "The whole screen"
                       : (docked ? shell.panelW + " × " + shell.panelH + " % of the screen" : shell.winW + " × " + shell.winH + " px") },
        { k: "Edge offset", v: docked ? shell.offset + " px" : "—" },
        { k: "Opens with", v: shell.fxOn ? shell.effect.charAt(0).toUpperCase() + shell.effect.slice(1) + ", " + shell.effectMs + " ms"
                            : (edge === "full" ? "Fade, " + shell.slideSpeed + " ms" : (docked ? "Slide in, " + shell.slideSpeed + " ms" : "Instantly")) }
    ]

    height: 132
    radius: 0
    color: shell.mField

    Rectangle { // the screen
        id: screen
        x: 10; y: 10
        width: prev.mw; height: prev.mh
        radius: 0
        color: prev.desk
        border.width: 1
        border.color: shell.mBorder
        clip: true

        Rectangle { // the launcher
            readonly property real w: prev.edge === "full" ? screen.width
                : (prev.docked ? screen.width * shell.panelW / 100 : Math.min(shell.winW, prev.sw) * prev.k)
            readonly property real h: prev.edge === "full" ? screen.height
                : (prev.docked ? screen.height * shell.panelH / 100 : Math.min(shell.winH, prev.sh) * prev.k)
            readonly property real off: shell.offset * prev.k
            width: w; height: h
            x: prev.edge === "left" ? off : (prev.edge === "right" ? screen.width - w - off : (screen.width - w) / 2)
            y: prev.edge === "top" ? off : (prev.edge === "bottom" ? screen.height - h - off : (screen.height - h) / 2)
            radius: 0
            color: shell.solidBg
            border.width: 1
            border.color: shell.accent
            Grid {
                anchors { fill: parent; margins: 4 }
                columns: 2
                spacing: 2
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        width: (parent.width - 2) / 2; height: (parent.height - 2) / 2
                        radius: 0
                        color: shell.paint("bg", null)
                        border.width: 1
                        border.color: shell.paint("border", null)
                    }
                }
            }
        }
    }

    Column { // the numbers
        anchors { left: screen.right; leftMargin: 18; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 6
        Repeater {
            model: prev.facts
            delegate: Row {
                required property var modelData
                spacing: 8
                Text { width: 84; text: parent.modelData.k; color: shell.mDim; font.pixelSize: 12 }
                Text { text: parent.modelData.v; color: shell.mFg; font.pixelSize: 12 }
            }
        }
    }
}
