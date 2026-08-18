# PixelRoom — task pack for Gemini / ChatGPT / Claude chat

**How to use.** Open a **new chat per task**. Attach the files listed under
that task. Paste the prompt verbatim — everything inside the fenced block,
nothing else. Save the reply. When you are back, hand it to Claude Code and
say **"integrate task N"**.

Every prompt is **self-contained**: the real numbers are written into the
prompt itself, so a stale document cannot poison the output. Attach the
files anyway — they are the authority if the two ever disagree.

Tasks are ordered by value. ⭐ marks the ones worth doing first.

---

## Why these prompts look over-specified

They are written against three failures that actually happened, and every
oddity below is load-bearing:

1. **A worked example with invented numbers.** The briefing once showed the
   microscope at `bonus 0.05` when the real item is `0.13`. A model anchored
   on it and produced 22 items at half the correct strength — all of them
   traps, none of them obviously wrong. **Every schema example in this pack
   is copied verbatim from the live data file.**
2. **A model that cannot see the data invents plausible substitutes.** Asked
   for concept ids without `curriculum.json` attached, it used the four ids
   visible in the briefing's examples — including a globe that required
   fraction models. **Every prompt that references ids ships the real list.**
3. **A check performed is not a check enforced.** Told to compute a value
   and check it against a range, a model computed it, printed a violation,
   and shipped the item anyway. **Every numeric rule below says what to do
   when it fails, not just how to test it.**

---

## House rules — true of every task

Restated inside each prompt, because a rule stated once in a preamble is a
rule a long generation forgets.

- **Prose, never numbers, in anything a player reads.** "Picks things up
  quickly", not "aptitude 0.72". A test enforces this.
- **47 characters maximum for a body line**, 11 rows to a screen. Labels
  clip in silence.
- **British-flavoured, plain English.** Short words. No exclamation marks,
  no emoji in game text, no jokes a tired person would resent.
- **It must change what the player does.** A trait, item or event that only
  prints a sentence is decoration, and decoration teaches players to stop
  reading.
- **Never invent a standards code.** An uncited lesson is more honest than a
  fabricated citation.
- **Machine-readable JSON in one code block, no commentary**, in exactly the
  schema given.

---

## Task 1 — Twenty more lessons ✅ DONE (August 2026)

**Integrated.** The curriculum is now 40 lessons / 120 concepts. Fifteen
came back with real, verified codes and the source's own wording; five
social-studies lessons were honestly returned uncited and went in that
way. **Do not re-send this prompt** — it would collide with everything
below. Kept for the record, and because its shape is the template for any
future curriculum task.

<details>
<summary>The prompt as sent</summary>

**Attach:** `data/curriculum.json`

```text
You are writing curriculum content for PixelRoom, a classroom management
sim whose lessons cite real published standards. The attached
curriculum.json is the real, current file: 20 lessons, 5 per strand,
60 concepts.

Write 20 more - 5 each for math, ela, science and social - bringing each
strand to 10.

SCHEMA. One lesson, copied verbatim from the live file:

  {
    "id": "fractions",
    "name": "Fractions",
    "short": "Fractions",
    "icon": "",
    "strand": "math",
    "standard": "4.NF.A.1",
    "source": "Maryland CCR Standards for Mathematics (2025)",
    "objective": "Explain why a fraction a/b is equivalent to a fraction (n x a)/(n x b) by using visual fraction models.",
    "difficulty": 2,
    "concepts": [
      {"id": "fractions.equivalent", "name": "Equivalent fractions",
       "standard": "4.NF.A.1",
       "source": "Maryland CCR Standards for Mathematics (2025)", "at": 1},
      {"id": "fractions.compare", "name": "Comparing fractions",
       "standard": "4.NF.A.1",
       "source": "Maryland CCR Standards for Mathematics (2025)", "at": 3},
      {"id": "fractions.models", "name": "Fraction models",
       "standard": "4.NF.A.1",
       "source": "Maryland CCR Standards for Mathematics (2025)", "at": 6}
    ]
  }

FIELD RULES

  id          lowercase, underscores, unique
  short       13 CHARACTERS MAXIMUM. It is a column on a 320-pixel screen
              and it clips in silence. Count the characters.
  icon        always an empty string
  strand      exactly one of: math ela science social
  difficulty  1 to 5. Exactly four lessons at each level across your
              twenty. It drives how often the subject confuses a child.
  concepts    EXACTLY three. Never two, never four.
              "at" is 1, 3 and 6 in that order - the number of teachings
              that unlocks it.
              A concept id is always parent_lesson_id.short_name.
              A concept cites its PARENT lesson's code, never one of its
              own. Minting 4.NF.A.1.a would be a fabricated citation.

THE CITATION RULE - this is the point of the task.

Do not invent a plausible-looking code. An uncited lesson is more honest
than a fabricated citation, and this is the one error nothing downstream
can catch: a wrong code looks exactly like a right one.

  - Cite a code ONLY where you are confident it exists AND says what you
    claim it says. Verify it rather than recalling it. 4.NF.A.1 and
    MS-PS1-2 are real; something that merely follows their shape is not.
  - Where you are not confident, set BOTH "standard" and "source" to ""
    and list that lesson under an UNCITED heading after the JSON, with
    one line saying what you were unsure about. It will be registered
    deliberately. One field filled and the other empty is never
    acceptable.
  - "objective" should be the source document's own wording wherever you
    are citing one. Paraphrase only for uncited lessons.
  - I would rather have six honestly uncited lessons than twenty with one
    invented code in them. Do not pad the citations to look complete.

Use exactly these four source strings, matching the existing file:

  "Maryland CCR Standards for Mathematics (2025)"
  "Maryland CCR Standards for ELA (2025)"
  "Maryland Science Standards (NGSS)"
  "Maryland Social Studies Framework (June 2025)"

Add a page reference where you have one, in the existing style:
"Maryland CCR Standards for ELA (2025), p23".

DO NOT COLLIDE

These 20 lesson ids exist: reading_fluency, basic_arithmetic,
handwriting_grammar, science_basics, map_geography, pre-algebra,
essay_writing, earth_life_science, world_history, speaking_listening,
place_value, fractions, algebra_one, vocabulary, life_cycles, chemistry,
ecosystems, civics, economics, using_sources.

These codes are already used - pick different ones: RF4, 3.OA.C.7, L.3.1,
5-PS1-3, Standard 3.0, 7.EE.B.4, W.7.1, MS-LS1-1, Standard 2.0, SL.8.4,
3.NBT.A.2, 4.NF.A.1, A-REI.B.3, L.4.4, 3-LS1-1, MS-PS1-2, MS-LS2-3,
Standard 1.0, Standard 4.0.

No new id, name or standard may collide with those.

BEFORE YOU OUTPUT

Check each of these and FIX anything that fails - do not report a
violation and ship it anyway:
  - exactly 20 lessons, 5 per strand
  - exactly four lessons at each difficulty 1-5
  - every "short" is 13 characters or fewer
  - every lesson has exactly 3 concepts, at 1 / 3 / 6
  - every concept's standard equals its parent lesson's standard
  - no id, name or code collides with the lists above

OUTPUT

One JSON array of 20 lesson objects in a single code block. Then the
UNCITED list. No other commentary.
```

