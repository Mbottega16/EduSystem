# EDUSystem — rules & map (read this first)

A Godot 4.7 pixel-art classroom-management sim. This file is the source of truth for how
to work on it; read it fully before editing anything. **Start Claude Code from THIS
folder** — this repo depends on nothing outside itself.

**History:** [`HISTORY.md`](HISTORY.md), newest first — every session's log, plus the
long-form reasons behind the rules below. Read it when a task touches past work.
**Business side** (money, audience, the owner's long-term vision in full): the my-brain
vault, `projects/edusystem/context.md`.

**Naming:** this game is **EDUSystem** (one word). "The EduSystems prototype" (trailing s)
is the archived HTML/JS predecessor this project learned from (`docs/SALVAGE.md`). It is
never a source of truth here.

## What this is
- **What:** you are a teacher, and walking the room is the game. Children get stuck and
  stop dead until you reach them; work only advances while you teach it; furniture helps
  the child sitting next to it; terms end in an exam with a target you can miss. Stay in
  one classroom for a whole career, or hire staff and run the school — a room you
  delegate is simulated by the same model you would have played it with. Pitch:
  *Football Manager for a primary school, played from the inside.*
- **For:** players of pixel-art management/sim games.
- **Platform:** Godot 4.7, Windows first. Mac/Linux/Steam Deck are wanted, not a focus.
- **Money:** free, ad-supported — optional rewarded video only, never forced
  interstitials, no paywall. Steam is the real target; itch.io is for playtesting.
- **What "done" looks like:** a Steam game you can replay forever. Dopamine density in
  the loop itself, and an easy, friction-free restart the moment a run stops being fun.
- **Direction (the owner, 2026-08-24):** the infinite axis is lesson *quality* — the
  player crafts and refines their own lesson variants against a lesson's fixed
  objective — not lesson count. Admin/multi-room play should unlock only once the
  player has shown they have mastered one classroom. The next big system is an admin
  layer that *coaches* delegated teachers ("teaching teachers how to teach"), built on a
  solid `Game.auto_teach` (clean-room maths in `docs/SIM_FORMULAS.md`). No named school,
  town or teacher, on purpose: the story emerges from the simulation.
- **Full design:** `docs/GDD.md` — **read before designing**. Technical map with
  diagrams: `docs/ARCHITECTURE.md`.

## Settled decisions (don't re-argue)
Every one was paid for. The full wording and the incidents behind each are in the
appendix of `HISTORY.md`.
- **Determinism.** Every random decision goes through the seeded `Game.rng`. Global
  `randi()`/`randf()` are banned project-wide; without this no balance testing can exist.
- **Numbers do not live in code.** Every tunable is in `data/balance.json` (46 sections
  outside the item and trait tables, 243 `static var` tunables in `balance.gd`). Nothing
  tunable may be a `const` in a `.gd`.
- **The balance contract must hold** — measured from *simulated* play, asserted by the
  suite: bare room + perfect teaching ~0.63 → C · full room + never helped ~0.71 → C ·
  full room + perfect teaching ~0.97 → A. Neither input alone reaches the top band.
  **Nothing may quietly move this.** It is why the quiz pays no grade, and why
  assignment rarity pays coins and XP but never grade.
- **Prose, never numbers, in player-facing text** (enforced by a test). Banned: a number
  standing in for a CHILD'S ability, teaching or outcome. Fine: prices, coin totals, day
  counters, a milestone's own count (6/23). Unsure? If printing the number would replace
  a sentence that makes a claim about a child, it is banned.
- **Legwork, not judgement.** Automation may do the walking, never the decision about a
  particular child. Two named exceptions, each built on explicit request after the
  tension was confirmed: `Game.auto_teach` (hands the WHOLE lesson to RoomSim's Steady
  policy, graded through the ordinary `Game.grade_class()` on your real `room_score()`),
  and skip days (`Game.skip_days_available()` / `Classroom.run_skipped_days()`: up to
  `skip.max_days` whole days, no homework goes out, never reaches the exam, grades D/D/E
  where played days grade B). Automation that presses buttons WHILE you are still playing
  your own lesson is still forbidden — confirm with the owner rather than assuming these
  precedents cover it.
- **One dedicated key per verb**, global, never landmark-contextual.
  `Interactable.KEY_ACTIONS` (`scripts/interact/interactable.gd`) is the single list;
  default keys are in `scripts/autoload/settings.gd`. **E** is the mash (help, collect,
  hand in, clean up) and must never gain a job that is not mashable and reversible. **F**
  is bell/shop, **L** starts the lesson, **Q** quiz, **H** marking, **M** move a desk,
  **J** answer all, **U** grade book, **X** treats. A verb at more than one landmark, or
  one that could be confused with another, gets its own action — add to the list, never
  overload E or F.
- **Advanced verbs are gated behind the mentor** (the dash, answer all, the call);
  existing saves are grandfathered. **Boss readiness is prose**, never a number. The
  roguelike subject boss is a named exception to `SALVAGE.md`'s "no ELO / no boss
  manager" rule.
- **A dev tool must never write the player's save.** `Game.save_path` is a var for
  exactly this reason; the suite and simulators point it elsewhere.
- **Panel budget:** 11 rows at font 16 in a 640×352 body. Labels clip in silence, so every
  panel is fit-tested: `hud._rich_overflows()` measures the wrapped text against the box,
  and crowded screens move their least important lines to small print. Confirm with a
  real screenshot, not a line count.
- **The citation rule.** `data/curriculum.json` cites **real** standards (Common Core,
  NGSS, the Maryland Social Studies Framework). Never invent a code — an uncited lesson
  is more honest than a fabricated citation. Six are uncited on purpose and the suite
  asserts it: `using_sources`, `community_roles`, `state_symbols`, `transport_history`,
  `constitution`, `industrialisation`. Name any new uncited lesson in that list.

## How it's built
| | |
|---|---|
| `scripts/autoload/game.gd` | The run: day, coins, roster, grading, terms, school. The big one. |
| `scripts/data/` | Every data layer — balance, students, curriculum, items, traits, assignments, staff, milestones, tutorials, room templates |
| `scripts/world/` | The room and the school: grid, layout, classroom (world root), room_builder, placement, hallway, the grade wing (`live_room`, `stage_door`), trophy_case, window_butterfly, ambient_touches, mentor_room, principal_office, visit_room |
| `scripts/actors/` · `scripts/interact/` | actor, player, student · one file per landmark verb |
| `scripts/ui/hud.gd` | Every screen (23 modes; ~ten share `REPORT`). `principal_says()` is the tutorial mascot. `scripts/ui/tutorial.gd` plays the cutscenes in `data/tutorials.json` |
| `data/balance.json` | **Every tunable number** |
| `data/curriculum.json` | 40 lessons, 120 concepts, real standard codes |
| `data/room_templates.json` | Seven ready-made room ideas (shop tab), checked by `room_templates.gd` `problems()`. Inspiration only |
| `tests/run.gd` | The suite — 3076 assertions, 146 sections |
| `tools/` | Simulators, walkthroughs, the audit, art tools. `tools/godot_path.txt` is the ONE place the Godot path lives; `tools/playdrive.gd` is the ONE walk/keypress base both walkthroughs extend — add a shared helper there, never a second copy |
| `docs/GDD.md` | **What the finished game is.** Read before designing. |
| `docs/ARCHITECTURE.md` | Module ownership, the day, the grade pipeline, where tunables live, the harness (Mermaid) |
| `docs/ART_PIPELINE.md` | **Every art tool and its rules — read before any art work** |
| `docs/ART_CATALOG.md` | Every PNG in `art/`, grouped by category and which tool draws/edits it |
| `docs/SIM_FORMULAS.md` | Clean-room sim maths (attention decay, reaction curve, pedagogy tiers) for the coaching layer |
| `docs/CRAFT_STYLES.md` | The five `Game.CRAFT_STYLES`: colour, where it shows, icon naming |
| `docs/BRIEFING.md` · `docs/TASK_PACK.md` | Context pack for external AIs · copy-paste prompts for Gemini/ChatGPT |
| `docs/SALVAGE.md` | What to take from EduSystems and what to refuse; idea banks; the trait calibration set |
| `docs/relay/PROTOCOL.md`, `tools/relay.py` | **The Claude ↔ Gemini relay**: turns, file claims, a validated turn format. `Relay.bat` shows the state; `GEMINI.md` is Antigravity's way in |
| `Dev Console.bat` | One menu for every other `.bat` launcher |
| `.claude/commands/` | `/deep_scan` (status), `/deep_update` (re-sync docs to live state), `/deep_critique` (outsider design pass) |

## Commands & Verification
**The one golden rule: verify by looking at the running game, not by reading the code.**
Tools that *look* have saved this project repeatedly; edits that seemed obviously right
have burned it — a patch landed in the byte-identical `end_test()` instead of
`end_lesson()` (suite green; `Audit the Room.bat` caught it), the podium offered nothing
for ten seconds a day with 730 assertions green (`Trace a Day.bat` found it), an
unimported PNG passed every file-exists check. **Run the tools. Read their output. Do not
trust a diff.**

Run from the project root. **Read the assertion COUNT, not the word PASSED** — a broken
script can print PASSED with a silently lower count (it has happened three times).

```
Verify.bat               the suite, the docs, the contract and a whole term in one (~6 min) — run before a push
Run Tests.bat            3076 assertions — must pass, count must not drop
Simulate a Term.bat      the three contract rows must still hold
Play a Whole Term.bat    twenty real days through the real buttons: WALKTHROUGH PASSED / FAILED - day N
Trace a Day.bat          walks a real day through the real buttons
Audit the Room.bat       what both buttons offer at every landmark, every phase
Simulate the School.bat  delegated rooms: does hiring matter, does the board move
python tools/check_docs.py      every doc claim against live data
python tools/check_balance.py   every key in balance.json is read by something
python tools/check_items.py · check_traits.py   validate a task-2 / task-3 submission
```

- Only the suite and the walkthrough answer in a machine-readable way. The walkthrough
  gates on liveness only (every day reaches the bell, the exam fires); whether the class
  met its target is printed but does not fail it (`GATE_COMPETENCE` in
  `tools/playterm.gd`). The other four speak prose — read them.
- **Then look at it.** `Take a Screenshot.bat [screen]` saves a PNG into `shots/` (one of
  the 43 names in the batch file's comment). It only loads `scenes/main.tscn`; for the
  real title screen use `godot --path . res://tools/title_shot.tscn -- out.png [page]`.
  `tools/shot_all.py` shoots every named screen and `compare`s two runs.
- A new system gets checks in `tests/run.gd`. Narrow the output while iterating:
  `godot --headless --path . res://tests/run.tscn -- CURRICULUM`.
- **The git hooks are OFF by default — nothing checks your work unless you run it.**
  Disarmed 2026-09-05 on the owner's call. `EDUSYSTEM_GATE=1 git commit` / `git push`
  re-arms one for a single command (PowerShell: `$env:EDUSYSTEM_GATE=1`);
  `git config core.hooksPath .githooks` is needed once per clone. A gate that is off
  must *say* it is off — never leave one that looks armed.
- **Rhythm:** small, additive edit → `Run Tests.bat` (count up, nothing failed) → the tool
  that covers what you touched → screenshot anything visual → commit saying *why* →
  `git push` (remote `Mbottega16/EduSystem`, private).

## Never Read / Noise Zones (Do Not Scan)

To avoid wasting context or slowing down searches, **never read or grep inside**:
- `.godot/` — 2,018+ Godot internal cache, shader, and imported texture files.
- `shots/` — generated screenshot PNGs (inspect only the specific screenshot you just captured).
- `art/*.import`, `*.uid`, `audio/*.wav`, `audio/*.ogg` — binary/import metadata files.
- `tools/__pycache__/` — Python bytecode caches.

## Rules & Gotchas
- **Doing art? Read `docs/ART_PIPELINE.md` first.** Characters *are palettes*: one drawn
  chibi model (`draw_char()` in `tools/make_art.py`), recoloured, so a new character is a
  data-table edit.
- **LimeZu art is the owner's chosen look.** The packs are read in place from their zips
  and **never committed** (licence: credit required, no redistribution); only finished
  sprites live in `art/`. A LimeZu-owned name is protected — change its manifest/cast
  entry and re-run the importer, **never the PNG**. The suite's `LIMEZU ART` section
  guards the limezu.itch.io credit (a licence condition). The **FREE** Modern Interiors
  edition is non-commercial: never use it.
- **The seam that bites:** `make_art.py`, `forge_art.py` and `Browse Art` write PNGs but do
  not import them, and Godot cannot load an unimported texture. After adding or editing
  art, run `godot --headless --path . --import` (or `Reimport Art.bat`).
- **Speech is printed on paper, and all player-facing UI is Galmuri9** (SIL OFL, drawn
  after the Nintendo DS text; Nintendo's own font cannot ship on Steam). Two sizes only,
  `UI_SIZE` 20 and `UI_SMALL` 10 in `hud.gd` — a test fails on any size that is not a
  multiple of 10. Faces beside speech are 72px (the 24px bust at 3x). Dev tools keep the
  default font.
- **The verbs on offer are the coloured badges over the teacher's head, and nothing
  else**; the bottom bar is only ever the speech box. The mentor's three moves sit
  bottom right, shown only while usable (`_update_move_bar()`).
- **Two agents work this folder.** If a relay round is live (`Relay.bat`), check whose
  turn it is and claim files before editing.

## Session Handoff (Last Worked On · Current State · Next Up)

*Overwrite this at the end of every session; move the previous handoff into `HISTORY.md` first.*

- **Last Worked On (2026-10-23, the owner's ask): the grade wing, moving up by choice,
  the watch card.** Four `LiveRoom` classrooms (`scripts/world/live_room.gd`), one per
  stage, run forever above the hallway's corridor wall on a fixed hash (never
  `Game.rng`). Each stage has a door (`stage_door.gd`, E opens its paper card) and a
  plaque. F on the next stage's card moves up (`Game.move_up()`) after
  `tiers.terms_before_move_up` terms, for `age_tiers.<id>.move_up_cost` coins; higher
  stages pay `age_tiers.<id>.pay_mult`. The WATCH screen is a paper card now. Full
  detail: `HISTORY.md`.
- **Current State (2026-10-24):** suite green at **3076 assertions** in 146 sections,
  balance contract `0.63 C / 0.72 C / 0.97 A` unmoved, whole-term walkthrough passed
  (all 2026-10-23, game at `7a64a7f`). Docs restructured 2026-10-24 (no code change);
  `check_docs.py` 323/323.
- **Next Up:**
  1. The owner plays the grade wing: do the move-up prices and stage pay feel right?
     Should the wing rooms be walk-in? Should the School board screen go on paper too?
  2. The owner looks at the back wall, the butterfly and the grade book's subjects page
     in the real game; playtest desk-chatter frequency and Study Folder balance
     (`balance.json` → `chat`, `items.study_folder`).
  3. Build the admin coaching layer from `docs/SIM_FORMULAS.md`.
  4. The remaining tiers of the vault's `projects/edusystem/limezu-build-plan.md` (sleep
     row for stuck students, cast variation pass, Modern Farm cosmetics), as the owner
     directs.
