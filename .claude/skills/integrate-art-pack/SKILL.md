---
name: integrate-art-pack
description: Bring a newly purchased/downloaded art pack (itch.io-style, e.g. LimeZu) into EduSystem -- inventory it, read its licence, map what can be used directly, import it through the manifest tools, and note what it teaches the procedural generators. Use when the user says they bought or downloaded a new art pack, or asks to add more of a pack's art to the game.
---

# Integrating a new art pack

**Read `docs/ART_STYLE_REFERENCE.md` FIRST, in full.** It is the living record of
every pack studied, every licence, the measured facts about LimeZu's art, and the
pitfalls already hit. Update it; do not replace it.

## Where things stand (Oct 2026)

The owner wants the LimeZu look and asked for "as much as possible" of the packs in the
game. So the rule that used to live here ("characters are style reference only") is
**reversed**: props, the room shell, the whole cast and their HUD faces come straight from
the *Modern Interiors / Office / UI* packs. What a pack does not contain stays procedural
(`make_art.py`, `make_items.py`, `make_ui.py`), and the pack's measured technique becomes
the spec for conforming that generator output (see "Step 5").

Tools (all Pillow-only, all read the packs IN PLACE from their zips -- the licences forbid
redistributing them, so a pack is never copied into the repo, only finished sprites are):

| Tool | Job |
|---|---|
| `tools/limezu.py` | pack discovery (`$LIMEZU_DIR`, `tools/limezu_path.txt`, Desktop, Downloads), `owned_names()`, `same_pixels()` |
| `tools/import_limezu.py` | props / fixtures / hats <- `tools/limezu_manifest.json` |
| `tools/limezu_room.py` | the 18 `tile_*.png` <- `tools/limezu_room.json` |
| `tools/limezu_chars.py` | character sheets + HUD busts <- `tools/limezu_cast.json` |
| `tools/limezu_ui.py` | UI pieces needing "their frame, our glyph" |

## Step 1 -- locate, inventory, and read the licence

Find the zip (Desktop / Downloads). **Do not extract it whole** -- list it:

```python
import zipfile, collections, os
zf = zipfile.ZipFile(path)
names = [n for n in zf.namelist() if not n.endswith("/")]
print(collections.Counter(n.split("/")[0] for n in names))
```

Packs repeat the same art as sheets, as "singles", in shadowed / shadowless / black-shadow
variants and at 16/32/48 px -- count UNIQUE sprites, not entries. **Read the licence file
in full and record it** in the licence table in `docs/ART_STYLE_REFERENCE.md`. Terms differ
by pack: LimeZu's FREE editions are non-commercial and must never be used in a Steam game;
the full ones allow commercial use, forbid redistribution, and require credit (the credits
page names the artist and a suite section asserts it).

## Step 2 -- look before you choose

Build contact sheets (a shelf-packed grid of every candidate at 3x, each labelled with its
number) and LOOK. A keyword grep misses things and a thumbnail lies about scale. Prefer the
`Shadowless` singles (the game casts its own contact shadow). Work from the `16x16` folder
and double with NEAREST -- LimeZu's own 32x32 folder is exactly that.

## Step 3 -- props and tiles: `limezu_manifest.json`

Add an entry (`ref` = `theme#number`, or a `sheet`+`rect` cut, or a `join`), run
`python tools/import_limezu.py <name>`, then `godot --headless --path . --import`. Check the
real size against the item's footprint (`w` in `data/balance.json`) -- a prop is anchored by
its BOTTOM edge, so top/bottom transparent rows are trimmed; use `"trim": "xy"` for narrow
things so the contact shadow is the right width. Wall-hung items are `flat`. If the name had
a `tools/sprites/<name>.txt` hand source the importer archives it to
`tools/sprites/_replaced_by_limezu/` (the suite insists a live `.txt` matches its PNG).

## Step 4 -- people: bake, don't composite at runtime

Check the three things that decide whether a pack's characters can be used:

1. **Proportions** -- chibi? (Modern Interiors: 16 wide x ~22 tall, kids ~19; the game's cell
   is 16x24 art-px, so the bottom 24 rows of a 16x32 LimeZu cell, doubled, IS the cell.)
2. **Poses** -- the game needs a 4-direction walk, a seated frame and four one-shots
   (handoff, chat, jump, sad). A pack rarely has them; derive the missing ones from the idle
   frame (`limezu_chars.py` does: sit raised, paper held out, turned head, raised, sunk head).
3. **Architecture** -- a layered paper-doll pack is fine: stack the layers offline and save
   ONE flat sheet (18x4 for LimeZu: 9 poses, the pack's 6 walk frames, a slump, two blinks). The game never composites at runtime.

Skin/hair that the pack lacks (black hair, deep skin) come from a colour **ramp**: rank the
layer's fill colours by brightness and re-map them onto a target ramp, keyline untouched.

## Step 5 -- what the pack teaches the generators

For the parts of the game the pack does NOT cover, zoom 16x on a few of its pieces and
write the measurable answers into the "Measured facts" list in `ART_STYLE_REFERENCE.md`:
keyline colour, tones per material, how shading is structured (per surface, not
silhouette), grain, seam treatment. Then change ONE generator helper at a time, regenerate
a handful of sprites, and diff before/after (see the generator plan in the vault).

## Verify (this is where it went wrong before)

- Before AND after: `Take a Screenshot.bat <screen>` for every named screen
  (`tools/shot.gd`); delete `user://edusystem_SHOT_save.json` before each shot or the day
  drifts and the comparison lies. Look for sprites that vanished or float -- a constant tuned
  to the old art's height (the mentor room's pupil offset, hat nudges, the bubble's offset)
  breaks silently and no test asserts it.
- Run the suite and then **grep its log for `SCRIPT ERROR`** and read the assertion COUNT. A
  runtime error inside a section aborts that section, the suite still prints PASSED, and only
  the count falls (`tests/assertion_count.txt` -> "COUNT DROPPED").
- `python tools/check_docs.py` after anything that changes the count; `Simulate a Term`'s
  contract rows (0.63C / 0.72C / 0.97A) must not move; run the whole-term walkthrough.
- **Compare images with `limezu.same_pixels(a, b)`** (premultiplied bytes), NOT
  `ImageChops.difference(a, b).getbbox() is None` -- on an RGBA image `getbbox()` looks only
  at alpha, so a recolour that keeps the silhouette reads as "no change" and the file is
  never rewritten. (This skill used to recommend the broken check.)
- Commit in tiers (props, room, cast, UI) so any one can be reverted; stage explicit paths --
  a fresh worktree rewrites `.import` noise. Don't push until the user has looked.

## Environment notes

- Godot may be at `~/Applications/Godot.app/Contents/MacOS/Godot` on the Mac; the repo's
  `tools/godot_path.txt` holds the Windows path. A fresh worktree has no `.godot/` cache --
  run `--headless --import` before anything else. Never run two Godot processes at once.
- The Godot editor, if opened on the Mac, rewrites `project.godot` and has been seen to drop
  the `[audio]` bus-layout line and `window/size/resizable`; never commit that diff.