</details>

**What the round taught us, for every task below.** Two models answered.
The one that shipped had checked its own work against the closing
checklist; the one that was rejected returned all twenty uncited, giving
"no attached curriculum.json" as its reason — it had misread the citation
rule as being about the attachment rather than about the code. It also
shipped a 14-character `short`. **Every prompt below now ends with a
checklist for exactly that reason: a rule the model does not verify against
is a rule it will explain away.**

---

## Task 2 — Twenty-one more items of furniture ⭐ SEND THIS NEXT

**Attach:** `data/balance.json`, `data/curriculum.json`

> **When it comes back**, save the JSON to a file and run
> `python tools/check_items.py thatfile.json` before anything else. It
> enforces every rule below mechanically — the count, the density window,
> the range and cost bands, concept links that exist and are not already
> taught, the ladder check, blurb length and voice, and near-duplicates
> of the existing 29. Round 1 scored 24 rejections against it.

```text
You are designing furniture for PixelRoom, a pixel-art classroom
management sim. Design 21 new items for the classroom shop, taking it
from 29 to 50. The attached files are the real, current data. Read them
before starting and trust them over anything else.

SCHEMA. One item, copied verbatim from data/balance.json -> "items":

  "microscope": {
    "name": "Microscope", "art": "microscope", "cost": 280,
    "range": 3, "bonus": 0.13, "w": 1, "cat": "learning",
    "blurb": "The first time a child sees a cell is worth the price.",
    "teaches": "earth_life_science.cells"
  }

  cat     one of: seating surfaces learning comfort decor
  art     same string as the item id
  name    13 CHARACTERS MAXIMUM. The shop prints it through a 13-wide
          column and simply cuts anything longer, with no warning. Two
          shipped items were being truncated before this rule existed,
          and eight of a twenty-two item batch would have been. Count
          the characters, spaces included: "Science Station" is 15 and
          is cut to "Science Stati".
  w       width in tiles, 1 or 2
  cost    30 to 400
  range   how many tiles away it still helps a desk, 2 to 6
  bonus   what it adds to a desk's grade floor, 0.02 to 0.15
  flat    true for anything on a wall or flat on the floor, which casts
          no shadow: a clock, a notice board, a banner, a rug, a poster.
          A bookshelf, a desk, a globe on a stand are NOT flat.
          Omit the field entirely when false.
  teaches optional - a concept id this item unlocks outright
  needs   optional - a concept id that must be known before it is on sale

THE EXCHANGE RATE - the constraint that matters most.

All 29 existing items, as cost / bonus / range. This is the economy you
are matching:

  stool 45/0.03/2        floor_cushion 40/0.03/2   beanbag 95/0.05/3
  bench 150/0.06/3       crate 50/0.03/2           side_table 80/0.05/3
  cabinet 170/0.07/3     supply_shelf 210/0.08/4   maths_tiles 110/0.07/3
  abacus 130/0.08/3      globe 160/0.09/3          music_corner 190/0.10/3
  microscope 280/0.13/3  reading_nook 260/0.11/4   whiteboard 300/0.12/5
  lamp 65/0.04/3         coat_hooks 70/0.04/4      water_cooler 140/0.06/4
  radiator 180/0.07/5    pot_of_pens 30/0.02/3     wall_clock 55/0.03/5
  class_banner 90/0.04/5 alphabet_frieze 100/0.04/6  fish_tank 240/0.07/6
  plant 70/0.05/3        bookshelf 140/0.09/4      art_easel 190/0.11/3
  rug 240/0.07/6         lab_bench 320/0.15/3

RULE 1 - VALUE DENSITY. For every item:

    cost / (bonus x range)   must land between 360 and 840.

  All 29 existing items satisfy this: the real spread runs from 367
  (wall_clock) to 833 (bench). Work it out for each item you write,
  showing the substituted numbers, e.g.

      quiet_chair: 105 / (0.06 x 2) = 105 / 0.12 = 875

  875 is outside the window, so that item is NOT FINISHED. Change the
  cost or the bonus and recompute until it lands inside, THEN write it
  into the JSON.

  Do not print a failing number and ship the item anyway. A previous
  attempt was asked to compute this, computed it correctly, printed
  five values between 857 and 1167, and submitted all five regardless.
  Nothing outside 360-840 may appear in your output.

  Watch the arithmetic. That same attempt also mis-multiplied three
  items - substitute the real range, not a different one.

RULE 2 - REACH TRADES AGAINST STRENGTH.

  A high bonus means a SHORT range. A wide range means a WEAK bonus.
  lab_bench is the strongest at 0.15 but reaches only 3 tiles. rug
  reaches the whole room at 6 but is worth 0.07.

  Do NOT scale bonus and range together with cost. That removes the
  decision and makes expensive items strictly better than cheap ones.
  Every item should be somebody's right answer and somebody else's waste
  of money. Before you finish, look at your 21 sorted by cost: if bonus
  and range both rise together down that list, you have made a ladder
  instead of a set of choices, and you need to redo it.

THE BLURB - 60 characters maximum.

This is the house voice. Read all of these before writing one:

  stool          Somewhere else to perch.
  pot_of_pens    Half of them work.
  beanbag        Nobody sits up straight in one, and that is fine.
  cabinet        Everything has a place, in theory.
  class_banner   This is OUR classroom.
  water_cooler   They will use any excuse to visit it.
  radiator       A cold classroom teaches nobody anything.
  crate          Everything ends up in here eventually.
  microscope     The first time a child sees a cell is worth the price.

Dry, British, observational - a teacher's aside about the thing, not a
description of it. It may be wry. It must never read like a supplier's
catalogue.

THE TEST: if the blurb would still be true printed under a stock photo
of the object, it is not finished. "Gives children a quiet place to
read" for a Reading Rug fails - it adds nothing a player cannot read off
the label. "Somewhere to disappear into a book" passes.

No exclamation marks. No emoji. No numbers.

CONCEPTS - use the real ones.

Concept ids live in the attached curriculum.json: three per lesson, 120
in total, formatted lesson_id.concept_name. Real examples:
ecosystems.food_webs, place_value.regrouping, civics.rights,
vocabulary.roots, chemistry.reactions, world_history.chronology,
weather_patterns.observe, decimals.compare, phonics.decode.

  - At least 7 items must "teach" a concept; at least 5 must "need" one.
    The shop currently links only 8 concepts in total, and the design
    target is roughly twenty across all 50 items - enough that the
    concept-to-furniture loop is visible, not so many that every item is
    a key to a lock. Your 21 are where most of that gap gets closed.
  - Copy ids verbatim from the attached file. Never invent or guess one.
  - The link must make sense. A globe may teach map reading; a globe must
    not require fraction models. If you cannot justify the pairing in one
    sentence, drop the field.
  - No more than TWO of your items may touch the same lesson. Three
    fraction items is a shop that only serves one lesson.
  - These five concepts already have an item that teaches them - do not
    reuse them: pre-algebra.variables, basic_arithmetic.tables,
    map_geography.reading_a_map, speaking_listening.presenting,
    earth_life_science.cells.

SPREAD

  Exactly 21 items. Number them 1 to 21 in your working before you write
  the JSON, and count them again afterwards. Two previous attempts
  returned 22 and 20.
  Weighted toward "learning" and "decor", which are thinnest at the top
  end. Every category gets at least two.

NO NEAR-DUPLICATES.

  A new item that is the same kind of object as an existing one is a
  duplicate even when the name differs. All of these would be rejected:
      Reading Lamp    (there is already a Lamp)
      Plant Shelf     (there is already a Plant)
      Fraction Tiles  (there is already Maths Tiles)
      Bench Seat      (there is already a Bench)
      Classroom Clock (there is already a Wall Clock)
      Reading Rug     (there is already a Rug)
  Check every one of your 21 against the list of 29 above and against
  the attached file. Find genuinely new ground instead.

  Here is new ground, if you want it - real classroom objects with no
  equivalent in the shop yet. Take from this freely, ignore it freely,
  and you are not limited to it:

    Chalkboard, Cork Board, Letter Board, Magnetic Letters, Storybook
    Shelf, Puppet Theatre, Listening Station, Counting Beads, Shape
    Sorter, Anatomy Model, Sand Table, Water Table, Sensory Table,
    Peg Board, Clay Station, Pottery Wheel, Printmaking Press,
    Overhead Projector, Pull-Down Screen, Lectern, Vocabulary Wall,
    Wash Basin, Umbrella Stand, Hamster Cage, Zen Sand Garden,
    Toy Chest, Cubby Shelf, Assignment Tray, Sorting Tray, Art Caddy,
    Wall Cabinet, Portfolio Rack, Rest Mat, Step Stool, Crawl Tunnel,
    Lounge Ottoman, Welcome Banner, Student Art Wall, Display Case,
    Mural Panel, Butterfly Display, Framed Mirror, Trophy Cabinet.

ART BRIEFS

After the JSON, one line per item describing the sprite:

  - 16x16 for w:1, 32x16 for w:2.
  - 3/4 view, chunky pixel art, dark outline, flat colours.
  - Standing items: "bottom row meets the floor".
  - flat:true items: "hangs on the wall, no floor contact, no shadow".
    Never write "bottom row meeting floor" for a clock or a poster.
  - No readable text anywhere in the sprite. Lettering at 16 pixels
    becomes noise.

OUTPUT, in this order:

  1. One JSON object keyed by item id, in a single code block.
  2. The art briefs, as a plain list.
  3. The value-density working for all 21, showing the substituted
     numbers, every result inside 360-840.

No other commentary.
```

