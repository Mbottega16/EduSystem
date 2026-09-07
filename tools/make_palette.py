#!/usr/bin/env python3
"""Write tools/palette.json -- the house palette, as the forges' swatches.

    python tools/make_palette.py

docs/PIXEL_STYLE.md has promised "the curated set lives in
tools/palette.json and loads as the forge's default swatches" since it was
written; the file did not exist, so the art forge opened with only whatever
colours happened to be in the sprite you had selected. Painting a new
sprite in house colours meant eyedropping another one first.

**Generated from the generators, never hand-kept.** The three make_*.py
modules already hold every colour the game is drawn in as module
constants; this imports them and groups them. A hand-written palette file
would be a second source of truth for the same colours, and the first
retune through the forge would put the two out of step silently.

Excluded on purpose: SHADOW (pure black, the contact shadow's own colour,
never painted with) and the per-character skin/hair entries in
make_art.CHARACTERS, which are a character's identity rather than shared
material colours -- a new character is a new palette, per the Art section
of CLAUDE.md, not a pick from this list.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import make_art
import make_items
import make_ui

OUT = os.path.join(HERE, "palette.json")

# Which module owns which group, and the order the forge shows them in.
# A colour named in more than one module (LINE, WOOD*) is listed once, in
# the first group that claims it -- the forge shows a flat row per group
# and a duplicate swatch is just a wider row saying nothing new.
GROUPS = [
    ("keyline", make_art, ["LINE"]),
    ("skin", make_art, ["SKIN", "SKIN_D", "BLUSH", "MOUTH", "MOUTH_OPEN",
                        "TONGUE", "TEETH", "EYE", "TEAR"]),
    ("wood", make_art, ["WOOD_L", "WOOD", "WOOD_D", "DADO_L", "DADO",
                        "DADO_D", "RAIL", "HANDLE", "HANDLE_D"]),
    ("metal", make_art, ["METAL", "METAL_D"]),
    ("wall & floor", make_art, ["WALL_TOP", "WALL_L", "WALL", "WALL_D",
                                "WALL_BASE", "FLOOR_A", "FLOOR_B",
                                "FLOOR_FLECK", "FLOOR_GROUT"]),
    ("board & chalk", make_art, ["BOARD_L", "BOARD", "CHALK", "CHALK_D"]),
    ("glass & light", make_art, ["GLASS_L", "GLASS", "GLASS_D_L", "GLASS_D",
                                 "GLASS_FRAME", "LENS", "SKY_MID"]),
    ("cloth & trim", make_art, ["CURTAIN_L", "CURTAIN", "CURTAIN_D",
                                "DOOR_PAINT_L", "DOOR_PAINT", "DOOR_PAINT_D",
                                "LANYARD", "HAIR_BAND", "BADGE",
                                "BADGE_STRIPE"]),
    ("frame", make_art, ["FRAME_L", "FRAME", "FRAME_D", "TITLE_FRAME_W",
                         "TITLE_FRAME_D"]),
    ("items", make_items, ["STEEL_L", "STEEL", "STEEL_D", "CLOTH_L", "CLOTH",
                           "PAPER", "GREEN_L", "GREEN", "BLUE_L", "BLUE",
                           "GOLD", "DARK"]),
    ("book & UI", make_ui, ["PAGE", "PAGE_SHADE", "PAGE_EDGE", "GUTTER",
                            "COVER_L", "COVER", "INK"]),
]


def _hex(rgb):
    return "#%02x%02x%02x" % tuple(rgb[:3])


def build():
    # "_modules" maps each group to the generator module that owns it, so
    # the Master Forge's Items / HUD tabs can offer only the constants that
    # THEIR forge script can actually set. Underscore-prefixed keys are
    # metadata; every reader skips them, the way balance.json's own _note
    # entries are skipped.
    out = {"_modules": {}}
    seen = set()
    for group, mod, names in GROUPS:
        row = {}
        for n in names:
            v = getattr(mod, n, None)
            if v is None:
                raise SystemExit(
                    "palette: %s.%s is gone. Fix the list in this file rather "
                    "than letting the forge quietly lose a swatch." % (mod.__name__, n))
            h = _hex(v)
            if h in seen:
                continue
            seen.add(h)
            row[n] = h
        if row:
            out[group] = row
            out["_modules"][group] = mod.__name__
    return out


def make_all():
    data = build()
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    n = sum(len(v) for k, v in data.items() if not k.startswith("_"))
    groups = [k for k in data if not k.startswith("_")]
    print("tools/palette.json   %d colours in %d groups" % (n, len(groups)))
    return data


if __name__ == "__main__":
    make_all()
