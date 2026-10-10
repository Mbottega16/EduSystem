# EDUSystem — project rules & map (read this first)

You are working on **EDUSystem**, a Godot 4.7 pixel-art classroom management
sim. This file is the source of truth for how to work on it. Read it fully
before editing anything.

**Start Claude Code from THIS folder**, not from the EduSystems prototype
folder. They are separate games and this repo depends on nothing outside
itself.

**Naming, so nothing gets confused:** this game is **EDUSystem** (one word).
"The EduSystems prototype" (trailing s) always means the archived HTML/JS
predecessor this project learned from and replaced — see `docs/SALVAGE.md`.
It is never a source of truth here.

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
  (46 sections outside the item and trait tables, 243 `static var`
  tunables in `balance.gd`). Nothing tunable may be a `const` in a `.gd`.
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
  job", not "0.62". Enforced by a test. **Scope, made explicit after a
  design-critique pass found the rule was being read two ways as more
  numeric screens shipped:** this bans a number standing in for a CHILD'S
  ability, teaching, or outcome -- anything the game is otherwise careful
  to phrase as a judgement rather than a score. It does not ban prices,
  coin totals, day counters, or a milestone's own count (6/23) -- those
  are the sanctioned exception the rule was always written around, not a
  loophole in it. If a new screen is unsure which side of that line it's
  on: would printing this number replace a sentence that currently makes
  a claim about a *child*? If yes, it is banned. If it is just what
  something costs or how far along you are, it is fine.
- **Legwork, not judgement.** Automation may do the walking; it may never
  make the decision about a particular child. **The one deliberate,
  named exception:** `Game.auto_teach` (Aug 2026, on explicit user
  request, after being asked to confirm the tension before it was
  built). Toggled, off by default, and it does not sneak past this rule
  so much as step outside it on purpose -- it hands the WHOLE lesson to
  RoomSim's Steady policy, the same honest simulation a delegated room
  already runs, rather than quietly automating one judgement at a time
  inside a lesson you are still nominally playing. Graded through the
  ordinary `Game.grade_class()`, on your real `room_score()`, not
  RoomSim's own flat abstraction -- see `run_auto_lesson()`'s own
  comment. If a future request asks for automation that presses
  buttons WHILE you are still standing in and playing your own lesson,
  that is the thing this rule still forbids; confirm the distinction
  with the user rather than assuming this precedent already covers it.
  **A SECOND named exception (Sept 2026, on explicit request):**
  `Game.skip_days_available()` / `Classroom.run_skipped_days()` — hand
  the room over for up to five whole DAYS, not one lesson. Same shape
  as `auto_teach` and resolved by the same RoomSim Steady policy, so
  it steps outside the lesson rather than automating judgements inside
  one; the distinction above was confirmed rather than assumed. What
  keeps it a decision: no homework goes out on a day you were not
  there to set it, so the marking that lifts a class never happens,
  and the skip is clamped so it can never reach the exam. Measured on
  a real run it grades D/D/E where played days grade B — it costs you
  something, which is the point. The cap is `skip.max_days` in
  balance.json; an item def carrying a `skip_days` key raises it, the
  way `teaches` already grants a concept.
- **One dedicated key per verb.** *(Revised Aug 2026, on user request --
  see `Interactable.Key` in `scripts/interact/interactable.gd` for the
  authoritative list.)* Used to be "two buttons per landmark": E the
  mashable verb, F the session-level one, and nothing else. That held
  for a while, then broke down the moment a landmark needed a THIRD
  verb (a quiz, at the podium, alongside teach/end-lesson) -- there was
  nowhere left to put it that wasn't a lie about what E or F meant.
  The fix was not a third contextual button. It was giving each verb
  its own PERMANENT key, global rather than landmark-contextual: E
  stays the mash (help, collect, hand in, clean up) and can never do
  anything irreversible; F stays session-level (lesson, bell, shop);
  quiz, marking and moving a desk each got their own key (Q, H, M)
  instead of sharing E or F depending which landmark you stood at.
  Two rules replace the old one:
    1. **E must never gain a job that is not mashable and reversible.**
       The instant helping a stuck child could end a lesson, the whole
       point of splitting keys is gone.
    2. **A verb that appears at more than one landmark, or that could
       ever be confused with another verb sharing its key, gets its
       own dedicated action** rather than being folded back into E or
       F contextually. `Interactable.KEY_ACTIONS` is the single list;
       add to it rather than overloading an existing entry.
  Tab/B/C/Y/P/I/V remain dedicated global keys for verbs that were never
  about a landmark at all (the class list, rearranging the room,
  settling it, pausing, your dashboard, watching a delegated room) --
  unaffected by this, and the precedent this whole scheme now follows.