---

## Task 3 — Six more student traits ⭐

**Attach:** `data/balance.json`

```text
You are designing student traits for PixelRoom, a classroom management
sim. A trait is what makes one child different from another - not how
WELL they work (that is aptitude and diligence) but how they behave
while they do it, and therefore what the player has to do about them.

Design 6 new traits, taking it from 6 to 12.

THE HOOKS - the complete set the engine reads.

This is the whole list. A trait using any other field is silently
ignored at runtime: it will look like mechanics in the file and behave
like decoration in the game. Do not invent a field.

  stall_mult            float. Multiplies how often THEY get stuck.
                        Above 1.0 = stuck more often.
  neighbour_stall_mult  float. Multiplies how often the children EITHER
                        SIDE of them get stuck.
  hide_seconds          float. Seconds their stuck state stays invisible
                        to the player - they are stuck, and you cannot
                        see it yet.
  help_xp_mult          float. Multiplies the XP you earn for helping
                        them.
  copy_from_neighbour   bool. They get unstuck off a neighbour, without
                        understanding it.
  helps_neighbour       float. They lift the child next to them by this
                        much.

A trait carries ONLY the hooks it uses. It does not list the others at
neutral values.

SCHEMA, copied verbatim from the live file:

  "chatty": {
    "name": "Chatty",
    "blurb": "Talks to whoever is sitting next to them.",
    "neighbour_stall_mult": 1.5
  }

THE EXISTING SIX, with the hook each one uses:

  quiet    "Will not say when they are lost."
           hide_seconds 6.0
  curious  "Asks about everything. Gets stuck more, learns more."
           stall_mult 1.35, help_xp_mult 2.0
  chatty   "Talks to whoever is sitting next to them."
           neighbour_stall_mult 1.5
  steady   "Quietly gets on with it."
           stall_mult 0.7
  copier   "Leans over at the first sign of trouble."
           copy_from_neighbour true
  bright   "Finishes early and helps the next desk along."
           helps_neighbour 0.35

THE RULE THAT MATTERS.

A trait must change what the PLAYER DOES. It must hook into the work
model (how often they stall, how much help is worth, whether their
trouble is visible) or into the seating (how they affect the child next
to them). A trait that only prints a sentence on the class list is
rejected - decoration is what teaches a player to stop reading the list.

The bar is set by the existing six. Quiet is not "shy"; Quiet is "you
will not notice this child is stuck until six seconds have passed, so
walk past them on purpose". That is a trait.

For each of your six, write one paragraph saying what the player has to
do DIFFERENTLY because of it. If you cannot write that paragraph, the
trait is decoration - replace it before you submit.

Aim at ground the existing six do not cover. Combinations are allowed
and often the most interesting - a child who is quick but drags their
neighbour, a child worth helping only late in the day.

THE BLURB - 47 characters maximum.

Plain, British, observational. It is what the file says about the child;
the player is NEVER told the numbers. "Will not say when they are lost"
is right. "hide_seconds 6.0" or "gets stuck 35% more" is wrong.
The children are people, not stat blocks. No jokes at their expense.

BEFORE YOU OUTPUT

  - every trait uses at least one hook, and only hooks from the list
  - no blurb exceeds 47 characters
  - no blurb contains a number
  - you can write the "what changes for the player" paragraph for all six

OUTPUT

One JSON object keyed by trait id in a single code block, then the six
paragraphs. No other commentary.
```

