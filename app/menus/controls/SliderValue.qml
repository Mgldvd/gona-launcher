import QtQuick

// The number of a SliderRow ("60 px"). Click it to type a value instead of dragging: Enter applies
// it (`typed(n)`, the row clamps it), Esc or clicking elsewhere cancels.
Item {
    id: val
    property var shell
    property string text: ""
    property int value: 0
    signal typed(int n)

    width: 44
    height: 20

    function finish() { input.focus = false; val.shell.menuFocusRequested(); } // the menu keeps the keys

    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        visible: !input.activeFocus
        text: val.text
        color: valMa.containsMouse ? val.shell.mFg : val.shell.mDim
        font.pixelSize: 12
    }
    MouseArea {
        id: valMa
        anchors { fill: parent; margins: -4 }
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: { input.text = String(val.value); input.forceActiveFocus(); input.selectAll(); }
    }
    Rectangle { // the field, only while typing
        anchors { fill: parent; leftMargin: -6; rightMargin: -4; topMargin: -3; bottomMargin: -3 }
        visible: input.activeFocus
        radius: 0
        color: val.shell.mField
        border.width: 1
        border.color: val.shell.accent
    }
    TextInput {
        id: input
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: parent.width
        horizontalAlignment: Text.AlignRight
        color: val.shell.mFg
        font.pixelSize: 12
        selectByMouse: true
        validator: IntValidator { bottom: 0; top: 99999 }
        visible: activeFocus
        onAccepted: { const n = parseInt(text); if (!isNaN(n)) val.typed(n); val.finish(); }
        onActiveFocusChanged: { if (!activeFocus) val.shell.menuFocusRequested(); }
        Keys.onEscapePressed: val.finish()
    }
}
