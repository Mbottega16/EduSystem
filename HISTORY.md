# EDUSystem — history

Every session's log, **newest first**. Read on demand, not at startup. The current
snapshot is the Session Handoff at the bottom of `CLAUDE.md`; the rules are in
`CLAUDE.md` too, and their long-form reasons are in the appendix at the bottom of
this file.

**Adding an entry:** at the end of a session, move the old handoff here as a new entry
at the top, then overwrite the handoff. One entry per session, 5–10 lines:

```
## YYYY-MM-DD — <what, in a few words>
*<machine: Mac | PC> · <agent: Claude | Antigravity> · commits `abc1234`*
- **Changed:** what is different now, for the player and in the code.
- **Why:** the ask or the problem, and any decision made (with its reason).
- **Verified:** what was run and what it said; what was NOT checked.
- **Left open:** anything unfinished or waiting on the owner.
```

Entries from 2026-10-04 to 2026-10-23 were moved here word for word on 2026-10-24,
from the old `CLAUDE.md` handoff and the vault's `context.md`. Where both described
the same session, the vault's plain-English summary comes first and the handoff's
technical detail follows. Links that pointed into the vault are written as
`vault: <path>` (the vault is `~/Desktop/my-brain` on the Mac,
`~/OneDrive/Desktop/AI Projects/my-brain` on the PC).

---

## 2026-10-28 — Teacher skill tiers, dumb/smart persona spectrum, and fleet evaluation leaderboard
*PC · Antigravity · commits pending*
- **Changed:**
  1. Persona Skill Hierarchy (`tools/personas/`): Added `tier` (1-4), `skill_rating` (0-100), `category` (novice/developing/proficient/master), `reaction_delay`, `chores_first`, `use_voice`, `idle_circulate`, and `desk_rearrange_mode` to `persona_schema.json`.
  2. Persona Spectrum: Added Tier 1 novice/dumb personas (`clueless_sub.json` with 4.0s reaction lag, no voice, no chaining; `distracted_sweeper.json` fixated on sweeping crumbs before helping crying students) and Tier 2 (`strict_lecturer.json` podium-bound with frequent pop quizzes). Upgraded `pedagogy_master.json` (Tier 4 Master) and `steady_teacher.json` / `furniture_nerd.json` (Tier 3 Proficient).
  3. Director Humanization & Dials (`tools/director.gd`): Wired perception reaction delay, chore distraction priority, voice gating, front-of-room idle patrol circulation, and tier-based furniture shopping.
  4. Teacher Scorecard & Leaderboard: Automated evaluation scoring in `_finish()` and `_save_scorecard()`, outputting ranked fleet standings to `D:/EduSystemClips/leaderboard.json` (or `user://leaderboard.json`).
  5. Multi-Screen Supervisor & Batch (`run_6_screens.py`, `Launch 6 Bots.bat`): Added `--roster` preset selector (`diverse` spectrum, `smart`, `dumb`, `classic`) and end-of-run ranked leaderboard summary printout.
  6. Suite Coverage (`tests/run.gd`): Added `PERSONA TIERS & SCHEMAS` section (34 new assertions), bringing test suite to 3,110 assertions across 147 sections.
- **Why:** The owner asked to introduce distinct skill levels for bot teachers and a system to organize "good smart" teachers from "bad dumb" teachers for footage variety and simulation fidelity.
- **Verified:** All 3,110 assertions passed in `Run Tests.bat`. `Simulate a Term.bat` verified balance contract `0.63 C / 0.72 C / 0.97 A` unmoved. `tools/check_docs.py` validated.
- **Left open:** Offline heuristic weight updater for director personas based on historical leaderboard results.

## 2026-10-28 — 6-bot autonomous fleet, personas, term controls, continuous career saves
*PC · Antigravity · commits pending*
- **Changed:** 
  1. Persona engine (`tools/personas/`): `pedagogy_master.json` (ZPD peer pairing, min-maxing, high-aura decor), `steady_teacher.json` (calm routine), `furniture_nerd.json` (classroom makeover designer, aggressive decorating).
  2. Director intelligence: chained desk visits (`_nearby_desk_needing_me()`), safe furniture placement zoning with reachability checks, podium fallback navigation, speed-adaptive walk tolerances, and continuous career saves across segments (`continue_save` in `playdrive.gd`).
  3. Term controls: added `term_complete` logging and `max_terms` cap to `tools/director.gd`. Added perpetual vs term-capped controls (`--terms N`, `--perpetual`, `--fresh`) to `projects/edusystem/promo/run_6_screens.py`.
  4. 6-Screen Multi-Bot Launcher (`Launch 6 Bots.bat`): tiles 6 Godot instances in a 3x2 grid across the monitor (top 3 recording, bottom 3 live companion play), prompting for perpetual vs term-capped play.
  5. Evaluator (`tools/eval_term.py`): headless batch benchmark evaluating personas and tracking GPA, grades, and stuck recoveries.
- **Why:** The owner asked to run 6 bots simultaneously visible in a tiled layout (with classroom makeover designer recording as bot 3), to have bots think smarter across daily/term passes with Vygotsky ZPD pairing, and to have controls to run them perpetually or stop after N terms.
- **Verified:** All 3,076 assertions in `Run Tests.bat` passed green. Headless term evaluator proved 0 stuck recoveries and grade boost from D/E ceiling to C (2.0 GPA) with +53% coins. All 6 bots ran simultaneously on primary monitor in 3x2 grid with ~1.34 GB RAM consumption without crash.
- **Left open:** Future AI policy training / Q-learning scaffold on saved metadata, high-tier boss term automation.

## 2026-10-27 — director bot v1/v2, teacher names, long recordings
*PC · Claude · commits `8e5afd3`, `bfdb1fa`, `b4019ed`*
- **Changed:** `Game.teacher_name` (saved, shown at the start of the HUD status line; empty by default). `tools/director.gd` plays the real game through the real buttons: sweeps messes, collects and marks homework, runs quizzes and goes over them, settles with the voice, answers everyone at once, shops, hires the janitor and aide, spends skill points, places furniture, visits the mentor's room, moves a desk. `tools/clip_term.gd` and the vault's `promo/record_loop.py` record named teachers in segments.
- **Why:** the owner wants marketing footage of the game being played intuitively, by several teacher styles at once (vault `projects/edusystem/promo/content-engine-spec.md`).
- **Verified:** suite 3076 assertions after the teacher-name change. Headless director runs from seed 5: 20 days with no stuck day; the mentor taught the dash, answer-all and chain; furniture was placed; a desk was moved; homework was collected and marked. Two recorders at once ran for hours on D:. NOT verified: the director over many seeds, any detail past term 1, the director as good teaching (it still misses most term targets).
- **Left open:** personas (every director plays alike), choosing lessons, the mentor's last talk (call-response), furniture and perk taste, trimming the long quiz screens from footage.

