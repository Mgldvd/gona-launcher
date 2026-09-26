import QtQuick
import Quickshell

// One draggable app icon inside a tile. `path` is the tile it lives in.
// `appId` may also be `shell.launchAllMarker`, standing in for "Launch all" shown as a regular
// icon (see shell.qml's displayIds()); it opens every app in the tile instead of one app.
Item {
    id: cell
    property var shell
    property var path: []
    property string appId: ""
    property int iconSize: shell.iconSize
    readonly property bool isLaunchAll: appId === shell.launchAllMarker
    // reading .values makes this re-run once the desktop entries finish loading
    readonly property var entry: {
        DesktopEntries.applications.values;
        return isLaunchAll ? null : DesktopEntries.byId(appId);
    }

    // the highlight colour: the tile's own colour when it has one, else the global accent
    property color accentColor: shell.accent
    property color textColor: shell.fg // the label colour; dark on a light tinted tile
    property color dimColor: shell.dim // the "Launch all" icon's dots
    readonly property color accentSoft: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.2)

    // keyboard selection: registered so the shell can find where each app sits on screen
    readonly property bool selected: shell.selectedId === appId
    // a cell in the "all apps" search results: registered apart from the tiles' cells, not draggable
    property bool inResults: false
    readonly property var registry: inResults ? shell.searchCells : shell.cellItems
    Component.onCompleted: if (!isLaunchAll) registry[appId] = cell
    Component.onDestruction: if (registry[appId] === cell) delete registry[appId]
    onSelectedChanged: if (selected) Qt.callLater(ensureVisible)
    // scroll the tile (its Flickable) just enough to show this cell
    function ensureVisible() {
        let f = cell.parent;
        while (f && f.contentY === undefined) f = f.parent;
        if (!f) return;
        const y = cell.mapToItem(f.contentItem, 0, 0).y;
        if (y < f.contentY) f.contentY = y;
        else if (y + cell.height > f.contentY + f.height) f.contentY = y + cell.height - f.height;
    }

    // hidden (and taking no space) while the type-to-filter does not match this app; "Launch all"
    // is unaffected by the filter, like the corner button it replaces
    readonly property bool shownNow: isLaunchAll || (entry !== null && shell.matchesFilter(entry))
    // with the names hidden the cell shrinks to just the icon plus padding
    // names shown or hidden: the search results have their own option, apart from the tiles'
    readonly property bool labels: inResults ? shell.searchLabels : shell.showLabels
    width: shownNow ? shell.cellWidth(iconSize, labels) : 0
    height: shownNow ? shell.cellHeight(iconSize, labels) : 0
    z: ma.containsMouse ? 10 : 0 // a hovered cell (and its name tip) paints above its neighbours
    visible: shownNow

    // Drop on the left half of an icon = insert before it, right half = insert after it. "Launch
    // all" is never a real id, so it needs its own shell functions on either end of the drop.
    DropArea {
        id: da
        anchors.fill: parent
        keys: ["app"]
        property bool rightHalf: false
        readonly property bool over: containsDrag && drag.source && drag.source.appId !== cell.appId
        onPositionChanged: drag => rightHalf = drag.x > width / 2
        onDropped: drop => {
            if (drop.source.appId === cell.appId) return;
            if (cell.isLaunchAll) {
                cell.shell.moveAppToLaunchAll(drop.source.appId, cell.path, rightHalf);
            } else if (drop.source.isLaunchAll) {
                // the icon belongs to its own tile only
                if (JSON.stringify(drop.source.path) === JSON.stringify(cell.path))
                    cell.shell.moveLaunchAll(cell.path, cell.appId, rightHalf);
            } else {
                cell.shell.moveApp(drop.source.appId, cell.path, cell.appId, rightHalf);
            }
        }
    }

    // insertion marker showing where the dragged icon will land
    Rectangle {
        visible: da.over
        x: da.rightHalf ? cell.width - width : 0
        y: 8
        width: 3
        height: cell.height - 16
        radius: 0
        color: cell.shell.accent
        z: 5
    }

    Rectangle {
        id: tile
        width: cell.width
        height: cell.height
        radius: cell.shell.corner
        color: cell.selected ? cell.accentSoft : (ma.containsMouse ? cell.shell.hover : "transparent")
        border.width: cell.selected ? 2 : 0
        border.color: cell.accentColor

        Drag.active: ma.drag.active
        Drag.source: cell
        Drag.keys: ["app"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Column {
            anchors.centerIn: parent
            spacing: 6
            Image {
                visible: !cell.isLaunchAll
                anchors.horizontalCenter: parent.horizontalCenter
                width: cell.iconSize; height: cell.iconSize
                asynchronous: true
                sourceSize: Qt.size(cell.iconSize * 2, cell.iconSize * 2)
                source: cell.entry ? Quickshell.iconPath(cell.entry.icon, "application-x-executable") : ""
            }
            // "Launch all": the same dot-grid glyph as the corner button it replaces, at icon size
            Item {
                visible: cell.isLaunchAll
                anchors.horizontalCenter: parent.horizontalCenter
                width: cell.iconSize; height: cell.iconSize
                Grid {
                    id: dots
                    anchors.centerIn: parent
                    columns: 3; rows: 3
                    readonly property real dot: Math.max(2, cell.iconSize / 7)
                    columnSpacing: dot / 2
                    rowSpacing: dot / 2
                    Repeater {
                        model: 9
                        delegate: Rectangle {
                            width: dots.dot; height: dots.dot
                            radius: 0
                            color: ma.containsMouse ? cell.textColor : cell.dimColor
                        }
                    }
                }
            }
            Text {
                width: cell.width - 8
                visible: cell.labels
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: cell.isLaunchAll ? "Launch all" : (cell.entry ? cell.entry.name : "")
                color: cell.textColor
                font.pixelSize: Math.round(8 + cell.iconSize / 12)
            }
        }

        // with the names hidden, the name shows in a small tip while hovering the icon
        Rectangle {
            visible: !cell.labels && ma.containsMouse && !ma.drag.active
            z: 20
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 2
            width: Math.min(tipText.implicitWidth + 16, 220)
            height: tipText.implicitHeight + 8
            radius: cell.shell.corner
            color: cell.shell.popupBg
            border.width: 1
            border.color: cell.shell.border
            Text {
                id: tipText
                anchors.centerIn: parent
                width: parent.width - 16
                elide: Text.ElideRight
                text: cell.isLaunchAll ? "Launch all" : (cell.entry ? cell.entry.name : "")
                color: cell.shell.fg
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            drag.target: cell.inResults ? null : tile
            onClicked: {
                if (cell.isLaunchAll) cell.shell.launchAllIn(cell.path);
                else { cell.shell.launchApp(cell.entry); cell.shell.hide(); }
            }
            onReleased: if (!cell.inResults) tile.Drag.drop()
        }

        states: State {
            when: ma.drag.active
            ParentChange { target: tile; parent: cell.shell.dragOverlay }
        }
    }
}
