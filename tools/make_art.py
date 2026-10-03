#!/usr/bin/env python3
"""Draw every image this game needs: characters, furniture, and the room.

Everything is hand-plotted pixel art, generated in code so it is easy to
tweak a colour or a proportion and re-run rather than repaint by hand.

    python tools/make_art.py
"""
import io
import os
import random

from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

LINE = (36, 26, 18)      # shared outline colour for everything
EYE = (28, 24, 32)

# --- characters ------------------------------------------------------
CW, CH = 32, 48          # one frame (doubled Aug 2026, was 16x24)
DIRS = 4                 # rows: down, left, right, up
# cols: stand, step, stand, step (other foot), SEATED, then four one-shot
# poses for scripted moments -- handing a paper across, mid-chat, a jump
# for joy, a sad head-down slump. (Aug 2026, room for real animation.)
FRAMES = 9
SIT_FRAME = 4            # must match Actor.SIT_FRAME in scripts/actors/actor.gd
POSE_HANDOFF = 5         # must match Actor.POSE_HANDOFF
POSE_CHAT = 6            # must match Actor.POSE_CHAT
POSE_JUMP = 7            # must match Actor.POSE_JUMP
POSE_SAD = 8             # must match Actor.POSE_SAD

# --- skin tones ------------------------------------------------------
# Named so a palette entry can say "tan" rather than carry three tuples.
# A raw (r, g, b) is still accepted in the `skin` key.
SKINS = {
    "fair": (250, 222, 196),
    "light": (240, 200, 160),
    "tan": (218, 170, 120),
    "brown": (170, 118, 78),
    "dark": (118, 78, 52),
}
SKIN = SKINS["light"]          # the historical default; other tools import it
SKIN_D = (206, 162, 122)

MOUTH = (118, 58, 62)          # a smile line; dark enough on every skin tone
MOUTH_OPEN = (70, 30, 36)      # the inside of an open mouth
TONGUE = (214, 104, 112)
TEETH = (250, 248, 244)
BLUSH = (240, 150, 140, 120)   # rosy cheeks, alpha-blended over any skin
TEAR = (120, 184, 244)
GLASS_FRAME = (48, 44, 54)
LENS = (200, 230, 255, 48)
HAIR_BAND = (226, 196, 96)     # the tie on a ponytail
LANYARD = (206, 64, 68)
BADGE = (246, 244, 236)
BADGE_STRIPE = (96, 150, 206)
LASH = (32, 24, 30)
SCLERA = (250, 250, 254)
PUPIL = (28, 22, 32)

HAIR_STYLES = ("short", "long", "curly", "spiky", "bob", "bun", "buzz",
               "ponytail")
PATTERNS = ("plain", "stripes", "dungarees", "collar", "tie", "cardigan",
            "lanyard")

