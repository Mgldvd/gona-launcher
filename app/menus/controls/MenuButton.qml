import QtQuick

// An outline ("wire") button of the menus (OptionsMenu, TileMenu): transparent fill, a coloured
// border and matching text. `primary` uses the accent, `danger` red; `active: false` dims it and
// ignores clicks.
Rectangle {
    id: btn
    property var shell
    property string label: ""
    property bool danger: false
    property bool primary: false
    property bool active: true
    signal clicked()
    readonly property color tint: danger ? shell.mDanger : (primary ? shell.accent : shell.mFg)
    height: 32
    radius: 0
    opacity: active ? 1 : 0.4
    color: "transparent"
    border.width: 1
    border.color: (primary || danger) ? tint : (ma.containsMouse ? shell.mDim : shell.mBorder)

    Text {
        anchors.centerIn: parent
        text: btn.label
        font.pixelSize: 13
        font.bold: btn.primary
        color: (btn.primary || btn.danger) ? btn.tint : (ma.containsMouse ? btn.shell.mFg : btn.shell.mDim)
    }
    activeFocusOnTab: active
    Keys.onSpacePressed: event => { btn.clicked(); event.accepted = true; }
    Keys.onReturnPressed: event => { btn.clicked(); event.accepted = true; }
    FocusRing { shell: btn.shell }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: btn.active; onClicked: btn.clicked() }
}
