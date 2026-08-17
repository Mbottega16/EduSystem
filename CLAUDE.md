# PixelRoom — project rules & map (read this first)

You are working on **PixelRoom**, a Godot 4.7 pixel-art classroom management
sim. This file is the source of truth for how to work on it. Read it fully
before editing anything.

**Start Claude Code from THIS folder**, not from the EduSystems one. They are
separate games and this repo depends on nothing outside itself.

---

## The one golden rule

**Verify by looking at the running game, not by reading the code.**

This project has been saved repeatedly by tools that *look*, and burned
repeatedly by edits that seemed obviously right:

- A patch landed in `end_test()` instead of `end_lesson()` because the two
  contain a byte-identical block. The suite passed. `Audit the Room.bat`
  caught it in seconds.
- The podium once offered nothing for the first ten seconds of every day,
  which made the game unplayable end-to-end. 730 assertions were green.
  `Trace a Day.bat` found it in one run.
- `art/inspector.png` existed on disk and could not be loaded, because
  nothing had imported it. Every file-exists check passed.

**Run the tools. Read their output. Do not trust a diff.**

---

## Hard constraints (non-negotiable)

- **Determinism.** Every random decision goes through `Game.rng`, which is
  seeded. Global `randi()`/`randf()` are banned project-wide. Without this,
  none of the balance testing can exist.
- **Numbers do not live in code.** Every tunable is in `data/balance.json`
  (32 sections, 122 values outside the item and trait tables). Nothing
  tunable may be a `const` in a `.gd`.
- **The balance contract must hold.** Three rows, measured from *simulated*
  play, asserted by the suite:

  | | |
  |---|---|
  | bare room, perfect teaching | ~0.63 → C |
  | full room, never helped | ~0.69 → C |
  | full room, perfect teaching | ~0.97 → A |

  Neither input alone reaches the top band. **Nothing may quietly move
  this.** It is why the quiz pays no grade and why assignment rarity pays
  coins and XP but never grade.
- **Prose, never numbers, in player-facing text.** "The room is doing its
  job", not "0.62". Enforced by a test.
- **Legwork, not judgement.** Automation may do the walking; it may never
  make the decision about a particular child.
- **Two buttons.** E is the mashable verb (help, collect, hand in). F is
  session-level (lesson, bell, shop). Anything irreversible is HELD.
- **A dev tool must never write the player's save.** `Game.save_path` is a
  var for exactly this reason — the suite and simulators point it elsewhere.
- **Panel budget:** 11 rows at font 8 in a 288×128 body. Labels clip in
  silence, so every panel is fit-tested.

---

## How to verify EVERY change

Run these from the project root. **Read the assertion COUNT, not the word
PASSED** — a broken script can still print PASSED with a silently lower
count. That has happened three times.

```
Run Tests.bat            1033 assertions — must pass, count must not drop
Simulate a Term.bat      the three contract rows must still hold
Trace a Day.bat          walks a real day through the real buttons
Audit the Room.bat       what both buttons offer at every landmark, every phase
Simulate the School.bat  delegated rooms: does hiring matter, does the board move
```

Then **look at it**: `Take a Screenshot.bat` runs the real scene and saves a
PNG. Headless proves code does not crash; it never proves anything is on
screen.

If you add a system, add checks to `tests/run.gd`.

---

## Working rhythm

1. Make a small, additive edit.
2. `Run Tests.bat` → count went **up**, nothing failed.
3. Run whichever tool covers what you touched (see table above).
4. Screenshot anything visual.
5. Commit, with a message that says *why*, not just what.
6. `git push` — the remote is `EduSystems-Code/PixelRoom` (private).

---

## File map

| | |
|---|---|
| `scripts/autoload/game.gd` | The run: day, coins, roster, grading, terms, school. The big one. |
| `scripts/data/` | Every data layer — balance, students, curriculum, items, traits, assignments, staff, milestones |
| `scripts/world/` | grid, layout, classroom (the world root), room_builder, placement |
| `scripts/actors/` | actor, player, student |
| `scripts/interact/` | one file per landmark verb |
| `scripts/ui/hud.gd` | Every screen. 13 modes; ten of them share `REPORT`. |
| `data/balance.json` | **Every tunable number** |
| `data/curriculum.json` | 20 lessons, 60 concepts, real standard codes |
| `tests/run.gd` | The suite — 1033 assertions, 74 sections |
| `tools/` | Simulators, walkthroughs, the audit, art tools |
| `docs/GDD.md` | **What the finished game is.** Read before designing. |
| `docs/BRIEFING.md` | Context pack for external AIs |
| `docs/TASK_PACK.md` | Copy-paste prompts for Gemini/ChatGPT |
| `docs/SALVAGE.md` | What to take from EduSystems and what to refuse. Idea banks; the trait calibration set |

---

## The citation rule

`data/curriculum.json` cites **real** standards — Common Core, NGSS, the
Maryland Social Studies Framework. The rule, from `curriculum.gd`:

> Do not invent a code for a new lesson. An uncited lesson is more honest
> than a fabricated citation.

One lesson (`using_sources`) is deliberately uncited and the suite asserts
it stays that way. If you add uncited content, name it in that list so an
*accidental* omission still fails.

---

## Art

Characters **are palettes** — one drawn model, recoloured. A new character
is a data-table edit, not new artwork.

| | |
|---|---|
| `Make a Sprite.bat` | New character: writes the palette, draws it, imports it, registers the name |
| `Draw a Sprite.bat` | Hand-drawing editor (HTML): brush, fill, soften, flatten, retint, onion skin |
| `Browse Art.bat` | Every sprite at once; flags unreferenced and missing art |

**The seam that bites:** `make_art.py` writes PNGs but cannot import them,
and Godot cannot load an unimported texture. After adding art run
`godot --headless --path . --import`. The suite now *loads* every PNG rather
than checking it exists.
