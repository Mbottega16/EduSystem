# What to take from EduSystems, and what to leave

EduSystems is the **prototype archive**. It is not a source of truth for
PixelRoom, and no agent should treat its documents, formulas or catalogues
as authoritative here. It taught this project a great deal; it is not this
project.

This file exists because the salvage question keeps coming back, and each
time it does, someone proposes re-importing a system PixelRoom deliberately
does not have.

---

## The premise correction that matters most

**PixelRoom is not a port in progress.** It is a finished, working Godot
4.7 game: 1098 assertions, 29 items, 40 lessons, 120 concepts, a balance
contract measured from simulated play, and five verification tools.

Any advice framed as "how to move EduSystems into Godot" is answering a
question that was settled weeks ago. Three separate outside analyses of the
migration arrived in August 2026 proposing an `ItemData` Resource, an
isometric `TileMap`, a magenta chroma-key Python pipeline and a turn-based
battle manager. **Every one of those is wrong for this codebase**, and the
reasons are worth keeping because they will be proposed again:

| Proposal | Why it does not apply |
|---|---|
| Isometric `TileMap`, 2:1 projection, `cartesian_to_isometric()` | PixelRoom is a **flat square grid**. `Grid.TILE` is 16, the room is 20×11 tiles — which is exactly the 320×176 screen. There is no `TileMap` node anywhere in `scripts/`. |
| `_unhandled_input` on `MOUSE_BUTTON_LEFT` to place furniture | The game is **mouse-free**. Two buttons: E is the mashable verb, F is session-level, irreversible things are HELD. The mouse cycles the card hand and nothing else. |
| `ItemData` Resource with `@export var cost: int` | **Numbers do not live in code.** Every tunable is in `data/balance.json`. An `@export`ed cost is exactly the constant that rule forbids. |
| Magenta chroma-key + Pillow processor | PixelRoom has no magenta pipeline. Characters **are palettes** — one drawn model, recoloured, via `Make a Sprite.bat`. The one real seam is that `make_art.py` cannot import, so `godot --headless --path . --import` must follow. |
| `BattleManager`, mastery/regulation/focus | Concept Battles were cut from EduSystems at the user's request for being too complicating. PixelRoom never had them and is not getting them. |
| `items_db.json` with `UNI_SAF_01`, tier, ELO, `art_status` | Incompatible schema. PixelRoom items are `cat / cost / range / bonus / w / blurb`, optionally `teaches` / `needs`. There is no tier and no ELO. |

None of that code used `Game.rng` either, which would have broken
determinism on its own.

---

## DO NOT REPEAT — the complexity traps

This is the genuinely valuable half of the salvage, and the part worth
re-reading before adding any system.

- **Five school tiers** (Preschool → University), each with its own
  learning theory and scoring rules. PixelRoom's year-group concept covers
  this ground at a fraction of the cost. See `docs/TASK_PACK.md` Task 4.
- **ELO as the central statistic.** It became a chain —
  items → needs → Gardner → theory → ELO → stars → income — that nobody
  could hold in their head. PixelRoom asks the direct question instead:
  *are these children learning?*
- **Gardner's four intelligences as a multiplier system** (4 types × 1.20,
  3 × 1.08, 2 × 1.00, fewer × 0.92). Elegant on paper, opaque in play.
  Real curriculum concepts are more concrete and already do the job.
- **Maslow as a hard cap** (no Safety + Comfort → ELO capped at 80). The
  idea is right and PixelRoom keeps it: comfort matters because *children
  behave differently in a bad room*. The cap is not needed to say that.
- **Prestige, Legacy Points, a three-currency economy** (coins, gems,
  principal points). Meta-progression for a much larger tycoon. PixelRoom
  has coins.
- **A catalogue that grows to fill itself.** EduSystems went from ~49
  planned items to 353 cataloged, then deleted 59 in a single art review.
  **50 furniture pieces that each earn their slot beat 273 that exist
  because the list looked short.**
