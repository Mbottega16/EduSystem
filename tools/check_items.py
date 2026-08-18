#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Validate a task-2 furniture submission BEFORE it touches balance.json.

    python tools/check_items.py submission.json

Every rule here is one the prompt in docs/TASK_PACK.md states outright,
and most of them exist because a submission broke them:

  - a whole 22-item batch came back at half the correct strength, because
    a stale worked example in the briefing said the microscope was
    bonus 0.05 when it is 0.13
  - one attempt computed the density window correctly, printed five
    failing values, and submitted all five anyway
  - counts of 22 and 20 have both been returned for "exactly 21"
  - concept links were lifted from the briefing's EXAMPLES rather than
    the curriculum, giving a globe that requires fraction models

Nothing is patched to fit. A submission that fails comes back with the
reason.
"""
import json
import re
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATS = {"seating", "surfaces", "learning", "comfort", "decor"}
LO, HI = 360, 840
WANT = 21


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def main(path):
    bal = load(os.path.join("data", "balance.json"))
    cur = load(os.path.join("data", "curriculum.json"))
    have = {k: v for k, v in bal["items"].items() if not k.startswith("_")}
    concepts = {c["id"] for l in cur["lessons"] for c in l["concepts"]}
    taught = {v["teaches"] for v in have.values() if "teaches" in v}

    raw = open(path, encoding="utf-8").read()
    # tolerate a fenced code block pasted straight out of a chat
    m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw, re.S)
    new = json.loads(m.group(1) if m else raw)

    bad = []
    warn = []

    if len(new) != WANT:
        bad.append("expected exactly %d items, got %d" % (WANT, len(new)))

    cats = {}
    lessons_touched = {}
    teaches = needs = 0

    for iid, v in new.items():
        def fail(msg):
            bad.append("%s: %s" % (iid, msg))

        if iid in have:
            fail("id already exists")
        for key in ("name", "art", "cost", "range", "bonus", "w", "cat", "blurb"):
            if key not in v:
                fail("missing %r" % key)
        if bad and any(iid in b for b in bad[-8:]):
            pass
        if v.get("art") != iid:
            fail("art %r should equal the id" % v.get("art"))
        if v.get("cat") not in CATS:
            fail("cat %r is not one of %s" % (v.get("cat"), sorted(CATS)))
        cats[v.get("cat")] = cats.get(v.get("cat"), 0) + 1
        if v.get("w") not in (1, 2):
            fail("w must be 1 or 2, got %r" % v.get("w"))
        if not 30 <= v.get("cost", 0) <= 400:
            fail("cost %s outside 30-400" % v.get("cost"))
        if not 2 <= v.get("range", 0) <= 6:
            fail("range %s outside 2-6" % v.get("range"))
        if not 0.02 <= v.get("bonus", 0) <= 0.15:
            fail("bonus %s outside 0.02-0.15" % v.get("bonus"))
        if "flat" in v and v["flat"] is not True:
            fail("flat must be true or omitted entirely")

        # RULE 1 - value density
        try:
            d = v["cost"] / (v["bonus"] * v["range"])
            if not LO <= d <= HI:
                fail("value density %.0f outside %d-%d  (%s / (%s x %s))"
                     % (d, LO, HI, v["cost"], v["bonus"], v["range"]))
        except (KeyError, ZeroDivisionError, TypeError):
            fail("cannot compute value density")

        # the blurb
        b = v.get("blurb", "")
        if len(b) > 60:
            fail("blurb is %d chars, max 60" % len(b))
        if re.search(r"\d", b):
            fail("blurb contains a number: %r" % b)
        if "!" in b:
            fail("blurb contains an exclamation mark")
        if v.get("name", "").lower() in b.lower():
            warn.append("%s: blurb restates the name -- %r" % (iid, b))
        for dull in ("gives children", "provides a", "allows students",
                     "used for", "a place for", "helps children"):
            if b.lower().startswith(dull):
                warn.append("%s: catalogue voice -- %r" % (iid, b))

        # concepts
        for key in ("teaches", "needs"):
            if key not in v:
                continue
            cid = v[key]
            if cid not in concepts:
                fail("%s names a concept that does not exist: %r" % (key, cid))
                continue
            if key == "teaches":
                teaches += 1
                if cid in taught:
                    fail("teaches %r, which an existing item already teaches"
                         % cid)
            else:
                needs += 1
            lesson = cid.split(".")[0]
            lessons_touched[lesson] = lessons_touched.get(lesson, 0) + 1

        # Near-duplicate sniff against the existing 29.
        #
        # Word overlap, not substring: "Bench Seat" against "Long Bench"
        # and "Classroom Clock" against "Wall Clock" are exactly the
        # duplicates the prompt names, and neither is a substring of the
        # other. A shared noun is enough to be worth a human look.
        STOP = {"the", "a", "of", "and", "for", "with", "small", "large",
                "new", "class", "classroom", "school", "student", "childs"}

        def words(s):
            return {w for w in re.findall(r"[a-z]+", s.lower())
                    if w not in STOP and len(w) > 2}

        nw = words(v.get("name", ""))
        for oid, ov in have.items():
            shared = nw & words(ov["name"])
            if shared:
                warn.append("%s (%s) shares %s with the existing %s (%s)"
                            % (iid, v.get("name"), sorted(shared),
                               oid, ov["name"]))

    # Raised from 4/3 once "concepts are texture, not a collection" was
    # decided: the shop links only 8 concepts and the target is ~20 across
    # 50 items, so this batch is where most of that gap closes.
    if teaches < 7:
        bad.append("only %d items teach a concept, need at least 7" % teaches)
    if needs < 5:
        bad.append("only %d items need a concept, need at least 5" % needs)
    for c in sorted(CATS):
        if cats.get(c, 0) < 2:
            bad.append("category %r has %d items, need at least 2"
                       % (c, cats.get(c, 0)))
    for lesson, n in sorted(lessons_touched.items()):
        if n > 2:
            bad.append("%d items touch the %r lesson, max 2" % (n, lesson))

    # RULE 2 - reach must trade against strength, not rise with it
    ordered = sorted(new.values(), key=lambda v: v.get("cost", 0))
    bonuses = [v.get("bonus", 0) for v in ordered]
    ranges = [v.get("range", 0) for v in ordered]
    if bonuses == sorted(bonuses) and ranges == sorted(ranges):
        bad.append("sorted by cost, bonus AND range both rise monotonically: "
                   "that is a ladder, not a set of choices (rule 2)")

    print("items: %d   categories: %s" % (len(new), cats))
    print("teaches: %d   needs: %d" % (teaches, needs))
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
