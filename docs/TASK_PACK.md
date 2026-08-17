# PixelRoom — task pack for Gemini / ChatGPT / Claude chat

**How to use.** Open a **new chat per task**. Attach the files listed under
that task. Paste the prompt verbatim. Save the reply. When you are back,
hand it to Claude Code and say **"integrate task N"** — every prompt asks
for a format that drops straight into a data file.

**Attach to every task:** `docs/BRIEFING.md` (the schemas and the rules).
Some tasks want `docs/GDD.md` as well; each says so.

Tasks are ordered by value. ⭐ marks the ones worth doing first.

---

## Task 1 — Twenty more lessons ⭐
**Attach:** `docs/BRIEFING.md`, `data/curriculum.json`

> You are writing curriculum content for PixelRoom (see the attached
> briefing and the existing curriculum file). There are 20 lessons today,
> 5 per strand. Write **20 more** — 5 each for `math`, `ela`, `science`,
> `social` — bringing each strand to 10.
>
> Requirements:
> - Follow the lesson schema in the briefing EXACTLY, including exactly
>   three concepts per lesson unlocking `at` 1, 3 and 6.
> - Spread `difficulty` 1–5 evenly across the twenty.
> - Do not duplicate any existing lesson `id`, `name` or `standard`.
> - **The citation rule is the important part.** Cite a real Common Core,
>   NGSS or Maryland Social Studies code ONLY where you are confident it
>   exists and says what you claim. Where you are not confident, set both
>   `standard` and `source` to `""` and list that lesson under an
>   "UNCITED" heading after the JSON so it can be registered deliberately.
>   A fabricated code is far worse than an empty one.
> - `short` ≤ 13 characters. `objective` should be the source document's
>   own wording wherever you are citing one.
>
> Output one JSON array of 20 lesson objects in a single code block, then
> the UNCITED list. No other commentary.

---

## Task 2 — Twenty-one more items of furniture ⭐
**Attach:** `docs/BRIEFING.md`

> Design **21 new items** for PixelRoom's classroom shop, taking it from 29
> to 50. Follow the item schema in the briefing exactly.
>
> - Spread across the five categories, weighted toward `learning` and
>   `decor` (currently thinnest at the top end).
> - Costs 30–400, and the cost/`bonus` ratio should stay roughly linear
>   with the existing items — no bargains, no traps.
> - At least 4 should `teach` a concept and at least 3 should `need` one.
>   Use only concept ids that exist in the attached curriculum.
> - `blurb` ≤ 60 characters, plain, says what the thing is FOR in a
>   classroom. Not jokes.
> - Also give each one a one-line **art brief** (what a 16×16 or 32×16
>   pixel sprite of it should show, in a 3/4 view, bottom row meeting the
>   floor) in a separate list after the JSON.
>
> Output one JSON object keyed by item id in a single code block, then the
> art briefs. No other commentary.

---

## Task 3 — Six more student traits ⭐
**Attach:** `docs/BRIEFING.md`

> Design **6 new student traits** for PixelRoom, taking it from 6 to 12.
>
> **The rule that matters:** a trait must change what the PLAYER DOES. It
> must hook into the work model (how often they stall, how much help is
> worth, whether their trouble is visible) or the seating (how they affect
> the child next to them). A trait that only prints a sentence on the class
> list is rejected — read the existing six in the briefing to see the bar.
>
> For each, give me: the JSON object, and one paragraph explaining **what
> the player has to do differently** because of it. If you cannot write
> that paragraph, the trait is decoration — replace it.
>
> Output the JSON in one code block, then the six paragraphs.

---

## Task 4 — The five year groups ⭐⭐ (design, not data)
**Attach:** `docs/GDD.md`, `docs/BRIEFING.md`

> PixelRoom is growing from one classroom into a school of up to six rooms,
> and each room will have a YEAR GROUP that changes how that room plays —
> not just its difficulty. An earlier design sketch called it "five games
> sharing a shell": nursery children play until an engagement bar fills;
> middle-school children work at shared tables where one stuck child blocks
> the group; sixth-formers hold a seminar where "your verb is asking, not
> helping".
>
> Write a design for **five year groups**. For each:
> - What the room LOOKS like and how it is laid out
> - What the child-level model is (what replaces "gets stuck")
> - **What the player's primary verb is** and how it differs from the
>   current "walk over and press E to unstick them"
> - What the failure state looks like
> - Which existing systems (quiz, homework, unit test, disruption, voice,
>   the assignment cards) apply, change, or do not apply
> - One paragraph on why a player would want to run this year group
>
> Constraints: it must stay desk-based and mouse-free, work at 320×176,
> and honour "walking the room is the game". Prose, not numbers.
>
> Output as Markdown. Be specific and opinionated; flag anything you think
> is a bad idea.

---

## Task 5 — Six more staff archetypes
**Attach:** `docs/BRIEFING.md`