# One drawing routine, many palettes. The REQUIRED keys are the ones
# Make a Sprite.bat has always written (hair/hair_d, shirt/shirt_d, legs,
# shoe, long_hair, skirt). Everything else is OPTIONAL with a safe default,
# so an old entry still draws and a new one can say more:
#   hair_style  one of HAIR_STYLES (default: "long" if long_hair else "short")
#   skin        a SKINS name or an (r, g, b) (default "light")
#   glasses     True/False (default False)
#   pattern     one of PATTERNS (default "plain") -- the adult cues
#               (tie / cardigan / lanyard) live here alongside the kids'
#               stripes and dungarees
#   sleeves     "long" or "short" (default "long")
#   tie, inner  the tie colour and the shirt seen inside a cardigan/collar
CHARACTERS = {
    "player": {
        "hair": (107, 74, 47), "hair_d": (74, 50, 30),
        "shirt": (59, 125, 216), "shirt_d": (40, 90, 165),
        "legs": (78, 92, 130), "shoe": (74, 53, 36),
        "long_hair": False, "skirt": False,
        "hair_style": "short", "skin": "light", "pattern": "lanyard",
        "eyes": (54, 120, 205),
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
        "hair_style": "short", "skin": "light", "pattern": "tie",
        "tie": (150, 40, 44),
        "eyes": (80, 110, 145),
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
        "hair_style": "short", "skin": "brown", "pattern": "tie",
        "tie": (222, 178, 70),
        "eyes": (180, 120, 40),
    },
    # The mentor teacher, in the small room off the hallway. Another
    # colleague rather than an authority figure, so a WARM everyday palette
    # -- rust cardigan, grey-streaked hair -- that reads as "an older
    # teacher" without borrowing the principal's purple or the inspector's
    # grey suit. One palette entry, same generator, same as everyone else.
    "mentor": {
        "hair": (150, 138, 120), "hair_d": (112, 100, 84),
        "shirt": (176, 96, 58), "shirt_d": (132, 68, 40),
        "legs": (86, 74, 62), "shoe": (52, 42, 34),
        "long_hair": True, "skirt": False,
        "hair_style": "long", "skin": "light", "pattern": "cardigan",
        "glasses": True,
        "eyes": (130, 80, 45),
    },
    # The examiner, who invigilates the end-of-term assessment. Austere:
    # charcoal-navy suit, silver hair in a bun, glasses -- built to be told
    # apart from the grey-suited inspector and the purple principal at a
    # glance, since all three are adults who turn up unannounced.
    "examiner": {
        "hair": (198, 200, 206), "hair_d": (148, 150, 160),
        "shirt": (40, 48, 82), "shirt_d": (26, 32, 58),
        "legs": (34, 38, 60), "shoe": (24, 22, 30),
        "long_hair": False, "skirt": True,
        "hair_style": "bun", "skin": "fair", "pattern": "collar",
        "glasses": True,
        "eyes": (55, 75, 115),
    },
    # Eight students. Two identical sprites across eight desks badly
    # undercuts "these are individual kids", and this is a data-table edit
    # rather than any new drawing code. Keys must match Names.ART in
    # scripts/data/names.gd. Each one differs in at least two of hair
    # style / skin / clothing pattern from every other, so they read as
    # eight people at desk distance and not as recolours.
    "student_a": {
        "hair": (58, 44, 38), "hair_d": (38, 28, 24),
        "shirt": (86, 166, 96), "shirt_d": (58, 124, 68),
        "legs": (104, 84, 64), "shoe": (58, 46, 40),
        "long_hair": False, "skirt": False,
        "hair_style": "spiky", "skin": "tan", "pattern": "stripes",
        "sleeves": "short",
        "eyes": (160, 95, 40),
    },
    "student_b": {
        "hair": (168, 102, 52), "hair_d": (126, 74, 36),
        "shirt": (214, 96, 124), "shirt_d": (170, 66, 94),
        "legs": (196, 158, 190), "shoe": (92, 60, 72),
        "long_hair": True, "skirt": True,
        "hair_style": "bob", "skin": "light", "pattern": "collar",
        "sleeves": "short",
        "eyes": (145, 80, 165),
    },
    "student_c": {
        "hair": (222, 190, 104), "hair_d": (176, 142, 66),
        "shirt": (238, 200, 84), "shirt_d": (194, 156, 52),
        "legs": (72, 96, 148), "shoe": (54, 44, 38),
        "long_hair": False, "skirt": False,
        "hair_style": "short", "skin": "fair", "pattern": "dungarees",
        "sleeves": "short",
        "eyes": (45, 125, 210),
    },
    "student_d": {
        "hair": (72, 52, 44), "hair_d": (48, 34, 30),
        "shirt": (150, 108, 196), "shirt_d": (110, 76, 152),
        "legs": (188, 166, 208), "shoe": (74, 58, 76),
        "long_hair": True, "skirt": True,
        "hair_style": "long", "skin": "brown", "pattern": "plain",
        "sleeves": "long",
        "eyes": (95, 55, 35),
    },
    "student_e": {
        "hair": (206, 108, 58), "hair_d": (158, 76, 38),
        "shirt": (232, 138, 72), "shirt_d": (184, 100, 48),
        "legs": (108, 112, 120), "shoe": (56, 50, 46),
        "long_hair": False, "skirt": False,
        "hair_style": "curly", "skin": "light", "pattern": "stripes",
        "sleeves": "short",
        "eyes": (45, 145, 85),
    },
    "student_f": {
        "hair": (40, 38, 48), "hair_d": (26, 24, 32),
        "shirt": (78, 176, 172), "shirt_d": (50, 132, 130),
        "legs": (160, 176, 184), "shoe": (52, 58, 62),
        "long_hair": True, "skirt": True,
        "hair_style": "ponytail", "skin": "dark", "pattern": "plain",
        "sleeves": "short",
        "eyes": (55, 40, 35),
    },
    "student_g": {
        "hair": (140, 104, 66), "hair_d": (100, 72, 44),
        "shirt": (206, 82, 76), "shirt_d": (160, 54, 52),
        "legs": (58, 68, 104), "shoe": (48, 42, 40),
        "long_hair": False, "skirt": False,
        "hair_style": "buzz", "skin": "brown", "pattern": "collar",
        "sleeves": "long",
        "eyes": (120, 80, 40),
    },
    "student_h": {
        "hair": (222, 218, 208), "hair_d": (176, 172, 166),
        "shirt": (128, 206, 168), "shirt_d": (88, 160, 126),
        "legs": (200, 196, 188), "shoe": (70, 74, 72),
        "long_hair": True, "skirt": True,
        "hair_style": "bun", "skin": "fair", "pattern": "dungarees",
        "sleeves": "short",
        "eyes": (45, 155, 215),
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
# school flooring actually looks, rather than a chequerboard. Grout
# warmed and softened Sept 2026 -- the old cool grey read as concrete
# next to the new warm plaster walls.
FLOOR_A = (224, 214, 194)
FLOOR_B = (214, 203, 182)
FLOOR_GROUT = (204, 188, 160)
FLOOR_FLECK = (202, 190, 168)

# Warm painted plaster -- Sept 2026, the art overhaul. Replaces the flat
# red brick every wall used to be, one of the launch complaints ("heavy
# flat-red-brick walls"): a lived-in classroom is a painted wall, not
# exposed brick, and cream reads warmer under the window light besides.
# The names (WALL, WALL_L, ...) are unchanged so door_tile()/window_tile()
# below did not need to change what they ask for, only what they get.
WALL = (230, 210, 178)
WALL_L = (242, 226, 198)
WALL_D = (204, 182, 150)
WALL_TOP = (246, 234, 210)     # the lit course along the very top of the wall
WALL_BASE = (72, 48, 30)       # now doubles as the skirting-board colour

# The dado: a painted wood wainscot along the ROOM-FACING wall
# (tile_wall_bottom only -- see wall_tile()), finished with a chair rail
# above it and the dark WALL_BASE skirting board where it meets the floor.
DADO = (146, 100, 62)
DADO_L = (176, 128, 82)
DADO_D = (104, 70, 42)
RAIL = (208, 184, 142)

# Painted door and window frames, deliberately NOT wall-coloured so the
# ways in and out read at a glance against the plaster.
DOOR_PAINT = (58, 118, 132)
DOOR_PAINT_L = (86, 154, 168)
DOOR_PAINT_D = (36, 80, 92)
HANDLE = (222, 186, 108)
HANDLE_D = (164, 130, 66)

# The window: a dusk sky gradient rather than flat daytime blue -- cool
# blue-violet near the ceiling, warming toward the sill, like the last
# light of the day. GLASS/GLASS_L/GLASS_D keep their old names (used by
# the top- and bottom-half tiles respectively) but now carry that
# gradient instead of one flat blue.
GLASS = (150, 138, 180)         # upper pane: dusk blue-violet
GLASS_L = (176, 162, 204)
GLASS_D = (238, 176, 110)       # lower pane: warm, low-in-the-sky glow
GLASS_D_L = (250, 202, 144)
SKY_MID = (206, 146, 128)       # the horizon band each half fades toward
CURTAIN = (172, 78, 66)
CURTAIN_L = (200, 108, 90)
CURTAIN_D = (128, 54, 46)
FRAME = (238, 234, 224)
FRAME_L = (250, 248, 242)
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


def scale2x(img):
    """Double an image's size the way pixel-art upscalers do -- not a resize.

    A plain nearest-neighbour 2x would be a complete no-op on screen: the
    window doubled exactly as much as the art, so every source pixel would
    still land on the same physical screen pixels it always did. This is
    Scale2x/AdvMAME2x instead -- decades old, used in emulators for exactly
    this problem. For each source pixel P with neighbours above/below/left/
    right (B/H/D/F), a diagonal corner of its 2x2 block is redrawn in a
    NEIGHBOUR colour rather than P's own wherever that neighbour agrees with
    one adjacent side and disagrees with the perpendicular one -- which is
    precisely the situation a staircased diagonal edge produces. Flat edges
    and solid fills are untouched and stay perfectly crisp; only the actual
    diagonals gain real new pixels that were not decidable from one sample.
    """
    w, h = img.size
    src = img.convert("RGBA")
    get = src.getpixel
    out = Image.new("RGBA", (w * 2, h * 2))
    put = out.putpixel
    for y in range(h):
        for x in range(w):
            p = get((x, y))
            b = get((x, y - 1)) if y > 0 else p
            d = get((x - 1, y)) if x > 0 else p
            f = get((x + 1, y)) if x < w - 1 else p
            hh = get((x, y + 1)) if y < h - 1 else p
            if b != hh and d != f:
                e0 = d if d == b else p
                e1 = b if b == f else p
                e2 = d if d == hh else p
                e3 = f if f == hh else p
            else:
                e0 = e1 = e2 = e3 = p
            put((x * 2, y * 2), e0)
            put((x * 2 + 1, y * 2), e1)
            put((x * 2, y * 2 + 1), e2)
            put((x * 2 + 1, y * 2 + 1), e3)
    return out


# ====================================================================
# characters
# ====================================================================

def mix(c, target, amt):
    return tuple(int(round(c[i] + (target[i] - c[i]) * amt)) for i in range(3))


def lighter(c, amt=0.22):
    return mix(c[:3], (255, 255, 255), amt)


def darker(c, amt=0.22):
    return mix(c[:3], (0, 0, 0), amt)


def blend(img, x, y, c):
    """Alpha-blend an (r, g, b, a) over whatever is at (x, y)."""
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    r, g, b, a = img.getpixel((x, y))
    if a == 0:
        return
    t = c[3] / 255.0
    img.putpixel((x, y), (int(r + (c[0] - r) * t), int(g + (c[1] - g) * t),
                          int(b + (c[2] - b) * t), a))


def blend_rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            blend(img, x, y, c)


# Pixel masks for a rounded corner, by radius: which (i, j) offsets from
# the corner are left out. Explicit rather than a circle test, because at
# 2-4px a circle test rounds either too little or too much to read.
_CORNER = {
    0: (),
    1: ((0, 0),),
    2: ((0, 0), (1, 0), (0, 1)),
    3: ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (0, 2)),
    4: ((0, 0), (1, 0), (2, 0), (3, 0), (0, 1), (1, 1), (0, 2), (0, 3)),
    5: ((0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (0, 1), (1, 1), (2, 1),
        (0, 2), (1, 2), (0, 3), (0, 4)),
}


def _corner_cut(i, j, r):
    if i >= r or j >= r:
        return False
    if r <= 5:
        return (i, j) in _CORNER[r]
    dx = r - 0.5 - i
    dy = r - 0.5 - j
    return dx * dx + dy * dy > r * r


def rrect(img, x0, y0, x1, y1, c, r=2, r_top=None, r_bottom=None):
    """A filled rectangle with rounded corners. Corners are SKIPPED, not
    cleared, so a rounded shape can sit over something already drawn."""
    rt = r if r_top is None else r_top
    rb = r if r_bottom is None else r_bottom
    w = x1 - x0 + 1
    h = y1 - y0 + 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            i = x - x0
            j = y - y0
            if rt and _corner_cut(i, j, rt):
                continue
            if rt and _corner_cut(w - 1 - i, j, rt):
                continue
            if rb and _corner_cut(i, h - 1 - j, rb):
                continue
            if rb and _corner_cut(w - 1 - i, h - 1 - j, rb):
                continue
            px(img, x, y, c)


def ring(img, x0, y0, x1, y1, c, r=2, thickness=1):
    """The outline of a rounded rectangle only -- for spectacle frames."""
    m = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rrect(m, x0, y0, x1, y1, c, r)
    inner = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rrect(inner, x0 + thickness, y0 + thickness, x1 - thickness,
          y1 - thickness, c, max(0, r - thickness))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < img.width and 0 <= y < img.height:
                if m.getpixel((x, y))[3] and not inner.getpixel((x, y))[3]:
                    px(img, x, y, c)


def refill(img, x0, y0, x1, y1, frm, to):
    """Recolour only the pixels of one colour inside a box -- a stripe that
    stops at the edge of the shirt rather than the edge of the box."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < img.width and 0 <= y < img.height:
                if img.getpixel((x, y))[:3] == tuple(frm[:3]):
                    px(img, x, y, to)


def rim_light(img, amt=0.18):
    """The one shading rule everything shares: light from the upper-left.

    Every opaque pixel on the silhouette's top or left edge is lifted, and
    every one on its bottom or right edge is dropped. Applied AFTER a
    frame is mirrored, so a right-facing sprite is lit from the same side
    as a left-facing one -- which a mirrored highlight would not be.
    """
    src = img.copy()
    w, h = img.size
    get = src.getpixel
    for y in range(h):
        for x in range(w):
            c = get((x, y))
            if c[3] == 0:
                continue
            up = y == 0 or get((x, y - 1))[3] == 0
            left = x == 0 or get((x - 1, y))[3] == 0
            down = y == h - 1 or get((x, y + 1))[3] == 0
            right = x == w - 1 or get((x + 1, y))[3] == 0
            lit = up or left
            dark = down or right
            if lit and not dark:
                img.putpixel((x, y), lighter(c, amt) + (c[3],))
            elif dark and not lit:
                img.putpixel((x, y), darker(c, amt) + (c[3],))


def finish(im, amt=0.14):
    """The furniture/props finishing pass -- the art overhaul's consistency
    rule (Sept 2026): every placed object gets the SAME upper-left highlight,
    lower-right shade that draw_char() gives every person, so a desk and the
    teacher standing at it agree about where the window is. A softer `amt`
    than characters use (0.18) -- most furniture is flatter, larger blocks of
    colour than a 32x48 sprite, and the stronger amount blew out the flattest
    fills (a whiteboard's face, a table top) into visibly banded steps.
    Call this in place of a bare `outline(im)` at the end of a draw_*()."""
    rim_light(im, amt)
    return outline(im)


def second_band(img, amt2=0.09):
    """A second, softer shading ring one pixel further in from the
    silhouette edge, layered ON TOP of whatever rim_light already did --
    it does not redo rim_light's own edge band, only adds one more step
    inward, so a flat fill gets a two-step gradient instead of a hard 1px
    edge. Style reference: limezu's "Modern Farm" pack (Oct 2026) -- its
    props carry a visible multi-step highlight/shadow across large flat
    faces (a roof, a barrel) where a single edge band reads flatter by
    comparison. Call this AFTER rim_light, at whatever resolution
    rim_light itself was applied at (characters: the 32x48 build, before
    the pixel-grid quantise; furniture: native low-res, same as finish).
    """
    src = img.copy()
    w, h = img.size
    get = src.getpixel
    for y in range(h):
        for x in range(w):
            c = get((x, y))
            if c[3] == 0:
                continue
            # Skip the silhouette edge itself -- rim_light already set it.
            if (y == 0 or get((x, y - 1))[3] == 0
                    or x == 0 or get((x - 1, y))[3] == 0
                    or y == h - 1 or get((x, y + 1))[3] == 0
                    or x == w - 1 or get((x + 1, y))[3] == 0):
                continue
            up = y <= 1 or get((x, y - 2))[3] == 0
            left = x <= 1 or get((x - 2, y))[3] == 0
            down = y >= h - 2 or get((x, y + 2))[3] == 0
            right = x >= w - 2 or get((x + 2, y))[3] == 0
            lit = up or left
            dark = down or right
            if lit and not dark:
                img.putpixel((x, y), lighter(c, amt2) + (c[3],))
            elif dark and not lit:
                img.putpixel((x, y), darker(c, amt2) + (c[3],))


def rim_light2(img, amt=0.20, amt2=0.09):
    """rim_light() followed by second_band() -- the combined two-band
    pass furniture's finish_rich() uses. See second_band() for why the
    two are kept separate: characters need the second band applied at a
    different resolution than the first."""
    rim_light(img, amt)
    second_band(img, amt2)


def finish_rich(im, amt=0.20, amt2=0.09):
    """finish(), but with rim_light2's two-band gradient in place of the
    single hard-edge band -- the richer, more dimensional look used for
    the classroom-overlap furniture redrawn against the Modern Farm pack
    as a style reference (Oct 2026): bench, crate, cabinet, stool,
    supply_shelf. Everything else keeps calling plain finish()."""
    rim_light2(im, amt, amt2)
    return outline(im)


def resolve_palette(pal):
    """Fill in every optional key and derive the shading tones."""
    p = dict(pal)
    p.setdefault("long_hair", False)
    p.setdefault("skirt", False)
    p.setdefault("hair_style", "long" if p["long_hair"] else "short")
    p.setdefault("skin", "light")
    p.setdefault("glasses", False)
    p.setdefault("pattern", "plain")
    p.setdefault("sleeves", "long")
    p.setdefault("tie", (176, 52, 56))
    p.setdefault("inner", (236, 232, 222))
    p.setdefault("eyes", EYE)
    if p["hair_style"] not in HAIR_STYLES:
        p["hair_style"] = "short"
    if p["pattern"] not in PATTERNS:
        p["pattern"] = "plain"
    skin = p["skin"]
    if isinstance(skin, str):
        skin = SKINS.get(skin, SKINS["light"])
    p["skin_c"] = tuple(skin)
    p["skin_d"] = darker(skin, 0.18)
    p["skin_l"] = lighter(skin, 0.18)
    p["hair_l"] = lighter(p["hair"], 0.28)
    p["shirt_l"] = lighter(p["shirt"], 0.28)
    p["legs_d"] = darker(p["legs"], 0.25)
    p["shoe_l"] = lighter(p["shoe"], 0.35)
    p["tie_l"] = lighter(p["tie"], 0.3)
    p["eyes_l"] = lighter(p["eyes"], 0.35)
    p["eyes_d"] = darker(p["eyes"], 0.25)
    return p


# Head box shared by every facing: x 4..27, y 4..29 in a 32x48 cell, hair
# top at y=4 -- the row Player.refresh_hat()'s HatSprite offset assumes.
HX0, HY0, HX1, HY1 = 4, 4, 27, 29
# Torso box, front/back: x 8..23, y 30..39. Profile: x 10..21.
TX0, TY0, TX1, TY1 = 8, 30, 23, 39


def _hair_front(im, p, dy, extras_only=False):
    """Hair as seen from the front, per style. Long styles also lay hair
    down beside the body; the caller draws those strands BEFORE the torso
    (behind the shoulders) by calling with extras_only."""
    st = p["hair_style"]
    hair, hair_d, hair_l = p["hair"], p["hair_d"], p["hair_l"]
    if extras_only:
        if st == "long":
            rrect(im, 3, 10 + dy, 6, 36 + dy, hair, r_top=0, r_bottom=2)
            rrect(im, 25, 10 + dy, 28, 36 + dy, hair, r_top=0, r_bottom=2)
            rect(im, 3, 35 + dy, 6, 36 + dy, hair_d)
            rect(im, 25, 35 + dy, 28, 36 + dy, hair_d)
        elif st == "ponytail":
            rrect(im, 25, 12 + dy, 29, 31 + dy, hair, r_top=0, r_bottom=2)
            rect(im, 26, 13 + dy, 29, 13 + dy, HAIR_BAND)
        return
    if st == "bun":
        rrect(im, 11, 0 + dy, 20, 5 + dy, hair, r=2)
        rect(im, 12, 5 + dy, 19, 5 + dy, hair_d)
    if st == "buzz":
        rrect(im, HX0, HY0 + dy, HX1, 9 + dy, hair, r_top=3, r_bottom=0)
        rect(im, HX0 + 1, 9 + dy, HX1 - 1, 9 + dy, hair_d)
        rect(im, 8, 5 + dy, 14, 5 + dy, hair_l)
        return
    # the cap every other style shares
    rrect(im, HX0, HY0 + dy, HX1, 11 + dy, hair, r_top=3, r_bottom=0)
    rect(im, HX0, 11 + dy, HX1, 11 + dy, hair_d)
    rect(im, 8, 5 + dy, 15, 6 + dy, hair_l)
    if st == "bob":
        rect(im, HX0, 12 + dy, HX1, 12 + dy, hair)        # straight fringe
        rect(im, HX0, 13 + dy, HX1, 13 + dy, hair_d)
        rrect(im, 3, 12 + dy, 6, 25 + dy, hair, r_top=0, r_bottom=2)
        rrect(im, 25, 12 + dy, 28, 25 + dy, hair, r_top=0, r_bottom=2)
        rect(im, 3, 24 + dy, 6, 25 + dy, hair_d)
        rect(im, 25, 24 + dy, 28, 25 + dy, hair_d)
        return
    # a fringe with a few notches, so it is hair rather than a helmet
    for x0, x1 in ((6, 8), (13, 16), (21, 23)):
        rect(im, x0, 12 + dy, x1, 12 + dy, hair_d)
    # side locks down past the ears
    rect(im, HX0, 12 + dy, HX0 + 1, 15 + dy, hair)
    rect(im, HX1 - 1, 12 + dy, HX1, 15 + dy, hair)
    if st == "curly":
        for x, y in ((3, 7), (3, 8), (3, 12), (3, 13), (28, 7), (28, 8),
                     (28, 12), (28, 13), (6, 3), (7, 3), (12, 3), (13, 3),
                     (18, 3), (19, 3), (24, 3), (25, 3)):
            px(im, x, y + dy, hair)
        for x, y in ((7, 8), (11, 6), (16, 9), (20, 5), (24, 8), (10, 10),
                     (22, 10)):
            px(im, x, y + dy, hair_d)
    elif st == "spiky":
        for cx in (7, 12, 17, 22):
            rect(im, cx - 1, 3 + dy, cx, 3 + dy, hair)
            px(im, cx, 2 + dy, hair)
            px(im, cx + 1, 1 + dy, hair)
    elif st == "long":
        rect(im, 3, 10 + dy, 3, 11 + dy, hair)
        rect(im, 28, 10 + dy, 28, 11 + dy, hair)


def _face_front(im, p, dy, pose):
    eyes = p["eyes"]
    eyes_l = p.get("eyes_l", lighter(eyes, 0.35))
    # Pokemon-style eyes: defined upper lash, white sclera, vibrant iris, specular catchlight
    for ex in (8, 20):
        # Sclera base (outer/lower white)
        rect(im, ex, 16 + dy, ex + 3, 19 + dy, SCLERA)
        # Upper lash line (dark, defines eye shape)
        rect(im, ex, 15 + dy, ex + 3, 15 + dy, LASH)
        px(im, ex - 1 if ex == 8 else ex + 4, 15 + dy, LASH)
        # Iris & pupil: dark pupil at top, vibrant iris color below
        rect(im, ex + 1, 16 + dy, ex + 2, 17 + dy, PUPIL)
        rect(im, ex + 1, 18 + dy, ex + 2, 19 + dy, eyes)
        px(im, ex + 2, 19 + dy, eyes_l)
        # Brilliant specular catchlight (upper corner)
        px(im, ex, 16 + dy, (255, 255, 255))
        px(im, ex + 1, 16 + dy, (255, 255, 255))

    # brows
    if pose == POSE_SAD:
        for x, y in ((8, 14), (9, 14), (10, 13), (11, 13),
                     (20, 13), (21, 13), (22, 14), (23, 14)):
            px(im, x, y + dy, p["hair_d"])
    else:
        rect(im, 8, 13 + dy, 11, 13 + dy, p["hair_d"])
        rect(im, 20, 13 + dy, 23, 13 + dy, p["hair_d"])

    # nose
    rect(im, 15, 21 + dy, 16, 21 + dy, p["skin_d"])

    # mouth, by mood
    if pose == POSE_SAD:
        rect(im, 15, 24 + dy, 16, 25 + dy, MOUTH)
        px(im, 8, 21 + dy, TEAR)
        px(im, 8, 22 + dy, TEAR)
    elif pose == POSE_CHAT:
        rect(im, 14, 24 + dy, 17, 26 + dy, MOUTH_OPEN)
        rect(im, 15, 26 + dy, 16, 26 + dy, TONGUE)
    elif pose == POSE_JUMP:
        px(im, 12, 23 + dy, MOUTH)
        px(im, 19, 23 + dy, MOUTH)
        rect(im, 13, 24 + dy, 18, 25 + dy, MOUTH_OPEN)
        rect(im, 14, 24 + dy, 17, 24 + dy, TEETH)
    else:
        px(im, 13, 24 + dy, MOUTH)
        px(im, 18, 24 + dy, MOUTH)
        rect(im, 14, 25 + dy, 17, 25 + dy, MOUTH)

    # cheeks
    blend_rect(im, 5, 21 + dy, 7, 22 + dy, BLUSH)
    blend_rect(im, 24, 21 + dy, 26, 22 + dy, BLUSH)

    if p["glasses"]:
        blend_rect(im, 8, 15 + dy, 11, 19 + dy, LENS)
        blend_rect(im, 20, 15 + dy, 23, 19 + dy, LENS)
        ring(im, 7, 14 + dy, 12, 20 + dy, GLASS_FRAME, r=1)
        ring(im, 19, 14 + dy, 24, 20 + dy, GLASS_FRAME, r=1)
        rect(im, 13, 16 + dy, 18, 16 + dy, GLASS_FRAME)
        rect(im, 4, 15 + dy, 6, 15 + dy, GLASS_FRAME)
        rect(im, 25, 15 + dy, 27, 15 + dy, GLASS_FRAME)


def _torso_pattern_front(im, p, dy, back=False):
    """Clothing detail over a plain shirt box x 8..23, y 30..39 (+dy)."""
    pat = p["pattern"]
    shirt, shirt_l, shirt_d = p["shirt"], p["shirt_l"], p["shirt_d"]
    y0 = TY0 + dy
    if pat == "stripes":
        for y in (y0 + 3, y0 + 4, y0 + 7, y0 + 8):
            refill(im, 0, y, CW - 1, y, shirt, shirt_l)
    elif pat == "dungarees":
        rect(im, 11, y0 + 3, 20, y0 + 9, p["legs"])
        rect(im, 11, y0, 12, y0 + 3, p["legs"])
        rect(im, 19, y0, 20, y0 + 3, p["legs"])
        rect(im, 11, y0 + 9, 20, y0 + 9, p["legs_d"])
        if not back:
            px(im, 12, y0 + 3, HAIR_BAND)
            px(im, 19, y0 + 3, HAIR_BAND)
    elif pat == "collar":
        rect(im, 12, y0, 19, y0 + 1, p["inner"])
        if not back:
            px(im, 12, y0 + 2, p["inner"])
            px(im, 19, y0 + 2, p["inner"])
            rect(im, 15, y0 + 2, 16, y0 + 2, shirt_d)
    elif pat == "tie" and not back:
        rect(im, 12, y0, 19, y0, p["inner"])
        rect(im, 14, y0, 17, y0 + 1, p["tie"])
        rect(im, 15, y0 + 2, 16, y0 + 7, p["tie"])
        px(im, 15, y0 + 3, p["tie_l"])
    elif pat == "cardigan" and not back:
        rect(im, 13, y0, 18, y0 + 1, p["inner"])
        rect(im, 14, y0 + 2, 17, y0 + 3, p["inner"])
        rect(im, 15, y0 + 4, 16, y0 + 5, p["inner"])
        rect(im, 12, y0, 12, y0 + 9, shirt_d)
        rect(im, 19, y0, 19, y0 + 9, shirt_d)
        px(im, 15, y0 + 7, LINE)
        px(im, 16, y0 + 7, LINE)
    elif pat == "lanyard":
        if back:
            rect(im, 12, y0, 19, y0, LANYARD)
        else:
            for x, y in ((12, 0), (12, 1), (13, 2), (13, 3), (14, 4), (14, 5),
                         (19, 0), (19, 1), (18, 2), (18, 3), (17, 4), (17, 5)):
                px(im, x, y0 + y, LANYARD)
            rect(im, 14, y0 + 6, 17, y0 + 8, BADGE)
            rect(im, 15, y0 + 7, 16, y0 + 7, BADGE_STRIPE)


def _arm_front(im, p, x0, y0, length, hand=True):
    """One arm hanging from (x0, y0), 3px wide: sleeve then hand."""
    sleeve = length if p["sleeves"] == "long" else max(2, length // 2)
    rect(im, x0, y0, x0 + 2, y0 + sleeve - 1, p["shirt"])
    if sleeve < length:
        rect(im, x0, y0 + sleeve, x0 + 2, y0 + length - 1, p["skin_c"])
    if hand:
        rect(im, x0, y0 + length, x0 + 2, y0 + length + 1, p["skin_c"])


def _legs_front(im, p, step, seated, pose):
    legs, legs_d, shoe, shoe_l = p["legs"], p["legs_d"], p["shoe"], p["shoe_l"]
    if seated:
        # thighs toward the camera, feet out of sight under the desk
        for x0 in (9, 17):
            rect(im, x0, 44, x0 + 4, 47, legs)
            px(im, x0 + 4, 44, legs_d)
            px(im, x0 + 4, 45, legs_d)
        return
    if pose == POSE_JUMP:
        rect(im, 10, 36, 21, 40, legs)
        rect(im, 9, 41, 21, 43, shoe)
        return
    lifts = {10: max(0, step) * 2, 17: max(0, -step) * 2}
    for x0, lift in lifts.items():
        rect(im, x0, 40 - lift, x0 + 4, 45 - lift, legs)
        rect(im, x0 + 4, 40 - lift, x0 + 4, 45 - lift, legs_d)
        rect(im, x0 - 1, 45 - lift, x0 + 4, 47 - lift, shoe)
        px(im, x0, 45 - lift, shoe_l)


def _front(im, p, dy, step, seated, pose):
    skin, skin_d = p["skin_c"], p["skin_d"]
    shirt, shirt_d, shirt_l = p["shirt"], p["shirt_d"], p["shirt_l"]
    hy = dy   # head offset
    _legs_front(im, p, step, seated, pose)
    _hair_front(im, p, hy, extras_only=True)
    # torso
    rrect(im, TX0, TY0 + dy, TX1, TY1 + dy, shirt, r_top=1, r_bottom=0)
    rect(im, 9, 31 + dy, 14, 31 + dy, shirt_l)
    rect(im, TX0, TY1 - 1 + dy, TX1, TY1 + dy, shirt_d)
    _torso_pattern_front(im, p, dy)
    if p["skirt"] and not seated and pose != POSE_JUMP:
        rect(im, 8, 38 + dy, 23, 38 + dy, shirt)
        rect(im, 7, 39 + dy, 24, 40 + dy, shirt)
        rect(im, 6, 41 + dy, 25, 41 + dy, shirt_d)
    # arms
    if pose == POSE_HANDOFF:
        rect(im, 3, 32 + dy, 7, 34 + dy, shirt)
        rect(im, 24, 32 + dy, 28, 34 + dy, shirt)
        rect(im, 1, 32 + dy, 2, 34 + dy, skin)
        rect(im, 29, 32 + dy, 30, 34 + dy, skin)
    elif pose == POSE_SAD:
        _arm_front(im, p, 5, 32 + dy, 9)
        _arm_front(im, p, 24, 32 + dy, 9)
    elif pose == POSE_JUMP:
        rect(im, 1, 20 + dy, 3, 31 + dy, shirt)
        rect(im, 28, 20 + dy, 30, 31 + dy, shirt)
        rect(im, 1, 17 + dy, 3, 19 + dy, skin)
        rect(im, 28, 17 + dy, 30, 19 + dy, skin)
    elif seated:
        rect(im, 5, 35 + dy, 7, 39 + dy, shirt)
        rect(im, 24, 35 + dy, 26, 39 + dy, shirt)
        rect(im, 6, 40 + dy, 9, 41 + dy, skin)
        rect(im, 22, 40 + dy, 25, 41 + dy, skin)
    elif pose == POSE_CHAT:
        _arm_front(im, p, 5, 31 + dy, 6)
    else:
        _arm_front(im, p, 5, 31 + dy - step * 2, 6)
        _arm_front(im, p, 24, 31 + dy + step * 2, 6)
    # head
    rrect(im, HX0, HY0 + hy, HX1, HY1 + hy, skin, r=3)
    rect(im, 6, 28 + hy, 25, 29 + hy, skin_d)
    _hair_front(im, p, hy)
    _face_front(im, p, hy, pose)
    if pose == POSE_CHAT:
        # the other hand comes up beside the face, mid-sentence
        rect(im, 25, 26 + dy, 27, 33 + dy, shirt)
        rect(im, 25, 23 + dy, 27, 25 + dy, skin)


def _back(im, p, dy, step, seated, pose):
    skin, skin_d = p["skin_c"], p["skin_d"]
    hair, hair_d, hair_l = p["hair"], p["hair_d"], p["hair_l"]
    shirt, shirt_d = p["shirt"], p["shirt_d"]
    st = p["hair_style"]
    _legs_front(im, p, step, seated, pose)
    rrect(im, TX0, TY0 + dy, TX1, TY1 + dy, shirt, r_top=1, r_bottom=0)
    rect(im, TX0, TY1 - 1 + dy, TX1, TY1 + dy, shirt_d)
    _torso_pattern_front(im, p, dy, back=True)
    if p["skirt"] and not seated and pose != POSE_JUMP:
        rect(im, 8, 38 + dy, 23, 38 + dy, shirt)
        rect(im, 7, 39 + dy, 24, 40 + dy, shirt)
        rect(im, 6, 41 + dy, 25, 41 + dy, shirt_d)
    if pose == POSE_HANDOFF:
        rect(im, 3, 32 + dy, 7, 34 + dy, shirt)
        rect(im, 24, 32 + dy, 28, 34 + dy, shirt)
        rect(im, 1, 32 + dy, 2, 34 + dy, skin)
        rect(im, 29, 32 + dy, 30, 34 + dy, skin)
    elif pose == POSE_SAD:
        _arm_front(im, p, 5, 32 + dy, 9)
        _arm_front(im, p, 24, 32 + dy, 9)
    elif pose == POSE_JUMP:
        rect(im, 1, 20 + dy, 3, 31 + dy, shirt)
        rect(im, 28, 20 + dy, 30, 31 + dy, shirt)
        rect(im, 1, 17 + dy, 3, 19 + dy, skin)
        rect(im, 28, 17 + dy, 30, 19 + dy, skin)
    elif seated:
        rect(im, 5, 35 + dy, 7, 39 + dy, shirt)
        rect(im, 24, 35 + dy, 26, 39 + dy, shirt)
    elif pose == POSE_CHAT:
        _arm_front(im, p, 5, 31 + dy, 6)
        rect(im, 25, 26 + dy, 27, 33 + dy, shirt)
        rect(im, 25, 23 + dy, 27, 25 + dy, skin)
    else:
        _arm_front(im, p, 5, 31 + dy - step * 2, 6)
        _arm_front(im, p, 24, 31 + dy + step * 2, 6)
    # head: skin at the nape, then hair over nearly all of it
    rrect(im, HX0, HY0 + dy, HX1, HY1 + dy, skin, r=3)
    rect(im, 6, 28 + dy, 25, 29 + dy, skin_d)
    hair_bottom = {"buzz": 22, "short": 25, "spiky": 25, "curly": 25,
                   "bun": 25, "ponytail": 25, "bob": 27, "long": 29}[st]
    rrect(im, HX0, HY0 + dy, HX1, hair_bottom + dy, hair, r_top=3, r_bottom=2)
    rect(im, HX0 + 1, hair_bottom + dy, HX1 - 1, hair_bottom + dy, hair_d)
    rect(im, 8, 5 + dy, 15, 6 + dy, hair_l)
    if st == "long":
        rrect(im, 6, 26 + dy, 25, 38 + dy, hair, r_top=0, r_bottom=3)
        rect(im, 7, 37 + dy, 24, 38 + dy, hair_d)
    elif st == "bob":
        rect(im, 3, 20 + dy, 3, 27 + dy, hair)
        rect(im, 28, 20 + dy, 28, 27 + dy, hair)
    elif st == "bun":
        rrect(im, 11, 0 + dy, 20, 5 + dy, hair, r=2)
        rect(im, 12, 5 + dy, 19, 5 + dy, hair_d)
        rect(im, 13, 2 + dy, 16, 2 + dy, hair_l)
    elif st == "ponytail":
        rrect(im, 13, 22 + dy, 18, 37 + dy, hair, r_top=0, r_bottom=2)
        rect(im, 13, 23 + dy, 18, 24 + dy, HAIR_BAND)
        rect(im, 14, 36 + dy, 17, 37 + dy, hair_d)
    elif st == "curly":
        for x, y in ((3, 7), (3, 8), (3, 12), (3, 13), (3, 18), (3, 19),
                     (28, 7), (28, 8), (28, 12), (28, 13), (28, 18), (28, 19),
                     (6, 3), (7, 3), (12, 3), (13, 3), (18, 3), (19, 3),
                     (24, 3), (25, 3)):
            px(im, x, y + dy, hair)
        for x, y in ((7, 9), (12, 13), (17, 8), (22, 12), (10, 18), (20, 20),
                     (15, 22)):
            px(im, x, y + dy, hair_d)
    elif st == "spiky":
        for cx in (7, 12, 17, 22):
            rect(im, cx - 1, 3 + dy, cx, 3 + dy, hair)
            px(im, cx, 2 + dy, hair)
            px(im, cx + 1, 1 + dy, hair)


def _profile(im, p, dy, step, seated, pose):
    """Facing LEFT. The right-facing row is this, mirrored."""
    skin, skin_d = p["skin_c"], p["skin_d"]
    hair, hair_d, hair_l = p["hair"], p["hair_d"], p["hair_l"]
    shirt, shirt_d, shirt_l = p["shirt"], p["shirt_d"], p["shirt_l"]
    legs, legs_d, shoe, shoe_l = p["legs"], p["legs_d"], p["shoe"], p["shoe_l"]
    st = p["hair_style"]
    pat = p["pattern"]

    # legs
    if seated:
        rect(im, 8, 42, 19, 45, legs)          # thigh forward
        rect(im, 6, 44, 9, 47, legs)           # shin
        rect(im, 4, 46, 9, 47, shoe)
        rect(im, 16, 44, 19, 47, legs_d)       # the chair-side shadow
    elif pose == POSE_JUMP:
        rect(im, 10, 36, 19, 40, legs)
        rect(im, 8, 41, 19, 43, shoe)
    else:
        # Symmetrical stride:
        # step == 0: neutral standing, both legs side by side
        # step == 1: near leg strides forward (x: 7..11), far leg back (x: 16..20)
        # step == -1: near leg strides back (x: 16..20), far leg strides forward (x: 7..11)
        if step == 0:
            rect(im, 14, 40, 18, 45, legs_d)
            rect(im, 14, 45, 18, 47, shoe)
            rect(im, 9, 40, 13, 45, legs)
            rect(im, 13, 40, 13, 45, legs_d)
            rect(im, 8, 45, 13, 47, shoe)
            px(im, 9, 45, shoe_l)
        elif step == 1:
            # Near leg forward (lifted), Far leg back
            rect(im, 16, 40, 20, 45, legs_d)
            rect(im, 15, 45, 20, 47, shoe)
            rect(im, 7, 38, 11, 43, legs)
            rect(im, 11, 38, 11, 43, legs_d)
            rect(im, 5, 43, 11, 45, shoe)
            px(im, 6, 43, shoe_l)
        else:
            # Near leg back, Far leg forward (lifted)
            rect(im, 7, 38, 11, 43, legs_d)
            rect(im, 5, 43, 11, 45, shoe)
            rect(im, 16, 40, 20, 45, legs)
            rect(im, 20, 40, 20, 45, legs_d)
            rect(im, 15, 45, 20, 47, shoe)
            px(im, 16, 45, shoe_l)

    # hair that hangs behind the shoulder goes under the torso
    if st == "long":
        rrect(im, 19, 10 + dy, 27, 36 + dy, hair, r_top=0, r_bottom=3)
        rect(im, 20, 35 + dy, 27, 36 + dy, hair_d)
    elif st == "ponytail":
        rrect(im, 25, 11 + dy, 30, 32 + dy, hair, r_top=2, r_bottom=2)
        rect(im, 26, 13 + dy, 29, 14 + dy, HAIR_BAND)

    # torso, narrower from the side
    rrect(im, 10, TY0 + dy, 21, TY1 + dy, shirt, r_top=1, r_bottom=0)
    rect(im, 10, TY1 - 1 + dy, 21, TY1 + dy, shirt_d)
    y0 = TY0 + dy
    if pat == "stripes":
        for y in (y0 + 3, y0 + 4, y0 + 7, y0 + 8):
            refill(im, 0, y, CW - 1, y, shirt, shirt_l)
    elif pat == "dungarees":
        rect(im, 11, y0 + 3, 20, y0 + 9, legs)
        rect(im, 12, y0, 13, y0 + 3, legs)
        px(im, 12, y0 + 3, HAIR_BAND)
    elif pat == "collar":
        rect(im, 11, y0, 16, y0 + 1, p["inner"])
    elif pat == "tie":
        rect(im, 11, y0, 15, y0, p["inner"])
        rect(im, 12, y0 + 1, 13, y0 + 7, p["tie"])
    elif pat == "cardigan":
        rect(im, 10, y0, 11, y0 + 9, shirt_d)
        rect(im, 12, y0, 13, y0 + 5, p["inner"])
    elif pat == "lanyard":
        rect(im, 13, y0, 13, y0 + 5, LANYARD)
        rect(im, 12, y0 + 6, 14, y0 + 8, BADGE)
    if p["skirt"] and not seated and pose != POSE_JUMP:
        rect(im, 10, 38 + dy, 21, 38 + dy, shirt)
        rect(im, 9, 39 + dy, 22, 40 + dy, shirt)
        rect(im, 8, 41 + dy, 23, 41 + dy, shirt_d)

    # the near arm, over the torso
    def arm(x0, y0, length):
        sleeve = length if p["sleeves"] == "long" else max(2, length // 2)
        rect(im, x0, y0, x0 + 3, y0 + sleeve - 1, shirt)
        if sleeve < length:
            rect(im, x0, y0 + sleeve, x0 + 3, y0 + length - 1, skin)
        rect(im, x0, y0 + length, x0 + 3, y0 + length + 1, skin)

    if pose == POSE_HANDOFF:
        rect(im, 4, 33 + dy, 14, 35 + dy, shirt)
        rect(im, 1, 33 + dy, 3, 35 + dy, skin)
    elif pose == POSE_SAD:
        arm(12, 32 + dy, 9)
    elif pose == POSE_JUMP:
        rect(im, 12, 19 + dy, 14, 30 + dy, shirt)
        rect(im, 12, 16 + dy, 14, 18 + dy, skin)
    elif seated:
        rect(im, 12, 35 + dy, 15, 39 + dy, shirt)
        rect(im, 8, 40 + dy, 12, 41 + dy, skin)
    elif pose != POSE_CHAT:
        arm(12 - step * 2, 31 + dy, 6)

    # head
    rrect(im, HX0, HY0 + dy, HX1, HY1 + dy, skin, r=3)
    rect(im, 6, 28 + dy, 25, 29 + dy, skin_d)
    # hair: cap, plus the back of the head
    if st == "buzz":
        rrect(im, HX0, HY0 + dy, HX1, 9 + dy, hair, r_top=3, r_bottom=0)
        rect(im, 18, 10 + dy, HX1, 21 + dy, hair)
        rect(im, 5, 9 + dy, 17, 9 + dy, hair_d)
        rect(im, 18, 21 + dy, HX1 - 1, 21 + dy, hair_d)
    else:
        rrect(im, HX0, HY0 + dy, HX1, 11 + dy, hair, r_top=3, r_bottom=0)
        back_bottom = {"bob": 27, "long": 29}.get(st, 24)
        rrect(im, 16, 12 + dy, HX1, back_bottom + dy, hair, r_top=0, r_bottom=2)
        rect(im, 17, back_bottom + dy, HX1 - 1, back_bottom + dy, hair_d)
        rect(im, 4, 11 + dy, 15, 11 + dy, hair_d)
        rect(im, 4, 12 + dy, 8, 12 + dy, hair)          # the front lock
        px(im, 4, 13 + dy, hair)
        px(im, 5, 13 + dy, hair)
        if st == "bob":
            rect(im, 4, 12 + dy, 6, 24 + dy, hair)
            rect(im, 4, 24 + dy, 6, 24 + dy, hair_d)
        elif st == "long":
            rect(im, 4, 12 + dy, 5, 20 + dy, hair)
    rect(im, 8, 5 + dy, 15, 6 + dy, hair_l)
    if st == "bun":
        rrect(im, 21, 0 + dy, 28, 6 + dy, hair, r=2)
        rect(im, 22, 6 + dy, 27, 6 + dy, hair_d)
    elif st == "curly":
        for x, y in ((28, 7), (28, 8), (28, 12), (28, 13), (28, 18), (28, 19),
                     (6, 3), (7, 3), (12, 3), (13, 3), (18, 3), (19, 3),
                     (24, 3), (25, 3), (3, 8), (3, 9)):
            px(im, x, y + dy, hair)
        for x, y in ((20, 9), (24, 14), (19, 19), (23, 22), (10, 7)):
            px(im, x, y + dy, hair_d)
    elif st == "spiky":
        for cx in (8, 13, 18, 23):
            rect(im, cx - 1, 3 + dy, cx, 3 + dy, hair)
            px(im, cx, 2 + dy, hair)
            px(im, cx + 1, 1 + dy, hair)
    # ear, over the hair
    rect(im, 17, 17 + dy, 19, 21 + dy, skin)
    px(im, 18, 19 + dy, skin_d)
    # face / eye: looking left
    eyes = p["eyes"]
    eyes_l = p.get("eyes_l", lighter(eyes, 0.35))
    rect(im, 7, 16 + dy, 10, 19 + dy, SCLERA)
    rect(im, 6, 15 + dy, 10, 15 + dy, LASH)
    rect(im, 7, 16 + dy, 8, 17 + dy, PUPIL)
    rect(im, 7, 18 + dy, 8, 19 + dy, eyes)
    px(im, 8, 19 + dy, eyes_l)
    px(im, 7, 16 + dy, (255, 255, 255))
    if pose == POSE_SAD:
        px(im, 7, 14 + dy, hair_d)
        px(im, 8, 13 + dy, hair_d)
        px(im, 9, 13 + dy, hair_d)
    else:
        rect(im, 7, 13 + dy, 9, 13 + dy, hair_d)
    px(im, 3, 21 + dy, skin)                   # the nose, proud of the face
    px(im, 3, 22 + dy, skin_d)
    if pose == POSE_SAD:
        rect(im, 5, 24 + dy, 6, 25 + dy, MOUTH)
        px(im, 7, 21 + dy, TEAR)
        px(im, 7, 22 + dy, TEAR)
    elif pose == POSE_CHAT:
        rect(im, 4, 24 + dy, 7, 26 + dy, MOUTH_OPEN)
        rect(im, 5, 26 + dy, 6, 26 + dy, TONGUE)
    elif pose == POSE_JUMP:
        px(im, 9, 23 + dy, MOUTH)
        rect(im, 4, 24 + dy, 8, 25 + dy, MOUTH_OPEN)
        rect(im, 5, 24 + dy, 7, 24 + dy, TEETH)
    else:
        rect(im, 5, 25 + dy, 7, 25 + dy, MOUTH)
        px(im, 8, 24 + dy, MOUTH)
    blend_rect(im, 9, 21 + dy, 11, 22 + dy, BLUSH)
    if p["glasses"]:
        blend_rect(im, 6, 15 + dy, 9, 19 + dy, LENS)
        ring(im, 5, 14 + dy, 10, 20 + dy, GLASS_FRAME, r=1)
        rect(im, 10, 15 + dy, 17, 15 + dy, GLASS_FRAME)
    if pose == POSE_CHAT:
        rect(im, 10, 26 + dy, 12, 33 + dy, shirt)
        rect(im, 9, 23 + dy, 12, 25 + dy, skin)


def draw_char(direction, frame, pal):
    """One 32x48 frame, CHIBI proportions: the head is most of the sprite.

    `direction` 0=down 1=left 2=right 3=up.
    `frame` 0-3 is the walk cycle; frame 4 (SIT_FRAME) is the seated pose;
    5-8 are the one-shot POSE_* frames.

    The seated pose is drawn LOWERED INSIDE the same cell rather than
    compensated for with a node offset in the engine. That keeps one rule
    true of every character sprite -- the bottom of the cell is where this
    person meets the floor -- which is the rule the whole game positions
    and depth-sorts by.

    *(Sept 2026, the art overhaul.)* Built at the full 32x48 -- eyes with
    a highlight, brows, a mouth that changes with the pose, cheeks, a nose
    on the profile, a real hair silhouette per style, a pattern on the
    clothes -- with one shading rule (rim_light: lit upper-left, shaded
    lower-right) applied to every frame so all four facings agree about
    where the window is. Still one routine, many palettes.

    *(Sept 2026, the pixel-grid pass.)* The frame is BUILT at 32x48 for
    that detail, then quantised back onto the room's own grid before it is
    returned: the whole set -- every tile, desk and shelf -- is authored
    at 16 px per tile and Scale2x'd to 32, so a character drawn straight
    at 32x48 had pixels half the size of the desk beside it. Each frame is
    now resized to 16x24 and Scale2x'd the same way the furniture is. The
    face that the 32x48 build buys survives only in the 96x96 portrait
    bust, which is UI and off this grid.
    """
    p = resolve_palette(pal)
    im = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    seated = (frame == SIT_FRAME)
    pose = frame if frame >= POSE_HANDOFF else None
    step = 1 if frame == 1 else (-1 if frame == 3 else 0)
    if seated:
        dy = 4
    elif pose == POSE_JUMP:
        dy = -4
    elif pose == POSE_SAD:
        dy = 2
    else:
        dy = 0                           # head stays steady during walk cycle to avoid parity distortion
    if direction == 0:
        _front(im, p, dy, step, seated, pose)
    elif direction == 3:
        _back(im, p, dy, step, seated, pose)
    else:
        _profile(im, p, dy, step, seated, pose)
        if direction == 2:
            im = ImageOps.mirror(im)
    rim_light(im)
    # Quantise onto the room's 16-px-per-tile grid FIRST, then outline
    # and shadow directly at lowres before Scale2x. This guarantees a
    # 100% uniform, solid 2px outline (1 texel) with zero dropped border
    # pixels on walking frames or pose bobs.
    lowres = im.resize((CW // 2, CH // 2), Image.NEAREST)
    # A second, softer shading ring at the lowres stage (Oct 2026, style
    # reference: limezu's Modern Farm pack) -- applied here rather than
    # on the hi-res build above because that's the resolution furniture's
    # finish_rich() shades at, and a hi-res second band mostly vanished
    # under the NEAREST half-resize anyway.
    second_band(lowres, 0.08)
    outline(lowres, LINE)
    shadow(lowres, (CW // 2) // 2, (CH // 2) - 2, 6 if pose != POSE_JUMP else 4, 2)
    return scale2x(lowres)


def make_character(name, pal):
    sheet = Image.new("RGBA", (CW * FRAMES, CH * DIRS), (0, 0, 0, 0))
    for d in range(DIRS):
        for f in range(FRAMES):
            sheet.alpha_composite(draw_char(d, f, pal), (f * CW, d * CH))
    save_png(sheet, name)
    return sheet.size


# --- portraits -------------------------------------------------------
# A 96x96 bust for the HUD's bio and mascot panels. The sheet's 32x48
# frame has to work at desk distance; this one gets to be a face.

PW, PH = 96, 96


def draw_portrait(pal):
    p = resolve_palette(pal)
    im = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    skin, skin_d, skin_l = p["skin_c"], p["skin_d"], p["skin_l"]
    hair, hair_d, hair_l = p["hair"], p["hair_d"], p["hair_l"]
    shirt, shirt_d, shirt_l = p["shirt"], p["shirt_d"], p["shirt_l"]
    st = p["hair_style"]
    pat = p["pattern"]

    # long hair falls behind the shoulders: drawn first
    if st == "long":
        rrect(im, 12, 30, 23, 84, hair, r_top=0, r_bottom=4)
        rrect(im, 72, 30, 83, 84, hair, r_top=0, r_bottom=4)
        rect(im, 13, 81, 22, 84, hair_d)
        rect(im, 73, 81, 82, 84, hair_d)
    elif st == "ponytail":
        rrect(im, 74, 24, 86, 78, hair, r=4)
        rect(im, 75, 36, 85, 38, HAIR_BAND)
        rect(im, 76, 75, 84, 78, hair_d)

    # neck and shoulders
    rect(im, 40, 60, 55, 74, skin_d)
    rrect(im, 8, 72, 87, PH - 1, shirt, r_top=9, r_bottom=0)
    rect(im, 8, 91, 87, PH - 1, shirt_d)
    rect(im, 14, 74, 28, 76, shirt_l)
    if pat == "stripes":
        for y in range(78, PH, 8):
            refill(im, 0, y, PW - 1, y + 2, shirt, shirt_l)
    elif pat == "dungarees":
        rect(im, 30, 80, 65, PH - 1, p["legs"])
        rect(im, 30, 72, 35, 80, p["legs"])
        rect(im, 60, 72, 65, 80, p["legs"])
        rect(im, 31, 80, 32, 81, HAIR_BAND)
        rect(im, 63, 80, 64, 81, HAIR_BAND)
        rect(im, 30, 94, 65, 95, p["legs_d"])
    elif pat == "collar":
        rect(im, 33, 72, 62, 74, p["inner"])
        rect(im, 33, 75, 40, 78, p["inner"])
        rect(im, 55, 75, 62, 78, p["inner"])
        rect(im, 47, 80, 48, 81, LINE)
    elif pat == "tie":
        rect(im, 34, 72, 61, 75, p["inner"])
        rect(im, 44, 72, 51, 76, p["tie"])
        rect(im, 45, 77, 50, PH - 1, p["tie"])
        rect(im, 46, 78, 47, PH - 1, p["tie_l"])
    elif pat == "cardigan":
        for y in range(72, 90):
            w = max(1, int(12 - (y - 72) * 0.65))
            rect(im, 48 - w, y, 47 + w, y, p["inner"])
        rect(im, 33, 72, 35, PH - 1, shirt_d)
        rect(im, 60, 72, 62, PH - 1, shirt_d)
        rect(im, 47, 86, 48, 87, LINE)
        rect(im, 47, 92, 48, 93, LINE)
    elif pat == "lanyard":
        for i in range(17):
            rect(im, 38 + i * 7 // 17, 72 + i, 39 + i * 7 // 17, 72 + i, LANYARD)
            rect(im, 56 - i * 7 // 17, 72 + i, 57 - i * 7 // 17, 72 + i, LANYARD)
        rect(im, 42, 87, 53, PH - 1, BADGE)
        rect(im, 44, 90, 51, 91, BADGE_STRIPE)

    # head
    rrect(im, 18, 6, 77, 69, skin, r=12)
    for y in range(64, 70):
        refill(im, 18, y, 77, y, skin, skin_d)
    rect(im, 26, 20, 32, 34, skin_l)

    # hair
    if st == "bun":
        rrect(im, 35, 0, 60, 12, hair, r=5)
        rect(im, 37, 11, 58, 12, hair_d)
        rect(im, 40, 3, 50, 4, hair_l)
    if st == "buzz":
        rrect(im, 18, 6, 77, 22, hair, r_top=12, r_bottom=0)
        rect(im, 22, 22, 73, 22, hair_d)
    else:
        rrect(im, 18, 6, 77, 27, hair, r_top=12, r_bottom=0)
        rect(im, 19, 27, 76, 27, hair_d)
        if st == "bob":
            rect(im, 18, 28, 77, 29, hair)
            rect(im, 19, 30, 76, 30, hair_d)
            rrect(im, 14, 28, 23, 60, hair, r_top=0, r_bottom=4)
            rrect(im, 72, 28, 81, 60, hair, r_top=0, r_bottom=4)
            rect(im, 15, 58, 22, 60, hair_d)
            rect(im, 73, 58, 80, 60, hair_d)
        else:
            for x0, x1 in ((24, 31), (40, 49), (58, 66)):
                rect(im, x0, 28, x1, 30, hair)
                rect(im, x0 + 1, 31, x1 - 1, 31, hair_d)
            rect(im, 18, 28, 22, 40, hair)
            rect(im, 73, 28, 77, 40, hair)
        if st == "long":
            rect(im, 16, 24, 17, 40, hair)
            rect(im, 78, 24, 79, 40, hair)
        elif st == "curly":
            for cx, cy in ((16, 20), (16, 34), (16, 48), (79, 20), (79, 34),
                           (79, 48), (24, 4), (40, 1), (56, 1), (72, 4)):
                rrect(im, cx - 4, cy - 4, cx + 3, cy + 3, hair, r=3)
            for x, y in ((28, 14), (44, 10), (60, 16), (34, 22), (52, 24),
                         (68, 22), (20, 30), (76, 30)):
                rrect(im, x, y, x + 3, y + 3, hair_d, r=1)
        elif st == "spiky":
            for cx in (28, 42, 56, 70):
                for hgt in range(8):
                    half = (7 - hgt) // 2
                    rect(im, cx - half, 6 - hgt, cx + half, 6 - hgt, hair)
    rect(im, 28, 10, 48, 13, hair_l)

    # Expressive Pokemon style portrait eyes:
    eyes = p["eyes"]
    eyes_l = p.get("eyes_l", lighter(eyes, 0.35))
    eyes_d = p.get("eyes_d", darker(eyes, 0.25))

    # brows
    rect(im, 29, 30, 40, 31, hair_d)
    rect(im, 55, 30, 66, 31, hair_d)

    for ex in (29, 56):
        # White sclera
        rrect(im, ex, 34, ex + 10, 46, SCLERA, r=3)
        # Upper lash line (bold anime curve, 2px thick at top)
        rect(im, ex - 1, 33, ex + 11, 34, LASH)
        px(im, ex - 2 if ex == 29 else ex + 12, 34, LASH)
        # Lower subtle lash rim
        rect(im, ex + 1, 46, ex + 9, 46, (200, 175, 170))
        # Iris (oval)
        rrect(im, ex + 2, 35, ex + 8, 45, eyes_d, r=2)
        # Iris gradient: vibrant lower crescent
        rect(im, ex + 2, 41, ex + 8, 44, eyes)
        rect(im, ex + 3, 43, ex + 7, 44, eyes_l)
        # Pupil (deep black center)
        rect(im, ex + 4, 37, ex + 6, 41, PUPIL)
        # Specular catchlight: 2x2 brilliant white gleam
        rect(im, ex + 2, 36, ex + 3, 37, (255, 255, 255))
        # Micro secondary gleam
        px(im, ex + 7, 43, (255, 255, 255))

    rect(im, 46, 47, 47, 52, skin_d)
    px(im, 48, 52, skin_d)
    for x, y in ((38, 57), (39, 58), (56, 58), (57, 57)):
        px(im, x, y, MOUTH)
    rect(im, 40, 59, 55, 59, MOUTH)
    rect(im, 41, 60, 54, 60, skin_d)
    blend_rect(im, 23, 50, 30, 53, BLUSH)
    blend_rect(im, 65, 50, 72, 53, BLUSH)
    if p["glasses"]:
        blend_rect(im, 27, 32, 42, 48, LENS)
        blend_rect(im, 53, 32, 68, 48, LENS)
        ring(im, 26, 31, 43, 49, GLASS_FRAME, r=3, thickness=2)
        ring(im, 52, 31, 69, 49, GLASS_FRAME, r=3, thickness=2)
        rect(im, 44, 38, 51, 39, GLASS_FRAME)
        rect(im, 17, 37, 25, 38, GLASS_FRAME)
        rect(im, 70, 37, 78, 38, GLASS_FRAME)

    rim_light(im, 0.14)
    second_band(im, 0.07)
    outline(im)
    return im


def make_portrait(name, pal):
    """Write art/portrait_<name>.png -- a 96x96 bust of one palette."""
    im = draw_portrait(pal)
    save_png(im, "portrait_" + name)
    return im.size


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
    return finish(im)


def draw_table():
    im = Image.new("RGBA", (32, 20), (0, 0, 0, 0))
    shadow(im, 16, im.height - 2, 13, 2)
    rect(im, 1, 2, 30, 11, WOOD)         # top
    rect(im, 1, 2, 30, 4, WOOD_L)        # lit near edge of the surface
    rect(im, 1, 11, 30, 12, WOOD_D)      # underside lip
    rect(im, 3, 13, 5, 18, WOOD_D)       # legs
    rect(im, 26, 13, 28, 18, WOOD_D)
    return finish(im)


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
    return finish(im)


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
    return finish(im)


def draw_podium():
    """Front of the room. Starting a lesson happens here."""
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    rect(im, 2, 1, 13, 7, WOOD)           # slanted reading surface
    rect(im, 2, 1, 13, 2, WOOD_L)
    rect(im, 2, 7, 13, 8, WOOD_D)
    rect(im, 5, 9, 10, 17, WOOD)          # column
    rect(im, 5, 9, 6, 17, WOOD_L)
    rect(im, 3, 18, 12, 21, WOOD_D)       # base
    return finish(im)


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
    return finish(im)


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
    return finish(im)


def draw_cabinet_body():
    """The storage cabinet landmark -- a tall wall-standing cupboard the
    class's desks are pulled from in the opening scene. Bigger and plainer
    than the small `cabinet` shop item, so the two do not read as the
    same object."""
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    rect(im, 1, 1, 14, 21, WOOD_D)              # carcass
    rect(im, 2, 2, 13, 20, WOOD)                # front
    rect(im, 1, 1, 14, 2, (170, 124, 78))      # cornice cap, proud of the front
    rect(im, 2, 2, 13, 3, (156, 112, 70))      # top lip
    rect(im, 7, 3, 8, 20, WOOD_D)              # centre stile between doors
    rect(im, 3, 4, 6, 19, (150, 106, 66))      # left door panel
    rect(im, 9, 4, 12, 19, (150, 106, 66))     # right door panel
    # a recessed rectangle on each door, so the front reads as PANELLED
    # rather than one flat plank -- the detail this piece was missing.
    for x0 in (3, 9):
        rect(im, x0 + 1, 6, x0 + 2, 16, WOOD_D)
    px(im, 6, 11, (60, 52, 40)); px(im, 9, 11, (60, 52, 40))   # handles
    rect(im, 0, 20, 15, 21, (90, 62, 38))       # plinth the doors sit on
    return finish(im)


def draw_ad_poster():
    """The optional reward-video poster. E opens it; never forced, never
    pops up on its own -- see scripts/interact/ad_poster.gd."""
    im = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
    rect(im, 1, 1, 14, 17, (224, 220, 206))    # paper
    rect(im, 1, 1, 14, 3, (196, 82, 74))       # header band
    rect(im, 3, 6, 12, 13, (60, 96, 140))      # "screen"
    play = (224, 220, 206)                     # a blocky play triangle
    rect(im, 6, 8, 6, 11, play)
    rect(im, 7, 9, 7, 10, play)
    px(im, 8, 9, play)
    rect(im, 3, 15, 12, 16, WOOD_D)             # post
    return finish(im)


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
    "ad_poster": draw_ad_poster, "cabinet_body": draw_cabinet_body,
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
    return finish(im)


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
    return finish(im)


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
    return finish(im)


def draw_rug():
    im = Image.new("RGBA", (32, 18), (0, 0, 0, 0))
    rect(im, 1, 1, 30, 16, (168, 96, 104))
    rect(im, 3, 3, 28, 14, (196, 128, 132))
    rect(im, 6, 5, 25, 12, (168, 96, 104))
    rect(im, 9, 7, 22, 10, (216, 176, 140))
    return finish(im)


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
    return finish(im)


ITEM_ART = {
    "bookshelf": draw_bookshelf, "lab_bench": draw_lab_bench,
    "art_easel": draw_art_easel, "rug": draw_rug, "plant": draw_plant,
}


# --- cosmetics: hats -------------------------------------------------
# The dashboard has said "Hat: none chosen yet" since it was built -- a
# hook for exactly this, deliberately not built at the time. Worn by
# ANY character (player, inspector, principal, a student), so drawn
# once as a flat icon rather than per-palette: the head is chibi-big
# and round in every direction, and a hat this simple reads fine sat
# on top of it regardless of which way the wearer is facing, which is
# what lets one sprite serve all four walk directions with no redraw.

def draw_hat_cap():
    # A beanie, not a baseball cap -- a brim sticking out to one side
    # read as a disconnected floating block at this size, confirmed by
    # a real render rather than assumed. A dome plus a fold band all the
    # way round is forgiving at any angle, which matters since this one
    # sprite has to sit convincingly on a head facing any direction.
    im = Image.new("RGBA", (24, 20), (0, 0, 0, 0))
    for y, (x0, x1) in enumerate(
            ((10, 13), (8, 15), (6, 17), (5, 18), (4, 19), (3, 20), (2, 21))):
        rect(im, x0, 1 + y, x1, 1 + y, (196, 48, 56))
    rect(im, 2, 8, 21, 12, (168, 40, 48))             # fold band
    rect(im, 6, 2, 15, 3, (216, 72, 80))              # highlight near the top
    rect(im, 10, 0, 13, 1, (236, 200, 108))           # pom-pom
    return outline(im)


def draw_hat_bow():
    im = Image.new("RGBA", (24, 16), (0, 0, 0, 0))
    # Two wings, each a diamond built from rows that widen then narrow
    # outward from the centre knot -- the same taper trick as the cap
    # and the wizard hat, mirrored left and right.
    widths = (1, 4, 8, 11, 8, 4, 1)
    for y, w in enumerate(widths):
        rect(im, 11 - w, 2 + y, 10, 2 + y, (222, 92, 132))          # left wing
        rect(im, 13, 2 + y, 13 + w, 2 + y, (222, 92, 132))          # right wing
    rect(im, 10, 4, 13, 9, (176, 60, 96))            # knot
    return outline(im)


def draw_hat_wizard():
    im = Image.new("RGBA", (24, 22), (0, 0, 0, 0))
    rect(im, 2, 18, 21, 21, (96, 64, 156))          # brim
    for row, (x0, x1) in enumerate(
            ((9, 14), (8, 15), (7, 16), (6, 17), (5, 18), (10, 13))):
        rect(im, x0, 2 + row * 3, x1, 4 + row * 3, (116, 84, 176))
    rect(im, 10, 1, 13, 3, (216, 196, 108))          # star tip
    return outline(im)


def draw_hat_mortarboard():
    """A graduation mortarboard. draw_hat_cap's brim read as a
    disconnected floating block at this scale and was redrawn without
    one -- but the flat board here IS a mortarboard's whole identity, so
    it stays, drawn wide and short (a flattened diamond, the convention
    most chibi/pixel mortarboards use) rather than brim-thin, so it
    reads as a board and not a stray smear. Unlike the other three flat
    hats above, this one gets rim_light -- style reference: the Modern
    Farm pack's shaded layered accessory hats (Oct 2026)."""
    im = Image.new("RGBA", (24, 22), (0, 0, 0, 0))
    # A deliberately big value gap between the two forms -- an early
    # pass used two close charcoal tones and the whole hat read as one
    # muddy blob, board and cap indistinguishable from each other.
    CAP = (104, 98, 128)
    CAP_D = (76, 72, 98)
    BOARD = (20, 18, 26)
    CORD = (222, 182, 72)
    TUFT = (238, 204, 104)
    # the flat board -- a wide, short diamond (a lens seen edge-on), near-
    # black against the cap's lighter slate so the silhouette splits into
    # two readable forms rather than one blob
    rect(im, 11, 2, 12, 2, BOARD)
    rect(im, 5, 3, 18, 3, BOARD)
    rect(im, 0, 4, 23, 4, BOARD)
    rect(im, 5, 5, 18, 5, BOARD)
    rect(im, 11, 6, 12, 6, BOARD)
    # the base skull-cap, same taper trick as draw_hat_cap/draw_hat_wizard,
    # narrower than the board and starting the row BELOW the board's own
    # narrow point -- row 6 above and row 7 below share columns 11-13, so
    # the two forms touch with no floating gap between them.
    for y, (x0, x1) in enumerate(((10, 13), (9, 14), (8, 15), (7, 16))):
        rect(im, x0, 7 + y, x1, 7 + y, CAP)
    rect(im, 8, 10, 15, 11, CAP_D)                   # the band, near the head
    # the cord, hanging from the board's right corner past the cap's
    # edge, with a small tuft where it ends
    px(im, 16, 3, CORD)
    px(im, 17, 4, CORD)
    px(im, 18, 5, CORD)
    px(im, 18, 6, CORD)
    rect(im, 17, 7, 19, 8, TUFT)
    rim_light(im, 0.16)
    return outline(im)


HAT_ART = {
    "cap": draw_hat_cap, "bow": draw_hat_bow, "wizard": draw_hat_wizard,
    "mortarboard": draw_hat_mortarboard,
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

    # a painted surface takes a fleck, not a mortar grid -- plaster is not
    # laid in courses the way brick is. `row` still seeds it, so a 2-tile
    # wall doesn't repeat one speckle exactly.
    rnd = random.Random(9001 + row * 733)
    for _ in range(11):
        x, y = rnd.randrange(TILE), rnd.randrange(TILE)
        px(t, x, y, WALL_L if rnd.random() < 0.5 else WALL_D)

    if cap:
        rect(t, 0, 0, TILE - 1, 1, WALL_TOP)

    if is_bottom_row:
        # This tile IS the near wall's whole visible height -- one course,
        # not a strip at the foot of a taller plastered wall -- so the
        # dado fills it, rather than sharing the tile with plaster above.
        rect(t, 0, 0, TILE - 1, TILE - 1, DADO)
        rect(t, 0, 0, TILE - 1, 1, RAIL)               # the chair rail
        rect(t, 0, 1, TILE - 1, 1, DADO_D)              # its shaded underside
        rect(t, 0, 2, TILE - 1, 2, DADO_L)              # panelling's lit top edge
        for x in range(1, TILE, 4):
            rect(t, x, 3, x, TILE - 4, DADO_D)          # panel grooves
        rect(t, 0, TILE - 3, TILE - 1, TILE - 1, WALL_BASE)      # skirting board
        rect(t, 0, TILE - 3, TILE - 1, TILE - 3, (98, 68, 42))   # its lit top edge
    return t


def window_tile(left_half, top_half):
    """One quarter of a 2x2-tile window: a bevelled frame, panes split by a
    glazing bar, a dusk sky gradient with a reflection streak, a curtain
    drawn back to the outer edge, and -- on the lower half -- a moulded
    sill carried on a corbel."""
    t = Image.new("RGBA", (TILE, TILE))
    rect(t, 0, 0, TILE - 1, TILE - 1, WALL)
    x0 = 2 if left_half else 0
    x1 = TILE - 1 if left_half else TILE - 3
    y0 = 3 if top_half else 0
    y1 = TILE - 1 if top_half else TILE - 4

    # frame, bevelled: lit on the top and left faces, shaded on the others
    rect(t, x0, y0, x1, y1, FRAME)
    rect(t, x0, y0, x1, y0, FRAME_L)
    rect(t, x0, y0, x0, y1, FRAME_L)
    rect(t, x0, y1, x1, y1, FRAME_D)
    rect(t, x1, y0, x1, y1, FRAME_D)

    gx0, gy0 = x0 + 2, y0 + 2
    gx1 = x1 if left_half else x1 - 2
    gy1 = y1 if top_half else y1 - 2

    # glass: a dusk gradient. Cool blue-violet near the ceiling (top_half),
    # warming through a shared horizon band, to a low warm glow at the
    # sill (bottom_half) -- "warm window light" rather than flat daytime
    # blue, and each half fades TOWARD the other so the two stacked tiles
    # read as one sky rather than two flat colours stacked on each other.
    if top_half:
        rect(t, gx0, gy0, gx1, gy1, GLASS)
        rect(t, gx0, gy0, gx1, gy0 + 2, GLASS_L)
        rect(t, gx0, gy1 - 2, gx1, gy1, SKY_MID)
    else:
        rect(t, gx0, gy0, gx1, gy1, GLASS_D)
        rect(t, gx0, gy0, gx1, gy0 + 2, SKY_MID)
        rect(t, gx0, gy1 - 2, gx1, gy1, GLASS_D_L)

    # a thin glazing bar across the middle -> two panes in every quarter
    bar = gy0 + (gy1 - gy0) // 2
    rect(t, gx0, bar, gx1, bar, FRAME)
    rect(t, gx0, bar + 1, gx1, bar + 1, FRAME_D)

    # one short diagonal reflection streak, in the upper pane of the quarter
    streak = GLASS_L if top_half else GLASS_D_L
    for i in range(4):
        px(t, gx0 + 2 + i, bar - 2 - i, streak)
        px(t, gx0 + 3 + i, bar - 2 - i, streak)

    # the mullion's shaded inner edge, at the tile seam
    if left_half:
        rect(t, TILE - 1, gy0, TILE - 1, gy1, FRAME_D)
    else:
        rect(t, 0, gy0, 0, gy1, FRAME_D)

    # a curtain, drawn back to the OUTER edge of the whole 2-tile window --
    # only that side, so the pair of tiles reads as one curtain held open
    # on each side rather than one hanging across the middle of the glass.
    if left_half:
        cx0, cx1 = gx0, gx0 + 2
    else:
        cx0, cx1 = gx1 - 2, gx1
    rect(t, cx0, gy0, cx1, gy1, CURTAIN)
    rect(t, cx0, gy0, cx0, gy1, CURTAIN_L if left_half else CURTAIN_D)
    rect(t, cx1, gy0, cx1, gy1, CURTAIN_D if left_half else CURTAIN_L)

    if not top_half:
        rect(t, x0, y1 - 1, x1, y1 - 1, FRAME_L)      # lit nose of the sill
        rect(t, x0, y1, x1, y1, FRAME_D)              # sill body
        rect(t, x0, TILE - 3, x1, TILE - 2, WALL_D)   # shadow it throws
        rect(t, x0, TILE - 1, x1, TILE - 1, WALL_BASE)
        cx = x0 if left_half else x1 - 2              # a corbel under the end
        rect(t, cx, TILE - 3, cx + 2, TILE - 1, FRAME_D)
    return t


def door_tile(top):
    """One tile of the two-tile doorway: a painted classroom door with a
    vision panel, a raised panel mould, and a proper handle."""
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
        # a raised panel mould below the vision panel's frame -- the
        # "proper door" detail a flat-painted plank was missing.
        rect(t, 4, 9, 11, 9, DOOR_PAINT_D)
    else:
        rect(t, 5, 0, 10, 4, GLASS_D)
        rect(t, 4, 5, 11, 5, FRAME)
        rect(t, 4, 8, 11, 8, DOOR_PAINT_D)             # top of the raised panel
        rect(t, 4, 8, 4, TILE - 3, DOOR_PAINT_D)
        rect(t, 11, 8, 11, TILE - 3, DOOR_PAINT_L)
        rect(t, 5, 9, 10, TILE - 4, DOOR_PAINT_L)      # the panel face itself
        # a proper round handle rather than two bare pixels
        rect(t, TILE - 6, 8, TILE - 4, 10, HANDLE_D)
        px(t, TILE - 6, 8, HANDLE)
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
    doubled = scale2x(im)
    save_png(doubled, "shadow")
    return doubled.size


def backdrop_tile():
    """What lies BEYOND the classroom: the schoolyard, out of focus.

    The room used to be exactly the size of the viewport, so nothing was
    ever visible around it and there was nothing to draw. Since the window
    can be any shape (display/window/stretch/aspect is "expand" now, so a
    16:10 or ultrawide monitor shows real space above and below the room)
    something has to be there, and black bars are not something.

    *(Oct 2026, the outside pass.)* Used to be the far corridor wall, dark
    panelling in the room's own palette. Replaced with a dim grassy
    schoolyard -- the user wants the room read as a real building from
    outside it, Sims-style, not a windowless box -- with a soft, low hedge
    line along the top edge standing in for "maybe even trees": full trees
    do NOT fit this mechanism (Godot tiles this one short strip both ways
    via `texture_repeat`, so anything taller than the tile would stack
    into a repeating column, not read as a tree -- see
    docs/ART_STYLE_REFERENCE.md's note on this if that changes later).

    Deliberately LOW CONTRAST and dark, same restraint as the corridor
    version it replaces: out of play, never walked on, never interacted
    with, must never pull the eye off the room.

    Four tiles wide so the hedge silhouette can vary across its width
    before repeating, rather than visibly stamping one identical tile --
    the same reasoning make_room_tiles' floor variants already use.
    """
    W = TILE * 4
    t = Image.new("RGBA", (W, TILE))
    # a dim, desaturated lawn -- not the room's warm plaster family
    # anymore, since this is outside it now, not another room of it
    grass = (42, 54, 36)
    grass_l = (52, 66, 44)
    grass_d = (34, 44, 29)
    hedge = (28, 38, 26)
    hedge_l = (36, 48, 32)
    rect(t, 0, 0, W - 1, TILE - 1, grass)

    # the hedge line: a soft, rounded silhouette along the top edge only
    # (never crosses the tile's own top/bottom border, so it tiles
    # vertically with no seam) -- bump heights vary across the 4-tile
    # width so the repeat doesn't read as one stamped shape
    rnd = random.Random(4711)
    heights = [rnd.randrange(3, 7) for _ in range(W // 2)]
    for i, h in enumerate(heights):
        x0 = i * 2
        for y in range(h):
            shade = hedge_l if y == h - 1 else hedge
            rect(t, x0, y, min(x0 + 1, W - 1), y, shade)

    # seeded fleck across the lawn, same technique the room's own plaster
    # and the old corridor backdrop both used -- a material cue, not a
    # pattern you can count
    for _ in range(28):
        x, y = rnd.randrange(W), rnd.randrange(max(heights) if heights else 0, TILE)
        px(t, x, y, grass_l if rnd.random() < 0.5 else grass_d)
    return t


def make_room_tiles():
    """The room, in pieces, so it can be rebuilt at ANY size at runtime.

    room.png is still written for the opening 20x11 classroom, but a room the
    player can grow cannot be one baked image -- see RoomBuilder.build_floor.
    """
    out = []

    def save(img, name):
        save_png(scale2x(img), name)
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

    # Not part of the room: what shows AROUND it. RoomBuilder.build_backdrop()
    # tiles this behind everything.
    save(backdrop_tile(), "tile_backdrop")
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
    names = set()
    if os.path.isdir(SPRITE_SRC):
        names = {os.path.splitext(f)[0] for f in os.listdir(SPRITE_SRC)
                 if f.endswith(".txt")}
    # A LimeZu sprite (tools/limezu_manifest.json, tools/limezu_cast.json) is
    # owned by its importer the same way a hand source owns its PNG: the
    # procedural drawing stands down so the next run cannot undo the import.
    # Read from the JSON alone, so this works on a machine without the packs.
    try:
        import limezu
        names |= limezu.owned_names()
    except ImportError:
        pass
    return names


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
    "D": ["1111.", "1...1", "1...1", "1...1", "1...1", "1...1", "1111."],
    "U": ["1...1", "1...1", "1...1", "1...1", "1...1", "1...1", ".111."],
    "S": [".1111", "1....", "1....", ".111.", "....1", "....1", "1111."],
    "Y": ["1...1", "1...1", ".1.1.", "..1..", "..1..", "..1..", "..1.."],
    "T": ["11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.."],
}

CHALK = (238, 240, 232)
CHALK_D = (188, 196, 190)
BOARD = (44, 62, 52)
BOARD_L = (56, 76, 64)
# Named TITLE_FRAME_* rather than FRAME_W/FRAME_D: the room section above
# already owns FRAME_D for the window/door trim's shaded edge (line 279),
# a bare, off-white grey -- a second module-level FRAME_D here silently
# replaced it (Python globals are last-assignment-wins), so window_tile()
# and door_tile() were drawing their "shaded frame" with THIS dark wood
# brown every time make_room_tiles() ran, since it executes after both
# assignments regardless of definition order. Distinct names fix it.
TITLE_FRAME_W = (128, 88, 52)
TITLE_FRAME_D = (92, 60, 34)


def draw_logo(scale=6, gap=4):   # doubled Aug 2026, was 3/2
    """The wordmark: filled chalk letters, a dark outline, a soft drop
    shadow, and a small chalk-apple flourish.

    *(Sept 2026, the art overhaul.)* The old version was letters with no
    outline and no shadow, speckled for "chalk grain" -- against the
    board that speckle read as static and the wordmark washed out rather
    than reading as a title. Outline + shadow is the same two-step every
    character and prop in this file already gets (see `finish()`); the
    apple is the one new shape, doodled the way a teacher actually draws
    one on a board -- two overlapping rounded blobs, a stem, one leaf.
    """
    word = "EDUSYSTEM"
    gw, gh = 5, 7
    text_w = len(word) * (gw * scale + gap) - gap
    text_h = gh * scale
    pad = 1                       # margin left for outline() to trace into
    apple_gap, apple_w, apple_h = 10, 24, 28

    base = Image.new("RGBA", (pad * 2 + text_w + apple_gap + apple_w,
                               pad * 2 + max(text_h, apple_h)), (0, 0, 0, 0))
    x0 = pad
    y_text = pad + (base.height - pad * 2 - text_h) // 2
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
                        px(base, x0 + gx * scale + sx, y_text + gy * scale + sy, c)
        x0 += gw * scale + gap

    ax = x0 - gap + apple_gap
    ay = pad + (base.height - pad * 2 - apple_h) // 2
    APPLE, APPLE_L, APPLE_D = (216, 84, 70), (238, 130, 114), (168, 52, 46)
    STEM, LEAF = (120, 84, 48), (110, 168, 100)
    rrect(base, ax, ay + 8, ax + 21, ay + 27, APPLE, r=7)
    rrect(base, ax + 1, ay + 9, ax + 10, ay + 17, APPLE_L, r=4)   # highlight
    rect(base, ax + 9, ay + 22, ax + 15, ay + 27, APPLE_D)        # base shade
    rect(base, ax + 10, ay, ax + 12, ay + 9, STEM)
    rrect(base, ax + 12, ay - 1, ax + 20, ay + 6, LEAF, r=3)

    lettered = outline(base)

    # A soft drop shadow: a solid-colour silhouette of the outlined mark,
    # offset down-right and composited BEHIND it -- not rim_light/finish(),
    # which shades a shape's OWN pixels rather than casting one behind it.
    off = 3
    alpha = lettered.split()[3]
    dark = Image.new("RGBA", lettered.size, (18, 22, 18, 0))
    dark.putalpha(alpha.point(lambda a: 110 if a else 0))
    out = Image.new("RGBA", (lettered.width + off, lettered.height + off),
                     (0, 0, 0, 0))
    out.alpha_composite(dark, (off, off))
    out.alpha_composite(lettered, (0, 0))
    return out


def _silhouette(img, tint=(32, 27, 48), amt=0.72):
    """A copy of `img` with every opaque pixel mixed toward `tint` -- a
    backlit-furniture look for the title screen's window margin, without
    needing the piece's own palette to harmonise with dusk light."""
    out = img.convert("RGBA").copy()
    data = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = data[x, y]
            if a == 0:
                continue
            nr, ng, nb = mix((r, g, b), tint, amt)
            data[x, y] = (nr, ng, nb, a)
    return out


def draw_title_bg():
    """A classroom at dusk: the chalkboard the menu sits on, framed, with a
    chalk tray and some ghost writing left over from the last lesson -- and,
    down the left margin the menu text never reaches, a window with the
    day's last light in it and a row of the game's own desks and chairs in
    silhouette below it.

    *(Sept 2026, the art overhaul.)* The board itself, and the whole strip
    behind `scenes/ui/title.tscn`'s Menu label (x184-632, y68-300), are
    UNCHANGED from before this pass -- that region's whole job is staying
    low-contrast enough for the pale menu text sitting on it, so the new
    scene lives entirely left of x=184, where there is no text to fight.
    """
    W, H = 640, 352   # doubled Aug 2026, was 320x176
    im = Image.new("RGBA", (W, H), BOARD)

    # uneven wiped-over patches, so the board is not flat colour. The
    # speckle loop itself already scales for free -- it ranges over W/H,
    # which just doubled -- only the fixed patch SIZE needed doubling to
    # keep the same texture density rather than twice as many tiny flecks.
    rnd = random.Random(11)
    for _ in range(90):
        cx = rnd.randrange(0, W)
        cy = rnd.randrange(0, H)
        rw = rnd.randrange(20, 92)
        rh = rnd.randrange(6, 20)
        for y in range(cy, min(H, cy + rh)):
            for x in range(cx, min(W, cx + rw)):
                if rnd.random() < 0.35:
                    px(im, x, y, BOARD_L)

    # faint sums in the corner, half rubbed out
    for i, line in enumerate(("7 x 8 =", "12 + 5 =", "3 x 9 =")):
        gy = 264 + i * 20
        gx = 500
        for ch in line:
            if ch != " ":
                for dy in range(8):
                    for dx in range(6):
                        if rnd.random() < 0.30:
                            px(im, gx + dx, gy + dy, CHALK_D)
            gx += 10

    # --- the left-margin classroom scene ---------------------------------
    # Confined to x=12..183: inside the picture frame's left edge (0-11)
    # and stopping before the Menu label's own left edge (x=184), and to
    # y=96..316: below the logo's bounding box and above the bottom frame
    # (y=328) and its chalk tray. A soft warm glow is allowed to bleed a
    # LITTLE past x=184 -- it only ever darkens the board further there, so
    # it cannot hurt the pale menu text's contrast.
    mx0, mx1 = 12, 183
    fx0, fx1 = 30, 158                          # the window frame itself
    fy0, fy1 = 98, 206
    rect(im, fx0 - 3, fy0 - 3, fx1 + 3, fy1 + 3, FRAME)
    rect(im, fx0 - 3, fy0 - 3, fx1 + 3, fy0 - 1, FRAME_L)
    rect(im, fx0 - 3, fy1 + 1, fx1 + 3, fy1 + 3, FRAME_D)
    rect(im, fx1 + 1, fy0 - 3, fx1 + 3, fy1 + 3, FRAME_D)

    gy_mid = fy0 + (fy1 - fy0) // 2
    rect(im, fx0, fy0, fx1, gy_mid - 1, GLASS)          # cool dusk sky
    rect(im, fx0, fy0, fx1, fy0 + 6, GLASS_L)
    rect(im, fx0, gy_mid - 6, fx1, gy_mid - 1, SKY_MID)
    rect(im, fx0, gy_mid, fx1, fy1, GLASS_D)            # warm low glow
    rect(im, fx0, gy_mid, fx1, gy_mid + 5, SKY_MID)
    rect(im, fx0, fy1 - 10, fx1, fy1, GLASS_D_L)
    rect(im, fx0, gy_mid - 1, fx1, gy_mid, FRAME)       # glazing bar
    rect(im, fx0, gy_mid, fx1, gy_mid, FRAME_D)
    fx_mid = fx0 + (fx1 - fx0) // 2
    rect(im, fx_mid - 1, fy0, fx_mid, fy1, FRAME)
    rect(im, fx_mid, fy0, fx_mid, fy1, FRAME_D)
    for i in range(7):                                  # one long reflection
        px(im, fx0 + 14 + i, fy0 + 10 - i, GLASS_L)
        px(im, fx0 + 15 + i, fy0 + 10 - i, GLASS_L)

    # curtains, drawn back to both outer edges of the frame
    rect(im, fx0, fy0, fx0 + 6, fy1, CURTAIN)
    rect(im, fx0, fy0, fx0, fy1, CURTAIN_L)
    rect(im, fx0 + 6, fy0, fx0 + 6, fy1, CURTAIN_D)
    rect(im, fx1 - 6, fy0, fx1, fy1, CURTAIN)
    rect(im, fx1 - 6, fy0, fx1 - 6, fy1, CURTAIN_L)
    rect(im, fx1, fy0, fx1, fy1, CURTAIN_D)

    # the sill, and the wall taking the window's warm light below it
    rect(im, fx0 - 3, fy1 + 4, fx1 + 3, fy1 + 8, FRAME_D)
    rect(im, fx0 - 3, fy1 + 4, fx1 + 3, fy1 + 5, FRAME_L)
    rect(im, mx0, fy1 + 9, mx1, 250, WALL)
    for x, y in ((22, 220), (150, 235), (60, 250), (110, 210), (40, 260)):
        rect(im, x, y, x + 3, y + 2, WALL_L)

    # a wood dado and skirting, matching the room's tile_wall_bottom, so
    # the title screen's floor reads as the SAME classroom the game is set
    # in rather than a generic backdrop
    rect(im, mx0, 250, mx1, 296, DADO)
    rect(im, mx0, 250, mx1, 251, RAIL)
    rect(im, mx0, 296, mx1, 300, WALL_BASE)
    rect(im, mx0, 296, mx1, 297, (98, 68, 42))

    # the floor, warm underfoot in the last of the window light
    for tx, x0 in enumerate(range(mx0, mx1, 24)):
        x1 = min(mx1, x0 + 23)
        shade = FLOOR_A if tx % 2 == 0 else FLOOR_B
        rect(im, x0, 301, x1, 316, shade)
    rect(im, mx0, 301, mx1, 301, FLOOR_GROUT)

    # the game's own desks and chairs, in silhouette against the window --
    # loaded from disk rather than redrawn, so this is never a second,
    # drifting copy of what draw_chair()/draw_desk() (or their hand-edited
    # sources) actually look like.
    for name, y_feet in (("chair", 300), ("desk", 300)):
        path = os.path.join(OUT, "%s.png" % name)
        if not os.path.exists(path):
            continue
        sil = _silhouette(Image.open(path))
        for i, cx in enumerate((58, 130) if name == "chair" else (94, 166)):
            im.alpha_composite(sil, (cx - sil.width // 2, y_feet - sil.height))

    # wooden frame
    rect(im, 0, 0, W - 1, 11, TITLE_FRAME_W)
    rect(im, 0, 0, W - 1, 3, (156, 112, 70))
    rect(im, 0, H - 24, W - 1, H - 1, TITLE_FRAME_W)
    rect(im, 0, H - 24, W - 1, H - 22, (156, 112, 70))
    rect(im, 0, H - 8, W - 1, H - 1, TITLE_FRAME_D)
    rect(im, 0, 0, 11, H - 1, TITLE_FRAME_W)
    rect(im, W - 12, 0, W - 1, H - 1, TITLE_FRAME_W)
    rect(im, 0, 0, 3, H - 1, TITLE_FRAME_D)
    rect(im, W - 4, 0, W - 1, H - 1, TITLE_FRAME_D)

    # chalk tray: a stub of chalk and a board rubber
    rect(im, 48, H - 20, 80, H - 16, CHALK)
    rect(im, 48, H - 20, 80, H - 20, (255, 255, 255))
    rect(im, 108, H - 22, 148, H - 14, (86, 62, 40))
    rect(im, 108, H - 22, 148, H - 20, (120, 92, 62))
    rect(im, 112, H - 16, 144, H - 14, (200, 200, 196))
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
    # A 96x96 bust per character, for a HUD bio/mascot panel that wants a
    # face rather than a desk-distance sprite. Not "examiner" -- that
    # character is owned by a parallel session working in the main repo;
    # generating art for it here would be duplicated (or conflicting) work.
    for name, pal in CHARACTERS.items():
        if name == "examiner":
            continue
        size = make_portrait(name, pal)
        print("art/%-18s %3dx%-3d (a HUD/bio bust)"
              % ("portrait_" + name + ".png", size[0], size[1]))
    # FURNITURE/ITEM_ART are still drawn at the ORIGINAL small resolution
    # internally -- scale2x doubles them here, adding real diagonal-edge
    # detail rather than a blur. TITLE_ART is excluded: draw_title_bg() and
    # draw_logo() were rewritten to draw at the new resolution directly
    # (see their own Aug 2026 notes), so scaling them again would be wrong.
    for name, fn in (list(FURNITURE.items()) + list(ITEM_ART.items())):
        img = scale2x(fn())
        if save_png(img, name):
            print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    # Moved ahead of TITLE_ART (Sept 2026): draw_title_bg() pastes the
    # game's own desk/chair art into its left-margin scene, reading them
    # straight off disk -- and desk/chair are hand-edited, so the PNG a
    # fresh checkout has is only ever written by make_grid_sprites(), not
    # by the FURNITURE loop just above (which stands down for them). Title
    # art drawn before this call would silently skip them on a clean run.
    make_grid_sprites()
    for name, fn in TITLE_ART.items():
        img = fn()
        if save_png(img, name):
            print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    # Hats are worn on a character, so they follow the character grid --
    # which, since the pixel-grid pass, is the same 16-per-tile / Scale2x
    # grid as the rest of the room. Built at their full size for the shape,
    # then quantised and Scale2x'd back, same as draw_char does per frame.
    for name, fn in HAT_ART.items():
        raw = fn()
        img = scale2x(raw.resize((raw.width // 2, raw.height // 2), Image.NEAREST))
        if save_png(img, name):
            print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    # The furniture lives in its own file because the catalogue outgrew this
    # one. It was never actually called from here despite the docstring
    # saying so, which meant this script rebuilt the characters and left
    # every purchasable item untouched.
    import make_items
    make_items.make_all(_HAND)
    # Screen furniture -- the book the curriculum and the lesson plans are
    # read out of. Same reason make_items is its own file: it is neither a
    # character, a tile, nor something you can buy.
    import make_ui
    make_ui.make_all()
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
            if os.path.exists(os.path.join(SPRITE_SRC, f + ".txt")):
                print("      %-20s <- tools/sprites/%s.txt" % (f, f))
            else:
                print("      %-20s <- LimeZu (tools/limezu_manifest.json / limezu_cast.json)" % f)

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
