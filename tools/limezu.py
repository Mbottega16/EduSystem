"""Read LimeZu asset packs straight out of their zips -- Pillow only.

WHY THIS EXISTS
    The game's art used to be 100% procedural (make_art.py, make_items.py,
    make_ui.py). The owner wants the LimeZu look -- the Modern Interiors,
    Modern Office and Modern UI packs -- so this module is the other half of
    the pipeline: it fetches one sprite out of a pack, and the importers
    (import_limezu.py for props and tiles, limezu_chars.py for people) turn it
    into the PNG the game loads.

THE PACKS STAY OUT OF THE REPO
    Licence (all three, read 2026-10-02): edit and use in commercial or
    non-commercial projects; you CANNOT resell or distribute the asset to
    others; credit required (limezu.itch.io) for Interiors and UI, appreciated
    for Office. So the repo carries only the finished sprites the game uses,
    never a pack, and the packs are read in place from wherever they were
    downloaded. The FREE edition of Modern Interiors is NON-COMMERCIAL ONLY and
    is deliberately not used anywhere -- this is a Steam game.

WHERE THE PACKS ARE FOUND (first hit wins)
    1. $LIMEZU_DIR, 2. the first line of tools/limezu_path.txt (untracked,
    per-machine), 3. ~/Desktop, ~/Downloads, ~/OneDrive/Desktop,
    ~/OneDrive/Downloads. A pack may be the original .zip or an extracted
    folder.

SCALE
    Everything here is taken from the 16x16 folders and doubled with plain
    NEAREST. That is byte-for-byte what LimeZu's own 32x32 folders are (checked
    2026-10-02), and it lands on the game's 32px tile with no resampling.
"""
import glob
import io
import json
import os
import re
import zipfile

from PIL import Image

TOOLS = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(TOOLS, "limezu_manifest.json")
CAST = os.path.join(TOOLS, "limezu_cast.json")

# pack key -> (zip name glob, a path that proves we are looking at the pack root)
PACKS = {
    "interiors": ("moderninteriors*.zip", "1_Interiors"),
    "office": ("Modern_Office*.zip", "4_Modern_Office_singles"),
    "ui": ("modernuserinterface*.zip", "Portrait_Generator_ase"),
}

CREDIT = "Art by LimeZu (limezu.itch.io) - Modern Interiors, Modern Office, Modern UI"


def search_dirs():
    out = []
    env = os.environ.get("LIMEZU_DIR")
    if env:
        out.append(env)
    f = os.path.join(TOOLS, "limezu_path.txt")
    if os.path.exists(f):
        with io.open(f, encoding="utf-8") as fh:
            first = fh.readline().strip()
        if first:
            out.append(first)
    home = os.path.expanduser("~")
    for rel in ("Desktop", "Downloads", os.path.join("OneDrive", "Desktop"),
                os.path.join("OneDrive", "Downloads")):
        out.append(os.path.join(home, rel))
    return [d for d in out if os.path.isdir(d)]


class Pack(object):
    """One pack, read from a zip or from an extracted folder."""

    def __init__(self, key, where):
        self.key = key
        self.where = where
        self._cache = {}
        if os.path.isdir(where):
            self._zip = None
            self._root = where
            self._names = None
        else:
            self._zip = zipfile.ZipFile(where)
            self._root = ""
            self._names = [n for n in self._zip.namelist() if not n.endswith("/")]

    def names(self):
        if self._names is None:
            base = self._root
            self._names = []
            for dp, _dn, fns in os.walk(base):
                for fn in fns:
                    self._names.append(os.path.relpath(os.path.join(dp, fn), base).replace(os.sep, "/"))
        return self._names

    def has(self, member):
        if self._zip is not None:
            try:
                self._zip.getinfo(member)
                return True
            except KeyError:
                return False
        return os.path.exists(os.path.join(self._root, member))

    def read(self, member):
        if self._zip is not None:
            return self._zip.read(member)
        with open(os.path.join(self._root, member), "rb") as fh:
            return fh.read()

    def image(self, member):
        """An RGBA copy of one member (cached, so callers may mutate theirs)."""
        if member not in self._cache:
            self._cache[member] = Image.open(io.BytesIO(self.read(member))).convert("RGBA")
        return self._cache[member].copy()


_packs = {}


