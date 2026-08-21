# PixelRoom — Game Design Document

> **Measured on 2026-08-19**, against build `b31`, with **1189 assertions
> passing**. Every number in this document is quoted from `data/balance.json`
> or from a tool's own output, with the source named. Anything not yet built
> is marked ***(to build)*** — if it is not marked, it exists and you can go
> and look at it.

---

## 1. What this is

**You are a teacher. Walking the room is the game.**

A pixel-art management sim about a classroom you can actually feel: children
who get stuck and stop dead until you reach them, work that only advances
while you are at the front teaching it, and a room you furnish because
furniture genuinely helps the child sitting next to it. Terms end in an exam
with a target you can miss. Miss enough and the school closes.

You can spend your whole career inside one classroom, or hire staff, open
rooms and run the place from a desk — and both are a real way to play,
because a room you delegate is simulated by the same model you would have
played it with.

**The pitch.** *Football Manager for a primary school, played from the
inside.*

**Store blurb** *(draft)*
> Teach a class of eight, one child at a time. They get stuck, they mess
> about, they copy off each other, and their work stops the moment you stop
> teaching. Furnish the room, set the papers, mark the homework, and get
> them through the exam. Then do it again with a class you have never met —
> because the ones you taught best are the ones who leave. Hire staff, open
> rooms, and become the head you never wanted to be. Or don't, and stay in
> the room.

---

## 2. Pillars

These are not aspirations. Every one is a rule already written into the
code, and most are enforced by a test. They are the reason the game is
coherent, and the thing to check any new feature against.

### The balance contract
> *"The room sets the floor, the teacher sets the ceiling."*

| | measured |
|---|---|
| bare room, perfect teaching | **0.63 → C** |
| full room, never helped | **0.71 → C** |
| full room, perfect teaching | **0.97 → A** |

Neither input alone reaches the top band. Measured from **simulated play**
by `tools/sim.gd`, asserted by `tests/run.gd`. It is written down in
`data/balance.json._contract`, which also records why:

> *"The previous version asserted hand-set state, which is how a grade model
> broken in four places passed 218 tests."*

**Nothing may quietly move this pillar.** It is why the quiz pays no grade,
and why assignment rarity pays coins and XP but never grade — a multiplier
on the lesson term would move the pillar *by luck rather than by play*.

### The grade LETTER bands are separate from the pillar, and were softened

**Decided August 2026.** The three numbers above (0.63 / 0.71 / 0.97) are
the pillar and did not move — the room/lesson/homework formula in
`grade_for()` is untouched. What moved is `data/balance.json`'s
`grade_bands`: where a numeric grade lands as a letter, which used to be
hardcoded in `game.gd` as A .88 / B .75 / C .62 / D .50 / E .38.

The problem: the pillar's own bare-room-perfect-teaching row (0.63) sat a
single point above the old C floor of 0.62. Realistic play — decent, not
flawless — routinely landed a shade below that, in D, which is what "grading
feels too hard" actually was: not the pillar, the margin around it.

Softened to A .85 / B .73 / C .55 / D .42 / E .30. The pillar's three rows
still land C / C / A — `full room, never helped` (0.71) now has real
margin below B (0.73) instead of `0.71 < 0.75` on the old scale, and
`bare room, perfect teaching` (0.63) has real margin above C (0.55)
instead of one point. `tests/run.gd` asserts the boundary logic against
`Balance.grade_band_*` rather than pinned literals, so a future retune
cannot silently break it the way a hardcoded probe would.

### Walking the room is the game
Every verb lives on a landmark you walk to. `scripts/interact/noticeboard.gd`:

> *"An in-world object you walk to rather than a hotkey menu... a menu you
> can open from anywhere would quietly undermine 'walking is the game'."*

Every departure from this is deliberately limited so the rule survives:
**voice** (Q) is the only non-landmark verb and it only reaches desks within
earshot; **autopilot** (R) moves your feet and never presses your buttons;
the **aide** collects and nothing else.

