# PixelRoom — briefing for an outside AI

**Attach this file to every task you hand to Gemini, ChatGPT or a Claude
chat.** It is written to be pasted into a model that cannot see the repo and
cannot run anything.

> **Design detail lives in `docs/GDD.md`.** This file deliberately does not
> repeat it — two copies of the same design drift within a fortnight. This
> is the *working* brief: what the game is in one page, the exact data
> schemas, and the rules any contribution must obey.

---

## The game in one page

A pixel-art classroom management sim in Godot 4.7, 320×176, mouse-free.

**You are a teacher. Walking the room is the game.** A class of up to eight
children sit at desks. Work only advances while you stand at the front
teaching it — leave, and the class's attention drains and the work stops.
Children get stuck (frozen until you reach them), mess about (spreads to
whoever sits next to them), or fall behind on a quiz. You collect finished
work, mark homework blind against a hidden answer key, and furnish the room
because furniture genuinely helps the child sitting near it.

A term is 20 days and ends in an exam with a **target you can miss**. Pass
and the next term carries your room, curriculum, level and coins — but not
your class, because the children who passed move up and out. Miss enough
and the school closes.

You can also hire staff, open rooms and run the place from a desk. **A room
you delegate is resolved by running the same lesson model you play**, with
the hired teacher's policy making the decisions you would make with your
feet.

**Tone:** a proper management sim. Grounded, quiet, and genuinely demanding.
Not whimsical, not a joke about school. The children are people.

---

## The rules any contribution must obey

1. **Prose, never numbers, in anything a player reads.** "Picks things up
   quickly", not "aptitude 0.72". A test enforces this.
2. **Every line must fit the panel.** 47 characters maximum for a body
   line; 11 rows in a screen. Labels clip in silence.
3. **British-flavoured, plain English.** Short words. No exclamation marks,
   no emoji in game text, no jokes that a tired person would resent.
4. **A trait, item or event must CHANGE WHAT THE PLAYER DOES.** Anything
   that only prints a sentence is decoration, and decoration teaches
   players to stop reading.
5. **Never invent a standards code.** See the citation rule below.
6. **Output machine-readable JSON in one code block, no commentary**, in
   exactly the schema given. It gets pasted straight into a data file.

---

## The citation rule — important

`data/curriculum.json` cites **real** standards: Common Core (as Maryland's
CCR standards), NGSS, and the Maryland Social Studies Framework.

> **Do not invent a plausible-looking code.** An uncited lesson is more
> honest than a fabricated citation.

If you are confident a code is real (e.g. `4.NF.A.1`, `MS-PS1-2`), cite it
and name its document. **If you are not certain, leave `standard` and
`source` as empty strings** and say so in your reply. Both fields empty is
acceptable; one filled and one empty is never acceptable.

---

## Data schemas

### A lesson — `data/curriculum.json` → `lessons[]`

```json
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
     "standard": "4.NF.A.1", "source": "Maryland CCR Standards for Mathematics (2025)", "at": 1},
    {"id": "fractions.compare", "name": "Comparing fractions",
     "standard": "4.NF.A.1", "source": "Maryland CCR Standards for Mathematics (2025)", "at": 3},
    {"id": "fractions.models", "name": "Fraction models",
     "standard": "4.NF.A.1", "source": "Maryland CCR Standards for Mathematics (2025)", "at": 6}
  ]
}
```

- `strand` is one of `math` `ela` `science` `social`.
- `short` must be ≤ 13 characters — it is a column on a screen.
- `difficulty` 1–5. It drives how often the subject confuses a child.
- **Exactly 3 concepts per lesson**, unlocked `at` 1, 3 and 6 teachings.
- A concept **cites its parent lesson's code**, never one of its own.
  Minting `4.NF.A.1.a` would be a fabricated citation.
- `objective` should be the source document's own wording where you are
  citing one.

Currently 20 lessons, 5 per strand, 60 concepts.

### An item — `data/balance.json` → `items`

