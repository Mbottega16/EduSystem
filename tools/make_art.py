#!/usr/bin/env python3
"""Draw every image this game needs: characters, furniture, and the room.

Everything is hand-plotted pixel art, generated in code so it is easy to
tweak a colour or a proportion and re-run rather than repaint by hand.

    python tools/make_art.py
"""
import io
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

LINE = (36, 26, 18)      # shared outline colour for everything
EYE = (28, 24, 32)

# --- characters ------------------------------------------------------
CW, CH = 16, 24          # one frame
DIRS = 4                 # rows: down, left, right, up
FRAMES = 5               # cols: stand, step, stand, step (other foot), SEATED
SIT_FRAME = 4            # must match Actor.SIT_FRAME in scripts/actors/actor.gd

SKIN = (240, 200, 160)
SKIN_D = (206, 162, 122)

# One drawing routine, three palettes. `long_hair` adds hair past the jaw
# and `skirt` replaces the trousers — between them that is enough to read
# three distinct people without writing three draw functions.
CHARACTERS = {
    "player": {
        "hair": (107, 74, 47), "hair_d": (74, 50, 30),
        "shirt": (59, 125, 216), "shirt_d": (40, 90, 165),
        "legs": (78, 92, 130), "shoe": (74, 53, 36),
        "long_hair": False, "skirt": False,
    },
    # The inspector. Grey, and in a suit nobody else in the building owns,
    # because the entire job of this sprite is to be recognised across the
    # room without a label. Same generator as everyone else -- it is a
    # palette, not new drawing code.
    "inspector": {
        "hair": (178, 178, 184), "hair_d": (138, 138, 146),
        "shirt": (52, 56, 72), "shirt_d": (36, 38, 52),
        "legs": (42, 44, 56), "shoe": (28, 26, 30),
        "long_hair": False, "skirt": False,
    },
    # The principal. Older (white hair, same trick as the inspector's grey)
    # and in a colour nobody else in the building wears, so a popup can
    # show the portrait alone and it reads as "the principal" with no
    # label needed -- same reasoning as the inspector, different colour so
    # the two authority figures are not confused with each other.
    "principal": {
        "hair": (206, 204, 198), "hair_d": (164, 162, 156),
        "shirt": (96, 48, 92), "shirt_d": (68, 32, 66),
        "legs": (54, 46, 40), "shoe": (30, 26, 22),
        "long_hair": False, "skirt": False,
    },
    # Eight students. Two identical sprites across eight desks badly
    # undercuts "these are individual kids", and this is a data-table edit
    # rather than any new drawing code. Keys must match Names.ART in
    # scripts/data/names.gd.
    "student_a": {
        "hair": (58, 44, 38), "hair_d": (38, 28, 24),
        "shirt": (86, 166, 96), "shirt_d": (58, 124, 68),
        "legs": (104, 84, 64), "shoe": (58, 46, 40),
        "long_hair": False, "skirt": False,
    },
    "student_b": {
        "hair": (168, 102, 52), "hair_d": (126, 74, 36),
        "shirt": (214, 96, 124), "shirt_d": (170, 66, 94),
        "legs": (196, 158, 190), "shoe": (92, 60, 72),
        "long_hair": True, "skirt": True,
    },
    "student_c": {
        "hair": (222, 190, 104), "hair_d": (176, 142, 66),
        "shirt": (238, 200, 84), "shirt_d": (194, 156, 52),
        "legs": (72, 96, 148), "shoe": (54, 44, 38),
        "long_hair": False, "skirt": False,
    },
    "student_d": {
        "hair": (72, 52, 44), "hair_d": (48, 34, 30),
        "shirt": (150, 108, 196), "shirt_d": (110, 76, 152),
        "legs": (188, 166, 208), "shoe": (74, 58, 76),
        "long_hair": True, "skirt": True,
    },
    "student_e": {
        "hair": (206, 108, 58), "hair_d": (158, 76, 38),
        "shirt": (232, 138, 72), "shirt_d": (184, 100, 48),
        "legs": (108, 112, 120), "shoe": (56, 50, 46),
        "long_hair": False, "skirt": False,
    },
    "student_f": {
        "hair": (40, 38, 48), "hair_d": (26, 24, 32),
        "shirt": (78, 176, 172), "shirt_d": (50, 132, 130),
        "legs": (160, 176, 184), "shoe": (52, 58, 62),
        "long_hair": True, "skirt": True,
    },
    "student_g": {
        "hair": (140, 104, 66), "hair_d": (100, 72, 44),
        "shirt": (206, 82, 76), "shirt_d": (160, 54, 52),
        "legs": (58, 68, 104), "shoe": (48, 42, 40),
        "long_hair": False, "skirt": False,
    },
    "student_h": {
        "hair": (222, 218, 208), "hair_d": (176, 172, 166),
        "shirt": (128, 206, 168), "shirt_d": (88, 160, 126),
        "legs": (200, 196, 188), "shoe": (70, 74, 72),
        "long_hair": True, "skirt": True,
    },
}

# --- furniture -------------------------------------------------------
WOOD = (156, 110, 66)
WOOD_L = (186, 140, 92)
WOOD_D = (112, 76, 44)
METAL = (128, 132, 142)
METAL_D = (88, 92, 102)

