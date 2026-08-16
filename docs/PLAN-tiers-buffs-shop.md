> # SUPERSEDED — see `docs/GDD.md`
>
> **Parts 1-3 of this document are BUILT and shipped** (August 2026). The
> shop shows its items and describes them in prose; teacher levels, perks,
> student levels, coaching, graduation and readiness all exist. The line
> below saying "nothing here is built" has been wrong for some time.
>
> **Part 4 — the five-tier system — is still unbuilt, and is still the best
> design in this repo for what year groups should be.** It is folded into
> the GDD as the content plan for room types (§11), where a school with five
> year groups finally gives it the frame it was waiting for.
>
> Its open questions have since been answered in code: "grade quicker"
> became *fewer sheets* (`Progress.sheets_skipped`), student levelling is
> automatic and spendable via coaching, and the term kept its exam alongside
> graduation. Its note that "353 assertions assume the T2 loop" is stale —
> there are 962 now.
>
> Kept for the Part 4 design. Do not plan from Parts 1-3.

---

# Plan: a shop you can see, levels, graduation, and five ways to teach

Nothing here is built. This is a proposal covering:

1. **See the items in the shop** — it's a text list today.
2. **Levels** — progress the teacher *and* individual students to be
   better, faster, more efficient.
3. **Graduation as your decision** — you choose when a child is ready.
4. **A tier system like EduSystems**, but where each grade genuinely learns
   differently: infants play with the toys until their bar fills, elementary
   work in small groups, and so on.

Ascending order of size. (1) is an afternoon. (4) is a different project —
I've said where that line falls rather than pretending it's all one job.

---

# Part 1 — A shop you can see

## What's wrong now

`_render_catalogue()` in `scripts/ui/hud.gd` prints:

```
> Bookshelf      140   +0.09 within 4
  Art Easel      190   +0.11 within 3
```

You are buying furniture you have never seen, described by a decimal. Two
problems: no picture, and `+0.09 within 4` is the exact raw-number style the
student file deliberately avoids.

## Proposal

**A preview panel, reusing the student-portrait pattern.** The `Portrait`
TextureRect built for the bio already does 90% of this — a `TextureRect` fed
an `AtlasTexture`, hidden by `_open()`, switched on by the screen that wants
it. The catalogue points it at `art/<item>.png` and shows the selected row
large on the right.

**Per-row icons are the expensive half.** A `Label` can't hold images, so an
icon column means converting the overlays to `RichTextLabel` with `[img]`
tags. That's a decision about the whole UI layer, not a side effect of this.

**Recommendation:** big preview now (an hour); treat "should the overlays
become RichTextLabel" as its own question.

Also replace `+0.09 within 4` with words — *"Helps the desks close around
it"* vs *"Reaches the whole room, but gently"*. The precise number is already
visible where it matters, in the green range highlight at placement.

---

# Part 2 — Levels

Two separate ladders, because they answer different questions. Both earn XP
from play; both spend it on things you choose.

## 2a. The teacher levels

**XP from:** days taught, class average, and students graduated well-prepared
(see Part 3). Levelling gives a skill point.

| perk | effect | note |
|---|---|---|
| Brisk Walk | `SPEED` 60 → 75 → 90 | The lesson clock is the pressure; this buys time directly. |
| Long Reach | `PICK_RADIUS` 20 → 28 | Help without lining up exactly. Changes routing, not speed. |
| Steady Hands | carry unlimited work | Removes a trip, so it competes with Brisk Walk rather than stacking. |
| Calm Presence | students within N tiles stall less while you stand there | The only one that changes *how you play*, not how fast. |
| Practised Eye | off-screen stuck students get an edge marker | Mild while the room is one screen. |
| Quick Marker | marking | **Nothing to speed up yet — see below.** |

### "Grade quicker" has nothing to speed up

The marking screen is one verdict per sheet with **no timer** — deliberately,
because EduSystems found per-question marking hit 32–120 taps a lesson and
had to be redesigned to exactly this. So "grade quicker" means one of:

- **add a timer** and let levels buy slack against it — adds pressure;
- **auto-mark the obvious sheets** — removes play from the one minigame;
- **fewer sheets a night** — free, and honestly the best value.

Worth deciding rather than assuming.

### The architectural catch

`SPEED` and `PICK_RADIUS` are `const` in `actor.gd` and `interactable.gd`.
Every other tunable moved into `data/balance.json` precisely so it could be
changed *and simulated* — these two were missed because they read as physics
rather than balance. Levels force that fix, which is a good thing: it means
`tools/sim.tscn` can model a levelled teacher.

## 2b. Students level

**XP from:** work completed, homework handed in, and being helped. Levelling
nudges their own numbers — slightly faster work, slightly less stalling.

Two ways to run it, and they play very differently:

- **Automatic** — they simply improve by attending. Quiet, realistic, no new
  screen. You feel it rather than manage it.
- **You spend on them** — "extra tuition", "a word with their parents",
  bought from **the student's own file**, with rising costs per child.

**Recommendation: both.** Levels come automatically from teaching them; the
file screen lets you *spend* to accelerate one child. The interesting
decision is who — the struggling child who needs it, or the strong one who
converts it into grades fastest?

**Note:** `aptitude` and `diligence` are rolled once at enrolment and never
change. Making them mutable is easy, but the file screen's "prose, never
numbers" rule has to keep holding — *"has been getting extra tuition"*, not a
rising decimal.

---

# Part 3 — Graduation, and the trap in it

**Your decision, per student.** A child accumulates readiness; you choose the
moment. Graduating is done from their file, which finally makes that screen
act rather than only report.

## The trap, stated plainly

If graduating loses you a strong student and hands you a weak replacement,
**the optimal play is to never graduate anyone.** A decision with an
obviously correct answer isn't a decision. Whatever else this design does, it
has to make holding a child back cost something. Three ways, and I'd take the
third:

1. **A payoff for sending them up** — coins and teacher XP scaled by how
   ready they were. Straightforward, but it's just a number against a number.
2. **A cost to holding them** — a child kept past readiness gets bored:
   stalls more, drags the class average, maybe unsettles neighbours. Real
   pressure, but it can feel like the game nagging you.
3. **Graduation *is* the score.** The term isn't graded on your class
   average — it's graded on **who you sent up and how ready they were**. Then
   holding a child back isn't punished, it just doesn't score, and the
   decision is genuinely yours: send them now for a safe pass, or keep them
   two more weeks for a better one and risk the term ending first.

(3) turns the end-of-term exam from a thing that happens *to* you into the
consequence of choices you made. It also gives the class-size cap teeth: a
desk occupied by a coasting child is a desk a new one can't use.

## What happens to the child

**They leave, and a younger one enrols.** You stay a nursery teacher; your
record is who you sent on. This keeps one room at one tier, which is what
makes the tier system tractable at all — see below.

*(The alternative — the whole class moves up with you — is a lovely story and
means five sprite sets and five simultaneous room layouts. Noted, not
recommended first.)*

---

# Part 4 — Five grades, five ways to teach

## What EduSystems actually does

`TIER_LEARNING` gives each tier a label and a few modifiers on **one shared
system**:

| tier | label | discover | team |
|---|---|---|---|
| T1 | Discovery | 0.34 | — |
| T2 | Guided Discovery | 0.30 | — |
| T3 | Peer Tutoring | 0.20 | 2, tutor |
| T4 | Group Work | 0.20 | 2, diverse |
| T5 | Seminar | 0.20 | 3, diverse |

The names promise five ways to teach; the code delivers three numbers. You're
asking for the version where they're genuinely different — better, and much
more work.

## The tiers

PixelRoom today **is** T2. T1 sits below; T3–T5 above.

### T1 · Nursery — *Free play*
- **No seats, no assigned work, no homework, no podium.**
- Children wander and settle at whatever furniture appeals. Each has an
  **engagement bar** that fills at something they like and drains when they
  drift.
- They tire of a toy — the same one stops filling the bar — so the room needs
  **variety** rather than quality.