---

## Task 4 — The five year groups ⭐⭐ (design, not data)

**Attach:** `docs/GDD.md`, `docs/BRIEFING.md`

```text
PixelRoom is a classroom management sim: you are a teacher, and walking
the room is the game. A class of up to eight children sit at desks. Work
only advances while you stand at the front teaching it. Children get
stuck (frozen until you reach them), mess about (spreads to whoever sits
next to them), or fall behind. You collect finished work, mark homework
blind, and furnish the room. See the attached design document.

It is growing from one classroom into a school of up to six rooms, and
each room will have a YEAR GROUP that changes HOW THAT ROOM PLAYS - not
just its difficulty. An earlier sketch called it "five games sharing a
shell": nursery children play until an engagement bar fills; middle
school children work at shared tables where one stuck child blocks the
group; sixth formers hold a seminar where "your verb is asking, not
helping".

Write the design for five year groups. For each, give me:

  - What the room LOOKS like and how it is laid out
  - What the child-level model is - what replaces "gets stuck"
  - WHAT THE PLAYER'S PRIMARY VERB IS, and how it differs from the
    current "walk over and press E to unstick them". This is the heart
    of it: if two year groups share a verb, one of them is a difficulty
    setting wearing a costume, and you should say so.
  - What the failure state looks like
  - Which existing systems (quiz, homework, unit test, disruption,
    voice, the assignment cards) apply, change, or do not apply
  - One paragraph on why a player would CHOOSE to run this year group
    when they could run an easier one

HARD CONSTRAINTS

  - Desk-based and mouse-free. Two buttons: E is the mashable verb and
    is never destructive; F is session-level. Anything irreversible is a
    HOLD.
  - It must work at 320x176 pixels, 11 rows of text to a screen.
  - "Walking the room is the game." A design where the player stands
    still is a different game, not a year group.
  - Prose, never numbers. Do not propose balance values - they have to
    be simulated, not reasoned about.
  - The children are people. The tone is a proper management sim:
    grounded, quiet, demanding. Not whimsical, not a joke about school.

BE OPINIONATED. Where you think one of these five is a bad idea, or two
should be merged, or the sixth-form seminar cannot work in this engine,
say so plainly and say why. A confident "this one does not work" is
worth more to me than five polished designs of equal enthusiasm. Put
those judgements in a section at the end called RESERVATIONS.

Output as Markdown. No JSON in this one.
```

