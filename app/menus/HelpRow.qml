import QtQuick

// One line of the shortcut card (Help.qml): the keys in the accent colour, and what they do.
Item {
    id: r
    property var shell
    property string keys: ""
    property string what: ""
    property real keyWidth: 190
    width: parent ? parent.width : 300
    height: 22
    Text { id: k; width: r.keyWidth; elide: Text.ElideRight; text: r.keys; color: r.shell.accent; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
    Text { anchors { left: k.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter } elide: Text.ElideRight; text: r.what; color: r.shell.mFg; font.pixelSize: 12 }
}
