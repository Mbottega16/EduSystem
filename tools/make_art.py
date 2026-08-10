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
FRAMES = 4               # cols: stand, step, stand, step (other foot)

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
    "student_boy": {
        "hair": (58, 44, 38), "hair_d": (38, 28, 24),
        "shirt": (86, 166, 96), "shirt_d": (58, 124, 68),
        "legs": (104, 84, 64), "shoe": (58, 46, 40),
        "long_hair": False, "skirt": False,
    },
    "student_girl": {
        "hair": (168, 102, 52), "hair_d": (126, 74, 36),
        "shirt": (214, 96, 124), "shirt_d": (170, 66, 94),
        "legs": (196, 158, 190), "shoe": (92, 60, 72),
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
    """One 16x24 frame. `direction` 0=down 1=left 2=right 3=up."""
    im = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    hair, hair_d = pal["hair"], pal["hair_d"]
    shirt, shirt_d = pal["shirt"], pal["shirt_d"]

    # walk cycle: frames 1 and 3 lift opposite feet, 0 and 2 stand
    step = 0
    if frame == 1:
        step = 1
    elif frame == 3:
        step = -1

    # ---- legs ----
    l_off = max(0, step)
    r_off = max(0, -step)
    leg_top = 20 if pal["skirt"] else 18      # a skirt covers the thighs
    rect(im, 4, leg_top - l_off, 6, 21 - l_off, pal["legs"])
    rect(im, 9, leg_top - r_off, 11, 21 - r_off, pal["legs"])
    rect(im, 4, 22 - l_off, 6, 22 - l_off, pal["shoe"])
    rect(im, 9, 22 - r_off, 11, 22 - r_off, pal["shoe"])

    # ---- body ----
    rect(im, 4, 12, 11, 18, shirt)
    rect(im, 4, 17, 11, 18, shirt_d)          # shading under the torso
    if pal["skirt"]:
        rect(im, 4, 17, 11, 17, shirt)        # a flared hem over the legs
        rect(im, 3, 18, 12, 19, shirt)
        rect(im, 2, 20, 13, 20, shirt_d)

    # ---- arms (swing opposite to the legs) ----
    a_l = -step
    a_r = step
    rect(im, 2, 13 + a_l, 3, 17 + a_l, shirt_d)
    rect(im, 12, 13 + a_r, 13, 17 + a_r, shirt_d)
    px(im, 2, 18 + a_l, SKIN); px(im, 3, 18 + a_l, SKIN)
    px(im, 12, 18 + a_r, SKIN); px(im, 13, 18 + a_r, SKIN)

    # ---- head ----
    rect(im, 4, 4, 11, 11, SKIN)
    rect(im, 4, 11, 11, 11, SKIN_D)           # jaw shadow

    # ---- long hair falls behind the head, so it goes down before the fringe
    if pal["long_hair"]:
        rect(im, 3, 5, 3, 15, hair)
        rect(im, 12, 5, 12, 15, hair)
        px(im, 3, 15, hair_d); px(im, 12, 15, hair_d)

    # ---- hair, which is what actually sells the facing ----
    if direction == 3:                        # away: all hair, no face
        rect(im, 4, 3, 11, 10, hair)
        rect(im, 4, 10, 11, 10, hair_d)
        if pal["long_hair"]:
            rect(im, 4, 10, 11, 15, hair)     # full fall of hair down the back
            rect(im, 4, 15, 11, 15, hair_d)
    elif direction == 0:                      # toward camera: fringe + eyes
        rect(im, 4, 3, 11, 6, hair)
        rect(im, 4, 6, 5, 7, hair)
        rect(im, 10, 6, 11, 7, hair)
        px(im, 6, 8, EYE); px(im, 9, 8, EYE)
        px(im, 6, 9, SKIN_D); px(im, 9, 9, SKIN_D)
    elif direction == 1:                      # left profile
        rect(im, 4, 3, 11, 6, hair)
        rect(im, 9, 3, 11, 9, hair)
        px(im, 5, 8, EYE)
    else:                                     # right profile
        rect(im, 4, 3, 11, 6, hair)
        rect(im, 4, 3, 6, 9, hair)
        px(im, 10, 8, EYE)

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


FURNITURE = {"chair": draw_chair, "table": draw_table, "desk": draw_desk}


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


def make_room():
    im = Image.new("RGBA", (ROOM_W * TILE, ROOM_H * TILE))
    for ty in range(ROOM_H):
        for tx in range(ROOM_W):
            edge = (tx == 0 or tx == ROOM_W - 1
                    or ty < TOP_WALL or ty == ROOM_H - 1)
            if edge:
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
    for name, fn in FURNITURE.items():
        img = fn()
        img.save(os.path.join(OUT, "%s.png" % name))
        print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    r = make_room()
    print("art/%-18s %3dx%-3d (%d x %d tiles of %d)"
          % ("room.png", r[0], r[1], ROOM_W, ROOM_H, TILE))