- **Achievement bloat** — 30 challenges plus 30 accolades plus prestige.
  PixelRoom has 15 milestones that pay nothing and gate nothing.

---

## What genuinely transfers

Almost everything worth keeping is **already built**, which is the real
finding. Listed here so nobody re-implements it:

- Content is data, not code — `data/balance.json`, `data/curriculum.json`.
- Stable ids as the seam between systems.
- Furniture changes classroom performance, and can `teach` or `need` a
  concept.
- A trait must change what the player DOES. Decoration teaches players to
  stop reading.
- A teacher is never strictly better than another, only better AT
  something.
- A day event must change a real number.
- A milestone names something you would tell somebody about.
- "Walking the room is the game."

Two things transfer that are **not** yet fully banked:

1. **The vertical-slice gate.** Do not generate a large batch of assets
   before one complete slice is approved. EduSystems learned this the
   expensive way. For PixelRoom the slice is: one room, one teacher, a
   class, a handful of furniture, one lesson, one disruption, one complete
   day — which the game already reaches, so the rule now applies to
   *content batches*: integrate and look at five new items before
   commissioning twenty more.
2. **The flat-texture lesson, adapted.** EduSystems learned not to ask a
   generator for pre-skewed isometric tiles when the engine applies the
   transform. PixelRoom is not isometric, so the lesson becomes: ask for
   art in the projection the game actually draws — 3/4 view, 16×16 or
   32×16, bottom row meeting the floor, and *hung on the wall with no
   floor contact* for `flat: true` items. That distinction is already
   written into `docs/TASK_PACK.md` Task 2.

---

## The old catalogue is an idea bank, never a data source

EduSystems' item list and its 20 canonical student traits are worth reading
for *ideas* when writing new PixelRoom content — they are a record of
classroom objects and child behaviours someone already thought hard about.

They must never be imported. Different schema, different economy, different
game. Read them, then write PixelRoom content from PixelRoom's rules.

---

## A note on how these analyses were produced

Three outside analyses were run. The two that were given only EduSystems
context proposed the isometric port above. The one that was **also given
`docs/BRIEFING.md` and `docs/TASK_PACK.md`** correctly identified what to
keep and what to leave, and recommended this document.

That is the whole thesis of the delegation pack in one experiment: an
outside model is only as good as the brief attached to it. Attach the
briefing. Every time.

---

## The idea banks — read off disk, not recalled

Three further analyses were asked to recover EduSystems' item catalogue
and student traits from memory. One admitted it could not and invented a
replacement; one produced a categorised list presented as extracted from
the archive; one honestly refused to fabricate the missing entries.

**None of that was necessary.** `EduSystems/game_template.html` is still on
disk. The real data was extracted directly:

- **338 `it()` rows, 331 unique item names**, across the old AUT/COM/DEC/
  KIN/LIN/LOG/SAF/SPA categories.
- **Exactly 12 student traits.** Not 20 — that figure appears in old
  documentation and is wrong against the live code.
- Ten item names already appear in PixelRoom: Art Easel, Coat Hooks,
  Floor Cushion, Microscope, Reading Lamp, Supply Cabinet, Wall Clock,
  Whiteboard, Wooden Stool, World Globe.

**The standing rule: when the archive is on disk, read it. A recollection
of a data file is not the data file**, and a plausible catalogue is harder
to spot than an obviously wrong one.

### The 12 real traits — a calibration set of what FAILS the bar

This is the whole of `TRAITS` in the live EduSystems code:

```js
{id:"curious",  spd:1.12, aff:"LOG"}   {id:"shy",      spd:0.94, aff:"COM"}
{id:"artistic", spd:1.08, aff:"SPA"}   {id:"restless", spd:0.90, aff:"KIN"}
{id:"bookworm", spd:1.10, aff:"LIN"}   {id:"dreamer",  spd:0.96, aff:"SPA"}
{id:"athletic", spd:1.06, aff:"KIN"}   {id:"diligent", spd:1.09, aff:null}
{id:"social",   spd:1.05, aff:"COM"}   {id:"playful",  spd:1.02, aff:"KIN"}
{id:"focused",  spd:1.15, aff:null}    {id:"gifted",   spd:1.20, aff:null}
```

