import QtQuick

// One tab page of the settings menu: only the open one is visible, every page is as tall as the
// tallest (`pageH`) so the menu keeps one size whichever tab is open, and its rows flow into two
// columns. `content` collects whatever is declared inside the { } when this is used.
Item {
    id: sec
    property int index: 0
    property int current: 0   // the open tab
    property real pageH: 300
    property real fullWidth: 696
    property real gap: 24     // between the columns and between the rows
    readonly property real natural: inner.height + 8 // what this page needs
    default property alias content: inner.children
    visible: current === index
    width: fullWidth
    height: pageH

    Flow {
        id: inner
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4 }
        spacing: sec.gap
    }
}
