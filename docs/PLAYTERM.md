# Play a Whole Term — measured results log

[`tools/playterm.gd`](../tools/playterm.gd) plays a whole term through the real
buttons and prints three answers: **liveness** (every day reaches the bell and the
exam fires — gated), **carry-on** (a second term begins — reported), and
**competence** (the class meets the term's target — reported, not gated, see
`GATE_COMPETENCE`). This file records the measured competence gap, dated, so the
number is not lost between runs. Newest first.

Run it from the project root:

```
godot --headless --path . res://tools/playterm.tscn
```

---

## 2026-11-01 — first competence measurement with homework marking on

**Run:** seed 777, `SPEED` 6.0, one term (20 days). Output read from the run itself.

**Result**

| | Measured | Target / bar |
|---|---|---|
| Exam (term 1) | F, **0 of 4 passed** | **2 passing** (`Game.term_target()` at term 1) |
| Concepts | 15 of 120 | — |
| Graduated | 0 | — |
| Average grade on sampled days | F on days 4, 9, 14, 19, 20 (class of 4) | — |

Sampled lesson tallies (front-of-room %, trips, children helped): day 4 66% / 3 / 3,
day 9 56% / 1 / 0, day 14 44% / 2 / 0, day 19 77% / 2 / 2, day 20 47% / 1 / 0.

**Verdict lines as printed**

- `liveness    : ok - the bell every day, and the exam fired`
- `carry-on    : no second term began` — missed; the run ended on the missed target
- `competence  : the class missed its target of 2` — missed
- `WALKTHROUGH PASSED - 1 term(s) played, every day reached the bell.`

**Steps missed:** the term's target (0 passed against 2 needed), so the run ended
and no second term began. Liveness held on every day.

**Homework-marking change already made:** `_mark_homework()` in
[`tools/playterm.gd`](../tools/playterm.gd) (added 2026-09-14). After each lesson the
bot walks to the teacher's desk, marks what it carries, and judges each sheet with
`Questions.sheet_is_good()`. This closes the "never marks" gap but not the target
gap: the class still misses the bar. `GATE_COMPETENCE` stays `false`.

**Caveat on this run:** Godot could not write `user://` inside the sandbox, so
`save_game` and the log file both failed (`could not open the save file for
writing`). The run continued in memory, so the printed numbers stand, but the save
path was not exercised. Re-run outside the sandbox before quoting this as a saved-game
result.
