# AI art prompts (Canva image generator) — for the art pass

Prompts to run through Canva's built-in image generator (Gemini-backed),
no API key, no per-call cost — matches the "no API keys, that costs
money" constraint. Written 2026, against the real current `art/`
catalog (`docs/ART_CATALOG.md`).

## Read this first — what AI generation is actually good for here

**Do NOT use it for the animated character sheets** (`player.png`,
`student_a..h.png`, `inspector.png`, `principal.png`). Those are
9-column × 4-row sprite sheets (walk cycle, sit pose, four one-shot
poses, four facings) where every cell has to be the *same character*,
same proportions, same palette, precisely aligned to a 32×48 grid.
Diffusion-based generators (Canva/Gemini included) can't reliably hold
a character consistent across a multi-cell grid like that — you'd get
eight subtly different-looking kids, not one animated one. **The
existing procedural pipeline (`tools/make_art.py`) already does this
correctly, for free, and stays** — a character is a palette through one
shared `draw_char()`, not separate artwork, and that's the right tool
for exactly this job.

**Use AI generation for single, static images** instead — furniture,
room tiles, hats, and UI/backdrop art. Each of those is one flat icon
or texture, which is what these tools are actually good at.

**Every image will need light post-processing after Canva generates
it** — cropped to the item's real footprint, background removed to
transparent, and downscaled/aligned to Godot's tile grid (`TILE = 32`
px). Don't expect a pixel-perfect drop-in straight out of Canva; expect
a good starting image to clean up. Hand me the raw exports and I'll
handle the cropping/transparency/import side.

## The master style guide (paste at the start of every prompt)

> Retro Game Boy–style pixel art, chibi proportions (oversized head,
> small simplified body when a character is present), flat and
> unshaded except for one consistent light source from the upper
> left, a limited warm/earthy palette (browns, creams, soft blues and
> greens — classroom colors, not neon), no gradients, no anti-aliasing,
> no soft/blurred edges, no drop shadows baked into the image, crisp
> hard pixel edges, transparent background, viewed from a straight-on
> or very slight top-down angle (matching a simple 2D game, not an
> isometric or 3D-rendered look), no text or watermark anywhere in the
> image.

Every prompt below starts with that paragraph, then adds the
item-specific description.

## Furniture & shop items (one static icon each)

Full current list, from `data/balance.json`'s item table — all 39.
Use the template: **[style guide] + "[Item], a single piece of
classroom furniture, [short description]. Isolated on a transparent
background, no room or floor visible around it."**

Learning/decor:
`bookshelf`, `lab_bench`, `art_easel`, `rug`, `plant`, `stool`,
`beanbag`, `bench`, `floor_cushion`, `side_table`, `cabinet`, `crate`,
`globe`, `abacus`, `microscope`, `whiteboard`, `reading_nook`,
`maths_tiles`, `music_corner`, `lamp`, `water_cooler`, `radiator`,
`coat_hooks`, `wall_clock`, `alphabet_frieze`, `fish_tank`,
`class_banner`, `pot_of_pens`

Consumables (same visual treatment, they're just not placed in the
room): `coffee`, `sticker_chart`, `bake_sale`, `photocopies`

Fixed room furniture (bigger, still one static icon each): `desk`,
`chair`, `table`, `podium`, `bell`, `teacher_desk`, `noticeboard`,
`supply_shelf`

### Worked examples (calibrate style on these three first)
1. **`bookshelf`**: *[style guide] + A short wooden bookshelf, three
   shelves, a mix of colorful book spines standing upright, sturdy and
   simple. Isolated on a transparent background, no room or floor
   visible around it.*
2. **`globe`**: *[style guide] + A small classroom desk globe on a
   wooden stand, blue and green continents, simple and iconic rather
   than geographically detailed. Isolated on a transparent background,
   no room or floor visible around it.*
3. **`beanbag`**: *[style guide] + A round, squashy beanbag chair,
   slightly deflated/sat-in shape, one solid warm color. Isolated on a
   transparent background, no room or floor visible around it.*

Generate these three first, look at them next to the existing
procedural room art, and confirm the palette/style actually reads as
"the same game" before running the other 36 — cheaper to catch a style
mismatch on three images than forty.

## Room tiles (textures, tileable)

`tile_floor_a0..a3`, `tile_floor_b0..b3` (two floor families, four
variants each so a floor doesn't read as one stamped texture),
`tile_wall_top0/1`, `tile_wall_side`, `tile_wall_bottom`,
`tile_door_top/bottom`, `tile_window_l0/1`, `tile_window_r0/1`.

**Prompt template**: *[style guide] + A seamless, tileable [floor/
wall] texture for a classroom, [description]. Flat top-down/front-on
view, no perspective distortion, edges designed to repeat seamlessly
when placed side by side.*

Example — `tile_floor_a0`: *[style guide] + A seamless, tileable
classroom floor texture — warm beige linoleum tile with a very subtle
scuff/wear variation. Flat top-down view, no perspective distortion,
edges designed to repeat seamlessly when placed side by side.*

Tiling is the hard part for an AI generator — expect to need several
attempts, or to make one tile and hand-duplicate/vary it slightly
yourself for the "variant" files (`a0`–`a3`) rather than generating
four independently.

## Cosmetics (hats — one flat icon each)

`cap` (a beanie, not a baseball cap — a brim reads as a floating block
at this scale), `bow` (a bow-tie shape), `wizard` (pointed hat, star
tip).

**Prompt template**: *[style guide] + [Hat], viewed as if sitting on
top of a round chibi head (the head itself not shown), from directly
in front. Isolated on a transparent background.*

## UI & backdrop art (the highest-value pieces to actually get right)

- **`logo.png`** — the title screen wordmark. This is the one image
  worth the most iteration, since it's the first thing anyone sees on
  a store page. Prompt: *[style guide, but allow a bit more color
  richness here] + A game logo reading "EDUSYSTEM" in a bold, rounded
  pixel-art font, playful and readable at small sizes, a small chalk/
  schoolhouse motif incorporated. Transparent background.*
- **`title_bg.png`** — title screen backdrop. Prompt: *[style guide] +
  A cozy, empty classroom at dusk, chalkboard, rows of empty desks,
  warm lamp light, viewed straight-on. No characters present. Slightly
  more atmospheric and less flat than a gameplay icon — this is a
  mood backdrop, not an interactive object.*

Do **not** regenerate `bubble_q.png`, `paper.png`, `shadow.png`,
`dust.png`, `mess_trash.png`, `mess_spill.png`, or `poster_abc.png` —
small functional/effect assets and one deliberate hand-drawn exception,
not worth AI-generation effort.

## Workflow once you have exports
1. Drop the raw Canva exports somewhere I can read them (a folder in
   the repo, or just hand them to me directly).
2. I crop/resize/clean transparency and run them through Godot's
   import step (`godot --headless --path . --import`) — the same
   seam this project has hit before: a PNG that exists on disk but was
   never imported can't be loaded, and the suite now catches that by
   actually loading every texture.
3. `Take a Screenshot.bat` on the affected screens to confirm it reads
   right in the real game, not just that the file imported.
