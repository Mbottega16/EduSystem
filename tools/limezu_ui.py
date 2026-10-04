"""Small UI sprites composed from LimeZu pieces + a few generated pixels.

    python tools/limezu_ui.py             write them into art/
    python tools/limezu_ui.py --check     is art/ what this builds?

Some game sprites cannot be a straight copy from a pack because the game does
something to them at runtime. The "stuck" bubble over a child's head is TINTED
per reason (amber for stuck, cooler for a quiz flag, red for a flare-up), so its
art has to be a neutral white bubble with a dark mark -- a coloured LimeZu "?"
bubble would be multiplied into mud. So it is LimeZu's own blank speech bubble
(Interiors / UI elements) with a hand-set 5x6 pixel "?" in LimeZu's keyline
colour, which is also the pattern for any future piece that needs "their frame,
our glyph".

Everything is built in 16x16 art space and doubled with NEAREST.
"""
import os
import sys

from PIL import Image

import limezu

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
SPRITES = os.path.join(ROOT, "tools", "sprites")
ARCHIVE = os.path.join(SPRITES, "_replaced_by_limezu")

UI_SHEET = "4_User_Interface_Elements/UI_16x16.png"
KEYLINE = (0x3a, 0x3a, 0x50, 255)

QUESTION = [
    ".###.",
    "#...#",
    "...#.",
    "..#..",
    ".....",
    "..#..",
]


def stamp(im, glyph, x0, y0, colour):
    for dy, row in enumerate(glyph):
        for dx, ch in enumerate(row):
            if ch == "#":
                im.putpixel((x0 + dx, y0 + dy), colour)


def bubble_q(interiors):
    """LimeZu's blank speech bubble (12x14: a 12x10 body and a 4px tail) + a '?'."""
    sheet = interiors.image(UI_SHEET)
    bubble = sheet.crop((66, 11, 78, 25))
    # the body's interior is rows 2..9 of the cropped icon, columns 1..10
    stamp(bubble, QUESTION, 3, 3, KEYLINE)
    return limezu.up2(bubble)


BUILDERS = {
    "bubble_q": bubble_q,
}
OUTPUTS = sorted(BUILDERS)


def owned_names():
    return set(OUTPUTS)


def main(argv):
    check = "--check" in argv
    interiors = limezu.need_pack("interiors")
    wrote = bad = 0
    for name in OUTPUTS:
        img = BUILDERS[name](interiors)
        path = os.path.join(ART, name + ".png")
        have = Image.open(path).convert("RGBA") if os.path.exists(path) else None
        if have is not None and limezu.same_pixels(have, img):
            continue
        if check:
            bad += 1
            print("DIFFERS  %s" % name)
            continue
        hand = os.path.join(SPRITES, name + ".txt")
        if os.path.exists(hand):
            os.makedirs(ARCHIVE, exist_ok=True)
            os.replace(hand, os.path.join(ARCHIVE, name + ".txt"))
            print("  (hand source archived: tools/sprites/_replaced_by_limezu/%s.txt)" % name)
        img.save(path)
        wrote += 1
        print("art/%-16s %dx%d" % (name + ".png", img.width, img.height))
    print("%d written%s" % (wrote, (", %d differ" % bad) if check else ""))
    if wrote:
        print("Godot cannot load changed PNGs until:  godot --headless --path . --import")
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
