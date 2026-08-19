# The standing task menu

What `/deep_grind` picks from, and what `/loop /deep_grind` works through
while you are away. **Every task here is small, verifiable, and additive.**

## How to use this list

Pick the highest-value task that is **not done** and whose dependencies
are met. Do one full cycle: implement, verify, screenshot if visual,
commit with a message that says *why*, tick it off here.

**One task per cycle.** A cycle that touches three things cannot be
bisected when it breaks.

**Unless the tasks are genuinely independent — then run them in
parallel.** When more than one unblocked task touches different files
with no shared state (a different data-file section, a different tool
script), dispatch them as separate `Agent` calls with
`isolation: "worktree"` instead of grinding through them one at a time.
Each agent gets its own git worktree, so they cannot step on each other's
edits. The content-integration batches in section A are the clearest
case: task 2 (items) and task 3 (traits) touch different sections of
`balance.json` and were genuinely safe to validate and integrate in
parallel once both were back. Do not parallelize tasks that touch the
same file, or where one task's output is the input to another.

### The bar for finishing a task

```
Run Tests.bat            count went UP, nothing failed
python tools/check_docs.py
```

plus whichever of these covers what you touched:

```
Simulate a Term.bat      anything touching grades, coins or the contract
Trace a Day.bat          anything touching the day's flow or the buttons
Audit the Room.bat       anything touching what E or F offers
Simulate the School.bat  anything touching staff or delegated rooms
Take a Screenshot.bat    anything visual. Headless never proves this
```

**Read the assertion COUNT, not the word PASSED.**

### Rules that override anything below

- Never move the balance contract. If a task would, stop and flag it.
- Never delegate a decision about a particular child to automation.
- If a task turns out to be bigger than one cycle, **split it and write
  the split back into this file** rather than half-doing it.
- If you finish a task and the count did not rise, you did not add a
  check. Go back.

---

## A. Content integration — do these the moment a batch lands

These are not optional work; they are the queue. Prompts live in
`docs/TASK_PACK.md`.

- [ ] **A1. Integrate task 2 — 21 items of furniture.** *(One round
      rejected Aug 2026.)* Validate with
      `python tools/check_items.py <file.json>` before touching
      `balance.json`. Reject rather than patch: an item outside the
      360–840 density window, a near-duplicate of the existing 29, a
      blurb that reads like a catalogue, or a concept link that does not
      make sense. The first submission failed on all counts — every item
      was missing `name` and `art` entirely, two ids (`beanbag`, `globe`)
      collided with existing items, and every `teaches`/`needs` cited a
      concept id from a stale, unintegrated curriculum draft rather than
      the real file. The prompt in `docs/TASK_PACK.md` is unchanged and
      correct; that round just didn't follow it. Re-send, don't patch
      around it. Then art, then a screenshot of the shop.
- [x] **A2. Integrate task 3 — 6 student traits.** *(Done Aug 2026.)*
      Loud, Shy, Restless, Panics, Anchor, Ghost — 6 to 12. Every one
      carries two hooks in tension rather than one bare multiplier: Ghost
      hides AND self-resolves by copying, so a player may never learn
      there is a gap until a test exposes it. `tools/check_traits.py`
      validates future submissions against the real hook set.
- [ ] **A3. Integrate task 7 — 11 day events.** Weights must still total
      roughly 100 and "an ordinary day" must stay the most common outcome
      by a wide margin.
- [ ] **A4. Integrate task 8 — homework banks to 24 each.**

## B. Real gaps, found by counting — highest value first

- [x] **B1. What a concept is for.** *(Decided and implemented Aug 2026.)*
      The finding was bigger than "112 aren't linked": `concept_bonus`
      caps at **ten** concepts, so 110 of the 120 move no number at all.
      Decision — **concepts are texture, not a collection** — is written
      into `docs/GDD.md`.
      The cap stays (raising it moves the contract, and row three is
      already 0.97). The board no longer prints `Curriculum (8/120)`,
      which promised a completion target and made a teacher's own subject
      knowledge look like a checklist she was failing. Item links are
      curated at roughly twenty across 50 items, and task 2's quota rose
      from 4/3 to 7/5 to close most of that gap.
      **Still open:** the ~20 target is not reached until task 2 lands.
      Re-count after integrating it.
