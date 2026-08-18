# The standing task menu

What `/deep_grind` picks from, and what `/loop /deep_grind` works through
while you are away. **Every task here is small, verifiable, and additive.**

## How to use this list

Pick the highest-value task that is **not done** and whose dependencies
are met. Do one full cycle: implement, verify, screenshot if visual,
commit with a message that says *why*, tick it off here.

**One task per cycle.** A cycle that touches three things cannot be
bisected when it breaks.

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

- [ ] **A1. Integrate task 2 — 21 items of furniture.** Validate with
      `python tools/check_items.py <file.json>` before touching
      `balance.json`. Reject rather than patch: an item outside the
      360–840 density window, a near-duplicate of the existing 29, a
      blurb that reads like a catalogue, or a concept link that does not
      make sense. Then art, then a screenshot of the shop.
- [ ] **A2. Integrate task 3 — 6 student traits.** The bar is in
      `docs/SALVAGE.md`: if the trait can be expressed as one multiplier
      on that child, it has failed. Each needs a real hook into the work
      model or the seating, and an assertion proving the hook fires.
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
- [ ] **B4. Onboarding.** Still the biggest gap between what the game is
      and what a player can reach. Nothing tells a new player that
      leaving the podium stops the work, which makes the first lesson
      read as broken rather than as the central mechanic. Smallest useful
      version first — one line at the right moment beats a tutorial.

## C. Verification debt

- [ ] **C1. Sweep for more assertions that test a count instead of a
      claim.** `every lesson is still teachable whatever you trained in`
      asserted `lessons.size() == 20` and broke when content landed —
      it tested the size of the curriculum, not the claim in its own
      comment. Find the others: grep the suite for `== <literal>` against
      a collection size and judge each one.
- [ ] **C2. Panel fit-test the screens that grew.** The curriculum screen
      now lists 40 lessons and the shop will list 50 items. Screenshot
      every mode and check nothing clips; labels clip in silence.
- [ ] **C3. Assert the art contract.** Every item's `art` string resolves
      to a PNG that actually *loads* (currently 71 on disk, 0 missing —
      keep it that way as items are added). Loading, not existing:
      `art/inspector.png` once existed and could not be loaded because
      nothing had imported it.

## D. Housekeeping

- [ ] **D1. `.godot/` and OneDrive.** The repo now lives inside OneDrive.
      `.godot/` is a rebuildable cache; syncing it invites conflicts.
      Add it to `.gitignore` and exclude it from sync.
- [ ] **D2. Run `/deep_update` after any batch integration.** Counts move
      in six documents at once and disagreement is worse than staleness.

---

## Done

- [x] **Integrate task 1 — 20 lessons.** Curriculum 20 → 40, concepts
      60 → 120. 15 verified codes, 5 honestly uncited. Added five
      assertions including the `short`-length check that nothing had ever
      enforced. Suite 1033 → 1038. *(Aug 2026)*
- [x] **Port the `/deep` commands and make doc drift fail loudly.**
      `tools/check_docs.py`, 271 checks. *(Aug 2026)*