def _dir_root(path, marker):
    if os.path.isdir(os.path.join(path, marker)):
        return path
    for sub in sorted(os.listdir(path)):
        p = os.path.join(path, sub)
        if os.path.isdir(p) and os.path.isdir(os.path.join(p, marker)):
            return p
    return None


def find_pack(key):
    """-> Pack, or None when this machine does not have it."""
    if key in _packs:
        return _packs[key]
    pattern, marker = PACKS[key]
    found = None
    for d in search_dirs():
        for z in sorted(glob.glob(os.path.join(d, pattern))):
            found = z
            break
        if found:
            break
        for cand in sorted(glob.glob(os.path.join(d, pattern.replace(".zip", "")))):
            if os.path.isdir(cand):
                root = _dir_root(cand, marker)
                if root:
                    found = root
                    break
        if found:
            break
    _packs[key] = Pack(key, found) if found else None
    return _packs[key]


def need_pack(key):
    p = find_pack(key)
    if p is None:
        raise SystemExit(
            "Could not find the LimeZu '%s' pack (looked for %s in: %s).\n"
            "Put the zip on the Desktop or in Downloads, or set LIMEZU_DIR, or write\n"
            "its folder into tools/limezu_path.txt." % (key, PACKS[key][0], ", ".join(search_dirs())))
    return p


# --------------------------------------------------------------- manifest ---

def load_manifest():
    with io.open(MANIFEST, encoding="utf-8") as fh:
        return json.load(fh)


def load_cast():
    if not os.path.exists(CAST):
        return {}
    with io.open(CAST, encoding="utf-8") as fh:
        return json.load(fh)


def owned_names():
    """Every art name a LimeZu importer owns -- the generators stand down.

    Read from the JSON alone, so it works on a machine without the packs. This
    is what make_art.hand_edited() unions in: a LimeZu sprite is protected the
    same way a hand-edited one is, and for the same reason -- the next run of a
    procedural generator must not silently undo it.
    """
    names = set()
    if os.path.exists(MANIFEST):
        m = load_manifest()
        names.update(m.get("props", {}).keys())
        names.update(m.get("tiles", {}).keys())
        for pname, pspec in m.get("props", {}).items():
            if "anim" in pspec:
                names.add(pname + "_anim")
    room_cfg = os.path.join(TOOLS, "limezu_room.json")
    if os.path.exists(room_cfg):
        import limezu_room
        names.update(limezu_room.OUTPUTS)
    if os.path.exists(os.path.join(TOOLS, "limezu_ui.py")):
        import limezu_ui
        names.update(limezu_ui.OUTPUTS)
    # The free packs' importer (tools/import_free.py) owns its names the same way.
    free = os.path.join(TOOLS, "free_manifest.json")
    if os.path.exists(free):
        with io.open(free, encoding="utf-8") as fh:
            fm = json.load(fh)
        for pname, pspec in fm.get("props", {}).items():
            names.add(pname)
            if "anim" in pspec:
                names.add(pname + "_anim")
    cast = load_cast()
    for name, spec in cast.get("characters", {}).items():
        names.add(name)
        if isinstance(spec.get("portrait"), dict):
            names.add("portrait_" + name)
            names.add("portrait_" + name + "_talk")
    return names


_theme_index = {}


def _theme_files(pack, theme):
    """{n: member path} for one numbered-singles folder."""
    key = (pack.key, theme["dir"])
    if key not in _theme_index:
        idx = {}
        prefix = theme["dir"].rstrip("/") + "/"
        for n in pack.names():
            if n.startswith(prefix) and n.lower().endswith(".png"):
                m = re.search(r"(\d+)\.png$", n, re.I)
                if m:
                    idx[int(m.group(1))] = n
        _theme_index[key] = idx
    return _theme_index[key]


def resolve(ref, manifest):
    """'classroom#6' -> (Pack, member path)."""
    theme_key, _, num = ref.partition("#")
    theme = manifest["themes"][theme_key]
    pack = need_pack(theme["pack"])
    files = _theme_files(pack, theme)
    n = int(num)
    if n not in files:
        raise SystemExit("%s: no sprite #%d in %s" % (ref, n, theme["dir"]))
    return pack, files[n]


# ------------------------------------------------------------ image helpers --

