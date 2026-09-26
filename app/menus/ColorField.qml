import QtQuick
import "controls"

// One colour field, the same control everywhere: the global accent / border / tile background / app
// background (options menu, `path` null) and a tile's own border / background (tile menu, `path`
// set). It shows: a title with the current state and ↺, the choices System / Transparent, the 8
// palette colours and any colour (full picker), and the opacity of the colour.
// It reads and writes the field itself through the shell (see "the colour system" in shell.qml):
// on a tile, a field that was never set is "Inherited" from the global one, and ↺ goes back to that.
Column {
    id: g
    property var shell
    property string field: "bg" // accent | border | bg | appBg
    property var path: null // the tile it edits, or null for the global field
    property string label: ""
    property string hint: "" // an explanation under the title, when the field is not self-explanatory
    property real fullWidth: 300
    property string hoverName: "" // the swatch under the pointer: its name replaces the current state in the title

    readonly property bool isTile: path !== null
    readonly property var tileSpec: isTile ? shell.leafAt(path) : null
    // what is stored in this very field (undefined = never set)
    readonly property var own: shell.cleanField(isTile ? tileSpec[shell.tileKey(field)] : shell.colors[field])
    readonly property var eff: shell.pick(field, tileSpec) // what is actually used: { v, a }
    // the choice to show as selected: a global field never set is "system"; a tile's is nothing
    readonly property var curV: own && own.v !== undefined ? own.v : (isTile ? undefined : "system")
    readonly property bool isCustom: typeof curV === "string" && curV.charAt(0) === "#"
    readonly property bool clear: eff.v === "none" // fully transparent: the opacity means nothing
    readonly property bool modified: own !== undefined

    function stateText() {
        if (curV === undefined) return "Inherited";
        if (curV === "system") return "System";
        if (curV === "none") return "Transparent";
        return isCustom ? curV : "Color";
    }
    function apply(patch) {
        if (isTile) shell.setTileColor(path, field, patch);
        else shell.setColor(field, patch);
    }
    // Choosing a real colour sets its opacity to 100 % unless this field already has its own, so a
    // faint default (the system border) does not make the new colour faint too.
    function pickV(v) {
        const colour = v !== "system" && v !== "none";
        apply(colour && (!own || own.a === undefined) ? { v: v, a: 100 } : { v: v });
    }

    // the opacity is applied at most every 70 ms while dragging (each tile change rebuilds the tiles)
    property int pendingA: -1
    Timer {
        id: alphaTimer
        interval: 70
        onTriggered: { if (g.pendingA >= 0) g.apply({ a: g.pendingA }); g.pendingA = -1; }
    }
    function pickA(a) { pendingA = a; if (!alphaTimer.running) alphaTimer.start(); }

    // the custom colour as hue / saturation / value (0..1)
    property bool pickerOpen: false
    property real ph: 0.6
    property real ps: 0.6
    property real pv: 0.95
    property bool picking: false // a picker control is being dragged: do not re-sync meanwhile
    readonly property string customHex: Qt.hsva(ph, ps, pv, 1).toString() // "#rrggbb"
    onPathChanged: pickerOpen = false

    Gradient { // the rainbow of the "any colour" swatch
        id: rainbow
        orientation: Gradient.Horizontal
        GradientStop { position: 0.00; color: "#ff5f5f" }
        GradientStop { position: 0.25; color: "#ffd75f" }
        GradientStop { position: 0.50; color: "#5fff87" }
        GradientStop { position: 0.75; color: "#5fafff" }
        GradientStop { position: 1.00; color: "#d75fff" }
    }

    width: fullWidth
    spacing: 8

    function syncFromHex(hex) {
        const c = Qt.color(hex);
        if (c.hsvHue >= 0) ph = c.hsvHue; // a grey has no hue: keep the one we had
        ps = c.hsvSaturation;
        pv = c.hsvValue;
    }
    onCurVChanged: { if (isCustom && !picking && customHex !== curV) syncFromHex(curV); }
    // while dragging, the field is updated at most every 70 ms
    Timer { id: commitTimer; interval: 70; onTriggered: g.pickV(g.customHex) }
    function changed() { if (!commitTimer.running) commitTimer.start(); }
    function commitNow() { commitTimer.stop(); pickV(customHex); }

    // an outline chip, selected = accent border
    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool on: false
        signal clicked()
        height: 26
        width: chipText.implicitWidth + 24
        radius: 0
        color: "transparent"
        border.width: 1
        border.color: on ? g.shell.accent : (chipMa.containsMouse ? g.shell.mDim : g.shell.mBorder)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            font.pixelSize: 12
            font.bold: chip.on
            color: chip.on ? g.shell.accent : (chipMa.containsMouse ? g.shell.mFg : g.shell.mDim)
        }
        MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
    }

    // ---- title, what is chosen now, and ↺
    Item {
        width: g.width
        height: 18
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: g.label
            color: g.shell.mFg
            font.pixelSize: 13
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: g.hoverName !== "" ? g.hoverName : g.stateText()
                color: g.hoverName !== "" ? g.shell.mFg : g.shell.mDim
                font.pixelSize: 12
                font.family: g.isCustom && g.hoverName === "" ? "monospace" : ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "↺"
                color: g.modified ? g.shell.mFg : g.shell.mDim
                opacity: g.modified ? 1 : 0.35
                font.pixelSize: 15
                MouseArea {
                    anchors.fill: parent; anchors.margins: -5
                    enabled: g.modified
                    onClicked: { g.pickerOpen = false; g.apply(null); }
                }
            }
        }
    }

    Text {
        visible: g.hint !== ""
        width: g.width
        wrapMode: Text.WordWrap
        text: g.hint
        color: g.shell.mDim
        font.pixelSize: 11
    }

    // ---- System / Transparent
    Row {
        spacing: 6
        Chip { text: "System"; on: g.curV === "system"; onClicked: { g.pickerOpen = false; g.pickV("system"); } }
        Chip { text: "Transparent"; on: g.curV === "none"; onClicked: { g.pickerOpen = false; g.pickV("none"); } }
    }

    // ---- the 8 palette colours, and any colour (a rainbow until one is chosen)
    Row {
        id: swatches
        readonly property real gap: 5
        readonly property real size: Math.min(28, Math.floor((g.width - 8 * gap) / 9))
        spacing: gap
        Repeater {
            model: g.shell.palette
            delegate: Rectangle {
                required property int index
                required property string modelData
                width: swatches.size; height: swatches.size; radius: 0
                // the colour as it will look on this field in the current look, not the raw palette
                // colour: a tile background is a soft tint, so the swatch shows that tint and a
                // ring in the palette colour itself says which one it is
                readonly property bool tinted: g.field === "bg"
                color: g.shell.swatchFor(g.field, index)
                border.width: g.curV === index ? 3 : (tinted ? 2 : 0)
                border.color: g.curV === index ? g.shell.mFg : modelData
                MouseArea {
                    anchors.fill: parent; anchors.margins: -2
                    hoverEnabled: true
                    onEntered: g.hoverName = g.shell.paletteNames[index]
                    onExited: g.hoverName = ""
                    onClicked: { g.pickerOpen = false; g.pickV(index); }
                }
            }
        }
        Rectangle {
            width: swatches.size; height: swatches.size; radius: 0
            color: g.isCustom ? g.curV : "transparent"
            gradient: g.isCustom ? null : rainbow
            border.width: g.isCustom ? 3 : 1
            border.color: g.isCustom ? g.shell.mFg : g.shell.mDim
            MouseArea {
                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                onEntered: g.hoverName = "Any color"
                onExited: g.hoverName = ""
                onClicked: {
                    if (!g.isCustom) { // start from the colour it has now (or blue)
                        g.syncFromHex(g.shell.hexFor(g.field, g.eff.v) || "#89b4fa");
                        g.pickV(g.customHex);
                        g.pickerOpen = true;
                    } else {
                        g.pickerOpen = !g.pickerOpen;
                    }
                }
            }
        }
    }

    // ---- the full picker
    Column {
        visible: g.pickerOpen && g.isCustom
        width: g.width
        spacing: 10

        // saturation grows to the right, brightness grows upwards, at the chosen hue
        Rectangle {
            id: svBox
            width: parent.width; height: 120; radius: 0
            color: Qt.hsva(g.ph, 1, 1, 1)
            Rectangle {
                anchors.fill: parent; radius: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffffff" }
                    GradientStop { position: 1; color: "#00ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: 0
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#ff000000" }
                }
            }
            Rectangle { // the picked point
                x: g.ps * svBox.width - 7
                y: (1 - g.pv) * svBox.height - 7
                width: 14; height: 14; radius: 0
                color: "transparent"
                border.width: 2; border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                function pick(mouse) {
                    g.ps = Math.max(0, Math.min(1, mouse.x / width));
                    g.pv = 1 - Math.max(0, Math.min(1, mouse.y / height));
                    g.changed();
                }
                onPressed: mouse => { g.picking = true; pick(mouse); }
                onPositionChanged: mouse => { if (pressed) pick(mouse); }
                onReleased: { g.picking = false; g.commitNow(); }
            }
        }

        // hue
        Rectangle {
            id: hueBar
            width: parent.width; height: 14; radius: 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.167; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.667; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }
            Rectangle {
                x: g.ph * hueBar.width - 7
                y: -2
                width: 14; height: 18; radius: 0
                color: Qt.hsva(g.ph, 1, 1, 1)
                border.width: 2; border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6; anchors.bottomMargin: -6
                function pick(mouse) { g.ph = Math.max(0, Math.min(0.9999, mouse.x / width)); g.changed(); }
                onPressed: mouse => { g.picking = true; pick(mouse); }
                onPositionChanged: mouse => { if (pressed) pick(mouse); }
                onReleased: { g.picking = false; g.commitNow(); }
            }
        }

        // preview and the hex code: type six hex digits and press Enter
        Row {
            spacing: 10
            Rectangle {
                width: 30; height: 26; radius: 0
                color: g.customHex
                border.width: 1; border.color: g.shell.mBorder
            }
            Rectangle {
                width: 120; height: 26; radius: 0
                color: g.shell.mField
                border.width: hexInput.activeFocus ? 1 : 0
                border.color: g.shell.accent
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "#"; color: g.shell.mDim; font.pixelSize: 13 }
                TextInput {
                    id: hexInput
                    anchors { left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    color: g.shell.mFg
                    font.pixelSize: 13
                    font.family: "monospace"
                    maximumLength: 6
                    selectByMouse: true
                    text: g.customHex.slice(1)
                    validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,6}/ }
                    onAccepted: {
                        if (text.length === 6) { g.syncFromHex("#" + text); g.commitNow(); }
                        focus = false;
                        g.shell.menuFocusRequested();
                    }
                    Keys.onEscapePressed: { focus = false; g.shell.menuFocusRequested(); }
                }
                TapHandler { onTapped: hexInput.forceActiveFocus() }
            }
        }
    }

    // ---- opacity of this colour (no meaning while it is transparent)
    SliderRow {
        shell: g.shell
        fullWidth: g.width
        label: "Opacity"
        unit: " %"
        from: 0; to: 100; step: 1
        value: g.pendingA >= 0 ? g.pendingA : g.eff.a
        enabled: !g.clear
        opacity: g.clear ? 0.4 : 1
        onPicked: v => g.pickA(v)
    }
}