### Legwork, not judgement
The rule that governs every piece of automation, present and future.
`scripts/autoload/game.gd`:

> *"They never help, settle or mark — collecting is legwork and helping is a
> judgement, and hiring out the judgement would be hiring somebody to play
> the game for you."*

**This is the rule that will govern the entire school layer.** Delegating a
room is allowed. Delegating the decision of what to do about one child, in
the room you are standing in, is not.

### Prose, not numbers
The player is never shown a decimal. `scripts/ui/hud.gd`:

> *"'the room is doing its job' is a thing you can act on, 0.62 is not."*

Enforced by `tests/run.gd`: *"THE DESIGN RULE, enforced rather than trusted:
prose, never numbers."* Quantities are bars, not figures.

### Results animate, lists do not
`scripts/ui/fx.gd`: *"learned the hard way when the shop animated: results
animate, lists do not. Anything the player is steering must not move under
them."*

### Never offer nothing at a landmark
From the bug that made the game unplayable — the podium offered nothing for
the ten seconds the class took to sit down:

> *"A player walks up, sees nothing, and concludes the game is broken. They
> were right to."*

### Determinism
One seeded `RandomNumberGenerator` on `Game.rng`. Global `randi()`/`randf()`
are banned project-wide. Without it, none of the balance testing could exist.

### Numbers do not live in code
`data/balance.json` is the single table — **32 sections**, 122 tunables
(counting numbers directly in a section, not the item and trait tables).
Nothing tunable is a `const` in a `.gd` file.

### A dev tool must never destroy the thing it tests
The suite and simulator once overwrote the player's real save. `Game.save_path`
is a var for exactly this reason.

---

## 3. The fantasy, and the two altitudes

The one genuinely new design problem, and the thing this document exists to
settle.

**You choose your altitude, and the game does not have a preferred one.**

| | |
|---|---|
| **In the room** | You teach one class personally, every day, forever. This is the game that exists today and it must never become the tutorial for the other one. |
| **At the desk** | You run a school. You assign teachers to rooms, manage a budget and a reputation, and read results. You may still drop into any room and teach it yourself. |

### The rule that keeps both honest

> **A room you delegate is simulated by the same model you play.**

This is not a convenience — it is the load-bearing decision of the whole
design, and it is already built.

`tools/sim.gd` models a teacher as a **policy**: a reaction time, and whether
they collect, settle, quiz and teach. It runs whole terms and reports what
happens. That *is* an AI member of staff. The results a hired teacher
produces are therefore honestly generated by the same rules the player is
subject to — not assigned by a formula that approximates them.

Today's six policies, and what they produce over 40 days *(verbatim from
`tools/sim.gd`, 2026-08-16)*:

```
--- IDEAL ---     avg A   38 items   8 students   taught 53%
--- GOOD ---      avg A   33 items   8 students   taught 69%
--- LAZY ---      avg C   27 items   8 students   taught 69%
--- NOBODY ---    avg F    0 items   4 students   taught  0%
--- QUIZZER ---   avg A   40 items   8 students   taught 78%
--- SHOUTER ---   avg B   28 items   8 students   taught 77%
```

Those are six hireable teachers, already balanced, already asserted.

---

## 4. The core loop as it stands

### The day
A three-phase state machine (`Game.Phase`) — **MORNING**, **LESSON**,
**AFTERNOON** — and every verb in the game is gated on it.

1. The class files in through the door and sits down.
2. **Podium (F)** — deals three lesson plans. You leaf through them and set
   one. The lesson starts and a clock runs (`lesson.lesson_seconds 45.0`).
3. **You teach.** Standing within `teaching.radius_tiles 6` of the podium
   fills the class's attention at `0.85/s`; leaving drains it at `0.25/s`.
   **Work advances in proportion to attention, and `floor_rate` is 0.0** —
   an unattended class does nothing at all.
4. Children get **stuck** (`?`, work frozen), **mess about** (`!`, spreads to
   neighbours), or come back **behind on a quiz** (blue). Three problems,
   three colours, one instruction: go to that desk.
