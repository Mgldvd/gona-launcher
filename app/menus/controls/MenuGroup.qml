import QtQuick

// A bordered card of the tile menu: a small uppercase heading followed by its rows, so related
// settings read as one group instead of a flat list. Groups sit on the pages of the tabs.
Rectangle {
    id: sec
    property var shell
    property real fullWidth: 300
    property string label: ""
    default property alias content: inner.children
    width: fullWidth
    height: inner.height + 28
    radius: 0
    color: "transparent"
    border.width: 1
    border.color: sec.shell.mBorder

    Column {
        id: inner
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        Text {
            text: sec.label.toUpperCase()
            color: sec.shell.mDim
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
        }
    }
}