## 2026-10-27 — clip_probe: record the real game off-screen
*PC · Claude · commit `18cfd4a`*
- **Changed:** new `tools/clip_probe.gd` (+ `.tscn`) records a fixed-seed run with Godot's movie writer, off-screen. `playdrive.boot()` takes an optional `save_id`, so recorders running side by side write different scratch saves. Default behaviour is unchanged.
- **Why:** phase 0 of the marketing-video engine (vault `projects/edusystem/promo/content-engine-spec.md`). The owner wants real moving footage and several teacher styles recorded at once.
- **Verified:** 10 s clip plays, 640x352 at 30 fps, with an audio track. Same seed twice: same state fingerprint, frame PSNR 50+ dB (not byte-identical). Different seeds: different fingerprints, PSNR 31 dB. Two recorders at once finished in 9 s with free RAM near 0.63 GB. Suite 3076 assertions, `playtrace` one-day walkthrough rang the bell. NOT checked: three at once, a full-day recording, whether audio is audible to a listener.
- **Left open:** the director bot (teaching, questions, shop, furnishing) and the cut-list renderer are not built.

## 2026-10-24 — docs restructured to the uniform standard

*Mac · Claude · docs only, no game code touched*
- **Changed:** `CLAUDE.md` was cut from 430 lines to the seven standard sections (What this
  is · Settled decisions · How it's built · Commands & Verification · Never Read · Rules &
  Gotchas · Session Handoff), with the big picture now at the top. The art tool tables moved
  word for word to `docs/ART_PIPELINE.md`. Every dated session log (the old handoff's
  "Last Worked On" bullets and the vault `context.md`'s eight "Update" blocks) moved here
  word for word. The long-form text of every rule is kept in the appendix below. The vault
  `context.md` is now the business side only.
- **Why:** the owner's call: one uniform structure in every repo, with a short always-read
  file holding the big picture and the current snapshot, and a separate log read only when
  needed. Before this, an EduSystem session read ~23k tokens of docs before starting work.
- **Corrected while moving:** the old `CLAUDE.md` said F starts the lesson. The code
  (`scripts/autoload/settings.gd`) has **L** for the lesson, **F** for bell/shop, **J** for
  answer all, **U** for the grade book, **X** for treats, and `CLAUDE.md` now says so. The
  2026-10-18 pause-menu bullet appeared twice in the old handoff; it is kept once below.
- **Verified:** `python3 tools/check_docs.py` 323/323 (was 317: the file map now names more docs).
  The vault's `node workflows/scripts/doc-check.js edusystem` passes. A line-by-line check found every
  non-blank line of the old `CLAUDE.md` and vault `context.md` in the new files, except
  rewritten headers. md-doctor: zero broken links. The Godot suite was NOT run: no code,
  data or test changed (the one test that reads a doc, `GEMINI.md` naming
  `docs/relay/PROTOCOL.md`, still holds).
- **Left open:** none.

## 2026-10-23 — the grade wing, moving up by choice, the watch card

The owner's ask: classrooms that run on their own and show the tiers of rooms in the
hallway, Pokémon-style, a way to move up a grade after the first term, and no black
window.

- **The grade wing.** Above the hallway's corridor wall sit four classrooms, one per
  stage (Elementary, Middle, High, College). Each is a `LiveRoom`: six children and a
  teacher in that stage's own floor, walls, props and cast. The rooms run forever.
  Hands go up and the teacher walks over, neighbours whisper, someone jumps, high
  school dozes, the teacher writes on the board. Each stage has its own mix. A fixed
  hash drives it, never `Game.rng`. The corridor floor went from 4 to 3 tiles so the
  wing, the corridor and the doors fit one screen.
- **Moving up by choice.** Each stage has a door in the corridor wall and a plaque
  (gold = your stage, green = next). E reads the stage's paper card. After one whole
  term in your stage, F on the next stage's card moves you up for coins (400 / 900 /
  1600). Your class comes with you. Higher stages pay more per lesson (×1.2 / ×1.45 /
  ×1.75). The earned promotion at term end still works. The new-term report says when
  the next door opens. All numbers are in `balance.json` (`age_tiers.*`,
  `tiers.terms_before_move_up`).
- **The watch screen is a cream paper card** over the room, not the dark overlay.

**Decisions made (reversible):** "grades" means the four existing school stages, not
grade levels inside one stage. The move is coins + a whole term, not free. The class
loops up with you instead of being replaced. The wing rooms are scenery you look at
and read; you do not walk into them.

**Open for the owner:** play it and say if the prices and pay feel right; say if the
wing rooms should be walk-in; say if the School board screen should go on paper too.

**Technical detail (from the CLAUDE.md handoff):**

