# Pixel-art style — the target, in one page

> **Superseded in part, 2026-10-02.** The owner chose LimeZu's *Modern Interiors* look
> over the "GBA/Pokémon" rules below, and most art is now LimeZu's own (see
> `docs/ART_STYLE_REFERENCE.md`). Where this page and that one disagree, that one wins:
> keyline **#3a3a50** (not `#241A12`), 3-4 tones per material (not 2-3), a mouthless
> chibi with two-pixel eyes, per-surface shading with visible grain. The rules below
> still describe the procedural generators' output, i.e. the art the packs do not cover.

What "the EduSystem look" means concretely, so a person drawing in the art
forge (`Browse Art.bat`) or writing a generator has one place to check
against. This is the same direction `docs/AI_ART_PROMPTS.md` gives to an
image generator, restated for hand work; `docs/ART_CATALOG.md` is the
per-asset record.

## The one-line version

**GBA-era handheld-RPG sprite art** — what we've been calling "Pokémon
style". Chibi proportions, a hard dark keyline, flat 2-3-tone shading, one
light source, no dithering, authored at 16 art-px per tile and Scale2x'd
to 32.

## The rules

- **Keyline.** One shared outline colour, `#241A12` (`LINE` in
  `tools/make_art.py`). A 1px border on every edge where solid art meets
  transparency. Not pure black; not per-object.
- **One light source, upper-left.** Top and left edges of a shape are
  lifted a step, bottom and right edges dropped a step -- the `rim_light`
  / `finish` pass in `make_art.py`. A desk and the child standing at it
  agree about where the window is.
- **Flat fills, 2-3 tones per material.** A base colour, a lit tone, a
  shade tone -- that is the whole ramp for wood, cloth, metal, skin, hair.
  No gradients. No blends across a fill.
- **No anti-aliasing, no dithering, no soft edges.** Diagonals are
  staircased in the source; `scale2x` (AdvMAME2x) turns the staircase into
  real diagonal pixels on the way up to 32. Nothing is blurred.
- **Limited, warm, earthy palette.** Browns, creams, soft blues and
  greens -- classroom colours, not neon. Aim for **~16 colours per
  sprite**; the forge shows a count and warns past ~24. This is a target,
  not a hard limit. The curated set lives in `tools/palette.json` and
  loads as the forge's default swatches.
- **Chibi.** Oversized head, small simplified body. `draw_char()` builds a
  32×48 frame at that proportion.
- **Straight-on / very slight top-down.** Not isometric, not 3D-rendered.
- **Transparent background.** No baked drop shadow in the sprite -- the
  game adds a shared contact shadow at runtime; flat items (a stain, a
  held object) opt out.

## The grid

- **`TILE = 16`** art-space pixels per room tile in `make_art.py`;
  everything is Scale2x'd to **32** on disk, which is what the game shows.
- A character sheet is **9×4 cells of 32×48** = one **288×192** PNG (4
  walk frames, 1 seated, 4 one-shot poses; four facings). Since the Sept
  2026 pixel-grid pass each frame is built at 32×48 for the face detail,
  then quantised to 16×24 and Scale2x'd back, so the cast shares the
  furniture's texel size. The fine face survives only in the 96×96
  portrait bust.
- Furniture and items are authored small (canvas sized to the object) and
  Scale2x'd once at the write site.

## What this style note does NOT ask for

- A restyle of the ~40 sprites already shipped -- that is a separate art
  pass, not a rule.
- Migrating the generators' ~60 ad-hoc palette constants onto
  `palette.json` -- the file is authored *from* those constants, not
  wired *into* them.