```json
"microscope": {
  "name": "Microscope", "art": "microscope", "cost": 280,
  "range": 2, "bonus": 0.05, "w": 1, "cat": "learning",
  "blurb": "Real specimens. Science stops being a picture in a book.",
  "teaches": "earth_life_science.cells"
}
```

- `cat` is one of `seating` `surfaces` `learning` `comfort` `decor`.
- `range` in tiles, `bonus` is what it adds to a desk's grade floor.
- `w` is width in tiles (1 or 2). `flat: true` for wall/floor items that
  cast no shadow.
- Optional `teaches` (a concept id it unlocks outright) or `needs` (a
  concept id that must be known before it is on sale).
- `blurb` ≤ 60 characters, plain, says what it is *for*.
- Currently 29 items. Keep the price/benefit ratio roughly linear.

### A trait — `data/balance.json` → `traits`

```json
"chatty": {
  "name": "Chatty",
  "blurb": "Drags whoever sits next to them off task.",
  "stall_mult": 1.0, "neighbour_stall_mult": 1.6, "help_bonus": 0.0
}
```

**The rule:** it must hook into the work model or the seating. A trait that
only prints a sentence is rejected. Existing six: Quiet (hides that they are
stuck), Curious (stalls more, gains more from help), Chatty (disrupts
neighbours), Steady (reliable), Copies (gets unstuck off a neighbour without
understanding), Bright spark (finishes early, helps the next desk).

### A day event — `scripts/data/events.gd` → `TABLE`

```json
{"id": "wet_play", "weight": 8, "name": "Wet play",
 "blurb": "Nobody went outside. They are fidgety but they are here.",
 "stall_mult": 1.3, "coin_mult": 1.2}
```

Optional effects: `stall_mult`, `lesson_mult`, `coin_mult`, `bonus_coins`,
`homework_sure`, `inspection`. `blurb` ≤ 55 chars. Weights total ~100.

### A staff archetype — `scripts/data/staff.gd` → `ARCHETYPES`

```json
{"id": "firm", "name": "Firm",
 "blurb": "Nothing gets out of hand. Slow to notice quiet trouble.",
 "reaction": 8.0, "teaches": true, "collects": true,
 "settles": true, "quizzes": false, "wage": 26}
```

`reaction` is seconds before they notice a child needs them (1 = very quick,
14 = barely). **The rule: a teacher is never strictly better than another,
only better AT something.** Every archetype needs a real hole in it, and the
`blurb` should name the strength and the hole in one line.

### A milestone — `scripts/data/milestones.gd` → `TABLE`

```json
{"id": "full_house", "name": "Every single one",
 "blurb": "A whole class passed. Not one of them left behind."}
```

**The rule:** it must name something a player would tell somebody else
about. "Taught 50 lessons" is a counter; "got every child through" is a
story. They pay nothing and gate nothing.

### A homework question — `scripts/data/questions.gd`

```json
{"q": "plural of leaf", "a": "leaves", "wrong": ["leafs", "leafes", "leave"]}
```

Four banks (`math`, `ela`, `science`, `social`), 12 each. `q` ≤ 40 chars.
The player never sees the answer key — they judge a sheet on how it *looks*
— so wrong answers must be **plausible**, not silly.

---

## What NOT to delegate

An outside model cannot run `Run Tests.bat` or `Simulate a Term.bat`, and
this project's entire discipline is "verified against a running game". So:

| Delegate | Do not delegate |
|---|---|
| Content in a schema (lessons, items, traits, events, staff, milestones, questions) | **Code.** It cannot be run, and a plausible-looking GDScript patch is worse than none. |
| Copywriting — blurbs, store text, tooltips | **Balance numbers.** They must be simulated, not reasoned about. |
| Design proposals in prose | **Anything touching the three-row contract.** |
| Naming, flavour, personality | **Refactors.** |

Bring content back as JSON and hand it to Claude Code with *"integrate this"*
— it will schema-check it, load it, run the suite and the simulator, and
reject anything that moves the contract.
