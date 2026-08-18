#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Validate a task-3 trait submission BEFORE it touches balance.json.

    python tools/check_traits.py submission.json

A trait may use ONLY the hooks the engine actually reads (see
scripts/data/student_data.gd and scripts/autoload/game.gd). A field
outside that list is silently ignored at runtime -- it looks like
mechanics in the file and behaves like decoration in the game, which is
exactly the failure mode the design rule exists to prevent.
"""
import json
import re
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WANT = 6

# The complete set the engine reads, and the reasonable range for each --
# taken from the existing six, which run 0.35 to 2.0 on the multipliers
# and 5.0-6.0 on hide_seconds.
HOOKS = {
    "stall_mult": (float, 0.4, 2.0),
    "neighbour_stall_mult": (float, 0.4, 2.0),
    "hide_seconds": (float, 1.0, 10.0),
    "help_xp_mult": (float, 0.2, 3.0),
    "copy_from_neighbour": (bool, None, None),
    "helps_neighbour": (float, 0.1, 0.6),
}


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def main(path):
    bal = load(os.path.join("data", "balance.json"))
    have = {k: v for k, v in bal["traits"].items() if not k.startswith("_")}

    raw = open(path, encoding="utf-8").read()
    m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw, re.S)
    new = json.loads(m.group(1) if m else raw)

    bad = []
    warn = []

    if len(new) != WANT:
        bad.append("expected exactly %d traits, got %d" % (WANT, len(new)))

    have_names = {v["name"].lower() for v in have.values()}

    for tid, v in new.items():
        def fail(msg):
            bad.append("%s: %s" % (tid, msg))

        if tid in have:
            fail("id already exists")
        if "name" not in v or not v["name"]:
            fail("missing name")
        elif v["name"].lower() in have_names:
            fail("name %r collides with an existing trait" % v["name"])
        if "blurb" not in v or not v["blurb"]:
            fail("missing blurb")
        else:
            b = v["blurb"]
            if len(b) > 60:
                fail("blurb is %d chars, over the ~60 the class list allows"
                     % len(b))
            if re.search(r"\d", b):
                fail("blurb contains a number: %r" % b)
            if "!" in b:
                fail("blurb contains an exclamation mark")

        hooks_used = [k for k in v if k not in ("name", "blurb")]
        if not hooks_used:
            fail("carries no mechanical hook -- decoration, not a trait")
        for k in hooks_used:
            if k not in HOOKS:
                fail("%r is not a real hook. The complete set is: %s"
                     % (k, sorted(HOOKS)))
                continue
            kind, lo, hi = HOOKS[k]
            val = v[k]
            if kind is bool:
                if val is not True:
                    fail("%s must be true (or omitted), got %r" % (k, val))
            else:
                if not isinstance(val, (int, float)) or isinstance(val, bool):
                    fail("%s must be a number, got %r" % (k, val))
                elif not lo <= val <= hi:
                    fail("%s = %s is outside the sane range %s-%s "
                         "(the existing six run within it)" % (k, val, lo, hi))

        # THE DESIGN RULE: it must change what the player DOES, not just
        # what a child's stats are. A trait that is a single multiplier
        # with no directional consequence (nothing to route round, nothing
        # to notice) is exactly the EduSystems failure mode recorded in
        # docs/SALVAGE.md -- flagged for a human, not auto-rejected.
        if len(hooks_used) == 1 and hooks_used[0] in (
                "stall_mult", "help_xp_mult"):
            warn.append("%s: a single %s is close to the EduSystems "
                        "calibration set (spd + a category tag, nothing "
                        "the player could act on) -- read the blurb and "
                        "ask what you would do differently for this child"
                        % (tid, hooks_used[0]))

    print("traits: %d" % len(new))
    if warn:
        print("\nWARNINGS (judgement, not automatic rejection): %d" % len(warn))
        for w in warn:
            print("  ? " + w)
    if bad:
        print("\nREJECTED: %d problem(s)\n" % len(bad))
        for b in bad:
            print("  - " + b)
        return 1
    print("\nall automatic rules pass -- still read the blurbs yourself")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
