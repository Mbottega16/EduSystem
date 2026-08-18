#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Catch a misspelled key in data/balance.json before it costs an hour.

WHY THIS EXISTS. Balance.apply() (scripts/data/balance.gd) is ~120 lines
of `room_base = float(g.get("room_base", room_base))`. Type "room_bass"
in the JSON and .get() silently returns the built-in default -- the game
runs on a hardcoded constant, and nothing warns. For a project whose
first hard constraint is "numbers do not live in code", a tunable that
silently reverts to code is the worst version of that failure.

Static, not runtime: it reads balance.gd's own source to find every key
it actually consumes -- the same technique tools/curator.gd already uses
to find which sprites are referenced -- and compares that against every
key data/balance.json actually has. Two kinds of drift, both real:

  - a JSON key nothing reads (misspelled, or leftover from a rename)
  - a section apply() reads that the JSON does not have at all

Five sections are catalogues, not tunables -- consumed as a whole
Dictionary (Balance.items = d["items"]) rather than key by key, so a
per-key scan does not apply to them: items, item_order, item_categories,
perks, traits.

Run it: python tools/check_balance.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOGUE_SECTIONS = {"items", "item_order", "item_categories", "perks",
                      "traits"}


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def main():
    balance = json.loads(read(os.path.join("data", "balance.json")))
    src = read(os.path.join("scripts", "data", "balance.gd"))

    # Which local variable holds each section: `var g: Dictionary = d.get("grade", {})`
    # (var_name, section_name) in source order -> {section_name: var_name}
    pairs = re.findall(r'var (\w+)\s*:\s*Dictionary\s*=\s*d\.get\("(\w+)"', src)
    section_var = {section: var for var, section in pairs}

    json_sections = {k for k in balance if not k.startswith("_")}
    read_sections = set(section_var.keys()) | CATALOGUE_SECTIONS

    fails = []

    missing_sections = json_sections - read_sections
    if missing_sections:
        fails.append("balance.json has section(s) apply() never reads at "
                     "all: %s" % sorted(missing_sections))

    # Per-key scan, one section at a time: every `VAR.get("key"` in the
    # slice of the file between this section's declaration and the next.
    order = re.findall(r'var \w+: Dictionary = d\.get\("(\w+)"', src)
    positions = [m.start() for m in re.finditer(
        r'var \w+: Dictionary = d\.get\("(?:%s)"' % "|".join(map(re.escape, order)),
        src)]
    bounds = list(zip(order, positions, positions[1:] + [len(src)]))

    for section, start, end in bounds:
        if section not in balance:
            continue  # already reported above, or the section is empty
        var = section_var[section]
        chunk = src[start:end]
        consumed = set(re.findall(r'%s\.get\("(\w+)"' % re.escape(var), chunk)) \
            | set(re.findall(r'%s\["(\w+)"\]' % re.escape(var), chunk))
        real_keys = {k for k in balance[section] if not k.startswith("_")}
        unread = real_keys - consumed
        if unread:
            fails.append("section %r: key(s) in balance.json that apply() "
                         "never reads -- %s" % (section, sorted(unread)))

    for cat in CATALOGUE_SECTIONS:
        if cat not in balance:
            fails.append("catalogue section %r is read as a whole "
                         "Dictionary but is missing from balance.json" % cat)

    print("sections checked: %d" % len(bounds))
    if fails:
        print("\nFAILED: %d\n" % len(fails))
        for f in fails:
            print("  - %s" % f)
        return 1
    print("every key in balance.json is read by something")
    return 0


if __name__ == "__main__":
    sys.exit(main())
