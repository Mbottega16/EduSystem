---
from: claude
round: 9
at: 2026-09-14T09:33:22
---

## DID
Continued round 8 (turn 0009 was still overdue -- see relay.py status).
Three items from the owner's own backlog, started on their explicit
request this session. Full detail in the commit message (`f7e4331`,
pushed); summary:

1. **SaveManager wiring.** `Game.save_to_slot()`/`load_from_slot()`/
   `has_slot()`/`slot_day()`/`delete_slot()` bridge the 8-slot
   SaveManager to `Game.to_dict()`/`from_dict()`. Writing its first-ever
   test found two real pre-existing bugs in `SaveManager.delete_slot()`:
   missing `globalize_path()` before `DirAccess.remove_absolute()`, and
   treating that call's `Error` return (OK == 0) as a bool, so a
   successful delete reported `false`. Both fixed. No UI built --
   deliberately out of scope for "wiring".
2. **Homework-marking policy.** `playterm.gd` now visits the teacher's
   desk after each lesson and marks whatever it's carrying, accurately,
   against `Questions.sheet_is_good()`. `GATE_COMPETENCE` stays OFF --
   measured, not assumed: a real run still misses the term's target even
   with marking on.
3. **Named lesson-crafting styles.** `Game.CRAFT_STYLES`, assigned on a
   lesson's first craft, kept across relevels. Cosmetic only -- every
   style runs the same `craft_work_mult()` as before. Surfaced on the
   two free-form report lines, not the dense per-row list (didn't want
   to risk that screen's column layout sight-unseen).

Verify.bat clean end to end: suite 2203/2203 (2189 + 14 new, all
passing), docs 304/304, contract 0.63C/0.72C/0.97A, whole term
WALKTHROUGH PASSED.

## EVIDENCE
- `test_save_slots()` and the craft-style additions to
  `test_lesson_crafting()` in `tests/run.gd` -- both failed for real
  before the two SaveManager fixes and the test-logic fix described in
  the commit, confirmed by re-running, not assumed.
- Verify.bat log: suite/docs/contract/walkthrough all green, run
  multiple times across the session.
- The competence miss is the walkthrough's own printed verdict line,
  not inferred.

## PLAN
Nothing further planned this round beyond handing back. If a future
round wants to build on this:
- A slot-picker UI (title screen or pause menu) is the natural next
  step for #1 -- not scoped here.
- Style-specific mechanical effects, and letting the player pick a
  style instead of rolling one, are the natural next step for #3 -- not
  decided here on purpose (see NEED FROM YOU).
- Closing the competence gap for #2 needs more than marking; not
  investigated further this round.

## NEED FROM YOU
- None blocking. Two real design questions are open whenever there's
  appetite: what a save-slot picker should look like (and where it
  lives), and whether lesson-craft styles should ever do something
  mechanically different from each other, or stay a name.

## CAN GIVE YOU
- A clean, fully-verified master (`f7e4331`), pushed.
- `art/table.png`, `art/wizard.png`, `tools/sprites/table.txt`,
  `tools/sprites/wizard.txt` are mid-edit, live owner work from Master
  Forge this same session -- untouched, still uncommitted. Not this
  round's claim.

## YOU GOT RIGHT
- n/a -- nothing from a previous round touched by this one.

## YOU GOT WRONG
- n/a

## QUESTIONS
- none

## CLAIMING
- Releasing everything -- nothing held.
