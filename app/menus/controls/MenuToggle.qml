import QtQuick

// A row of the menus: the label on the left, an outline switch on the right. Tab reaches it, Space or
// Enter flips it. `tip` is explained in a tooltip while the pointer rests on the row.
Item {
    id: row
    property var shell
    property real fullWidth: 300
    property string label: ""
    property bool checked: false
    property string tip: ""
    signal toggled()

    width: fullWidth
    height: 34
    z: tipItem.showing ? 100 : 0 // the tooltip paints over the rows below
    opacity: enabled ? 1 : 0.38   // dimmed rather than hidden when it does not apply right now
    Behavior on opacity { NumberAnimation { duration: 120 } }
    activeFocusOnTab: true
    Keys.onSpacePressed: event => { row.toggled(); event.accepted = true; }
    Keys.onReturnPressed: event => { row.toggled(); event.accepted = true; }

    MenuTip { id: tipItem; shell: row.shell; text: row.tip }
    FocusRing { shell: row.shell }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: row.shell.mFg
        font.pixelSize: 13
    }
    Rectangle {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 36; height: 20; radius: 0
        color: "transparent"
        border.width: 1
        border.color: row.checked ? row.shell.accent : row.shell.mBorder
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Rectangle {
            y: 4
            x: row.checked ? parent.width - width - 4 : 4
            width: 12; height: 12; radius: 0
            color: row.checked ? row.shell.accent : row.shell.mDim
            Behavior on x { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: row.toggled() }
}