- [x] **B2. The dead `icon` field.** *(Done Aug 2026.)* Nothing in
      `scripts/`, `tools/` or `tests/` read it — zero references. Ten of
      forty held an emoji, which the briefing bans in game text, and the
      other thirty were an invitation to spend a cycle filling in a field
      no screen renders. Deleted, with an assertion so it cannot drift
      back, and a note in `PLAN-tiers-buffs-shop.md` for whoever builds
      the icon column later.
- [x] **B3. Numbers in player-facing text.** *(Done Aug 2026.)* The
      curriculum screen printed *"Knowing your subjects is worth +12% to
      every grade"*; it is now banded prose, with the thresholds taken as
      a ratio of `concept_bonus_cap` so no number moved into code. The
      `bookshelf` blurb is now *"Reaches further than it looks like it
      should."*
      **The rule was only ever enforced on the student file**, which is
      how both survived — and the row test actually *allowlisted* the
      violation by accepting any line containing `"worth +"`. Coverage now
      extends to the curriculum screen and every item blurb.
      *Correction: the third suspect, `"room 40%  lesson 0%  hw 3%"`,
      appears only in comments describing what that screen used to print.
      A false positive in the scan that produced this list — grep the
      strings, not the file.*
- [x] **B4. Onboarding — first slice.** *(Done Aug 2026.)* One sentence,
      at the moment it explains something the player has just watched:
      *"Work only moves while you are at the front."*
      It fires on the **downward crossing** of an attention threshold, not
      when you step away — walking to a stuck child *is* the game, and a
      nudge fired then would read as "do not do that". By the time
      attention has fallen that far the player has already seen the work
      slow, so the line explains rather than pre-empts.
      The threshold is `teaching.drift_hint_below` in `balance.json`,
      because numbers do not live in code. `hint_once()` already existed
      and was used exactly once in the whole game; this is the second
      caller.
      **Still open:** this is one line, not onboarding. Nothing yet
      teaches collecting, marking, the shop, or what the term target
      means. Next slice should come from watching a real first run, not
      from a list.

## C. Verification debt

- [x] **C1. Assertions that test a count instead of a claim.** *(Swept
      Aug 2026.)* Automated the sweep — extract every `size() == <int>` /
      `count() == <int>` literal from the suite and cross-reference it
      against the ten live content counts. **No remaining matches.** The
      one real instance (`lessons.size() == 20`) was found and fixed
      during the task-1 integration; everything else compares against
      state the test itself created, which is legitimate. Re-run the
      sweep after any content batch.
- [x] **C2. Panel fit-test the screens that grew.** *(Done Aug 2026, and
      it found a live bug.)* The curriculum screen and the shop both
      **window** their lists with `...` markers, so 40 lessons and 50
      items do not clip. But the shop prints an item name through
      `substr(0, 13)` into a `%-13s` column and **cuts anything longer
      with no warning** — and nothing constrained the field.
      Two shipped items were already truncated: *Alphabet Frieze* rendered
      as "Alphabet Frie", *Supply Cabinet* as "Supply Cabine". Renamed to
      **Letter Frieze** and **Store Cabinet**. Eight of round one's
      twenty-two would have been cut. Now asserted, in the task-2 prompt,
      and in `check_items.py`.
- [x] **C3. Assert the art contract.** *(Done Aug 2026.)* The per-item
      check used `ResourceLoader.exists()`; it now also `load()`s, because
      `art/inspector.png` once existed, passed every file-exists check in
      the project, and still threw at runtime because nothing had imported
      it. The directory sweep already loaded every PNG and covers all 71
      (no subdirectories).

## D. Housekeeping

- [~] **D1. `.godot/` and OneDrive.** Git half was **already done** —
      `.godot/` is in `.gitignore` and zero files under it are tracked.
      **The OneDrive half needs the user**: excluding a folder from sync
      is a setting in the OneDrive client, not something a script can set
      reliably. Right-click `.godot` in Explorer → *Always keep on this
      device* off, or move the repo outside OneDrive.
- [ ] **D2. Run `/deep_update` after any batch integration.** Counts move
      in six documents at once and disagreement is worse than staleness.

