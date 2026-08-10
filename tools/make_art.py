#!/usr/bin/env python3
"""Draw the two images this game needs: the character and the room.

Everything is hand-plotted pixel art, generated in code so it is easy to
tweak a colour or a proportion and re-run rather than repaint by hand.

    python tools/make_art.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

# --- character -------------------------------------------------------
CW, CH = 16, 24          # one frame
DIRS = 4                 # rows: down, left, right, up
FRAMES = 4               # cols: stand, step, stand, step (other foot)

SKIN = (240, 200, 160)
SKIN_D = (206, 162, 122)
HAIR = (107, 74, 47)
HAIR_D = (74, 50, 30)
SHIRT = (59, 125, 216)
SHIRT_D = (40, 90, 165)
PANTS = (78, 92, 130)
SHOE = (74, 53, 36)
LINE = (36, 26, 18)
EYE = (28, 24, 32)

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


def draw_char(direction, frame):
    """One 16x24 frame. `direction` 0=down 1=left 2=right 3=up."""
    im = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))

    # walk cycle: frames 1 and 3 lift opposite feet, 0 and 2 stand
    step = 0
    if frame == 1:
        step = 1
    elif frame == 3:
        step = -1

    # ---- legs ----
    l_off = max(0, step)
    r_off = max(0, -step)
    rect(im, 4, 18 - l_off, 6, 21 - l_off, PANTS)
    rect(im, 9, 18 - r_off, 11, 21 - r_off, PANTS)
    rect(im, 4, 22 - l_off, 6, 22 - l_off, SHOE)
    rect(im, 9, 22 - r_off, 11, 22 - r_off, SHOE)

    # ---- body ----
    rect(im, 4, 12, 11, 18, SHIRT)
    rect(im, 4, 17, 11, 18, SHIRT_D)        # shading under the torso

    # ---- arms (swing opposite to the legs) ----
    a_l = -step
    a_r = step
    rect(im, 2, 13 + a_l, 3, 17 + a_l, SHIRT_D)
    rect(im, 12, 13 + a_r, 13, 17 + a_r, SHIRT_D)
    px(im, 2, 18 + a_l, SKIN); px(im, 3, 18 + a_l, SKIN)
    px(im, 12, 18 + a_r, SKIN); px(im, 13, 18 + a_r, SKIN)

    # ---- head ----
    rect(im, 4, 4, 11, 11, SKIN)
    rect(im, 4, 11, 11, 11, SKIN_D)         # jaw shadow

    # ---- hair, which is what actually sells the facing ----
    if direction == 3:                       # away: all hair, no face
        rect(im, 4, 3, 11, 10, HAIR)
        rect(im, 4, 10, 11, 10, HAIR_D)
    elif direction == 0:                     # toward camera: fringe + eyes
        rect(im, 4, 3, 11, 6, HAIR)
        rect(im, 4, 6, 5, 7, HAIR)
        rect(im, 10, 6, 11, 7, HAIR)
        px(im, 6, 8, EYE); px(im, 9, 8, EYE)
        px(im, 6, 9, SKIN_D); px(im, 9, 9, SKIN_D)
    elif direction == 1:                     # left profile
        rect(im, 4, 3, 11, 6, HAIR)
        rect(im, 9, 3, 11, 9, HAIR)
        px(im, 5, 8, EYE)
    else:                                    # right profile
        rect(im, 4, 3, 11, 6, HAIR)
        rect(im, 4, 3, 6, 9, HAIR)
        px(im, 10, 8, EYE)

    # ---- outline pass: any transparent pixel touching the body ----
    src = im.copy()
    for y in range(CH):
        for x in range(CW):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CW and 0 <= ny < CH and src.getpixel((nx, ny))[3]:
                    px(im, x, y, LINE)
                    break
    return im


def make_character():
    sheet = Image.new("RGBA", (CW * FRAMES, CH * DIRS), (0, 0, 0, 0))
    for d in range(DIRS):
        for f in range(FRAMES):
            sheet.alpha_composite(draw_char(d, f), (f * CW, d * CH))
    sheet.save(os.path.join(OUT, "player.png"))
    return sheet.size


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
    c = make_character()
    r = make_room()
    print("art/player.png  %dx%d  (%d dirs x %d frames of %dx%d)"
          % (c[0], c[1], DIRS, FRAMES, CW, CH))
    print("art/room.png    %dx%d  (%d x %d tiles of %d)"
          % (r[0], r[1], ROOM_W, ROOM_H, TILE))
