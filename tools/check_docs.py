#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Check every factual claim in every PixelRoom document against live data.

WHY THIS EXISTS. `docs/BRIEFING.md` once carried a worked example claiming
the microscope was `range 2, bonus 0.05` when the real item is `range 3,
bonus 0.13`. That single wrong example was attached to an outside model,
which anchored on it and returned an entire 22-item catalogue at half the
correct strength. Nothing caught it: the example parsed as valid JSON and
every field name was real. Only the VALUES had drifted.

A document that is attached to an outside model is not documentation. It
is an input to a build step, and it needs the same verification as code.

Run it: python tools/check_docs.py       (from the project root)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

checks = 0
fails = []


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as f:
        return f.read()


def check(label, got, want):
    global checks
    checks += 1
    if got != want:
        fails.append("%s\n     doc:  %s\n     data: %s" % (label, want, got))


def present(label, needle, haystack):
    global checks
    checks += 1
    if needle not in haystack:
        fails.append("%s: %r missing" % (label, needle))


balance = json.loads(read(os.path.join("data", "balance.json")))
curric = json.loads(read(os.path.join("data", "curriculum.json")))
items = {k: v for k, v in balance["items"].items() if not k.startswith("_")}
traits = {k: v for k, v in balance["traits"].items() if not k.startswith("_")}

claude = read("CLAUDE.md")
brief = read(os.path.join("docs", "BRIEFING.md"))
pack = read(os.path.join("docs", "TASK_PACK.md"))
gdd = read(os.path.join("docs", "GDD.md"))
salvage = read(os.path.join("docs", "SALVAGE.md"))
readme = read("README.md")
ALL = {"CLAUDE.md": claude, "BRIEFING.md": brief, "TASK_PACK.md": pack,
       "GDD.md": gdd, "SALVAGE.md": salvage, "README.md": readme}

# ---- 1. every schema example in BRIEFING is the REAL row ----
#
# This is the check that would have caught the microscope.
for doc_name, doc in [("BRIEFING.md", brief), ("TASK_PACK.md", pack)]:
    for m in re.finditer(r'"(\w+)":\s*\{\s*"name":\s*"([^"]+)",\s*'
                         r'"art":[^}]*?"cost":\s*(\d+),\s*"range":\s*(\d+),\s*'
                         r'"bonus":\s*([\d.]+)', doc):
        iid, _name, cost, rng, bonus = m.groups()
        if iid not in items:
            fails.append("%s: worked example uses unknown item %r"
                         % (doc_name, iid))
            continue
        real = items[iid]
        check("%s example %s.cost" % (doc_name, iid), real["cost"], int(cost))
        check("%s example %s.range" % (doc_name, iid), real["range"], int(rng))
        check("%s example %s.bonus" % (doc_name, iid), real["bonus"], float(bonus))

# ---- 2. the item table quoted in TASK_PACK matches balance.json ----
quoted = dict(re.findall(r"(\w+) (\d+)/([\d.]+)/(\d+)",
                         pack.replace("\n", " ")) and
              [(m[0], (int(m[1]), float(m[2]), int(m[3])))
               for m in re.findall(r"(\w+) (\d+)/([\d.]+)/(\d+)", pack)])
for iid, (cost, bonus, rng) in quoted.items():
    if iid not in items:
        continue
    real = items[iid]
    check("TASK_PACK item table %s" % iid,
          (real["cost"], real["bonus"], real["range"]), (cost, bonus, rng))

# ---- 3. counts ----
check("item count", len(items),
      int(re.search(r"Currently (\d+) items", brief).group(1)))
check("trait count", len(traits), 12)
check("lesson count", len(curric["lessons"]),
      int(re.search(r"Currently (\d+) lessons", brief).group(1)))
check("concept count", sum(len(l["concepts"]) for l in curric["lessons"]),
      int(re.search(r"Currently \d+ lessons, \d+ per strand, (\d+) concepts",
                    brief).group(1)))

# ---- 4. the do-not-collide inventory lives in BRIEFING ----
#
# It used to live inside task 1's prompt. Finishing that task archived the
# prompt, which would have left the next curriculum task colliding with
# lessons it could not see. BRIEFING is attached to EVERY task.
for l in curric["lessons"]:
    present("BRIEFING inventory: lesson id", l["id"], brief)
    std = l.get("standard", "")
    if std:
        present("BRIEFING inventory: standard code", std, brief)
    for c in l["concepts"]:
        checks += 1
        if c.get("standard", "") != std or c.get("source", "") != l.get("source", ""):
            fails.append("%s: a concept cites a different code than its parent"
                         % l["id"])

# ---- 5. the value-density window the prompt asserts ----
lo, hi = 360, 840
m = re.search(r"between (\d+) and (\d+)", pack)
if m:
    lo, hi = int(m.group(1)), int(m.group(2))
for iid, v in items.items():
    checks += 1
    d = v["cost"] / (v["bonus"] * v["range"])
    if not (lo <= d <= hi):
        fails.append("value-density claim false: %s = %.0f, prompt says all "
                     "%d sit in %d-%d" % (iid, d, len(items), lo, hi))

# ---- 6. the assertion count agrees across every doc that states it ----
counts = set()
for name, doc in ALL.items():
    for n in re.findall(r"(\d+) assertions", doc):
        # 730 is a story about the podium bug, not a current count
        if n != "730":
            counts.add(int(n))
checks += 1
if len(counts) > 1:
    fails.append("docs disagree on the assertion count: %s "
                 "(run Run Tests.bat and sync them)" % sorted(counts))

# ---- 7. every doc named in CLAUDE.md's file map exists ----
for rel in re.findall(r"`(docs/[A-Za-z_\-]+\.md)`", claude):
    checks += 1
    if not os.path.exists(os.path.join(ROOT, rel.replace("/", os.sep))):
        fails.append("CLAUDE.md file map names a doc that does not exist: %s" % rel)
for name in ["GDD.md", "BRIEFING.md", "TASK_PACK.md", "SALVAGE.md"]:
    present("CLAUDE.md file map", name, claude)

# ---- report ----
print("checks run: %d" % checks)
if fails:
    print("\nFAILED: %d\n" % len(fails))
    for f in fails:
        print("  - %s" % f)
    sys.exit(1)
print("all doc facts match the live data")
