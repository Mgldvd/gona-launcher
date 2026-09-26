import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "lib/fx.js" as Fx

// The bar button that opens Gona Launcher. Left click toggles the tiles; middle click opens straight into "all
// apps"; right click opens a small menu (Settings, Reload, About and the version), since opening the ⚙ settings
// straight away was not something people expected from a right click. The ⚙ menu is also one key away (⚙ > Keys).
BarWidget {
  id: root
  moduleName: "gona.launcher"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // the small menu: it is one of the bar's popups (the same card, dismissal and stacking as the clock's or the
  // volume's), so the bar closes it when another opens or when you click anywhere else
  property bool menuOpen: false
  function close() { menuOpen = false }

  readonly property string repoUrl: "https://github.com/Mgldvd/gona-launcher"
  property string version: ""
  FileView { // manifest.json, one folder above this file: where the version lives
    id: manifest
    path: decodeURIComponent(Qt.resolvedUrl("../manifest.json").toString().replace(/^file:\/\//, ""))
    printErrors: false
    onLoaded: { try { root.version = JSON.parse(manifest.text()).version || "" } catch (e) { root.version = "" } }
  }

  function summon(payload) {
    if (root.bar) root.bar.run("omarchy-shell shell summon gona.launcher '" + JSON.stringify(payload) + "'")
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "▦" // a plain Unicode glyph, so it renders without depending on an icon font being installed
    horizontalMargin: 7.5
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton)
        root.menuOpen = !root.menuOpen
      else if (mouseButton === Qt.MiddleButton)
        root.summon({ allApps: true })
      else {
        root.menuOpen = false
        // where this button is on its screen, so a panel can open next to it (⚙ > Window > "Open next to the bar button")
        // (the bar's window spans its screen along its edge and is only as thick as the bar across it, so for a
        // bottom or right bar its coordinates are moved to where they are on the screen)
        const p = button.mapToItem(null, button.width / 2, button.height / 2)
        const win = button.Window.window
        const scr = win && win.screen ? win.screen : null
        const at = scr ? Fx.screenPoint(p.x, p.y, root.bar.position, scr.width, scr.height, win.width, win.height) : p
        const anchor = { x: Math.round(at.x), y: Math.round(at.y), screen: scr ? scr.name : "" }
        root.bar.run("omarchy-shell shell toggle gona.launcher '" + JSON.stringify({ anchor: anchor }) + "'")
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.menuOpen
    contentWidth: popup.fittedContentWidth(Style.space(190))
    contentHeight: popup.fittedContentHeight(items.implicitHeight)

    Column {
      id: items
      anchors.fill: parent
      spacing: Style.space(2)

      // the name, as a heading
      Text {
        width: parent.width
        leftPadding: Style.space(8)
        topPadding: Style.space(2)
        bottomPadding: Style.space(4)
        text: "Gona Launcher"
        color: Color.popups.text
        opacity: 0.6
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      PanelSeparator { foreground: Color.popups.text }

      Repeater {
        model: [
          { glyph: "⚙", label: "Settings", run: "settings" },
          { glyph: "↻", label: "Reload", run: "reload" },
          { glyph: "ⓘ", label: "About", run: "about" }
        ]
        delegate: Rectangle {
          id: row
          required property var modelData
          width: items.width
          height: Style.spacing.popupRowHeight
          radius: Style.cornerRadius
          color: rowMa.containsMouse ? Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.12) : "transparent"
          Row {
            anchors { left: parent.left; leftMargin: Style.space(8); verticalCenter: parent.verticalCenter }
            spacing: Style.space(10)
            Text {
              width: Style.space(16)
              horizontalAlignment: Text.AlignHCenter
              text: row.modelData.glyph
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              text: row.modelData.label
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }
          }
          MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.menuOpen = false
              if (row.modelData.run === "settings") root.summon({ options: true })
              else if (row.modelData.run === "reload") root.summon({ reload: true })
              else if (root.bar) root.bar.run("xdg-open " + root.repoUrl)
            }
          }
        }
      }

      PanelSeparator { foreground: Color.popups.text }
      // the version, not a button
      Text {
        width: parent.width
        leftPadding: Style.space(8)
        topPadding: Style.space(4)
        bottomPadding: Style.space(2)
        text: root.version !== "" ? "Version " + root.version : "Version unknown"
        color: Color.popups.text
        opacity: 0.6
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
