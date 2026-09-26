import QtQuick

// A hover tooltip for one row of a menu: it fills its parent, waits 450 ms of hovering, then shows
// `text` in a bubble just under the row. The row should raise its own `z` while `showing`, so the
// bubble paints over the rows below it.
Item {
    id: tip
    property var shell
    property string text: ""
    readonly property bool showing: bubble.visible
    anchors.fill: parent
    z: 5

    HoverHandler { id: hov }
    Timer { interval: 450; running: hov.hovered && tip.text !== ""; onTriggered: bubble.visible = true }
    Connections { target: hov; function onHoveredChanged() { if (!hov.hovered) bubble.visible = false; } }

    Rectangle {
        id: bubble
        visible: false
        y: tip.height + 2
        width: tip.width
        height: bubbleText.implicitHeight + 16
        radius: 0
        color: tip.shell.mPopup
        border.width: 1
        border.color: tip.shell.mDim
        Text {
            id: bubbleText
            anchors { fill: parent; margins: 8 }
            text: tip.text
            wrapMode: Text.WordWrap
            color: tip.shell.mFg
            font.pixelSize: 12
        }
    }
}