# --- room ------------------------------------------------------------
TILE = 16
ROOM_W, ROOM_H = 20, 11  # in tiles -> 320 x 176 px
TOP_WALL = 2             # top wall is 2 tiles tall (see make_room)
# Two tiles tall. A one-tile doorway is only 16px, and a character whose
# feet-box bottom edge lands exactly on the wall segment below it collides
# with that shared edge and cannot pass. Must match Layout.DOOR_TILES.
DOOR_TILES = [(0, 7), (0, 8)]

# Two windows in the back wall, each 2 tiles wide and the full 2 tiles tall.
WINDOW_COLS = [(5, 6), (12, 13)]

# Classroom vinyl: warm off-white squares with a faint speckle, the way
# school flooring actually looks, rather than a chequerboard.
FLOOR_A = (224, 214, 194)
FLOOR_B = (214, 203, 182)
FLOOR_GROUT = (188, 176, 156)
FLOOR_FLECK = (200, 190, 172)

# Red brick.
WALL = (152, 76, 62)
WALL_L = (176, 96, 78)
WALL_D = (116, 54, 44)
WALL_TOP = (196, 122, 102)
WALL_BASE = (92, 42, 34)
MORTAR = (206, 192, 176)

# Painted door and window frames, deliberately NOT brick-coloured so the
# ways in and out read at a glance against a wall of red.
DOOR_PAINT = (58, 118, 132)
DOOR_PAINT_L = (86, 154, 168)
DOOR_PAINT_D = (36, 80, 92)
GLASS = (176, 214, 232)
GLASS_L = (208, 234, 246)
FRAME = (238, 234, 224)
FRAME_D = (176, 170, 158)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c if len(c) == 4 else c + (255,))


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


SHADOW = (0, 0, 0, 60)


def shadow(img, cx, cy, rx, ry, colour=SHADOW):
    """A soft contact ellipse. Without one, every sprite looks pasted onto
    the floor rather than standing on it — it is the cheapest thing in this
    whole file that changes how the game looks."""
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if rx == 0 or ry == 0:
                continue
            dx = (x - cx) / float(rx)
            dy = (y - cy) / float(ry)
            if dx * dx + dy * dy <= 1.0:
                if 0 <= x < img.width and 0 <= y < img.height:
                    r, g, b, a = img.getpixel((x, y))
                    if a == 0:
                        img.putpixel((x, y), colour)


def outline(img, colour=LINE):
    """Put a 1px border on every transparent pixel touching solid art."""
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3]:
                    px(img, x, y, colour)
                    break
    return img


# ====================================================================
# characters
# ====================================================================

