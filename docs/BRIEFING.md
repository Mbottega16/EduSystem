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

A pixel-art classroom management sim in Godot 4.7, 640×352 (doubled from
320×176 in Aug 2026 for more detail per tile — same 20×11 room), mouse-free.

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

Currently 40 lessons, 10 per strand, 120 concepts. Six are deliberately
uncited (`standard` and `source` both empty) — five of them social
studies, because the Maryland Framework numbers by strand rather than by
topic. That is allowed and named in the suite; a fabricated code is not.

#### What already exists — do not collide with any of it

**Lesson ids** (40). `algebra_one` `basic_arithmetic` `cell_function`
`chemistry` `civics` `community_roles` `comparing_genres` `constitution`
`decimals` `division` `earth_life_science` `earth_systems` `ecosystems`
`economics` `essay_writing` `fractions` `handwriting_grammar`
`industrialisation` `informational_text` `inherited_traits` `life_cycles`
`map_geography` `material_properties` `measuring_length`
`opinion_writing` `phonics` `place_value` `pre-algebra` `reading_fluency`
`retelling` `science_basics` `shapes` `speaking_listening` `state_symbols`
`statistics` `transport_history` `using_sources` `vocabulary`
`weather_patterns` `world_history`

**Standard codes in use** (34). `1.MD.A.1` `2-PS1-2` `3-LS1-1` `3-LS3-2`
`3.NBT.A.2` `3.OA.A.2` `3.OA.C.7` `4.NF.A.1` `5-ESS2-1` `5-PS1-3`
`5.NBT.A.3` `6.SP.A.1` `7.EE.B.4` `A-REI.B.3` `K-ESS2-1` `K.G.A.1`
`L.3.1` `L.4.4` `MS-LS1-1` `MS-LS1-2` `MS-LS2-3` `MS-PS1-2` `RF.K.3`
`RF4` `RI.3.1` `RL.1.2` `RL.6.9` `SL.8.4` `Standard 1.0` `Standard 2.0`
`Standard 3.0` `Standard 4.0` `W.4.1` `W.7.1`

**The four source strings**, used verbatim — `Maryland CCR Standards for
Mathematics (2025)`, `Maryland CCR Standards for ELA (2025)`,
`Maryland Science Standards (NGSS)`,
`Maryland Social Studies Framework (June 2025)`.

### An item — `data/balance.json` → `items`

```json
"microscope": {
  "name": "Microscope", "art": "microscope", "cost": 280,
  "range": 3, "bonus": 0.13, "w": 1, "cat": "learning",
  "blurb": "The first time a child sees a cell is worth the price.",
  "teaches": "earth_life_science.cells"
}
```

*(Copied verbatim from `data/balance.json`. If you change this example,
copy the new one from the file — a worked example with invented numbers
once produced 22 items at half the correct strength.)*

- `cat` is one of `seating` `surfaces` `learning` `comfort` `decor`.
- `range` in tiles (2–6), `bonus` is what it adds to a desk's grade floor
  (0.02–0.15).
- `w` is width in tiles (1 or 2). `flat: true` for wall/floor items that
  cast no shadow — a clock, a banner, a rug. Omit it otherwise.
- Optional `teaches` (a concept id it unlocks outright) or `needs` (a
  concept id that must be known before it is on sale).
- `blurb` ≤ 60 characters. See the voice rule below.
- Currently 50 items.
- *(Aug 2026)* The shop also sells 4 **consumables** — `cat: "consumable"`,
  no `range`/`bonus`, an `effect` dict instead (the same hook vocabulary
  day events use: `stall_mult`, `lesson_mult`, `coin_mult`, `bonus_coins`,
  `homework_sure`), bought and spent the same day rather than placed. A
  different schema, not covered by the density rule below or by this
  task's prompt — do not generate one of these by extrapolating from the
  furniture rules.

**The two balance rules, both derived from the real 29:**

1. **Value density.** `cost ÷ (bonus × range)` lands between **360 and
   840** for every one of the 29 existing items — the real spread is
   367 (`wall_clock`) to 833 (`bench`). Anything outside that is a trap
   or a bargain.
2. **Reach trades against strength.** High bonus means short range; wide
   range means weak bonus. `lab_bench` is 0.15 at range 3; `rug` is 0.07
   at range 6. Never scale bonus *and* range together with cost — that
   deletes the decision and makes expensive items strictly better.

**The blurb voice.** Dry, British, observational — a teacher's aside, not
a supplier's catalogue. Real ones: *"Half of them work."* (pot of pens),
*"Nobody sits up straight in one, and that is fine."* (beanbag),
*"Everything has a place, in theory."* (cabinet), *"They will use any
excuse to visit it."* (water cooler). A blurb that merely restates the
name adds nothing a player cannot read off the label.

### A trait — `data/balance.json` → `traits`

```json
"chatty": {
  "name": "Chatty",
  "blurb": "Talks to whoever is sitting next to them.",
  "neighbour_stall_mult": 1.5
}
```

*(Copied verbatim from `data/balance.json`.)* A trait carries **only the
hooks it actually uses** — it does not list the others at neutral values.

**These six hooks are the complete set the engine reads.** Anything else
is silently ignored, so a trait built on an invented field is decoration
that looks like mechanics:

| Hook | Type | Effect |
|---|---|---|
| `stall_mult` | float | Multiplies how often *they* get stuck. |
| `neighbour_stall_mult` | float | Multiplies how often the children **either side of them** get stuck. |
| `hide_seconds` | float | Seconds their stuck state stays invisible to the player. |
| `help_xp_mult` | float | Multiplies the XP they give when you help them. |
| `copy_from_neighbour` | bool | They get unstuck off a neighbour, without understanding it. |
| `helps_neighbour` | float | They lift the child next to them by this much. |

**The rule:** it must hook into the work model or the seating. A trait that
only prints a sentence is rejected. The existing six, and the hook each
one uses: Quiet (`hide_seconds` 6.0), Curious (`stall_mult` 1.35 +
`help_xp_mult` 2.0), Chatty (`neighbour_stall_mult` 1.5), Steady
(`stall_mult` 0.7), Copies (`copy_from_neighbour`), Bright spark
(`helps_neighbour` 0.35).

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
