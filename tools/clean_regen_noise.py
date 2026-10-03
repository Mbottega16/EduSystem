#!/usr/bin/env python3
"""Restore any file git flags as modified but is actually pixel-identical
to the committed version -- the recurring noise from regenerating art with
a different Pillow/zlib build than whatever produced the committed PNGs
(confirmed harmless by direct pixel diff, not assumed).

Run this after ANY make_art.py / make_items.py / make_ui.py / forge_art.py
invocation, before `git add`. Without it, a single regen run can flag 20+
files nobody touched, burying the real change in noise.

    python3 tools/clean_regen_noise.py [path ...]   (default: art/)

Prints which files were real changes and which were restored as noise.
Exits non-zero only on an actual error (git/PIL failure), never because
noise was found -- finding and fixing noise is the success case.
"""
import os
import subprocess
import sys
from io import BytesIO

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git(*args, text=True):
    return subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=text)


def modified_pngs(paths):
    res = git("status", "--porcelain", *paths)
    if res.returncode != 0:
        sys.exit("git status failed: %s" % res.stderr)
    out = []
    for line in res.stdout.splitlines():
        if not line:
            continue
        status, path = line[:2], line[3:].strip()
        if path.endswith(".png") and "M" in status:
            out.append(path)
    return out


def pixel_identical(path):
    """True only if HEAD has this path AND every pixel matches exactly.
    Any failure to read either side (new file, corrupt image, git miss)
    returns False -- a real-change verdict is the safe default, never
    silently discard something that might be a genuine change."""
    head = git("show", "HEAD:%s" % path, text=False)
    if head.returncode != 0:
        return False
    try:
        old = Image.open(BytesIO(head.stdout)).convert("RGBA")
    except Exception:
        return False
    try:
        new = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    except Exception:
        return False
    if old.size != new.size:
        return False
    # getbbox()'s alpha_only defaults to True on an RGBA image -- it
    # then checks ONLY the alpha channel and ignores RGB entirely. Two
    # fully-opaque images always diff to alpha=0 everywhere even when
    # their colours are completely different, so the old
    # `.getbbox() is None` check here always returned True (pixel
    # identical) regardless of colour -- confirmed the hard way: it
    # silently reverted a real finish() -> finish_rich() shading change
    # on whiteboard/alphabet_frieze, discarding real work. alpha_only
    # =False makes it check every channel, which is what "pixel
    # identical" actually has to mean here.
    return ImageChops.difference(old, new).getbbox(alpha_only=False) is None


def main():
    paths = sys.argv[1:] or ["art/"]
    changed = modified_pngs(paths)
    if not changed:
        print("No modified PNGs under %s." % " ".join(paths))
        return
    noise, real = [], []
    for path in changed:
        (noise if pixel_identical(path) else real).append(path)
    if noise:
        res = git("checkout", "--", *noise)
        if res.returncode != 0:
            sys.exit("git checkout failed restoring noise: %s" % res.stderr)
    print("restored (pixel-identical, encoder noise only): %d" % len(noise))
    for p in noise:
        print("  - %s" % p)
    print("real changes: %d" % len(real))
    for p in real:
        print("  - %s" % p)


if __name__ == "__main__":
    main()