def draw_char(direction, frame, pal):
    """One 16x24 frame.

    `direction` 0=down 1=left 2=right 3=up.
    `frame` 0-3 is the walk cycle; frame 4 (SIT_FRAME) is the seated pose.

    The seated pose is drawn LOWERED INSIDE the same 16x24 cell rather than
    compensated for with a node offset in the engine. That keeps one rule
    true of every character sprite — the bottom of the cell is where this
    person meets the floor — which is the rule the whole game positions and
    depth-sorts by.
    """
    im = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    hair, hair_d = pal["hair"], pal["hair_d"]
    shirt, shirt_d = pal["shirt"], pal["shirt_d"]

    seated = (frame == SIT_FRAME)
    dy = 3 if seated else 0        # how far the figure sinks into the chair

    # contact shadow, drawn before anything else so the figure sits on it
    shadow(im, CW // 2, CH - 2, 6, 2)

    # walk cycle: frames 1 and 3 lift opposite feet, 0 and 2 stand
    step = 0
    if frame == 1:
        step = 1
    elif frame == 3:
        step = -1

    # ---- legs ----
    if seated:
        # knees forward, feet tucked under the chair. Only the tops of the
        # thighs read from this angle, and at a desk even those are hidden.
        rect(im, 3, 21, 6, 23, pal["legs"])
        rect(im, 9, 21, 12, 23, pal["legs"])
    else:
        l_off = max(0, step)
        r_off = max(0, -step)
        leg_top = 20 if pal["skirt"] else 18   # a skirt covers the thighs
        rect(im, 4, leg_top - l_off, 6, 21 - l_off, pal["legs"])
        rect(im, 9, leg_top - r_off, 11, 21 - r_off, pal["legs"])
        rect(im, 4, 22 - l_off, 6, 22 - l_off, pal["shoe"])
        rect(im, 9, 22 - r_off, 11, 22 - r_off, pal["shoe"])

    # ---- body ----
    rect(im, 4, 12 + dy, 11, 18 + dy, shirt)
    rect(im, 4, 17 + dy, 11, 18 + dy, shirt_d)   # shading under the torso
    if pal["skirt"] and not seated:
        rect(im, 4, 17, 11, 17, shirt)           # a flared hem over the legs
        rect(im, 3, 18, 12, 19, shirt)
        rect(im, 2, 20, 13, 20, shirt_d)

    # ---- arms (swing opposite to the legs; still when seated) ----
    a_l = 0 if seated else -step
    a_r = 0 if seated else step
    rect(im, 2, 13 + dy + a_l, 3, 17 + dy + a_l, shirt_d)
    rect(im, 12, 13 + dy + a_r, 13, 17 + dy + a_r, shirt_d)
    px(im, 2, 18 + dy + a_l, SKIN); px(im, 3, 18 + dy + a_l, SKIN)
    px(im, 12, 18 + dy + a_r, SKIN); px(im, 13, 18 + dy + a_r, SKIN)

    # ---- head ----
    rect(im, 4, 4 + dy, 11, 11 + dy, SKIN)
    rect(im, 4, 11 + dy, 11, 11 + dy, SKIN_D)    # jaw shadow

    # ---- long hair falls behind the head, so it goes down before the fringe
    if pal["long_hair"]:
        rect(im, 3, 5 + dy, 3, 15 + dy, hair)
        rect(im, 12, 5 + dy, 12, 15 + dy, hair)
        px(im, 3, 15 + dy, hair_d); px(im, 12, 15 + dy, hair_d)

    # ---- hair, which is what actually sells the facing ----
    if direction == 3:                           # away: all hair, no face
        rect(im, 4, 3 + dy, 11, 10 + dy, hair)
        rect(im, 4, 10 + dy, 11, 10 + dy, hair_d)
        if pal["long_hair"]:
            rect(im, 4, 10 + dy, 11, 15 + dy, hair)   # full fall down the back
            rect(im, 4, 15 + dy, 11, 15 + dy, hair_d)
    elif direction == 0:                         # toward camera: fringe + eyes
        rect(im, 4, 3 + dy, 11, 6 + dy, hair)
        rect(im, 4, 6 + dy, 5, 7 + dy, hair)
        rect(im, 10, 6 + dy, 11, 7 + dy, hair)
        px(im, 6, 8 + dy, EYE); px(im, 9, 8 + dy, EYE)
        px(im, 6, 9 + dy, SKIN_D); px(im, 9, 9 + dy, SKIN_D)
    elif direction == 1:                         # left profile
        rect(im, 4, 3 + dy, 11, 6 + dy, hair)
        rect(im, 9, 3 + dy, 11, 9 + dy, hair)
        px(im, 5, 8 + dy, EYE)
    else:                                        # right profile
        rect(im, 4, 3 + dy, 11, 6 + dy, hair)
        rect(im, 4, 3 + dy, 6, 9 + dy, hair)
        px(im, 10, 8 + dy, EYE)

    return outline(im)


def make_character(name, pal):
    sheet = Image.new("RGBA", (CW * FRAMES, CH * DIRS), (0, 0, 0, 0))
    for d in range(DIRS):
        for f in range(FRAMES):
            sheet.alpha_composite(draw_char(d, f, pal), (f * CW, d * CH))
    save_png(sheet, name)
    return sheet.size


# ====================================================================
# furniture
# ====================================================================
# Drawn in the room's 3/4 view: a little of the top surface, a little of
# the front. The BOTTOM row of pixels is where the piece meets the floor,
# which is the point the game positions and depth-sorts against.

def draw_chair():
    im = Image.new("RGBA", (16, 18), (0, 0, 0, 0))
    shadow(im, 8, im.height - 2, 6, 2)
    rect(im, 3, 1, 12, 6, WOOD)          # back rest
    rect(im, 3, 1, 12, 2, WOOD_L)
    rect(im, 5, 3, 10, 5, WOOD_D)        # gap in the back rest
    rect(im, 2, 7, 13, 11, WOOD)         # seat
    rect(im, 2, 7, 13, 8, WOOD_L)
    rect(im, 3, 12, 4, 16, WOOD_D)       # legs
    rect(im, 11, 12, 12, 16, WOOD_D)
    return outline(im)


def draw_table():
    im = Image.new("RGBA", (32, 20), (0, 0, 0, 0))
    shadow(im, 16, im.height - 2, 13, 2)
    rect(im, 1, 2, 30, 11, WOOD)         # top
    rect(im, 1, 2, 30, 4, WOOD_L)        # lit near edge of the surface
    rect(im, 1, 11, 30, 12, WOOD_D)      # underside lip
    rect(im, 3, 13, 5, 18, WOOD_D)       # legs
    rect(im, 26, 13, 28, 18, WOOD_D)
    return outline(im)


def draw_desk():
    im = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
    shadow(im, 8, im.height - 2, 6, 2)
    rect(im, 1, 2, 14, 9, WOOD)          # writing surface
    rect(im, 1, 2, 14, 4, WOOD_L)
    rect(im, 1, 9, 14, 10, WOOD_D)
    rect(im, 3, 11, 12, 14, METAL)       # book shelf beneath the top
    rect(im, 3, 11, 12, 11, METAL_D)
    rect(im, 2, 15, 3, 18, METAL_D)      # legs
    rect(im, 12, 15, 13, 18, METAL_D)
    return outline(im)


def draw_teacher_desk():
    """Two tiles wide — the front of the room, where marked work is handed in."""
    im = Image.new("RGBA", (32, 22), (0, 0, 0, 0))
    rect(im, 1, 2, 30, 12, WOOD)          # top
    rect(im, 1, 2, 30, 4, WOOD_L)         # lit near edge
    rect(im, 1, 12, 30, 13, WOOD_D)
    rect(im, 3, 14, 14, 19, WOOD)         # drawer bank
    rect(im, 3, 14, 14, 14, WOOD_L)
    rect(im, 5, 16, 12, 16, WOOD_D)       # drawer pull
    rect(im, 2, 20, 4, 21, WOOD_D)        # legs
    rect(im, 27, 14, 29, 21, WOOD_D)
    return outline(im)


def draw_podium():
    """Front of the room. Starting a lesson happens here."""
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    rect(im, 2, 1, 13, 7, WOOD)           # slanted reading surface
    rect(im, 2, 1, 13, 2, WOOD_L)
    rect(im, 2, 7, 13, 8, WOOD_D)
    rect(im, 5, 9, 10, 17, WOOD)          # column
    rect(im, 5, 9, 6, 17, WOOD_L)
    rect(im, 3, 18, 12, 21, WOOD_D)       # base
    return outline(im)


def draw_paper():
    """A finished sheet of work. Sits on a desk, and stacks in your arms."""
    im = Image.new("RGBA", (10, 9), (0, 0, 0, 0))
    rect(im, 1, 1, 8, 7, (246, 244, 236))
    rect(im, 1, 1, 8, 1, (255, 255, 255))
    for y in (3, 5):                      # lines of writing
        rect(im, 3, y, 6, y, (150, 152, 160))
    px(im, 3, 7, (150, 152, 160)); px(im, 4, 7, (150, 152, 160))
    return outline(im)


def draw_bell():
    """Ends the day. Deliberately across the room from the podium."""
    im = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
    rect(im, 4, 2, 11, 3, (198, 160, 62))     # crown
    rect(im, 3, 4, 12, 10, (226, 186, 74))    # body
    rect(im, 3, 4, 5, 10, (246, 214, 116))    # highlight
    rect(im, 2, 11, 13, 12, (198, 160, 62))   # lip
    rect(im, 7, 13, 8, 14, (150, 118, 42))    # clapper
    rect(im, 5, 15, 10, 16, WOOD)             # stand
    rect(im, 3, 17, 12, 19, WOOD_D)
    return outline(im)


def draw_noticeboard():
    """Where you order furniture from."""
    im = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
    rect(im, 1, 1, 14, 13, WOOD_D)            # frame
    rect(im, 2, 2, 13, 12, (188, 156, 116))   # cork
    rect(im, 3, 3, 7, 6, (246, 244, 236))     # pinned notes
    rect(im, 9, 4, 12, 8, (232, 226, 200))
    rect(im, 3, 8, 6, 11, (222, 216, 196))
    rect(im, 6, 14, 9, 16, WOOD)              # post
    rect(im, 4, 17, 11, 19, WOOD_D)
    return outline(im)


def draw_bubble_q():
    """A confused student. The single most important readout in the game —
    at this resolution a bubble over a head says more than any HUD label."""
    im = Image.new("RGBA", (11, 12), (0, 0, 0, 0))
    rect(im, 1, 0, 9, 7, (252, 250, 242))     # bubble
    rect(im, 0, 1, 10, 6, (252, 250, 242))
    rect(im, 4, 8, 6, 9, (252, 250, 242))     # tail
    px(im, 5, 10, (252, 250, 242))
    q = (196, 72, 60)
    rect(im, 4, 1, 6, 1, q)                   # question mark
    px(im, 7, 2, q); px(im, 6, 3, q); px(im, 5, 4, q)
    px(im, 3, 2, q); px(im, 5, 6, q)
    return outline(im)


FURNITURE = {
    "chair": draw_chair, "table": draw_table, "desk": draw_desk,
    "teacher_desk": draw_teacher_desk, "podium": draw_podium, "paper": draw_paper,
    "bell": draw_bell, "noticeboard": draw_noticeboard, "bubble_q": draw_bubble_q,
}


# --- purchasable classroom items -------------------------------------
# Each is a floor prop the player buys and places. They exist as art here;
# their effects live in scripts/data/items.gd.

def _shelf(body, trim):
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    rect(im, 1, 2, 14, 18, body)
    rect(im, 1, 2, 14, 3, WOOD_L)
    for y in (8, 13):
        rect(im, 2, y, 13, y, WOOD_D)
    for x in range(3, 13, 3):                 # books
        rect(im, x, 4, x + 1, 7, trim)
        rect(im, x, 9, x + 1, 12, (trim[0] // 2 + 60, trim[1] // 2 + 60, trim[2] // 2 + 60))
    rect(im, 2, 19, 4, 21, WOOD_D)
    rect(im, 11, 19, 13, 21, WOOD_D)
    return outline(im)


def draw_bookshelf():
    return _shelf(WOOD, (86, 128, 196))


def draw_lab_bench():
    im = Image.new("RGBA", (32, 20), (0, 0, 0, 0))
    shadow(im, 16, im.height - 2, 13, 2)
    rect(im, 1, 4, 30, 12, (132, 138, 148))   # steel top
    rect(im, 1, 4, 30, 5, (170, 176, 186))
    rect(im, 1, 12, 30, 13, (92, 96, 106))
    rect(im, 4, 1, 7, 3, (108, 196, 168))     # flasks
    rect(im, 10, 0, 13, 3, (196, 148, 84))
    rect(im, 22, 1, 25, 3, (146, 132, 206))
    rect(im, 3, 14, 5, 18, (92, 96, 106))
    rect(im, 26, 14, 28, 18, (92, 96, 106))
    return outline(im)


def draw_art_easel():
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    shadow(im, 8, im.height - 2, 6, 2)
    rect(im, 2, 1, 13, 12, (246, 244, 236))   # canvas
    rect(im, 4, 3, 8, 7, (206, 96, 88))       # a painting in progress
    rect(im, 8, 6, 11, 10, (104, 160, 206))
    rect(im, 1, 12, 14, 13, WOOD)
    rect(im, 4, 14, 5, 21, WOOD_D)            # legs
    rect(im, 10, 14, 11, 21, WOOD_D)
    rect(im, 7, 14, 8, 19, WOOD_D)
    return outline(im)


def draw_rug():
    im = Image.new("RGBA", (32, 18), (0, 0, 0, 0))
    rect(im, 1, 1, 30, 16, (168, 96, 104))
    rect(im, 3, 3, 28, 14, (196, 128, 132))
    rect(im, 6, 5, 25, 12, (168, 96, 104))
    rect(im, 9, 7, 22, 10, (216, 176, 140))
    return outline(im)


def draw_plant():
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    shadow(im, 8, im.height - 2, 5, 2)
    rect(im, 5, 14, 10, 20, (176, 106, 78))   # pot
    rect(im, 4, 13, 11, 15, (196, 126, 96))
    for pts in (((7, 2), (8, 12)), ((3, 6), (7, 11)), ((12, 5), (8, 11))):
        x0, y0 = pts[0]
        x1, y1 = pts[1]
        rect(im, min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1), (84, 152, 90))
    rect(im, 6, 3, 9, 9, (108, 180, 112))
    return outline(im)


ITEM_ART = {
    "bookshelf": draw_bookshelf, "lab_bench": draw_lab_bench,
    "art_easel": draw_art_easel, "rug": draw_rug, "plant": draw_plant,
}


# ====================================================================
# room
# ====================================================================

def floor_tile(vx, vy):
    """One vinyl floor tile. The speckle is seeded from the tile position, so
    the pattern is stable between runs but never visibly repeats."""
    t = Image.new("RGBA", (TILE, TILE))
    base = FLOOR_A if (vx + vy) % 2 == 0 else FLOOR_B
    rect(t, 0, 0, TILE - 1, TILE - 1, base)
    rnd = random.Random(vx * 7919 + vy * 104729)
    for _ in range(9):
        px(t, rnd.randrange(1, TILE - 1), rnd.randrange(1, TILE - 1), FLOOR_FLECK)
    # grout on two edges only, so neighbouring tiles share one line
    for i in range(TILE):
        px(t, i, 0, FLOOR_GROUT)
        px(t, 0, i, FLOOR_GROUT)
    return t


def wall_tile(is_bottom_row, cap=True, row=0):
    """Red brick in a running bond. `row` staggers the courses so the bricks
    offset correctly between vertically stacked tiles."""
    t = Image.new("RGBA", (TILE, TILE))
    rect(t, 0, 0, TILE - 1, TILE - 1, WALL)

    course = 4
    for i, y in enumerate(range(0, TILE, course)):
        offset = 0 if (i + row * 4) % 2 == 0 else 4
        for bx in range(-8 + offset, TILE, 8):
            shade = (WALL_L, WALL_D, WALL)[(bx // 8 + i) % 3]
            for xx in range(bx + 1, min(TILE, bx + 8)):
                if xx < 0:
                    continue
                for yy in range(y + 1, min(TILE, y + course)):
                    px(t, xx, yy, shade)
            if 0 <= bx < TILE:
                for yy in range(y + 1, min(TILE, y + course)):
                    px(t, bx, yy, MORTAR)
        rect(t, 0, y, TILE - 1, y, MORTAR)

    if cap:
        rect(t, 0, 0, TILE - 1, 2, WALL_TOP)
    if is_bottom_row:
        rect(t, 0, TILE - 3, TILE - 1, TILE - 1, WALL_BASE)
    return t


def window_tile(left_half, top_half):
    """One quarter of a 2x2-tile window: frame, glass, glazing bar, sill."""
    t = Image.new("RGBA", (TILE, TILE))
    rect(t, 0, 0, TILE - 1, TILE - 1, WALL)
    x0 = 2 if left_half else 0
    x1 = TILE - 1 if left_half else TILE - 3
    y0 = 3 if top_half else 0
    y1 = TILE - 1 if top_half else TILE - 4

    rect(t, x0, y0, x1, y1, FRAME)
    gx0, gy0 = x0 + 2, y0 + 2
    gx1 = x1 if left_half else x1 - 2
    gy1 = y1 if top_half else y1 - 2
    rect(t, gx0, gy0, gx1, gy1, GLASS)
    if top_half:
        rect(t, gx0, gy0, gx1, gy0 + 2, GLASS_L)   # daylight across the top
    if left_half:
        rect(t, TILE - 1, gy0, TILE - 1, gy1, FRAME_D)
    else:
        rect(t, 0, gy0, 0, gy1, FRAME_D)
    if not top_half:
        rect(t, x0, y1 - 1, x1, y1, FRAME_D)       # sill
        rect(t, x0, TILE - 3, x1, TILE - 1, WALL_D)
    return t


def door_tile(top):
    """One tile of the two-tile doorway: a painted classroom door with a
    vision panel."""
    t = Image.new("RGBA", (TILE, TILE))
    rect(t, 0, 0, TILE - 1, TILE - 1, WALL)
    rect(t, 1, 0, TILE - 2, TILE - 1, DOOR_PAINT)
    rect(t, 2, 0, 3, TILE - 1, DOOR_PAINT_L)
    rect(t, TILE - 3, 0, TILE - 3, TILE - 1, DOOR_PAINT_D)
    for y in range(TILE):
        px(t, 1, y, FRAME)
        px(t, TILE - 2, y, FRAME_D)
    if top:
        rect(t, 0, 0, TILE - 1, 1, WALL_TOP)
        rect(t, 1, 2, TILE - 2, 2, FRAME)
        rect(t, 5, 6, 10, TILE - 1, GLASS)
        rect(t, 5, 6, 10, 7, GLASS_L)
        rect(t, 4, 5, 11, 5, FRAME)
    else:
        rect(t, 5, 0, 10, 4, GLASS)
        rect(t, 4, 5, 11, 5, FRAME)
        px(t, TILE - 5, 8, (232, 220, 150))
        px(t, TILE - 5, 9, (232, 220, 150))
        rect(t, 1, TILE - 2, TILE - 2, TILE - 1, DOOR_PAINT_D)
    return t


# How many speckle variants of each floor parity get exported. floor_tile()
# seeds its speckle from the tile position, so it is not a finite set -- but
# once the room can be any size, the runtime has to compose it from a bank of
# real tiles. Eight variants picked by a position hash keeps "stable between
# runs, never visibly repeating" without shipping a tile per coordinate.
FLOOR_VARIANTS = 4


def make_contact_shadow():
    """The one shadow the RUNTIME uses, as its own sprite.

    Every other shadow in this file is painted INTO the sprite it belongs to,
    which was right while sprites never moved relative to their own feet. Two
    things broke that: the seated idle-bob lifts a character 0.6px, taking its
    baked shadow up with it so the shadow floats off the floor, and bought
    furniture only got one if its text grid happened to declare `shadow: yes`.

    A separate sprite parented under each actor and prop -- and deliberately
    NOT under the bobbing Sprite2D -- stays on the ground where a shadow
    belongs, and costs nothing to give to every prop at once.
    """
    w, h = 16, 6
    im = Image.new("RGBA", (w, h))
    cx, cy = w / 2.0, h / 2.0
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - cx) / (w / 2.0)
            dy = (y + 0.5 - cy) / (h / 2.0)
            d = dx * dx + dy * dy
            if d <= 1.0:
                # softer at the rim, so it reads as contact rather than a decal
                a = int(70 * (1.0 - d * 0.65))
                im.putpixel((x, y), (0, 0, 0, max(0, a)))
    save_png(im, "shadow")
    return im.size


def make_room_tiles():
    """The room, in pieces, so it can be rebuilt at ANY size at runtime.

    room.png is still written for the opening 20x11 classroom, but a room the
    player can grow cannot be one baked image -- see RoomBuilder.build_floor.
    """
    out = []

    def save(img, name):
        save_png(img, name)
        out.append(name)

    for i in range(FLOOR_VARIANTS):
        # even/odd parity are the two vinyl shades; x offsets pick a speckle
        save(floor_tile(i * 2, 0), "tile_floor_a%d" % i)
        save(floor_tile(i * 2 + 1, 0), "tile_floor_b%d" % i)

    save(wall_tile(False, cap=True, row=0), "tile_wall_top0")
    save(wall_tile(False, cap=False, row=1), "tile_wall_top1")
    save(wall_tile(False, cap=False, row=2), "tile_wall_side")
    save(wall_tile(True, cap=False, row=0), "tile_wall_bottom")

    save(window_tile(True, True), "tile_window_l0")
    save(window_tile(False, True), "tile_window_r0")
    save(window_tile(True, False), "tile_window_l1")
    save(window_tile(False, False), "tile_window_r1")

    save(door_tile(True), "tile_door_top")
    save(door_tile(False), "tile_door_bottom")
    return out


def make_room():
    """RETIRED. The room is composed from tiles at runtime now, because the
    player can buy it bigger and a baked image cannot answer for a size that
    is not known until the save is loaded. Kept only as a reference render
    -- nothing in the game loads it. See RoomBuilder.compose_room()."""
    im = Image.new("RGBA", (ROOM_W * TILE, ROOM_H * TILE))
    for ty in range(ROOM_H):
        for tx in range(ROOM_W):
            edge = (tx == 0 or tx == ROOM_W - 1
                    or ty < TOP_WALL or ty == ROOM_H - 1)
            window_here = ty < TOP_WALL and any(tx in c for c in WINDOW_COLS)
            if (tx, ty) in DOOR_TILES:
                tile = door_tile(ty == DOOR_TILES[0][1])
            elif window_here:
                cols = next(c for c in WINDOW_COLS if tx in c)
                tile = window_tile(tx == cols[0], ty == 0)
            elif edge:
                # only the very top course gets the lit cap, so the two-tile
                # top wall reads as one wall rather than two stacked ones
                tile = wall_tile(ty == ROOM_H - 1, cap=(ty != 1), row=ty)
            else:
                tile = floor_tile(tx, ty)
            im.alpha_composite(tile, (tx * TILE, ty * TILE))
    return im.size          # not saved: nothing loads it any more


# ====================================================================
# text-grid sprites
# ====================================================================
# Anything in tools/sprites/*.txt becomes a PNG, so art can be added by
# drawing a picture in a text file rather than by plotting coordinates in
# Python. See tools/sprites/README.md.

SPRITE_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sprites")


def hand_edited():
    """Names that have a tools/sprites/*.txt source.

    THE RULE: a hand edit wins, and is recorded. A sprite drawn by hand --
    in the gallery, or by writing the grid out yourself -- lands here as a
    text source, and the procedural version below stands down for it.

    Before this existed there were three ways a sprite could be produced
    and nothing arbitrated between them, so hand-editing a generated sprite
    was silently undone by the next run of this script.
    """
    if not os.path.isdir(SPRITE_SRC):
        return set()
    return {os.path.splitext(f)[0] for f in os.listdir(SPRITE_SRC)
            if f.endswith(".txt")}


_HAND = set()
_STOOD_DOWN = []


def save_png(img, name):
    """Save unless a hand-edited source owns this name. -> was it written?"""
    if name in _HAND:
        _STOOD_DOWN.append(name)
        return False
    img.save(os.path.join(OUT, "%s.png" % name))
    return True


def parse_grid_sprite(path):
    """-> (PIL image, name) from a text-grid file."""
    name = os.path.splitext(os.path.basename(path))[0]
    palette = {".": None, " ": None}
    do_outline = None
    do_shadow = False
    rows = []

    for raw in io.open(path, encoding="utf-8").read().splitlines():
        line = raw.rstrip("\n")
        if line.startswith("#"):
            body = line[1:].strip()
            key, _, val = body.partition(":")
            key = key.strip().lower()
            val = val.strip()
            if key == "name" and val:
                name = val
            elif key == "palette":
                # Entries are comma-separated, so colours are HEX rather than
                # "r,g,b" -- otherwise the entry split chops the triples up.
                for entry in val.split(","):
                    ch, _, col = entry.partition("=")
                    ch = ch.strip()
                    col = col.strip().lstrip("#")
                    if not ch:
                        continue
                    if col.lower() in ("none", "transparent", ""):
                        palette[ch] = None
                    elif len(col) == 6:
                        palette[ch] = tuple(
                            int(col[i:i + 2], 16) for i in (0, 2, 4))
                    else:
                        print("  note: %s has a bad colour %r" % (name, col))
            elif key == "outline":
                v = val.strip().lstrip("#")
                do_outline = (tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))
                              if len(v) == 6 else LINE)
            elif key == "shadow":
                do_shadow = val.lower() in ("yes", "true", "1")
            continue
        if line.strip() == "" and not rows:
            continue
        rows.append(line)

    while rows and rows[-1].strip() == "":
        rows.pop()
    if not rows:
        return None, name

    w = max(len(r) for r in rows)
    ragged = [i for i, r in enumerate(rows) if len(r) != w]
    if ragged:
        print("  note: %s has %d short row(s), padded" % (name, len(ragged)))

    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    unknown = set()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in palette:
                unknown.add(ch)
                continue
            c = palette[ch]
            if c is not None:
                px(im, x, y, c)
    if unknown:
        print("  note: %s uses undeclared characters %s (left transparent)"
              % (name, "".join(sorted(unknown))))

    if do_shadow:
        shadow(im, im.width // 2, im.height - 2, max(2, im.width // 3), 2)
    if do_outline is not None:
        outline(im, do_outline)
    return im, name


def make_grid_sprites():
    made = 0
    if not os.path.isdir(SPRITE_SRC):
        return 0
    for f in sorted(os.listdir(SPRITE_SRC)):
        if not f.endswith(".txt"):
            continue
        im, name = parse_grid_sprite(os.path.join(SPRITE_SRC, f))
        if im is None:
            continue
        im.save(os.path.join(OUT, "%s.png" % name))
        print("art/%-18s %3dx%-3d (from sprites/%s)" % (name + ".png", im.width, im.height, f))
        made += 1
    return made



# ====================================================================
# title screen
# ====================================================================

# A 5x7 pixel font, only the letters the wordmark needs. Kept deliberately
# small: a full A-Z atlas is a lot of data to carry for one word, and the
# rest of the UI uses Godot's font.
GLYPHS = {
    "P": ["1111.", "1...1", "1...1", "1111.", "1....", "1....", "1...."],
    "I": ["11111", "..1..", "..1..", "..1..", "..1..", "..1..", "11111"],
    "X": ["1...1", "1...1", ".1.1.", "..1..", ".1.1.", "1...1", "1...1"],
    "E": ["11111", "1....", "1....", "1111.", "1....", "1....", "11111"],
    "L": ["1....", "1....", "1....", "1....", "1....", "1....", "11111"],
    "R": ["1111.", "1...1", "1...1", "1111.", "1..1.", "1...1", "1...1"],
    "O": [".111.", "1...1", "1...1", "1...1", "1...1", "1...1", ".111."],
    "M": ["1...1", "11.11", "1.1.1", "1...1", "1...1", "1...1", "1...1"],
}

CHALK = (238, 240, 232)
CHALK_D = (188, 196, 190)
BOARD = (44, 62, 52)
BOARD_L = (56, 76, 64)
FRAME_W = (128, 88, 52)
FRAME_D = (92, 60, 34)


def draw_logo(scale=3, gap=2):
    """The wordmark, drawn big and chalky."""
    word = "PIXELROOM"
    gw, gh = 5, 7
    w = len(word) * (gw * scale + gap) - gap
    h = gh * scale
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    x0 = 1
    for ch in word:
        rows = GLYPHS[ch]
        for gy in range(gh):
            for gx in range(gw):
                if rows[gy][gx] != "1":
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        # a little grain so it reads as chalk rather than vinyl
                        c = CHALK if (sx + sy + gx + gy) % 5 else CHALK_D
                        px(im, x0 + gx * scale + sx, 1 + gy * scale + sy, c)
        x0 += gw * scale + gap
    return im


def draw_title_bg():
    """A blackboard in a wooden frame, with a chalk tray and some ghost
    writing left over from the last lesson."""
    W, H = 320, 176
    im = Image.new("RGBA", (W, H), BOARD)

    # uneven wiped-over patches, so the board is not flat colour
    rnd = random.Random(11)
    for _ in range(90):
        cx = rnd.randrange(0, W)
        cy = rnd.randrange(0, H)
        rw = rnd.randrange(10, 46)
        rh = rnd.randrange(3, 10)
        for y in range(cy, min(H, cy + rh)):
            for x in range(cx, min(W, cx + rw)):
                if rnd.random() < 0.35:
                    px(im, x, y, BOARD_L)

    # faint sums in the corner, half rubbed out
    for i, line in enumerate(("7 x 8 =", "12 + 5 =", "3 x 9 =")):
        gy = 132 + i * 10
        gx = 250
        for ch in line:
            if ch != " ":
                for dy in range(4):
                    for dx in range(3):
                        if rnd.random() < 0.30:
                            px(im, gx + dx, gy + dy, CHALK_D)
            gx += 5

    # wooden frame
    rect(im, 0, 0, W - 1, 5, FRAME_W)
    rect(im, 0, 0, W - 1, 1, (156, 112, 70))
    rect(im, 0, H - 12, W - 1, H - 1, FRAME_W)
    rect(im, 0, H - 12, W - 1, H - 11, (156, 112, 70))
    rect(im, 0, H - 4, W - 1, H - 1, FRAME_D)
    rect(im, 0, 0, 5, H - 1, FRAME_W)
    rect(im, W - 6, 0, W - 1, H - 1, FRAME_W)
    rect(im, 0, 0, 1, H - 1, FRAME_D)
    rect(im, W - 2, 0, W - 1, H - 1, FRAME_D)

    # chalk tray: a stub of chalk and a board rubber
    rect(im, 24, H - 10, 40, H - 8, CHALK)
    rect(im, 24, H - 10, 40, H - 10, (255, 255, 255))
    rect(im, 54, H - 11, 74, H - 7, (86, 62, 40))
    rect(im, 54, H - 11, 74, H - 10, (120, 92, 62))
    rect(im, 56, H - 8, 72, H - 7, (200, 200, 196))
    return im


def draw_dust():
    """One chalk mote. Drifts across the title screen."""
    im = Image.new("RGBA", (2, 2), (0, 0, 0, 0))
    px(im, 0, 0, CHALK)
    px(im, 1, 0, CHALK_D)
    px(im, 0, 1, CHALK_D)
    return im


TITLE_ART = {"logo": draw_logo, "title_bg": draw_title_bg, "dust": draw_dust}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # Read the hand-edited set ONCE, before anything is drawn.
    _HAND = hand_edited()
    for name, pal in CHARACTERS.items():
        size = make_character(name, pal)
        print("art/%-18s %3dx%-3d (%d facings x %d frames of %dx%d)"
              % (name + ".png", size[0], size[1], DIRS, FRAMES, CW, CH))
    for name, fn in (list(FURNITURE.items()) + list(ITEM_ART.items())
                     + list(TITLE_ART.items())):
        img = fn()
        if save_png(img, name):
            print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    # The furniture lives in its own file because the catalogue outgrew this
    # one. It was never actually called from here despite the docstring
    # saying so, which meant this script rebuilt the characters and left
    # every purchasable item untouched.
    import make_items
    make_items.make_all(_HAND)
    make_grid_sprites()
    sh = make_contact_shadow()
    print("art/%-18s %3dx%-3d (the runtime contact shadow)"
          % ("shadow.png", sh[0], sh[1]))
    pieces = make_room_tiles()
    print("art/tile_*.png       %d room pieces, for rooms built at runtime"
          % len(pieces))

    if _STOOD_DOWN:
        print("")
        print("  %d sprite(s) have a hand-edited source and were NOT redrawn:"
              % len(_STOOD_DOWN))
        for f in sorted(_STOOD_DOWN):
            print("      %-20s <- tools/sprites/%s.txt" % (f, f))

    # A PNG on disk is NOT yet a texture Godot can load. Anything new needs
    # importing, and until it is, load() returns null in the running game
    # while every file-exists check stays green -- which is precisely how
    # the inspector shipped invisible.
    missing = [f for f in sorted(os.listdir(OUT))
               if f.endswith(".png")
               and not os.path.exists(os.path.join(OUT, f + ".import"))]
    if missing:
        print("")
        print("  %d NEW file(s) are not imported yet:" % len(missing))
        for f in missing:
            print("      art/%s" % f)
        print("  Godot cannot load these until you run:")
        print("      godot --headless --path . --import")
        print("  (or just open the project in the editor once).")
