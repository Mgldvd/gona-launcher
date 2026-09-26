import QtQuick

// The row of tabs at the top of a menu (OptionsMenu, TileMenu): every tab is a line icon over a
// small label (MenuIcon.qml, menuIcons.js). `tabs` is a list of { t: label, icon: name }; they
// share the bar's width evenly. `current` is the open tab (a soft filled square behind it); a
// click emits `picked(index)` and the menu switches to it. A faint rule under the tabs (the same
// gap below it as the menu's own row spacing) separates them from the page.
Item {
    id: bar
    property var shell
    property var tabs: []
    property int current: 0
    signal picked(int index)

    // one device pixel whatever the menu's own scale (⚙ > Menu > Menu size): at 75 % a plain 1 px
    // rectangle covers only 0.75 px and, drawn without anti-aliasing, can vanish altogether
    readonly property real ruleH: 1 / (shell ? shell.menuScale : 1)
    height: tabRow.height + 16 + ruleH

    Row {
        id: tabRow
        Repeater {
            model: bar.tabs
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool on: bar.current === index
                readonly property color tint: on || tabMa.containsMouse ? bar.shell.mFg : bar.shell.mDim
                width: bar.width / bar.tabs.length
                height: 50

                Rectangle { // the selected tab (and the one under the pointer, fainter)
                    anchors { fill: parent; margins: 2 }
                    radius: 0
                    color: bar.shell.mFg
                    opacity: tab.on ? 0.1 : (tabMa.containsMouse ? 0.05 : 0)
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                MenuIcon {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                    name: tab.modelData.icon
                    color: tab.tint
                    size: 18
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                    width: parent.width - 4
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tab.modelData.t
                    color: tab.tint
                    font.pixelSize: 11
                    font.bold: tab.on
                }
                MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; onClicked: bar.picked(tab.index) }
            }
        }
    }

    Rectangle { // the rule
        y: tabRow.height + 16
        width: parent.width; height: bar.ruleH
        antialiasing: true
        color: bar.shell.mFg
        opacity: 0.18
    }
}
