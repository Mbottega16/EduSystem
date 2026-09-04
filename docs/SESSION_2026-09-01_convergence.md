# Session record — 2026-09-01 — the EDUSystem convergence push

A handoff note for the "my brain" vault / Notion. This session ran in
Claude Code, in the repo directly. It is **not** wired to Notion or
Obsidian — the repo is the record. The full working plan lives outside
the repo at `~/.claude/plans/okay-this-far-and-pure-lampson.md`; the
git log is the source of truth.

## What this was

One large push, run as a sequence of small verified commits, to:

1. finish the rename PixelRoom -> **EDUSystem**
2. rework dash (double-tap trigger + visible cooldown)
3. add an "answer all questions" mass-help skill with its own cooldown
4. add subject-specific items
5. build a real storage cabinet (buy -> cabinet -> place) + a cold-open
   intro where the teacher pulls the desks out of it
6. bring back the roguelike endgame subject boss + per-boss trophies

Decisions taken up front (from you): phased PRs verified between each;
RoomSim projection for boss readiness, not ELO; both boss modes chosen
at the term fork; full rename with save migration; answer-all = mass
help, no grade/coins; subject items as a new class, the 54 originals
untouched; cabinet = real persistent storage (full reroute); boss stakes
= lose is run-over, win is a trophy + a cosmetic room piece.

## Shipped (9 commits, `1301a86` -> `4981f69`, all pushed)

