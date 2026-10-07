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

## The rest of the family, added Oct 2026. Same bubble, same 5x6 box, same
## keyline -- only the mark changes, so a room of children reads as a row of
## DIFFERENT problems instead of a row of identical "?" in four tints. Colour
## alone was carrying that distinction, which is both a colour-blindness
## problem and hard to read at a glance across thirty tiles.
##
## Why hand-set pixels and not LimeZu's own emote sheet (which has all of
## these): the bubble is TINTED per reason at runtime and his emotes are
## already coloured -- amber multiplied over a yellow "!" is mud. Same reason
## bubble_q exists. His sheet stays the source for anything drawn untinted.
EXCLAIM = [
    "..#..",
    "..#..",
    "..#..",
    "..#..",
    ".....",
    "..#..",
]

DOTS = [
    ".....",
    ".....",
    "#.#.#",
    ".....",
    ".....",
    ".....",
]

HEART = [
    ".#.#.",
    "#####",
    "#####",
    ".###.",
    "..#..",
    ".....",
]

ZED = [
    "#####",
    "...#.",
    "..#..",
    ".#...",
    "#####",
    ".....",
]

DROP = [
    "..#..",
    ".###.",
    ".###.",
    "#####",
    "#####",
    ".###.",
]

NOTE = [
    "...##",
    "..#.#",
    "..#..",
    "..#..",
    ".##..",
    ".##..",
]


def stamp(im, glyph, x0, y0, colour):
    for dy, row in enumerate(glyph):
        for dx, ch in enumerate(row):
            if ch == "#":
                im.putpixel((x0 + dx, y0 + dy), colour)


def _bubble(glyph):
    """LimeZu's blank speech bubble (12x14: a 12x10 body and a 4px tail) + a mark.

    The body's interior is rows 2..9 of the cropped icon, columns 1..10, so a
    5x6 mark stamped at (3, 3) sits inside it with a pixel to spare.
    """

    def build(interiors, ui):
        bubble = interiors.image(UI_SHEET).crop((66, 11, 78, 25))
        stamp(bubble, glyph, 3, 3, KEYLINE)
        return limezu.up2(bubble)

    return build


bubble_q = _bubble(QUESTION)


# Modern UI (its own pack): Style 1 is the warm bamboo-and-cream set that sits with
# the game's palette (Style 2 is a cold lavender). The frame is the 32x31 bordered
# panel at the sheet's top-left; the HUD draws it as a 9-slice, with its centre
# either left empty (a border round a dark screen) or filled (a cream slot that a
# shop item's picture sits in).
UI_STYLE_1 = "16x16/Modern_UI_Style_1.png"
FRAME_BOX = (8, 8, 40, 39)


def ui_frame(interiors, ui):
    return limezu.up2(ui.image(UI_STYLE_1).crop(FRAME_BOX))


# The speech panel: what someone SAYS is printed on paper-white, black ink, the
# way a 16-bit RPG's text box is -- the owner's ask, over the old dark box with
# yellow text. Style 2's rounded white panel (keyline, a grey inner rim, a soft
# lower edge) is that box already. The HUD 9-slices it with a 4-art-pixel (8px)
# margin, round the dialogue box, its name tag, the face beside a line, and the
# room's own speech bubbles.
UI_STYLE_2 = "16x16/Modern_UI_Style_2.png"
SPEECH_BOX = (60, 235, 84, 260)


def ui_speech(interiors, ui):
    return limezu.up2(ui.image(UI_STYLE_2).crop(SPEECH_BOX))


BUILDERS = {
    "bubble_q": bubble_q,
    "bubble_excl": _bubble(EXCLAIM),
    "bubble_dots": _bubble(DOTS),
    "bubble_heart": _bubble(HEART),
    "bubble_zzz": _bubble(ZED),
    "bubble_drop": _bubble(DROP),
    "bubble_note": _bubble(NOTE),
    "ui_frame": ui_frame,
    "ui_speech": ui_speech,
}
OUTPUTS = sorted(BUILDERS)


def owned_names():
    return set(OUTPUTS)


def main(argv):
    check = "--check" in argv
    interiors = limezu.need_pack("interiors")
    ui = limezu.need_pack("ui")
    wrote = bad = 0
    for name in OUTPUTS:
        img = BUILDERS[name](interiors, ui)
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
