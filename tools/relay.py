#!/usr/bin/env python3
"""The Claude <-> Gemini relay. See docs/relay/PROTOCOL.md for the rules.

    python tools/relay.py status
    python tools/relay.py read [--last N] [--since-mine] [--agent NAME]
    python tools/relay.py template > my_turn.md
    python tools/relay.py post --agent claude --file my_turn.md
    python tools/relay.py claim --agent claude scripts/ui/hud.gd ...
    python tools/relay.py release --agent claude [paths ...]
    python tools/relay.py check --file my_turn.md

WHY A TOOL AND NOT JUST A SHARED MARKDOWN FILE: two agents appending to one
file is the exact race the relay exists to prevent, and a turn nobody
validated is a turn with three of its eight sections missing. Everything
here is a guard rail that failed in some other project first:

  - post() refuses when it is not your turn, so "I thought it was my go"
    stops being possible.
  - post() refuses a turn missing a required section, because the sections
    ARE the protocol -- WHAT YOU GOT WRONG without evidence is how one agent
    sends the other after a bug that was never there.
  - claim() refuses a path another agent already holds, and says which one,
    BEFORE the work happens rather than after both have edited it.
  - Every turn is its own file, numbered. Nothing is ever appended to, so
    two writes can never interleave into one corrupted document.

Standard library only, like every other tool in tools/. No install step: an
agent that has to be told to pip install something will skip the protocol.
"""
import argparse
import datetime
import json
import os
import re
import sys

# Turn files are UTF-8 and the protocol's own prose uses em dashes. A
# Windows console defaults to cp1252 and would either mangle them or raise
# UnicodeEncodeError mid-read, which reads as the relay being broken.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RELAY = os.path.join(ROOT, "docs", "relay")
TURNS = os.path.join(RELAY, "turns")
STATE = os.path.join(RELAY, "STATE.json")

AGENTS = ("claude", "gemini")

# The turn format, from PROTOCOL.md. Order matters: post() reports the first
# one missing, and reading them in order is reading the argument in order.
SECTIONS = [
    "DID",
    "EVIDENCE",
    "PLAN",
    "NEED FROM YOU",
    "CAN GIVE YOU",
    "YOU GOT RIGHT",
    "YOU GOT WRONG",
    "QUESTIONS",
    "CLAIMING",
]

# Phrases that mean "I did not check this". Allowed everywhere except the
# section that sends the other agent digging.
HEDGES = ("looks like", "seems to", "i think", "probably", "might be",
          "appears to", "i believe", "presumably", "possibly")

DEFAULT_STATE = {
    "_note": "Whose turn it is, and who holds which files. Written by "
             "tools/relay.py -- edit by hand only to break a deadlock, and "
             "say so in your next turn. Rules: docs/relay/PROTOCOL.md",
    "turn": "claude",
    "round": 0,
    "interval_minutes": 20,
    "due_at": None,
    "claims": {"claude": [], "gemini": []},
}


# --------------------------------------------------------------- state

def now():
    return datetime.datetime.now().replace(microsecond=0)


def load_state():
    if not os.path.exists(STATE):
        return dict(DEFAULT_STATE)
    with open(STATE, encoding="utf-8") as f:
        d = json.load(f)
    for k, v in DEFAULT_STATE.items():
        d.setdefault(k, v)
    for a in AGENTS:
        d["claims"].setdefault(a, [])
    return d


def save_state(d):
    os.makedirs(RELAY, exist_ok=True)
    with open(STATE, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2)
        f.write("\n")


def other(agent):
    return AGENTS[1] if agent == AGENTS[0] else AGENTS[0]


def check_agent(agent):
    if agent not in AGENTS:
        sys.exit("unknown agent %r -- expected one of %s"
                 % (agent, " ".join(AGENTS)))
    return agent


# --------------------------------------------------------------- turns

def turn_files():
    if not os.path.isdir(TURNS):
        return []
    return sorted(f for f in os.listdir(TURNS) if f.endswith(".md"))


def next_number():
    files = turn_files()
    if not files:
        return 1
    return max(int(f.split("-", 1)[0]) for f in files) + 1


def parse_sections(text):
    """Every '## NAME' heading in the file, mapped to its body."""
    out = {}
    current = None
    for line in text.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            current = m.group(1).strip().upper()
            out[current] = []
        elif current is not None:
            out[current].append(line)
    return {k: "\n".join(v).strip() for k, v in out.items()}


