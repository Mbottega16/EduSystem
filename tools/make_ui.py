#!/usr/bin/env python3
"""Draw the book the curriculum and the lesson plans are read out of.

    python tools/make_ui.py        (make_art.py calls this too)

Screen furniture, not room furniture -- which is why it is neither in
make_art.py (characters, tiles, the room) nor make_items.py (things you
buy and place). Same principle as both: generated in standard-library
Python plus PIL, so a colour or a curve is retuned by changing a number
here, never by sourcing an asset.

Drawn at HALF size and scale2x'd, exactly like every sprite in this
project, so the book has the same pixel density as the room behind it.
A book drawn at full resolution would be the one crisp object on a
screen full of chunky pixels, and would read as pasted on.

The spread is 288x133 before doubling -> 576x266 on screen, sitting under
the Overlay's own title and above its hint bar.

SHAPE, Sept 2026: the boards and the paper are RECTANGLES. The first
version sagged the page edges away from the spine on a curve and knocked
the cover's corners off, on the theory that two rectangles would not read
as a book. On screen at this size the curve mostly read as a wobble, and
the squared-off spread sits under the HUD's own square panels far better.
What sells it as a book now is TEXTURE, not silhouette -- paper grain,
laid lines, a stack of leaf edges down each outer edge, and a woven
cover -- all of it position-hashed rather than random, so the book is
byte-identical every time this runs (the same rule the room floor's
speckle already follows in make_art.py).
"""
import os

from PIL import Image

from make_art import scale2x, save_png, outline

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

W, H = 288, 133
SPINE = W // 2

# Warm paper, aged a little towards the edges, and the same ink the rest
# of the UI outlines with.
import json
pal_path = os.path.join(os.path.dirname(__file__), 'data', 'palette.json')
try:
    with open(pal_path, 'r') as f:
        _pal = json.load(f)
    PAGE = tuple(_pal.get('UI_PAGE', (236, 226, 200)))
    PAGE_SHADE = tuple(_pal.get('UI_PAGE_SHADE', (214, 202, 173)))
    PAGE_EDGE = tuple(_pal.get('UI_PAGE_EDGE', (196, 182, 152)))
    GUTTER = tuple(_pal.get('UI_GUTTER', (150, 136, 110)))
    COVER = tuple(_pal.get('UI_COVER', (108, 60, 52)))
    COVER_L = tuple(_pal.get('UI_COVER_L', (140, 82, 70)))
    INK = tuple(_pal.get('UI_INK', (46, 42, 54)))
except:
    PAGE = (236, 226, 200)
    PAGE_SHADE = (214, 202, 173)
    PAGE_EDGE = (196, 182, 152)
    GUTTER = (150, 136, 110)
    COVER = (108, 60, 52)
    COVER_L = (140, 82, 70)
    INK = (46, 42, 54)


def _rect(im, x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(H, y1 + 1)):
        for x in range(max(0, x0), min(W, x1 + 1)):
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))


MARGIN = 9          # how much cover shows outside the paper, all round
LEAVES = 5          # how many page edges show in the stack down each side


def _shift(c, d):
    """One colour, nudged by `d` steps and clamped. The texture passes all
    work in these small deltas rather than in new palette entries, so a
    retint through the forge (UI_PAGE=#hex) carries the grain with it."""
    return tuple(max(0, min(255, v + d)) for v in c[:3])


def _hash(x, y, salt=0):
    """A stable 0..255 from a pixel position.

    Position-hashed, not random: this file is re-run whenever a colour is
    retuned, and a book whose grain reshuffled every time would show up as
    a diff in every art commit. Same reason the room floor picks its
    speckle variant from (tx, ty) in make_art.py rather than from rng.
    """
    n = (x * 7919 + y * 104729 + salt * 1299721) & 0x7FFFFFFF
    n ^= n >> 13
    n = (n * 1274126177) & 0x7FFFFFFF
    return (n >> 11) & 0xFF


