# 0001 — Port from a Cinnamon app to an Omarchy plugin (2026-09-22)

**Before**: a standalone `qs -p groupmenu-qs` process for Linux Mint Cinnamon (X11), with a floating OS window, a
docked panel and full screen, a Cinnamon panel applet (`GroupMenu@uu/`), a `yad` tray icon, a toggle script, and much
`xdotool`/`wmctrl` shelling to steal focus and keep windows stacked (`refocusProc`, `focusProc`, `menuKeeper`).

**Decision**: run as an Omarchy shell plugin (`overlay` + `bar-widget`). A layer-shell surface gets exclusive keyboard
focus for free, so all the focus/stacking code was **deleted, not ported**. The docked and full-screen modes and their
animations came back the same day (pure QML, not X11-specific), later rewritten as shader effects of every mode
(`SnapshotPiece.qml` removed).

**Dropped for good** (scope cuts, not oversights): the tray icon and "Start with system" (the shell already starts with
the session); migration of the old `~/.config/GroupMenu@uu/` folder (now `~/.config/gona-launcher/`).

**Came back**: "View on panel" as "Open next to the bar button" (`nextToBar`, the bar widget sends its position).

Nothing Cinnamon-specific remains in the code.