def trim(im, mode="y"):
    """Crop transparent margins. 'y' keeps the full width on purpose: a LimeZu
    object is drawn tile-aligned, so keeping its canvas width keeps it centred
    on its tile exactly as its artist placed it."""
    bb = im.getbbox()
    if bb is None or mode == "none":
        return im
    if mode == "y":
        return im.crop((0, bb[1], im.width, bb[3]))
    return im.crop(bb)


def same_pixels(a, b):
    """True when two RGBA images look identical.

    NOT ImageChops.difference(a, b).getbbox() is None: on an RGBA image getbbox()
    looks at the alpha channel only, so a recolour that leaves the silhouette alone
    (a different hair colour, a hue shift) reads as "no change" and the importer
    would skip a sprite that really did change. Premultiplied bytes compare the
    colours too, and make every fully transparent pixel equal whatever its RGB."""
    return a.size == b.size and a.convert("RGBa").tobytes() == b.convert("RGBa").tobytes()


def up2(im):
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def parse_hex(c):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16))


def recolor(im, mapping):
    """Swap exact colours: {'#aabbcc': '#112233'}. Alpha is preserved."""
    if not mapping:
        return im
    m = {parse_hex(k): parse_hex(v) for k, v in mapping.items()}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in m:
                nr, ng, nb = m[(r, g, b)]
                px[x, y] = (nr, ng, nb, a)
    return im


# LimeZu bakes a flat, opaque contact shadow in this one colour under his objects,
# matched to his own floor. The "shadowless" singles leave it out, but his animated
# sheets (and a stray few singles) keep it, and on our floor it reads as a mauve
# patch -- the room draws its own shadow. "drop_shadow": true clears it.
LZ_SHADOW = (0xa7, 0x97, 0x96)


def drop_shadow(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] and px[x, y][:3] == LZ_SHADOW:
                px[x, y] = (0, 0, 0, 0)
    return im


def hue_shift(im, degrees):
    """Rotate the hue of every coloured pixel by `degrees`; outlines and greys stay.

    How one LimeZu object becomes a second colourway (the locker the storage
    cabinet uses, bought again as a green one). Dark outline pixels and
    near-greys are left alone so the keyline keeps its slate tone.
    """
    if not degrees:
        return im
    import colorsys
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if v < 0.34 or s < 0.10:
                continue
            h = (h + degrees / 360.0) % 1.0
            nr, ng, nb = colorsys.hsv_to_rgb(h, min(1.0, s * 1.15), v)
            px[x, y] = (int(nr * 255 + .5), int(ng * 255 + .5), int(nb * 255 + .5), a)
    return im


def spin_frames(still, spin, n):
    """N frames of a globe turning, from one still.

    Every pixel drawn in a "land" or "sea" colour is a map pixel. Its CATEGORY (land
    or sea) rolls round its row -- by row length * f / N on frame f, so a short row
    near a pole turns at the same rate as the equator -- while its SHADE (its index in
    the light-to-dark ramp) stays where it is, so the light still falls from the same
    side as the map goes past. Frame N would be frame 0 again, so the strip loops.
    Outline, stand and every other colour never move.
    """
    ramps = {k: [parse_hex(c) for c in spin[k]] for k in ("land", "sea")}
    lookup = {}
    for cat, ramp in ramps.items():
        for i, c in enumerate(ramp):
            lookup[c] = (cat, i)
    px = still.load()
    w, h = still.size
    rows = {}
    for y in range(h):
        xs = [x for x in range(w) if px[x, y][3] and px[x, y][:3] in lookup]
        if xs:
            rows[y] = xs
    frames = []
    for f in range(n):
        im = still.copy()
        q = im.load()
        for y, xs in rows.items():
            k = len(xs)
            shift = int(round(f * k / float(n)))
            for i, x in enumerate(xs):
                cat = lookup[px[xs[(i - shift) % k], y][:3]][0]
                shade = min(lookup[px[x, y][:3]][1], len(ramps[cat]) - 1)
                r, g, b = ramps[cat][shade]
                q[x, y] = (r, g, b, px[x, y][3])
        frames.append(im)
    return frames


