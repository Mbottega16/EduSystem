---
description: Sweep every PixelRoom doc and rewrite stale facts against live repo state — counts, schema examples, file map, the balance contract
---

Refresh every reference document against what the repository actually
contains right now. **Read the live data; never carry a number forward
from a previous pass or from memory.**

Docs in scope: `CLAUDE.md`, `README.md`, `docs/BRIEFING.md`,
`docs/TASK_PACK.md`, `docs/GDD.md`, `docs/SALVAGE.md`.

## 1. Run the mechanical half first

```
python tools/check_docs.py
```

It verifies the things that have actually gone wrong here: that every
worked example in `BRIEFING.md` and `TASK_PACK.md` is the *real* row from
`data/balance.json`, that the quoted item table matches, that every lesson
id and standard code appears in BRIEFING's do-not-collide inventory, that
the value-density window the prompt asserts is true of all 29 items, and
that every doc agrees on the assertion count.

Fix everything it reports before going further. Anything it *cannot*
check is what the rest of this command is for.

## 2. Re-derive the counts

Run these and take their own output as truth:

```
Run Tests.bat            assertion count and section count
Simulate a Term.bat      the three contract rows
```

Then re-count from the data itself — lessons and concepts in
`data/curriculum.json`; items, traits and sections in `data/balance.json`;
events, staff, milestones, questions and names in `scripts/data/`; art in
`art/`; audio in `audio/`.

**Read the assertion COUNT, not the word PASSED.** A broken script prints
PASSED with a silently lower count.

## 3. The traps this command exists for

- **A worked example is an input, not prose.** `BRIEFING.md` once showed
  the microscope at `bonus 0.05` when the real value is `0.13`. It was
  attached to an outside model, which anchored on it and returned 22 items
  at half strength. Valid JSON, real field names, wrong values.
- **A list inside a finished task's prompt rots the moment that task is
  archived.** That is why the do-not-collide inventory lives in
  `BRIEFING.md`, which is attached to every task.
- **The contract rows drift within a band.** If a row moved but kept its
  letter, update the number and say so; if it changed band, stop and flag
  it — that is a balance regression, not a doc problem.
- **Counts that appear in several docs must agree.** Disagreement is worse
  than staleness, because it makes both untrustworthy.

## 4. Finish

Re-run `python tools/check_docs.py` and `Run Tests.bat`. Commit with a
message that says which facts moved and why, not just "update docs".

Report: what was stale, what you changed it to, and anything you found
that is a real problem rather than a stale number.

$ARGUMENTS
