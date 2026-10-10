# EduSystem — Steam page (draft)

*Originally a content batch, August 2026 (source: ChatGPT, integrated
without changes). **Revised 2026-09-04** against the vault's positioning
files — `business.md`, `offers.md`, `customers.md`, `voice.md` — and
against the real build at commit `2d57099`, build stamp **b44**. Copy
only: nothing here touches code, balance or the contract.*

**Nothing on this page has been submitted or published anywhere.** A
store listing is public-facing, so it gets shown to the user first —
`rules.md` 3.

---

## Name

**EduSystem.** One word, capital E, capital S.

`business.md` records this as the store-facing name, deliberately one
letter away from the older `EduSystems` prototype. The August draft wrote
"EDUSystem" throughout — corrected here, because a store page is the one
place a spelling becomes permanent.

## Price

**Free, with optional rewarded video ads.** Confirmed 2026-08-24
(`offers.md`, `business.md`). No paywall; the full game is included. Ads
are optional and rewarded only — never a forced interstitial, never
unprompted.

*Open question, flagged not decided:* Steam lists this as **Free To
Play**, a tag carrying genre baggage — gacha, energy timers, paid
progression — that this game deliberately does not earn. Worth deciding
whether to accept the tag or spend a line of the description distancing
from it.

## Tagline

> **Teach the room. Lose the class. Start again.**

Kept from the August draft. It has aged better than it was written to:
"start again" is now literally the run structure after the roguelike
pivot.

One alternate, closer to the thematic core the founder named in
`customers.md` — *"society grows great when old men plant trees in whose
shade they shall never sit"*:

> **The children you teach best are the ones who leave.**

## Short description

*(Steam caps this at 300 characters. This is 262.)*

> EduSystem is a classroom management sim about the work of teaching.
> Teach lessons, walk to stuck pupils, settle disruption, furnish the
> room, mark homework without an answer key, and get a class through its
> exam. The children who succeed are the ones who leave.

## Long description

You are the teacher, and the classroom is the game. Stand at the front
and work advances. Leave the teaching position and the room slows down.
Walk between desks to find children who are stuck, deal with pupils
disrupting their neighbours, collect finished work, and decide where your
attention actually matters.

The room is part of the job. Furniture helps the pupils near it, so the
layout you build changes the class you teach. A good room cannot replace
a good teacher, and a good teacher cannot rescue a room that gives
children nowhere useful to work. Neither alone is enough — that is the
rule the whole game is balanced around.

Homework is marked without an answer key. The tells are useful but
imperfect, so every sheet is a judgement rather than an answer check.
Quizzes surface pupils falling behind; unit tests and the end-of-term
exam show whether the work held together.

**The game never shows you a number for a child.** Open a pupil's file
and it tells you, in words, what is acting on them right now — their
temperament, the day's event, whether the room suits today's subject,
who they sit close enough to chat with, whether you have been standing close
enough, and what they are doing to themselves. Sorted by what is working
against them, worst first. A bad grade always traces back to something
you can point at.

Some mornings the paper fights back. On the last day of a boss term an
examiner stands at the front and the exam itself makes a move each round
— freezing a child, setting off a row, filling the room with noise — and
you answer with the same verbs you use every other day: steady the frozen
one, settle the disruption, put a pupil up front to present, or talk the
whole room through it and hope. The record still decides the exam. The
day decides the margin.

Terms continue; the class does not. When pupils pass, they leave and a
new group arrives. Keep the school going, improve the room, hire staff as
it grows, and decide how much of the work you still want to do yourself.

## Features

- **Teach from inside the classroom** — work advances only while you
  actually teach.
- **Walk the room** — find stuck pupils, settle disruption and collect
  work yourself. Standing near a child matters.
- **Build a classroom that works** — furniture genuinely changes how the
  pupils near it learn.
- **Mark homework blind** — judge finished work with no answer key, on
  imperfect tells.
- **Read a child in words, never numbers** — every file names what is
  helping and what is hurting, in plain language.
- **Play the exam, don't just receive it** — boss papers are a real
  encounter with rounds, moves and answers.
- **Answer the door mid-lesson** — the principal and the children
  interrupt with decisions that cost something either way, while the
  lesson clock keeps running.
- **Run a career, not a campaign** — pupils move on, and every term
  starts with another class.

## Screenshot order

1. **The room in progress** — pupils at their desks, the teacher
   teaching at the front.
2. **A stuck pupil** — the teacher crossing the room toward work that has
   stopped.
3. **A furnished classroom** — a room with several useful pieces placed
   around the desks.
4. **A child's third page** — what is acting on them, for and against, in
   words.
5. **The boss paper** — the examiner at the front, mid-encounter.
6. **Homework marking** — a sheet being judged with no answer key
   visible.
7. **The curriculum book** — the cream-paper spread, mid page-turn.
8. **The empty desks after term** — a cleared classroom, ready for the
   next class.

*All eight exist in the current build. 1–3, 6 and 8 were in the August
draft; 4, 5 and 7 are new work from the 2026-08-30 → 09-04 push, and are
the most distinctive things the game has.*

## Capsule art — needed, not made

Steam requires a set of capsule images at fixed sizes (header, small,
main, vertical, plus library art). **Confirm the current required
dimensions against Steamworks before drawing anything** — they change,
and this file should not become the place a stale list lives.

*Open question:* `goals.md`'s non-negotiable now reads *"art stays
generated or hand-made — it never gets bought."* That rule was written
about game art. Capsule and header art is marketing art. If the rule
covers it too, capsules come out of `tools/make_art.py` or the user's own
hand, and that constraint should shape the design now rather than after
someone has already drawn something. Not decided here.

## What this page does not yet reflect

Honest gaps, so whoever edits this next knows what is missing rather than
assuming it is finished:

- **No audience framing.** `customers.md` names high school gamers as the
  first-picture player, wants quick sessions and daily challenges, and is
  gender-neutral by design. None of that shapes the copy above yet.
- **A live contradiction in the vault.** `voice.md` describes the product
  as *"a mobile game people play for quick sessions and daily
  challenges."* `business.md` and `offers.md` say Steam is the real
  target and mobile is a stretch. Both cannot be the brief. Resolve it
  before writing anything audience-facing.
- **"Daily challenges" are asserted nowhere in the build.** Do not put
  them on a store page until they exist.
- **No trailer, no tags, no genre list, no system requirements.**
- **Nobody has played this game.** Every claim above is derived from the
  design documents and the test suite, not from anyone's experience of
  playing it. Copy written before the first playtest is a hypothesis, and
  should be re-read the day after someone else has played.
