# PixelRoom

You are the teacher. Walking the room *is* the game.

## Play

Double-click **`Play PixelRoom.bat`**, or the **Play PixelRoom** shortcut on
the Desktop.

It opens on a title screen: **Continue**, **New term**, **How to play**,
**Settings**, **Controls**, **Credits** and **Erase save**.

| key | | rebindable |
|---|---|---|
| Arrows / WASD | walk | yes |
| **E** / Space | **help, collect, hand in, call a quiz, sit a test** | yes |
| **F** | **start or end a lesson, ring the bell, open the shop, move a desk** | yes |
| **Q** | **settle the room within earshot** | yes |
| **B** | **rearrange the room from a free cursor** | yes |
| Shift | hurry (1.7x) | yes |
| Tab | class list, and cycles buy / sell / staff room / the room | yes |
| P | pause | yes |
| Esc | back out | no, always Escape |
| F1 / F2 | live tuning panel | dev only |

**E and F are deliberately separate.** E is the button you mash all lesson
long — helping, collecting, handing in — and it can never do anything
session-level. Everything that changes the state of the day is on F, and the
two that cannot be undone (ending a lesson early, ending the day) must be
**held**, with a bar in the prompt showing the hold. Before this, one key did
all of it, and reaching to help a student who happened to be near the podium
ended the whole lesson.

One landmark can carry a verb on **each** button, and several now do: the
podium teaches on F and quizzes on E, a desk offers help on E and picks
itself up on F, the noticeboard is the shop on F and the curriculum on E.

**Settings** covers master and sound volume, window size, fullscreen and
whether hints appear. **Controls** rebinds any key — taking a key from
another action removes it there rather than leaving it bound twice.
Settings live in their own file, so erasing your save keeps them.

## The loop

1. The class files in through the door and sits down.
2. Start the lesson at the **podium**. Everyone begins their work, and a
   clock starts.
3. Students get **stuck** — a `?` appears and **their work stops dead**.
   Walk over and press E. That is the only way they make progress, and it
   is the reason you cannot stand still.
4. Collect finished work from each desk, hand it in at **your** desk. Work
   you never picked up is worth half.
5. Set homework, and next day collect and **mark** it. The answer key is
   hidden — you are judging whether a sheet looks right. Wave a bad one
   through and that student is secretly behind, and stalls more tomorrow.
6. Ring the **bell**. Grades pay coins; furniture costs upkeep.
7. Buy furniture at the **noticeboard**. Range matters — while placing, the
   desks it would actually help light up green.
8. After 20 days the class sits an exam. That is the run.

## The class is eight particular children

Every child has a **trait**, and each one changes what you have to do about
them rather than only what a number does:

| | |
|---|---|
| **Quiet** | Will not say when they are lost — no `?` for a few seconds |
| **Curious** | Gets stuck more, and gets more out of every answer |
| **Chatty** | Drags whoever sits *next to them* off task |
| **Steady** | Quietly gets on with it |
| **Copies** | Leans over at the first sign of trouble |
| **Bright spark** | Finishes early and helps the next desk along |

The rule for adding one, which the suite enforces: **it must reach into the
work model or the seating.** A trait that only prints a sentence is
decoration, and decoration is what teaches a player to stop reading the
screen it is on.

**Copies** is the one worth watching. They get themselves unstuck off their
neighbour — the work moves, the bubble disappears, and it looks like the
problem solved itself. Then the quiz, the homework and the test all quietly
disagree, because copying is not understanding.

## Messing about, and the seating plan that answers it

Being stuck and playing up are different problems, and only one of them gets
worse while you are somewhere else. A disruptive child stops working **and**
doubles the stall chance either side of them, and it **spreads along the
desks** until somebody deals with it. Settling outranks helping at the desk
for exactly that reason.

Three problems, three bubble colours: **red** spreads, **amber** is frozen,
**blue** is behind but working.

Both routes in are your own doing, which is what stops it feeling like bad
luck — **boredom** is finished work you never came to collect, and
**frustration** is a child left stuck too long. Collecting promptly is no
longer only worth grade points; it is how you keep the room quiet.

Which is why the desks move. Sit the Chatty one next to somebody who needs
to concentrate and you will find out.

## Your voice

**Q** settles every disruptive child *within earshot*. It is the only verb
in the game not attached to a landmark — and it still depends on where you
are standing, which is the line that keeps walking the room the game.

It settles the room. It does not teach anybody anything, so a stuck child is
still a walk to their desk. Roughly three shouts, recharging slowly through
the lesson, so it is the answer to *more than one at a time* rather than the
answer to everything.

