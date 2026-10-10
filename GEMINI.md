# Gemini — start here

You are working on **EDUSystem**, a Godot 4.7 pixel-art classroom management
sim. **You are not working alone.** Claude Code works this same folder, and
the two of you coordinate through a file-based relay.

## Read these, in this order

1. **`AGENTS.md`** — the project's rules. Determinism, where numbers live,
   the balance contract, the panel budget, how to verify a change. It is
   long and it is not optional; every constraint in it was paid for.
2. **`docs/relay/PROTOCOL.md`** — how you and Claude take turns, claim files,
   and tell each other things without wasting each other's rounds.
3. **`docs/relay/turns/`** — what has been said so far. Start with the most
   recent, or run the command below.

## Your loop

```
python tools/relay.py status                      whose turn is it?
python tools/relay.py read --agent gemini --since-mine   what did Claude say?
                                                  ...do the work...
python tools/relay.py claim --agent gemini <paths>   before you edit
python tools/relay.py template --agent gemini > turn.md
                                                  ...fill every section...
python tools/relay.py check --file turn.md        does it pass?
python tools/relay.py post --agent gemini --file turn.md
```

`Relay.bat` at the project root does `status` + the unread turns in one
double-click, if you would rather see it that way.

## The four things that will bite you

**Post only on your turn.** `status` says whose it is. If `post` refuses,
that is the protocol working. `--force` exists only for a genuinely overdue
turn, and using it obliges you to say so in your `DID` section.

**Claim before you edit.** Not after. The claim is checked against Claude's
claims and refuses on overlap, naming the file. That refusal is the entire
value of the mechanism — it happens *before* two agents have edited one file
rather than after.

**Do not accuse without evidence.** `## YOU GOT WRONG` is validated: it must
name a file and must not hedge. A wrong finding costs the other agent a whole
round chasing a bug that was never there. If you are not certain, it goes in
`## QUESTIONS` as a question. This is the single most important rule here.

**Art you write is not art the game can load.** `make_art.py`,
`forge_art.py` and Browse Art write PNGs but do not import them. Run
`godot --headless --path . --import` (or `Reimport Art.bat`) afterwards, or
the game cannot load what you just made — and every file-exists check will
still pass.

## What you are good at here

From `docs/relay/PROTOCOL.md`, the split that makes two agents worth more
than one: **you generate faster, Claude verifies harder.** Self-contained
generative work is yours — a new sprite generator, a `forge_*` script, a data
table, an art batch, a bounded refactor inside a file you hold. Cross-cutting
changes that must reason about the balance contract or the project's written
rules are Claude's. Anything that would *change* the balance contract, the
save format, or a hard constraint in `AGENTS.md` belongs to the human: say so
in `NEED FROM YOU` and stop rather than deciding it yourself.

## Verifying, always

```
Run Tests.bat            2595 assertions — read the COUNT, not the word PASSED
Simulate a Term.bat      the three contract rows must still hold
Play a Whole Term.bat    prints WALKTHROUGH PASSED / FAILED and exits on it
python tools/check_docs.py
python tools/check_balance.py
Take a Screenshot.bat [screen]     headless never proves anything is on screen
```

Put what those printed in your `## EVIDENCE` section. "It looks right" is not
evidence, and this project has been burned three times by a suite that said
PASSED with a silently lower count.
