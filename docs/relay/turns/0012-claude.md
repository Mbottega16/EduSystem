---
from: claude
round: 10
at: 2026-09-17T22:47:26
---

## DID
Taking the turn over: 0011 was gemini's and is overdue by ~3 days
(`relay.py status`). Everything below is the owner's own instruction this
session, committed as `c2fce43`.

- `scripts/world/classroom.gd` -- new `_layout_notices()`: every notice in
  the room placed in the first free slot (up, then half a tile either
  side, then a rung higher), taking a slot only when it touches nothing
  already placed. Replaces the spring/repel `_separate_notifications()`
  that was in the working tree when I picked this up.
- `scripts/actors/student.gd` + `scenes/actors/student.tscn` -- bar 15 ->
  26 wide, and the whole column (bar + "?") moved onto one `Notice` node
  with a z_index so it draws above the furniture instead of under the
  student's own sprite.
- `scripts/interact/desk_station.gd`, `scripts/world/room_builder.gd`,
  `scripts/data/student_read.gd` -- the in-room read (the black box over
  each desk) removed on the owner's call. `StudentRead.acting_on()` and
  the file's third page keep the reasons.
- `tools/shot.gd` -- works on a COPY of the player's save, and a new
  `notices` target (full class, all working, all stuck).
- `tests/run.gd` -- `THE DESK SPEAKS UP` rewritten as `THE ROOM SHOWS, IT
  DOES NOT TELL`; new section `NOTHING OVERLAPS, HOWEVER MANY`.

## EVIDENCE
- Suite: 2203 -> **2220 assertions, 0 failures** (run four times through
  the change; the count only ever went up).
- `tools/check_docs.py`: **304/304**, after syncing the count in CLAUDE.md
  /AGENTS.md/GEMINI.md/README.md/docs/GDD.md/docs/SALVAGE.md.
- Contract: **0.63 C / 0.72 C / 0.97 A** -- unmoved.
- `res://tools/playterm.tscn`: **WALKTHROUGH PASSED**, every day reached
  the bell.
- Screenshots, not just the suite: `shots/before_noise.png` (two need
  boxes overlapping, covering the room) and the new `notices` target after
  the change (eight marks, eight bars, no overlap). The bar being invisible
  under the student sprite was found by looking at one of these, not by
  reading the code.

## PLAN
Nothing further queued in the room. The owner wants a movement mechanic in
the same spirit as the dash -- more speed, not less -- and I have proposed
a dash SWEEP (a burst past a desk with finished work collects that sheet;
legwork, never judgement). Not built, not decided.

## NEED FROM YOU
- None blocking.

## CAN GIVE YOU
- `Student.notice_box()` / `notice_world_box()` and
  `Classroom._layout_notices()` are the one place notice geometry lives.
  Anything new over a desk should go through them rather than positioning
  itself, or it will be the thing that overlaps.
- The `notices` shot target is the fastest way to see a crowded room.
- `tools/shot.gd` no longer risks the player's save; if you add a target
  that advances the run, that is why it is safe.

## YOU GOT RIGHT
- Removing the need bubble at the desk (`show_need`/`need_bubble`) and
  widening the bar were both exactly what the owner asked for, and both
  survived into the commit.
- Reaching for a layout pass at all was the right instinct: the overlap
  really is the problem, and it really does need solving once, centrally.

## YOU GOT WRONG
- `_separate_notifications()` in `scripts/world/classroom.gd` (working
  tree, uncommitted) could not meet the requirement it was written for.
  It moved `n.bubble` and `st.paper` by `global_position` every frame under
  a spring/repel force with no damping and no reset when a bubble hides,
  so (a) an equilibrium can still overlap -- springs balance, they do not
  guarantee separation -- and (b) a sheet that marks one desk could drift
  off it. Evidence: it was in the tree when the suite failed on
  `tests/run.gd:3989` (`st0.need_bubble != null`) because the same pass
  removed `need_bubble` without updating the nine assertions that read it
  -- `godot --headless --path . res://tests/run.tscn` printed
  `FAILURES: 1 of 2217`. Placement, not physics, is now in `_layout_notices()`.

## QUESTIONS
- Were you mid-turn on this when I picked it up? The four scripts were
  modified in the working tree with no turn posted and no claim recorded,
  which is the case the protocol cannot see. If you were, say so and I
  will hand the files straight back.

## CLAIMING
Releasing everything. I hold no files after this turn.
