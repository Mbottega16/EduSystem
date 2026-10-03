#!/usr/bin/env python3
"""Generate new student (or adult) appearances from the same trait pools
the hand-authored cast already draws from -- hair style/colour, skin,
eye colour, clothing pattern (respecting the adult-cue vs kid-cue split
PATTERNS already documents), glasses, sleeves.

This tool DRAWS and PREVIEWS only -- it never edits make_art.py or
names.gd itself. A generated look becomes real by hand: review the
preview, then copy the printed CHARACTERS entry into make_art.py and the
printed name into Names.ART in scripts/data/names.gd, same as this
session's other additions were reviewed before being wired in. Roster
registration (Names.ART) is a short, fixed list on purpose -- see its
own doc comment -- so growing it is a deliberate edit, not something a
script does silently.

    python tools/random_student.py [N] [seed] [--adult]

Writes N preview sheets + portraits to art/ as student_i, student_j, ...
(the next free letters after the hand-authored student_a..h), prints
each one's CHARACTERS entry and Names.ART line. Defaults: N=4, seed=
random (printed, so a specific preview can be reproduced).
"""
import os
import random
import string
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import make_art as ma

EXISTING_LETTERS = set(
    name[len("student_"):] for name in ma.CHARACTERS if name.startswith("student_")
)


def next_letters(n):
    out = []
    for ch in string.ascii_lowercase:
        if ch not in EXISTING_LETTERS and ch not in out:
            out.append(ch)
        if len(out) == n:
            break
    return out


def format_entry(name, pal, hair_name):
    return (
        '    "%s": {\n'
        '        "hair": %s, "hair_d": %s,  # %s\n'
        '        "shirt": %s, "shirt_d": %s,\n'
        '        "legs": %s, "shoe": %s,\n'
        '        "long_hair": %s, "skirt": %s,\n'
        '        "hair_style": "%s", "skin": "%s", "pattern": "%s",\n'
        '        "glasses": %s, "sleeves": "%s", "eyes": %s,\n'
        '    },'
    ) % (
        name, pal["hair"], pal["hair_d"], hair_name,
        pal["shirt"], pal["shirt_d"],
        pal["legs"], pal["shoe"],
        pal["long_hair"], pal["skirt"],
        pal["hair_style"], pal["skin"], pal["pattern"],
        pal["glasses"], pal["sleeves"], pal["eyes"],
    )


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    child = "--adult" not in sys.argv[1:]
    n = int(args[0]) if len(args) > 0 else 4
    seed = int(args[1]) if len(args) > 1 else random.randrange(1_000_000)
    rng = random.Random(seed)
    print("seed: %d  (pass this as the 2nd argument to reproduce this exact batch)" % seed)

    letters = next_letters(n)
    if len(letters) < n:
        sys.exit("only %d free student_<letter> slots left (a-z), asked for %d"
                  % (len(letters), n))

    for letter in letters:
        name = "student_%s" % letter
        pal, hair_name = ma.random_palette(rng, child=child)
        size = ma.make_character(name, pal)
        psize = ma.make_portrait(name, pal)
        print("\n# %s  (sheet %dx%d, portrait %dx%d)" % (name, size[0], size[1], psize[0], psize[1]))
        print(format_entry(name, pal, hair_name))
        print('# scripts/data/names.gd Names.ART: add "%s",' % name)


if __name__ == "__main__":
    main()
