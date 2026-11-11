#!/usr/bin/env python3
"""Generate 20x20 pixel-art icons for all 11 cheats in EduSystem.

Icons match the classroom palette and LimeZu visual density:
1. all:       Golden Key / Master Tool
2. coins:     Overflowing Coin Sack
3. teacher:   Graduation Cap & Star
4. students:  Golden Apple & A+ Slate
5. ready:     Rolled Diploma
6. furnish:   Bookshelf & Globe
7. enrol:     Group of Student Desks
8. grow:      Expanding Blueprint Arrows
9. day:       Sun & Desk Calendar
10. term:     School Bell Ringing
11. boss:     Wax-Sealed Exam Scroll
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

# Common palette tokens
TRANS = (0, 0, 0, 0)
DARK_LINE = (35, 28, 24, 255)
GOLD_HI = (255, 240, 130, 255)
GOLD_MID = (240, 185, 45, 255)
GOLD_SHADOW = (170, 115, 25, 255)
CREAM_HI = (252, 250, 242, 255)
CREAM_MID = (242, 234, 212, 255)
CREAM_SHADOW = (205, 190, 160, 255)
WOOD_HI = (215, 175, 115, 255)
WOOD_MID = (175, 125, 70, 255)
WOOD_SHADOW = (120, 75, 35, 255)
RED_HI = (245, 95, 95, 255)
RED_MID = (215, 40, 40, 255)
RED_SHADOW = (145, 20, 20, 255)
BLUE_HI = (120, 180, 245, 255)
BLUE_MID = (55, 120, 210, 255)
BLUE_SHADOW = (30, 65, 140, 255)
GREEN_HI = (140, 215, 90, 255)
GREEN_MID = (75, 165, 50, 255)
GREEN_SHADOW = (40, 105, 30, 255)
WHITE = (255, 255, 255, 255)


def new_icon() -> Image.Image:
    return Image.new("RGBA", (20, 20), TRANS)


def set_pixel(im: Image.Image, x: int, y: int, color: tuple) -> None:
    if 0 <= x < 20 and 0 <= y < 20:
        im.putpixel((x, y), color)


def fill_rect(im: Image.Image, x0: int, y0: int, x1: int, y1: int, color: tuple) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            set_pixel(im, x, y, color)


def draw_all() -> Image.Image:
    """Golden Key / Master Tool"""
    im = new_icon()
    # Key bow (ring) top-left
    # Outer circle around (6, 6)
    ring_points = [
        (5,3),(6,3),(7,3),
        (4,4),(8,4),
        (3,5),(9,5),
        (3,6),(9,6),
        (3,7),(9,7),
        (4,8),(8,8),
        (5,9),(6,9),(7,9)
    ]
    for x, y in ring_points:
        set_pixel(im, x, y, GOLD_MID)
    # Highlights & shadows on bow
    set_pixel(im, 5, 3, GOLD_HI)
    set_pixel(im, 6, 3, GOLD_HI)
    set_pixel(im, 4, 4, GOLD_HI)
    set_pixel(im, 3, 5, GOLD_HI)
    set_pixel(im, 8, 8, GOLD_SHADOW)
    set_pixel(im, 7, 9, GOLD_SHADOW)
    set_pixel(im, 6, 9, GOLD_SHADOW)

    # Key shaft diagonally to bottom right
    shaft = [(7,7),(8,8),(9,9),(10,10),(11,11),(12,12),(13,13),(14,14),(15,15)]
    for x, y in shaft:
        set_pixel(im, x, y, GOLD_MID)
        set_pixel(im, x, y-1, GOLD_HI)
        set_pixel(im, x-1, y, GOLD_SHADOW)

    # Key bits / teeth at bottom right
    teeth = [
        (13,15),(14,16), # tooth 1
        (15,13),(16,14), # tooth 2
        (16,16)          # end tip
    ]
    for x, y in teeth:
        set_pixel(im, x, y, GOLD_MID)
    set_pixel(im, 14, 16, GOLD_SHADOW)
    set_pixel(im, 16, 14, GOLD_HI)

    # Sparkle glints
    sparkles = [(13,3), (12,4), (13,4), (14,4), (13,5), # sparkle top right
                (3,13), (2,14), (3,14), (4,14), (3,15)]  # sparkle bottom left
    for x, y in sparkles:
        set_pixel(im, x, y, GOLD_HI)
    set_pixel(im, 13, 4, WHITE)
    set_pixel(im, 3, 14, WHITE)
    return im


def draw_coins() -> Image.Image:
    """Overflowing Coin Sack"""
    im = new_icon()
    # Burlap sack body
    for y in range(8, 18):
        hw = 3 if y == 8 else (5 if y in (9, 17) else 6)
        fill_rect(im, 10 - hw, y, 10 + hw, y, (190, 145, 90, 255))
    # Sack shade & highlight
    for y in range(9, 17):
        set_pixel(im, 4, y, (220, 175, 120, 255))
        set_pixel(im, 16, y, (140, 95, 50, 255))
    fill_rect(im, 5, 17, 15, 17, (130, 85, 45, 255))

    # Tied neck cord
    fill_rect(im, 7, 7, 13, 7, (95, 60, 30, 255))

    # Gold coins overflowing top
    coins = [
        (8,4),(9,4),(10,4),(11,4),
        (7,5),(8,5),(9,5),(10,5),(11,5),(12,5),
        (6,6),(7,6),(8,6),(9,6),(10,6),(11,6),(12,6),(13,6)
    ]
    for x, y in coins:
        set_pixel(im, x, y, GOLD_MID)
    # Coin highlights
    set_pixel(im, 9, 4, GOLD_HI)
    set_pixel(im, 8, 5, GOLD_HI)
    set_pixel(im, 11, 5, GOLD_HI)
    set_pixel(im, 7, 6, GOLD_HI)
    set_pixel(im, 10, 6, GOLD_HI)
    # Spill coins on side
    set_pixel(im, 4, 7, GOLD_MID)
    set_pixel(im, 3, 8, GOLD_HI)
    set_pixel(im, 16, 7, GOLD_MID)
    set_pixel(im, 17, 8, GOLD_SHADOW)

    # Coin symbol stamped on sack face ($ mark or gold coin)
    fill_rect(im, 9, 11, 11, 14, GOLD_MID)
    set_pixel(im, 10, 10, GOLD_MID)
    set_pixel(im, 10, 15, GOLD_MID)
    set_pixel(im, 10, 12, GOLD_HI)
    return im


def draw_teacher() -> Image.Image:
    """Graduation Cap & Star"""
    im = new_icon()
    # Mortarboard cap diamond
    rows = [
        (9, 11, 5),
        (7, 13, 6),
        (5, 15, 7),
        (3, 17, 8),
        (5, 15, 9),
        (7, 13, 10),
        (9, 11, 11),
    ]
    for x0, x1, y in rows:
        fill_rect(im, x0, y, x1, y, (45, 48, 58, 255))
    # Cap highlight on top edges
    fill_rect(im, 9, 5, 11, 5, (85, 95, 115, 255))
    set_pixel(im, 7, 6, (85, 95, 115, 255))
    set_pixel(im, 5, 7, (85, 95, 115, 255))
    set_pixel(im, 3, 8, (85, 95, 115, 255))

    # Skullcap underneath
    fill_rect(im, 7, 11, 13, 14, (30, 32, 40, 255))
    fill_rect(im, 8, 15, 12, 15, (25, 26, 32, 255))

    # Center button
    set_pixel(im, 10, 8, GOLD_HI)

    # Gold tassel hanging down left
    tassel = [(9, 9), (8, 10), (7, 11), (6, 12), (6, 13), (6, 14), (5, 14), (7, 14)]
    for x, y in tassel:
        set_pixel(im, x, y, GOLD_MID)
    set_pixel(im, 6, 13, GOLD_HI)

    # Gold rank star at top right (15, 3)
    star = [(15, 2), (14, 3), (15, 3), (16, 3), (15, 4)]
    for x, y in star:
        set_pixel(im, x, y, GOLD_MID)
    set_pixel(im, 15, 3, WHITE)
    return im


def draw_students() -> Image.Image:
    """Golden Apple & A+ Slate"""
    im = new_icon()
    # Slate board in background (left side)
    fill_rect(im, 2, 4, 11, 15, WOOD_MID)
    fill_rect(im, 3, 5, 10, 14, (28, 52, 44, 255)) # slate dark green
    # Chalk "A+" on slate
    # 'A'
    for y in range(7, 12):
        set_pixel(im, 4, y, WHITE)
        set_pixel(im, 6, y, WHITE)
    set_pixel(im, 5, 6, WHITE)
    set_pixel(im, 5, 9, WHITE)
    # '+'
    set_pixel(im, 8, 8, GOLD_HI)
    set_pixel(im, 8, 9, GOLD_HI)
    set_pixel(im, 8, 10, GOLD_HI)
    set_pixel(im, 7, 9, GOLD_HI)
    set_pixel(im, 9, 9, GOLD_HI)

    # Shiny Red Apple on right foreground
    # Apple body
    apple_rows = [
        (13, 16, 10),
        (12, 17, 11),
        (12, 17, 12),
        (12, 17, 13),
        (12, 17, 14),
        (13, 16, 15),
        (14, 15, 16)
    ]
    for x0, x1, y in apple_rows:
        fill_rect(im, x0, y, x1, y, RED_MID)
    # Apple highlight & shadow
    set_pixel(im, 13, 11, RED_HI)
    set_pixel(im, 13, 12, RED_HI)
    set_pixel(im, 14, 11, WHITE) # glossy shine
    fill_rect(im, 13, 15, 16, 15, RED_SHADOW)
    # Stem & Leaf
    set_pixel(im, 14, 9, (90, 55, 30, 255))
    set_pixel(im, 14, 8, (90, 55, 30, 255))
    set_pixel(im, 15, 8, GREEN_MID)
    set_pixel(im, 16, 8, GREEN_HI)
    set_pixel(im, 16, 9, GREEN_MID)
    return im


def draw_ready() -> Image.Image:
    """Rolled Diploma / Graduation Scroll"""
    im = new_icon()
    # Scroll rolled diagonally from (3, 16) to (16, 3)
    body = [
        (13, 4), (14, 4), (15, 4),
        (11, 5), (12, 5), (13, 5), (14, 5),
        (9, 6), (10, 6), (11, 6), (12, 6), (13, 6),
        (8, 7), (9, 7), (10, 7), (11, 7), (12, 7),
        (7, 8), (8, 8), (9, 8), (10, 8), (11, 8),
        (6, 9), (7, 9), (8, 9), (9, 9), (10, 9),
        (5, 10), (6, 10), (7, 10), (8, 10), (9, 10),
        (4, 11), (5, 11), (6, 11), (7, 11), (8, 11),
        (3, 12), (4, 12), (5, 12), (6, 12), (7, 12),
        (3, 13), (4, 13), (5, 13), (6, 13),
        (3, 14), (4, 14), (5, 14)
    ]
    for x, y in body:
        set_pixel(im, x, y, CREAM_MID)

    # Highlight top edge
    hi = [(14, 3), (15, 3), (12, 4), (10, 5), (8, 6), (7, 7), (5, 9), (4, 10), (3, 11)]
    for x, y in hi:
        set_pixel(im, x, y, CREAM_HI)

    # Shadow bottom edge
    sha = [(15, 5), (14, 6), (13, 7), (11, 9), (10, 10), (8, 12), (7, 13), (5, 15), (4, 15)]
    for x, y in sha:
        set_pixel(im, x, y, CREAM_SHADOW)

    # Curl roll circles at ends
    fill_rect(im, 15, 2, 17, 4, CREAM_MID)
    set_pixel(im, 16, 3, (160, 145, 125, 255))
    fill_rect(im, 2, 14, 4, 16, CREAM_MID)
    set_pixel(im, 3, 15, (160, 145, 125, 255))

    # Red ribbon wrapped around center
    ribbon = [
        (10, 8), (11, 8),
        (9, 9), (10, 9),
        (8, 10), (9, 10),
        (7, 11), (8, 11)
    ]
    for x, y in ribbon:
        set_pixel(im, x, y, RED_MID)
    # Ribbon bow tails hanging down
    fill_rect(im, 10, 11, 11, 12, RED_MID)
    set_pixel(im, 11, 13, RED_SHADOW)
    fill_rect(im, 9, 12, 10, 14, RED_MID)
    set_pixel(im, 10, 15, RED_SHADOW)
    set_pixel(im, 9, 9, RED_HI)
    return im


def draw_furnish() -> Image.Image:
    """Bookshelf & Globe"""
    im = new_icon()
    # Bookshelf frame
    fill_rect(im, 3, 3, 16, 17, WOOD_MID)
    fill_rect(im, 4, 4, 15, 10, (65, 45, 30, 255))  # top shelf cavity
    fill_rect(im, 4, 12, 15, 16, (65, 45, 30, 255)) # bottom shelf cavity
    # Shelf middle divider
    fill_rect(im, 3, 11, 16, 11, WOOD_HI)

    # Miniature Globe on top shelf (left/center)
    # Globe stand
    set_pixel(im, 7, 9, GOLD_SHADOW)
    set_pixel(im, 8, 9, GOLD_SHADOW)
    set_pixel(im, 9, 9, GOLD_SHADOW)
    set_pixel(im, 8, 8, GOLD_MID)
    # Globe ball
    fill_rect(im, 6, 5, 9, 7, BLUE_MID)
    set_pixel(im, 6, 5, BLUE_HI)
    set_pixel(im, 8, 6, GREEN_HI)
    set_pixel(im, 7, 7, GREEN_MID)

    # Books on bottom shelf
    # Book 1: Red
    fill_rect(im, 5, 12, 6, 16, RED_MID)
    set_pixel(im, 5, 12, RED_HI)
    # Book 2: Blue
    fill_rect(im, 7, 13, 8, 16, BLUE_MID)
    set_pixel(im, 7, 13, BLUE_HI)
    # Book 3: Green (tilted)
    fill_rect(im, 9, 12, 10, 16, GREEN_MID)
    set_pixel(im, 9, 12, GREEN_HI)
    # Book 4: Gold
    fill_rect(im, 11, 13, 12, 16, GOLD_MID)
    set_pixel(im, 11, 13, GOLD_HI)
    # Book 5: Cream
    fill_rect(im, 13, 14, 14, 16, CREAM_MID)
    return im


def draw_enrol() -> Image.Image:
    """Group of Student Desks"""
    im = new_icon()
    # Rear desk
    fill_rect(im, 4, 4, 11, 7, WOOD_MID)
    fill_rect(im, 4, 4, 11, 4, WOOD_HI)
    set_pixel(im, 4, 8, (90, 95, 105, 255))
    set_pixel(im, 11, 8, (90, 95, 105, 255))
    # Rear chair
    fill_rect(im, 6, 2, 9, 3, WOOD_SHADOW)

    # Front-left desk
    fill_rect(im, 2, 10, 9, 13, WOOD_MID)
    fill_rect(im, 2, 10, 9, 10, WOOD_HI)
    # Front-left legs
    fill_rect(im, 2, 14, 2, 16, (90, 95, 105, 255))
    fill_rect(im, 9, 14, 9, 16, (90, 95, 105, 255))
    # Front-left chair back
    fill_rect(im, 4, 8, 7, 9, WOOD_MID)

    # Front-right desk
    fill_rect(im, 10, 12, 17, 15, WOOD_MID)
    fill_rect(im, 10, 12, 17, 12, WOOD_HI)
    # Front-right legs
    fill_rect(im, 10, 16, 10, 18, (90, 95, 105, 255))
    fill_rect(im, 17, 16, 17, 18, (90, 95, 105, 255))
    # Front-right chair back
    fill_rect(im, 12, 10, 15, 11, WOOD_MID)

    # Yellow pencils on desks
    set_pixel(im, 5, 11, GOLD_HI)
    set_pixel(im, 6, 11, GOLD_MID)
    set_pixel(im, 13, 13, GOLD_HI)
    set_pixel(im, 14, 13, GOLD_MID)
    return im


def draw_grow() -> Image.Image:
    """Expanding Blueprint Arrows"""
    im = new_icon()
    # Blueprint grid base
    fill_rect(im, 2, 2, 17, 17, (35, 75, 145, 255))
    # Grid lines
    for x in (5, 9, 13):
        for y in range(3, 17):
            set_pixel(im, x, y, (55, 105, 180, 255))
    for y in (5, 9, 13):
        for x in range(3, 17):
            set_pixel(im, x, y, (55, 105, 180, 255))
    # Blueprint border
    for x in range(2, 18):
        set_pixel(im, x, 2, (80, 130, 210, 255))
        set_pixel(im, x, 17, (25, 55, 110, 255))
    for y in range(2, 18):
        set_pixel(im, 2, y, (80, 130, 210, 255))
        set_pixel(im, 17, y, (25, 55, 110, 255))

    # Center hub
    fill_rect(im, 9, 9, 10, 10, GOLD_HI)

    # 4 Expanding diagonal arrows
    # Top-Left Arrow
    tl_shaft = [(8, 8), (7, 7), (6, 6), (5, 5)]
    for x, y in tl_shaft:
        set_pixel(im, x, y, WHITE)
    set_pixel(im, 4, 4, WHITE)
    set_pixel(im, 4, 5, WHITE)
    set_pixel(im, 4, 6, WHITE)
    set_pixel(im, 5, 4, WHITE)
    set_pixel(im, 6, 4, WHITE)

    # Top-Right Arrow
    tr_shaft = [(11, 8), (12, 7), (13, 6), (14, 5)]
    for x, y in tr_shaft:
        set_pixel(im, x, y, WHITE)
    set_pixel(im, 15, 4, WHITE)
    set_pixel(im, 14, 4, WHITE)
    set_pixel(im, 13, 4, WHITE)
    set_pixel(im, 15, 5, WHITE)
    set_pixel(im, 15, 6, WHITE)

    # Bottom-Left Arrow
    bl_shaft = [(8, 11), (7, 12), (6, 13), (5, 14)]
    for x, y in bl_shaft:
        set_pixel(im, x, y, WHITE)
    set_pixel(im, 4, 15, WHITE)
    set_pixel(im, 4, 14, WHITE)
    set_pixel(im, 4, 13, WHITE)
    set_pixel(im, 5, 15, WHITE)
    set_pixel(im, 6, 15, WHITE)

    # Bottom-Right Arrow
    br_shaft = [(11, 11), (12, 12), (13, 13), (14, 14)]
    for x, y in br_shaft:
        set_pixel(im, x, y, WHITE)
    set_pixel(im, 15, 15, WHITE)
    set_pixel(im, 15, 14, WHITE)
    set_pixel(im, 15, 13, WHITE)
    set_pixel(im, 14, 15, WHITE)
    set_pixel(im, 13, 15, WHITE)
    return im


def draw_day() -> Image.Image:
    """Sun & Desk Calendar"""
    im = new_icon()
    # Golden Sun on top-left
    fill_rect(im, 3, 3, 8, 8, GOLD_MID)
    fill_rect(im, 4, 2, 7, 9, GOLD_MID)
    fill_rect(im, 2, 4, 9, 7, GOLD_MID)
    fill_rect(im, 4, 4, 6, 6, GOLD_HI)
    # Sun rays
    rays = [(5, 0), (5, 1), (5, 10), (0, 5), (1, 5), (10, 5), (2, 2), (8, 2), (2, 8)]
    for x, y in rays:
        set_pixel(im, x, y, (245, 155, 35, 255))

    # Calendar pad on right
    fill_rect(im, 8, 7, 17, 17, CREAM_MID)
    # Red header bar
    fill_rect(im, 8, 6, 17, 8, RED_MID)
    set_pixel(im, 9, 5, (90, 40, 30, 255))  # spiral ring 1
    set_pixel(im, 12, 5, (90, 40, 30, 255)) # spiral ring 2
    set_pixel(im, 15, 5, (90, 40, 30, 255)) # spiral ring 3

    # Date numeral "1" on calendar page
    fill_rect(im, 12, 11, 13, 15, (45, 45, 55, 255))
    set_pixel(im, 11, 12, (45, 45, 55, 255))
    fill_rect(im, 11, 15, 14, 15, (45, 45, 55, 255))

    # Curling tear-off corner lifting up
    fill_rect(im, 15, 15, 17, 17, CREAM_SHADOW)
    set_pixel(im, 16, 16, CREAM_HI)
    return im


def draw_term() -> Image.Image:
    """School Bell Ringing"""
    im = new_icon()
    # Dark wood bell handle
    fill_rect(im, 9, 2, 11, 5, (100, 65, 35, 255))
    set_pixel(im, 10, 2, (140, 95, 55, 255))
    fill_rect(im, 9, 6, 11, 6, GOLD_SHADOW) # brass collar

    # Brass Bell dome & flare
    rows = [
        (8, 12, 7),
        (7, 13, 8),
        (7, 13, 9),
        (6, 14, 10),
        (6, 14, 11),
        (5, 15, 12),
        (4, 16, 13),
        (3, 17, 14),
    ]
    for x0, x1, y in rows:
        fill_rect(im, x0, y, x1, y, GOLD_MID)
    # Bell highlight stripe down left
    fill_rect(im, 7, 7, 8, 13, GOLD_HI)
    set_pixel(im, 5, 13, GOLD_HI)
    set_pixel(im, 4, 14, GOLD_HI)
    # Bell shadow on right
    fill_rect(im, 13, 8, 14, 12, GOLD_SHADOW)
    fill_rect(im, 15, 13, 16, 14, GOLD_SHADOW)

    # Clapper swinging out
    fill_rect(im, 9, 15, 11, 16, (60, 50, 45, 255))
    set_pixel(im, 10, 16, (90, 80, 70, 255))

    # Sound vibration waves
    # Left waves
    set_pixel(im, 1, 9, GOLD_SHADOW)
    set_pixel(im, 0, 10, GOLD_SHADOW)
    set_pixel(im, 0, 11, GOLD_SHADOW)
    set_pixel(im, 1, 12, GOLD_SHADOW)
    # Right waves
    set_pixel(im, 18, 9, GOLD_SHADOW)
    set_pixel(im, 19, 10, GOLD_SHADOW)
    set_pixel(im, 19, 11, GOLD_SHADOW)
    set_pixel(im, 18, 12, GOLD_SHADOW)
    return im


def draw_boss() -> Image.Image:
    """Wax-Sealed Exam Scroll"""
    im = new_icon()
    # Parchment document body
    fill_rect(im, 4, 2, 16, 16, CREAM_MID)
    fill_rect(im, 4, 2, 16, 2, CREAM_HI)
    fill_rect(im, 4, 2, 4, 16, CREAM_HI)
    fill_rect(im, 16, 3, 16, 16, CREAM_SHADOW)
    fill_rect(im, 4, 16, 16, 16, CREAM_SHADOW)

    # Ruled ink exam lines
    for y in (5, 7, 9):
        fill_rect(im, 6, y, 14, y, (180, 170, 150, 255))

    # Ribbon strap behind seal
    fill_rect(im, 9, 10, 11, 17, RED_SHADOW)

    # Crimson Red Wax Seal
    seal_points = [
        (9, 11), (10, 11), (11, 11),
        (8, 12), (9, 12), (10, 12), (11, 12), (12, 12),
        (8, 13), (9, 13), (10, 13), (11, 13), (12, 13),
        (9, 14), (10, 14), (11, 14)
    ]
    for x, y in seal_points:
        set_pixel(im, x, y, RED_MID)
    # Seal highlight & stamp imprint
    set_pixel(im, 9, 12, RED_HI)
    set_pixel(im, 10, 12, RED_HI)
    set_pixel(im, 10, 13, RED_SHADOW)
    # Ribbon v-tails
    set_pixel(im, 8, 18, RED_MID)
    set_pixel(im, 12, 18, RED_MID)
    return im


ICONS = {
    "icon_cheat_all": draw_all,
    "icon_cheat_coins": draw_coins,
    "icon_cheat_teacher": draw_teacher,
    "icon_cheat_students": draw_students,
    "icon_cheat_ready": draw_ready,
    "icon_cheat_furnish": draw_furnish,
    "icon_cheat_enrol": draw_enrol,
    "icon_cheat_grow": draw_grow,
    "icon_cheat_day": draw_day,
    "icon_cheat_term": draw_term,
    "icon_cheat_boss": draw_boss,
}


def make_all_cheat_icons() -> list[str]:
    os.makedirs(OUT, exist_ok=True)
    generated = []
    for name, func in ICONS.items():
        im = func()
        path = os.path.join(OUT, f"{name}.png")
        im.save(path)
        generated.append(path)
        print(f"Generated {path} (20x20)")
    return generated


if __name__ == "__main__":
    make_all_cheat_icons()
