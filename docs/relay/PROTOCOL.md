# The relay — how Claude and Gemini work this repo without fighting

Two agents work on EDUSystem: **Claude** (Claude Code, in a terminal on this
folder) and **Gemini** (Antigravity, in the same folder). Both can edit every
file. Neither can see the other's context. Left alone, that produces the
three failures this protocol exists to prevent:

1. **Conflation.** Both edit `hud.gd` in the same twenty minutes. The second
   save wins, silently, and a day's work is gone with no conflict marker
   because neither was using git as a boundary.
2. **Duplicated work.** Both independently decide the shop needs a scrollbar.
   Two scrollbars, two styles, two sets of tests, one of them deleted later.
3. **Confident nonsense about each other.** One reports "Gemini broke the
   walkthrough" without having run it, the other spends an hour looking for
   a break that was never there.

The fix is not more chat. It is **turns, claims, and evidence**.

---

## The three rules

### 1. One writer at a time, and it is written down

`docs/relay/STATE.json` holds `turn` — `"claude"` or `"gemini"`. **If it is
not your turn, you do not post.** You may read, you may run the verification
tools, you may think. You do not write a turn file and you do not start
editing files you have not claimed.

A turn ends when you post. Posting flips `turn` to the other agent and
stamps `due_at` — the time by which they should have answered.

### 2. You claim the files you are about to touch

`relay.py claim "scripts/ui/hud.gd" "scenes/ui/hud.tscn"` records that those
paths are yours. A claim by the other agent that overlaps yours is refused
by the tool, with the overlapping path named. Claims live in
`docs/relay/STATE.json` under `claims` and are released with
`relay.py release`.

**A claim is a promise, not a lock.** Nothing at the filesystem level stops
either agent editing a claimed file. What the claim buys is that the
*overlap is visible before the work happens* rather than after, and that
"who was meant to be in that file" has an answer that is not a memory.

Claim narrowly. `scripts/` is not a claim, it is a land grab.

### 3. Every claim about the other agent cites evidence

The turn format has a **WHAT YOU GOT WRONG** section, and it is the most
dangerous section in this file. It is where a plausible-sounding hallucination
becomes the other agent's afternoon. So:

> **A "got wrong" entry that does not name the file, the line or symbol, and
> the command whose output shows it, does not go in that section.** Put it in
> QUESTIONS instead, phrased as a question.

`Run Tests.bat` printing `2117 assertions` is evidence. "The tests looked
like they were failing" is not. This repo's own `CLAUDE.md` opens with *verify
by looking at the running game, not by reading the code* — the same rule
applies to verifying each other.

The mirror of that rule: **WHAT YOU GOT RIGHT is not optional politeness.**
It is how the other agent learns which of its guesses about this codebase
were correct, and it is the only positive signal in the loop. Name the
specific decision, not "good work".

---

## The turn file

`relay.py post` opens (or takes `--file`) a turn written to
`docs/relay/turns/NNNN-<agent>.md`. Every section is required; an empty
section says `- none` rather than being deleted, because a missing section
reads as an oversight and `- none` reads as an answer.

```markdown
---
from: claude
round: 7
at: 2026-09-06T21:40:00
---

## DID
What I actually changed this round, as paths. Not intentions.

## EVIDENCE
The commands I ran and what they printed. Assertion COUNT, not the word
PASSED. If I changed nothing verifiable, say so.

## PLAN
What I intend to do next round, specifically enough that you could tell me
it is a bad idea before I spend the round on it.

## NEED FROM YOU
Concrete asks. A decision, a file, an answer, a piece of work. If I need
nothing, "- none" — do not invent an ask to fill the section.

## CAN GIVE YOU
What I have that would save you time: a tool I just built, a fact I
established, a file I am done with and am releasing.

## YOU GOT RIGHT
Specific decisions of yours I checked and agree with. Name them.

## YOU GOT WRONG
Only with file + symbol + the command that shows it. Otherwise it goes in
QUESTIONS.

## QUESTIONS
Things I suspect but cannot show. Phrased as questions, never as findings.

## CLAIMING
The paths I am taking for the next round, and the ones I am releasing.
```

---

## Delegating intelligently

Neither agent is better at everything, and the point of two is not two of
the same. Split by **what the work needs**, not by who is free:

| Give it to | When the work is |
|---|---|
| **Claude** | Long-context and cross-cutting: a change that touches `game.gd`, the HUD and the suite at once; anything that must reason about the balance contract; anything where the project's own written rules (the panel budget, the citation rule, prose-not-numbers) decide the answer. |
| **Gemini** | Self-contained and generative: a new sprite generator, a new `forge_*` script, a data table, a batch of art, a bounded refactor inside one file it holds a claim on. |
| **Whoever holds the claim** | Anything inside a file already claimed. Do not hand work into another agent's claim; ask them to do it, or ask them to release. |
| **Neither, yet** | Anything that changes the balance contract, the save format, or a hard constraint in `CLAUDE.md`. Those go to the human. Say so in NEED FROM YOU and stop. |

The asymmetry worth remembering: **Gemini generates faster, Claude verifies
harder.** A good round is often Gemini producing three candidate item tables
and Claude running `check_items.py` over them and saying which one survives.
A bad round is both writing the same table.

---

## The clock

The loop is time-based so it does not depend on a human remembering to poke
it. `STATE.json` carries:

- `interval_minutes` — how long a turn may take before it is overdue.
- `due_at` — when the current turn became due. Set on every post.

`relay.py status` prints whether the current turn is overdue and by how much.
An **overdue turn may be taken over**: the waiting agent posts a turn with
`- none` in DID, saying it is proceeding, and takes the turn back. That is
the deadlock-breaker, and it is why the interval exists at all.

Driving it:

- **Claude:** `/loop 20m relay` — wakes on the interval, runs
  `python tools/relay.py read --since-mine`, works, posts.
- **Gemini (Antigravity):** the same loop by hand or on a timer, starting from
  `GEMINI.md` at the repo root, which points here.

Neither side should poll faster than the interval. A relay that posts every
two minutes is a chat, and a chat is the thing this replaces.

---

## What the relay is not

- **Not a place to design.** Design lives in `docs/GDD.md`. A turn file
  points at a doc; it does not become one.
- **Not a substitute for git.** Commit your own work in your own round. The
  relay records intent and findings; git records code.
- **Not a source of truth about the code.** A turn file is what one agent
  believed at one moment. `tests/run.gd`, `data/balance.json` and the running
  game are the truth. If a turn file and the repo disagree, the repo wins and
  the next turn says so.