- **A dev tool must never write the player's save.** `Game.save_path` is a
  var for exactly this reason — the suite and simulators point it elsewhere.
- **Panel budget:** 11 rows at font 16 in a 640×352 body (doubled Aug 2026
  alongside the whole game's resolution -- was font 8 in 320×176; the ROW
  COUNT a screen can hold is unchanged, since font size and body both
  scaled together). Labels clip in silence, so every panel is fit-tested --
  found twice more since this rule was written: a 10-line flat list in the
  Principal's Office clipped past the 4th entry with no scrollbar to say
  so, and the Controls screen's own action list overflowed into its
  footer the moment three new rebindable actions landed. Both are now
  windowed the way Career already was; confirm with a real screenshot,
  not a line count, since the true cutoff sits below what raw `\n`
  counting suggests once font size and line spacing are both accounted
  for. *(Oct 2026)* `hud._rich_overflows()` measures it: the wrapped
  text's height against the box. Every rich-panel fit test checks it as
  well as the row count; the day report and the lesson-plan page use it
  to move their least important lines to small print until they fit.

---

## How to verify EVERY change

Run these from the project root. **Read the assertion COUNT, not the word
PASSED** — a broken script can still print PASSED with a silently lower
count. That has happened three times.

```
Run Tests.bat            2562 assertions — must pass, count must not drop
Simulate a Term.bat      the three contract rows must still hold
Play a Whole Term.bat    twenty real days through the real buttons, not sim.gd's model
Trace a Day.bat          walks a real day through the real buttons
Audit the Room.bat       what both buttons offer at every landmark, every phase
Simulate the School.bat  delegated rooms: does hiring matter, does the board move
```

Or **`Verify.bat`** — the suite, the docs, the contract and a whole term
in one command, replacing four of the five double-clicks above. Since the
git hooks were disarmed (see Working rhythm), this is the only thing that
runs the slow checks, so run it before a push.

**Only two of those tools have a machine-readable answer: the suite, and
`Play a Whole Term.bat`.** The walkthrough prints a `WALKTHROUGH PASSED` /
`WALKTHROUGH FAILED - day N: <reason>` line and exits accordingly. It used
to `quit()` with no argument, so a broken day 18, a clean run, and a
script that never compiled all exited 0 and read the same from outside —
which is how a walkthrough regression sat for four days behind a green
suite. **It gates on liveness only** (every day reaches the bell, the exam
fires). The bot never marks homework, so it cannot pass a term on merit;
whether the class met its target is printed on every run and deliberately
does not fail it. `GATE_COMPETENCE` in `tools/playterm.gd` is the switch,
for when there is a marking policy to hold it to.

The other four still speak only prose at a human. Read their output.

Then **look at it**: `Take a Screenshot.bat [screen]` runs the real scene
and saves a PNG into `shots/` (gitignored). Pass no argument for the HUD's
own TITLE overlay, or one of the 43 named in the batch file's own comment.
Headless proves code does not crash; it never proves anything is on screen.

**That tool only ever loads `scenes/main.tscn`**, so it has never been
able to see the ACTUAL start screen (`scenes/ui/title.tscn` — the chalk
dust, the logo, Settings/Controls/Credits) at all. For those, use
`godot --path . res://tools/title_shot.tscn -- out.png [page]`, `page`
being one of Title.Page's names (main, settings, controls, howto,
credits, confirm_wipe). Built the same session Controls grew past ten
rows and needed to be screenshotted to confirm it, rather than assumed.

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
6. `git push` — the remote is `Mbottega16/EduSystem` (private; GitHub moved the
   repo there from `EduSystems-Code/EduSystem`, and the old URLs still redirect).

