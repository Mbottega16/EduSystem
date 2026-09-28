# Lesson-craft styles

`Game.CRAFT_STYLES` names the flavour a crafted lesson gets locked to on
its first craft (`Game.commit_lesson_craft()`), rolled through `Game.rng`
so it is as deterministic as everything else. Cosmetic only, on purpose:
every style runs through the exact same `Game.craft_work_mult()` /
`craft_stall_mult()` as every other one, so a crafted lesson reads as
"Algebra II — Visual" rather than a bare level number (the naming from
the 2026-08-24 vision interview: "Algebra II, Visual Lesson, v15").
Whether a style should ever do something mechanically different, or stay
a name, is still an open design question (see
`docs/relay/turns/0011-claude.md`'s NEED FROM YOU) — this doc does not
decide that either. It names and documents the five styles as they
stand today.

## The five styles

| Style | Colour | Hex | Asset stem |
|---|---|---|---|
| Visual | teal | `7fd0c9` | `visual` |
| Hands-On | orange | `e2a15e` | `hands_on` |
| Discussion | rose | `e296b0` | `discussion` |
| Story-Based | indigo | `9b93e0` | `story_based` |
| Game-Based | chartreuse | `c7d96b` | `game_based` |

Each hex lives in `scripts/ui/hud.gd`'s `CRAFT_STYLE_COLOUR`, read
through `craft_style_colour()` — the same shape as `STRAND_COLOUR` /
`strand_colour()` a few screens over, deliberately: one colour per
category, and the same hue wherever that category's name is printed.
The five hues were chosen to sit apart from the existing UI palette
(`C_ROOM`/math blue `8ab4f8`, `C_LESSON`/ela green `9fd89f`, `C_COIN`/
science amber `f2c66b`, `C_KNOW`/social violet `d0a3e8`, `C_BAD` coral
`d08a86`) at the same pastel lightness/saturation, so a style reads as
its own thing next to a strand mark or a good/bad line rather than
colliding with what those colours already mean.

## UI appearance

A style's colour shows up everywhere its name is currently printed —
no new panel, border or icon was added; the panel-budget rule in
`CLAUDE.md` means a new visual element gets fit-tested with a real
screenshot before it ships, and this pass stayed inside rows that
already exist:

- **The lesson-crafting tab** (`hud._render_craft()`): once a lesson's
  `craft_level` is above zero, its progress bar (the row of `█`/`░`
  glyphs) tints to its style's colour instead of the flat `C_LESSON`
  green every other row uses. A lesson with no craft yet still shows
  the bar in `DIM`, unchanged.
- **The "still in the oven" line**, on the crafting tab while a craft
  is pending: the style name prints in its colour, nested inside the
  line's own `C_KNOW` wrap.
- **The day report**, on the day a craft resolves (win or lose): same
  treatment, nested inside whichever colour (`C_GOOD`/`C_BAD`) the
  surrounding sentence already uses. `test_lesson_crafting()` in
  `tests/run.gd` strips every `[color=...]` tag before checking the
  result sentence carries no digit — nesting one more tag inside
  another doesn't change that; the same regex strips both.

## Asset-naming convention (not built yet)

No art exists per style yet — `craft_style()` returns a bare string,
never an icon. If a style ever gets one, the way each curriculum
STRAND already has a 16×16 mark (see `docs/ART_CATALOG.md`'s
`icon_ela.png`/`icon_math.png`/`icon_science.png`/`icon_social.png`
row), it should follow the same shape:

- **File:** `art/icon_craft_<stem>.png`, 16×16, one flat mark per
  style, coloured in that style's own `CRAFT_STYLE_COLOUR` hex — e.g.
  `art/icon_craft_hands_on.png`.
- **Stem:** the `Asset stem` column above — the style's own display
  name, lowercased, with every space and hyphen turned into `_`.
- **Path table:** written out as a literal `res://` string per entry
  (a `CRAFT_STYLE_ICON_PATH` dict, the same shape as `hud.gd`'s
  `STRAND_ICON_PATH`), not assembled from the stem at runtime — the
  art audit scans source for `res://` literals, and a path built by
  string interpolation is invisible to it. `STRAND_ICON_PATH`'s own
  comment carries the same warning, for the same reason.
- **Hand-edited source, if any:** `tools/sprites/icon_craft_<stem>.txt`,
  the convention every other hand-drawn sprite in `tools/sprites/`
  already uses.

## Where this lives in code

| | |
|---|---|
| `Game.CRAFT_STYLES` (`scripts/autoload/game.gd`) | the five names, in the order a fresh craft can roll them |
| `Game.craft_style(lesson_id)` | the style a lesson is locked to, or `""` if never crafted |
| `hud.gd`'s `CRAFT_STYLE_COLOUR` / `craft_style_colour()` | the palette table above, and the lookup that reads it |
