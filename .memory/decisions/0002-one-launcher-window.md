# 0002 — One full-screen launcher window for every mode

**Problem**: the centred card and the docked/full-screen panel were two layer-shell windows, each mapped only in its
mode. Switching `edge` while the ⚙ menu was open mapped the other window, and a freshly mapped surface lands on top of
same-layer ones, so it covered the menu — with no `open()` call involved to reorder.

**Decision**: merge them into `launcherWin`, always full screen and mapped whenever the launcher is open or animating,
with `card` and `dockedArea` as plain Items inside. Removing the remapping is more durable than sequencing one more pair
of property writes.

**Consequences**: `launcherWin`'s scrim closes on a click outside `card`/`dockedArea` (it replaced separate click-away
windows); only one Loader may have `focus: true`; `dockedArea` must be placed without anchors. See
[architecture/windows.md](../architecture/windows.md).