| Phase | Commit | Result |
|---|---|---|
| 0 | `8f585e8` | Deleted the empty `EduSystem/` folder + orphan logo import; naming glossary added so "EDUSystem" (this game) and "the EduSystems prototype" (the archived HTML/JS predecessor) can't be confused. |
| 1 | `235c98e` `799e14d` | **Full rename to EDUSystem** — `config/name`, all save/settings filenames, the test-completion sentinel (run.gd + Run Tests.bat + the pre-commit hook, together), export presets, the generated logo wordmark (5 new 5x7 glyphs for D U S Y T), the launcher filename, dev-tool titles, every doc. `Game.migrate_legacy_user_files()` carries a pre-rename save + settings across the moved `user://` directory on first launch, once, real-game only. |
| 2 | `38faf1a` | Dash fires on a **double-tapped direction** within `teacher.dash_double_tap_window` (Shift kept as an alt trigger). Cooldown lengthened 0.35 -> 1.3s so the new HUD meter means something. A `dash ‖·` pip on the status strip, shown only while recharging. |
| 3 | `813bfc6` | **"Answer all questions"** — key **J**, its own `KEY_ACTIONS` entry, wired at the podium exactly like the quiz (connected in both `build()` and `rebuild_room()`). One press clears confusion + resolves flagged quizzes for the whole room. Pays **no grade, no coins**; costs 16 lesson-seconds + a 75s cooldown. `_one_lesson()` source-scan guard added so a future sim can't quietly start using it. |
| 4 | `3b07429` | **Subject-shelf items** — Rhyme Chart / Number Line / Bug Viewer / Map Corner, one per strand (ela/math/science/social). Each carries a `strand` + `strand_bonus`: `room_score()` pays the ordinary bonus any day and the strand bonus on top only when today's lesson matches. Cannot move the contract — `room_score()` clamps to `room_cap`. New sprites drawn + imported. Item count 50 -> 54. |
| 5a | `a19ad72` | **The cabinet — full storage reroute.** Buying furniture drops it in the cabinet (charged then, shop stays open); you place it from the new CABINET tab (replaced SELL in the same 5-stop Tab cycle) or from a new physical cabinet landmark on the back wall (MANAGE key, wired in build + rebuild). `store_item` packs a placed item away (build-mode F, was "sell"); `sell_from_cabinet` is the only disposal path now, for half price. `cabinet` is saved; an older save loads it empty. `Game.place_item` kept for tools/tests. |
| 5b·1 | `114cefb` `4981f69` | Intro copy fixed — the storyline pages still said "F starts the lesson" (it's L now; F is the cabinet/shop). Slate reworked to set up the cabinet in the corner and "start with the desks", pointing toward the cold-open scene. |

**Balance contract 0.63 / 0.71 / 0.97 verified unmoved after every
gameplay phase.** Suite: 1375 -> **1439 assertions**, green.

## Not done *(at the time -- see the 2026-09-03 note at the end)*

- **Phase 6 — the roguelike subject boss FIGHT.** The trophy shelf is
  built (`8cb3f9c` -- `scripts/data/trophies.gd`, `Game.trophies`,
  `award_trophy`, save/load, shown on the career screen). What is NOT
  built is the encounter that calls `award_trophy`: a boss term in the
  `TermPaths` fork (a subject boss you specialise against, or a
  randomised gauntlet for a rarer trophy); RoomSim projection ("your
  room looks ready" in prose) for readiness; losing a boss term is a
  run-over like a missed target; winning also unlocks one cosmetic decor
  piece. To be documented as a deliberate exception to
  `docs/SALVAGE.md`'s "no ELO / no boss manager" guidance, the same way
  `Game.auto_teach` is an exception in CLAUDE.md.

## Follow-on work done after the first handoff (commits `be49fa4`..`7896529`)

- **`be49fa4`** — audit tool now covers every verb (built from
  `Interactable.KEY_ACTIONS`, so L/K/J show), plus a cabinet row; and
  `respond` was added to `player.targets` (the one action missing from
  the literal).
- **`8c856b5`** — `/deep_update` pass: resynced the counts that drifted
  across the phases and did NOT machine-check -- balance sections
  37 -> 39, `static var` tunables 187 -> 192 (CLAUDE.md and GDD.md
  disagreed here; unified), suite sections 91 -> 94, milestones 22 -> 23,
  GDD header date. `check_docs.py` was already green on the machine-checked
  facts.
- **`8cb3f9c`** — Phase 6 groundwork: the boss trophy shelf (5 trophies,
  `Game.trophies`, `award_trophy`, save/load, on the career screen). No
  boss fight yet -- nothing calls `award_trophy`.
- **`7896529`** — Phase 5b, the cold open: leaving the slate empties the
  room, the teacher walks to the cabinet and pulls each desk out, then
  the class comes in. Desk rebuild goes through its own signal so it does
  not re-roll mess off `Game.rng`. `test_scene()` drives it end to end.

Suite now **1473 assertions**, `check_docs` 299/299, contract still
0.63/0.71/0.97.

## Caveats

- **The cold open needs a visual check.** `test_scene()` proves the logic
  (room empties, teacher walks to the cabinet, eight pulls, class in,
  pages, teacher at the front), but nobody has *watched* it. Launch
  `Play EDUSystem.bat`, start a New term, and confirm it looks right --
  the desk sprites landing on their seats, the teacher's path, the dust
  puff. The title/scene screenshot tool hangs in the Claude Code
  environment, so this one is on you.
- **No visual verification** of the rest either — logo wordmark,
  status-strip cooldown pips, cabinet prop and screen, the career
  screen's trophy rows. All covered by headless assertions.
- Harmless **pre-existing** "2 ObjectDB instances leaked / 1 resource in
  use at exit" warning on every suite run. Present before this work,
  does not fail the gate.
- **Manual, off-repo:** the GitHub repo is still `EduSystems-Code/PixelRoom`
  (GitHub auto-redirects a rename; `CLAUDE.md` documents the current name
  honestly). The Desktop `Play PixelRoom.lnk` shortcut still has the old
  name. Confirm the save migration lands your real dev save on first
  launch of the renamed build.

## Update, 2026-09-03

The boss FIGHT is built: the last day of a boss term is now played in
the room, in rounds, against the card's own move list --
`scripts/data/boss_fight.gd`, documented in `docs/ROGUELIKE_DESIGN.md`
("The fight"). The trophy shelf, the term-path card and the bar it is
judged against are unchanged; the fight feeds a small, clamped
per-child nudge into the exam the class sits at the bell.