5. Collect finished work; hand it in at your desk. Work you never collected
   is worth half (`grade.uncollected_penalty 0.5`).
6. **Bell (F, held)** — grades pay coins, furniture costs upkeep.
7. Overnight: homework comes back on a diligence roll, and you mark it blind
   the next morning.

### The three assessments
Deliberately three instruments that *play* differently, not one screen with
three titles.

| | when | stakes | what you do |
|---|---|---|---|
| **Quiz** | mid-lesson, E at the podium | low | Costs 11 lesson-seconds. Results immediately; flags whoever is behind, which unlocks a verb at their desk. The only one you can act on. |
| **Homework** | overnight | medium | Marked blind — the answer key is hidden and the tells are only 75% reliable. Waving a bad sheet through makes that child secretly behind. |
| **Unit test** | morning, after teaching a unit 3× | high | Silent room. No helping, no collecting, no stalls. You may only watch. |

### The term
20 days, then an exam. **A set number must pass** (`term.target_base 2`,
rising by `target_growth 1` each term) and the number is on the status strip
from the first morning. Pass and the next term opens, carrying your room,
curriculum, level, perks and coins — but **not your class**, because the
children who passed move up and out.

> *"So a term you taught well empties your class of exactly the children you
> got good at teaching."*

---

## 5. Systems reference

*Measured 2026-08-19. ~26,000 lines across scripts, tests, tools and data.*

### Run state — `scripts/autoload/game.gd`
Seeded RNG · day phases · roster and enrolment · neighbour model (reads live
desk positions) · class tick (helping, copying, disruption) · grading and the
grade split · room score · terms, targets and `next_term()` · teacher XP,
levels and perks · graduation · concepts · room expansion · unit test ·
inspection · voice · attention/teaching · aide · quiz · coaching · the
assignment hand · specialism · difficulty · economy · homework · items ·
input arbitration (`claim_action`) · save/load · the cheat flag.

