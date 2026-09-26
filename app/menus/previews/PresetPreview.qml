import QtQuick
import Quickshell
import "../../lib/layout.js" as Tree
import "../../lib/presets.js" as Presets
import "../../lib/config.js" as Config

// A picture of a preset on the welcome screen. The launcher is drawn with the preset's own settings (tile
// corners, border width and colours, backgrounds, padding, gap, titles, names, centring, the button strip) and
// the icons of its apps that are installed here, scaled up to fill the picture so a dock or a small window
// reads as well as full screen. It sits against the edge it opens from (top, bottom, left, right); a small map
// of the screen in the corner shows where it really opens and how much of the screen it takes.
Rectangle {
    id: prev
    property var shell
    property var info             // an entry of Overlay.presetInfo: { settings, layout, ... }
    property real screenW: 1920
    property real screenH: 1080

    // the preset's settings over the defaults (a preset says only what differs)
    readonly property var st: Object.assign({}, Config.DEFAULTS, info.settings || {})
    readonly property string edge: st.edge
    readonly property var boxF: Presets.launcherBox(info.settings, screenW, screenH)
    // the launcher's real size in px, and the scale that fits it in the picture
    readonly property real realW: boxF.w * screenW
    readonly property real realH: boxF.h * screenH
    readonly property real room: 8
    readonly property real s: Math.min((width - 2 * room) / realW, (height - 2 * room) / realH)
    // the same room the launcher leaves (Overlay: outerMargin, the strip of buttons)
    readonly property real pad: st.padding
    readonly property real outer: Math.min(12, pad)
    readonly property int buttons: (st.allAppsButton ? 1 : 0) + (st.powerOffButton ? 1 : 0) + (st.restartButton ? 1 : 0) + (st.logoutButton ? 1 : 0)
    readonly property real stripH: buttons > 0 ? st.powerButtonSize + 8 : 0

    height: width * screenH / screenW
    radius: 0
    color: Qt.darker(Qt.rgba(shell.deskRgb.r, shell.deskRgb.g, shell.deskRgb.b, 1), 1.25)
    border.width: 1
    border.color: shell.mBorder
    clip: true

    Rectangle { // the launcher, against the edge it opens from
        id: launcher
        width: prev.realW * prev.s
        height: prev.realH * prev.s
        x: prev.edge === "left" ? prev.room : (prev.edge === "right" ? prev.width - width - prev.room : (prev.width - width) / 2)
        y: prev.edge === "top" ? prev.room : (prev.edge === "bottom" ? prev.height - height - prev.room : (prev.height - height) / 2)
        radius: Math.min(prev.st.radius, 12) * prev.s
        color: prev.shell.bgColor

        Item { // the tiles, inside the launcher's margin and above the strip
            id: area
            x: prev.outer * prev.s
            y: prev.outer * prev.s
            width: launcher.width - 2 * x
            height: launcher.height - 2 * y - prev.stripH * prev.s
            Repeater {
                model: Tree.leafRects(prev.info.layout)
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property var leaf: modelData.leaf
                    readonly property real half: prev.st.gap * prev.s / 2
                    readonly property real icon: (leaf.icon || prev.st.icon) * prev.s
                    readonly property real cellW: Tree.cellWidth(leaf.icon || prev.st.icon, prev.st.labels, prev.pad) * prev.s
                    readonly property real cellH: Tree.cellHeight(leaf.icon || prev.st.icon, prev.st.labels, prev.pad) * prev.s
                    readonly property real padTopPx: Tree.padTop(leaf, prev.pad) * prev.s
                    readonly property var shown: {
                        DesktopEntries.applications.values;
                        return leaf.ids.filter(id => DesktopEntries.byId(id));
                    }
                    // a gap between two tiles only, not along the launcher's edge
                    x: modelData.x * area.width + (modelData.x > 0 ? half : 0)
                    y: modelData.y * area.height + (modelData.y > 0 ? half : 0)
                    width: modelData.w * area.width - (modelData.x > 0 ? half : 0) - (modelData.x + modelData.w < 0.999 ? half : 0)
                    height: modelData.h * area.height - (modelData.y > 0 ? half : 0) - (modelData.y + modelData.h < 0.999 ? half : 0)
                    radius: prev.st.radius * prev.s
                    color: prev.shell.paint("bg", leaf)
                    border.width: Math.max(1, prev.st.borderWidth * prev.s)
                    border.color: prev.shell.paint("border", leaf)
                    clip: true
                    // the title: its text when the picture is big enough to read it, else a bar of its length
                    Text {
                        visible: (tile.leaf.title || "") !== "" && 14 * prev.s >= 7
                        x: 14 * prev.s; y: 7 * prev.s
                        text: tile.leaf.title || ""
                        color: prev.shell.fg
                        font.pixelSize: 14 * prev.s
                        font.bold: true
                    }
                    Rectangle {
                        visible: (tile.leaf.title || "") !== "" && 14 * prev.s < 7
                        x: 14 * prev.s; y: 10 * prev.s
                        width: (tile.leaf.title || "").length * 9 * prev.s; height: Math.max(1.5, 10 * prev.s)
                        radius: 0
                        color: prev.shell.fg
                        opacity: 0.8
                    }
                    Flow { // the installed apps, laid out as the tile does (padding, cells, centring)
                        id: flow
                        readonly property real inner: tile.width - 2 * prev.pad * prev.s
                        readonly property int cols: Math.max(1, Math.min(tile.shown.length, Math.floor((inner + 4 * prev.s) / (tile.cellW + 4 * prev.s))))
                        width: tile.leaf.centerH === true ? cols * (tile.cellW + 4 * prev.s) - 4 * prev.s : inner
                        x: prev.pad * prev.s + (tile.leaf.centerH === true ? (inner - width) / 2 : 0)
                        y: tile.leaf.centerV === true ? Math.max(tile.padTopPx, (tile.height - height) / 2) : tile.padTopPx
                        spacing: 4 * prev.s
                        Repeater {
                            model: tile.shown
                            delegate: Item {
                                required property string modelData
                                readonly property var entry: DesktopEntries.byId(modelData)
                                width: tile.cellW; height: tile.cellH
                                Image {
                                    x: (parent.width - width) / 2
                                    y: prev.st.labels ? 6 * prev.s : (parent.height - height) / 2
                                    width: tile.icon; height: tile.icon
                                    sourceSize: Qt.size(32, 32)
                                    source: parent.entry ? Quickshell.iconPath(parent.entry.icon, "application-x-executable") : ""
                                }
                                Rectangle { // the name, as a short line
                                    visible: prev.st.labels
                                    x: (parent.width - width) / 2
                                    y: 6 * prev.s + tile.icon + 6 * prev.s
                                    width: tile.icon; height: Math.max(1, 3 * prev.s)
                                    radius: 0
                                    color: prev.shell.fg
                                    opacity: 0.35
                                }
                            }
                        }
                    }
                }
            }
        }
        Row { // the strip of buttons, below the tiles
            visible: prev.buttons > 0
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 * prev.s }
            spacing: 10 * prev.s
            Repeater {
                model: prev.buttons
                delegate: Rectangle {
                    width: prev.st.powerButtonSize * prev.s; height: width
                    radius: 0
                    color: "transparent"
                    border.width: 1
                    border.color: prev.shell.fg
                    opacity: 0.5
                }
            }
        }
    }

    Rectangle { // where it opens: the screen, and the launcher on it, in the corner
        readonly property bool bottomish: prev.edge === "bottom"
        anchors { right: parent.right; margins: 4 }
        y: bottomish ? 4 : parent.height - height - 4
        width: 26; height: width * prev.screenH / prev.screenW
        radius: 0
        color: Qt.rgba(0, 0, 0, 0.45)
        border.width: 1
        border.color: prev.shell.mDim
        visible: prev.edge !== "full"
        Rectangle {
            x: prev.boxF.x * parent.width; y: prev.boxF.y * parent.height
            width: Math.max(2, prev.boxF.w * parent.width); height: Math.max(2, prev.boxF.h * parent.height)
            color: prev.shell.accent
        }
    }
}
