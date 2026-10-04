"""Make any picture look like it came out of a LimeZu pack: his colours, his keyline, his grid.

    python tools/lz_conform.py --build-palette                 (once, needs the packs) -> tools/limezu_palette.json
    python tools/lz_conform.py in.png out.png --grid 16x24     snap to the palette, keyline, fit a 16x24 art-px canvas
    python tools/lz_conform.py in.png out.png --grid 32x16 --x2   ...and double it to the game's scale
    python tools/lz_conform.py in.png out.png --nearest        input is ALREADY pixel art at the right size: only recolour

For the pieces the packs do not have -- the bell, an abacus, a microscope, a state flag --
there are three ways to a LimeZu-looking sprite: compose it from LimeZu parts
(limezu_ui.py shows how), regenerate it with a conformed procedural drawing
(make_art.py), or take ANY picture of the thing (an AI image, a photo, a hand drawing)
and run it through here. What it does, in order:

  1. crop to the drawn part (transparent margins; a flat white/black corner counts as one),
  2. shrink to fit --grid (art pixels; default 16x24) -- BOX filter, so detail averages
     instead of aliasing; --nearest skips this for art that is already at size,
  3. snap every opaque pixel to the nearest colour LimeZu actually used
     (tools/limezu_palette.json, the ~190 most-used fills across the Interiors and
     Office packs; alpha is thresholded -- no soft edges),
  4. add the 1px keyline #3a3a50 round the silhouette, which is LimeZu's single most
     recognisable trait (never black, never warm brown) -- or, if the picture already has a
     dark outline, recolour THAT to the keyline instead of adding a second ring,
  5. optionally x2 with NEAREST: the game's scale.

KNOWN LIMIT: this is built for a picture with no baked contact shadow (an AI image, a photo, a
drawing). The game's OLD procedural sprites carry a translucent shadow row; removing it can leave
a ragged edge, so for those prefer `--no-keyline` (palette snap only) or regenerate them.

It does NOT invent LimeZu's shading -- per-surface light/dark, a visible grain, dark
seams between planks (docs/ART_STYLE_REFERENCE.md, findings 1-5). A conformed AI image
will have the right colours and outline and, if the source was flat, flat shading: treat
the output as a strong first draft to touch up in Browse Art.bat, not a finished sprite.
"""
import json
import os
import sys

from PIL import Image

import limezu

HERE = os.path.dirname(os.path.abspath(__file__))
PALETTE = os.path.join(HERE, "limezu_palette.json")
KEYLINE = (0x3a, 0x3a, 0x50)
OUTLINE_FAMILY = [(0x3a, 0x3a, 0x50), (0x46, 0x46, 0x5e), (0x56, 0x59, 0x72), (0x6c, 0x59, 0x81)]


def build_palette(n=192):
    """Count opaque colours over every 16x16 single of the Interiors + Office packs and the
    premade characters, keep the n most used (plus the keyline family)."""
    counts = {}

    def feed(im):
        px = im.convert("RGBA").getdata()
        for r, g, b, a in px:
            if a == 255:
                counts[(r, g, b)] = counts.get((r, g, b), 0) + 1

    seen = 0
    for key, subs in (("interiors", ("Theme_Sorter_Shadowless_Singles/", "0_Premade_Characters/16x16/")),
                      ("office", ("4_Modern_Office_singles/16x16/",))):
        pack = limezu.find_pack(key)
        if not pack:
            continue
        for name in pack.names():
            if name.lower().endswith(".png") and any(s in name for s in subs):
                feed(pack.image(name))
                seen += 1
    if not seen:
        sys.exit("no packs found -- put the LimeZu zips on the Desktop / in Downloads (see tools/limezu.py)")
    top = sorted(counts, key=lambda c: -counts[c])[:n]
    for c in OUTLINE_FAMILY:
        if c not in top:
            top.append(c)
    with open(PALETTE, "w", encoding="utf-8") as fh:
        json.dump({"_about": "The most-used opaque colours in LimeZu's Modern Interiors/Office singles and premade "
                             "characters, most used first (colours only -- no art). Built by `lz_conform.py --build-palette`.",
                   "colours": ["#%02x%02x%02x" % c for c in top]}, fh, indent=0)
    print("%d colours from %d sprites -> %s" % (len(top), seen, os.path.relpath(PALETTE, os.path.dirname(HERE))))


def load_palette():
    with open(PALETTE, encoding="utf-8") as fh:
        return [limezu.parse_hex(c) for c in json.load(fh)["colours"]]


