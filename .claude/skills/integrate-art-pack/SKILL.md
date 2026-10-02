---
name: integrate-art-pack
description: Analyze a newly purchased/downloaded art reference pack (itch.io-style asset pack, e.g. limezu) and work out what to adapt into EduSystem's procedural art pipeline. Use when the user says they bought or downloaded a new art pack, reference pack, or "model" for EduSystem's art, or asks to re-run the art-style analysis.
---

# Integrating a new art reference pack

EduSystem's art is NOT hand-drawn or sourced — every sprite is generated
by Python (`tools/make_art.py`, `make_items.py`, `make_ui.py`), on
purpose, so retuning a colour or a proportion is editing a number and
re-running, not repainting. The user buys reference packs (currently
limezu-style itch.io packs) not to drop their files into the game, but
because they've found the ART STYLE they want EduSystem to look like,
and wants the procedural pipeline adapted to match it as closely as
possible. "I want it exactly like this... WE have to be the ones to
adapt to conform the art style" (user, Oct 2026) — confirmed over the
alternative of adopting the pack's actual asset files directly.

**Read `docs/ART_STYLE_REFERENCE.md` FIRST, in full, before anything
else.** It's the living record of every technique finding from every
pack studied so far. This skill's whole point is that understanding
COMPOUNDS across packs — don't re-derive from scratch what a past
session already worked out. Update that file, don't replace it.

## When this skill fires

The user says something like "I bought another pack," "here's a new
reference," "check out this art style," "I downloaded [name]'s assets,"
or asks you to "relearn" / re-run the style analysis. They may hand you
a new zip, a folder, or just a name/link to look at.

## Step 1 — locate and inventory the pack

Find it (Desktop and Downloads are the usual spots for a fresh
download). Do NOT extract the whole archive — list it first:

```
unzip -l /path/to/pack.zip | head -100          # quick shape
python3 -c "import zipfile; ..."                 # for anything more
  # than a quick look — zipfile + sorted unique basenames is far more
  # reliable than parsing `unzip -l` column output by hand, especially
  # once filenames have spaces (seen first-hand this session).
```