### Steps 2 and 3 are yours to run. The hooks are OFF by default.

**Read this before you assume anything is checking your work: nothing is.**
Both git hooks exist, both still work, and both exit immediately unless you
ask for them. Disarmed 2026-09-05, deliberately, on the owner's call —
occasional breakage is acceptable, waiting two minutes on every commit and
three and a half on every push is not.

```
Verify.bat                     the suite, the docs, the contract, and a
                               whole term through the real buttons. THE
                               one command that runs everything. Slow
                               (~6 min) and on demand, which is the point.

EDUSYSTEM_GATE=1 git commit    re-arm the pre-commit suite for one command
EDUSYSTEM_GATE=1 git push      re-arm the pre-push docs + walkthrough
$env:EDUSYSTEM_GATE=1          the same, from PowerShell
```

Each hook prints one line saying it is off, every time it fires. That is
on purpose — see below for why a quiet gate is the dangerous kind.

The hook bodies are untouched and worth keeping: `.githooks/pre-commit`
blocks on a failure, a parse error, or a hang (240s fail-safe — this
machine has shown Godot hang rather than exit when spawned as a git-hook
child, so the hook kills it and blocks rather than trusting a clean exit).
`.githooks/pre-push` runs `check_docs.py` and then a whole term through
the real buttons — the only thing in this repo that has ever caught a day
that cannot be finished. To turn either back on permanently, delete the
four-line `EDUSYSTEM_GATE` block at the top of it. `--no-verify` still
skips them if you re-arm.

`git config core.hooksPath .githooks` is still required, one-time per
clone, or the hooks are not found at all.

**Why the disarm is written down in four places** (both hook headers, this
file, and three assertions in `tests/run.gd`): there was an untracked
`.git/hooks/pre-push` doing this job before, and it had stopped running
altogether — `core.hooksPath` sends git to `.githooks`, so anything left
in `.git/hooks` is dead. A hook nobody can see is a hook nobody notices
has died, and this repo lost weeks to exactly that. A gate that is off
because someone decided it should be is fine. A gate that is off and
still looks armed is how the last one got missed.

---

## File map

