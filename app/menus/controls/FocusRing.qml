import QtQuick

// The outline a menu control shows while it has the keyboard focus (reached with Tab): fills its
// parent, a little outside it. Nothing is drawn for mouse use, since a click never focuses a control.
Rectangle {
    property var shell
    anchors { fill: parent; margins: -3 }
    radius: 0
    color: "transparent"
    border.width: 1.5
    border.color: shell ? shell.accent : "white"
    visible: parent.activeFocus
}
