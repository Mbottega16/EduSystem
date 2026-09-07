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

from make_art import (LINE, WOOD, WOOD_L, WOOD_D, outline, finish, px, rect,
                      shadow, hand_edited, scale2x)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

# a small shared palette so two dozen items still look like one set
import json
pal_path = os.path.join(os.path.dirname(__file__), 'data', 'palette.json')
try:
    with open(pal_path, 'r') as f:
        _pal = json.load(f)
    STEEL = tuple(_pal.get('STEEL', (132, 138, 148)))
    STEEL_L = tuple(_pal.get('STEEL_L', (170, 176, 186)))
    STEEL_D = tuple(_pal.get('STEEL_D', (92, 96, 106)))
    CLOTH = tuple(_pal.get('CLOTH', (188, 96, 104)))
    CLOTH_L = tuple(_pal.get('CLOTH_L', (216, 128, 134)))
    PAPER = tuple(_pal.get('PAPER', (246, 244, 236)))
    GREEN = tuple(_pal.get('GREEN', (84, 152, 90)))
    GREEN_L = tuple(_pal.get('GREEN_L', (108, 180, 112)))
    BLUE = tuple(_pal.get('BLUE', (96, 150, 206)))
    BLUE_L = tuple(_pal.get('BLUE_L', (140, 186, 226)))
    GOLD = tuple(_pal.get('GOLD', (232, 186, 74)))
    DARK = tuple(_pal.get('DARK', (46, 42, 54)))
except Exception as e:
    print('Failed to load palette.json:', e)
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
    return finish(im)


def draw_beanbag():
    im = _blank(18, 16)
    rect(im, 2, 6, 15, 14, CLOTH)
    rect(im, 3, 4, 14, 7, CLOTH_L)
    rect(im, 5, 3, 12, 4, CLOTH_L)
    rect(im, 2, 13, 15, 14, (150, 70, 80))
    return finish(im)


def draw_bench():
    im = _blank(32, 16)
    rect(im, 1, 5, 30, 8, WOOD)
    rect(im, 1, 5, 30, 6, WOOD_L)
    rect(im, 3, 9, 4, 14, WOOD_D)
    rect(im, 27, 9, 28, 14, WOOD_D)
    rect(im, 5, 10, 26, 11, WOOD_D)
    return finish(im)


def draw_floor_cushion():
    im = _blank(16, 12)
    rect(im, 2, 5, 13, 10, BLUE)
    rect(im, 3, 4, 12, 6, BLUE_L)
    px(im, 8, 7, BLUE_L)
    return finish(im)


# --- surfaces --------------------------------------------------------

def draw_side_table():
    im = _blank(16, 18)
    rect(im, 1, 4, 14, 7, WOOD)
    rect(im, 1, 4, 14, 5, WOOD_L)
    rect(im, 3, 8, 4, 16, WOOD_D)
    rect(im, 11, 8, 12, 16, WOOD_D)
    return finish(im)


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
    return finish(im)


def draw_crate():
    im = _blank(16, 14)
    rect(im, 2, 3, 13, 12, WOOD)
    rect(im, 2, 3, 13, 4, WOOD_L)
    rect(im, 2, 7, 13, 7, WOOD_D)
    rect(im, 7, 5, 8, 11, WOOD_D)
    return finish(im)