---

## Task 5 — Six more staff archetypes

**Attach:** `data/balance.json`

```text
You are designing hireable teachers for PixelRoom, a classroom
management sim. Design 6 new archetypes, taking the hiring pool from
6 to 12.

WHAT A TEACHER IS, MECHANICALLY.

A hired teacher is a POLICY. When you delegate a room, the game runs the
same lesson model the player is subject to, with the teacher's policy
making the decisions the player would make with their feet. So these
five fields are the entire teacher - there is nothing else to tune:

  reaction  float, seconds before they notice a child needs them.
            1.0 = very quick. 14.0 = barely there. Existing range 1-14.
  teaches   bool. Whether work advances while they are in the room.
  collects  bool. Whether they collect finished work.
  settles   bool. Whether they deal with a class messing about.
  quizzes   bool. Whether they check who has fallen behind.
  wage      int, coins per day. Existing range 11-52.

SCHEMA, copied verbatim from the live file:

  {
    "id": "firm", "name": "Firm",
    "blurb": "Nothing gets out of hand. Slow to notice quiet trouble.",
    "reaction": 8.0, "teaches": true, "collects": true,
    "settles": true, "quizzes": false, "wage": 26
  }

THE EXISTING SIX:

  steady      4.0  collects, teaches                        wage 22
              "Reliable. Will not chase a noisy room."
  sharp       1.0  teaches, settles                         wage 30
              "Spots a stuck child instantly. Forgets the paperwork."
  firm        8.0  teaches, collects, settles               wage 26
              "Nothing gets out of hand. Slow to notice quiet trouble."
  diagnostic  5.0  teaches, collects, quizzes               wage 34
              "Quizzes constantly. Superb with a class that is behind."
  supply     14.0  teaches only                             wage 11
              "Cheap, and it shows. Better than an empty room."
  veteran     2.0  everything                               wage 52
              "Does everything well. Costs what that is worth."

THE RULE: A TEACHER IS NEVER STRICTLY BETTER THAN ANOTHER, ONLY BETTER
AT SOMETHING.

Every archetype needs a real hole in it. The moment one dominates,
hiring stops being a decision and becomes a sort. Veteran is the
deliberate exception and it is priced accordingly - do not write a
second one.

Test each of yours: name a class you would give them, and a class you
would NOT. If you cannot name the second, they have no hole and the
archetype is rejected.

Cover ground the existing six do not. Think about:
  - the teacher who is wonderful with a struggling class and wasted on a
    good one
  - the one who is cheap because nobody else will have them
  - the one whose strength only shows over a whole term
  - the one who is superb at exactly one of the four jobs and hopeless
    at the rest

WAGE. Price against the existing range honestly. A cheap archetype with
no real weakness breaks the hiring screen, and a costly one with two
holes will never be hired. Note that "teaches" is false only for a
genuinely broken hire - a teacher who does not teach stops the room.

THE BLURB - 47 characters maximum, and it must name the STRENGTH AND
THE HOLE in one line, the way all six above do. Plain British English.
Prose, never numbers: "Spots a stuck child instantly" is a thing the
player can act on; "reaction 1.0" is not.

BEFORE YOU OUTPUT

  - no archetype is strictly better than an existing one on every field
    at an equal or lower wage. Check each against all six above.
  - every blurb is 47 characters or fewer and names a weakness
  - no blurb contains a number

OUTPUT

One JSON array in a single code block. Then one line per archetype
naming the class you would give them and the class you would not.
```

---

## Task 6 — Fifteen more milestones

**Attach:** `data/balance.json`