- **The grade wing, moving up by choice, the watch card (2026-10-23, the owner's ask):** Above the hallway's corridor wall, four classrooms -- one per stage (`Balance.tier_order`) -- each a `LiveRoom` (`scripts/world/live_room.gd`): six children and a teacher in the stage's own look, props and cast, running forever. Hands go up and the teacher walks over along the aisle, neighbours whisper until looked at, someone jumps, high school dozes and is woken, the teacher writes on the board; each stage's mix is `LiveRoom.STAGES[id].flavour`. A fixed hash of room and beat drives it, never `Game.rng` (tested); bubbles pop silently; the wing only processes while the hallway is visible. The corridor floor is 3 tiles now (`Hallway.HEIGHT` 96) so wing + corridor + doors are one screen, and the camera is pinned to it. Each stage has a door in the corridor wall (`stage_door.gd`, **E**, read-only) and a plaque (gold YOU, green NEXT). E opens the stage's paper card (`hud.show_stage`, `Mode.STAGE`); on the next stage's card **F** moves up (`Game.move_up()`): only after `tiers.terms_before_move_up` whole terms in this stage (`Game.tier_since_term`, saved), only between lessons, for `age_tiers.<id>.move_up_cost` coins. The class loops up with you; the new-term report says when the door opens. Each stage pays `age_tiers.<id>.pay_mult` on the day's lesson coins (`Game.tier_pay_mult()`); the auto promotion at term end still works and also sets `tier_since_term`. The WATCH screen is a cream paper card now (two children a row), not the dark overlay. Shots: `grade_wing`, `grade_wing_far`, `stage_card`, `stage_moved`.

**The handoff's state and next steps, as written then:**

- **Current State (2026-10-23):**
  - Suite green: **3076 assertions** in 146 sections, docs 317/317, balance contract `0.63 C / 0.72 C / 0.97 A` unmoved, whole-term walkthrough passed.
- **What Needs To Be Worked On Next:**
  1. Owner look at the new back wall, the butterfly and the grade book's subjects page in the real game; then playtest feedback on desk chatter frequency and Study Folder balance (`balance.json` -> `chat`, `items.study_folder`).
  2. Implement upcoming Admin Coaching layer using the clean-room math in `docs/SIM_FORMULAS.md`.
  3. Remaining tiers of `[limezu-build-plan.md]` (sleep row for stuck students, cast variation juice pass, Modern Farm animal cosmetics) as directed by the owner.

## 2026-10-19 — paper screens and tutorial cutscenes

- **Paper screens and tutorial cutscenes (2026-10-19):** The principal's office, the mentor and the desk caller are now cream paper panels over the live room (`hud._paper_on`, 22% dim at most), with the speaker's face. Mentor pages cut to five lines at a sentence (`hud.paper_pages`). New tutorial system: `data/tutorials.json` (ten tutorials), `scripts/ui/tutorial.gd` runner (panel, face, pointer ring and arrow, E next, Esc skip), `Game.tutorials_seen` saved, older saves grandfathered by use. `Game.fire_tutorial(event)` queues one; it plays when the room is free (`hud.tutorial_room_free`), or before a screen the player opens. Pause menu has a Tutorials page for replays (seen set unchanged). Shots: `tutorial_quiz`, `tutorial_homework`, `tutorial_pick`, `mentor_talk`.

## 2026-10-18 — the back wall, the grade book, the bars; pause menu, cheats, lessons, homework, final exam

- **The back wall, the grade book, the bars (2026-10-18, the owner's list):**
  - Nothing on the back wall touches the skirting or anything else: windows two art pixels higher (`limezu_room.json` "top" 5), every hung piece's bottom on `Layout.WALL_HANG_Y` 50 (was 62, on the trim). Hung fixtures (`RoomBuilder.hung_fixtures()`): the corkboard is the furniture shop and ONLY the shop; the curriculum moved to the alphabet poster at 7-8 (`curriculum_poster`, E, beside the podium); the hand bell became LimeZu's wall intercom at column 1 (`Layout.BELL`), across the room from the shop; the treats sit on a jar shelf at 14-15 (`treat_shelf`, X) instead of floating round the locker; the locker moved to column 4, off the first window; the cuckoo clock hangs at 18. A save with a piece on a now-taken column is rehung (`Game.rehang_wall_items`); the seven room ideas were re-slotted.
  - Teacher's desk: pencil pot painted out of the art (manifest `fill`), mug moved onto the desktop. Work bars outlined in LimeZu's keyline `#3a3a50`. Reward poster is LimeZu's animated advertising screen (57 frames).
  - The butterfly (`scripts/world/window_butterfly.gd`): the second window opens (`art/window_open.png`), it flies out, comes back, loops over the front row, lands. Fixed timetable, no rng.
  - The grade book opens on a subjects page: all 40 lessons in four subject columns, subject colours and icons, taught lessons in colour with the class's last letter, untaught in faint ink, a cursor with the selected lesson's detail. Tab turns to the old register. `log_grades()` now records the lesson id.
- **Pause menu, cheats, lessons, homework, final exam (2026-10-18):** Esc (or P) opens a pause menu: Resume, Lesson plans, Settings (master/music/sfx volume, window, fullscreen, hints, status strip, move bar), Controls, Cheats, School, Career, Quit (to title or the game). The cheat panel (`debug_panel.gd`) is now in the bamboo frame and Galmuri9. **Z** opens the lesson plans screen; after enough lessons in a subject (`assignments.prestige_lessons_needed`, 5) **F** there makes a lesson Prestige (always deals a Legendary card). Legendary pays x3.0. Homework is back to per-sheet marking: college-ruled paper in Patrick Hand (`fonts/`, SIL OFL), a check banks the sheet, an X does not, waving through a bad sheet marks the child `misjudged`. The last bell of a term asks for one lesson per subject first (`Game.exam_picks`, capped effect `term.exam_pick_swing`).

## 2026-10-17 — SaveManager 3 slots, Title Controls footer polish, REA toolchain, sim formulas

- **SaveManager slot picker UI landed (`c92f44b`):** 3 visual slots with metadata, play time formatting, and selection in Godot UI.
- **Title screen Controls footer overlap fixed (`c119d4b`):** The non-scrolling menu Label was appending the page counter (`1-10 of 29`) as rows 11-12, rendering directly over the centered footer at Y=304. Moved pagination cleanly into `footer.text` (`"E to rebind, Esc to go back  (1-10 of 29)"`).
- **REA (Reverse Engineer Anything) connected:** Integrated `morluto/rea` (153 CLI commands, 207 MCP tools) into machine tooling index (`tools.md` / `tools-detail.md`) to drive clean-room sim formula extraction, Pokémon pacing analysis, and asset pipeline automation.
- **Reverse-Engineered Sim Formulas, Pokemon Dialogue Pacing & Procedural Student Generator (`19d59b4`):**
  - **Track A (Sim Math):** Documented clean-room attention decay differential equation $A(t)$, diminishing-returns reaction curve $R(\ell)$, 5-tier pedagogy progression tree for `RoomSim`, and ZPD scaffolding multipliers in `docs/SIM_FORMULAS.md`.
  - **Track B (Juice/Pacing):** Refined authentic Pokemon Gen 4/5 NDS dialogue frame pacing in `scripts/ui/hud.gd` — punctuation pauses (`.` `!` `?` -6 ticks, `,` `;` `:` `—` `-` -3 ticks), non-whitespace alternating audio blips, and pixel-snapped integer indicator bounce.
  - **Track C (Asset Tools):** Created procedural student cast generator in `tools/limezu_random_student.py` enforcing LimeZu sprite layering rules, body-type matching, palette compatibility, and personality trait assignment.
- **Verified:** Suite completely green at **2,781 assertions** in 138 sections, docs 315/315, balance contract unmoved. Pushed `19d59b4` to `origin/master`.

**Next:** owner playtest feedback on chatter frequency, Study Folder balance, and implementation of upcoming Admin Coaching layer using `docs/SIM_FORMULAS.md`.

**Technical detail (from the CLAUDE.md handoff):**

- **Reverse-Engineered Sim Formulas & Pokemon Dialogue Pacing & LimeZu Generator (2026-10-17):**
  - Extracted and codified clean-room simulation math in `docs/SIM_FORMULAS.md`: differential attention decay equation $A(t)$, diminishing-returns reaction curve $R(\ell)$, 5-tier pedagogy progression tree for `RoomSim`, and ZPD scaffolding multipliers.
  - Fine-tuned authentic Pokemon Gen 4/5 NDS dialogue and UI pacing in `scripts/ui/hud.gd`: sentence terminator pauses (-6.0 ticks / ~0.16s), phrase separator pauses (-3.0 ticks / ~0.08s), non-whitespace alternating sound blips, and pixel-snapped integer indicator bounce.
  - Built procedural student generator `tools/limezu_random_student.py` adhering to LimeZu generator layering rules, palette constraints, and role balance.
- **Title Screen Controls Footer Polish (2026-10-17):** Fixed pagination overlap on Title screen Controls rebind page (`scripts/ui/title.gd`); integrated page range cleanly into `footer.text` rather than appending extra lines into the non-scrolling menu Label.
- **SaveManager Slot-Picker UI (`c92f44b`):** Implemented 3 visual save slots with metadata in the UI.

## 2026-10-10 — desks that talk, a study folder, the grade book

The owner's three asks, built in the game repo as three commits.

- **Desks that touch get talking** (`accdd57`). Two seated children whose
  desks touch, corners included, may start a conversation while both work.
  They turn to each other, a lilac quote-mark bubble goes back and forth,
  and neither works until it ends: after 5 s, or at once when the teacher
  comes within 2 tiles ("shh!"), calls Class, class!, or raises their voice
  in earshot. A pair then owes 6 s of work. A chat nobody broke up has a 25%
  chance to turn the one who started it into ordinary messing about.
- **The Study Folder** (`8414c57`). A new kind of item that stands ON a
  child's desk (`Game.desk_items`), placed with the normal cursor and moving
  with its desk. Learning tab, 60 coins, two at most. A stuck child behind
  one looks it up after 6 s (no XP, no help counted), and nobody chats with
  them or copies over it. Art is LimeZu's own desk-with-folder minus the
  plain desk.
- **The grade book** (third commit, this session). The open register on the
  teacher's desk, read on its own key **U**. Every lesson, unit test and term
  exam is written into `Game.grade_log`; the book shows five lessons a page
  as a register (a row per child, a coloured letter per lesson), keeps the
  children who have moved up, and back-fills the current term for an older
  save.

**Decisions made (each one reversible; numbers live in `balance.json`):**
- Talking **replaces** the hidden 12% `room.cluster_penalty`. Keeping both
  would charge crowding twice, and the hidden one was the "math in the
  background" the owner asked to see.
- "Too close" means desks touching, corners included (`chat.reach_tiles` 1).
  The opening layout is never too close, so nobody talks until desks are
  pushed together.
- "Make them solve their lessons" was read as the child working out their
  own stuck moments. The folder is capped at two, so it is a choice of
  WHICH children, not a set for every desk.
- The grade book is on its own key, not E. E at that desk hands in sheets,
  and a screen that opened on a mashed E would get in the way.
- Traits gained a `chat_mult` hook: Chatty 2.0, Loud 1.5, Anchor 0.6, Shy 0.5.

**Verified:** suite **2595** assertions in 131 sections (from 2478), docs
315/315, contract 0.63 C / 0.72 C / 0.97 A unmoved, whole-term walkthrough
passed. Screenshots checked for every new screen (`chatter`, `chatter_build`,
`chatter_file`, `folder`, `folder_place`, `folder_shop`, `grade_book`,
`grade_book_empty`, `at_desk`, `help_sheet`).

**Fixed (2026-10-17, `c119d4b`):** the title screen Controls footer overlap is resolved — pagination is integrated cleanly into `footer.text` rather than appended to the non-scrolling menu Label.

**From the CLAUDE.md handoff:**

- **Desks that touch get talking (`accdd57`, 2026-10-10):** Adjacent/diagonal seated students can start a 5s lilac-bubble conversation (replaces hidden 12% `room.cluster_penalty`; broken up by walking within 2 tiles, calling *Class, class!*, or raising voice; traits carry `chat_mult`).
- **The Study Folder (`8414c57`):** Desk-top item (`Game.desk_items`, Learning tab, 60 coins, max 2) that lets a stuck child look up their own answer after 6s and prevents chatting/copying across that desk.
- **The Grade Book (Key `U`):** Open register on the teacher's desk showing 5 lessons per page across `Game.grade_log` (lessons, unit tests, term exams).

## 2026-10-09 — desk props for event days, a trophy case, the office is a room

The owner's three asks from the 10-08 list, built and pushed:

- **Event days put something on the teacher's desk**, that day only: a snow globe
  with swirling snow (cold snap), a stack of books (book fair), ice cream
  (heatwave), tissues (bug), a basketball (sports day), bundles of notes (budget,
  small grant), doughnuts (parents' evening), flowers (a new face). All LimeZu's
  except the book stack: no pack draws books lying flat, so it is **hand-drawn in
  his palette and keyline** (`tools/sprites/book_stack.txt`). Table:
  `RoomBuilder.EVENT_DESK`. Commit `c80393d`.
- **A trophy case in the hallway**, between the office and mentor doors. One place
  per boss trophy: won ones stand in it, the rest show a dimmed shape, so it is a
  map of what is left to win. E at it lists them. Art is LimeZu's museum vitrine,
  lengthened; the importer learned `parts`, `rows` and `glare_over` to build it.
- **The principal's office is a room**, not a menu on the door: her desk between two
  windows, the school's charts behind her, visitors' chairs, a sofa, shelves and
  files. She sits at her desk; E there opens the same office screen. Walking in
  still earns `met_principal`.
- **Bug fixed:** a screen opened after the intro's slate was closed from outside
  kept the slate's see-through backing and hidden footer. Every screenshot from a
  fresh run showed it (the shot harness has had no real save to copy since 10-08).
  `_open()` now restores both.

Verified: suite **2467**, docs 315/315, contract 0.63 C / 0.72 C / 0.97 A, whole-term
walkthrough passed, screenshots of every changed screen. **Pushed** at `18722b7`.

**Then, on "find something else" — the next slice of the approved T5 plan:**

- **Walk into any room you hold** (`caee67f`). A staffed room's door opens the room,
  not a screen: its six children at their desks, the hired teacher at the front, one
  more piece of furniture per level bought, and **yesterday replayed** from RoomSim's
  own frames — stuck bubbles go up, the teacher walks to whoever needed them. A visit,
  never a second room to teach (the owner's 10-05 call); E at the front opens the
  watch screen the door used to. Hired teachers have faces now: four new LimeZu
  sheets (`staff_a`..`staff_d`), picked by name. Leaving a room puts you outside its
  own door.
- **Every room off the corridor has its own floor and walls** (`d46f111`). Six new
  Room Builder looks (108 tiles): the office in dark wood under a cream-and-green
  wall, the rooms you hold in teal tiles, golden boards, red herringbone, rose tiles
  and yellow squares, each under its own wall colour.

Verified the same way after each: suite **2476**, docs, contract unmoved, walkthrough
passed, screenshots. **Pushed** at `d46f111`.

- **A QA pass over all 72 screens** (`acbd5ae`, `670f5f9`). Found and fixed: the day
  report ran off its panel on busy days, the lesson-plan page overflowed on long
  objectives (division's ran to a dozen lines), and the run-over yearbook printed
  over a stale title. The fit tests counted line breaks, so they passed all of it;
  they now measure the wrapped text (`hud._rich_overflows()`), and crowded screens
  move their least important lines to small print. The screenshot tool now closes
  the intro first, so in-room shots show the room again. A flaky crafting-nudge
  test was steadied.

Final state: suite **2478**, docs 315/315, contract unmoved, walkthrough passed.
**Pushed** at `670f5f9`.

**From the CLAUDE.md handoff:**

- **Explorable School & Animated Room (2026-10-08/09):** Walkable staffed rooms replaying yesterday's `RoomSim`, hallway trophy case, principal's office room, event-day desk props (`RoomBuilder.EVENT_DESK`), blinking cast (`18x4` sheets), and 13 animated shop items.

## 2026-10-08 — free art packs in, and the room moves

The owner asked for every usable free pack, to phase out old art, and for more
animation because the room felt static.

- **Packs downloaded** to `Downloads/free_art` (never committed): Ninja Adventure (CC0),
  Midcentury Modern Furniture (0_mem0ry), Kenney Tiny Town and RPG Urban (CC0), Lo Bit
  City (credit required if used). A new importer, `tools/import_free.py` with
  `tools/free_manifest.json`, records each pack's licence and credit. See
  free-art-packs-on-disk (vault: `memory/free-art-packs-on-disk.md`).
- **Replaced:** rocking chair, hammock chair, window seat, low shelf (Midcentury); sand
  timer and the state/winner's flag (Ninja); pedestal fan, pot of pens, standing
  chalkboard, terrarium, server rack (LimeZu). "Desk Fan" is now **"Standing Fan"**.
- **New movement in the room:** a cuckoo clock on the wall, steam off the teacher's
  coffee, a blinking server rack, a frog in the terrarium, waving flags, a spinning fan,
  the bell swings when rung, and rain, snow and sparkles drawn as real particles.
- **Still old art:** 8 shop items (maths tiles, abacus, microscope, sound cards, number
  line, rock tray, vote box, season wheel), the bell, ad poster, book, logo, title
  backdrop, messes, bow and mortarboard. The packs had no fair match. The subject icons
  and mood faces were kept on purpose: they carry the strand colours.
- **Not built:** Kenney and Lo Bit City stay unused until the schoolyard work, which
  waits for art.
- **The LimeZu write-up is done:** limezu-art-description.md (vault: `projects/edusystem/limezu-art-description.md`)
  measures his style (grid, keyline, palette, light, ramps, characters, animation) and
  lists every LimeZu sprite the game uses. It is the brief for the owner's own
  LimeZu-style art generator.

Verified with `Verify.bat`: suite **2428**, docs 315/315, contract 0.63 C / 0.72 C /
0.97 A unmoved, whole-term walkthrough passed. **Pushed** at `50a9f55`.

**Second pass, same day:** five more items move: the **globe** turns, the **computer**
is LimeZu's animated monitor with a scrolling page, the **paper mobile** drifts, the
**telephone**'s light blinks, the **robot kit**'s face light pulses. Thirteen shop items
now animate, and a test checks that every strip's frames really differ. Suite
**2431**, Verify passed, **pushed** at `766f79a`.

**Third pass, same day ("KEEP GOING"):**
- **Everyone blinks.** LimeZu's idle row closes the eyes on its fifth frame; the
  character sheets now carry it as columns 16-17 (18x4, 576x192), and a resting
  actor blinks every few seconds. The two characters in glasses keep their eyes open.
- **Sun on the floor** under every window, gone on wet and cold days, with dust
  drifting through it on fair days.
- **Someone's birthday:** three LimeZu party balloons bob over the teacher's desk,
  that day only (the owner's "event decoration that takes itself away" rule).
- **The hallway and the mentor's room are real rooms now.** Both were flat dark
  rectangles. They are painted from the classroom's tiles, and the corridor's wall is
  lined with lockers, boards, a clock, a plant, a water cooler, coat hooks and a
  swimming fish tank.
- **Bug fixed:** the test suite was writing to the player's real settings file on
  every run (rebinding a key, corrupting it on purpose, then resetting to defaults).
  It now uses its own file; the real one is byte-identical after a run.
- **Noticed, not caused here:** the player's main save (`edusystem_save.json`) is
  not on disk. Screenshots taken at 06:04 still started from it; by ~11:35 the
  user-data folder had been refreshed and it was gone. Another session or a manual
  reset is the likely cause.

Verified with `Verify.bat` after each step: suite **2448**, docs 315/315, contract
unmoved, walkthrough passed. **Pushed** as `3ea00ab` (blink), `b707679` (sun,
balloons, settings fix) and `3362752` (hallway, mentor room).

## 2026-10-07 — speech on paper, centred faces, a third mentor move (build b45)

The owner's four asks, built in the game repo on Windows, plus a critique pass:

- **Faces are centred in their squares.** `tools/limezu_chars.py` cropped every bust
  from the top of the head, and the frame grew back to 96px, so heads sat high and
  hung off the frame. Re-baked all 28 busts; faces beside speech draw at 72px (3x).
  Each face now **blinks** (the `portrait_*_talk.png` strips an earlier session baked
  and never wired).
- **Speech is black ink on white paper**, in a pixel font: the dialogue box, the corner
  tip/day beat, and the in-room bubble, on LimeZu's white panel. The owner first
  rejected Tiny5 as unreadable and asked for "the same exact font as Pokémon".
  Nintendo's font cannot ship in a Steam game, so it is **Galmuri9** (SIL OFL, drawn
  after the Nintendo DS text) — see edusystem-speech-font (vault: `memory/edusystem-speech-font.md`).
  Long tips now wrap instead of running off the screen. The intro no longer says
  each line twice.
- **Answer-all bursts out of the teacher:** a ring of light; each answered child jumps
  with a "got it!" as the wave passes their desk.
- **A third mentor move: "Class, class!" — "Yes, yes!"** (key **Y**). From anywhere
  mid-lesson, attention snaps to full and holds for 5s wherever you walk. It costs
  half the voice meter (shared with settling) and has a 20s cooldown. It is pace only,
  and `tools/sim.gd` never calls it. The mentor teaches it on the visit after the
  chain dash and shows it with her own class. It is not grandfathered.
- **Critique fixes:** the status strip and prompt bar were clipped by a budget measured
  for a different panel. Docs counts and the build stamp were stale. Full list:
  critiques/edusystem-2026-10-07 (vault: `memory/critiques/edusystem-2026-10-07.md`).

Verified with `Verify.bat` on Windows: suite **2398** assertions (was 2356), docs
315/315, contract 0.63 C / 0.72 C / 0.97 A unmoved, whole-term walkthrough passed.
Screenshots were checked for every changed screen. **Pushed** at `045c543`, as three
commits.

**Owner decisions, 2026-10-07:**
- **Modern Exteriors is not being bought for now.** The owner will look for other art
  instead. Any schoolyard work waits for that art.
- **All three critique ideas are approved:** the move bar, dropping the duplicate
  bottom-bar prompts, and the pixel font across the whole UI.

**Built the same day (2026-10-07, second pass):**
- **The move bar.** Dash, answer-all and the call sit bottom right as LimeZu icons with
  their keys. A move only shows while it can be used. Each icon is shaded while the move
  recharges and flashes when it is ready. The recharge pips left the status strip.
- **The prompts are the badges over the teacher.** The bottom bar no longer repeats
  them; it is only ever the speech box now. A held verb's badge says "hold" and fills
  while you hold it.
- **Every word the player reads is in Galmuri9**, at 20 or 10 only, with a test on it.
  The font is larger than the old one, so about a dozen screens were re-fitted against
  before/after screenshots of all 69. The fixes: half-width bars, a taller text area,
  footers cut at a word, small print for footnotes, and a smaller face on a child's
  file. The dev tools keep the default font.
- **Screenshots no longer take over the screen.** The owner found full-screen Godot
  windows popping up every few seconds impossible to work beside. The screenshot tools
  now open a 1x window off-screen.

Verified with `Verify.bat` again: suite **2415**, docs 315/315, contract unmoved, and the
walkthrough passed. **Pushed** at `07bd73f`.

**State the vault recorded after this session** (from `context.md`, as written then;
the open items still live are carried in the vault `context.md` and `CLAUDE.md`):

**Everything through `07bd73f` is pushed; `master` and `origin/master`
are in sync (build b45).** **Pushing no longer verifies anything** — the pre-push
hook is disarmed as of `7de74d9`. Run `Verify.bat` first if the push
should be gated; it runs `check_docs` (315/315) and a whole term, plus the suite
(2415 assertions) and the contract. It passed all four before the last push.

**Immediate next focus:**
1. **Owner playtest:** The new LimeZu art, centred faces, Galmuri9 pixel font UI,
   move bar, and "Class, class!" mentor move have passed `Verify.bat` (2415 assertions)
   on Windows, but still need human eyes on screen during live gameplay.
2. **LimeZu build plan rollout (`limezu-build-plan.md`):** Continue through the
   approved tiers (Tier 4 animated life, Tier 5 explorable school visit polish,
   Tier 6 themed events, Tier 7 Modern Farm cosmetics).
3. **Schoolyard art:** The owner declined Modern Exteriors for now; holds on alternate art.

**Genuinely still open, none of it blocking "finished":**
- ~~The mentor-room screenshot~~ and ~~`mess_trash.png`~~ are both
  **fixed** — see the follow-up pass above. The mentor one was not the
  harness quirk this file claimed; it was blank in the real game too.
- **Bell rush** is still fully built and switched off
  (`bell_rush.enabled: false`) with zero player-facing UI or verb to
  trigger it — confirmed this session it has no interactable at all,
  only test-only API calls. Left alone on purpose: half-wiring a UI for
  it would be worse than the honest "not built yet" it already is.
- Everything in `next-level.md` past Session 2 (juice/readability
  polish, a director view for multi-room play, the lesson-crafting
  mechanic, the mastery-gated admin unlock) is still real, un-scoped
  future design, not part of this push.
- **Not done, deliberately:** anything Steam/store/distribution-facing —
  out of scope for this push by the user's own instruction.
- **Nothing is open in `docs/AUTONOMOUS_TASKLIST.md` any more.** This
  file previously said A1 (the second furniture batch) was still open —
  it is not, and was not: the repo marks it done in Aug 2026, commit
  `2494e66`, furniture 29 → 50. D2 was the last unchecked box and it was
  ticked in the follow-up pass. Likewise `next-level.md` Sessions 1–2 are
  **landed**, not pending — `moments` is live in `student_data.gd` and
  the persistent `meta` block is in `to_dict`/`from_dict` with
  `new_run()` sparing it.
- **The "noisy room" ambience bed is done** (`c17915f`, 2026-09-05,
  built by Antigravity/Gemini off an `agent-sync` brief, reviewed and
  merged here). `music_noise` is a resident layer in `music.gd`, faded
  each frame off the ratio of disrupting to seated students — a
  continuous mix, not a crossfade target. Silent outside a lesson,
  during a boss paper, and in tests.
- **Still genuinely open:** the B4 onboarding gap — still one sentence,
  and the repo's own note says the next slice must come from watching a
  real first run, not from a list.

## 2026-10-05 — the whole LimeZu menu is approved, and the school becomes a place

The owner read the measured pack inventory and approved **every block**: the emote
vocabulary, the kids' sleep row, the character-generator variation pass, animated life,
the Room Builder, the off-theme packs and Modern Farm. The order, the reasoning and the
four open calls are in **limezu-build-plan.md (vault: `projects/edusystem/limezu-build-plan.md`)**; the counted
inventory is the last section of limezu-ideas.md (vault: `projects/edusystem/limezu-ideas.md`).

Four directions they added that go past the art:
- **The school becomes explorable.** Unlock a room and you can walk into it and see it;
  the room you teach is lit, the others sit dim and raise their lights over a fade. It
  is a *visit*, not a second room to teach — the game puppets one room and a delegated
  room stays a `RoomSim` policy (edusystem-one-room-puppet-rule (vault: `memory/edusystem-one-room-puppet-rule.md`)).
- **The sleep row is for stuck students** — head-down, sulking, thinking and asking stop
  sharing one tinted bubble.
- **The character generator gets a juice pass** — unique faces everywhere, bolder
  colour, blinking and talking portraits, the unused Books and Smartphones layers.
- **Off-theme packs are fair game** for cute lessons and easter eggs, as seeded events
  that take themselves away — never permanent shop clutter. **Modern Farm** becomes a
  coin-bought cosmetic: students into chickens, the teacher into a cow. The animals walk
  4×6 like the cast but cannot sit or raise a hand, so the emote tier ships first.

**Repo tip:** the desktop is three commits past the `f4af2e7` recorded below — `b41e8d7`,
a Sprite Hub and a browser Forge panel, both built on Windows after the Mac session. The
new art has still never been through `Verify.bat` on Windows; that is T0 of the plan.
*(Superseded 2026-10-07: Verify.bat has run on Windows — see the next block.)*

## 2026-10-04 — LimeZu art is in the game and on GitHub

*Written from the repo after the Mac session; the sections below this block were last refreshed
2026-10-02 and do not mention any of this. How to resume on the desktop:
edusystem-desktop-pickup-2026-10-04 (vault: `memory/edusystem-desktop-pickup-2026-10-04.md`).*

The game repo is now **`Mbottega16/EduSystem`** (private; GitHub moved it from
`EduSystems-Code/EduSystem` and the old URL still redirects). `master` holds everything below,
pushed at `f4af2e7`: suite **2356** assertions, contract 0.63 / 0.72 / 0.97 unchanged, whole-term
walkthrough passed — all run on the Mac, never yet on Windows.

- **Art is mostly LimeZu's:** all 17 characters (Character + Portrait Generators) with the pack's
  real **6-frame walk** (sheets are 15 columns); 54 of 72 shop items; the room shell; the stuck
  bubble; an animated fish tank. The five main characters were restyled (teacher cardigan,
  inspector detective hat, principal plum waistcoat, examiner side-part). Details and the
  ownership rule: limezu-art-integration (vault: `memory/limezu-art-integration.md`).
- **Eight pieces hang on the wall** (item flag `wall: true`): clock, banner, letter frieze, world
  map, map corner, certificate, duty roster, coat hooks. They live on the wall row, take no
  floor, can't cover a window or a fixture; the room's starting decor gives way when you hang
  over its spot; old saves are rehung on load.
- **UI:** LimeZu's bamboo frame round every full-screen panel; the shop shows the item in a cream
  slot at a whole-number scale.
- **Room Ideas:** a sixth shop tab (five Tabs from the buy list) with seven validated template
  rooms (`data/room_templates.json`) drawn half size, plus what you own and what the rest costs.
  View only — nothing is bought or moved.

**Open, the owner's call:** 18 shop items + bell, ad poster, book, logo, lawn are still
hand-drawn; the framed boards (vocab board, web of life, word wall, rhyme chart, ten frame,
timeline, bug viewer, number line, chalk border) could hang too but compete for ~10 free wall
columns; "apply this template to my room" is not built; Modern Exteriors (the schoolyard) is not
bought. **Direction (owner):** love the LimeZu look; introduce it gradually, towards students
interacting with classroom items that make sense where they stand.

## Before 2026-10-04

Session logs from August to 2026-10-03 (build logs, commits, art passes, relay turns)
are archived in the vault at `projects/edusystem/history.md`. That file is frozen; new
entries go here.

---

## Appendix — long-form rule text, as it stood in CLAUDE.md on 2026-10-24

The rules still hold; `CLAUDE.md` has the short form. This is the full wording with the
reasons and the incidents behind each one, kept so nothing was lost in the cut. Where a
detail here is out of date, `CLAUDE.md` is right (for example, **L** now starts the lesson
and **F** is bell/shop only).

### The one golden rule

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
### Hard constraints (non-negotiable)

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
### How to verify EVERY change

Run these from the project root. **Read the assertion COUNT, not the word
PASSED** — a broken script can still print PASSED with a silently lower
count. That has happened three times.

```
Run Tests.bat            3076 assertions — must pass, count must not drop
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


### Working rhythm

1. Make a small, additive edit.
2. `Run Tests.bat` → count went **up**, nothing failed.
3. Run whichever tool covers what you touched (see table above).
4. Screenshot anything visual.
5. Commit, with a message that says *why*, not just what.
6. `git push` — the remote is `Mbottega16/EduSystem` (private; GitHub moved the
   repo there from `EduSystems-Code/EduSystem`, and the old URLs still redirect).

#### Steps 2 and 3 are yours to run. The hooks are OFF by default.

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
### The citation rule

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

### File map (as it stood)

| | |
|---|---|
| `scripts/autoload/game.gd` | The run: day, coins, roster, grading, terms, school. The big one. |
| `scripts/data/` | Every data layer — balance, students, curriculum, items, traits, assignments, staff, milestones |
| `scripts/world/` | grid, layout, classroom (the world root), room_builder, placement, hallway (the corridor between the rooms you hold), trophy_case (the hallway's, a place per boss trophy), window_butterfly (the butterfly that flies out of the second window and back), ambient_touches (the idle room's five small moving touches: drip, leaf, bird, spider, intercom lights; off in a lesson), mentor_room, principal_office and visit_room (rooms off the corridor you visit but never run; visit_room is any room you hold, its last day replayed), live_room (a classroom of one stage of the school, running forever on a fixed hash, never Game.rng; the hallway's grade wing is four of them, above the corridor wall, with a door and a plaque each) |
| `scripts/actors/` | actor, player, student |
| `scripts/interact/` | one file per landmark verb |
| `scripts/ui/hud.gd` | Every screen. 23 modes; ~ten of them share `REPORT`. `principal_says()` is the tutorial mascot — a once-per-run corner popup, portrait and all. |
| `data/balance.json` | **Every tunable number** |
| `data/curriculum.json` | 40 lessons, 120 concepts, real standard codes |
| `data/room_templates.json` | **Room ideas** (shop tab, Tab x5): seven ready-made layouts of the opening room built from real shop items, for players to take inspiration from. `scripts/data/room_templates.gd` `problems()` checks each against the placement rules (also `tools/check_templates.tscn`, and the suite). Inspiration only: nothing is bought or moved |
| `data/tutorials.json` | **Tutorial cutscenes**: ten short scripts (id, title, trigger event, 3-6 steps of speaker + text + optional pointer + optional demo). `scripts/data/tutorials.gd` (`TutorialData`) reads and checks it; `scripts/ui/tutorial.gd` (`Tutorial`) plays one over the room. State: `Game.tutorials_seen`, `Game.tutorials_enabled` (off in every headless run and tool; `main.gd` turns it on for a real player) |
| `tests/run.gd` | The suite — 3076 assertions, 146 sections |
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

## Appendix B — the vault context.md's standing sections, as they read before 2026-10-24

Word for word. The current, shorter version is the vault's `projects/edusystem/context.md`;
the owner's long-term vision there is a summary of the interview text below.

### EduSystem — current state

*Snapshot, not a live link. Refresh manually as the game moves forward —
it will go stale otherwise. Last refreshed 2026-10-10 from the real repo
at `master` (the talking / study folder / grade book commits on top of
`670f5f9`, build b45) — `git log`, `git status --short`, and a direct read
of the new/changed files. Read from the repo, not assumed.*

**Skills for this project:** deep_furniture (vault: `skills/deep_furniture/SKILL.md`) ·
deep_balance (vault: `skills/deep_balance/SKILL.md`) ·
deep_trait (vault: `skills/deep_trait/SKILL.md`). Portfolio-wide:
deep_refresh (vault: `skills/deep_refresh/SKILL.md`) ·
deep_critique (vault: `skills/deep_critique/SKILL.md`) ·
vault-sync (vault: `skills/vault-sync/SKILL.md`). The technical map lives in
the game repo at `docs/ARCHITECTURE.md`; the plain-language companion is
architecture-visual.md (vault: `projects/edusystem/architecture-visual.md`).

#### What it is
A Godot 4.7 pixel-art classroom-management sim. You play a teacher (or
run a whole school of them). The game's own repo is private and already
exists — this vault does not touch it directly.

**Naming note (renamed 2026-08-30, on the user's instruction):** this
project is now **EduSystem** everywhere in the vault — every file, path,
slug, and label here has been switched over from its former name. The
game's own repo, its local folder, the Notion "Project" value, and the
git history still carry the old name — those are separate renames the
user does at the source.

**Do not confuse it with `projects/edusystems/`** (with an *s*) — that
is a different, older, inactive HTML5 game. EduSystem (this project, the
Godot game, active) and EduSystems (that one, archived) are one letter
apart on purpose; the user picked the shorter name here.

#### Who it is for
Players of pixel-art management/sim games. No formal audience research
or marketing persona exists yet in the repo's own docs — this is a
genre-level description, not invented positioning. `docs/STEAM_PAGE.md`
is where that gets worked out when it's time.

#### Where it stands

> **Historical build logs (August?September 2026, commits, art passes, and relay turns)** have been archived verbatim to `history.md` (vault: `projects/edusystem/history.md`) so this file stays fast to read at session start.

#### The next-level roadmap
`next-level.md` (this folder) is the agreed multi-session plan for taking
the game past "competent sim" — the bet is **making students into
characters the player remembers and surfacing their stories**, then a
persistent cross-run meta-layer, unlock-a-verb progression gates, juice,
and room identity. Session 1 = the student-story core + a persistent
`meta` save block.

#### Decisions already made
These are load-bearing, not stylistic — changing any of them means
re-verifying the balance contract above:
- **Determinism.** Every random decision goes through one seeded
  `Game.rng`; global `randi()`/`randf()` are banned project-wide.
- **Numbers live in `data/balance.json`, never hardcoded in a script.**
- **Prose, never numbers, in anything player-facing** — enforced by a
  test, not just a convention.
- **Automation may do legwork, never judgement about a specific
  child** — the one deliberate, named exception is `Game.auto_teach`,
  built only after explicitly confirming the tension with the user first.
- **One dedicated key per verb**, global rather than landmark-contextual
  — E is the mashable/reversible verb, everything else got its own key.
  Dash now fires on a double-tapped direction (Shift is a kept alt);
  F moved to the cabinet/shop, L starts the lesson, J is "answer all".
- **Advanced verbs are gated behind the mentor.** The dash and "answer
  all" are mechanically locked until the mentor teaches them — the intro
  no longer front-loads a control sheet. Existing saves are grandfathered.
- **Boss readiness is prose, never a number** — the mentor gives a
  RoomSim confidence tier ("your room looks ready"), not an ELO or a %.
- **The roguelike subject boss is a named exception** to `SALVAGE.md`'s
  "no ELO / no boss manager" rule, like `Game.auto_teach` in CLAUDE.md.

#### Long-term vision (from the user, 2026-08-24 — a full interview, not a
guess)
- **Playthrough length is meant to be flexible** — however long a given
  player wants to treat it. The core design goal is dopamine density in
  the loop itself: the moment it starts to slow down, the player should
  have an easy, friction-free reset/restart, rather than being stuck in
  a run that's stopped being fun.
- **Steam is the eventual real goal.** itch.io is explicitly just a
  playtester distribution channel, not the intended long-term home. The
  Steam submission fee ($100) is something the user is prepared to
  spend once the game is closer to ready.
- **Mac/Linux/Steam Deck compatibility is wanted, but explicitly not a
  focus** — nice-to-have, not something that should eat majority time.
- **Monetization: free-to-play, ad-supported, for now** — a real
  decision (confirmed directly, not invented), superseding the "pricing
  fully undecided" framing in `business.md`/`offers.md` for this
  specific project. Those vault-level files may need a matching update
  next time they're touched.
- **The game is meant to be open-ended and replayable forever** — but
  the user explicitly named the real tension: a finite curriculum
  doesn't naturally support an infinite game. The proposed solution
  (not yet built, a real open design direction): a **lesson
  planning/development mechanic**, where the player crafts and
  iterates their own lesson variants against a lesson's fixed learning
  objective/mechanical hooks — e.g. "Algebra II, Visual Lesson, v15" —
  so the *infinite* axis is lesson quality/variation the player
  personally refines over time, not lesson *count*. This is the
  leading candidate for solving the finite-curriculum problem, not yet
  scoped into a real spec.
- **No named school, district, or town, on purpose** — the setting is
  meant to feel like it could be anyone's school, not a specific place.
  Not an oversight; don't propose naming it.
- **The player-teacher has no name or backstory on purpose** — framed
  only as "a teacher burnt out by the system." The game's entire story
  is meant to emerge from the simulation itself, not a scripted
  narrative arc (no rival teacher, no plotted crisis/ending planned).
- **No visual style reference exists beyond what's already shipped** —
  the pixel-art direction is self-defined, not drawn from an external
  mood board or another game.
- **Art pipeline: Gemini-generated, workflow still being built by the
  user** — they'll paste results back into a session for integration
  (Claude Code doesn't have IDE/VS Code access on their end yet, so
  this stays a manual paste-back loop for now, same shape as the
  ChatGPT/Gemini furniture-batch pipeline in `docs/TASK_PACK.md`).
- **Scope-gating for multi-room/admin play, a real progression design:**
  the game should start scoped tightly to being a single classroom
  teacher. Only once the player has demonstrably learned the core loop
  — grading, lesson planning, room orientation, giving quizzes,
  "everything" — over a couple of in-game days, should the game open
  up the option to be considered "admin" and manage multiple
  classrooms/districts. This reframes the existing multi-room/delegate
  system as something to be *unlocked through demonstrated mastery*,
  not available from day one the way it currently is.
- **The next system after the furniture batch closes:** a more fully
  fleshed-out management simulator layer. Sequencing matters here —
  the user wants automated teaching (`Game.auto_teach`) solid and
  first-class *before* building the player's admin-layer job, which
  they framed as "teaching teachers how to teach" — i.e. the admin
  layer isn't just hiring/firing/delegating (already built), it's
  actively coaching the delegated teachers themselves.

**None of the above is implemented.** This is durable direction, not a
task list — several pieces here (the lesson-crafting mechanic, the
mastery-gated admin unlock, the teach-the-teachers admin layer) are
real, separate design efforts each worth their own planning pass before
any code gets written.

#### Why this file exists
So a session opened in *this* vault (not the EduSystem repo) can answer
"where does the game actually stand?" without re-reading EduSystem's own
`CLAUDE.md`/`docs/GDD.md`/`docs/AUTONOMOUS_TASKLIST.md` from scratch.
For anything beyond a quick status check, those are still the real
source of truth — this is a summary, not a replacement.


#### 🗺️ Visual Architecture

**Superseded 2026-09-07.** The two loose sketches that were here (a
"teacher gets tired → drinks coffee" day loop and a "buy a desk" flow)
were an early, inexact pass. The real map now lives in the game repo:
**`EduSystem/docs/ARCHITECTURE.md`** — five Mermaid diagrams (module
ownership + signal flow, the three-phase day, the grade pipeline, where
tunables live, the verification harness), validated with `mermaid-cli`,
rendered in place on GitHub. It is the authoritative picture; keep it
there, not duplicated here.
