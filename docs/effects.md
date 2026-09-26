# Opening effects

How the launcher comes in and goes out is the **effect**, chosen in ⚙ > Effects (or `window.effect` in
[`config.toml`](configuration.md)). Every effect works in every position: the centered window, a panel on any of
the four edges, and full screen.

**Classic** is the default and keeps what the launcher always did: a panel slides in from its edge, full screen
fades, and a centered window appears at once. Any other effect replaces that, in every position.

The tab shows the chosen effect playing on a loop on a mini screen (with a small "bar button" at the top for the
effects that start from one), so you can try them without opening the launcher.

## The effects

| Group | Effect | What it does |
|---|---|---|
| Basic | **Fade** | Comes up out of nothing with a slight zoom |
| | **Slide** | Slides in from beyond the edge of the screen. A panel comes from its own edge; anything else from the side chosen in "Comes from" |
| | **Meet** | Two halves come in from opposite sides and join in the middle ("Comes from": left and right, or top and bottom) |
| | **Corners** | Four quarters come in diagonally from the corners |
| | **Blocks** | A 6 × 4 grid of blocks pops in, bottom row first, each dropping and growing as it lands |
| Fancy | **Fluid** | Grows out of a point like a drop of liquid, rippling, and settles with a soft spring |
| | **Bounce** | Pops up on a springy bounce: stretched as it rises, squashed as it lands, with a slight tilt |
| | **Genie** | Poured out of a point through a funnel, like a magic lamp, and sucked back in on close |
| | **Dissolve** | Burns in along a glowing, ragged edge from a point, and burns away on close |
| | **Glitch** | Tearing bands, split colour channels, dropped blocks and scanlines that settle into the picture |
| Terminal | **Matrix** | Columns of falling glyphs, bright at the head; the launcher shows through their trail |
| | **Decrypt** | Every cell starts as scrambled glyphs and resolves into the picture with a flash, in random order |
| | **Synthgrid** | A neon grid grows from the middle, its cells fill in with the picture, then the grid fades |
| | **Spotlights** | Four lights search the launcher, lighting what they cross, then converge on the middle and grow |
| | **Laser etch** | A laser etches the launcher row by row, back and forth, leaving it glowing and cooling; sparks fly |
| | **Blackhole** | A black hole opens in the middle and the launcher bursts out of it, spiralling outwards in blocks |
| | **Fireworks** | Rockets climb and burst in sparks; the cells around each burst light up and drop into place |
| | **Rain** | Every cell falls from the top as a thin streak and lands in its place with a splash |
| | **Beams** | A light runs along every row and column of the grid, showing each cell as it passes |
| | **VHS tape** | An old tape settling: wobbling lines, a rolling tracking band, colour bleed and snow |

The **terminal** effects are the ones of Omarchy's [screensaver](https://omarchy.org/screensaver/), which runs
[terminaltexteffects](https://chrisbuilds.github.io/terminaltexteffects/) (`ttfx`) over the Omarchy wordmark. Here
they are redone for a picture instead of text: the launcher is treated as a grid of terminal-sized cells (12 × 24 px
at 1080 p) with made-up dot glyphs while a cell is being drawn.

## Where it starts from

- **Fluid, Bounce, Genie and Dissolve** grow from a point. Opened with the **bar button**, that point is the
  button. Opened from a key, it is the panel's own edge (a top panel comes out of the middle of its top edge), or the
  centre of a centered or full-screen launcher; Genie then draws a centered window into the bottom of the screen,
  like a dock.
- **Slide and Meet** come from a side (see above).
- **Everything else** plays in place, wherever the launcher was opened from.

## Duration and closing

- **Duration** is the length of the opening and of the closing, 0 to 2000 ms. The effects have one shared length,
  700 ms by default (`window.effect_ms`). **Classic keeps its own** (`window.slide_speed`, 110 ms), so switching
  effect never changes it; the slider edits whichever belongs to the effect in use. At 0 the launcher is instant.
- **Reduce motion** on opens and closes the launcher at once, with no effect or slide (`window.reduce_motion`); the effect and
  its length stay saved for when it is off.
- **Animate closing** off makes closing instant and animates only the opening (`window.animate_close`), for any
  effect and for Classic.
- Closing is the effect played back, with its own curve (a spring winds up before it drops, for example).

## Settings

| Key | Default | |
|---|---|---|
| `window.effect` | `"classic"` | `classic`, `fade`, `slide`, `meet`, `corners`, `blocks`, `fluid`, `bounce`, `genie`, `dissolve`, `glitch`, `matrix`, `decrypt`, `synthgrid`, `spotlights`, `laser`, `blackhole`, `fireworks`, `rain`, `beams`, `vhs` |
| `window.effect_ms` | 700 | Length of the effects |
| `window.animate_close` | `true` | |
| `window.slide_speed` | 110 | Length of Classic |
| `window.full_from` | `"top"` | Side Slide and Meet come from |

An older `full_animation` (the full-screen-only styles Classic used to have) is read once, when the mode was full
screen, as the effect: `slide`, `meet`, `corners` and `stack` (now `blocks`) keep working; `fade` was the default and
becomes Classic. It is not written back.

## How it works, briefly

One fragment shader (`app/shaders/fx.frag`, compiled to the committed `fx.frag.qsb`) draws all of them over a frozen
picture of the launcher, so the tiles are rendered once per open or close and not on every frame. Details, and how to
add an effect, are in [architecture](architecture.md#opening-effects).