The term simulator puts it at about **a whole letter grade** for a careless
player — settling two at once stops a cascade, and a cascade is what ruins a
term — while still not reaching the A that walking over earns.

## Being inspected

Sometimes the evening report says an inspector is coming tomorrow. They
watch the lesson and judge three things, all of which you can prepare
because you were told the night before:

- **the room** — what your furniture is actually worth to the desks
- **the lesson** — how much work got done, less whoever was still stuck or
  still playing up at the bell
- **the material** — whether you know what you are teaching today

A pass pays a grant. Everything judged is something the game already
tracked, and every verdict is a sentence rather than a decimal.

## Three things that carry the load for you

**Autopilot (R)** walks you to whoever needs you next — settling outranks
unsticking, which outranks the quiz flag, which outranks collecting, the
same priority the desk itself uses. It moves your **feet** and never presses
your buttons: what to do when you arrive is still a judgement, and so is the
decision to leave the front at all. Touch a movement key and it stands aside
instantly.

**A teacher's aide**, hired in the staff room and paid every day, walks the
room collecting finished work. They never help, settle or mark. That line is
deliberate — collecting is legwork, helping is a judgement about a
particular child, and hiring out the judgement would be hiring somebody to
play the game. The daily wage makes keeping one a standing decision rather
than a purchase you forget.

## Setting work is a hand of cards

The podium **shuffles and deals 3 to 7 papers** — a real shuffle, not
always the same count — and you go through them one at a time, the way a
teacher at a desk goes through lesson plans — turn the page with the
scroll wheel, a click, or Up/Down. Two axes, rolled separately and then
correlated:

| | |
|---|---|
| **Rarity** | what it PAYS — coins, and what finishing it is worth to a child |
| **Difficulty** | how LONG the paper is |

**Common · Rare · Excellent · Epic · Legendary**, in the grey/green/blue/
violet/gold ladder every looter has trained players to read without a
legend. Most papers are Common; a Legendary turns up about one time in
fifty.

They are correlated on purpose, so a Legendary is usually a demanding piece
of work — which makes the hand a decision rather than a ranking. The
question is not "which is best" but **"can this class, today, in the room I
have built, actually finish this"** — because work you never collect is
worth half. A Legendary Project nobody completes is worth less than a Common
Worksheet everybody hands in.

Rarity pays coins and experience and **never grade**. The three-row balance
contract is measured from work completion, and a multiplier on the lesson
term would move the design pillar by luck instead of by play.

## You have to actually teach

Work only advances while the class is paying attention, and attention only
comes from **you standing at the front**, near the podium. Walk away and it
drains; come back and it fills.

Which means every second at one child's desk is a second the other seven are
not being taught. That is the trade the whole game is about — and the term
simulator agrees: a policy that reacts to every twitch in half a second ends
on a **B**, while one that waits four seconds and teaches steadily gets an
**A**. Hovering costs you the room.

## Choose your subject, choose your lessons

Twenty lessons across English, Maths, Science and Humanities, each rated
**1 to 5 for difficulty** — which scales how long the work takes and how
often a child gets stuck on it. You can see the rating before you commit.

A run asks what kind of teacher you are, once. Your own subject is a step
easier and pays 25% more; everything else is a step harder. A lean, not a
cage — you can still teach all twenty, and a class that only ever sees one
subject learns one subject.

And **furniture now makes the work easier**, not just better-marked: a
well-equipped desk takes the edge off a hard lesson for whoever sits at it.

## A term is a chapter, and you can lose

Twenty days, then the exam. **A set number of children have to pass** — two
in your first term, rising every term after — and the number is on the
status strip from the first morning, not sprung on you at the end.

Miss it and the run is over: a screen of every term you taught, in order,
and the one that ended it.

Make it and the next term begins. **What you built carries over** — the
room, where the desks are, the curriculum you learned to teach, your level,
your perks, your coins. **The class does not.** Children who passed move up
and out; children who did not stay for another go, keeping their record.

Which means a term you taught well empties your class of exactly the
children you had got good at teaching, and hands you a room of strangers and
a better room to teach them in. The rising target is what makes that better
room necessary rather than merely pleasant.

## Three ways to find out what they know

|  | when | stakes | what you do |
|---|---|---|---|
| **Quiz** | mid-lesson, **E** at the podium | low | A few questions answered at the desks. Results **immediately**, worst first. |
| **Homework** | overnight | medium | Set it, collect it, mark it with the key hidden. |
| **Test** | end of a unit, **E** at the podium in the morning | high | Silent room. You may only watch. |

