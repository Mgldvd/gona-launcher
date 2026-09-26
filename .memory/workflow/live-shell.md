# Working against the live shell

The install loop and the test scripts are in [docs/development.md](../../docs/development.md). This is what an agent
must do on top of it.

- The shell under test is the **user's real desktop session** (`quickshell -n -p /usr/share/omarchy/shell`, pid from
  `pgrep -f "quickshell -n -p /usr/share/omarchy/shell"`). There is no sandbox for it; `tests/ui.sh` is the only
  isolated instance.
- After every `tools/install.sh`, read its log before reporting done:
  `journalctl --user _PID=<pid> -n 40 --no-pager` (not a systemd unit, `-u` finds nothing). Look for
  `WARN`/`ERROR`/`TypeError`/`ReferenceError` near the change. Ignore the `IpcHandler ... weather` / `SystemUpdate`
  warnings and the `readFile ... File does not exist` ones (a missing optional file).
- **Stale hot reload**: `Local plugin changed, reloading: gona.launcher` does not prove the new code runs. It can keep
  an old compile indefinitely, even across `omarchy plugin disable`/`enable` (worst with files that declare inline
  `component X:`; `LauncherContent.qml`'s `PowerButton` still does). It can also reload by halves: files read at run time (`app/presets/*.toml`) are new while
  an edited `app/lib/*.js` is still the old one (seen with `presets.js`). Check that the change actually ran (a log line,
  a file it writes); if not, prove the code in `tests/ui.sh`. The user gave standing permission to run
  `omarchy restart shell` after every change (it flashes their bar and every panel), so do it after each install and look at the result. After a restart expect a fresh `Configuration Loaded` and a new pid.
- Seeing it: `omarchy-shell shell summon gona.launcher '{"tab":"keys"}'`, `grim /tmp/check.png`, read the PNG, then
  `hide`.
- **Never use `wtype`/`ydotool`** (there is no `xdotool`, this is Wayland). `wtype` worked once, then typed into
  whatever window `hyprctl activewindow` reported — the user's terminal, mid-conversation — despite the plugin's
  exclusive keyboard focus. For clicks and keys: a UI test, or ask the user to try it.
- Editing `~/.config/hypr/*`: load the `omarchy` skill first, back the file up, then `hyprctl reload` and
  `hyprctl configerrors`.