> Design **6 new teacher archetypes** for PixelRoom's hiring pool, taking
> it from 6 to 12. Follow the staff schema in the briefing.
>
> **The rule:** a teacher is never strictly better than another, only
> better AT something. Every one needs a real hole. Cover ground the
> existing six do not — think about the teacher who is wonderful with a
> struggling class and wasted on a good one, the one who is cheap because
> nobody else will have them, the one whose strength only shows over a
> whole term.
>
> Wages should sit sensibly against the existing range (11–52/day) given
> what each is worth.
>
> Output the JSON array in one code block, then one line per archetype
> naming the class you would give them and the class you would not.

---

## Task 6 — Fifteen more milestones
**Attach:** `docs/BRIEFING.md`

> Write **15 new milestones** for PixelRoom, taking it from 15 to 30.
>
> **The rule:** a milestone names something a player would tell somebody
> else about. "Taught 50 lessons" is a counter; "got every child through"
> is a story. They pay nothing and gate nothing — the moment is the reward.
>
> Cover: the room, a career's length, teaching against the odds, the
> school layer (rooms, staff), and two or three that are quietly sad or
> funny rather than triumphant.
>
> For each, also state in one line **what game state would prove it** (e.g.
> "graduated.size() >= 50"), using only things named in the briefing.
>
> Output the JSON array in one code block, then the proof lines.

---

## Task 7 — Eleven more day events
**Attach:** `docs/BRIEFING.md`

> Design **11 new day events** for PixelRoom, taking it from 9 to 20.
> Follow the event schema in the briefing.
>
> They should feel like things that actually happen in a primary school —
> a fire drill, a heatwave, a visiting speaker, half the class off with a
> bug. Each must change a real number, not just print a line.
>
> Keep the weights totalling roughly 100 across all 20 (the existing nine
> are listed in the briefing) and keep "an ordinary day" the most common
> outcome by a wide margin.
>
> `blurb` ≤ 55 characters. Output the JSON array in one code block.

---

## Task 8 — The homework question banks
**Attach:** `docs/BRIEFING.md`

> PixelRoom's homework minigame shows a child's finished sheet and asks the
> player to judge it WITHOUT an answer key — you are guessing whether it
> looks right. There are four banks (math, ela, science, social) of 12
> questions each; I want **24 per bank**.
>
> Write 12 new questions per bank, in the schema in the briefing.
>
> The critical constraint: **the wrong answers must be plausible.** The
> player is skim-marking, so `7 x 8 = 54` is a good wrong answer and
> `7 x 8 = banana` is a useless one. Aim at what a real child would
> actually write. Questions ≤ 40 characters.
>
> Output one JSON object with four keys, each an array of 12, in a single
> code block.

---

## Task 9 — The Steam page
**Attach:** `docs/GDD.md`

> Write the store copy for PixelRoom's Steam page, from the attached
> design document.
>
> Give me: a one-line tagline (≤ 60 chars); a short description (≤ 300
> chars, the blurb under the trailer); a long description in 3–4 short
> paragraphs; five bullet features; and a list of six screenshots to take,
> each with a caption, in the order they should appear.
>
> Tone: this is a proper management sim about teaching, not a whimsical
> game about school. Quiet, confident, specific. No exclamation marks. Do
> not oversell — the honest pitch is stronger than the hyped one.
>
> Output as Markdown.

---

## Task 10 — The audio brief
**Attach:** `docs/GDD.md`

> PixelRoom has 11 procedurally-generated sound effects and no music. It
> needs a score and room ambience for release.
>
> Write a brief for a composer/sound designer:
> - The feel, in one paragraph, grounded in what the game actually is
> - A list of ambience layers and what triggers each (the game has states:
>   morning, lesson, a silent test, a noisy room, afternoon, the exam)
> - A list of music cues with length and mood
> - A list of any NEW sound effects the recent systems need — the game now
>   has a card hand, a quiz, a unit test, a voice/shout, build mode, a
>   school board and hiring
> - Reference tracks (name real, findable pieces)
>
> Output as Markdown.

---

## Task 11 — Names
**Attach:** `docs/BRIEFING.md`

> PixelRoom's children are given names from a pool of 48 first names and 32
> surnames. Expand to **96 first names and 64 surnames**.
>
> They should read as a real British primary-school register: a broad mix
> of origins, no joke names, no fantasy names, nothing that would be unkind
> to a child who shares it. First names ≤ 8 characters (they sit in a
> column). Do not duplicate the existing ones (attached briefing has the
> current lists' size; assume common names are already used and lean
> slightly less common).
>
> Output two JSON arrays of strings in a single code block.

---

## When you are back

Hand the file or the pasted text to Claude Code:

> **"integrate task 3"**

It will schema-check it, load it into the game, run `Run Tests.bat` and
`Simulate a Term.bat`, screenshot anything visual, and reject anything that
moves the balance contract. Content that fails the rules comes back to you
with the reason rather than being quietly patched to fit.