def _page_top(x):
    """How far down the paper starts at column `x` -- now a constant.

    Kept as a function, and still called everywhere, because page_flip()
    and the leaf stack both ask the same question and a future edge
    treatment may want the column back.
    """
    return MARGIN


def _page_bottom(x):
    return H - 1 - MARGIN


def _paper_grain(im, x, y):
    """Fibre, laid lines and a little ageing, over whatever is already
    at (x, y). Applied only to paper pixels, and only in small steps --
    the right-hand page carries body text at 16px over the top of it,
    so anything stronger than this competes with the words."""
    r, g, b, a = im.getpixel((x, y))
    if not a:
        return
    d = 0
    h = _hash(x, y)
    if h < 34:                       # fibre fleck, lighter
        d += 5
    elif h < 68:                     # fibre fleck, darker
        d -= 5
    if y % 5 == 0:                   # laid lines, the faintest of ribs
        d -= 3
    if _hash(x, y, 7) < 10:          # the odd speck of pulp
        d -= 9
    # aged towards the outer edges: paper handled at the corner darkens
    near = min(x - MARGIN, W - 1 - MARGIN - x, y - MARGIN, H - 1 - MARGIN - y)
    if near < 6:
        d -= (6 - near)
    if d:
        im.putpixel((x, y), _shift((r, g, b), d) + (a,))


def _cover_weave(im, x, y):
    """Bookcloth. A 2px over-under weave plus a slub every so often, so
    the boards read as covered board rather than as a flat maroon slab."""
    r, g, b, a = im.getpixel((x, y))
    if not a:
        return
    d = 3 if ((x >> 1) + (y >> 1)) % 2 == 0 else -3
    if _hash(x, y, 3) < 18:
        d -= 6
    im.putpixel((x, y), _shift((r, g, b), d) + (a,))


# Cover cloth for the other two books: the furniture catalogue is BLUE, the
# curriculum GREEN. Same weave, same boards, same cream paper -- only the
# cloth changes, so they read as the same family as the red lesson book.
BLUE_COVER = ((44, 72, 124), (70, 106, 168))
GREEN_COVER = ((52, 96, 62), (78, 132, 88))


def book_open(cover=None):
    """The spread. `cover` is (COVER, COVER_L) for a variant, or None for the
    house red. The helpers read the module-level COVER, so it is swapped for
    the duration of the draw and put back."""
    global COVER, COVER_L
    saved = (COVER, COVER_L)
    if cover is not None:
        COVER, COVER_L = cover
    try:
        return _book_open()
    finally:
        COVER, COVER_L = saved


