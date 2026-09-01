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

## Not done

- **Phase 5b — the cold-open cutscene** (empty room -> teacher walks to
  the cabinet -> pulls the desks out one by one -> class files in). The
  backstory/copy is in; the cutscene is not. It restructures when desks
  and students spawn (touches `build_desks`, `_spawn_students`, and the
  intro state machine across `hud.gd` + `main.gd`), and the project's #1
  rule is "verify by looking at the running game" — this environment's
  title/scene screenshot tool hangs, so I would not commit an
  unverifiable cutscene blind. `test_scene()` already drives the intro
  end to end and can be extended to verify it.
- **Phase 6 — roguelike subject boss + trophies.** Not started. The full
  design is in the plan file: a boss term in the `TermPaths` fork
  (subject boss you specialise against, or a randomised gauntlet for a
  rarer trophy); RoomSim projection ("your room looks ready" in prose)
  for readiness; losing a boss term is a run-over like a missed target;
  winning gives a trophy (`Trophies` table, parallel to milestones,
  pays/gates nothing) plus one cosmetic decor piece. Documented as a
  deliberate exception to `docs/SALVAGE.md`'s "no ELO / no boss manager"
  guidance, the same way `Game.auto_teach` is an exception in CLAUDE.md.

## Caveats

- **No visual verification** of anything from Phases 1-5 — logo wordmark,
  status-strip pips, cabinet prop, cabinet screen. All covered by
  headless assertions; a real screenshot pass is worth doing.
- Harmless **pre-existing** "2 ObjectDB instances leaked / 1 resource in
  use at exit" warning on every suite run. Present before this work,
  does not fail the gate.
- `audit.tscn`'s columns are still E/F/Q/H/M — it never grew columns for
  L/K/J, so it does not display the teach / respond / answer-all verbs.
  Not a regression; the suite covers them. Worth updating the tool.
- **Manual, off-repo:** the GitHub repo is still `EduSystems-Code/PixelRoom`
  (GitHub auto-redirects a rename; `CLAUDE.md` documents the current name
  honestly). The Desktop `Play PixelRoom.lnk` shortcut still has the old
  name. Confirm the save migration lands your real dev save on first
  launch of the renamed build.
