#!/usr/bin/env python3
"""Draw the purchasable classroom furniture.

Split out of make_art.py because the catalogue went from 5 items to two
dozen, and that file was already 900 lines of characters, tiles and room.

    python tools/make_items.py        (make_art.py calls this too)

Every item here must have a matching row in data/balance.json under
"items", and the browser (Browse Art.bat) will flag either half if the two
drift apart.
"""
import os

from PIL import Image

from make_art import (LINE, WOOD, WOOD_L, WOOD_D, outline, px, rect, shadow,
                      hand_edited)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

# a small shared palette so two dozen items still look like one set
STEEL = (132, 138, 148)
STEEL_L = (170, 176, 186)
STEEL_D = (92, 96, 106)
CLOTH = (188, 96, 104)
CLOTH_L = (216, 128, 134)
PAPER = (246, 244, 236)
GREEN = (84, 152, 90)
GREEN_L = (108, 180, 112)
BLUE = (96, 150, 206)
BLUE_L = (140, 186, 226)
GOLD = (232, 186, 74)
DARK = (46, 42, 54)


def _blank(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow(im, w // 2, h - 2, max(3, w // 3), 2)
    return im


# --- seating ---------------------------------------------------------

def draw_stool():
    im = _blank(16, 18)
    rect(im, 3, 5, 12, 8, WOOD)
    rect(im, 3, 5, 12, 6, WOOD_L)
    rect(im, 4, 9, 5, 16, WOOD_D)
    rect(im, 10, 9, 11, 16, WOOD_D)
    rect(im, 5, 12, 10, 13, WOOD_D)
    return outline(im)


def draw_beanbag():
    im = _blank(18, 16)
    rect(im, 2, 6, 15, 14, CLOTH)
    rect(im, 3, 4, 14, 7, CLOTH_L)
    rect(im, 5, 3, 12, 4, CLOTH_L)
    rect(im, 2, 13, 15, 14, (150, 70, 80))
    return outline(im)


def draw_bench():
    im = _blank(32, 16)
    rect(im, 1, 5, 30, 8, WOOD)
    rect(im, 1, 5, 30, 6, WOOD_L)
    rect(im, 3, 9, 4, 14, WOOD_D)
    rect(im, 27, 9, 28, 14, WOOD_D)
    rect(im, 5, 10, 26, 11, WOOD_D)
    return outline(im)


def draw_floor_cushion():
    im = _blank(16, 12)
    rect(im, 2, 5, 13, 10, BLUE)
    rect(im, 3, 4, 12, 6, BLUE_L)
    px(im, 8, 7, BLUE_L)
    return outline(im)


# --- surfaces --------------------------------------------------------

def draw_side_table():
    im = _blank(16, 18)
    rect(im, 1, 4, 14, 7, WOOD)
    rect(im, 1, 4, 14, 5, WOOD_L)
    rect(im, 3, 8, 4, 16, WOOD_D)
    rect(im, 11, 8, 12, 16, WOOD_D)
    return outline(im)


def draw_cabinet():
    im = _blank(16, 22)
    rect(im, 1, 2, 14, 19, WOOD)
    rect(im, 1, 2, 14, 3, WOOD_L)
    rect(im, 2, 5, 13, 10, WOOD_D)
    rect(im, 2, 12, 13, 17, WOOD_D)
    px(im, 12, 7, GOLD)
    px(im, 12, 14, GOLD)
    rect(im, 2, 20, 4, 21, WOOD_D)
    rect(im, 11, 20, 13, 21, WOOD_D)
    return outline(im)


def draw_crate():
    im = _blank(16, 14)
    rect(im, 2, 3, 13, 12, WOOD)
    rect(im, 2, 3, 13, 4, WOOD_L)
    rect(im, 2, 7, 13, 7, WOOD_D)
    rect(im, 7, 5, 8, 11, WOOD_D)
    return outline(im)


def draw_supply_shelf():
    im = _blank(32, 20)
    rect(im, 1, 2, 30, 17, WOOD_D)
    rect(im, 2, 3, 29, 9, WOOD)
    rect(im, 2, 11, 29, 16, WOOD)
    for x in range(4, 28, 5):
        rect(im, x, 4, x + 2, 8, BLUE if (x // 5) % 2 else CLOTH)
        rect(im, x, 12, x + 2, 15, GREEN if (x // 5) % 2 else GOLD)
    return outline(im)


# --- learning --------------------------------------------------------

def draw_globe():
    im = _blank(16, 20)
    rect(im, 4, 3, 11, 11, BLUE)
    rect(im, 5, 4, 7, 6, GREEN)
    rect(im, 8, 7, 10, 9, GREEN)
    rect(im, 4, 3, 11, 3, BLUE_L)
    rect(im, 7, 12, 8, 15, STEEL_D)
    rect(im, 4, 16, 11, 18, WOOD_D)
    return outline(im)


def draw_abacus():
    im = _blank(16, 18)
    rect(im, 1, 3, 14, 15, WOOD_D)
    rect(im, 2, 4, 13, 14, (200, 176, 140))
    for i, y in enumerate((5, 8, 11)):
        rect(im, 2, y, 13, y, WOOD_D)
        for j in range(3):
            c = (CLOTH, BLUE, GREEN)[(i + j) % 3]
            px(im, 3 + j * 3, y - 1, c)
            px(im, 4 + j * 3, y - 1, c)
    return outline(im)


def draw_microscope():
    im = _blank(16, 20)
    rect(im, 5, 2, 8, 9, STEEL)
    rect(im, 5, 2, 6, 9, STEEL_L)
    rect(im, 4, 10, 11, 11, STEEL_D)
    rect(im, 6, 12, 9, 15, STEEL)
    rect(im, 3, 16, 12, 18, STEEL_D)
    px(im, 9, 4, BLUE_L)
    return outline(im)


def draw_whiteboard():
    im = _blank(32, 22)
    rect(im, 1, 1, 30, 15, (60, 56, 70))
    rect(im, 2, 2, 29, 14, PAPER)
    rect(im, 4, 4, 16, 4, (140, 146, 156))
    rect(im, 4, 6, 22, 6, (140, 146, 156))
    rect(im, 4, 8, 12, 8, (140, 146, 156))
    rect(im, 1, 16, 30, 17, STEEL_D)
    rect(im, 5, 18, 8, 19, STEEL_D)
    rect(im, 23, 18, 26, 19, STEEL_D)
    return outline(im)


def draw_reading_nook():
    im = _blank(32, 20)
    rect(im, 1, 6, 30, 17, CLOTH)
    rect(im, 2, 4, 29, 8, CLOTH_L)
    rect(im, 3, 2, 11, 6, BLUE)
    rect(im, 20, 2, 28, 6, GREEN)
    rect(im, 1, 16, 30, 17, (150, 70, 80))
    return outline(im)


def draw_maths_tiles():
    im = _blank(16, 14)
    rect(im, 1, 4, 14, 12, WOOD_D)
    for i, (x, c) in enumerate(((2, CLOTH), (6, BLUE), (10, GREEN))):
        rect(im, x, 5, x + 3, 8, c)
        rect(im, x, 9, x + 3, 11, GOLD if i == 1 else STEEL)
    return outline(im)


def draw_music_corner():
    im = _blank(16, 20)
    rect(im, 3, 8, 12, 16, WOOD)
    rect(im, 3, 8, 12, 9, WOOD_L)
    rect(im, 4, 10, 11, 14, DARK)
    for x in range(4, 12, 2):
        rect(im, x, 10, x, 14, PAPER)
    rect(im, 6, 3, 7, 7, DARK)
    rect(im, 6, 2, 9, 3, DARK)
    return outline(im)


# --- comfort ---------------------------------------------------------

def draw_lamp():
    im = _blank(16, 22)
    rect(im, 3, 2, 12, 8, GOLD)
    rect(im, 3, 2, 12, 3, (250, 214, 120))
    rect(im, 7, 9, 8, 17, STEEL_D)
    rect(im, 4, 18, 11, 20, STEEL_D)
    return outline(im)


def draw_water_cooler():
    im = _blank(16, 22)
    rect(im, 4, 1, 11, 8, BLUE_L)
    rect(im, 5, 2, 10, 7, (176, 216, 240))
    rect(im, 3, 9, 12, 19, PAPER)
    rect(im, 3, 9, 12, 10, (220, 220, 214))
    rect(im, 6, 13, 9, 14, STEEL_D)
    return outline(im)


def draw_radiator():
    im = _blank(32, 16)
    rect(im, 1, 3, 30, 13, STEEL)
    for x in range(3, 30, 3):
        rect(im, x, 4, x + 1, 12, STEEL_L)
    rect(im, 1, 13, 30, 14, STEEL_D)
    return outline(im)


def draw_coat_hooks():
    im = _blank(32, 18)
    rect(im, 1, 2, 30, 5, WOOD)
    rect(im, 1, 2, 30, 2, WOOD_L)
    for i, x in enumerate((5, 13, 21, 27)):
        rect(im, x, 6, x + 1, 8, STEEL_D)
        if i % 2 == 0:
            rect(im, x - 2, 7, x + 3, 15, CLOTH if i == 0 else GREEN)
    return outline(im)


# --- decor -----------------------------------------------------------

def draw_wall_clock():
    im = _blank(14, 14)
    rect(im, 1, 1, 12, 12, PAPER)
    rect(im, 2, 2, 11, 11, (230, 228, 220))
    rect(im, 6, 3, 6, 6, DARK)
    rect(im, 6, 6, 9, 6, DARK)
    return outline(im)


def draw_alphabet_frieze():
    im = _blank(32, 12)
    rect(im, 1, 1, 30, 10, PAPER)
    for i, x in enumerate(range(3, 30, 4)):
        c = (CLOTH, BLUE, GREEN, GOLD)[i % 4]
        rect(im, x, 3, x + 2, 8, c)
    return outline(im)


def draw_fish_tank():
    im = _blank(32, 18)
    rect(im, 1, 2, 30, 15, (150, 200, 220))
    rect(im, 2, 3, 29, 14, (120, 180, 214))
    rect(im, 2, 12, 29, 14, (206, 190, 150))
    rect(im, 6, 6, 9, 8, GOLD)
    rect(im, 18, 8, 21, 10, CLOTH)
    rect(im, 12, 9, 13, 13, GREEN)
    rect(im, 24, 8, 25, 13, GREEN_L)
    rect(im, 1, 1, 30, 2, STEEL_D)
    return outline(im)


def draw_class_banner():
    im = _blank(24, 16)
    rect(im, 1, 1, 22, 3, WOOD_D)
    rect(im, 2, 4, 21, 12, CLOTH)
    rect(im, 4, 6, 19, 7, PAPER)
    rect(im, 4, 9, 15, 10, PAPER)
    for x in range(2, 22, 4):
        rect(im, x, 13, x + 1, 14, CLOTH)
    return outline(im)


def draw_pot_of_pens():
    im = _blank(14, 16)
    rect(im, 4, 7, 10, 14, STEEL)
    rect(im, 4, 7, 5, 14, STEEL_L)
    for i, x in enumerate((5, 7, 9)):
        c = (CLOTH, BLUE, GREEN)[i]
        rect(im, x, 3 + i, x, 7, c)
    return outline(im)


ITEMS = {
    # seating
    "stool": draw_stool, "beanbag": draw_beanbag,
    "bench": draw_bench, "floor_cushion": draw_floor_cushion,
    # surfaces
    "side_table": draw_side_table, "cabinet": draw_cabinet,
    "crate": draw_crate, "supply_shelf": draw_supply_shelf,
    # learning
    "globe": draw_globe, "abacus": draw_abacus, "microscope": draw_microscope,
    "whiteboard": draw_whiteboard, "reading_nook": draw_reading_nook,
    "maths_tiles": draw_maths_tiles, "music_corner": draw_music_corner,
    # comfort
    "lamp": draw_lamp, "water_cooler": draw_water_cooler,
    "radiator": draw_radiator, "coat_hooks": draw_coat_hooks,
    # decor
    "wall_clock": draw_wall_clock, "alphabet_frieze": draw_alphabet_frieze,
    "fish_tank": draw_fish_tank, "class_banner": draw_class_banner,
    "pot_of_pens": draw_pot_of_pens,
}


def make_all(hand=None):
    """Draw every item. `hand` is the set of names a text source owns.

    A hand-edited sprite wins: it is drawn from tools/sprites/<name>.txt by
    make_art.make_grid_sprites(), and redrawing it here would silently undo
    the edit. Passed in rather than recomputed so one run reads the folder
    once.
    """
    os.makedirs(OUT, exist_ok=True)
    if hand is None:
        hand = hand_edited()
    drawn = 0
    for name, fn in ITEMS.items():
        if name in hand:
            print("art/%-20s hand-edited, not redrawn" % (name + ".png"))
            continue
        img = fn()
        img.save(os.path.join(OUT, "%s.png" % name))
        print("art/%-20s %3dx%-3d" % (name + ".png", img.width, img.height))
        drawn += 1
    return drawn


if __name__ == "__main__":
    print("drew %d items" % make_all())