The quiz is the only one you can act on. It costs **lesson seconds** — the
one thing a lesson cannot make more of — and can be run once per lesson.
It carries no grade of its own; what it buys is knowing who is behind while
there is still time to walk over. Whoever falls below the line is **flagged**,
which unlocks "go over it with them" at their desk and puts a blue bubble
over their head. Going over it twice does nothing, so it cannot become a
second, better Help.

The test is gated on having taught the unit three times. Every verb is
switched off for its duration — no helping, no collecting, and nobody stalls,
because you would not be allowed to unstick them. It measures the room you
**built** and the children you developed, not how well you ran around today,
and it is worth more than a lesson can ever be.

## Learning to teach

Teaching a lesson teaches *you*. Each of the ten lessons has three
**concepts** that unlock as you teach it (after 1, 3 and 6 lessons), and
every concept you know is worth a little to every grade — small, capped at
12%, and **breadth is the only route to the cap**: teaching one lesson
thirty times unlocks its three concepts and then nothing, forever.

A concept cites its parent lesson's real standard code. It does not get one
of its own — minting a plausible-looking sub-code would be a fabricated
citation, which is worse than no citation at all.

Furniture joins the curriculum in both directions. Some items **teach** a
concept just by being in the room (a microscope really does put cells within
reach), and some are **gated** behind one, so the shop grows as you teach
and not only as you earn — a term spent on science opens a different
catalogue from a term spent on English. **F** at the noticeboard shows what
you know against what is left.

Every child keeps their own **transcript**: what they were taught, when, the
standard, and what they got. It is theirs, so it goes with them when they
move up, and it can tell you what they turned out to be strongest at, which
is not always the subject they were born good at.

## A room you can rearrange, and grow

Walk up to any desk and press **F** to pick it up — the chair and whoever is
sitting there come with it. The same aisle-safety check that stops you
walling a student in applies: a seat nobody can reach is as broken as a seat
blocked off.

The classroom itself can be bought bigger, a column or a row at a time, from
the fourth shop tab. At the opening 20x11 the room is exactly the screen and
the camera sits dead still — the whole-room-at-a-glance reading that the `?`
bubble and the audio design both lean on. Buy past one screen and the view
starts to follow you. That is a deliberate choice you make, not something
that happens to you.

## How a grade is built

```
room     0.28 .. 0.62   the furniture in range of that desk
lesson   0.00 .. 0.35   how much of their work they got through
                        (halved if you never collected it)
hw       0.00 .. 0.12   homework, reduced if you misjudged it
concepts 0.00 .. 0.12   what you have learned to teach (zero on day one)
```

Deliberately, **neither the room nor the teaching alone reaches the top**:
a perfect room with an absent teacher is a C, a bare room with perfect
teaching is a C, and both together is an A. Those three rows are asserted by
the test suite against *simulated play*.

Concept knowledge is worth exactly **zero on day one**, which is what lets it
grow a teacher across a term without moving that pillar.

## Your class

**Tab** opens the class list. Arrow to a student and press **E** to read
their file: portrait, full name, which seat they took and the day they
joined, what they are best at, how their grades are trending, their homework
record, how often you have gone over to help them, and what their own
record says they are strongest at.

Everything on it is something the game actually tracked — there is no
invented backstory — and every number is turned into a letter, a count of
days, or a word. Never a float, never a percentage: you should come to know a
child by teaching them, not by reading a statistic off a screen. A test
enforces that by forcing an odd ability value and asserting no `0.` or `%`
reaches the text.

First names are guaranteed unique within a class. They used not to be, and
with eight students there was a ~71% chance of two you could not tell apart,
because every screen shows the first name only.

## The lessons are real

The subject on the board is not decoration. `data/curriculum.json` holds ten
lessons taken from the actual Maryland state standards — each with a genuine
standard code and the source document's own wording for the objective:

| lesson | standard | from |
|---|---|---|
| Reading Fluency | RF4 | MD CCR Standards for ELA (2025) |
| Basic Arithmetic | 3.OA.C.7 | MD CCR Standards for Mathematics (2025) |
| Handwriting & Grammar | L.3.1 | MD CCR Standards for ELA (2025) |
| Science Basics | 5-PS1-3 | Maryland Science Standards (NGSS) |
| Map & Geography | Standard 3.0 | MD Social Studies Framework (June 2025) |
| Pre-Algebra | 7.EE.B.4 | MD CCR Standards for Mathematics (2025) |
| Essay Writing | W.7.1 | MD CCR Standards for ELA (2025) |
| Earth & Life Science | MS-LS1-1 | Maryland Science Standards (NGSS) |
| World History | Standard 2.0 | MD Social Studies Framework (June 2025) |
| Speaking & Listening | SL.8.4 | MD CCR Standards for ELA (2025) |

