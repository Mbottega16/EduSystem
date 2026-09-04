# The roguelike pivot — design doc

*(Supersedes the raw idea captured in the business vault at
`my-brain/projects/edusystem/roguelike-idea.md` — that file was a
placeholder for exactly this. Real design decisions belong here, in
EDUSystem's own repo, not the business vault.)*

*(Revised: the first version of this doc got its own load-bearing
premise wrong — see below. Corrected against the real code rather than
assumed, the same discipline this whole project is built on.)*

## The load-bearing correction: a run is NOT a term

The first version of this doc said "a run IS a term" and built
everything on that. That was wrong the moment it was written: a commit
that predates it, `5a36ae3` ("A term is a chapter now, not the end of
the book"), had already changed what a run means in code.

**What's actually true**: `Game.term: int` tracks which chapter you're
on; `Game.next_term()` (`scripts/autoload/game.gd:980-1065`) carries
the **room, furniture, coins, teacher level/perks, and curriculum**
forward between terms — only the class roster resets, per
`_next_term_note` in `data/balance.json`'s `"term"` section (already
accurate, wasn't touched by the mistake above). A run only ends
(`Game.run_over = true`) when a term's target is **missed** —
`term_target()` is a bar that rises every term
(`target_base + target_growth * (term - 1)`), the one thing in the game
you can actually lose to. `Game.new_run()` is the real full reset, only
reached from the run-over screen.

That's already most of a roguelike shape: a persistent build across
repeated cycles, an escalating difficulty bar, and a real failure state
that resets everything. The work below builds *on* that, not instead
of it.

- **Run start**: `Game.new_run()` — already resets the room/coins/perks
  to nothing. No change needed here; this was never actually broken.
- **Term start** (not run start) is the real recurring decision point —
  see "Term paths" below.
- **Run end**: missing a term's target, exactly as it already works.
  No new grading system.

## The anti-clustering fix (base game, not roguelike-only) — shipped

The originally-reported problem: the discovered meta is cramming every
desk together in the middle of the room. The fix: a child with another
**occupied desk orthogonally adjacent** works `room.cluster_penalty`
(0.12) slower — `Game.cluster_rate_mult()`, applied per student in
`classroom._physics_process()` on top of the class-wide work rate.
Spreading the desks back out is the whole counter-play, and the opening
layout already has no two seats within a tile of each other, so it costs
nothing until a player chooses to bunch them.

Layout only — it never touches a grade formula, and the contract sim
(`tools/sim.gd::_one_lesson()`) seats every child at 0 and calls
`tick_work()` directly rather than through the room, so it never sees
this. `test_balance()`'s source scan asserts `_one_lesson()` never calls
`cluster_rate_mult()`, the same guard the complication ticks got.

Genuinely adjacent, and left as-is: `neighbour_stall_multiplier()`
(`scripts/data/student_data.gd`) already raises stall chance from an
*actively disrupting* neighbour, and a `helps_neighbour` trait is a
*positive* reason to cluster — the two pulls now sit either side of the
new penalty rather than all pointing one way.

## Mid-lesson complications — shipped

A per-second onset roll while a lesson is running, generalizing the
existing flare-up mechanic rather than extending `DayEvent` (which is
deliberately once-per-day, never mid-lesson). See
`scripts/data/complications.gd` for the weighted table (mess, a phone
call, a parent conference to start — a future complication is a new
table row, not a new script, as long as it reuses an existing
`landmark` type) and `data/balance.json`'s `"complication"` section for
the tunable onset rate and per-lesson cap.

Mess can now pop up mid-lesson, not just at day boundaries, cleaned
through the same existing verb. A phone call or parent conference lands
at the teacher's desk on a new dedicated key, `RESPOND` (bound to `K`)
— answering costs real lesson seconds and pays coins; letting it ring
out has its own cost (one student flipped disrupting, or a reputation
nudge). Neither reveals a new screen — both resolve instantly in the
world, the same way settling the room already does.

## Someone at your desk — shipped (2026-09-04)

The complication table's own promise ("a future complication is a new
table row, not a new script") paid off: the people who now interrupt you
are six new rows, one new screen, and no new key.

A `"desk"` row may carry a `speaker`, a `line` and a list of `choices`.
Answering it opens the smallest screen in the game — a face, one
sentence from them, two or three ways to answer — and after you pick,
one sentence back. A row *without* `choices` still resolves instantly,
which is why the phone call and the parent conference are untouched.

**The cast.** The principal (the trip fund, covering a lesson, a spare
from the storeroom) and the children themselves (a child who is lost, a
child who has finished, a child who has lost something). A child speaker
resolves to a real seated child, picked off `Game.rng` when the row
spawns, so a seed replays the same child asking the same thing — and the
screen shows their own portrait and their own name.

**It is a decision, not a menu.** Every branch that pays has a sibling
that costs: coins out of your own purse, standing with the principal, or
a child set off because you turned them away. Ignoring it is already a
branch — it resolves through `ignored_effect` when the ring runs out.
The lesson clock does *not* stop while the screen is open, so dithering
is its own small price.

**Why none of this moves the balance contract.** The effects vocabulary
(`Complication.EFFECTS`) is deliberately narrow and **nothing in it
touches a child's record**:

- `coins` buy items, and items are already clamped by `room_cap` — the
  contract's "full room" row is that ceiling already.
- `item` drops a copy in the *cabinet*, exactly where buying puts it, so
  placing it stays the player's call.
- `boost` is a stretch of quicker feet — teacher pace and nothing else.
  Both teaching rows of the contract assume either a perfect teacher or
  no teacher at all, and a faster walk moves neither. It never stacks
  (a second win refreshes the timer) and the bell ends it.
- `reputation` and `disrupt_one` already existed as outcomes.

A source-scan guard asserts `tools/sim.gd` never reaches
`resolve_caller_choice()` or `start_boost()`, the same way the boss
fight and the mass-help are guarded, so the measured rows cannot drift.

**Prose, never numbers, in both directions.** A choice never prints its
price — "Give what you can", not "-40 coins" — and you feel it at the
purse afterwards. Asserted, not just intended.

## Term paths — shipped, the PokeRogue-style fork

Modeled directly on the assignment-hand system (draw several pre-rolled
options, pick one, discard the rest) rather than inventing a new UI
shape. At the start of each new term, `scripts/data/term_paths.gd`
draws a small hand of paths — Quiet, Ordinary, Busy, Chaotic to start —
each carrying a `lesson_mult`/`coin_mult`/`density_mult`. `Ordinary`
sits at `1.0` across the board on purpose, so a player who always picks
it sees exactly today's numbers; picking Busy or Chaotic means longer
lessons, more complications, and better pay, for as long as that term
lasts. This is the actual "choose a harder or easier path" autonomy —
scoped to term starts, since that's the real recurring decision point
in the corrected run model above, not an artificial one invented to
match the original (wrong) single-term premise.

## The skill list → the existing perk board

The original nine-skill list was written without accounting for the
fact that EDUSystem already has a working, run-scoped, ranked perk
system (`Game.perk_ranks`, `scripts/data/progress.gd`, the Staff Room
screen in `hud.gd`). Building a second, parallel skill system alongside
it would fork progression into two competing UIs for nothing — every
skill below is a rank on that *existing* board, not a new subsystem.

| Skill | Resolution | Perk id | Status |
|---|---|---|---|
| Longer Stride | dash reach | `brisk_walk` | already existed |
| Warm Presence | stall reduction near teacher | `calm_presence` | already existed |
| Quick Hands | +carry capacity | `steady_hands` | already existed |
| Steady Hands *(renamed — collided with the existing `steady_hands` id above)* | mess needs fewer presses to clean | `quick_sweep` | shipped |
| Carrying Voice | settle radius | `carrying_voice` | shipped |
| Quick Study *(passive, not activated — confirmed directly: the key budget was already tight, and a permanent percentage gets the same payoff with no new input to track mid-lesson)* | small permanent % more real seconds per lesson | `quick_study` | shipped |
| Lucky Break | better assignment-hand rarity odds | `lucky_break` | shipped |
| Thrifty | shop discount (buy price only, not sell) | `thrifty` | shipped |
| Iron Will | disruption *spread* reduced (not boredom/frustration onset) | `iron_will` | shipped |

## The boss term — shipped (the card, the bar, the trophy)

Every `boss_term_interval`-th term (3), `Game.draw_term_paths()` folds
the five boss cards from `balance.json`'s `bosses.table` into the same
fork the Quiet/Ordinary/Busy/Chaotic cards are drawn from -- one per
strand (Reading Paper, Number Gauntlet, Science Fair, Mock Election)
plus the mixed Open Evening. A boss term plays like an ordinary one
until the exam: `Game.next_term()`'s boss branch judges the class
AVERAGE that `sit_exam()` already produced against the card's own
`target` bar instead of the seat-count target. Clear it and the
matching trophy lands on the career screen (`scripts/data/trophies.gd`)
and the cosmetic decor gated on any trophy goes on sale; miss it and the
run is over, exactly as a missed ordinary target ends it.

This is the one deliberate exception to `docs/SALVAGE.md`'s "no ELO /
no boss manager" guidance, documented the same way `Game.auto_teach` is
an exception in CLAUDE.md.

## The fight — shipped (2026-09-03): the last day of a boss term is PLAYED

`scripts/data/boss_fight.gd`. The last morning of a boss term the
podium does not deal a hand; it reads **"Begin the Reading Paper"**.
Press it and the paper is sat in the room, in real time, with the
examiner standing at the front:

- **Rounds.** The card's own `moves` list is the paper's attack pattern,
  one move per round (`bosses.fight.round_seconds` each, with a short
  `breath_seconds` between, the question across the top of the screen as
  each opens). Four kinds of move:
  - `freeze` -- `freeze_count` children freeze on the question (weighted
    toward the ones who find the work hardest, drawn off `Game.rng`);
    their desk's E reads *Steady Nora*.
  - `chain` -- one child freezes and, every `chain_spread_seconds`, the
    freeze spreads to an adjacent occupied desk (through the same
    `Game.neighbours_of()` the seating plan already uses). Spreading the
    desks out is the counter, same as the cluster penalty.
  - `noise` -- `noise_count` children start arguing (`disrupting`);
    settle them at the desk or with your voice.
  - `present` -- one child is put up front (a gold bubble); the teacher
    has to STAND WITH them, within `present_radius_tiles`, for
    `present_seconds` of the round (`present_rally_seconds` to rally),
    while the audience gets restless at `restless_per_second`.
- **Marks.** Each child a round touches ends it *rallied* (dealt with
  inside `quick_seconds`), *held* (dealt with in time), or *dropped*
  (still frozen / still shouting / left alone up front when the question
  moved on). J -- answer all -- talks everyone through it at once, but
  they count as held, never rallied: a panic button, never the best play.
- **The nudge.** `BossFight.finish()` turns the tally into
  `StudentData.boss_delta = rally_mark * rallied - drop_mark * dropped`,
  clamped to `+-max_swing` (about half a letter band), which
  `Game.exam_score_for()` adds on top of the child's own record at the
  bell. The record still decides the exam; the day decides the margin.
  `next_term()`'s boss branch is untouched -- it still reads the one
  `sit_exam()` average against the bar.
- **What the player sees.** The strip drops the day counter for
  `Q3/6  41s  hold ||||. steady  voice |||.` -- composure is pips and
  a word banded by `composure_*`, never a number. A floater over each
  desk as it resolves (*rose to it!* / *held* / *lost it*). A report
  when it is over (one line per child, the room in a sentence), then the
  bell sits the exam, whose screen is titled with the paper's name and
  says CLEARED / NOT cleared instead of the seat count. The mentor's
  readiness read gains the card's `tactic` line. A child who rose to it
  twice, or froze twice, gets a moment on their story page.
- **What it is not.** No work is set, nothing is graded that day, the
  unit test is not offered that morning, and the contract sim
  (`tools/sim.gd`) never touches any of it -- `test_boss_fight()` scans
  for that, and for bare `randi()/randf()` in the fight.

Dev: the tuning panel's CHEATS page has *Boss paper now (Reading
Paper)*; `Take a Screenshot.bat boss_fight` / `fight_report` capture it.

## NG+ — still not built

- **More students.** Class size scales up per NG+ level, applied to the
  player's own room too.
- **Reversed spatial rule.** Where the base game penalizes clustering
  (once the fix above lands), NG+ requires the opposite — tighter
  spacing becomes more punishing, or a minimum-spacing rule is
  enforced outright. An escalation of the anti-clustering fix, not a
  separate mechanic.
- **Difficulty has to scale sensibly.** Each level a deliberate step,
  not a cliff — tunable in `balance.json` per level, no hardcoded
  multiplier.
- **Scaling rewards.** A meta-currency or skill-purchase power that
  carries between full runs (not terms) and grows with runs completed.

None of this is built yet. It's a real extension of the run-ends-on-
missed-target model above (an NG+ "run" would presumably start the
target bar higher, or scale faster) but needs its own pass once the
base run-over screen and a first real playthrough exist to tune
against.

## What's still an open implementation decision
- NG+'s exact numbers and trigger (Section above).
- The anti-clustering fix's exact penalty curve.
- Whether NG+'s meta-currency is coins carried forward, a new resource,
  or unlocked perk ranks that survive a run-over.

## Verification
Same discipline as every other feature in this project:
`Simulate a Term.bat` must still show 0.63/0.71/0.97 unmoved — nothing
shipped here touches the grade formula, only levers the contract
already ignores (flat coins, the `disrupting` flag). `Run Tests.bat`'s
count must strictly rise with each addition, never just stay green.
See `tests/run.gd` for the sections this shipped with:
`test_mid_lesson_mess`, `test_desk_interruption`, `test_term_paths`,
`test_new_perks`.
