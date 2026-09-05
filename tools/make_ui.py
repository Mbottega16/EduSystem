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
"""
import os

from PIL import Image

from make_art import scale2x, save_png

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art")

W, H = 288, 133
SPINE = W // 2

# Warm paper, aged a little towards the edges, and the same ink the rest
# of the UI outlines with.
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


def _page_top(x):
    """How far down the paper starts at column `x`.

    A real open book sags away from the spine, so the top edge is a
    curve rather than a straight line -- this is most of what stops the
    drawing reading as two rectangles. The dip is deepest at the outer
    edges, where the leaves hang furthest from the binding.
    """
    d = abs(x - SPINE) / float(SPINE)
    return MARGIN + int((d ** 1.5) * 7)


def _page_bottom(x):
    d = abs(x - SPINE) / float(SPINE)
    return H - 1 - MARGIN - int((d ** 1.5) * 7)


def book_open():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # The cover: a slab with its corners knocked off, so the boards read
    # as boards rather than as a rectangle behind the paper.
    for x in range(W):
        d = abs(x - SPINE) / float(SPINE)
        inset = int((d ** 4) * 5)
        _rect(im, x, 2 + inset, x, H - 3 - inset, COVER)
        _rect(im, x, 2 + inset, x, 3 + inset, COVER_L)

    # the paper itself, inset from the boards on every side
    for x in range(MARGIN - 4, W - MARGIN + 4):
        top, bot = _page_top(x), _page_bottom(x)
        _rect(im, x, top, x, bot, PAGE)
        # the leaves under the top sheet, thicker towards the outer edge
        d = abs(x - SPINE) / float(SPINE)
        leaves = int(d * d * 4)
        if leaves:
            _rect(im, x, bot - leaves, x, bot, PAGE_EDGE)
            _rect(im, x, top, x, top + max(0, leaves - 2), PAGE_SHADE)

    # the gutter: paper curving down into the spine, darkest at the fold
    for dx in range(-6, 7):
        x = SPINE + dx
        shade = GUTTER if abs(dx) <= 1 else PAGE_SHADE
        if abs(dx) > 4:
            continue
        _rect(im, x, _page_top(x), x, _page_bottom(x), shade)

    # a hint of shadow along the inner edge of each page, so the paper
    # looks like it lifts away from the fold
    for dx in (5, 6, -5, -6):
        x = SPINE + dx
        for y in range(_page_top(x), _page_bottom(x) + 1):
            r, g, b, a = im.getpixel((x, y))
            im.putpixel((x, y), (int(r * 0.94), int(g * 0.94), int(b * 0.94), a))

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
    """
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = (step + 1) / float(steps + 1)          # 0..1 across the turn
    # width of the turning sheet: full at the ends, edge-on in the middle
    reach = int(SPINE * abs(1.0 - 2.0 * t))
    if reach < 2:
        reach = 2
    left = t > 0.5
    x0 = SPINE - reach if left else SPINE
    x1 = SPINE if left else SPINE + reach

    for x in range(x0, x1 + 1):
        top, bot = _page_top(x), _page_bottom(x)
        # the free edge lifts off the page a little at the top
        lift = int((1.0 - abs(1.0 - 2.0 * t)) * 6)
        _rect(im, x, top - lift, x, bot - lift, PAGE)
        # the underside catches less light than the face
        if left:
            _rect(im, x, top - lift, x, top - lift + 2, PAGE_SHADE)

    _outline(im)
    return im


def make_all():
    made = []
    save_png(scale2x(book_open()), "book_open")
    made.append("book_open")
    for i in range(4):
        save_png(scale2x(page_flip(i)), "book_flip%d" % i)
        made.append("book_flip%d" % i)
    print("art/book_*.png       %d pieces (the curriculum/plans book, %dx%d)"
          % (len(made), W * 2, H * 2))
    return made


if __name__ == "__main__":
    make_all()
