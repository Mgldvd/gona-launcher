import QtQuick

// A node of the tiling tree: either a leaf (a group of apps) or a split of two child nodes.
// `path` is the list of "a"/"b" keys leading to this node from the root.
Item {
    id: node
    property var shell
    property var path: []
    readonly property var spec: shell.nodeAt(shell.layout, path)

    Loader {
        anchors.fill: parent
        sourceComponent: node.spec.type === "split" ? splitView : leafView
    }

    //---------------------------------------------------------- leaf = one group
    Component {
        id: leafView
        Rectangle {
            id: leaf
            // the icon size this tile was given, and the one it shows: smaller when its apps do not fit at that size
            readonly property int wantedSize: node.spec.icon || node.shell.iconSize
            readonly property int size: node.shell.fitIcon(wantedSize, node.shell.installedCountIn(node.spec.ids) + node.shell.launchAllExtra(node.spec),
                                                           flick.width, flick.height)

            // The tile's colours (see "the colour system" in shell.qml): its own field, else the
            // global one, else the system default. `hasColor` = the border is a real colour (a
            // palette or custom one) rather than the soft system look or none.
            readonly property var borderPick: node.shell.pick("border", node.spec)
            readonly property bool hasColor: typeof borderPick.v === "number" || borderPick.v.charAt(0) === "#"
            readonly property color borderPaint: node.shell.paint("border", node.spec)
            readonly property color tileColor: Qt.rgba(borderPaint.r, borderPaint.g, borderPaint.b, 1) // solid, for the cells' selection
            // text colours for this tile: dark ones when its background is light
            readonly property bool light: node.shell.tileIsLight(node.spec)
            readonly property color textColor: node.shell.inkColor(light, false)
            readonly property color dimColor: node.shell.inkColor(light, true)
            radius: node.shell.tileRadius
            color: node.shell.paint("bg", node.spec)
            // true while this tile's menu is open: the tile is outlined so you can see which it is
            readonly property bool menuOpen: node.shell.tileMenuPath !== null
                                             && node.shell.key(node.shell.tileMenuPath) === node.shell.key(node.path)
            // every tile's border follows the same global thickness
            border.width: node.shell.tileBorderWidth
            // while the menu is open the tile keeps showing its own border colour (so colour changes
            // are seen live); it is outlined with the accent only when its border has no colour
            border.color: drops.containsDrag ? node.shell.accent
                          : (menuOpen && !hasColor ? node.shell.accent : borderPaint)

            DropArea {
                id: drops
                anchors.fill: parent
                keys: ["app"]
                onDropped: drop => {
                    // Qt never offers a drop to the dragged icon's own cell, so it falls through
                    // to the tile: ignore drops that land on the icon's original slot.
                    const slot = drop.source.mapToItem(drops, 0, 0);
                    const onOwnSlot = drop.x >= slot.x && drop.x <= slot.x + drop.source.width
                                   && drop.y >= slot.y && drop.y <= slot.y + drop.source.height;
                    if (onOwnSlot) return;
                    if (drop.source.isLaunchAll) {
                        // the icon belongs to its own tile only: dropped elsewhere in it, it goes
                        // to the end; dropped on a different tile, the drop is ignored
                        if (JSON.stringify(drop.source.path) === JSON.stringify(node.path))
                            node.shell.moveLaunchAll(node.path, "", false);
                    } else {
                        node.shell.moveApp(drop.source.appId, node.path, "");
                    }
                }
            }
            // The ＋ and ⋯ buttons sit over the tile's icons, so by default they show only once the pointer has rested
            // on the tile (shell.tileButtons): passing over to click an app never brings them up. An empty tile has
            // no icons to cover, so its ＋ shows at once. Right-click opens the tile menu whatever the setting.
            property bool rested: false
            readonly property bool emptyTile: node.shell.installedCountIn(node.spec.ids) === 0
            readonly property bool controlsOn: menuOpen || (hover.hovered && (emptyTile || (node.shell.tileButtons === "pause" && rested)))
            Timer {
                id: restTimer
                interval: node.shell.tileButtonsDelay
                running: hover.hovered && !leaf.rested && node.shell.tileButtons === "pause"
                onTriggered: leaf.rested = true
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: node.shell.openTileMenu(node.path)
            }
            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (!hovered) leaf.rested = false;
                    if (hovered) node.shell.hoverPath = node.path;
                    else {
                        if (JSON.stringify(node.shell.hoverPath) === JSON.stringify(node.path)) node.shell.hoverPath = null;
                    }
                }
            }

            // scrolls when the tile is fuller than it is tall, instead of overflowing its border
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: node.shell.tilePadding
                anchors.topMargin: node.shell.tilePadTop(node.spec)
                contentHeight: flow.y + flow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Centring (per tile, set in the tile menu). Horizontally the block of icons is sized
                // to the columns it really uses and centred; vertically it is centred in the tile
                // whenever it is shorter than the tile (otherwise it just scrolls from the top).
                readonly property real gap: 4
                readonly property real stride: node.shell.cellWidth(leaf.size) + gap
                readonly property int shownCount: node.shell.shownCountIn(node.spec.ids) + node.shell.launchAllExtra(node.spec)
                readonly property int columns: Math.min(Math.max(1, shownCount),
                                                        Math.max(1, Math.floor((width + gap) / stride)))
                Flow {
                    id: flow
                    width: node.spec.centerH === true ? flick.columns * flick.stride - flick.gap : parent.width
                    x: node.spec.centerH === true ? (flick.width - width) / 2 : 0
                    y: node.spec.centerV === true ? Math.max(0, (leaf.height - height) / 2 - flick.y) : 0
                    spacing: flick.gap
                    // "Launch all" (turned on in the tile menu), shown as a regular cell instead of
                    // the small corner button, is spliced into the ids here (never stored in
                    // `ids` itself) so it is a cell like any other: draggable to reorder among them.
                    Repeater {
                        model: node.shell.displayIds(node.spec)
                        delegate: AppCell {
                            required property string modelData
                            shell: node.shell
                            path: node.path
                            appId: modelData
                            iconSize: leaf.size
                            accentColor: leaf.hasColor ? leaf.tileColor : node.shell.accent
                            textColor: leaf.textColor
                            dimColor: leaf.dimColor
                        }
                    }
                }
            }

            // the tile's title, along its top edge; it keeps clear of the corner buttons (⋯ ＋ on the
            // right, "launch all" on the left, unless that one is shown as a grid icon instead)
            readonly property bool launchAllCorner: node.spec.launchAll === true && node.spec.launchAllIcon !== true
            Text {
                visible: (node.spec.title || "") !== ""
                anchors {
                    top: parent.top; topMargin: 7
                    left: parent.left; leftMargin: 14 + (leaf.launchAllCorner ? 22 : 0)
                    right: parent.right; rightMargin: 64
                }
                text: node.spec.title || ""
                horizontalAlignment: node.spec.titleAlign === "center" ? Text.AlignHCenter
                                     : (node.spec.titleAlign === "right" ? Text.AlignRight : Text.AlignLeft)
                elide: Text.ElideRight
                color: leaf.textColor
                font.pixelSize: 14
                font.family: node.spec.titleFont || Qt.application.font.family
                font.bold: node.spec.titleBold !== false
                font.italic: node.spec.titleItalic === true
            }

            Text {
                anchors.centerIn: parent
                // also when it lists apps but none is installed (a preset's tile after they were removed), so
                // it never looks broken; not while typing, when a tile with no match is simply empty
                visible: node.spec.ids.length === 0 || (node.shell.filterText === "" && node.shell.shownCountIn(node.spec.ids) === 0)
                width: parent.width - 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: node.spec.ids.length === 0 ? "Drag apps here or press ＋" : "None of these apps is installed. Press ＋ to add some"
                color: leaf.dimColor
                font.pixelSize: 13
            }

            // "Launch all" (turned on in the tile menu): a small dot-grid icon, always shown (not
            // just on hover, since it is a deliberate per-tile setting), that opens every app here.
            Item {
                id: launchAllBtn
                visible: leaf.launchAllCorner
                anchors { top: parent.top; left: parent.left; margins: 10 }
                width: 16; height: 16
                Grid {
                    anchors.centerIn: parent
                    columns: 3; rows: 3; spacing: 2
                    Repeater {
                        model: 9
                        delegate: Rectangle {
                            width: 3; height: 3; radius: 0
                            color: launchAllMa.containsMouse ? leaf.textColor : leaf.dimColor
                        }
                    }
                }
                MouseArea {
                    id: launchAllMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: node.shell.launchAllIn(node.path)
                }
            }

            // The tile's only control: a ⋯ button in its corner (shown while the pointer is over the
            // tile). It opens the tile menu, which holds every option of the tile.
            // ＋ beside it: add apps to this tile straight away (the menu has the same button)
            Text {
                visible: leaf.controlsOn
                anchors { top: parent.top; right: menuButton.left; rightMargin: 12; topMargin: 8 }
                text: "+"
                color: addMa.containsMouse ? leaf.textColor : leaf.dimColor
                font.pixelSize: 20
                font.bold: true
                MouseArea {
                    id: addMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: node.shell.pickingPath = node.path
                }
            }
            Text {
                id: menuButton
                visible: leaf.controlsOn
                anchors { top: parent.top; right: parent.right; margins: 8 }
                text: "⋯"
                color: leaf.menuOpen ? node.shell.accent : (menuMa.containsMouse ? leaf.textColor : leaf.dimColor)
                font.pixelSize: 20
                font.bold: true
                MouseArea {
                    id: menuMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: node.shell.openTileMenu(node.path)
                }
            }

        }
    }

    //---------------------------------------------------------- split = two children + divider
    Component {
        id: splitView
        Item {
            id: sv
            readonly property bool side: node.spec.dir === "h" // "h": side by side (split right)
            // the divider position, kept away from squeezing either side below what its icons need
            readonly property real ratio: node.shell.effRatio(node.spec, sv.width, sv.height, node.shell.ratioOf(node.path))
            // the same for the two children (only used when this split is a cross); each one sits in
            // the box the loaders below give it
            function childRatio(k) {
                const box = k === "a" ? first : second;
                return node.shell.effRatio(node.spec[k], box.width, box.height, node.shell.ratioOf(node.path.concat([k])));
            }
            readonly property real gap: node.shell.tileGap

            // A "cross" is a split whose two children split the other way (2x2-like junction).
            // Its lines get grab handles: one per line half, and one on the junction when the
            // halves are aligned. Geometry below is in this item's own coordinates.
            readonly property bool cross: node.shell.isCross(node.spec)
            readonly property real c1: cross ? childRatio("a") : 0
            readonly property real c2: cross ? childRatio("b") : 0
            // one expression on purpose: if it went through c1 and c2, Qt would update them one
            // at a time and `aligned` would flicker false in between, hiding the dragged handle
            readonly property bool aligned: cross && Math.abs(childRatio("a") - childRatio("b")) < node.shell.alignTol
            readonly property real px: side ? width * ratio : width * c1   // junction x
            readonly property real py: side ? height * c1 : height * ratio // junction y
            readonly property real vx1: side ? width * ratio : width * c1  // vertical line, top half
            readonly property real vx2: side ? width * ratio : width * c2  // vertical line, bottom half
            readonly property real hy1: side ? height * c1 : height * ratio // horizontal line, left half
            readonly property real hy2: side ? height * c2 : height * ratio // horizontal line, right half

            HoverHandler { id: svHover }

            Loader {
                id: first
                x: 0; y: 0
                width: sv.side ? sv.width * sv.ratio - sv.gap / 2 : sv.width
                height: sv.side ? sv.height : sv.height * sv.ratio - sv.gap / 2
                Component.onCompleted: setSource("Node.qml", { shell: node.shell, path: node.path.concat(["a"]) })
            }
            Loader {
                id: second
                x: sv.side ? sv.width * sv.ratio + sv.gap / 2 : 0
                y: sv.side ? 0 : sv.height * sv.ratio + sv.gap / 2
                width: sv.side ? sv.width - x : sv.width
                height: sv.side ? sv.height : sv.height - y
                Component.onCompleted: setSource("Node.qml", { shell: node.shell, path: node.path.concat(["b"]) })
            }

            MouseArea {
                id: divider
                x: sv.side ? sv.width * sv.ratio - 5 : 0
                y: sv.side ? 0 : sv.height * sv.ratio - 5
                width: sv.side ? 10 : sv.width
                height: sv.side ? sv.height : 10
                enabled: node.shell.resizeMode // dividers only respond in resize mode
                hoverEnabled: true
                cursorShape: sv.side ? Qt.SplitHCursor : Qt.SplitVCursor
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(sv, mouse.x, mouse.y);
                    const r = sv.side ? p.x / sv.width : p.y / sv.height;
                    node.shell.setLive(node.path, node.shell.effRatio(node.spec, sv.width, sv.height, r));
                }
                onReleased: node.shell.commitLive()
                Rectangle {
                    anchors.centerIn: parent
                    width: sv.side ? 2 : parent.width * 0.3
                    height: sv.side ? parent.height * 0.3 : 2
                    radius: 0
                    color: divider.containsMouse || divider.pressed ? node.shell.accent
                         : (node.shell.resizeMode ? node.shell.accentGuide : "transparent")
                }
            }

            // ---- cross handles (drawn above the dividers). The vertical/horizontal line whose
            // halves are already independent is always available; the other one is free only
            // while the two halves are aligned (dragging it then flips the structure).
            CrossPill {
                role: "V1"; area: sv; near: svHover.hovered
                shown: sv.cross && (!sv.side || sv.aligned)
                cx: sv.vx1; cy: sv.py / 2
            }
            CrossPill {
                role: "V2"; area: sv; near: svHover.hovered
                shown: sv.cross && (!sv.side || sv.aligned)
                cx: sv.vx2; cy: sv.py + (sv.height - sv.py) / 2
            }
            CrossPill {
                role: "H1"; area: sv; near: svHover.hovered; onHLine: true
                shown: sv.cross && (sv.side || sv.aligned)
                cx: sv.px / 2; cy: sv.hy1
            }
            CrossPill {
                role: "H2"; area: sv; near: svHover.hovered; onHLine: true
                shown: sv.cross && (sv.side || sv.aligned)
                cx: sv.px + (sv.width - sv.px) / 2; cy: sv.hy2
            }
            CrossPill {
                role: "X"; area: sv; near: svHover.hovered
                shown: sv.aligned
                cx: sv.px; cy: sv.py
            }
        }
    }

    // A grab handle on a divider: a small pink pill (round for the junction). Faint while the
    // pointer is over the surrounding tiles, solid when it is hovered or dragged.
    component CrossPill: Item {
        id: pill
        property string role: ""
        property Item area
        property bool near: false
        property bool shown: false // whether this handle applies to the current geometry
        // handles exist only in resize mode; one being dragged never hides mid-drag
        visible: (shown && node.shell.resizeMode) || ma.pressed
        property bool onHLine: false // sits on a horizontal line -> wide pill, else tall
        property real cx: 0
        property real cy: 0

        x: cx - width / 2
        y: cy - height / 2
        width: role === "X" ? 14 : (onHLine ? 38 : 6)
        height: role === "X" ? 14 : (onHLine ? 6 : 38)
        z: 5

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: node.shell.accent
            opacity: ma.containsMouse || ma.pressed ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: pill.role === "X" ? Qt.SizeAllCursor : (pill.onHLine ? Qt.SplitVCursor : Qt.SplitHCursor)
            onPressed: node.shell.crossPress(node.path, pill.role)
            onPositionChanged: mouse => {
                if (!pressed) return;
                const p = mapToItem(pill.area, mouse.x, mouse.y);
                node.shell.crossMove(node.path, pill.role, p.x / pill.area.width, p.y / pill.area.height);
            }
            onReleased: node.shell.commitLive()
        }
    }
}
