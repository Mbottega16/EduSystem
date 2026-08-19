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