```text
You are writing milestones for PixelRoom, a classroom management sim
that never ends: terms keep coming and the exam target keeps rising
until you miss one. Write 15 new milestones, taking it from 15 to 30.

WHY THEY EXIST. A player who reaches term five with nothing named to aim
at stops, and reasonably concludes the game is unfinished rather than
open-ended. A milestone is authored progress without an authored ending.
It gates nothing and pays nothing - the moment it fires IS the reward.

SCHEMA, copied verbatim from the live file:

  {"id": "full_house", "name": "Every single one",
   "blurb": "A whole class passed. Not one of them left behind."}

THE RULE: IT MUST NAME SOMETHING A PLAYER WOULD TELL SOMEBODY ELSE
ABOUT.

"Taught 50 lessons" is a counter. "Got every child through" is a story.
If it reads like a progress bar it is not a milestone - the career
screen already has counters for that.

THE EXISTING FIFTEEN:

  first_term      Survived a term / Twenty days, one class, and you are
                  still here.
  first_up        Sent one up / A child you taught has moved on to
                  somebody else.
  furnished       A proper classroom / Twenty pieces of furniture, and
                  every desk feels it.
  grown           Knocked a wall through / The room is bigger than the
                  one you were given.
  full_house      Every single one / A whole class passed. Not one of
                  them left behind.
  outstanding     Outstanding / An inspector watched you teach and could
                  not fault it.
  specialist      Knows the subject / Every concept in one subject,
                  learned and taught.
  polymath        Knows the lot / Every concept in the curriculum. All
                  of them.
  ten_up          Ten children on / Ten of them have gone up because of
                  you.
  fifty_up        Fifty children on / Fifty. That is a career, not a
                  term.
  five_terms      Five terms in / Five classes taught, and five classes
                  lost to the year above.
  ten_terms       A decade of it / Ten terms. You are the one they
                  remember.
  hard_unit       Taught the hard stuff / A class sat the hardest unit
                  in the book, and passed it.
  rich            A budget at last / Two thousand coins, and somewhere
                  to spend them.
  legendary_done  They finished it / You set a Legendary paper and the
                  class handed it in.

WHAT TO COVER. The room; a career's length; teaching against the odds;
the school layer (opening rooms, hiring staff, delegating); and two or
three that are quietly sad or funny rather than triumphant. The list
above is a map of what this game thinks is worth doing - yours should
widen it, not restate it.

IT MUST BE PROVABLE FROM STATE THE GAME ALREADY KEEPS.

Nothing here may ask the rest of the game to start recording something
new. For each milestone, give one line naming the state that would prove
it, using only these:

  Game.term_history      array of past terms, each with "passed" and
                         "total"
  Game.graduated         everyone you have sent up
  Game.roster            the current class
  Game.room_items        furniture placed in the room
  Game.coins             money now
  Game.concepts          concepts you have learned
  Game.last_inspection   the most recent inspection, with a "letter"
  Game.assignment        the current assignment, with a "rarity"
  Grid.W / Grid.H        room size, against Grid.BASE_W / Grid.BASE_H
  Curriculum.concept_count()   60
  Balance.exam_pass      the pass threshold

Example: full_house is proved by a row in Game.term_history where
passed == total and total > 0.

If a milestone you want cannot be proved from that list, say so under a
heading NEEDS NEW STATE rather than inventing a variable - it may be
worth adding, but that is a decision for the engine, not for you.

THE BLURB - 47 characters maximum. Plain British English, warm but not
sentimental, and it speaks to the player as "you".

  No number in the blurb unless the number IS the story, AND the
  threshold is a fixed one that content cannot move. "Fifty children
  on" is fine: fifty is fifty forever. A blurb counting the curriculum
  or the shop is NOT fine - one of these read "All sixty" and became a
  lie the day the curriculum reached 120. If your milestone counts
  something that grows, say "all of them", never the figure.

OUTPUT

One JSON array in a single code block. Then the proof lines, one per
milestone. Then NEEDS NEW STATE, if any.
```

---

## Task 7 — Eleven more day events

**Attach:** `data/balance.json`

```text
You are designing day events for PixelRoom, a classroom management sim.
One event is rolled per day. It is the cheapest possible source of
variety in a game where every day would otherwise be byte-identical -
same eight seats, same work, same room.

Design 11 new events, taking it from 9 to 20.

SCHEMA, copied verbatim from the live file:

  {"id": "wet_play", "weight": 8, "name": "Wet play",
   "blurb": "Nobody went outside. They are fidgety but they are here.",
   "stall_mult": 1.3, "coin_mult": 1.2}

THE EFFECT HOOKS - the complete set the engine reads. An event using any
other field does nothing at all. Do not invent one.

  stall_mult      float. Multiplies how often children get stuck today.
  lesson_mult     float. Multiplies the length of today's lesson.
  coin_mult       float. Multiplies coins earned today.
  bonus_coins     int. A one-off payment.
  homework_sure   bool. Everyone did their homework.
  inspection      bool. An inspector watches the lesson.

An event carries only the hooks it uses. "none" carries none at all.

THE EXISTING NINE, with weights totalling exactly 100:

  none        30  An ordinary day / Nothing out of the usual.
  restless    12  Restless class / stall_mult 1.6
  focused     12  Unusually focused / stall_mult 0.55
  short_day   10  Assembly this morning / lesson_mult 0.65
  long_day     8  Double period / lesson_mult 1.5
  inspector    8  An inspector is visiting / inspection
  wet_play     8  Wet play / stall_mult 1.3, coin_mult 1.2
  budget       6  Budget came through / bonus_coins 120
  keen         6  Homework club ran late / homework_sure

THE RULES

  1. EACH MUST CHANGE A REAL NUMBER. An event that only prints a line is
     decoration. If you cannot attach it to a hook above, it is not an
     event - it is flavour text, and this game does not have a slot for
     that.
  2. They should feel like things that ACTUALLY HAPPEN in a primary
     school. A fire drill, a heatwave, half the class off with a bug, a
     visiting speaker, the photocopier broken, a supply teacher next
     door. Not disasters, not whimsy.
  3. Mix helpful and unhelpful, and include two or three that are BOTH -
     wet_play is the model: they are fidgety, but they are all here and
     you get more done. A tradeoff is more interesting than a modifier.

WEIGHTS. You are rebalancing all twenty, not just adding eleven.

  - "An ordinary day" must stay the single most common outcome by a wide
    margin. A game where something happens every day has no baseline to
    notice things against.
  - All twenty weights must total EXACTLY 100. Add them up. If they do
    not total 100, adjust and add them up again before you output.
  - Output the full twenty-row weight table, including revised weights
    for the existing nine.

THE BLURB - 55 characters maximum. It tells the player what today is
like, in the voice of somebody who works there: "Nobody went outside.
They are fidgety but they are here." Plain British English, no
exclamation marks, no numbers, and it never names the mechanic. "They
will get stuck more today" is the honest limit.

BEFORE YOU OUTPUT

  - exactly 11 new events
  - every one carries at least one real hook from the list
  - no blurb exceeds 55 characters
  - the twenty weights total exactly 100, and "none" is the largest

OUTPUT

  1. One JSON array of the 11 new events, in a single code block.
  2. The full twenty-row weight table with the total shown.
```