def validate(text):
    """Everything wrong with a turn file, as a list of complaints."""
    problems = []
    found = parse_sections(text)
    for name in SECTIONS:
        if name not in found:
            problems.append("missing section: ## %s" % name)
        elif not found[name]:
            problems.append("empty section: ## %s  (write '- none' if that "
                            "is the answer)" % name)

    # The rule PROTOCOL.md calls the most dangerous section in the file: an
    # accusation with no evidence costs the other agent a whole round.
    wrong = found.get("YOU GOT WRONG", "")
    if wrong and wrong.strip().lower() not in ("- none", "none", "-none"):
        if not re.search(r"[\w/\\]+\.(gd|py|json|tscn|md|bat|txt)", wrong):
            problems.append(
                "## YOU GOT WRONG names no file. Name the file and the "
                "command that shows it, or move it to ## QUESTIONS.")
        low = wrong.lower()
        hedged = [h for h in HEDGES if h in low]
        if hedged:
            problems.append(
                "## YOU GOT WRONG hedges (%s). A thing you are not sure of "
                "is a QUESTION, not a finding." % ", ".join(hedged))
    return problems


TEMPLATE = """---
from: {agent}
round: {round}
at: {at}
---

## DID
- none

## EVIDENCE
- none

## PLAN
-

## NEED FROM YOU
- none

## CAN GIVE YOU
- none

## YOU GOT RIGHT
- none

## YOU GOT WRONG
- none

## QUESTIONS
- none

## CLAIMING
- none
"""


# ------------------------------------------------------------ commands

def cmd_status(args):
    d = load_state()
    print("round      : %d" % d["round"])
    print("turn       : %s" % d["turn"])
    due = d.get("due_at")
    if due:
        try:
            when = datetime.datetime.fromisoformat(due)
            late = (now() - when).total_seconds() / 60.0
            if late > 0:
                print("due        : %s  OVERDUE by %d min -- %s may take the "
                      "turn over (see PROTOCOL.md, The clock)"
                      % (due, int(late), other(d["turn"])))
            else:
                print("due        : %s  (%d min left)" % (due, int(-late)))
        except ValueError:
            print("due        : %s  (unparseable)" % due)
    else:
        print("due        : -")
    print("interval   : %d min" % d["interval_minutes"])
    for a in AGENTS:
        held = d["claims"].get(a, [])
        print("%-10s : %s" % ("holds " + a, ", ".join(held) if held else "-"))
    files = turn_files()
    print("turns      : %d  (%s)" % (len(files), files[-1] if files else "none yet"))
    return 0


def cmd_read(args):
    files = turn_files()
    if args.since_mine and args.agent:
        # Everything the OTHER side has said since my last turn -- the normal
        # way to start a round without re-reading the whole history.
        mine = [f for f in files if f.endswith("-%s.md" % args.agent)]
        if mine:
            files = [f for f in files if f > mine[-1]]
    if args.agent and not args.since_mine:
        files = [f for f in files if f.endswith("-%s.md" % args.agent)]
    if args.last:
        files = files[-args.last:]
    if not files:
        print("(nothing to read)")
        return 0
    for f in files:
        print("=" * 70)
        print(f)
        print("=" * 70)
        with open(os.path.join(TURNS, f), encoding="utf-8") as fh:
            print(fh.read().rstrip())
        print()
    return 0


def cmd_template(args):
    d = load_state()
    sys.stdout.write(TEMPLATE.format(
        agent=args.agent or d["turn"], round=d["round"] + 1,
        at=now().isoformat()))
    return 0


def cmd_check(args):
    with open(args.file, encoding="utf-8") as f:
        problems = validate(f.read())
    if not problems:
        print("turn is well formed -- all %d sections present" % len(SECTIONS))
        return 0
    for p in problems:
        print("  " + p)
    return 1