Each lesson belongs to a **strand** (maths / English / science / humanities),
and that strand decides which bank tonight's homework comes from — a Reading
Fluency lesson no longer sets `7 x 8`. Each student has a favourite strand
and stalls 25% less on a lesson in it.

**Do not invent standard codes.** If you add a lesson and cannot cite it, say
so — an uncited lesson is honest, a fabricated citation is not. The codes and
objectives here were fetched and parsed from the source PDFs in the
EduSystems project (`docs/reference/`), and carried across rather than
re-scraped so the citations stay the verified ones.

## Running things

```
Run Tests.bat            1062 assertions
Simulate a Term.bat      plays whole terms and prints the curves
Browse Art.bat           every sprite on one screen, with what uses it
Open in Godot Editor.bat
python tools/make_art.py     redraw every image
python tools/make_audio.py   resynthesise every sound

godot --path . res://tools/shot.tscn -- out.png [frames] [w] [h] [grow] [screen]
```

That last one is the screenshot harness. It runs the **real** scene windowed
and saves what it drew, optionally growing the room first or opening a named
screen (`quiz`, `curriculum`, `unit_test`, `student`, `shop`, `room`,
`staff`, `class_list`).

It exists because headless runs cannot see. A broken HUD once survived a
headless boot check, because the game opens on the title screen and never
instantiates the HUD; and six panels were quietly overflowing their box at
once, which no assertion had ever been able to catch. Note that headless
Godot also falls back to different font metrics, so `get_line_count()` lies
there — `test_panels_fit()` counts written lines against a budget measured
from real screenshots instead.

All art and all audio are generated by those two scripts — nothing is
sourced. To add art without touching code, drop a text file in
`tools/sprites/` (see the README there) and re-run `make_art.py`.

Every gameplay number lives in `data/balance.json`. Nothing tunable is a
constant in a script.

### Making art

    Make a Sprite.bat    a NEW CHARACTER, by palette
    Draw a Sprite.bat    hand-draw one sprite, pixel by pixel

A character in this game IS a palette — one drawing routine in
`tools/make_art.py` and a table of six-line colour entries — so the
generator is the right tool for a new person: it writes the palette, draws
the sheet with the same code as everyone else, imports it, and registers the
name. The editor is for the one-offs that are not palettes: props, icons,
touch-ups. It draws 16x24 cells in a 5x4 grid and exports the single 80x96
sheet the game loads.

### After adding a `class_name` or new art

    godot --headless --path . --import

A brand-new global class is not in Godot's registry, and a brand-new PNG is
not a loadable texture, until the project is rescanned. Until then every file
referencing them fails to PARSE — which does not fail an assertion, it
silently removes whole sections from the test run. Read the assertion COUNT,
never the word PASSED. It has caught this twice (724 to 560, 828 to 708).

### When the game disagrees with the tests

    Trace a Day.bat      walks one real day and prints what is on offer
    Audit the Room.bat   stands at every landmark in every phase

The suite teleports the player and presses keys straight into the InputMap.
That proves the logic and nothing about whether the game can be played —
these two walk it. They have found three bugs the suite could not see,
including one that made the game unplayable.

## Why the simulator exists

An earlier version passed 218 tests while four of its loops were wired to
nothing: collecting work fed no number, the homework verdict was never read,
the teacher could only ever matter once per lesson, and the economy could
not afford its own cheapest item. Each piece was individually consistent, so
unit tests could not see it — and the balance test set its inputs by hand,
so it validated a state the game could not reach.

`tools/sim.tscn` plays whole terms under four player policies and prints the
curves. Everything above is obvious in one table.

## Files

```
project.godot            window, input actions, autoloads
data/balance.json        every tunable number
scenes/                  main, actors, ui
scripts/
  autoload/  game.gd, sfx.gd
  world/     layout, grid, room_builder, classroom, placement
  actors/    actor, player, student
  interact/  podium, bell, desk_station, desk_mover, marking_desk,
             noticeboard, curriculum_board, quiz_caller, test_caller,
             placed_item
  data/      balance, items, questions, events, names, curriculum,
             progress, traits, student_data
  ui/        hud, floater, debug_panel
tools/       make_art.py, make_items.py, make_audio.py, sim.gd, playterm.gd,
             curator.gd, shot.gd, check_docs.py, check_balance.py,
             check_items.py, check_traits.py, godot_path.txt, sprites/
tests/run.gd
```
