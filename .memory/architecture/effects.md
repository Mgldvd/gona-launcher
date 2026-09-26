# Opening effects

What each effect is: [docs/effects.md](../../docs/effects.md). How they are built (one shader over a frozen snapshot,
`slide` linear, `Fx.ease()`, `Fx.geometry()`, `EffectPreview`, how to add one): [docs/architecture.md](../../docs/architecture.md#opening-effects).
Only the extra detail is here.

- `effect` is `"classic"` or a name in `Fx.NAMES`: `Fx.BASIC` (`fade`, `slide`, `meet`, `corners`, `blocks` — the old
  full-screen-only styles, now in every mode; slide/meet come from `fullFrom`, a docked panel's slide always from its
  own edge, `Fx.slideDir()`), `fluid`, `bounce`, `genie`, `dissolve`, `glitch`, and `Fx.TERMINAL` (the Omarchy
  screensaver ones: `matrix`, `decrypt`, `synthgrid`, `spotlights`, `laser`, `blackhole`, `fireworks`, `rain`, `beams`,
  `vhs`), which play in place (`Fx.fromPoint()` false).
- Classic: a docked panel slides `mover` with `slideSpeed`, full screen fades `mover.opacity`, the card appears at once.
- Length is `effectMs`; `closeAnim` false makes closing instant, classic included; `animMs` is the length in use.
- The snapshot source is `cardStage` (card background + tiles + grip) or `stage` (docked / full screen), `live: false`,
  refreshed by `fx.snap()` in `onOpenedChanged` — a live source re-renders the tile grid every frame.
- **The `.qsb` is committed.** After editing `app/shaders/fx.frag` run `tools/build-shaders.sh` (`/usr/lib/qt6/bin/qsb`,
  package qt6-shadertools) and commit both; `tests/verify.sh` fails otherwise.
- Tests: `tests/ui/effects.body` plays each effect in three modes and checks the shader compiled; `effects-menu.body`
  the tab. Freezing frames: [docs/development.md](../../docs/development.md#seeing-an-effect-frame-by-frame).

## Reduce motion

`saved.reduceMotion` (`window.reduce_motion`) makes `animMs` 0, which is what stops everything: `FxLayer`'s effect needs
`animMs > 0`, and `slideAnim.duration` reads `animMs`. `wantedMs` is the length set in ⚙ > Effects (the Duration slider and the
preview read it, so turning the switch on does not lose the setting). `tests/ui/reduce-motion.body`.