Get the REAL unique file count (big packs duplicate the same file across
a "complete tileset singles" folder AND per-category subfolders — this
session's pack had 2200 listed entries but only 1102 unique basenames).
Read the license file in full — terms vary pack to pack, record them in
`docs/ART_STYLE_REFERENCE.md`'s license table.

## Step 2 — characters: almost always style-reference-only, not direct use

Check three things before concluding otherwise:
1. **Proportions.** View a character sheet. EduSystem is chibi (big
   head, small body) — a deliberate, documented, load-bearing choice
   (`draw_char()`'s own docstring). If the pack's proportions are
   normal/semi-realistic, direct use would look like a different game's
   sprite pasted into this one.
2. **Pose vocabulary.** EduSystem needs: 4-direction walk cycle, a SEATED
   pose, and four one-shot poses (handoff, chat, jump, sad) — see
   `FRAMES`/`SIT_FRAME`/`POSE_*` in `tools/make_art.py`. Most reference
   packs are built for a different genre (farming, combat, whatever) and
   simply don't have equivalents for these. Confirm by checking the
   pack's own animation-guide image if it has one.
3. **Architecture.** Is it a single flat sprite sheet per character, or
   a LAYERED system (separate body/hair/outfit/accessory files meant to
   be composited at runtime)? EduSystem loads one pre-baked PNG per
   character (`scripts/actors/*.gd` + `art/<name>.png`). A layered pack
   would need new Godot-side compositing code to use directly — that's
   an engineering project, not an art swap.

If any of these three don't line up (they almost never fully do), the
character art is STYLE REFERENCE ONLY: study its technique (step 4
below) and apply that technique to `draw_char()`, not its files.

## Step 3 — props/furniture: the real direct-use candidates

Single-icon sprites (one object, no animation, no pose) transfer much
better, because EduSystem furniture is ALREADY one-flat-sprite-per-item
(`tools/make_items.py`'s `ITEMS` dict, `docs/ART_CATALOG.md`'s
furniture table). For each candidate:

1. Cross-reference against `docs/ART_CATALOG.md`'s furniture/item list —
   is there a real functional match (a stool is a stool regardless of
   theme; a crop basket is not a classroom item)?
2. Check its ACTUAL pixel size, not its filename — these packs often
   name every file by their tile-grid unit ("_32x32") regardless of how
   many tiles the actual sprite spans. Open it and check `.size`.
3. Flag licensing: fine to use/edit per most itch.io packs like this,
   but never assume — read THIS pack's license file, and if direct
   files are ever used as-is (not redrawn), credit belongs in the game's
   credits screen.

Do a FULL pass, not just a keyword grep — grep misses things (this
session's keyword pass missed a Trunk/Chest and a market-stand Scale
that only showed up on reading the complete list). Expect the vast
majority of any themed pack (90%+) to have zero classroom/EduSystem
equivalent — that's normal, not a sign the search was incomplete.

## Step 4 — reverse-engineer the technique (the actual point of this skill)

This is where the real work is, and where `docs/ART_STYLE_REFERENCE.md`
gets its value added. Don't eyeball a thumbnail — extract a few clean,
representative reference pieces and zoom in HARD:

```python
from PIL import Image
im = Image.open('reference.png').convert('RGBA')
im.resize((im.width*16, im.height*16), Image.NEAREST).save('zoom.png')
```

Pick 3-4 varied references (something rectangular/planked, something
round/curved, something with a clear light source) — then view each
zoomed crop and work through these questions explicitly, don't just
absorb a vibe:

- **Outline colour temperature.** Pure black? Warm dark brown (what
  EduSystem currently uses, `LINE`)? Cool dark slate/navy (what limezu
  uses)? Sample actual pixel values if unsure.
- **Shading structure: silhouette-edge or per-surface?** Does the light/
  dark gradient follow the OUTER edge of the whole object (what
  EduSystem's `rim_light()` does), or does each distinct physical
  surface (a plank, a panel, a curve) get its own independent gradient?
  This is usually the single biggest structural difference from
  EduSystem's current approach — check it specifically, don't assume.
- **Flat fill or textured/noisy fill?** Smooth gradient, dithered,
  speckled/grainy, or genuinely flat? Compare to EduSystem's own
  seeded-speckle floor tiles (`floor_tile()`) as a reference point for
  what a "textured" EduSystem asset already looks like.
- **How many distinct value steps per surface?** Count them on one
  plank/panel/limb. EduSystem furniture currently gets 2-3 (a base fill
  plus `finish()`'s single rim-light band); compare directly.
- **Do construction seams (joints, boards, panel edges) get their own
  dark line distinct from the outline?** Or does everything just share
  the one outline colour?

Write the answers into `docs/ART_STYLE_REFERENCE.md` under "Confirmed
technique findings" — append to the existing numbered list, don't
restart it, and note which pack each finding came from if techniques
start to diverge between packs.

## Step 5 — translate findings into the generator, small and reviewable

Don't rewrite `draw_char()`/furniture routines wholesale in one pass.
Pick ONE finding, build ONE new opt-in helper function in
`tools/make_art.py` (following the existing `rim_light()`/`finish()`
pattern — a new function, old callers unchanged), apply it to a SMALL
number of items first, regenerate just those, and visually diff before/
after (see workflow notes below) before rolling it out wider.

Priority order tends to follow structural impact: per-surface shading
(biggest visual difference, most work) > outline colour temperature
(cheap, high-impact) > texture/grain (moderate work, high polish value)
> anything else. But re-check this against what THIS pack's findings
actually emphasize — don't assume the priority order from a past pack
still applies unchanged.

## Workflow notes (things that bit this session, don't re-learn them)

- **No Godot on this machine (usually).** Check `which godot`. If
  absent, you can still run the Python generators directly (Pillow-only)
  and visually review PNGs, but cannot run `Verify.bat`/import/tests.
  Say so plainly rather than claiming something is "verified."
- **Characters with `tools/sprites/<name>.txt` sources are hand-edited
  and WIN over anything the generator draws** — `hand_edited()` in
  `make_art.py` silently stands down for them. Check this BEFORE
  spending time editing a draw function; `python tools/make_items.py`
  (or `forge_art.py <name>`) will print "hand-edited, not redrawn" for
  anything it skipped. Confirmed this session: 5 of the first furniture
  targets picked turned out to be dead-code edits for exactly this
  reason.
- **Regenerating even untouched items changes their PNG bytes** (Pillow/
  zlib version differences from whatever generated the committed art) —
  pixel-identical, not a real change. Confirm with
  `ImageChops.difference(...).getbbox()` (`None` = identical), then
  `git checkout --` the unintended files before committing, so the diff
  only shows real changes.
- **Run `tools/check_docs.py` and `tools/check_balance.py`** after any
  change — Python-only, no Godot needed, and they catch real
  regressions (doc/data drift) even without a full verify pass.
- **Don't push until the user has Godot-verified on a machine that has
  it** — this repo's own golden rule is "verify by looking at the
  running game, not by reading the code," and that only works where
  Godot is installed. Commit locally, say clearly what's NOT yet
  verified, let the user decide on timing.
