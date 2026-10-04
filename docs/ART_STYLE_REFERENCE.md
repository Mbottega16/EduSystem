# Art style reference — target look, and what we've learned

A living document, not a one-time writeup. Every time the user buys a new
reference pack, the `integrate-art-pack` skill (`.claude/skills/`) reads
this file first, studies the new pack, and comes back and UPDATES it —
so understanding compounds across packs instead of resetting each time.

> **Status, 2026-10-02 -- read this first.** The owner then bought the full
> LimeZu *Modern Interiors*, *Modern Office* and *Modern UI* packs and asked for
> "as much as possible" of them in the game. The decision below ("characters are
> style reference only") was therefore REVERSED for everything those packs
> actually contain: the props, the room shell, the whole cast and their HUD
> faces now come straight from the packs through `tools/import_limezu.py`,
> `limezu_room.py`, `limezu_chars.py` and `limezu_ui.py` (see "How the game uses
> the packs"). The procedural generators are kept, and what is left of this file's
> technique findings is now the spec for the pieces the packs do NOT have --
> 19 shop items, the bell, the book/UI, the logo and the backdrop.

**The goal, in the user's own words:** "I want the art style to be what
limezu uses here. I like this art. I want it exactly like this... WE
have to be the ones to adapt to conform the art style."

**The chosen approach (confirmed with the user, Oct 2026):**
reverse-engineer the TECHNIQUE into `tools/make_art.py`'s procedural
pipeline, not import assets directly for characters. Reasons this won,
over adopting their actual layered asset files:
- Keeps EduSystem's chibi proportions (big head, small body) — a
  documented, load-bearing design choice every character inherits.
  Switching to the pack's normal RPG proportions would mean redrawing
  every character from scratch in the new proportions.
- EduSystem needs poses (sit, handoff, chat, jump, sad) the farm pack
  doesn't have at all — it only has idle/walk/harvest/dig/water/chop/
  fish. No amount of asset reuse covers those; they'd have to be
  hand-drawn in matching style regardless.
- The farm pack is a true layered paper-doll system (separate Body/
  Hair/Outfit/Accessory PNGs composited at runtime). EduSystem loads one
  flat pre-baked PNG per character. Adopting their asset pipeline
  directly means building new Godot-side layer-compositing code, not an
  art change.
- Staying procedural keeps every existing advantage: deterministic,
  license-clean, retune-by-editing-a-number, same poses we already have.

Direct asset reuse is still fair game for single-icon PROPS (furniture,
containers) — see "Direct-use props" below — because those have none of
the above problems: one flat sprite, no pose, no proportion mismatch.

---

## Confirmed technique findings (limezu's "Modern Farm" pack)

Studied by zooming into reference pieces at 16x+ (`Crate_Brown_Empty`,
`Wooden_Table`, `Basket_Empty`, `Stool_Wood_1`, all from the 32x32
singles export). Compared directly against EduSystem's current
`rim_light()`/`finish()` in `tools/make_art.py`.

1. **Outline is cool, not warm.** Their line colour reads as a dark,
   desaturated blue-slate (roughly in the `#2d2b3d` family) — a COOL
   tone, deliberately contrasting against the warm wood/skin fills it
   borders. EduSystem's `LINE = (36, 26, 18)` is warm dark brown. This
   is one of the most visually distinctive differences between the two
   styles side by side — worth testing a cool-shifted outline option.

2. **Shading follows per-surface form, not silhouette distance.** This
   is the big structural difference. EduSystem's `rim_light()` shades
   based on a pixel's distance from the sprite's OUTER transparent
   boundary — one light pass over the whole silhouette. Limezu's crate
   shades each PLANK independently (its own light-top/dark-bottom
   gradient), and the round basket shades by ANGLE around the ring
   (brightest upper-left, darkest lower-right, following the curve's own
   implied surface normal) — not by distance from the basket's outer
   edge. A silhouette-edge rim light can never reproduce "each plank has
   its own highlight," because it has no idea where the internal plank
   boundaries are.
   - Practical translation: furniture draw routines already build
     objects out of discrete `rect()` calls per surface (a plank, a
     panel, a leg) — shading needs to happen PER RECT, not once at the
     end over the whole flattened image. `rrect`-based curved forms
     (baskets, barrels) need an angular gradient, not a radius-distance
     one — `ring()` already exists as a starting point.

3. **Visible grain/noise texture within a fill, not a flat colour.**
   Each plank has scattered pixel-level colour variation (small warm/
   cool flecks, not a smooth gradient, not fully random either — reads
   as curated noise, similar in spirit to how EduSystem's own floor
   tiles already do seeded speckle). EduSystem furniture fills
   (`WOOD`/`WOOD_L`/`WOOD_D` flat `rect()` blocks) have none of this.

4. **More value steps per surface than we use.** A single limezu plank
   reads as roughly 3-4 distinct tones (a bright top-edge highlight line,
   a noisy mid-tone body, a darker lower band, plus the dark joint/seam
   between planks acting as an extra shadow line) where EduSystem
   furniture currently gets 2-3 flat blocks total for the WHOLE object.

5. **Dark joints double as both structure and shadow.** The seams
   between crate planks aren't just a outline-coloured 1px line — they're
   a distinct dark reddish-brown BAND (several px), reading as both "this
   is where one board ends and another begins" and "this crevice is in
   shadow." EduSystem's furniture has no equivalent — surfaces that
   should read as multiple boards currently read as one flat block.

## What this session actually shipped (Oct 2026, partial progress)

`second_band()` / `rim_light2()` / `finish_rich()` in `tools/make_art.py`
— a second, softer shading ring one pixel in from the silhouette edge.
This is a modest step in the right DIRECTION (more tonal steps than a
single hard edge) but it is still silhouette-edge-based, not per-surface
— it does NOT yet implement finding #2 above, the biggest structural
gap. Applied to: `window_seat`, `low_shelf`, `display_rack` (make_items.py)
and all 17 characters + 16 portraits (make_art.py). Characters/portraits
also don't yet have the cool-outline or grain-texture treatment.

**Not yet done — the real next steps, in priority order:**
1. A per-rect/per-surface shading helper (finding #2) — this is the
   single highest-leverage change, since it's what actually produces
   "each plank/panel has its own highlight" instead of today's one
   whole-object rim light.
2. Cool-shifted outline option (finding #1) — cheap to test, could be
   as simple as a new `LINE_COOL` constant and an opt-in `outline()` arg.
3. Grain/noise texture pass (finding #3) — likely a new helper akin to
   `floor_tile()`'s existing seeded-speckle approach, applied to large
   flat fills.
4. Angular (not radial) shading for curved/round forms (finding #2b).

## Direct-use props (license-clean, no style problem)

Single-icon sprites transfer fine as-is (crop/resize/recolour as
needed) because EduSystem furniture is already one-flat-sprite-per-item,
same convention the pack uses. Shortlist confirmed from the FULL 1102-
file single-exports pass (not just a keyword grep) — see conversation
history for the full category breakdown; everything not listed here
(fences, trees, crop-growth stages, animal infrastructure, market-stand
signage, farm buildings, crafting-station tool props) is unambiguously
farm-specific with no classroom equivalent:

Pencil, Pencils Can, Handbook, Photo Frame, Stool (×2 variants), Wooden
Table, Box, Crate, Wood Box, Basket, Color Can, Sign Blank, Trunk/Chest
(closed+open, 2 sizes — good `cabinet` fit), Scale (market-stand weighing
scale — good math/science-corner fit).

**2026-10-03, three more limezu packs (Modern Office Revamped, Modern
Interiors, Modern UI) — catalogued by three parallel background Agents
per this doc's own skill, then spot-verified by hand (see "Packs studied"
below for the hit-rate numbers). Combined direct-use shortlist, all
pixel sizes agent-verified by opening the file, not assumed from its
name:**

From **Modern Interiors** (`moderninteriors-win.zip`) — the standout
pack, because it has an actual "Classroom and Library" theme category
(75 items) plus an "Art" category (46 items). Verified by hand against a
contact sheet of all 75 Classroom/Library items, not just the agent's
word: bookshelves (~25 colour/stock variants — strong `bookshelf`
upgrade), a noticeboard with pinned notes (`noticeboard`), an
alphabet/colour chart grid (`alphabet_frieze`/`sticker_chart`), two
globe sizes (`globe`), a wood-frame blackboard and a wheeled green
chalkboard (both `whiteboard` candidates), a world map poster (decor/
`class_banner` candidate), a circulation/checkout desk with a computer
(`teacher_desk` upgrade), plus from the Art category: potted plant
(`plant`), round stool (`stool`), easel with canvas (`art_easel`), bench
(`bench`), water cooler (`water_cooler`). **Two genuinely NEW items with
no current EduSystem equivalent:** a short and a tall library ladder.

From **Modern Office Revamped** — ~55-60 of 339 true-unique icons are
classroom/office relevant (a ~17% hit rate, 9-10x the farm pack's ~2%,
because an office theme fits a classroom-management game far better
than a farm theme does). Direct swaps: office chair (`chair`), desk lamp
(`lamp`). **New items, no current equivalent:** flat monitor, printer,
server rack, telephone, AV gear (all "tech" — EduSystem currently has
NO tech items at all), framed certificate/diploma and a 2-seat sofa
(principal's-office/staff-room decor), a backpack (student-cubby prop),
and a robotic-arm desk rig (unclear exact identity — possibly a STEM
"robot kit" learning item alongside `microscope`/`abacus`, flagged by
the agent as uncertain rather than guessed).

From **Modern UI** — mostly style-reference, not direct-use (nothing is
pre-cut, all packed into atlas sheets, and the visual language — slate/
navy outlines, gold-highlight buttons — doesn't match EduSystem's warm-
cream chalk style). Two things worth building toward: a mood/smiley icon
set (fits the game's hard rule against showing raw numbers for anything
judging a child) and segmented/smooth progress bars (a compact non-
numeric fill indicator, relevant given the HUD's 11-row panel budget).
Neither exists in EduSystem today.

**Characters, across both Modern Farm and Modern Interiors now:** same
verdict both times — style-reference only, not direct swap-in. Modern
Interiors' characters lean chibi already (closer to EduSystem's own
proportions than Modern Farm's), and its "Premade Character" sheets
include a "gift" pose (handing an item out — a real analog for
`POSE_HANDOFF`) and a "phone" pose (loose analog for `POSE_CHAT`).
Still no jump-for-joy or sad-slump equivalent in either pack. Both packs
are architecturally layered paper-doll systems requiring new Godot-side
compositing code to use directly, which is the real blocker, not the
art itself — this has now shown up twice, worth treating as the default
expectation for any future character pack rather than re-verifying from
scratch each time.

**Decision for props, reconfirmed 2026-10-03:** redraw in-house inspired
by these shapes/compositions, don't crop-and-paste the actual PNGs —
same reasoning the user gave for the Modern Farm bench/crate/cabinet
overlap (license-clean, stays consistent with the scale2x/outline/
rim-light pipeline, stays easy to retune). The shortlist above is a
reference for WHAT to draw, not files to import.

## License (per pack — re-check every new one)

limezu "Modern Farm": edit/use freely in commercial or non-commercial
projects; cannot resell or redistribute the assets themselves; credit
to limezu.itch.io appreciated.

limezu "Modern Office Revamped": same terms as Modern Farm (freely
use/edit, no resale, credit appreciated).

limezu "Modern Interiors" (full/paid version): same permissive terms,
but credit to limezu.itch.io is REQUIRED, not just appreciated. The
free version (`Modern_Interiors_Free_v2.2.zip`) is non-commercial use
only and confirmed a pure content subset of the full version — no
reason to use it once the full pack is available.

limezu "Modern UI": credit REQUIRED if anything is used directly
(cropped/lightly edited), not just appreciated. Since the conclusion
above is style-reference-only, this mostly doesn't bite, but matters if
any mood/progress-bar asset is ever cropped rather than redrawn.

EduSystem's HUD already has a credits screen, so satisfying a
"required" credit is a one-line addition whenever it's actually needed
— not done yet since nothing has been used directly yet.

## How the game uses the packs (Oct 2026)

Nothing from a pack is committed except the finished sprites the game uses. The
packs are read **in place out of their zips** (`tools/limezu.py` finds them in
`$LIMEZU_DIR`, `tools/limezu_path.txt`, `~/Desktop`, `~/Downloads`); the licence
forbids redistributing them.

| Importer | Owns | Driven by |
|---|---|---|
| `tools/import_limezu.py` | props, fixtures, hats -- one PNG each in `art/` | `tools/limezu_manifest.json` (`props`): a ref like `classroom#6` = the numbered *shadowless* single #6 of that theme, or a `sheet`+`rect` cut, or a `join` |
| `tools/limezu_room.py` | the 18 `tile_*.png` the room is stamped from | `tools/limezu_room.json` (which floor block, which wall set, which door/window) |
| `tools/limezu_chars.py` | the 17 character sheets (9x4 cells of 32x48) and their 96x96 HUD busts | `tools/limezu_cast.json` (body/eyes/outfit/hair/accessory ids + colour ramps) |
| `tools/limezu_ui.py` | UI pieces that need "their frame, our glyph" (the stuck "?" bubble) | the builders in the file |

* **The generators stand down.** `make_art.hand_edited()` unions in
  `limezu.owned_names()`, so `make_art.py`, `make_items.py` and `forge_art.py`
  skip every owned name exactly as they skip a hand-drawn `tools/sprites/*.txt`.
  To take the old procedural art for a sprite back: delete its manifest/cast entry,
  move its archived `.txt` out of `tools/sprites/_replaced_by_limezu/` if it had one,
  and run the generator.
* **Scale.** Everything is taken from the `16x16` folders and doubled with NEAREST --
  checked byte-for-byte equal to LimeZu's own `32x32` folders. Use the **Shadowless**
  singles: the game casts its own contact shadow, and the "shadowed" ones are just a
  1px translucent row anyway.
* **Anchoring.** A prop sits by its BOTTOM edge, so a single is trimmed top and bottom
  (not sideways -- LimeZu objects are drawn tile-aligned, so the canvas width keeps
  them centred); narrow things use `"trim": "xy"` so the shadow width is right.
* **People.** A LimeZu chibi is 16 wide, ~22 tall (a kid ~19), bottom-aligned in a
  16x32 cell -- the bottom 24 rows doubled ARE the game's 32x48 cell. Only the idle and
  walk rows are used; the pack has no front-facing seated pose, no mouths, and no kid
  poses beyond idle/walk/sleep, so sit / handoff / chat / jump / sad are derived from
  the idle frame by small deterministic edits (same for kids and adults).
* **Credit is a licence condition** (limezu.itch.io): the credits page names LimeZu and a
  suite section (`LIMEZU ART`) fails if it stops doing so.

### Measured facts about LimeZu's art (what the generators should conform to)

* Keyline **#3a3a50** (cool slate); a second dark **#46465e**, a lighter line
  **#565972**, a purple accent **#6c5981**. Never pure black, never warm brown.
* A material is **3-4 flat tones plus the keyline** (hair: 3 fills; kid skin: 3 + a
  pink accent), not 2. The soft shadow a fringe casts on a forehead is
  `rgba(0,0,0,0.12)` / `0.31` overlay pixels, not a colour.
* Faces: two dark pixels for eyes, no mouth, a rosy blush, a 16 px-wide head; a kid is
  head-dominant (head 14 of 19 rows).
* Sheets: four directions x six frames in the order **right, up, left, down**; rows =
  header(32px), idle, walk, sleep, sit (side-on), phone, ... A walk's "steps" are frames
  1 and 4 (the figure bobs up 1px).
* The pack's own furniture shading is per surface, with a light top edge and visible
  grain; see findings 1-5 above.

### Pitfalls this work found (do not re-learn them)

* **`ImageChops.difference(a, b).getbbox() is None` is NOT "identical" for RGBA** -- `getbbox()`
  looks at alpha only, so a recolour that leaves the silhouette alone passes as "no
  change". Compare `a.convert("RGBa").tobytes()` (`limezu.same_pixels`). The
  `integrate-art-pack` skill used to recommend the broken check.
* **A GDScript runtime error inside a suite section aborts that section and the suite
  still prints PASSED** -- only the COUNT falls. After every run grep the log for
  `SCRIPT ERROR` and read the count.
* The old mentor room, hats and the "?" bubble all carried constants tuned to the old
  art's heights; swapping art can break a position that no test asserts. Screenshot
  every screen before and after (`tools/shot.gd`; delete
  `user://edusystem_SHOT_save.json` between shots or the day drifts).
* `bubble_q` is TINTED at runtime per reason, so any replacement must be a neutral
  bubble with a dark mark.

## License (per pack — re-check every new one)

| Pack | Commercial use | Edit | Redistribute / resell | Credit |
|---|---|---|---|---|
| Modern Farm | yes | yes | **no** | appreciated |
| **Modern Interiors (full)** | yes | yes | **no** | **required** (limezu.itch.io) |
| **Modern Office (Revamped)** | yes | yes | **no** | appreciated |
| **Modern UI** | yes (not NFT minting) | yes | **no** | **required** |
| Modern Interiors **FREE** | **NO -- non-commercial only** | no for commercial | no | -- |
| Modern Interiors RPG Maker version | not read in full; not used | | | |

The **FREE** edition of Modern Interiors is non-commercial: EduSystem is headed for Steam,
so nothing from it is used (the full pack contains all of it anyway). Record each new
pack's licence here when it is added; terms differ pack to pack.

## Packs studied so far

| Pack | Studied | Verdict |
|---|---|---|
| limezu "Modern Farm" (`artgen.zip`) | 2026-10-02 | Characters: inspiration only (proportions/poses/architecture mismatch). Props: ~20 direct-use candidates out of 1102 files. Technique findings #1-5 above. |
| limezu **Modern Interiors** (full, `moderninteriors-win.zip`) | 2026-10-02 | Used directly: 38 shop items, 6 fixtures (desk, chair, teacher's desk, lectern, noticeboard, cabinet) and 2 hats, the room shell, the whole cast (Character Generator, baked), the "?" bubble frame. A themed *Classroom & Library* set of 75 singles, kid bodies/hair/outfits, 29 hair styles x ~7 colours, 33 outfit groups. |
| limezu **Modern Office Revamped** (`Modern_Office_Revamped_v1.2.zip`) | 2026-10-02 | Used (6 shop items): whiteboard, water cooler, ream of paper, filing unit, rota, sticker board. 339 singles, mostly modular desks and computers. |
| limezu **Modern UI** (`modernuserinterface-win.zip`) | 2026-10-02 | Used: the Portrait Generator (32x32 head portraits in a 10x3 expression grid) for the 16 HUD busts. **Not yet used:** the Style 1/2 panel frames, gamepad glyphs, animated buttons. |