---

## Task 8 — The homework question banks

**Attach:** none needed — everything is in the prompt.

```text
You are writing homework questions for PixelRoom, a classroom management
sim.

THE DESIGN CONSTRAINT, which drives everything below: the game shows you
a child's finished sheet and asks you to mark it WITHOUT an answer key.
You are guessing whether it looks right. Marking a right answer wrong
hurts exactly as much as marking a wrong one right.

Every answer is genuinely checkable, so the game is fair. But there are
more sheets than patience, so in practice the player triages on tells -
neat or rushed, working shown or not. The tells correlate with
correctness without determining it.

There are four banks - math, ela, science, social - of 12 questions
each. Write 12 NEW questions per bank, taking each to 24.

SCHEMA, copied verbatim from the live file:

  {"q": "plural of leaf", "a": "leaves",
   "wrong": ["leafs", "leafes", "leave"]}

  q      the question. 40 CHARACTERS MAXIMUM - it is a line on a sheet
         at 320 pixels. No question mark needed.
  a      the correct answer. 18 characters maximum.
  wrong  EXACTLY three wrong answers, each 18 characters maximum.

THE CRITICAL CONSTRAINT: THE WRONG ANSWERS MUST BE PLAUSIBLE.

The game picks ONE of your three wrongs at random and prints it as the
child's answer. So all three must independently look like something a
real child would actually write.

  "7 x 8 = 54"     is a good wrong answer - an off-by-one in the times
                   table, exactly the mistake a child makes
  "7 x 8 = banana" is useless - nobody has to think about it
  "7 x 8 = 55"     is weak - no child arrives at 55 by any route

Aim at the real error: the reversed digits, the regular plural of an
irregular noun, the confusion between two words that sound alike, the
step of the method that gets skipped. A wrong answer that names the
mistake is doing its job.

THE ANSWER MUST BE UNAMBIGUOUS. The player is judging it with no key, so
there must be exactly one defensible right answer. "the best planet" has
no answer. "opposite of generous" resolves to "mean" and is fine. If two
of your options could both be argued correct, the question is broken.

STYLE OF THE EXISTING BANKS, for level and tone:

  math     7 x 8 / 45 - 17 / 72 / 9 / 144 / 12 / 100 - 36
  ela      plural of child / past tense of bring / noun in: the dog
           barked / correct spelling / a word that rhymes with though
  science  water freezes at / plants make food by / the gas we breathe
           out / a magnet attracts / how many legs has an insect
  social   a map's scale shows / the largest ocean / the capital of
           Maryland / lines running east to west / a peninsula has
           water on

Roughly upper-primary level. British spelling in the ELA bank, except
where the answer IS the spelling. The social bank leans Maryland and
general geography, matching the curriculum.

DO NOT DUPLICATE any question listed above, and do not write two
questions in the same bank that test the same fact.

BEFORE YOU OUTPUT

  - exactly 12 per bank, 48 in total
  - every q is 40 characters or fewer - count them
  - every a and every wrong is 18 characters or fewer
  - every question has EXACTLY three wrongs
  - no wrong answer is silly, and none is accidentally correct
  - each question has exactly one defensible answer

OUTPUT

One JSON object with four keys - math, ela, science, social - each an
array of 12, in a single code block. No other commentary.
```

---

## Task 9 — The Steam page

**Attach:** `docs/GDD.md`

```text
Write the store copy for PixelRoom's Steam page, from the attached
design document.

WHAT THE GAME IS, so the pitch stays honest: a pixel-art classroom
management sim. You are a teacher. Walking the room is the game. Up to
eight children sit at desks; work only advances while you stand at the
front teaching it. Children get stuck, mess about, fall behind. You
collect work, mark homework blind against a key you cannot see, and
furnish the room because furniture genuinely helps the child sitting
near it. A term is 20 days and ends in an exam with a target you can
miss. Pass, and the next term carries your room and your curriculum -
but not your class, because the children who passed move up and out.
Miss enough and the school closes.

Give me:

  - a tagline, 60 characters maximum
  - a short description, 300 characters maximum - the blurb under the
    trailer
  - a long description, 3 to 4 short paragraphs
  - five bullet features
  - six screenshots to take, each with a caption, in the order they
    should appear on the page

TONE. This is a proper management sim about teaching, not a whimsical
game about school. Quiet, confident, specific. British English.

  - No exclamation marks.
  - No "Ever wondered what it's like to...?" Nobody has.
  - Do not oversell. The honest pitch is stronger than the hyped one,
    and this game's actual hook - that the children who do well leave
    you, every single term - is more interesting than anything you could
    inflate.
  - Name real mechanics rather than promising feelings. "Mark homework
    without an answer key" beats "experience the challenges of
    teaching".
  - The children are people. Not comic obstacles, not units.

THE SCREENSHOT LIST is a shot list, not a wish list - every shot must be
something the game described above can actually show on a 320x176
screen. No key art, no mockups, no scenes from a game that does not
exist yet.

Output as Markdown.
```

---

## Task 10 — The audio brief

**Attach:** `docs/GDD.md`