| | |
|---|---|
| `scripts/autoload/game.gd` | The run: day, coins, roster, grading, terms, school. The big one. |
| `scripts/data/` | Every data layer — balance, students, curriculum, items, traits, assignments, staff, milestones |
| `scripts/world/` | grid, layout, classroom (the world root), room_builder, placement, hallway (the corridor between the rooms you hold), trophy_case (the hallway's, a place per boss trophy), mentor_room, principal_office and visit_room (rooms off the corridor you visit but never run; visit_room is any room you hold, its last day replayed) |
| `scripts/actors/` | actor, player, student |
| `scripts/interact/` | one file per landmark verb |
| `scripts/ui/hud.gd` | Every screen. 23 modes; ~ten of them share `REPORT`. `principal_says()` is the tutorial mascot — a once-per-run corner popup, portrait and all. |
| `data/balance.json` | **Every tunable number** |
| `data/curriculum.json` | 40 lessons, 120 concepts, real standard codes |
| `data/room_templates.json` | **Room ideas** (shop tab, Tab x5): seven ready-made layouts of the opening room built from real shop items, for players to take inspiration from. `scripts/data/room_templates.gd` `problems()` checks each against the placement rules (also `tools/check_templates.tscn`, and the suite). Inspiration only: nothing is bought or moved |
| `tests/run.gd` | The suite — 2562 assertions, 130 sections |
| `tools/` | Simulators, walkthroughs, the audit, art tools |
| `docs/GDD.md` | **What the finished game is.** Read before designing. |
| `docs/BRIEFING.md` | Context pack for external AIs |
| `docs/TASK_PACK.md` | Copy-paste prompts for Gemini/ChatGPT |
| `docs/SALVAGE.md` | What to take from EduSystems and what to refuse. Idea banks; the trait calibration set |
| `docs/ART_CATALOG.md` | Every PNG in `art/`, grouped by category and which tool draws/edits it |
| `docs/CRAFT_STYLES.md` | The five `Game.CRAFT_STYLES` names: each one's colour, where that colour shows in the UI today, and the asset-naming convention a future icon should follow |
| `tools/check_docs.py` | Verifies every doc claim against live data. A worked example is an INPUT to an outside model, not prose |
| `tools/check_balance.py`, `check_items.py`, `check_traits.py` | Catch a misspelled tunable before it silently reverts to a built-in default; validate a task-2/task-3 submission before it touches `balance.json` |
| `Dev Console.bat` | One menu for every other `.bat` launcher at the project root -- play, verify, simulate, trace/audit, and the art tools, so there is one icon to remember instead of a dozen. Each individual `.bat` still exists and still works stand-alone; this just calls them. |
| `tools/godot_path.txt` | The ONE place the Godot executable path lives. Every launcher reads it via `tools/_godot.bat` |
| `tools/playdrive.gd` | The ONE walk/keypress/boot base both walkthroughs extend. `walk_to()` used to live in each of them, byte-identical; a real fix landed in one copy only. Add a shared helper here, never a second copy there |
| `.githooks/pre-commit`, `.githooks/pre-push` | The suite before a commit; `check_docs.py` + a whole term before a push. **Both DISARMED by default** — `EDUSYSTEM_GATE=1` re-arms one for a single command, `Verify.bat` runs the lot. `core.hooksPath` must point at `.githooks` |
| `docs/relay/PROTOCOL.md`, `tools/relay.py` | **The Claude <-> Gemini relay.** Two agents work this folder and cannot see each other's context. Turns (whose go it is), claims (who holds which files) and a turn format whose YOU-GOT-WRONG section is validated for evidence, because an unfounded finding costs the other agent a round. `Relay.bat` shows the state; `GEMINI.md` is Antigravity's way in |
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
is a data-table edit, not new artwork. The shared model (`draw_char()` in
`tools/make_art.py`) is chibi — big head, small body — *(Aug 2026)*, one
proportion change that every existing and future palette inherits for
free, rather than each character needing its own redraw.

| | |
|---|---|
| `Make a Sprite.bat` | New character: writes the palette, draws it, imports it, registers the name |
| `Draw a Sprite.bat` | Hand-drawing editor (HTML): brush, fill, soften, flatten, retint, onion skin |
| `Browse Art.bat` | Every sprite at once; flags unreferenced and missing art; select one and press Enter to EDIT it in place. Tools: brush / eraser / line / rect / ellipse (`1`-`7`), a 1-16 square or round nib (`[` `]`), Filled toggle, Fill, Eyedrop; wheel zooms to the cursor, MMB pans, `M` cycles mirror off/X/Y/XY (across the character cell on a sheet); interpolated strokes, per-stroke undo. Runs `--import` before it opens. Saving writes a `tools/sprites/<name>.txt` source + the PNG -- it does NOT re-import (a `--import` child of the running Godot has hung and frozen the tool). |
| `Reimport Art.bat` | Runs `--import` from a console. Use it to make the GAME pick up a `Browse Art` edit -- Save no longer does. |
| `tools/forge_art.py` | **CLI art forge** -- regenerate ONE sprite into `art/` with tweaks, no GUI. `python tools/forge_art.py list` \| `... <name> key=value`. Characters take palette keys (`hair=#hex hair_style=curly glasses=1 skin=tan pattern=stripes`) and rewrite the sheet + portrait. Furniture/items take shared palette-colour keys plus `tint=#hex strength=0..1` and `swap=#from:#to`. `tiles floor_a=#hex …` rewrites the tile set. A sprite with a `tools/sprites/*.txt` hand source is refused (edit it in Browse Art) unless `--force`. Sibling of `tools/forge_audio.py`. |

**LimeZu art (Oct 2026) -- the owner's chosen look.** Most sprites now come from the
LimeZu *Modern Interiors / Office / UI* packs, read in place from their zips (the
licence forbids redistributing them, so they are never committed; they must be on the
machine for these tools, and only the finished sprites live in `art/`):

| | |
|---|---|
| `tools/import_limezu.py` | props, fixtures, hats -> `art/*.png`, driven by `tools/limezu_manifest.json`. `--list` shows every owned sprite and its source; `--check` verifies |
| `tools/import_free.py` | sprites from FREE packs that are not LimeZu's (Ninja Adventure, CC0; the Midcentury Modern Furniture set by 0_mem0ry), driven by `tools/free_manifest.json`, which records each pack's licence and credit. Same rules: packs found on the machine (`$FREE_ART_DIR`, `tools/free_art_path.txt`, Desktop/Downloads), never committed; every name it owns is protected like a LimeZu one. `--list`, `--check` |
| `tools/limezu_room.py` | the 18 room `tile_*.png`, driven by `tools/limezu_room.json`; `--preview room.png` shows the whole room first |
| `tools/limezu_chars.py` | the 17 character sheets + HUD busts from the Character/Portrait Generators, driven by `tools/limezu_cast.json`; `--preview`, `--check` |
| `tools/limezu_ui.py` | UI pieces: `bubble_q` (LimeZu frame + our glyph) and `ui_frame` (the bamboo border the HUD 9-slices round every full-screen panel, and the cream slot behind a shop item) |
| `tools/limezu_catalog.py` | browse the packs as labelled contact sheets (`props <theme>`, `kids`, `adults`, `animated`, `ui`, `room` ...) into `shots/catalog/`; the ids are the ones the JSON files take |
| `tools/shot_all.py` | screenshot every named screen (deterministic: it clears the scratch save per shot) and `compare` two runs side by side -- Windows/Mac/Linux |
| `tools/lz_conform.py` | snap ANY image to LimeZu's real palette + the #3a3a50 keyline (`--build-palette` once; `tools/limezu_palette.json` is colours only) |

Rules: a LimeZu-owned name is protected -- `make_art.hand_edited()` includes it, so the
generators and all three forges (`forge_art.py`, `forge_items.py`, `forge_ui.py` -- the
Master Forge's tabs shell out to them) stand down. To change one, edit its manifest/cast entry and
re-run the importer, **not** the PNG. The suite's `LIMEZU ART` section guards the credit
to limezu.itch.io on the credits page (a licence condition), that every owned PNG loads at
the doubled scale, and that none has a hand source fighting it. The **FREE** Modern
Interiors edition is non-commercial -- never use it. Compare images with
`limezu.same_pixels`, not `ImageChops...getbbox()` (alpha-only on RGBA).

**Speech is printed on paper (Oct 2026, the owner's ask).** Anything a person
SAYS -- the dialogue box, the corner tip and day beat, a bubble in the room --
is black ink on LimeZu's white panel (`art/ui_speech.png`, from
`tools/limezu_ui.py`) in **Galmuri9 at 20px** (`fonts/`, SIL OFL, subset to
Latin). The owner asked for "the same font as Pokemon": Nintendo's own font
cannot ship in a Steam game, and Galmuri is an OFL font drawn after the
Nintendo DS text. 20px is its 10px em doubled, so one of its pixels is one
pixel of the room's art -- keep it on a multiple of 10. Faces beside speech are
drawn at 72px (the 24px bust at exactly 3x, `expand_mode` IGNORE_SIZE so the
rect cannot grow back to 96), and blink from `portrait_<art>_talk.png`.

**The whole player-facing UI is in that font too** (owner's call, Oct 2026):
`fonts/ui_theme.tres` sits on the HUD's root, and the title screen, the floaters
and the overhead key badges set it themselves. Two sizes only -- `UI_SIZE` (20)
and `UI_SMALL` (10) in `hud.gd` -- and a test fails on any size that is not a
multiple of 10. Galmuri's line is ~2px taller than the old font's, so every
line spacing came down by 2 to keep the 11-row budget. The dev tools (Master
Forge, Browse Art) keep the default font.

**The verbs on offer are the coloured badges over the teacher's head, and
nothing else.** The bar along the bottom used to repeat them word for word,
clipped; it is now only ever the speech box. A held verb's badge says "hold"
and fills as you hold. **The mentor's three moves** (dash, answer all, the
call) sit bottom right as icons with their keys, each shown only while it can
be used, shaded while it recharges (`_update_move_bar()`).

**The seam that bites:** `make_art.py`, `forge_art.py` and `Browse Art`
write PNGs but do not import them, and Godot cannot load an unimported
texture. After adding or editing art run `godot --headless --path .
--import` (or `Reimport Art.bat`). The suite now *loads* every PNG rather
than checking it exists.
