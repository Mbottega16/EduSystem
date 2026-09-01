# The roguelike pivot — design doc

*(Supersedes the raw idea captured in the business vault at
`my-brain/projects/pixelroom/roguelike-idea.md` — that file was a
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
