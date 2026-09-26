import QtQuick

// With "Allow all apps in search" on, typing a filter shows every installed app that matches here,
// over the tiles. The cells are the same as in the tiles (select, launch), but cannot be dragged.
Rectangle { // drawn like a tile, so it looks consistent with the tiles
    id: results
    property var shell
    radius: results.shell.corner
    // the app background, but never see-through (with a transparent one the icons and names would be
    // unreadable over the desktop): the same colour the launcher's text was chosen against
    color: shell.solidBg
    border.width: 1
    border.color: shell.border

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 36 // room for the filter pill (the pill sits on the tile border)
        contentHeight: Math.max(flow.height, height) // (a short list is centred in the room, a long one scrolls)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // The matches sit in the centre of the panel, both ways: the block is as wide as the columns it
        // really uses and centred, and centred vertically while it is shorter than the panel.
        readonly property real gap: 4
        readonly property real stride: results.shell.cellWidth(results.shell.iconSize, results.shell.searchLabels) + gap
        readonly property int columns: Math.min(Math.max(1, results.shell.searchResults.length),
                                                Math.max(1, Math.floor((width + gap) / stride)))
        Flow {
            id: flow
            width: flick.columns * flick.stride - flick.gap
            x: (flick.width - width) / 2
            y: Math.max(0, (flick.height - height) / 2)
            spacing: flick.gap
            Repeater {
                model: results.shell.searchResults
                delegate: AppCell {
                    required property string modelData
                    shell: results.shell
                    inResults: true
                    appId: modelData
                    iconSize: results.shell.iconSize
                }
            }
        }
    }
}
