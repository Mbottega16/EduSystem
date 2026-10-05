#!/usr/bin/env python3
"""Studio: the one place the Sprite Hub reaches every generator and every
colour / texture / shape control.

Generators are run as subprocesses through their own CLI rather than imported,
so this module never duplicates their logic and never drifts from it. The
transform pipeline is built on the primitives that already exist in
tools/limezu.py and tools/lz_conform.py.
"""

import io
import os
import sys
import json
import colorsys
import subprocess

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.dirname(HERE)
REPO_ROOT = os.path.dirname(TOOLS_DIR)

sys.path.insert(0, TOOLS_DIR)
import limezu
import lz_conform

# key -> how the UI should present it, and what to actually run.
GENERATORS = {
    "chars": {
        "label": "Characters",
        "script": "limezu_chars.py",
        "blurb": "Bake a cast member: body, eyes, outfit, hair, accessory.",
        "writes": "art/<name>.png",
        "examples": ["--list", "--preview", "player"],
    },
    "room": {
        "label": "Room tiles",
        "script": "limezu_room.py",
        "blurb": "Floors, walls, windows and door from the Room Builder.",
        "writes": "art/tile_*.png",
        "examples": ["--preview", "--check"],
    },
    "props": {
        "label": "Props & items",
        "script": "import_limezu.py",
        "blurb": "Build props and tiles listed in limezu_manifest.json.",
        "writes": "art/<name>.png",
        "examples": ["--list", "--check"],
    },
    "ui": {
        "label": "UI pieces",
        "script": "limezu_ui.py",
        "blurb": "The bubble frame and the panel frame.",
        "writes": "art/ui_*.png",
        "examples": ["--check"],
    },
    "catalog": {
        "label": "Contact sheets",
        "script": "limezu_catalog.py",
        "blurb": "Browse a pack as one big PNG contact sheet.",
        "writes": "shots/catalog/*.png",
        "examples": ["themes", "props", "kids", "adults", "portraits", "ui", "room"],
    },
    "conform": {
        "label": "Conform to LimeZu",
        "script": "lz_conform.py",
        "blurb": "Force any image onto the LimeZu palette, grid and keyline.",
        "writes": "the output path you give it",
        "examples": ["--build-palette"],
    },
}

GENERATOR_TIMEOUT = 300


def list_generators():
    return [
        {
            "key": key,
            "label": spec["label"],
            "blurb": spec["blurb"],
            "writes": spec["writes"],
            "examples": spec["examples"],
            "available": os.path.exists(os.path.join(TOOLS_DIR, spec["script"])),
        }
        for key, spec in GENERATORS.items()
    ]


def run_generator(key, args):
    """Run one generator's CLI. Returns a dict the UI can render directly."""
    spec = GENERATORS.get(key)
    if spec is None:
        return {"ok": False, "error": f"unknown generator: {key}"}

    script = os.path.join(TOOLS_DIR, spec["script"])
    if not os.path.exists(script):
        return {"ok": False, "error": f"missing script: {spec['script']}"}

    # args arrive from the browser, so they are passed as a list (never a
    # shell string) and each one must be a plain flag or token.
    clean = []
    for a in args or []:
        a = str(a).strip()
        if not a:
            continue
        if any(c in a for c in ";|&`$<>\n\r"):
            return {"ok": False, "error": f"refused argument: {a}"}
        clean.append(a)

    cmd = [sys.executable, script] + clean
    try:
        proc = subprocess.run(
            cmd, cwd=REPO_ROOT, capture_output=True, text=True,
            timeout=GENERATOR_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"timed out after {GENERATOR_TIMEOUT}s"}

    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "command": " ".join([spec["script"]] + clean),
        "stdout": proc.stdout[-8000:],
        "stderr": proc.stderr[-4000:],
    }


# ---------------------------------------------------------------- colour

def _each_pixel(im, fn):
    """Apply fn(r,g,b) -> (r,g,b) to every opaque, non-keyline pixel."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a or (r, g, b) == lz_conform.KEYLINE:
                continue
            nr, ng, nb = fn(r, g, b)
            px[x, y] = (
                max(0, min(255, int(nr))),
                max(0, min(255, int(ng))),
                max(0, min(255, int(nb))),
                a,
            )
    return im


def apply_colour(im, opts):
    mapping = opts.get("recolor") or {}
    if mapping:
        im = limezu.recolor(im, mapping)

    hue = float(opts.get("hue") or 0)
    if hue:
        im = limezu.hue_shift(im, hue)

    sat = float(opts.get("saturation", 1.0) or 1.0)
    bright = float(opts.get("brightness", 1.0) or 1.0)
    if sat != 1.0 or bright != 1.0:
        def adjust(r, g, b):
            h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            s = max(0.0, min(1.0, s * sat))
            l = max(0.0, min(1.0, l * bright))
            nr, ng, nb = colorsys.hls_to_rgb(h, l, s)
            return nr * 255, ng * 255, nb * 255
        im = _each_pixel(im, adjust)

    if opts.get("snap_palette"):
        im = lz_conform.snap(im, lz_conform.load_palette())
    return im


# --------------------------------------------------------------- texture

# 4x4 Bayer matrix, normalised to -0.5..+0.5 once at import.
_BAYER = [[(v + 0.5) / 16.0 - 0.5 for v in row] for row in
          ([0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5])]


def apply_texture(im, opts):
    bands = int(opts.get("posterize") or 0)
    if bands >= 2:
        step = 255.0 / (bands - 1)

        def band(r, g, b):
            return (round(r / step) * step,
                    round(g / step) * step,
                    round(b / step) * step)
        im = _each_pixel(im, band)

    strength = float(opts.get("dither") or 0)
    if strength:
        amount = strength * 64.0
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if not a or (r, g, b) == lz_conform.KEYLINE:
                    continue
                nudge = _BAYER[y % 4][x % 4] * amount
                px[x, y] = (
                    max(0, min(255, int(r + nudge))),
                    max(0, min(255, int(g + nudge))),
                    max(0, min(255, int(b + nudge))),
                    a,
                )
        # Dithering only reads as texture once the result is back on-palette.
        im = lz_conform.snap(im, lz_conform.load_palette())

    if opts.get("recolor_outline"):
        im = lz_conform.recolor_outline(im)
    if opts.get("keyline"):
        im = lz_conform.keyline(im)
    return im


# ----------------------------------------------------------------- shape

def apply_shape(im, opts):
    if opts.get("trim"):
        im = lz_conform.crop_to_content(im)

    if opts.get("flip_h"):
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if opts.get("flip_v"):
        im = im.transpose(Image.FLIP_TOP_BOTTOM)

    rotate = int(opts.get("rotate") or 0) % 360
    if rotate in (90, 180, 270):
        im = im.rotate(-rotate, expand=True)

    scale = int(opts.get("scale") or 1)
    if scale > 1:
        scale = min(scale, 8)
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)

    pad = int(opts.get("pad") or 0)
    if pad > 0:
        pad = min(pad, 64)
        out = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
        out.alpha_composite(im, (pad, pad))
        im = out
    return im


def transform(png_bytes, opts):
    """Run one image through colour -> texture -> shape and return PNG bytes.

    Order is deliberate: colour first while the pixel grid is still original,
    texture next because keyline() grows the canvas, scale last so nearest
    neighbour never blurs an outline that texture just drew.
    """
    im = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    im = apply_colour(im, opts.get("color") or {})
    im = apply_texture(im, opts.get("texture") or {})
    im = apply_shape(im, opts.get("shape") or {})
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue(), im.size
