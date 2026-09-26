import QtQuick

// A labelled check box of the tile menu: an outline square, filled only by its check mark (never a
// solid box). `active: false` greys it out and ignores clicks. Tab reaches it, Space flips it.
Item {
    id: row
    property var shell
    property string label: ""
    property bool checked: false
    property bool active: true
    signal toggled()
    width: parent.width
    height: 26
    opacity: active ? 1 : 0.4
    activeFocusOnTab: active
    Keys.onSpacePressed: event => { row.toggled(); event.accepted = true; }
    Keys.onReturnPressed: event => { row.toggled(); event.accepted = true; }
    FocusRing { shell: row.shell }

    Rectangle {
        id: box
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18; radius: 0
        color: "transparent"
        border.width: 1
        border.color: row.checked ? row.shell.accent : row.shell.mDim
        Text { anchors.centerIn: parent; visible: row.checked; text: "✓"; color: row.shell.accent; font.pixelSize: 12; font.bold: true }
    }
    Text {
        anchors { left: box.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: row.label
        color: row.shell.mFg
        font.pixelSize: 13
    }
    MouseArea { anchors.fill: parent; enabled: row.active; onClicked: row.toggled() }
}
