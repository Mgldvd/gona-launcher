import QtQuick

// One profile in the button strip (next to the all-apps and power buttons): a square, circle or plain
// box, by the chosen button style, holding its label (1 / A / I ...); the profile in use is filled with
// the accent. Hovering shows the profile's name beside it, on the side that faces the tiles. Clicking
// switches to it. `preview` draws it without reacting (⚙ > Buttons).
Item {
    id: pb
    property var shell
    property string name: ""      // "" = the default profile
    property string label: ""
    property real s: 34
    property bool preview: false
    readonly property bool selected: shell.activeProfile === name
    readonly property string title: name === "" ? "default" : name
    readonly property color accent: shell.accent
    readonly property bool accentLight: 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b > 0.5

    width: s; height: s
    z: hover.hovered ? 100 : 0

    Rectangle {
        anchors.fill: parent
        radius: pb.shell.stripRadius(width)
        color: pb.selected ? pb.accent : shell.popupBg
        border.width: 1.5
        border.color: pb.selected || hover.hovered ? pb.accent : shell.border
        opacity: hover.hovered && !pb.selected ? 1 : 0.92
    }
    Text {
        anchors.centerIn: parent
        text: pb.label
        font.pixelSize: Math.max(9, pb.s * (pb.label.length > 2 ? 0.3 : 0.42))
        font.bold: true
        color: pb.selected ? shell.inkColor(pb.accentLight, false) : shell.fg
    }
    HoverHandler { id: hover; enabled: !pb.preview }
    MouseArea {
        anchors.fill: parent
        enabled: !pb.preview
        onClicked: pb.shell.switchProfile(pb.name)
    }
    Rectangle { // the name
        id: tip
        visible: hover.hovered && !pb.preview
        readonly property string side: pb.shell.powerSide // where the strip is: the name goes toward the tiles
        x: side === "left" ? pb.width + 6 : (side === "right" ? -width - 6 : (pb.width - width) / 2)
        y: side === "bottom" ? -height - 6 : (side === "top" ? pb.height + 6 : (pb.height - height) / 2)
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: pb.shell.corner
        color: pb.shell.popupBg
        border.width: 1
        border.color: pb.shell.accent
        Text { id: tipText; anchors.centerIn: parent; text: pb.title; color: pb.shell.fg; font.pixelSize: 12 }
    }
}