def draw_supply_shelf():
    im = _blank(32, 20)
    rect(im, 1, 2, 30, 17, WOOD_D)
    rect(im, 2, 3, 29, 9, WOOD)
    rect(im, 2, 11, 29, 16, WOOD)
    for x in range(4, 28, 5):
        rect(im, x, 4, x + 2, 8, BLUE if (x // 5) % 2 else CLOTH)
        rect(im, x, 12, x + 2, 15, GREEN if (x // 5) % 2 else GOLD)
    return finish(im)


# --- learning --------------------------------------------------------

def draw_globe():
    im = _blank(16, 20)
    rect(im, 4, 3, 11, 11, BLUE)
    rect(im, 5, 4, 7, 6, GREEN)
    rect(im, 8, 7, 10, 9, GREEN)
    rect(im, 4, 3, 11, 3, BLUE_L)
    rect(im, 7, 12, 8, 15, STEEL_D)
    rect(im, 4, 16, 11, 18, WOOD_D)
    return finish(im)


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
    return finish(im)


def draw_microscope():
    im = _blank(16, 20)
    rect(im, 5, 2, 8, 9, STEEL)
    rect(im, 5, 2, 6, 9, STEEL_L)
    rect(im, 4, 10, 11, 11, STEEL_D)
    rect(im, 6, 12, 9, 15, STEEL)
    rect(im, 3, 16, 12, 18, STEEL_D)
    px(im, 9, 4, BLUE_L)
    return finish(im)


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
    return finish(im)


def draw_reading_nook():
    im = _blank(32, 20)
    rect(im, 1, 6, 30, 17, CLOTH)
    rect(im, 2, 4, 29, 8, CLOTH_L)
    rect(im, 3, 2, 11, 6, BLUE)
    rect(im, 20, 2, 28, 6, GREEN)
    rect(im, 1, 16, 30, 17, (150, 70, 80))
    return finish(im)


def draw_maths_tiles():
    im = _blank(16, 14)
    rect(im, 1, 4, 14, 12, WOOD_D)
    for i, (x, c) in enumerate(((2, CLOTH), (6, BLUE), (10, GREEN))):
        rect(im, x, 5, x + 3, 8, c)
        rect(im, x, 9, x + 3, 11, GOLD if i == 1 else STEEL)
    return finish(im)


def draw_music_corner():
    im = _blank(16, 20)
    rect(im, 3, 8, 12, 16, WOOD)
    rect(im, 3, 8, 12, 9, WOOD_L)
    rect(im, 4, 10, 11, 14, DARK)
    for x in range(4, 12, 2):
        rect(im, x, 10, x, 14, PAPER)
    rect(im, 6, 3, 7, 7, DARK)
    rect(im, 6, 2, 9, 3, DARK)
    return finish(im)


# --- comfort ---------------------------------------------------------

def draw_lamp():
    im = _blank(16, 22)
    rect(im, 3, 2, 12, 8, GOLD)
    rect(im, 3, 2, 12, 3, (250, 214, 120))
    rect(im, 7, 9, 8, 17, STEEL_D)
    rect(im, 4, 18, 11, 20, STEEL_D)
    return finish(im)


def draw_water_cooler():
    im = _blank(16, 22)
    rect(im, 4, 1, 11, 8, BLUE_L)
    rect(im, 5, 2, 10, 7, (176, 216, 240))
    rect(im, 3, 9, 12, 19, PAPER)
    rect(im, 3, 9, 12, 10, (220, 220, 214))
    rect(im, 6, 13, 9, 14, STEEL_D)
    return finish(im)


def draw_radiator():
    im = _blank(32, 16)
    rect(im, 1, 3, 30, 13, STEEL)
    for x in range(3, 30, 3):
        rect(im, x, 4, x + 1, 12, STEEL_L)
    rect(im, 1, 13, 30, 14, STEEL_D)
    return finish(im)


def draw_coat_hooks():
    im = _blank(32, 18)
    rect(im, 1, 2, 30, 5, WOOD)
    rect(im, 1, 2, 30, 2, WOOD_L)
    for i, x in enumerate((5, 13, 21, 27)):
        rect(im, x, 6, x + 1, 8, STEEL_D)
        if i % 2 == 0:
            rect(im, x - 2, 7, x + 3, 15, CLOTH if i == 0 else GREEN)
    return finish(im)


# --- decor -----------------------------------------------------------

def draw_wall_clock():
    im = _blank(14, 14)
    rect(im, 1, 1, 12, 12, PAPER)
    rect(im, 2, 2, 11, 11, (230, 228, 220))
    rect(im, 6, 3, 6, 6, DARK)
    rect(im, 6, 6, 9, 6, DARK)
    return finish(im)


def draw_alphabet_frieze():
    im = _blank(32, 12)
    rect(im, 1, 1, 30, 10, PAPER)
    for i, x in enumerate(range(3, 30, 4)):
        c = (CLOTH, BLUE, GREEN, GOLD)[i % 4]
        rect(im, x, 3, x + 2, 8, c)
    return finish(im)


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
    return finish(im)


def draw_class_banner():
    im = _blank(24, 16)
    rect(im, 1, 1, 22, 3, WOOD_D)
    rect(im, 2, 4, 21, 12, CLOTH)
    rect(im, 4, 6, 19, 7, PAPER)
    rect(im, 4, 9, 15, 10, PAPER)
    for x in range(2, 22, 4):
        rect(im, x, 13, x + 1, 14, CLOTH)
    return finish(im)


def draw_pot_of_pens():
    im = _blank(14, 16)
    rect(im, 4, 7, 10, 14, STEEL)
    rect(im, 4, 7, 5, 14, STEEL_L)
    for i, x in enumerate((5, 7, 9)):
        c = (CLOTH, BLUE, GREEN)[i]
        rect(im, x, 3 + i, x, 7, c)
    return finish(im)


# --- consumables -------------------------------------------------------
# Bought and used the same day rather than placed, so these are held
# objects rather than room furniture -- smaller, and drawn without the
# floor shadow every placed item gets (_blank() adds one; these skip it
# by building the canvas directly instead).

def draw_coffee():
    im = Image.new("RGBA", (14, 16), (0, 0, 0, 0))
    MUG = (216, 210, 198)
    MUG_D = (180, 172, 158)
    COFFEE = (108, 66, 40)
    rect(im, 3, 7, 10, 14, MUG)
    rect(im, 3, 12, 10, 14, MUG_D)
    rect(im, 4, 7, 9, 8, COFFEE)
    rect(im, 10, 8, 12, 11, MUG)
    px(im, 5, 3, (210, 208, 204))
    px(im, 8, 2, (210, 208, 204))
    px(im, 5, 5, (228, 226, 222))
    px(im, 8, 4, (228, 226, 222))
    return finish(im)


def draw_sticker_chart():
    im = _blank(14, 16)
    rect(im, 2, 2, 12, 14, PAPER)
    rect(im, 2, 2, 12, 3, WOOD)
    for i, (x, y) in enumerate(((4, 6), (8, 6), (4, 10), (8, 10))):
        c = (CLOTH, BLUE, GREEN, GOLD)[i]
        rect(im, x, y, x + 1, y + 1, c)
    return finish(im)


def draw_bake_sale():
    im = _blank(14, 16)
    rect(im, 3, 6, 11, 14, (216, 206, 190))
    rect(im, 3, 6, 11, 7, WOOD_D)
    rect(im, 5, 3, 9, 6, WOOD)
    px(im, 6, 10, GOLD)
    px(im, 8, 11, GOLD)
    px(im, 7, 12, GOLD)
    return finish(im)


def draw_photocopies():
    """A short stack of freshly run copies. Three sheets, each offset a
    little from the last, so it reads as loose paper fanned out rather
    than one solid block -- the flaw the old single-block version had."""
    im = _blank(16, 16)
    rect(im, 4, 2, 13, 12, (222, 218, 208))     # back sheet, peeking out
    rect(im, 3, 3, 12, 13, (232, 230, 222))     # middle sheet
    rect(im, 2, 4, 11, 14, PAPER)               # front sheet
    for y in (6, 8, 10):                        # printed lines on top
        rect(im, 3, y, 9, y, (150, 152, 160))
    rect(im, 3, 12, 6, 12, (150, 152, 160))
    return finish(im)


# --- daily room mess ---------------------------------------------------
# Not a shop item -- these are transient clutter spawned into the room by
# scripts/world/classroom.gd (see mess.gd), not bought or placed by the
# player, so they are deliberately NOT in ITEMS/balance.json below: a row
# there would claim they are purchasable furniture, which they are not.
# No floor shadow either (same reasoning as the consumables above): a
# flat stain or a scattered pile reads as ON the floor, not standing on it.

def draw_mess_trash():
    """Litter, not two lenses. (Sept 2026: the old shape was two paper
    balls of the same size, side by side at the same height, with a
    wrapper bridging them -- at gameplay scale that is a pair of
    spectacles, and the art pass's rim light only sharpened the misread.
    The fix is silhouette, not shading. A flat dropped sheet reads as
    paper more reliably than any blob does, so the mess is now one flat
    sheet with a folded corner, one crumpled ball creased enough not to
    read as round, and one torn strip set apart. Sheet and ball touch on
    purpose: finish() outlines each island of alpha separately, so three
    detached blobs come back as three ringed pebbles.)"""
    im = Image.new("RGBA", (18, 12), (0, 0, 0, 0))
    PAPER_M = (232, 230, 222)
    PAPER_D = (214, 210, 200)

    # the flat sheet -- stepped edges, because creased paper is angular
    rect(im, 1, 8, 9, 10, PAPER)
    rect(im, 2, 7, 8, 7, PAPER)
    rect(im, 4, 6, 6, 6, PAPER)
    px(im, 1, 6, PAPER)               # a corner lifted off the floor --
    px(im, 2, 7, PAPER)               # the one cue that says "sheet"
    rect(im, 7, 8, 9, 9, PAPER_D)     # a corner flipped over on itself
    px(im, 6, 9, PAPER_D)
    px(im, 3, 8, PAPER_M)             # a crease catching the light
    px(im, 4, 9, PAPER_M)
    px(im, 5, 8, PAPER_M)

    # the crumpled ball, touching the sheet so one outline wraps the mess
    rect(im, 10, 5, 15, 9, PAPER)
    px(im, 11, 4, PAPER)              # a notched top, so the ball does not
    rect(im, 13, 4, 14, 4, PAPER)     # dome over into a cloud
    px(im, 15, 3, PAPER)
    px(im, 16, 7, PAPER)
    px(im, 16, 8, PAPER)
    px(im, 12, 6, PAPER_D)            # creases -- crumpled, not spherical
    px(im, 13, 7, PAPER_D)
    px(im, 11, 8, PAPER_D)
    px(im, 14, 5, PAPER_M)
    px(im, 13, 8, PAPER_M)

    # a torn strip, set clear of both -- litter is scattered, not stacked
    rect(im, 12, 11, 16, 11, PAPER_M)

    return finish(im)


def draw_mess_spill():
    im = Image.new("RGBA", (18, 10), (0, 0, 0, 0))
    PUDDLE = (120, 168, 210, 165)
    PUDDLE_L = (176, 214, 236, 150)
    rect(im, 3, 5, 14, 8, PUDDLE)
    rect(im, 5, 4, 11, 5, PUDDLE)
    rect(im, 1, 6, 3, 7, PUDDLE)
    rect(im, 14, 6, 16, 7, PUDDLE)
    rect(im, 6, 5, 9, 6, PUDDLE_L)     # a highlight, so it reads as wet
    return im     # no outline() -- a hard ink border would kill the puddle


# --- task 2 batch (21 items, integrated per docs/AUTONOMOUS_TASKLIST.md
# A1) -------------------------------------------------------------------
# Placeholder pixel art, same drawing convention as everything above it --
# NOT the AI-generated art from docs/AI_ART_PROMPTS.md, which supersedes
# these once it exists. Kept simple on purpose since it is expected to be
# replaced, not because the item matters less.

def draw_rocking_chair():
    im = _blank(16, 20)
    rect(im, 4, 6, 12, 9, WOOD)
    rect(im, 4, 6, 12, 7, WOOD_L)
    rect(im, 4, 9, 5, 16, WOOD_D)
    rect(im, 11, 9, 12, 16, WOOD_D)
    rect(im, 2, 17, 14, 18, WOOD_D)
    return finish(im)


def draw_pouf():
    im = _blank(16, 12)
    rect(im, 3, 5, 12, 10, CLOTH)
    rect(im, 4, 4, 11, 6, CLOTH_L)
    return finish(im)


def draw_window_seat():
    im = _blank(32, 16)
    rect(im, 1, 5, 30, 10, BLUE)
    rect(im, 1, 5, 30, 6, BLUE_L)
    rect(im, 3, 11, 4, 14, WOOD_D)
    rect(im, 27, 11, 28, 14, WOOD_D)
    return finish(im)


def draw_low_shelf():
    im = _blank(16, 14)
    rect(im, 1, 4, 14, 12, WOOD)
    rect(im, 1, 4, 14, 5, WOOD_L)
    rect(im, 1, 8, 14, 8, WOOD_D)
    rect(im, 3, 5, 5, 7, CLOTH)
    rect(im, 7, 9, 9, 11, BLUE)
    return finish(im)


def draw_display_rack():
    im = _blank(28, 20)
    rect(im, 1, 2, 26, 17, WOOD_D)
    rect(im, 2, 3, 25, 8, WOOD)
    rect(im, 2, 10, 25, 15, WOOD)
    rect(im, 4, 4, 8, 7, GREEN)
    rect(im, 12, 4, 16, 7, BLUE)
    rect(im, 20, 4, 23, 7, CLOTH)
    return finish(im)


def draw_filing_cart():
    im = _blank(16, 18)
    rect(im, 2, 3, 13, 15, STEEL)
    rect(im, 2, 5, 13, 6, STEEL_D)
    rect(im, 2, 9, 13, 10, STEEL_D)
    rect(im, 2, 13, 13, 14, STEEL_D)
    px(im, 3, 16, DARK)
    px(im, 12, 16, DARK)
    return finish(im)


def draw_sand_timer():
    im = _blank(12, 16)
    rect(im, 3, 2, 8, 3, WOOD)
    rect(im, 3, 12, 8, 13, WOOD)
    rect(im, 4, 4, 7, 10, (222, 216, 200))
    rect(im, 5, 6, 6, 8, GOLD)
    return finish(im)


def draw_vocab_board():
    im = _blank(28, 16)
    rect(im, 1, 2, 26, 13, PAPER)
    rect(im, 1, 2, 26, 3, WOOD)
    rect(im, 3, 5, 11, 6, DARK)
    rect(im, 3, 8, 15, 9, DARK)
    rect(im, 3, 11, 9, 12, DARK)
    return finish(im)


def draw_shape_sorter():
    im = _blank(16, 14)
    rect(im, 2, 6, 13, 12, WOOD)
    rect(im, 3, 3, 6, 6, BLUE)
    rect(im, 8, 3, 11, 6, GREEN)
    px(im, 9, 8, GOLD)
    return finish(im)


def draw_terrarium():
    im = _blank(14, 18)
    rect(im, 2, 4, 11, 16, (200, 226, 232))
    rect(im, 2, 12, 11, 16, WOOD_D)
    rect(im, 4, 8, 6, 12, GREEN)
    rect(im, 7, 6, 8, 12, GREEN_L)
    return finish(im)


def draw_web_of_life():
    im = _blank(28, 16)
    rect(im, 1, 2, 26, 13, PAPER)
    rect(im, 1, 2, 26, 3, WOOD)
    rect(im, 8, 7, 18, 7, DARK)
    rect(im, 13, 4, 13, 10, DARK)
    px(im, 9, 5, DARK)
    px(im, 17, 5, DARK)
    px(im, 9, 9, DARK)
    px(im, 17, 9, DARK)
    return finish(im)


def draw_sound_cards():
    im = _blank(14, 12)
    rect(im, 2, 3, 9, 10, PAPER)
    rect(im, 4, 4, 11, 11, PAPER)
    rect(im, 6, 6, 9, 9, CLOTH)
    return finish(im)


def draw_hammock_chair():
    im = _blank(18, 20)
    rect(im, 1, 2, 16, 3, STEEL)
    rect(im, 4, 8, 13, 15, CLOTH)
    rect(im, 5, 7, 12, 9, CLOTH_L)
    px(im, 4, 3, STEEL_D)
    px(im, 13, 3, STEEL_D)
    return finish(im)


def draw_ottoman():
    im = _blank(14, 10)
    rect(im, 2, 3, 11, 8, GOLD)
    rect(im, 2, 3, 11, 4, (240, 206, 110))
    return finish(im)


def draw_desk_fan():
    im = _blank(14, 16)
    rect(im, 5, 10, 8, 15, STEEL_D)
    rect(im, 3, 3, 10, 10, STEEL_L)
    px(im, 6, 6, STEEL_D)
    px(im, 7, 6, STEEL_D)
    return finish(im)


def draw_paper_mobile():
    im = _blank(16, 20)
    rect(im, 7, 1, 8, 6, DARK)
    rect(im, 2, 6, 6, 6, DARK)
    rect(im, 9, 6, 13, 6, DARK)
    rect(im, 2, 7, 6, 11, CLOTH)
    rect(im, 9, 7, 13, 12, BLUE)
    rect(im, 6, 12, 9, 16, GREEN)
    return finish(im)


def draw_chalk_border():
    im = _blank(30, 12)
    rect(im, 1, 2, 28, 9, (60, 96, 70))
    rect(im, 1, 2, 28, 2, WOOD)
    rect(im, 1, 9, 28, 9, WOOD)
    px(im, 5, 5, PAPER)
    px(im, 13, 5, PAPER)
    return finish(im)


def draw_state_flag():
    im = _blank(14, 20)
    rect(im, 6, 2, 7, 18, WOOD)
    rect(im, 7, 3, 13, 9, BLUE)
    rect(im, 8, 5, 9, 6, GOLD)
    return finish(im)


def draw_vote_box():
    im = _blank(16, 14)
    rect(im, 2, 5, 13, 12, WOOD)
    rect(im, 2, 5, 13, 6, WOOD_L)
    rect(im, 6, 4, 9, 5, DARK)
    return finish(im)


def draw_season_wheel():
    im = _blank(16, 16)
    rect(im, 2, 2, 13, 13, WOOD)
    rect(im, 3, 3, 7, 7, GREEN)
    rect(im, 8, 3, 12, 7, GOLD)
    rect(im, 3, 8, 7, 12, (200, 220, 236))
    rect(im, 8, 8, 12, 12, (200, 130, 70))
    return finish(im)


def draw_duty_roster():
    im = _blank(16, 18)
    rect(im, 2, 2, 13, 15, PAPER)
    rect(im, 2, 2, 13, 3, WOOD)
    rect(im, 4, 5, 11, 6, DARK)
    rect(im, 4, 8, 11, 9, DARK)
    rect(im, 4, 11, 11, 12, DARK)
    return finish(im)


# --- subject shelf: each helps one strand -----------------------------

def draw_number_line():
    im = _blank(30, 10)
    rect(im, 1, 4, 28, 6, PAPER)
    rect(im, 1, 4, 28, 4, WOOD)
    for x in range(3, 28, 4):
        px(im, x, 6, DARK)
        px(im, x, 7, DARK)
    rect(im, 5, 1, 7, 3, BLUE)
    rect(im, 13, 1, 15, 3, GREEN)
    rect(im, 21, 1, 23, 3, GOLD)
    return finish(im)


def draw_bug_viewer():
    im = _blank(14, 16)
    rect(im, 3, 4, 10, 14, (204, 228, 234))
    rect(im, 3, 3, 10, 4, STEEL)
    rect(im, 3, 13, 10, 14, WOOD_D)
    rect(im, 5, 7, 8, 10, GREEN)
    px(im, 6, 8, DARK)
    return finish(im)


def draw_rhyme_chart():
    im = _blank(16, 18)
    rect(im, 2, 2, 13, 15, PAPER)
    rect(im, 2, 2, 13, 3, WOOD)
    rect(im, 9, 5, 11, 13, CLOTH)
    for y in range(5, 13, 3):
        rect(im, 4, y, 8, y + 1, DARK)
    return finish(im)


def draw_map_corner():
    im = _blank(30, 18)
    rect(im, 1, 1, 28, 15, (216, 226, 236))
    rect(im, 1, 1, 28, 2, WOOD)
    rect(im, 4, 5, 12, 11, GREEN)
    rect(im, 15, 4, 24, 9, GREEN_L)
    rect(im, 17, 11, 22, 13, GOLD)
    px(im, 20, 6, CLOTH)
    return finish(im)


# --- subject shelf, second wave (ten-commits.md step 8: one more per
# strand, so specialising a room is a real choice rather than one fixed
# shelf) -- a deliberately DIFFERENT silhouette from each strand's first
# item, so the two never read as the same prop recoloured.

def draw_word_wall():
    im = _blank(16, 18)
    rect(im, 2, 2, 13, 15, PAPER)
    rect(im, 2, 2, 13, 3, WOOD)
    for y in range(5, 14, 3):
        rect(im, 4, y, 11, y + 1, DARK)
    return finish(im)


def draw_ten_frame():
    im = _blank(30, 14)
    rect(im, 1, 2, 28, 11, WOOD_D)
    for row in range(2):
        for col in range(5):
            x0 = 2 + col * 5
            y0 = 3 + row * 5
            rect(im, x0, y0, x0 + 4, y0 + 4, PAPER)
            if (row + col) % 2 == 0:
                rect(im, x0 + 1, y0 + 1, x0 + 3, y0 + 3, GOLD)
    return finish(im)


def draw_rock_tray():
    im = _blank(16, 12)
    rect(im, 1, 5, 14, 10, WOOD_D)
    rect(im, 1, 5, 14, 6, WOOD)
    for x, c in ((4, STEEL), (8, (150, 120, 90)), (11, STEEL_D)):
        rect(im, x, 6, x + 2, 8, c)
    return finish(im)


def draw_timeline_wall():
    im = _blank(30, 10)
    rect(im, 1, 4, 28, 5, DARK)
    for x in range(4, 28, 6):
        rect(im, x, 2, x + 1, 7, GOLD)
    return finish(im)


MESS_ITEMS = {"mess_trash": draw_mess_trash, "mess_spill": draw_mess_spill}


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
    # consumables
    "coffee": draw_coffee, "sticker_chart": draw_sticker_chart,
    "bake_sale": draw_bake_sale, "photocopies": draw_photocopies,
    # task 2 batch -- seating
    "rocking_chair": draw_rocking_chair, "pouf": draw_pouf,
    "window_seat": draw_window_seat,
    # task 2 batch -- surfaces
    "low_shelf": draw_low_shelf, "display_rack": draw_display_rack,
    "filing_cart": draw_filing_cart,
    # task 2 batch -- learning
    "sand_timer": draw_sand_timer, "vocab_board": draw_vocab_board,
    "shape_sorter": draw_shape_sorter, "terrarium": draw_terrarium,
    "web_of_life": draw_web_of_life, "sound_cards": draw_sound_cards,
    # task 2 batch -- comfort
    "hammock_chair": draw_hammock_chair, "ottoman": draw_ottoman,
    "desk_fan": draw_desk_fan,
    # task 2 batch -- decor
    "paper_mobile": draw_paper_mobile, "chalk_border": draw_chalk_border,
    "state_flag": draw_state_flag, "vote_box": draw_vote_box,
    "season_wheel": draw_season_wheel, "duty_roster": draw_duty_roster,
    # subject shelf -- one strand each
    "number_line": draw_number_line, "bug_viewer": draw_bug_viewer,
    "rhyme_chart": draw_rhyme_chart, "map_corner": draw_map_corner,
    # subject shelf, second wave -- a second item per strand
    "word_wall": draw_word_wall, "ten_frame": draw_ten_frame,
    "rock_tray": draw_rock_tray, "timeline_wall": draw_timeline_wall,
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
        # Drawn at the original small resolution, same as furniture in
        # make_art.py -- scale2x doubles it here with real diagonal-edge
        # detail rather than a blur, and this is the ONE place every
        # purchasable item's art actually gets written.
        img = scale2x(fn())
        img.save(os.path.join(OUT, "%s.png" % name))
        print("art/%-20s %3dx%-3d" % (name + ".png", img.width, img.height))
        drawn += 1
    # Room mess: same treatment (hand-edit still wins, same 2x scale-up),
    # just not counted against ITEMS/balance.json since these are not
    # purchasable.
    for name, fn in MESS_ITEMS.items():
        if name in hand:
            print("art/%-20s hand-edited, not redrawn" % (name + ".png"))
            continue
        img = scale2x(fn())
        img.save(os.path.join(OUT, "%s.png" % name))
        print("art/%-20s %3dx%-3d" % (name + ".png", img.width, img.height))
        drawn += 1
    return drawn


if __name__ == "__main__":
    print("drew %d items" % make_all())