def build_anim(spec, manifest):
    """An animated prop -> (static first frame, horizontal strip of every frame), both at game scale.

    The spec is a "sheet"+"rect" prop (rect = FRAME 0: x, y, frame_w, frame_h) plus
    "anim": {"frames": N, ...}; frames sit side by side in the pack's sheet. Or it is a
    "ref" single that the pack never animated, plus either
      "anim": {"frames": 2, "swap_rows": [y0, y1], "swap": {colour: colour}} -- frame 2 is
        the single with those colours traded in those art rows (a fan's grille swapping
        its light and dark wires reads as the blades going round), or
      "anim": {"frames": N, "spin": {"land": [light..dark], "sea": [light..dark]}} -- the
        land/sea pattern rolls one way round each row while every pixel keeps its own
        shade (see spin_frames: a globe that turns, lit the same way all the time), or
      "anim": {"frames": N, "sway": {"from_row": y, "offsets": [0, 1, 0, -1]}} -- every
        art row from y down slides sideways by that frame's offset, the rows above it
        (a hook, a string) staying put: a hanging thing drifting on its thread.
    Every frame is
    cropped by the UNION of their bounds, so the strip is aligned frame to frame and the
    static art (frame 0 with that same crop) lines up with it exactly -- the shop's ghost and
    the placed, animating sprite are the same size.
    """
    n = int(spec["anim"]["frames"])
    if "ref" in spec:
        a = spec["anim"]
        rpack, member = resolve(spec["ref"], manifest)
        still = rpack.image(member)
        w, h = still.size
        if "spin" in a:
            frames = spin_frames(still, a["spin"], n)
        elif "sway" in a:
            y_from = int(a["sway"]["from_row"])
            frames = []
            for off in a["sway"]["offsets"]:
                f = still.copy()
                band = still.crop((0, y_from, w, h))
                f.paste((0, 0, 0, 0), (0, y_from, w, h))
                f.alpha_composite(band, (int(off), y_from))
                frames.append(f)
            if n != len(frames):
                raise SystemExit("%s: %d sway offsets for %d frames" % (spec["ref"], len(frames), n))
        else:
            ry0, ry1 = a["swap_rows"]
            alt = still.copy()
            alt.paste(recolor(alt.crop((0, ry0, w, ry1)), a["swap"]), (0, ry0))
            frames = [still, alt]
            if n != len(frames):
                raise SystemExit("%s: a colour-swap animation is 2 frames, not %d" % (spec["ref"], n))
    else:
        pack = need_pack(spec["pack"])
        sheet = pack.image(spec["sheet"])
        x0, y0, w, h = spec["rect"]
        frames = [sheet.crop((x0 + i * w, y0, x0 + (i + 1) * w, y0 + h)) for i in range(n)]
    if spec.get("drop_shadow"):
        frames = [drop_shadow(f) for f in frames]
    if "compose" in spec:
        # A still single under every frame, the animated sheet pasted onto it at
        # "at" (art px): the pack's idle frog sitting in its mossy tank, so a
        # terrarium has something alive in it. The frame is the base's size.
        comp = spec["compose"]
        bpack, bmember = resolve(comp["base"], manifest)
        base = bpack.image(bmember)
        ax, ay = comp["at"]
        framed = []
        for f in frames:
            b = base.copy()
            b.alpha_composite(f, (ax, ay))
            framed.append(b)
        frames = framed
        w, h = base.size
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    ux0 = min(b[0] for b in boxes)
    uy0 = min(b[1] for b in boxes)
    ux1 = max(b[2] for b in boxes)
    uy1 = max(b[3] for b in boxes)
    mode = spec.get("trim", "y")
    box = (0 if mode == "y" else ux0, uy0, w if mode == "y" else ux1, uy1)
    cut = [f.crop(box) for f in frames]
    strip = Image.new("RGBA", (cut[0].width * n, cut[0].height), (0, 0, 0, 0))
    for i, f in enumerate(cut):
        strip.alpha_composite(f, (i * f.width, 0))
    return up2(cut[0]), up2(strip)


def _side_by_side(parts):
    """Images set left to right, bottoms aligned."""
    h = max(p.height for p in parts)
    im = Image.new("RGBA", (sum(p.width for p in parts), h), (0, 0, 0, 0))
    x = 0
    for p in parts:
        im.alpha_composite(p, (x, h - p.height))
        x += p.width
    return im


