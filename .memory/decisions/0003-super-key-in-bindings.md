# 0003 — Super alone is written into Hyprland's bindings.lua (2026-09-24)

**Problem**: after `omarchy plugin add`, nothing opened the launcher from the keyboard. The user expects Super alone to
open it out of the box. A plugin cannot register keybindings, and `omarchy plugin` has no install hook.

**Decision**: the plugin keeps its own marked block in `~/.config/hypr/bindings.lua`
(`o.bind("SUPER + SUPER_L", …, { release = true })`, fires on release so Super+key combos keep working). It adds the
block the first time it loads (only if that file exists) and remembers that in `~/.local/state/gona-launcher/super-key`,
so turning it off, or deleting the block by hand, sticks. ⚙ > Keys, first row and set apart in the accent, switches it
between Off, Tiles and All apps.

**Consequences**: removing the plugin leaves the block behind unless the user sets it to Off first (the README says
so). The file, not config.toml, is the only record, so it is the same in every profile. Implementation:
[architecture/launcher.md](../architecture/launcher.md#super-alone).