A learning-speed multiplier and a category tag. **That is the entire
mechanism.** Not one of the twelve changes what the player *does* — they
change a number attached to a child and nothing else. `gifted` is
`spd:1.20` and no more.

This is the single most useful thing in the archive, because it is the
negative example. PixelRoom's rule — *a trait must hook into the work
model or the seating* — was written against exactly this. Compare
`copier`, which gets a child unstuck off a neighbour so the work visibly
recovers and the later quiz exposes that they never understood it. That is
a trait. `spd:1.12` is a stat.

**Use these twelve as the calibration set for Task 3**: if a proposed trait
could be expressed as a single multiplier on that child, it has failed.

### Furniture idea bank

Curated from the real 331. Removed: everything already in PixelRoom, the
university and district tier (Nobel Laureate Wall, Quantum Computer,
Endowment Plaque, Superintendent's Nameplate), the gym and lab buildings
(Rowing Machine, Fume Hood, Radiation Monitor), the old economy's
non-objects (Private Tutor Package, Focus Tonic, Maintenance Contract) and
generated placeholders (Decor Accent S, Reading Set 143).

What remains is objects that could plausibly stand in one primary
classroom. **Ideas only — no costs, no categories, no schema.** Anything
taken from here gets written from PixelRoom's rules.

**Seating** — Couch, Rest Mat, Kids Chair, Folding Chair, Step Stool, Soft
Play Steps, Crawl Tunnel, Ball Pit, Lounge Ottoman, Padded Bench, Scooter
Board.

**Surfaces** — Kids Table, Round Table, Sand Table, Water Table, Sensory
Table, Supply Trolley, Wall Cabinet, Toy Chest, Cubby Shelf, Open Cubby,
Assignment Tray, Sorting Tray, Art Caddy, Book Bin, Bin Shelf, Portfolio
Rack, Wardrobe Cabinet, File Drawer, Teacher's Desk.

**Learning** — Chalkboard, Cork Board, Letter Board, Shape Board, Magnetic
Letters, Alphabet Rug, Storybook Shelf, Puppet Theater, Listening Station,
Typewriter, Newspaper Stand, Counting Beads, Shape Sorter, Stacking
Pyramid, Logic Puzzle Shelf, Anatomy Model, Desk Globe, Science Supply
Table, Lab Sink, Circuit Rack, Coding Terminal, Overhead Projector,
Pull-Down Screen, Podium, Lectern, Debate Timer, Vocabulary Wall, Rhyme
Chart, Reading Log Chart, Math Mobile, Music Stands, Peg Board, Clay
Station, Pottery Wheel, Printmaking Press, Canvas Easel, 3D Model Shelf,
Tripod Camera, Writing Desk, Drafting Desk.

**Comfort** — Wash Basin, Umbrella Stand, Hamster Cage (a class pet),
Potted Fern, Bonsai Tree, Zen Sand Garden, Coat Tree, Snack Tray,
Grandfather Clock.

**Decor** — Welcome Banner, Student Art Wall, Display Case, Trophy Cabinet,
Mural Panel, World Map Poster, Butterfly Display, Mascot Statue, Marble
Bust, Framed Portrait, Event Posters, Bulletin Board, School Logo Sign,
Achievement Plaque, Hall of Fame Board, Star Chart, Behaviour Chart, Hall
Pass Board, Framed Mirror, Safety Rules Poster, Exit Sign, Fire
Extinguisher, First-Aid Kit, Sanitizer Station, Recycling Bin, Trash Can.

**50 items is a design target, not a quota.** EduSystems went from ~49
planned to 353 cataloged, then deleted 59 in one art review. If item 47 is
worse than something already in the shop, PixelRoom does not need item 47.
