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
  (40 sections outside the item and trait tables, 194 `static var`
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
  Tab/B/C/P/I/V remain dedicated global keys for verbs that were never
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
  for.

---

## How to verify EVERY change

Run these from the project root. **Read the assertion COUNT, not the word
PASSED** — a broken script can still print PASSED with a silently lower
count. That has happened three times.

```
Run Tests.bat            1920 assertions — must pass, count must not drop
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
6. `git push` — the remote is `EduSystems-Code/EduSystem` (private; the old
   `PixelRoom` URL still redirects).

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
| `scripts/world/` | grid, layout, classroom (the world root), room_builder, placement, hallway (the corridor between the rooms you hold) |
| `scripts/actors/` | actor, player, student |
| `scripts/interact/` | one file per landmark verb |
| `scripts/ui/hud.gd` | Every screen. 19 modes; ~ten of them share `REPORT`. `principal_says()` is the tutorial mascot — a once-per-run corner popup, portrait and all. |
| `data/balance.json` | **Every tunable number** |
| `data/curriculum.json` | 40 lessons, 120 concepts, real standard codes |
| `tests/run.gd` | The suite — 1920 assertions, 107 sections |
| `tools/` | Simulators, walkthroughs, the audit, art tools |
| `docs/GDD.md` | **What the finished game is.** Read before designing. |
| `docs/BRIEFING.md` | Context pack for external AIs |
| `docs/TASK_PACK.md` | Copy-paste prompts for Gemini/ChatGPT |
| `docs/SALVAGE.md` | What to take from EduSystems and what to refuse. Idea banks; the trait calibration set |
| `docs/ART_CATALOG.md` | Every PNG in `art/`, grouped by category and which tool draws/edits it |
| `tools/check_docs.py` | Verifies every doc claim against live data. A worked example is an INPUT to an outside model, not prose |
| `tools/check_balance.py`, `check_items.py`, `check_traits.py` | Catch a misspelled tunable before it silently reverts to a built-in default; validate a task-2/task-3 submission before it touches `balance.json` |
| `Dev Console.bat` | One menu for every other `.bat` launcher at the project root -- play, verify, simulate, trace/audit, and the art tools, so there is one icon to remember instead of a dozen. Each individual `.bat` still exists and still works stand-alone; this just calls them. |
| `tools/godot_path.txt` | The ONE place the Godot executable path lives. Every launcher reads it via `tools/_godot.bat` |
| `tools/playdrive.gd` | The ONE walk/keypress/boot base both walkthroughs extend. `walk_to()` used to live in each of them, byte-identical; a real fix landed in one copy only. Add a shared helper here, never a second copy there |
| `.githooks/pre-commit`, `.githooks/pre-push` | The suite before a commit; `check_docs.py` + a whole term before a push. **Both DISARMED by default** — `EDUSYSTEM_GATE=1` re-arms one for a single command, `Verify.bat` runs the lot. `core.hooksPath` must point at `.githooks` |
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
| `Browse Art.bat` | Every sprite at once; flags unreferenced and missing art; select one and press Enter to EDIT it in place -- brush, eraser, fill, eyedrop, undo/redo. Saving writes a `tools/sprites/<name>.txt` source, the PNG, and imports it |

**The seam that bites:** `make_art.py` writes PNGs but cannot import them,
and Godot cannot load an unimported texture. After adding art run
`godot --headless --path . --import`. The suite now *loads* every PNG rather
than checking it exists.