---

## Done

- [x] **A one-key dev room, and a real bug in the panel that made it.**
      *(Aug 2026 -- user request: "make me a dev room with max coins,
      itms, stuudents, sstats, etc.")* The F1 dev panel already had
      individual cheats for all of this (coins, teacher, students,
      furniture, enrolling, growing the room) -- what was missing was one
      key to fire all of them in the right order. Found a real bug while
      wiring it: the "grow" cheat was listed in `CHEATS` with a label but
      had no case in `_do_cheat()`'s match, so pressing E on it silently
      did nothing but mark the run cheated. Refactored each cheat into
      its own function so "EVERYTHING (dev room)" can call them in an
      order that actually works -- coins BEFORE grow (growing costs
      money), grow BEFORE enrol/furnish (both need the extra floor).
      Screenshotted both the panel (`dev_room`) and the room it produces
      (`dev_room_bare`) to confirm coins, room size, roster and furniture
      all actually changed, not just the message line. Regression-tested
      directly against the debug panel's own `_do_cheat`, including the
      previously-silent `grow` case.
- [x] **An auto-play system: watch a delegated room play out.**
      *(Aug 2026 -- user request, "an auto play system for the game as
      well".)* Conflicts directly with "legwork, not judgement" if read
      as automating the PLAYER's own room, so asked first rather than
      guessing -- the user picked "watch a delegated room play out",
      which turns automation the game already considers legitimate (a
      hired NPC teacher's fixed archetype policy) from an invisible
      number into something you can actually watch happen.
      `RoomSim.play_day()` already RUNS the real lesson model for a
      delegated room once a day (`Game.resolve_rooms()`, called at the
      bell) -- it was never a formula, so nothing needed to be re-derived
      for honesty, only recorded. Added a `history` array to its
      existing tick loop: one frame a second (roster + who is at the
      front), appended into the SAME dict `resolve_rooms()` already
      stores as `room["last"]`, so playback is the identical roll that
      produced the letter, not a fresh, possibly-different one.
      New `V` key (global, not landmark-bound -- `Mode.WATCH`, #15) from
      the School screen, only offered once a room is staffed AND has a
      day behind it (`_can_watch()`). Steps through its own frames on
      the idle clock at a speed a person can watch, ends on the actual
      grade letter, `V` again skips straight to the bell, Esc backs out.
      Regression-tested (frames recorded, screen reachable/gated
      correctly, last frame's letter matches `resolve_rooms()`'s own,
      panel fits) and screenshotted mid-lesson. Balance contract
      re-verified after touching `room_sim.gd`'s tick loop -- all three
      rows still hold, `Simulate the School.bat` still shows archetypes
      producing genuinely different, sensible results.
- [x] **A dashboard, and what "two buttons is not enough" actually meant.**
      *(Aug 2026 -- user request.)* Checked the actual rule in CLAUDE.md
      before touching it: E/F were never "two buttons total", they are
      "no LANDMARK ever offers more than two" -- the game already had
      Tab/B/Q/P as dedicated global keys, unrelated to any landmark,
      before that rule was written down. A dashboard is not about
      anywhere you are standing, so it got the same treatment: a new
      global key (`I`), Mode.DASHBOARD as #14, E/F untouched.
      Three pages, cycled with the shop's own tab-cycling pattern:
      OVERVIEW (level, speciality, class size, room, coins, portrait, and
      two deliberately-empty Hat/Background lines -- the cosmetic slots
      were asked for and explicitly deferred, same pattern as the hand-
      size luck skill), ITEMS (what is owned, by category, reusing
      `cat_colour`/`_worth_bar` from the shop rather than re-inventing
      them), SKILLS (a read-only mirror of the staff room's perk bars --
      spending stays the staff room's job).
      Found a real, silent clipping bug while screenshotting it: the body
      panel does not scroll (`scroll_active = false`), and the true
      visual capacity at font 8 / line-separation 2 is BELOW what the
      `<= 11` logical-line-count assertion catches, since that assertion
      only counts `
` and cannot see a wrapped or simply-too-tall block
      clip silently. The Overview page's Background line was cut off on
      screen while its own line-count assertion still reported it fit.
      Trimmed for real margin rather than exactly at the arithmetic edge.
      CLAUDE.md's constraint itself reworded from "Two buttons" to "Two
      buttons per landmark" to say the true rule out loud, since the old
      wording was ambiguous enough to prompt this very question.
- [x] **The homework screen went silent, for real players, permanently,
      after the first room rebuild.** *(Aug 2026 -- real bug, user-
      reported: "we broke the homework page as now it shows nothing".)*
      Root cause: `RoomBuilder.add_prop()` puts the "room_part" group on
      the PROP (a StaticBody2D), not on the Interactable, which is a
      CHILD of that prop. `rebuild_room()` calls `queue_free()` on the
      prop; the child's own `is_queued_for_deletion()` stays false right
      up until the deferred free actually runs, even though
      `remove_child()` already took it out of the tree. `Game.new_run()`
      rebuilds the room every time, and the crash happened INSIDE
      `_pick_target()`, which aborts `_physics_process()` before `targets`
      ever refreshes -- so the marking desk went untargetable for the rest
      of the run, silently, no error a player would ever see, just a
      button that stopped doing anything.
      Fixed at both the caller (`player.gd`'s `_pick_target()`/`_live()`
      now check `is_inside_tree()`, the actual general check, not
      `is_queued_for_deletion()`) and the source (`marking_desk.gd`'s own
      `_carrier()` no longer calls `get_tree()` on a detached node). A
      dedicated regression test forces the exact rebuild path and polls
      immediately, no `await`, to hit the narrow window. Verified live:
      screenshotted the marking screen straight after a fresh
      `new_run()` and confirmed it renders real content.
      **Only `marking_desk.gd` called `get_tree()` directly** among all
      the Interactable subclasses -- checked, so this was not a wider
      pattern needing a sweep.
      **Found, not fixed, out of scope for this pass:**
      `Placement._refresh()` throws `Cannot call method 'get_height' on a
      null value` -- a null `_ghost.texture`, unrelated to the
      tree-detachment class of bug above. Confined to a manual `.tile` +
      `._refresh()` poke in `test_build_mode` rather than the normal
      `begin()` flow, so lower urgency; still needs a real fix.
- [x] **Grading felt too hard, and the hand of cards is now a real
      shuffle of 3-7.** *(Aug 2026.)* Grade LETTER bands (not the pillar
      itself) moved from hardcoded A .88/B .75/C .62/D .50/E .38 in
      `game.gd` to `data/balance.json`'s `grade_bands`, softened to
      A .85/B .73/C .55/D .42/E .30 -- the pillar's own bare-room-perfect
      row (0.63) sat one point above the old C floor, so realistic,
      imperfect-but-decent play landed in D. Contract re-verified
      unmoved: 0.63/0.71/0.97 still land C/C/A, now with real margin.
      `assignments.hand_size` (fixed at 3) became `hand_size_min`/`_max`
      (3-7), rolled fresh every draw via `Assignments.draw()`, with a
      test proving the size actually VARIES across draws rather than
      landing on the same number by seed coincidence. Added a shuffle
      flourish in `hud.gd` -- a brief riffling pip-row with a paper sound
      per frame -- that plays once on a freshly drawn hand and never on a
      page turn. Found and fixed a stale test that could only ever have
      passed by coincidence of a fixed 3-card hand: it checked that every
      card's title appeared on a single page, when the UI only ever shows
      one card at a time.
      **Left for later, on purpose:** a teacher LUCK skill (more, and
      eventually better, cards for a teacher who has earned it) was asked
      for but explicitly deferred. `hand_size_min`/`_max` in
      `data/balance.json` is the intended hook -- when that lands, it
      should read these rather than hardcoding a count anywhere.
- [x] **Integrate task 1 — 20 lessons.** Curriculum 20 → 40, concepts
      60 → 120. 15 verified codes, 5 honestly uncited. Added five
      assertions including the `short`-length check that nothing had ever
      enforced. Suite 1033 → 1038. *(Aug 2026)*
- [x] **Port the `/deep` commands and make doc drift fail loudly.**
      `tools/check_docs.py`, 271 checks. *(Aug 2026)*
