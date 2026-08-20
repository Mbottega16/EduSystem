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
  | full room, never helped | ~0.71 → C |
  | full room, perfect teaching | ~0.97 → A |

  Neither input alone reaches the top band. **Nothing may quietly move
  this.** It is why the quiz pays no grade and why assignment rarity pays
  coins and XP but never grade.
- **Prose, never numbers, in player-facing text.** "The room is doing its
  job", not "0.62". Enforced by a test.
- **Legwork, not judgement.** Automation may do the walking; it may never
  make the decision about a particular child.
- **Two buttons per landmark.** E is the mashable verb (help, collect,
  hand in). F is session-level (lesson, bell, shop). Anything irreversible
  is HELD. This is about what one landmark can offer, not the whole
  keyboard -- the game already had Tab/B/Q/P as dedicated global keys
  before this rule was ever written down, and a new global key (`I`, the
  dashboard) is the same kind of thing, not an exception to it. What
  would actually break the rule is a THIRD verb on a landmark, or E/F
  gaining a job that is not mashable/session-level respectively.
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
Run Tests.bat            1132 assertions — must pass, count must not drop
Simulate a Term.bat      the three contract rows must still hold
Play a Whole Term.bat    twenty real days through the real buttons, not sim.gd's model
Trace a Day.bat          walks a real day through the real buttons
Audit the Room.bat       what both buttons offer at every landmark, every phase
Simulate the School.bat  delegated rooms: does hiring matter, does the board move
```

Or **`Verify.bat`** — the suite, the docs and the contract in one command,
replacing three of the five double-clicks above.

Then **look at it**: `Take a Screenshot.bat [screen]` runs the real scene
and saves a PNG into `shots/` (gitignored). Pass no argument for the title
screen, or one of the 23 named in the batch file's own comment. Headless
proves code does not crash; it never proves anything is on screen.

Two more checkers, run the same way as `check_docs.py`:

```
python tools/check_balance.py    every key in balance.json is read by something
python tools/check_items.py      validate a task-2 furniture submission
python tools/check_traits.py     validate a task-3 trait submission
```

If you add a system, add checks to `tests/run.gd`. To see only one
section's output while iterating, pass a filter: `Run Tests.bat` still
runs everything (state carries between sections), but
`godot --headless --path . res://tests/run.tscn -- CURRICULUM` narrows
what prints.

---

## Working rhythm

1. Make a small, additive edit.
2. `Run Tests.bat` → count went **up**, nothing failed.
3. Run whichever tool covers what you touched (see table above).
4. Screenshot anything visual.
5. Commit, with a message that says *why*, not just what.
6. `git push` — the remote is `EduSystems-Code/PixelRoom` (private).

**Step 2 is also enforced at the git level.** `git config core.hooksPath
.githooks` (one-time, per clone — run it if commits aren't being checked)
points git at the tracked `.githooks/pre-commit` hook, which runs the
suite before any commit and blocks on a failure, a parse error, or a
hang (240s fail-safe — this machine has shown Godot hang rather than
exit when spawned as a git-hook child, so the hook kills it and blocks
rather than trusting a clean exit). `git commit --no-verify` skips it for
a deliberate WIP commit.

---

## File map

| | |
|---|---|
| `scripts/autoload/game.gd` | The run: day, coins, roster, grading, terms, school. The big one. |
| `scripts/data/` | Every data layer — balance, students, curriculum, items, traits, assignments, staff, milestones |
| `scripts/world/` | grid, layout, classroom (the world root), room_builder, placement, hallway (the corridor between the rooms you hold) |
| `scripts/actors/` | actor, player, student |
| `scripts/interact/` | one file per landmark verb |
| `scripts/ui/hud.gd` | Every screen. 16 modes; ten of them share `REPORT`. `principal_says()` is the tutorial mascot — a once-per-run corner popup, portrait and all. |
| `data/balance.json` | **Every tunable number** |
| `data/curriculum.json` | 40 lessons, 120 concepts, real standard codes |
| `tests/run.gd` | The suite — 1132 assertions, 79 sections |
| `tools/` | Simulators, walkthroughs, the audit, art tools |
| `docs/GDD.md` | **What the finished game is.** Read before designing. |
| `docs/BRIEFING.md` | Context pack for external AIs |
| `docs/TASK_PACK.md` | Copy-paste prompts for Gemini/ChatGPT |
| `docs/SALVAGE.md` | What to take from EduSystems and what to refuse. Idea banks; the trait calibration set |
| `tools/check_docs.py` | Verifies every doc claim against live data. A worked example is an INPUT to an outside model, not prose |
| `tools/check_balance.py`, `check_items.py`, `check_traits.py` | Catch a misspelled tunable before it silently reverts to a built-in default; validate a task-2/task-3 submission before it touches `balance.json` |
| `tools/godot_path.txt` | The ONE place the Godot executable path lives. Every launcher reads it via `tools/_godot.bat` |
| `.claude/commands/` | `/deep_scan` (status report), `/deep_update` (re-sync docs to live state), `/deep_critique` (skeptical-outsider design pass) |

---

## The citation rule

`data/curriculum.json` cites **real** standards — Common Core, NGSS, the
Maryland Social Studies Framework. The rule, from `curriculum.gd`:

> Do not invent a code for a new lesson. An uncited lesson is more honest
> than a fabricated citation.

Six lessons are deliberately uncited and the suite asserts they stay that
way: `using_sources`, plus the five social-studies lessons of the August
2026 batch (`community_roles`, `state_symbols`, `transport_history`,
`constitution`, `industrialisation`). The Maryland Social Studies
Framework numbers its standards 1.0–6.0 by strand rather than by topic, so
a per-topic code would have had to be minted — which is the thing the rule
forbids. If you add uncited content, name it in that list so an
*accidental* omission still fails.

---

## Art

Characters **are palettes** — one drawn model, recoloured. A new character
is a data-table edit, not new artwork.

| | |
|---|---|
| `Make a Sprite.bat` | New character: writes the palette, draws it, imports it, registers the name |
| `Draw a Sprite.bat` | Hand-drawing editor (HTML): brush, fill, soften, flatten, retint, onion skin |
| `Browse Art.bat` | Every sprite at once; flags unreferenced and missing art; select one and press Enter to EDIT it in place -- brush, eraser, fill, eyedrop, undo/redo. Saving writes a `tools/sprites/<name>.txt` source, the PNG, and imports it |

**The seam that bites:** `make_art.py` writes PNGs but cannot import them,
and Godot cannot load an unimported texture. After adding art run
`godot --headless --path . --import`. The suite now *loads* every PNG rather
than checking it exists.
