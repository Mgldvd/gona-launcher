import QtQuick

// One tab page of the tile menu: only the open one is visible, and all are as tall as the tallest
// (`pageH`), so the menu keeps one size whichever tab is open.
Item {
    id: page
    property int index: 0
    property int current: 0 // the open tab
    property real pageH: 300
    property real fullWidth: 300
    readonly property real natural: pageInner.height
    default property alias content: pageInner.children
    visible: current === index
    width: fullWidth
    height: pageH
    Column { id: pageInner; width: parent.width; spacing: 12 }
}
