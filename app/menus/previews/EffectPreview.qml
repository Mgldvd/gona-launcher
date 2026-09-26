import QtQuick
import "../../lib/fx.js" as Fx
import "../../launcher"

// The live preview at the top of ⚙ > Effects: a mini screen with the launcher where it will open (same
// placement as WindowPreview) that plays the chosen effect on a loop -- opens, rests, closes -- through the very
// same FxLayer and shader the real launcher uses, coming out of a small "bar button" at the top of the screen
// (the terminal effects play in place and ignore it).
// "Classic" plays what a panel, full screen and a centred window do by default (slide, fade, nothing). The name
// and a line about the effect are on the right.
Rectangle {
    id: prev
    property var shell

    readonly property string effect: shell.effect
    readonly property string edge: shell.edge
    readonly property bool docked: edge !== "" && edge !== "full"
    readonly property real sw: shell.targetScreen ? shell.targetScreen.width : 1920
    readonly property real sh: shell.targetScreen ? shell.targetScreen.height : 1080
    readonly property real mh: height - 20
    readonly property real mw: mh * sw / sh
    readonly property real k: mw / sw
    readonly property color desk: Qt.rgba(shell.deskRgb.r, shell.deskRgb.g, shell.deskRgb.b, 1)
    readonly property var info: ({
        classic: { name: "Classic", text: "A panel slides in from its edge, Full screen fades, and a centered window appears at once." },
        fade: { name: "Fade", text: "Comes up out of nothing with a slight zoom." },
        slide: { name: "Slide", text: "Slides in from beyond the edge of the screen: a panel from its own edge, anything else from the side below." },
        meet: { name: "Meet", text: "Two halves come in from opposite sides and join in the middle." },
        corners: { name: "Corners", text: "Four quarters come in diagonally from the corners of the launcher." },
        blocks: { name: "Blocks", text: "A grid of blocks pops in, the bottom row first, each dropping and growing as it lands." },
        fluid: { name: "Fluid", text: "Grows out of a point like a drop of liquid, rippling, and settles with a soft spring." },
        bounce: { name: "Bounce", text: "Pops up on a springy bounce: stretched as it rises, squashed as it lands." },
        genie: { name: "Genie", text: "Poured out of the bar button through a funnel, like a magic lamp, and sucked back in on close." },
        dissolve: { name: "Dissolve", text: "Burns in along a glowing, ragged edge from where it starts, and burns away when it closes." },
        glitch: { name: "Glitch", text: "Tearing bands, split colours and dropped blocks that settle into the picture." },
        matrix: { name: "Matrix", text: "Columns of falling glyphs, bright at the head, leave the launcher showing through their trail." },
        decrypt: { name: "Decrypt", text: "Every cell starts as scrambled glyphs and resolves into the picture with a flash, in random order." },
        synthgrid: { name: "Synthgrid", text: "A neon grid grows from the middle, its cells fill in with the picture, and the grid fades away." },
        spotlights: { name: "Spotlights", text: "Four lights search the launcher, lighting what they cross, then converge on the middle and grow." },
        laser: { name: "Laser etch", text: "A laser etches the launcher row by row, back and forth, leaving it glowing and cooling; sparks fly." },
        blackhole: { name: "Blackhole", text: "A black hole opens in the middle and the launcher bursts out of it, spiralling outwards in blocks." },
        fireworks: { name: "Fireworks", text: "Rockets climb and burst in sparks; the cells around each burst light up and drop into place." },
        rain: { name: "Rain", text: "Every cell falls from the top as a thin streak and lands in its place with a splash." },
        beams: { name: "Beams", text: "A light runs along every row and column of the grid, showing each cell as it passes." },
        vhs: { name: "VHS tape", text: "An old tape settling: wobbling lines, a rolling tracking band, colour bleed and snow." }
    })
    // how long one opening takes here: what is set, but never so short that the preview cannot be followed
    readonly property int ms: Math.max(320, shell.wantedMs)
    property real t: 0            // the slide of the preview, like the launcher's own
    property bool opening: true

    height: 156
    radius: 0
    color: shell.mField
    clip: true

    Rectangle { // the screen
        id: screen
        x: 10; y: 10
        width: prev.mw; height: prev.mh
        radius: 0
        color: prev.desk
        border.width: 1
        border.color: shell.mBorder
        clip: true

        Rectangle { // the bar, with the button the launcher opens from
            width: parent.width; height: Math.max(5, 36 * prev.k)
            color: shell.mFg
            opacity: 0.08
        }
        Rectangle {
            id: button
            readonly property real cx: screen.width * 0.7
            readonly property real cy: Math.max(5, 36 * prev.k) / 2
            x: cx - width / 2; y: cy - height / 2
            width: 4; height: 4; radius: 0
            color: shell.mDim
        }

        Rectangle { // the launcher
            id: mini
            readonly property real w: prev.edge === "full" ? screen.width
                : (prev.docked ? screen.width * shell.panelW / 100 : Math.min(shell.winW, prev.sw) * prev.k)
            readonly property real h: prev.edge === "full" ? screen.height
                : (prev.docked ? screen.height * shell.panelH / 100 : Math.min(shell.winH, prev.sh) * prev.k)
            readonly property real off: shell.offset * prev.k
            readonly property real homeX: prev.edge === "left" ? off : (prev.edge === "right" ? screen.width - w - off : (screen.width - w) / 2)
            readonly property real homeY: prev.edge === "top" ? off : (prev.edge === "bottom" ? screen.height - h - off : (screen.height - h) / 2)
            // the classic modes, when the shader effects are off
            readonly property string from: shell.fxOn || prev.edge === "full" ? "" : prev.edge
            width: w; height: h
            x: homeX + (from === "left" ? -(1 - prev.t) * (w + off) : (from === "right" ? (1 - prev.t) * (w + off) : 0))
            y: homeY + (from === "top" ? -(1 - prev.t) * (h + off) : (from === "bottom" ? (1 - prev.t) * (h + off) : 0))
            opacity: !shell.fxOn && prev.edge === "full" ? prev.t : 1
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

        FxLayer {
            id: fx
            anchors.fill: parent
            effect: shell.fxOn ? prev.effect : ""
            t: prev.t
            opening: prev.opening
            target: mini
            srcRect: Qt.rect(mini.homeX, mini.homeY, mini.width, mini.height)
            edge: prev.edge
            from: shell.fullFrom
            anchor: ({ x: button.cx, y: button.cy })
        }
    }

    // opens, rests, closes, rests, again; only while this tab is showing. A centred window in Classic does not
    // animate: it just stays there.
    readonly property bool still: !shell.fxOn && prev.edge === ""
    SequentialAnimation {
        running: prev.visible && !prev.still
        loops: Animation.Infinite
        ScriptAction { script: { prev.opening = true; fx.snap(); } }
        NumberAnimation { target: prev; property: "t"; from: 0; to: 1; duration: prev.ms }
        PauseAnimation { duration: 1200 }
        ScriptAction { script: { prev.opening = false; fx.snap(); } }
        NumberAnimation { target: prev; property: "t"; from: 1; to: 0; duration: prev.ms }
        PauseAnimation { duration: 650 }
    }
    onStillChanged: { if (still) t = 1; }
    Component.onCompleted: { if (still) t = 1; }

    Column { // the name and what it does
        anchors { left: screen.right; leftMargin: 18; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 6
        Text {
            text: (prev.info[prev.effect] || prev.info.classic).name
            color: shell.mFg
            font.pixelSize: 15
            font.bold: true
        }
        Text {
            width: parent.width
            text: (prev.info[prev.effect] || prev.info.classic).text
            color: shell.mDim
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: prev.effect === "classic" ? (prev.edge === "" ? "Instant" : shell.slideSpeed + " ms")
                : shell.effectMs + " ms · " + (Fx.fromPoint(prev.effect) ? "from the bar button, else its edge or the centre"
                : (Fx.hasSide(prev.effect) ? "from the " + (prev.effect === "slide" && prev.docked ? prev.edge : shell.fullFrom) : "plays in place"))
            color: shell.mDim
            font.pixelSize: 12
        }
    }
}