```text
Write a brief for a composer and sound designer working on PixelRoom, a
pixel-art classroom management sim. See the attached design document.

WHAT EXISTS NOW: eleven procedurally generated sound effects, and no
music at all.

  bell     the end of a session        paper    handling work
  blip     UI movement                 start    a lesson begins
  coins    money                       step     the player walking
  confirm  an accepted action          stuck    a child needs you
  deny     a refused action            grade    a result lands
  help     helping a child

WHAT THE GAME SOUNDS LIKE, physically: one room, eight children, a
teacher walking between desks. Paper, chairs, a bell down a corridor. It
is quiet work, and the tension is social rather than dramatic - nothing
explodes, but a room can slide away from you in silence.

Give me:

  1. THE FEEL, in one paragraph, grounded in what the game actually is.
     Not "whimsical school adventure".
  2. AMBIENCE LAYERS, and what triggers each. The game has these states,
     and they are the real ones: morning before the bell, a lesson in
     progress, a silent test, a room that has got noisy, afternoon, and
     the end-of-term exam.
  3. MUSIC CUES, each with a length and a mood. Say which are looping
     and which are one-shot. Remember a player may sit in one state for
     twenty minutes - say what stops a loop becoming maddening.
  4. NEW SOUND EFFECTS the recent systems need. The game now has a card
     hand, a quiz, a unit test, raising your voice to settle a room,
     build mode, a school board, and hiring. For each: a key name in
     snake_case matching the eleven above, when it triggers, and a
     two-sentence synthesis recipe - waveform, envelope, pitch movement,
     duration under 600ms.
  5. REFERENCE TRACKS. Name real, findable pieces, with one line on what
     specifically to take from each. Do not invent titles.

CONSTRAINTS

  - Everything must be synthesisable offline. No licensed samples, no
    orchestra, no vocals.
  - The tone is a proper management sim: grounded, quiet, demanding.
  - Nothing may be startling. The player is listening for one specific
    cue - a child getting stuck - and an ambience that competes with it
    breaks the game's core signal.

Output as Markdown.
```

---

## Task 11 — Names

**Attach:** none needed — everything is in the prompt.

```text
PixelRoom is a classroom management sim. Its children are drawn from a
pool of 48 first names and 32 surnames. Expand it to 96 first names and
64 surnames - so write 48 new first names and 32 new surnames.

THE HARD CONSTRAINT, and it is tighter than it looks:

  First names:  3 to 5 characters.
  Surnames:     3 to 5 characters.

The class-list column is eleven characters at font 8, and it holds
"First Last" including the space. Six plus six does not fit. Every
existing name obeys this - the longest in the pool are Quinn, Silas,
Hazel, Mabel, Frost, Marsh, Croft, Doyle, all exactly five. Count the
characters on every single name you write. Names clip in silence, and a
clipped name is how a child stops being a person.

THE EXISTING POOL, which you must not duplicate:

  First: Ava Leo Mia Noah Zoe Kai Ivy Eli Luna Max Nora Finn Remy Sage
  June Theo Wren Cleo Iris Beau Milo Hazel Otis Nell Asa Bree Cass Dov
  Esme Fern Gil Halle Ida Jonah Kit Lark Mabel Ned Opal Pia Quinn Rosa
  Silas Tess Uma Vince Willa Zane

  Last: Park Reed Cole Vance Cruz Day Hale Frost Nash Pike Lund Ono
  Quill Vega Wood Sol Bly Kerr Marsh Finch Doyle Rowe Tate Voss Ames Bex
  Croft Dunn Ellis Ford Gale Hart

TONE. Read the existing pool before you start - it is short, warm,
modern and broadly international rather than narrowly British. Ono, Vega
and Cruz sit next to Reed and Doyle on purpose. Match that mix and
widen it: a real school register from a city, drawn from many origins,
none of it signposted or tokenistic.

  - No joke names. No fantasy names. No names invented to fit the
    length.
  - Nothing that would be unkind to a real child who shares it.
  - Age-neutral where you can. These are children, not characters.
  - Lean slightly less common - the obvious short names are mostly taken
    already, and the pool should not read like a top-ten list.

Every name must be a name somebody actually has.

BEFORE YOU OUTPUT

  - exactly 48 first names and 32 surnames
  - every one is 3 to 5 characters - check each individually
  - none duplicates the existing pool above
  - no duplicates within your own lists

OUTPUT

Two JSON arrays of strings in a single code block, labelled FIRST and
LAST. Then a one-line count of each. No other commentary.
```

---

## When you are back

Hand the file or the pasted text to Claude Code:

> **"integrate task 3"**

It will schema-check it, load it into the game, run `Run Tests.bat` and
`Simulate a Term.bat`, screenshot anything visual, and reject anything that
moves the balance contract. Content that fails the rules comes back to you
with the reason rather than being quietly patched to fit.

**Tell me which model produced it.** These prompts get tuned from what comes
back — the value-density rule, the near-duplicate list and the "fix it, do
not just report it" wording all exist because of specific things a specific
model did.

---

## What NOT to delegate

An outside model cannot run `Run Tests.bat` or `Simulate a Term.bat`, and
this project's entire discipline is "verified against a running game".

| Delegate | Do not delegate |
|---|---|
| Content in a schema (lessons, items, traits, events, staff, milestones, questions) | **Code.** It cannot be run, and a plausible-looking GDScript patch is worse than none. |
| Copywriting — blurbs, store text, tooltips | **Balance numbers.** They must be simulated, not reasoned about. |
| Design proposals in prose | **Anything touching the three-row contract.** |
| Naming, flavour, personality | **Refactors.** |
