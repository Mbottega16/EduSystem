#!/usr/bin/env python3
"""Draw every image this game needs: characters, furniture, and the room.

Everything is hand-plotted pixel art, generated in code so it is easy to
tweak a colour or a proportion and re-run rather than repaint by hand.

    python tools/make_art.py
"""
import os

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

FLOOR_A = (196, 166, 130)
FLOOR_B = (186, 156, 120)
FLOOR_LINE = (170, 140, 106)
WALL = (122, 96, 138)
WALL_TOP = (150, 122, 166)
WALL_BASE = (92, 70, 106)
WALL_LINE = (70, 52, 82)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c if len(c) == 4 else c + (255,))


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


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
    sheet.save(os.path.join(OUT, "%s.png" % name))
    return sheet.size


# ====================================================================
# furniture
# ====================================================================
# Drawn in the room's 3/4 view: a little of the top surface, a little of
# the front. The BOTTOM row of pixels is where the piece meets the floor,
# which is the point the game positions and depth-sorts against.

def draw_chair():
    im = Image.new("RGBA", (16, 18), (0, 0, 0, 0))
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
    rect(im, 1, 2, 30, 11, WOOD)         # top
    rect(im, 1, 2, 30, 4, WOOD_L)        # lit near edge of the surface
    rect(im, 1, 11, 30, 12, WOOD_D)      # underside lip
    rect(im, 3, 13, 5, 18, WOOD_D)       # legs
    rect(im, 26, 13, 28, 18, WOOD_D)
    return outline(im)


def draw_desk():
    im = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
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
    t = Image.new("RGBA", (TILE, TILE))
    base = FLOOR_A if (vx + vy) % 2 == 0 else FLOOR_B
    rect(t, 0, 0, TILE - 1, TILE - 1, base)
    # faint grout so the floor reads as tiles rather than flat colour
    for i in range(TILE):
        px(t, i, 0, FLOOR_LINE)
        px(t, 0, i, FLOOR_LINE)
    return t


def wall_tile(is_bottom_row, cap=True):
    t = Image.new("RGBA", (TILE, TILE))
    rect(t, 0, 0, TILE - 1, TILE - 1, WALL)
    if cap:
        rect(t, 0, 0, TILE - 1, 3, WALL_TOP)      # lit top edge
    if is_bottom_row:
        rect(t, 0, TILE - 4, TILE - 1, TILE - 1, WALL_BASE)
    # brick seams
    for y in (5, 10, 15):
        for x in range(TILE):
            px(t, x, y, WALL_LINE)
    for y, xs in ((5, (3, 11)), (10, (7, 15)), (15, (3, 11))):
        for x in xs:
            for yy in range(y, min(TILE, y + 5)):
                px(t, x, yy, WALL_LINE)
    return t


def door_tile(top):
    """One tile of the two-tile doorway. Students come in through here."""
    t = Image.new("RGBA", (TILE, TILE))
    rect(t, 0, 0, TILE - 1, TILE - 1, WALL)
    rect(t, 1, 0, TILE - 2, TILE - 1, (46, 34, 54))   # the dark beyond
    for y in range(TILE):                             # jambs
        px(t, 1, y, WOOD_D)
        px(t, TILE - 2, y, WOOD_D)
    if top:
        rect(t, 0, 0, TILE - 1, 0, WALL_TOP)
        rect(t, 1, 1, TILE - 2, 2, WOOD_D)            # lintel
    else:
        rect(t, 1, TILE - 2, TILE - 2, TILE - 1, (70, 52, 82))   # threshold
    return t


def make_room():
    im = Image.new("RGBA", (ROOM_W * TILE, ROOM_H * TILE))
    for ty in range(ROOM_H):
        for tx in range(ROOM_W):
            edge = (tx == 0 or tx == ROOM_W - 1
                    or ty < TOP_WALL or ty == ROOM_H - 1)
            if (tx, ty) in DOOR_TILES:
                tile = door_tile(ty == DOOR_TILES[0][1])
            elif edge:
                # only the very top course gets the lit cap, so the two-tile
                # top wall reads as one wall rather than two stacked ones
                tile = wall_tile(ty == ROOM_H - 1, cap=(ty != 1))
            else:
                tile = floor_tile(tx, ty)
            im.alpha_composite(tile, (tx * TILE, ty * TILE))
    im.save(os.path.join(OUT, "room.png"))
    return im.size


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, pal in CHARACTERS.items():
        size = make_character(name, pal)
        print("art/%-18s %3dx%-3d (%d facings x %d frames of %dx%d)"
              % (name + ".png", size[0], size[1], DIRS, FRAMES, CW, CH))
    for name, fn in list(FURNITURE.items()) + list(ITEM_ART.items()):
        img = fn()
        img.save(os.path.join(OUT, "%s.png" % name))
        print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    r = make_room()
    print("art/%-18s %3dx%-3d (%d x %d tiles of %d)"
          % ("room.png", r[0], r[1], ROOM_W, ROOM_H, TILE))