def _parts(parts, manifest):
    """[{"ref": r, "cols": [x0, x1]}, ...] -> those column ranges of those singles, side
    by side (no "cols" = the whole single). How a modular piece is made longer than the
    pack draws it: a museum vitrine's left end, its middle twice, its right end."""
    out = []
    for p in parts:
        pack, member = resolve(p["ref"], manifest)
        im = pack.image(member)
        if "cols" in p:
            x0, x1 = p["cols"]
            im = im.crop((x0, 0, x1, im.height))
        out.append(im)
    return _side_by_side(out)


def restack(im, rows):
    """Those [y0, y1) row ranges of `im`, one under the other."""
    out = Image.new("RGBA", (im.width, sum(y1 - y0 for y0, y1 in rows)), (0, 0, 0, 0))
    y = 0
    for y0, y1 in rows:
        out.alpha_composite(im.crop((0, y0, im.width, y1)), (0, y))
        y += y1 - y0
    return out


def glare(lit, plain):
    """The light `lit` adds over `plain`, as white: where plain is empty, lit's own
    pixel (a glint on clear glass); where plain is drawn, white at a strength set by how
    much brighter lit is there (a streak across the glass); nothing anywhere else."""
    if lit.size != plain.size:
        raise SystemExit("glare_over: %s against %s -- the two must be the same size" % (lit.size, plain.size))
    out = Image.new("RGBA", lit.size, (0, 0, 0, 0))
    a, b, o = lit.load(), plain.load(), out.load()
    for y in range(lit.height):
        for x in range(lit.width):
            if a[x, y] == b[x, y] or not a[x, y][3]:
                continue
            if not b[x, y][3]:
                o[x, y] = a[x, y]
                continue
            lum = lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
            gain = lum(a[x, y]) - lum(b[x, y])
            if gain > 0:
                o[x, y] = (255, 255, 255, min(255, int(gain * 5)))
    return out


def build_prop(spec, manifest):
    """One manifest prop entry -> the finished, game-scale RGBA image.

    A spec names its source one of four ways: "ref": "classroom#6" (a numbered
    single, see "themes" in the manifest), "join": [ref, ref] (several singles side
    by side), "parts" (pieces OF singles side by side, see _parts), or "sheet" +
    "pack" + "rect" (a [x, y, w, h] cut, in 16x16 art pixels, from one of a pack's
    big sheets -- how animated first frames come out).

    "rows": [[y0, y1], ...] restacks the image from those row ranges, top to bottom --
    how a vitrine loses the bar across its front and becomes one tall pane.

    "glare_over": [parts] keeps only the light the spec's own image adds over that
    other one, as white of matching strength -- the glass of a case without the
    case, to draw in front of whatever stands inside it. Both must be the same size,
    so a glare entry and its case use "trim": "none" and line up exactly.
    """
    if "join" in spec:
        # "join": [ref, ref, ...] -- numbered singles set side by side, bottoms aligned
        # (a two-seat sofa out of two one-seat modules).
        parts = []
        for ref in spec["join"]:
            pack, member = resolve(ref, manifest)
            parts.append(pack.image(member))
        im = _side_by_side(parts)
    elif "parts" in spec:
        im = _parts(spec["parts"], manifest)
    elif "sheet" in spec:
        pack = need_pack(spec["pack"])
        im = pack.image(spec["sheet"])
        x, y, w, h = spec["rect"]
        im = im.crop((x, y, x + w, y + h))
    else:
        pack, member = resolve(spec["ref"], manifest)
        im = pack.image(member)
    if "crop" in spec:
        im = im.crop(tuple(spec["crop"]))
    if "rows" in spec:
        im = restack(im, spec["rows"])
    if "glare_over" in spec:
        plain = _parts(spec["glare_over"], manifest)
        if "rows" in spec:
            plain = restack(plain, spec["rows"])
        im = glare(im, plain)
    if spec.get("flip") == "h":
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if spec.get("drop_shadow"):
        im = drop_shadow(im)
    im = recolor(im, spec.get("recolor"))
    im = hue_shift(im, spec.get("hue", 0))
    im = trim(im, spec.get("trim", "y"))
    if "pad" in spec:
        l, t, r, b = spec["pad"]
        padded = Image.new("RGBA", (im.width + l + r, im.height + t + b), (0, 0, 0, 0))
        padded.alpha_composite(im, (l, t))
        im = padded
    return up2(im)