def _book_open():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # ---------------------------------------------------------- the boards
    # A straight slab. One light source upper-left, per docs/PIXEL_STYLE.md:
    # the top and left edges lift a step, the bottom and right drop one.
    _rect(im, 0, 2, W - 1, H - 3, COVER)
    for y in range(2, H - 2):
        for x in range(W):
            _cover_weave(im, x, y)
    _rect(im, 0, 2, W - 1, 3, COVER_L)              # lit top edge
    _rect(im, 0, 4, 1, H - 3, COVER_L)              # lit left edge
    _rect(im, W - 2, 4, W - 1, H - 3, _shift(COVER, -14))
    _rect(im, 0, H - 4, W - 1, H - 3, _shift(COVER, -14))

    # Corner pieces, the way a half-bound book is reinforced. Square, big
    # enough to read at this size, and edged on the inner two sides so the
    # patch has a border rather than dissolving into the cloth behind it.
    cw, ch = 15, 13
    for cx, cy in ((0, 2), (W - cw, 2), (0, H - 2 - ch), (W - cw, H - 2 - ch)):
        _rect(im, cx, cy, cx + cw - 1, cy + ch - 1, COVER_L)
        for y in range(cy, cy + ch):
            for x in range(cx, cx + cw):
                _cover_weave(im, x, y)
        inner_x = cx + cw - 1 if cx == 0 else cx
        inner_y = cy + ch - 1 if cy < H // 2 else cy
        _rect(im, inner_x, cy, inner_x, cy + ch - 1, _shift(COVER, -24))
        _rect(im, cx, inner_y, cx + cw - 1, inner_y, _shift(COVER, -24))

    # The spine: a darker band with two raised bands across it.
    _rect(im, SPINE - 7, 2, SPINE + 6, H - 3, _shift(COVER, -20))
    for by in (H // 3, 2 * H // 3):
        _rect(im, SPINE - 7, by - 2, SPINE + 6, by + 1, COVER)
        _rect(im, SPINE - 7, by - 2, SPINE + 6, by - 2, COVER_L)

    # ----------------------------------------------------------- the paper
    # One rectangle per side, hard-edged, inset from the boards all round.
    top, bot = MARGIN, H - 1 - MARGIN
    _rect(im, MARGIN, top, W - 1 - MARGIN, bot, PAGE)

    # The stack of leaves, seen edge-on down each OUTER edge and along the
    # bottom -- the three sides of an open book where the block shows.
    # Alternating tones, one column per leaf, fading towards the inside so
    # the stack has a near and a far edge instead of reading as a stripe.
    for i in range(LEAVES):
        shade = PAGE_EDGE if i % 2 else PAGE_SHADE
        shade = _shift(shade, i * 3)          # nearer leaves are darker
        _rect(im, MARGIN + i, top + i, MARGIN + i, bot - i, shade)
        _rect(im, W - 1 - MARGIN - i, top + i, W - 1 - MARGIN - i, bot - i, shade)
        _rect(im, MARGIN + i, bot - i, W - 1 - MARGIN - i, bot - i, shade)
    # the outermost leaf and the top sheet's own edge, hard lines both
    _rect(im, MARGIN, top, W - 1 - MARGIN, top, PAGE_SHADE)

    # The gutter: a straight band down the fold, darkest at the centre.
    # No curve -- the shadow does the work the sag used to.
    for dx in range(-6, 7):
        x = SPINE + dx
        a = abs(dx)
        if a <= 1:
            shade = GUTTER
        elif a <= 3:
            shade = _shift(PAGE_SHADE, -10)
        else:
            shade = PAGE_SHADE
        _rect(im, x, top, x, bot, shade)

    # Grain last, so it sits over the paper, the leaves AND the gutter and
    # they all age together instead of the fold looking freshly printed.
    for y in range(top, bot + 1):
        for x in range(MARGIN, W - MARGIN):
            _paper_grain(im, x, y)

    _outline(im)
    return im


def _outline(im):
    """A 1px ink border on every transparent pixel touching the book."""
    src = im.copy()
    for y in range(H):
        for x in range(W):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and src.getpixel((nx, ny))[3]:
                    im.putpixel((x, y), INK + (255,))
                    break


def page_flip(step, steps=4):
    """One frame of a page sweeping right-to-left across the spine.

    Four frames is enough: the eye reads the direction, not the geometry.
    The page is drawn as a narrowing then widening sheet hinged at the
    spine -- narrow when it is edge-on to you, wide when it is flat.

    Clamped to the paper block since the spread went rectangular: the
    sheet is hinged at the spine and half the spread wide, which at the
    ends of the turn used to run it out over the boards and off the
    canvas edge. It carries the same grain as the page it lands on, or
    the turning sheet reads as a different, cleaner piece of paper.
    """
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = (step + 1) / float(steps + 1)          # 0..1 across the turn
    # width of the turning sheet: full at the ends, edge-on in the middle
    reach = int(SPINE * abs(1.0 - 2.0 * t))
    if reach < 2:
        reach = 2
    left = t > 0.5
    x0 = max(MARGIN, SPINE - reach if left else SPINE)
    x1 = min(W - 1 - MARGIN, SPINE if left else SPINE + reach)

    # the free edge lifts off the page a little through the middle of the turn
    lift = int((1.0 - abs(1.0 - 2.0 * t)) * 6)
    top, bot = _page_top(0) - lift, _page_bottom(0) - lift
    for x in range(x0, x1 + 1):
        _rect(im, x, top, x, bot, PAGE)
        # the underside catches less light than the face
        if left:
            _rect(im, x, top, x, top + 2, PAGE_SHADE)
    # the free edge itself, a hard line so the sheet has a leading edge
    _rect(im, x0 if left else x1, top, x0 if left else x1, bot, PAGE_EDGE)
    for y in range(max(0, top), min(H, bot + 1)):
        for x in range(x0, x1 + 1):
            _paper_grain(im, x, y)

    _outline(im)
    return im



# ---------------------------------------------------------------- icons
# One icon per SUBJECT STRAND, not per lesson. There are 40 lessons and four
# strands, and a lesson is already identified by its name on the row -- what
# the icon adds is the thing the name does not say at a glance, which is
# which family it belongs to. Forty pieces of art to say the same four
# things would be forty pieces of art to keep in step.
#
# Drawn at 8x8 and scale2x'd to 16, the size the book's own body text sits
# at. Bigger reads as a picture beside the word rather than a mark on it.
#
# THE COLOURS MUST MATCH hud.gd's STRAND_COLOUR. An icon in a different
# green from its own row is worse than no icon -- it reads as a second,
# unexplained category. A test asserts these four hexes against that table
# rather than trusting this comment.
STRAND_HUE = {
    "math": (0x8a, 0xb4, 0xf8),      # blue
    "ela": (0x9f, 0xd8, 0x9f),       # green
    "science": (0xf2, 0xc6, 0x6b),   # amber
    "social": (0xd0, 0xa3, 0xe8),    # violet
}

# '#' the strand's colour, '-' a step darker for structure inside the shape,
# '.' transparent. No keyline, deliberately: docs/PIXEL_STYLE.md asks for one
# on room art, but eight pixels minus a 1px border on every side leaves a 6x6
# interior, and two rounds of trying proved that is not enough to say "book"
# or "plus" -- the plus came out reading as an arrow. These sit on the book's
# cream page where a saturated colour already has all the contrast it needs,
# so the whole 8x8 goes on the SILHOUETTE, which is the thing that has to
# survive at this size.
#
# Authored as text because an 8x8 glyph is quicker to read and to fix as a
# picture than as a list of rectangles -- the same reason tools/sprites/*.txt
# exists for the room's furniture.
STRAND_GLYPH = {
    # a book, cover-on, with its spine down the left edge. The open-book
    # version (two pages either side of a centre spine) read as a plain
    # square at this size -- the spine has to be OFF centre to say "book".
    "ela": [
        ".######.",
        ".#-####.",
        ".#-####.",
        ".#-####.",
        ".#-####.",
        ".#-####.",
        ".#-####.",
        ".######.",
    ],
    # a plus. The one mark that still means arithmetic at eight pixels.
    "math": [
        "........",
        "...##...",
        "...##...",
        ".######.",
        ".######.",
        "...##...",
        "...##...",
        "........",
    ],
    # a conical flask with something in the bottom of it
    "science": [
        "...##...",
        "...##...",
        "...##...",
        "..####..",
        ".######.",
        ".##--##.",
        ".######.",
        "..####..",
    ],
    # a globe: a disc, an equator, and a meridian held deliberately OFF
    # centre. Centred, the two bands crossed in the middle and the icon read
    # as the maths plus in a different colour -- two subjects sharing a
    # silhouette is worse than neither having an icon.
    "social": [
        "..####..",
        ".#-####.",
        "##-#####",
        "##------",
        "##-#####",
        ".#-####.",
        "..####..",
        "........",
    ],
}


def _step(c, d):
    return tuple(max(0, min(255, v + d)) for v in c[:3])


def _double(im):
    """Plain nearest 2x, NOT scale2x.

    scale2x (AdvMAME2x) is an interpolating upscaler: it turns a staircase
    into a real diagonal, which is what you want for a chibi head and
    exactly what you do not want here. Doubled through it these came out as
    a diamond and a rounded square -- it rounded off the corners that were
    the whole shape. Every organic sprite still goes through scale2x; a
    geometric mark gets its pixels duplicated and keeps its corners.
    """
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def strand_icon(strand):
    """One 8x8 subject mark, in that strand's own colour."""
    hue = STRAND_HUE[strand]
    tones = {"#": hue, "+": _step(hue, 34), "-": _step(hue, -60)}
    rows = STRAND_GLYPH[strand]
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in tones:
                im.putpixel((x, y), tones[ch] + (255,))
    return im


# A small face icon for the room's overall grade band, on the Dashboard
# Overview page next to a new grade-letter line. Style-referenced against
# the Modern UI pack's mood/smiley icon strip (Oct 2026).
#
# NOTE on why this exists at all: the project's own stated rule, in the
# inspection screen's own doc comment, is "three verdicts in words, not
# three numbers... 0.62 is not [something you act on]" -- prose, never a
# visual score, for anything judging a CHILD. A face tied to the room's
# grade sits close to that line. Built anyway on the user's explicit,
# confirmed-after-the-tension-was-raised instruction (same shape as
# Game.auto_teach's own documented exception in the repo's CLAUDE.md --
# a deliberate override, not an oversight).
MOOD_FACE = (240, 200, 90)
MOOD_LINE = (60, 50, 30)


def mood_icon(state):
    """state: 'good' (A/B), 'ok' (C/D), 'struggling' (E/F)."""
    im = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    for y in range(14):
        for x in range(14):
            dx, dy = x - 6.5, y - 6.5
            if dx * dx + dy * dy <= 6.5 * 6.5:
                im.putpixel((x, y), MOOD_FACE + (255,))
    im.putpixel((4, 5), MOOD_LINE + (255,))
    im.putpixel((9, 5), MOOD_LINE + (255,))
    if state == "good":
        for x in (3, 10):
            im.putpixel((x, 8), MOOD_LINE + (255,))
        for x in (4, 9):
            im.putpixel((x, 9), MOOD_LINE + (255,))
        for x in range(5, 9):
            im.putpixel((x, 10), MOOD_LINE + (255,))
    elif state == "struggling":
        for x in (3, 10):
            im.putpixel((x, 10), MOOD_LINE + (255,))
        for x in (4, 9):
            im.putpixel((x, 9), MOOD_LINE + (255,))
        for x in range(5, 9):
            im.putpixel((x, 8), MOOD_LINE + (255,))
    else:
        for x in range(4, 10):
            im.putpixel((x, 9), MOOD_LINE + (255,))
    return outline(im)


def make_all():
    made = []
    save_png(scale2x(book_open()), "book_open")
    made.append("book_open")
    save_png(scale2x(book_open(BLUE_COVER)), "book_open_blue")
    made.append("book_open_blue")
    save_png(scale2x(book_open(GREEN_COVER)), "book_open_green")
    made.append("book_open_green")
    for i in range(4):
        save_png(scale2x(page_flip(i)), "book_flip%d" % i)
        made.append("book_flip%d" % i)
    print("art/book_*.png       %d pieces (the curriculum/plans book, %dx%d)"
          % (len(made), W * 2, H * 2))
    for strand in sorted(STRAND_GLYPH):
        save_png(_double(strand_icon(strand)), "icon_%s" % strand)
        made.append("icon_%s" % strand)
    print("art/icon_*.png       %d subject marks, 16x16" % len(STRAND_GLYPH))
    for state in ("good", "ok", "struggling"):
        save_png(_double(mood_icon(state)), "mood_%s" % state)
        made.append("mood_%s" % state)
    print("art/mood_*.png       3 dashboard mood faces, 28x28")
    return made


if __name__ == "__main__":
    make_all()