### Data — `scripts/data/`
`balance.gd` (122 tunables, static so it works with no SceneTree) ·
`student_data.gd` (one child's whole record) · `curriculum.gd` ·
`items.gd` · `assignments.gd` · `traits.gd` · `events.gd` · `progress.gd`
(every perk effect funnelled through one place) · `questions.gd` (four
banks, hidden key) · `names.gd` · `version.gd`.

### World — `scripts/world/`
`grid.gd` (32px tiles -- doubled Aug 2026, was 16px -- AStarGrid2D, `BASE 20×11` → `MAX 34×20`) ·
`layout.gd` (landmarks; seats movable) · `classroom.gd` (the world root, the
lesson clock, bubbles, the day, ambient weather keyed to today's day event —
see below) · `room_builder.gd` · `placement.gd` (ghost cursor, build mode,
aisle-safety check).

**Ambient weather** *(Aug 2026)* — five of the twenty day events
(`wet_play`, `heatwave`, `sports_day`, `cold_snap`, `cleaning`) now spawn
drifting motes in the room itself while their lesson is live, using
`Fx.weather_mote()`. Purely cosmetic — it changes nothing `DayEvent`'s own
hooks do not already change — but it turns "today is different" from a
line on last night's report into something visible while you are standing
in the room. The other fifteen events spawn nothing, on purpose: most days
should still look like the plain room they have always been.

### Actors, interactables, UI
`actor.gd` / `player.gd` (per-button targeting, hold-to-confirm, autopilot) /
`student.gd` · 11 interactable types · `hud.gd` (2741 lines, 16 screen modes,
20 of them sharing `REPORT`) · `title.gd` (6 pages) · `debug_panel.gd` ·
`fx.gd` · `floater.gd` · `sfx.gd` · `settings.gd`.

### Concepts are texture, not a collection

**Decided August 2026, after the curriculum doubled to 120 concepts.**

`concept_bonus` is 0.012 each with a cap of 0.12, so **the cap is reached
at ten concepts**. The other hundred and ten move no number in the game.
That is not a bug to be fixed by raising the cap — the bonus being small,
capped, and worth zero on day one is exactly what holds the three-row
contract still, and row three already sits at 0.97 with very little
headroom left in the A band.

So the honest reading is that **concepts are breadth, not currency**. They
are what you have learned to teach. A hundred and twenty of them describe
a real curriculum; they were never meant to be a hundred and twenty
collectibles, and the systems have never treated them as such.

What follows from that:

- **The cap stays where it is.** Anything proposing to raise or remove it
  is proposing to move the contract, and must say so out loud.
- **Nothing prints a concept fraction.** The board read
  `Curriculum (8/120)`, which promised a completion target and made a
  teacher's own subject knowledge look like a checklist she was failing.
  It now reads `Curriculum (8 learned)`. Asserted.
- **Item links are curated, not exhaustive.** Roughly twenty concepts
  across a fifty-item shop — enough that the concept→furniture loop is
  visible and legible, not so many that every item is a key to a lock.
  Chasing one link per concept would make each one meaningless.
- **A milestone counting concepts must not name the figure.** `polymath`
  read "All sixty" and became false the day the curriculum grew.
  Asserted.

The one thing genuinely lost is a reason to learn concept 87. That is
accepted: the reward for teaching the whole curriculum is the `polymath`
milestone and having taught it, not a number going up.

### Content, counted

| | count |
|---|---|
| Lessons | **40** (10 per strand, difficulty 1–5; 6 deliberately uncited) |
| Concepts | **120** (exactly 3 per lesson) |
| Strands | 4 — Maths, English, Science, Humanities |
| Furniture | **29** in 5 categories; 5 teach a concept, 3 are gated behind one |
| Student traits | **12** — Quiet, Curious, Chatty, Steady, Copies, Bright spark, Loud, Shy, Restless, Panics, Anchor, Ghost |
| Day events | **20**, weighted to 100 |
| Assignment rarities × forms | **5 × 5** |
| Teacher perks | **5** (10 rank purchases) |
| Names | 96 first, 64 surnames, 8 sprite sheets |
| Homework questions | 89, 3 to a sheet |
| Art | 71 PNGs · Audio: 11 WAVs |
| Screens | 16 modes |
| Input actions | 15 (14 rebindable) |
| Tests | **1189 assertions** across **81 sections** |

### What is on offer, everywhere
*Verbatim from `tools/audit.gd`, which stands at every landmark in every
phase. This is the systems-of-record for the verb list.*

```
-- MORNING --
   podium        E: -                       F: Teach Economics
   bell          E: -                       F: -
   noticeboard   E: Curriculum (0/60)       F: Furniture shop
   desk 1        E: -                       F: Move Nora's desk
-- LESSON --
   podium        E: Quick quiz              F: End the lesson early
   noticeboard   E: Curriculum (0/60)       F: -
   desk 1        E: Help Nora               F: -
   desk 2        E: Have a word with Quinn  F: -
   desk 3        E: Collect Beau's work     F: -
-- AFTERNOON --
   bell          E: -                       F: Ring the bell — end day 1
   noticeboard   E: Curriculum (1/60)       F: Furniture shop
-- CARRYING WORK, at your desk --
   your desk     E: Hand in 3 sheets        F: -
-- A UNIT YOU HAVE TAUGHT, in the morning --
   podium        E: Unit test: Economics    F: Teach Economics
```

---

## 6. The school layer ***(Phase 1 built, Phase 2 to build)***

**Built:** rooms you buy, staff you hire, wages that land daily, furniture
bought as a level, delegated days resolved by running the lesson, the
school board, and — *(Aug 2026)* — a real **hallway**: walk out your own
door and every room you hold is a physical door in a corridor, not a menu
row. Your own door leads back in; a staffed room's door opens the watch
screen; an unstaffed one opens hiring; the last door, shown only when
`Game.can_open_room()` says you actually can, opens a new one. The second
door along, always there, is the **principal's office** — milestones,
career totals and a tutorial shelf, reached by walking rather than by a
key. See §7.

**Also built, same batch:** the principal as the game's tutorial mascot.
`hud.principal_says(id, text)` is `hint_once()` with a face on it —
same once-per-run gate, same respect for `Settings.show_hints`, shown in
a corner popup (`MascotBox`/`MascotPortrait` in `hud.tscn`, deliberately
OUTSIDE `$Overlay` so it can appear while no screen is open, which is
exactly when a tip is needed) rather than a disembodied line of text.
Every existing hint now goes through it.

**Not built:** choosing which room to spend your day TEACHING in. Walking
to a delegated room now gets you to its watch/hire screen faster than the
old Tab-through-School route did, but it is still resolved by `RoomSim`,
not played — the hallway is real navigation to a real choice of *screen*,
not yet a second body to stand in. Making a delegated room personally
playable, by swapping which room's grid/roster/furniture is "live" when
you enter it, is Phase 2 and it is the manager altitude's actual core.

### What a room is
A room is a **classroom instance**: a grid, a set of desks, a class of
children, a teacher (you or hired), a year group, and its own furniture.
Today `Game` holds exactly one of each of these implicitly. The first
engineering job of the school layer is making "the class", "the room" and
"the furniture" plural — everything else follows from that.

### The school day, at the desk
The question "you manage" does not answer is *what do you do, minute to
minute*. The answer:

1. **Morning.** You see the school: each room, its teacher, its class, and
   anything flagged (a new intake, a bad run, an inspection due).
2. **You choose one room to be in today.** That room you play exactly as the
   game plays now.
3. **Every other room resolves instantly** using its teacher's policy.
4. **Evening.** A results board — one row per room, in the colours the game
   already uses. Anything that went wrong is a place to be tomorrow.

The choice of *where to spend yourself* is the strategic core of the manager
altitude, and it is the same choice the lesson already asks at small scale:
you cannot be in two places.

### Hiring
Staff are drawn as a small pool with wages, in the same card idiom as the
lesson plans. You cannot see everything about a teacher before hiring —
their weakness shows in results.

### Rooms
Bought with coins and gated on reputation. Each has a year group, which sets
the difficulty band of the lessons that room can teach.

---

## 7. Staff as policies ***(to build, from a built thing)***

A hired teacher **is** a play-style. The fields already exist in
`tools/sim.gd`:

| field | what it means | today's range |
|---|---|---|
| `reaction` | seconds before they notice a child needs them | 0.5 (ideal) → 15 (lazy) |
| `teaches` | do they stand at the front at all | true/false |
| `collects` | do they gather finished work | true/false |
| `shouts` | do they settle a noisy room | true/false |
| `quizzes` | do they run a mid-lesson quiz | true/false |
| `buys` | will they spend the room's budget | true/false |

**The design rule for staff:** *a teacher is never strictly better than
another, only better at something.* A fast reactor who never collects; a
steady one who cannot settle a noisy room; a quizzer who is superb with a
struggling class and wasted on a good one. This is what makes assignment a
decision rather than a sort.

Their wage scales with their strengths, and the daily-wage model already
exists — `aide.daily_wage 18` — so keeping staff is a standing decision, and
in a bad term they are what you let go.

---

## 8. Progression and the score

Three layers, each doing a different job.

### Reputation ***(built — no UI yet)*** — the gate
One standing figure, 0..100. Moves on what every room did that day — your
own class included — and drifts back toward the middle, so one glorious term
does not carry a school forever. **Gates** how many rooms your standing will
stretch to and how good the applicants are; below 5 the school is finished.

It deliberately GATES rather than pays: a bonus would just be more money in
a game that already has enough.

**It has no UI yet.** It moves and it gates, and the player cannot see it —
which by this project's own standards makes it half-built.

### School size ***(built)*** — the growth
Rooms, staff, pupils on roll. The visible, satisfying number that goes up.
This is what a screenshot shows.

### Children got through — the tally
**Already exists** as `Game.graduated`, and already shown on the end-of-term
and career screens. Lifetime count of pupils you saw all the way to passing.
The humane score: *the good you did*.

### Milestones ***(built)*** — the punctuation
An endless game on a store page needs authored progress or it reads as
unfinished. Milestones are named, one-off achievements against the three
layers above — *"a second room"*, *"a hundred children"*, *"an outstanding
inspection"*, *"a term where every child passed"* — that give a run
punctuation without giving it an ending.

Fifteen of them, on the career page off the pause menu. They gate nothing
and pay nothing — the moment is the reward, and a test asserts one leaves
your coins untouched. Unearned ones show as `- - -` rather than hiding,
because a list of what you have done is a trophy cabinet and one that shows
what is left is a map.

---

## 9. Failure

Two scales, deliberately.

| | |
|---|---|
| **A bad term shrinks you** | Miss a target and you lose reputation, and with it rooms, staff and intake quality. You fall back toward one classroom. Recoverable. |
| **Sustained failure closes you** | Repeated misses, or bankruptcy, and the school shuts. The run is over and the career screen is your score. |

The existing single-term fail state (`Game.run_over`, `show_run_over()`) is
the seed of the second. It already prints every term you taught, in order,
with the failed one in red — deliberately *a career rather than a failure
notice*.

**The player must see the cliff coming.** A term that would close the school
is announced as such at its start, in the same way an inspection is
announced the evening before:

> *"An unannounced judgement is weather."*

---

## 10. Economy

*Every figure from `data/balance.json`, 2026-08-16.*

| source | amount |
|---|---|
| Grades | `coins_per_grade_point` **14.0** × class average × class size |
| Assignment rarity | ×1.0 → **×2.8** (Common → Legendary) |
| Teaching your own subject | **×1.25** (`specialism.coin_bonus`) |
| Graduating a child | **90** + **45** per level beyond ready |
| A passed inspection | up to **420** |
| Day events | `budget` pays **120** |
| Selling furniture | **50%** back |
| Starting purse | **80** |

| sink | amount |
|---|---|
| Furniture | 30 → 320 coins (29 items) |
| Consumables | 25 → 55 coins (4 items, spent same day -- *(Aug 2026)*) |
| Upkeep | **3**/item/day |
| An aide | **260** to hire, **18**/day |
| Coaching a child | 90 or 70, ×**1.7** each time, max 4 per child |
| Growing the room | **26**/tile, ×**1.45** per expansion |

### The tension to name
**This economy was tuned for one room.** Six rooms multiply every sink —
upkeep, wages, furniture — while the income per room is unchanged. The
manager altitude is a *different economic game* and will need re-simulating
from scratch. `tools/sim.gd` is the instrument for that, and it will need to
learn about multiple rooms before Phase 2.

---

## 11. Content plan

| | now | target for release | note |
|---|---|---|---|
| Lessons | 20 | **40** | 8 per strand across 5 difficulty bands |
| Concepts | 60 | **120** | 3 per lesson, automatic |
| Furniture | 29 | **50** | more per category, and room-type-specific |
| Traits | 12 | 12 | done -- each changes what the player *does* |
| Day events | 20 | 20 | done -- 20 rows, weights total exactly 100 |
| Staff archetypes | 12 | 12 | done -- policy combinations with names and wages |
| Room types | 1 | **5** | year groups; see the tier design below |
| Milestones | 22 | **30** | 7 landed in the August 2026 batch; 8 more were rejected for duplicating existing milestones or citing state the game does not keep |

### On the citation rule

You have moved the curriculum from **pillar** to **flavour**, which frees
content from needing verifiable documents. One recommendation, and it costs
nothing:

> **Keep the 19 real codes that exist, and mark anything invented as
> invented.** Relaxing the rule should mean *"we may now invent"*, not *"we
> may now blur the two"*.

The existing lessons cite genuine Common Core, NGSS and Maryland Social
Studies codes, and six lessons are deliberately uncited under the old rule
(`using_sources` plus the five social-studies lessons of the August 2026
batch). That honesty is free to keep and impossible to recover
once mixed. Suggest a `"cited": true|false` field so the two can never be
confused, and so a future "real standards" marketing claim stays true.

### The tier system — already designed, not built
`docs/PLAN-tiers-buffs-shop.md` contains a five-tier design (Nursery →
Sixth form) where each year group plays differently: shared tables where one
stuck child blocks the group, self-chosen strands with off-task drift, a
seminar where *"your verb is asking, not helping"*. Its own note calls it
*"five games sharing a shell."*

**This is the natural content for room types.** A school with five year
groups is exactly the frame that design was waiting for. It should be folded
into the school layer rather than built separately.

---

## 12. Art direction

**Staying procedural pixel.** The decision is made and the pipeline exists.

- **32×48** character cells (doubled Aug 2026, was 16×24 -- chibi
  proportions redrawn at the same time), **5×4** sheets (4 facings × 5
  frames, the last being seated), one 160×192 PNG per character.
- Characters **are palettes** — `make_art.py` draws one model and recolours
  it. A new character is a data-table edit.
- Furniture is drawn in code (`make_items.py`), floors and walls are
  composed at runtime from 18 tile pieces so the room can grow.
- Contact shadows on everything that stands; flat items opt out.

### The tools
| | |
|---|---|
| `Make a Sprite.bat` | New character: writes the palette, draws the sheet, imports it, registers the name |
| `Draw a Sprite.bat` | Hand-drawing editor (HTML, same style as the EduSystems curator) — brush, fill, soften, flatten, **retint**, onion skin, mirror, 80×96 export. **Not yet updated for the Aug 2026 resolution doubling** — still exports at the old 80×96/16×24 size, so the five hand-edited furniture items (bookshelf, lab_bench, art_easel, rug, plant) are the one part of the shop still at the old scale until this tool is updated too. |
| `Browse Art.bat` | Every sprite at once; flags unreferenced art and missing art |

### What the school layer needs ***(to build)***
Staff portraits · room thumbnails · a school-level view that is not a
classroom · year-group visual identity.

> **The seam that has bitten before:** `make_art.py` writes PNGs but cannot
> import them, and Godot cannot load an unimported texture. The suite now
> loads every PNG and asserts none returns null, and `make_art.py` warns by
> name about anything it just wrote that has no `.import`.

---

## 13. Audio

**Music and ambience — effectively from nothing.**

| now | needed |
|---|---|
| 11 procedural WAVs (`make_audio.py`) | A score |
| One bus, one volume | A second bus so music and SFX are separate |
| 8-voice pool with a throttle table | Room tone: murmur, chairs, pages, a clock, weather |

This is **the one area where the procedural approach probably has to stop.**
Synthesised blips are charming; synthesised music is not, and a paid release
will be judged on it. Either a composition pass or licensed tracks.

Ambience is the higher-value half: a classroom that *sounds* occupied does
more for this game than a melody would, and it can be layered by state —
quieter during a test, restless when the room is noisy.

---

## 14. UX rules

- **640×352** (doubled Aug 2026, was 320×176 -- same 20×11 room, denser
  pixels, same 3x window scale). The whole room is one screen at the
  opening size; the camera only moves once you have bought a bigger room.
- **Two buttons.** E is the mashable verb (help, collect, hand in); F is
  session-level (lesson, bell, shop). *"You mash USE all lesson long, and it
  must never be able to end the lesson."*
- **One landmark carries a verb on each button** — the podium teaches on F
  and quizzes on E. Shared tiles resolve **by key**, never by node order.
- **Anything irreversible is HELD**, with a bar in the prompt.
- **Panel budget: 11 rows at font 16** in a 576×256 body (doubled Aug
  2026, was font 8 in 288×128 -- the row count is unchanged, only the
  pixels). Both the prompt bar and the status strip are Labels and clip
  in silence, so both are fit-tested.
- **The prompt bar names both buttons** whenever both are live.

---

## 15. Production roadmap

The honest observation first: **the school layer is a bigger job than
everything built so far combined**, and it re-decides both the economy and
the core loop. Phase 0 is deliberately not "start the school".

### Phase 0 — Harden what exists
- Milestones (§8) — the missing piece for an endless game
- Re-simulate the economy with an eye on multi-room scaling
- Buying additional desks (noted as unbuilt; class cap is hard-wired at 8)
- Fold `docs/PLAN-tiers-buffs-shop.md` into this document and retire it

### Phase 1 — One extra room, simulated
- Make the class, the room and the furniture plural
- One hired teacher, one delegated room, resolved by policy
- The evening results board
- **Gate:** is a delegated term worth reading? If not, stop and rethink.

### Phase 2 — The manager altitude
- The school view, assignment, the choice of where to spend the day
- Hiring, wages, the staff pool
- Room types / year groups (the tier design)

### Phase 3 — The career
- Reputation, school failure, the career screen
- Milestones surfaced, achievements

### Phase 4 — Release
- Audio (score + ambience), school-layer art
- Steam furniture: achievements, cloud saves, a settings pass
- Balance across a full career rather than a term

---

## 16. Risks and open decisions

### Risks

**1. ~~The two altitudes may not both be fun.~~ — ANSWERED, 2026-08-17.**
The gate has been run. `tools/schoolsim.gd` (`Simulate the School.bat`)
plays a term of delegated rooms and prints the evening board:

```
   day  Room 2      Room 3      Room 4
   1    B           E !         F !
   7    D           F !         F !
   13   B           E !         F !
   20   B           E           F
```

Room 2 is a Veteran with furniture, Room 3 a Supply teacher with none,
Room 4 nobody at all. Three visibly different rooms; the board moves day to
day; and an unstaffed room is a flat wall of F that reads as a problem you
have to go and solve. Across the twelve archetypes the same class scores
**0.48 (D) to 0.68 (C)** with different failure modes — one leaves work
uncollected, another loses the room, another never spots who is behind.
(Re-verified against `Simulate the School.bat` after the August 2026 grade
band softening — see `data/balance.json`'s `grade_bands`; the underlying
room/lesson/homework formula did not change, only which letter a given
score lands on.)

**Hiring is a decision and the board is worth reading.** Phase 2 is clear
to proceed.

It also caught two real bugs in its first run, both of which would have made
delegation meaningless: attention was computed from cumulative sums rather
than ticked as state (so a Supply teacher was indistinguishable from an
empty room), and an empty teacher record defaulted `teaches` to true (so an
unstaffed room quietly taught itself).

**2. An endless game needs milestones or it reads as unfinished.**
A Steam player who reaches term 5 with nothing named to aim at will stop.
→ *Mitigation:* milestones are Phase 0, before the school.

**3. The economy is tuned for one room.**
Six rooms multiply every sink and leave income per room flat.
→ *Mitigation:* teach `tools/sim.gd` about rooms before Phase 2.

**4. Scope.** A school layer plus five year-group designs plus audio plus
art is more than has been built to date.
→ *Mitigation:* the phase gates, and a willingness to ship the one-room game
if Phase 1's gate fails.

### Open decisions
- Does the player character have an identity, or are they a cipher?
- Is there a timetable, or does each room teach one lesson a day?
- Do children persist across rooms as they move up year groups? *(Powerful,
  and expensive — the transcript system already supports it.)*
- Difficulty options, or one curve?
- Save slots, or one run?

---

## How this document stays true

1. **Every number is quoted from `data/balance.json`** with its section
   named, never retyped from memory.
2. **The header carries a "measured on" date and the assertion count**, so a
   reader can tell how stale it is.
3. **`tools/audit.gd` and `tools/sim.gd` output is pasted verbatim** as the
   systems-of-record for what the game offers and how it plays.
   Regenerating either is one command:
   `Audit the Room.bat` · `Simulate a Term.bat`

*If a section here disagrees with the game, the game is right and this
document is stale. Fix the document.*
