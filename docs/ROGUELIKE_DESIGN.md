# The roguelike pivot — design doc

*(Supersedes the raw idea captured in the business vault at
`my-brain/projects/pixelroom/roguelike-idea.md` — that file was a
placeholder for exactly this. Real design decisions belong here, in
PixelRoom's own repo, not the business vault.)*

## The load-bearing decision: a run IS a term

`Balance.term_days` is already **20** — the existing term length. A
"run," as scoped directly by the user, is 20 days of lessons ending
with the students getting a grade based on scores accumulated across
the run. **That is exactly what a term already is.** This is the
reason the balance contract is *not* at risk: nothing about
`grade_letter()`, `class_average()`, `room_score()`, or the exam
changes. The roguelike layer sits *around* the existing term loop, not
inside its math.

- **Run start**: the room begins empty/bare — no carried-over
  furniture from the previous run. This is the actual roguelike trait:
  every run starts from a genuine blank slate, and the interesting
  decision is what you buy and how you place it *this* time, not
  accumulated wealth trivializing early runs.
- **Run end**: the term's existing exam/final grade *is* the run's
  ending. No new grading system — reuse what's there.
- **Victory condition**: passing the term at a real bar (the existing
  grade-letter thresholds already define this) unlocks NG+.

## The anti-clustering fix (base game, not roguelike-only)

The originally-reported problem: the discovered meta is cramming every
desk together in the middle of the room. Fix: **seats placed adjacent
to another occupied seat apply a progress-speed penalty** to both
students, tunable in `data/balance.json` (new key under `room`, e.g.
`cluster_penalty`) — not hardcoded, per the project's own hard
constraint. This ships as a base-game balance change independent of
the roguelike work, since it's a real problem today regardless of
whether the roguelike pivot lands.

## The skill list (run-scoped progression)

Nine skills, spanning the systems that already exist. Each is a
`Balance.json`-tunable modifier applied to an existing mechanic — no
new subsystem invented per skill, which is what keeps this
implementable rather than aspirational.

| Skill | What it does | Hooks into |
|---|---|---|
| **Longer Stride** | Extends dash distance/duration | `Actor`'s existing dash-cancel mechanic |
| **Quick Study** | Lesson clock briefly slows on activation — more real time per action | The lesson timer |
| **Warm Presence** | Students near the player recover attention/confusion faster | The existing proximity-based help mechanic |
| **Steady Hands** | Mess spawns less often / cleans faster | `Balance.mess_clean_presses`, mess spawn rate |
| **Carrying Voice** | The settle (C) radius extends further | `raise_voice()`'s range |
| **Quick Hands** | Reduced hold-time on mashable verbs, or +1 carry capacity | `Interactable.hold_time`, `carrying`/`carrying_hw` caps |
| **Lucky Break** | Better odds on the drawn assignment hand's rarity | `Game.draw_hand()` |
| **Thrifty** | Shop discount, a percentage off `Items.cost()` | The shop's cost lookup |
| **Iron Will** | Disruption spreads to fewer neighboring desks | The "messing about" spread mechanic |

Picked at set points across the run (e.g., after each week, or on a
milestone day) — exact cadence is an implementation decision, not
locked here.

## NG+ (per the user's direct spec)

- **More students.** Class size scales up per NG+ level
  (`Balance.school_class_size`-style scaling, applied to the player's
  own room too).
- **Reversed spatial rule.** Where the base game penalizes clustering,
  NG+ requires the *opposite* — students placed too close together is
  even more punishing, or a minimum-spacing rule is enforced outright.
  This is a real escalation of the anti-clustering fix above, not a
  separate mechanic.
- **Difficulty has to scale sensibly.** Each NG+ level should feel like
  a deliberate step up, not a cliff — same discipline the base game
  already applies to its difficulty curve (day events, disruption
  odds), tuned via `balance.json` per level rather than a hardcoded
  multiplier.
- **Scaling rewards.** A meta-currency or skill-purchase power that
  carries between runs and grows with runs completed, so repeat runs
  feel progressively *easier* to clear even as the base difficulty
  rises — classic roguelike shape: the run resets, the player's
  long-term power doesn't.

## What's still an open implementation decision
- Exact skill-pick cadence (weekly? milestone days?).
- The exact NG+ difficulty curve numbers (all tunables, none hardcoded
  — see `data/balance.json` conventions).
- Whether the meta-currency is coins carried forward, a new resource,
  or unlocked skill slots.
- UI: where a skill pick happens, how NG+ is offered post-victory.

## Verification this needs before it ships
Same discipline as every other feature in this project:
`Simulate a Term.bat` must still show 0.63/0.71/0.97 unmoved (nothing
here touches the grade formula, only what's fed into it), a new
`tests/run.gd` section for the skill/NG+ systems, and `Trace a Day.bat`
run against a fresh run to confirm the empty-room-start doesn't
deadlock anything the way the storyline intro once did.