def crop_to_content(im):
    px = im.load()
    w, h = im.size
    if im.getchannel("A").getextrema()[0] == 255:      # no transparency at all: treat a flat corner colour as ground
        corner = px[0, 0]
        if all(px[x, y] == corner for x, y in ((w - 1, 0), (0, h - 1), (w - 1, h - 1))):
            out = im.copy()
            op = out.load()
            for y in range(h):
                for x in range(w):
                    if op[x, y][:3] == corner[:3]:
                        op[x, y] = (0, 0, 0, 0)
            im = out
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def fit(im, grid, nearest):
    gw, gh = grid
    s = min(gw / float(im.width), gh / float(im.height), 1.0 if nearest else 99.0)
    if nearest and im.width <= gw and im.height <= gh:
        return im
    nw, nh = max(1, int(round(im.width * s))), max(1, int(round(im.height * s)))
    return im.resize((nw, nh), Image.NEAREST if nearest else Image.BOX)


def snap(im, palette):
    """Alpha thresholded; every opaque pixel -> nearest palette colour (RGB distance)."""
    alpha = im.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    flat = Image.new("RGB", im.size, (0, 0, 0))
    flat.paste(im.convert("RGB"), mask=alpha)
    pal = Image.new("P", (1, 1))
    flat_pal = []
    for c in palette[:256]:
        flat_pal.extend(c)
    flat_pal.extend([0] * (768 - len(flat_pal)))
    pal.putpalette(flat_pal)
    q = flat.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    out = q.convert("RGBA")
    out.putalpha(alpha)
    return out


def _lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def edge_pixels(im):
    """Opaque pixels that touch transparency (or the canvas edge), 4-neighbourhood."""
    w, h = im.size
    px = im.load()
    out = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 255:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                    out.append((x, y))
                    break
    return out


def already_outlined(im):
    """True when most of the silhouette's edge is already a dark line -- a second ring on top
    of that would be a 2px border, which LimeZu never draws."""
    edge = edge_pixels(im)
    if not edge:
        return False
    px = im.load()
    dark = sum(1 for x, y in edge if _lum(px[x, y]) < 90)
    return dark / float(len(edge)) >= 0.6


def recolor_outline(im):
    px = im.load()
    for x, y in edge_pixels(im):
        if _lum(px[x, y]) < 90:
            px[x, y] = KEYLINE + (255,)
    return im


def keyline(im):
    """A 1px ring of LimeZu's keyline round the silhouette (the canvas grows by 2) -- but only
    where the edge is NOT already a keyline pixel, so an already-outlined sprite gets no second
    border, while a stretch that lost its outline (a baked shadow removed) gets one back."""
    w, h = im.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.alpha_composite(im, (1, 1))
    src = out.copy().load()
    dst = out.load()
    for y in range(h + 2):
        for x in range(w + 2):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w + 2 and 0 <= ny < h + 2 and src[nx, ny][3] == 255 \
                            and src[nx, ny][:3] != KEYLINE:
                        dst[x, y] = KEYLINE + (255,)
                        break
    return out


def conform(path, grid=(16, 24), nearest=False, line=True):
    im = Image.open(path).convert("RGBA")
    im = crop_to_content(im)
    # A sprite whose edge is already a dark line gets THAT line recoloured to the keyline; the
    # ring then only fills what is still open (see keyline()).
    outlined = line and already_outlined(im)
    inner = (grid[0] - (2 if line else 0), grid[1] - (2 if line else 0))
    im = fit(im, inner, nearest)
    im = snap(im, load_palette())
    if outlined:
        im = recolor_outline(im)
    return keyline(im) if line else im


def main(argv):
    if "--build-palette" in argv:
        build_palette()
        return 0
    paths = [a for a in argv if not a.startswith("--")]
    if len(paths) != 2:
        print(__doc__)
        return 2
    grid = (16, 24)
    if "--grid" in argv:
        gw, gh = argv[argv.index("--grid") + 1].lower().split("x")
        grid = (int(gw), int(gh))
        paths = [p for p in paths if p != argv[argv.index("--grid") + 1]]
    if not os.path.exists(PALETTE):
        sys.exit("tools/limezu_palette.json is missing -- run `python tools/lz_conform.py --build-palette` once (needs the packs)")
    img = conform(paths[0], grid, "--nearest" in argv, "--no-keyline" not in argv)
    if "--x2" in argv:
        img = limezu.up2(img)
    img.save(paths[1])
    print("%s -> %s  %dx%d%s" % (paths[0], paths[1], img.width, img.height, "  (x2)" if "--x2" in argv else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