def cmd_post(args):
    agent = check_agent(args.agent)
    d = load_state()

    if d["turn"] != agent and not args.force:
        due = d.get("due_at")
        overdue = False
        if due:
            try:
                overdue = now() > datetime.datetime.fromisoformat(due)
            except ValueError:
                pass
        hint = ("  It is overdue, so you MAY take it over: re-run with "
                "--force and say so in your DID section."
                if overdue else
                "  Wait, or run status to see when it falls due.")
        sys.exit("it is %s's turn, not yours.%s" % (d["turn"], hint))

    with open(args.file, encoding="utf-8") as f:
        text = f.read()
    problems = validate(text)
    if problems and not args.force:
        print("this turn is not well formed:")
        for p in problems:
            print("  " + p)
        sys.exit("nothing posted. Fix it, or --force if you truly mean it.")

    os.makedirs(TURNS, exist_ok=True)
    n = next_number()
    name = "%04d-%s.md" % (n, agent)
    # The header the tool owns, so `round` and `at` cannot disagree with
    # STATE.json however the body was written.
    body = re.sub(r"\A---\n.*?\n---\n", "", text, count=1, flags=re.S)
    header = "---\nfrom: %s\nround: %d\nat: %s\n---\n\n" % (
        agent, d["round"] + 1, now().isoformat())
    with open(os.path.join(TURNS, name), "w", encoding="utf-8") as f:
        f.write(header + body.lstrip())

    d["round"] += 1
    d["turn"] = other(agent)
    d["due_at"] = (now() + datetime.timedelta(
        minutes=d["interval_minutes"])).isoformat()
    save_state(d)
    print("posted docs/relay/turns/%s" % name)
    print("it is now %s's turn, due %s" % (d["turn"], d["due_at"]))
    return 0


def _overlaps(a, b):
    """Whether two claimed paths collide -- either is inside the other."""
    a = a.replace("\\", "/").strip("/")
    b = b.replace("\\", "/").strip("/")
    return a == b or a.startswith(b + "/") or b.startswith(a + "/")


def cmd_claim(args):
    agent = check_agent(args.agent)
    d = load_state()
    theirs = d["claims"][other(agent)]
    clashes = [(p, q) for p in args.paths for q in theirs if _overlaps(p, q)]
    if clashes and not args.force:
        for p, q in clashes:
            print("  %s collides with %s's claim on %s" % (p, other(agent), q))
        sys.exit("nothing claimed. Ask them to release it, or work elsewhere.")
    mine = d["claims"][agent]
    for p in args.paths:
        if p not in mine:
            mine.append(p)
    mine.sort()
    save_state(d)
    print("%s now holds: %s" % (agent, ", ".join(mine) if mine else "-"))
    return 0


def cmd_release(args):
    agent = check_agent(args.agent)
    d = load_state()
    if args.paths:
        d["claims"][agent] = [p for p in d["claims"][agent]
                              if p not in args.paths]
    else:
        d["claims"][agent] = []
    save_state(d)
    held = d["claims"][agent]
    print("%s now holds: %s" % (agent, ", ".join(held) if held else "-"))
    return 0


def cmd_init(args):
    os.makedirs(TURNS, exist_ok=True)
    if os.path.exists(STATE) and not args.force:
        sys.exit("docs/relay/STATE.json already exists -- --force to reset it")
    save_state(dict(DEFAULT_STATE))
    print("relay ready. First turn belongs to %s." % DEFAULT_STATE["turn"])
    return 0


def main(argv):
    ap = argparse.ArgumentParser(
        description="The Claude <-> Gemini relay (docs/relay/PROTOCOL.md)")
    sub = ap.add_subparsers(dest="cmd")

    sub.add_parser("status").set_defaults(fn=cmd_status)

    p = sub.add_parser("read")
    p.add_argument("--last", type=int, default=0)
    p.add_argument("--agent")
    p.add_argument("--since-mine", action="store_true")
    p.set_defaults(fn=cmd_read)

    p = sub.add_parser("template")
    p.add_argument("--agent")
    p.set_defaults(fn=cmd_template)

    p = sub.add_parser("check")
    p.add_argument("--file", required=True)
    p.set_defaults(fn=cmd_check)

    p = sub.add_parser("post")
    p.add_argument("--agent", required=True)
    p.add_argument("--file", required=True)
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_post)

    p = sub.add_parser("claim")
    p.add_argument("--agent", required=True)
    p.add_argument("paths", nargs="+")
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_claim)

    p = sub.add_parser("release")
    p.add_argument("--agent", required=True)
    p.add_argument("paths", nargs="*")
    p.set_defaults(fn=cmd_release)

    p = sub.add_parser("init")
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_init)

    args = ap.parse_args(argv)
    if not getattr(args, "fn", None):
        ap.print_help()
        return 1
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