- **Your verb:** spot a drifting child and lead them somewhere. Redirecting,
  not un-sticking.
- **Grade** = how full their bar got.
- Furniture becomes **toys**, and variety replaces range as the room stat.

Your "play with the furniture till their bar is filled". It's the most
different from the current game, which is exactly why it should be built
first — it proves the architecture can carry a genuinely different lesson.

### T2 · Elementary — *Seated work* (already built)
Assign at the podium, they stall, you circulate, collect, hand in.

### T3 · Middle — *Small groups*
- Desks become **shared tables**, two or three to a table.
- A table moves at its members' pace, but **one stuck child blocks the
  table** — so a single un-stick helps everyone at it.
- **Composition matters:** a strong child with a weaker one lifts both; two
  weak ones stall constantly.
- **A new pre-lesson phase:** you arrange the groups. A real decision, made
  once a lesson, and the thing you'd get good at.

### T4 · High — *Independent study*
- Students pick their own work by strand, so a lesson has no single subject
  and your attention splits across four topics.
- They stall less but drift **off-task** — recoverable, and it looks
  different from a `?`.
- Homework carries much more of the grade.

### T5 · Sixth form — *Seminar*
- Three or four around one table.
- The work is collective: a discussion bar that fills only while people
  contribute.
- **Your verb is asking, not helping** — draw out the quiet one, or the loud
  one crowds everyone else out.

## How you reach a new tier

With graduation settled as "the child leaves", the tiers hang off **teacher
level**, not off the class: you get *promoted*. Reach a level, unlock the
next classroom, choose which to teach. One room at one tier at a time, which
is what keeps this buildable.

## What it touches

- **`Layout` becomes per-tier.** Already a const table read by
  `RoomBuilder`, so this is additive — but it means five room designs and
  five sets of art (T1 open play space, T3 group tables, T5 one big table).
- **`classroom.gd` grows a lesson-mode strategy.** The tick loop, what each
  interactable offers, and what the report says all become per-tier. Honestly
  described: **five games sharing a shell.**
- **The grade contract multiplies by five.** "Room sets the floor, teacher
  sets the ceiling" has to hold in each mode or be deliberately different in
  each. `tools/sim.tscn` models one loop today and needs a policy per tier —
  without that, tier balance is guesswork, which is the exact failure the
  simulator was built to stop.
- **Tests.** 353 assertions assume the T2 loop. They'd need to become
  per-mode, or the suite quietly stops covering four fifths of the game.

---

# Sequencing

| # | | size |
|---|---|---|
| 1 | Shop preview panel + prose effects | S |
| 2 | `SPEED`/`PICK_RADIUS` into run state so they're tunable and simulable | S |
| 3 | Teacher XP, levels, and the perk screen | M |
| 4 | Student XP and levels (automatic) | S |
| 5 | Coaching bought from the student file | M |
| 6 | Graduation from the file + readiness + the term scored on who you sent up | M |
| 7 | Decide "grade quicker" — timer, auto-mark, or fewer sheets | XS to decide |
| 8 | Tier scaffolding: lesson-mode strategy, per-tier layout, sim policies | **L** |
| 9 | T1 Nursery free play | **L** |
| 10 | T3 Middle small groups | **L** |
| 11 | T4, T5 | **L each** |

**1–7 are a normal amount of work** and, importantly, they're *good on their
own* — levels and graduation make the existing game deeper without needing
tiers at all. **8–11 are the different project.** One tier at a time, with
the simulator extended before each, rather than building five and discovering
the balance was fiction.

---

# What I still need from you

1. **"Grade quicker":** a marking timer to beat, auto-mark obvious sheets, or
   just fewer sheets a night?
2. **Student levelling:** automatic only, spend-only, or both (my
   recommendation)?
3. **Does the term still have an exam**, or does graduation replace it as the
   score? Option (3) in Part 3 says replace — it's the cleanest, but it's
   also throwing away something that already works.
4. **Order:** 1–7 first so the current game gets deeper, or straight at T1
   because free play is the part you actually want to see?
