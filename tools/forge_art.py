#!/usr/bin/env python3
"""CLI art forge -- regenerate ONE sprite straight into art/, with tweaks.

The visual sibling of tools/forge_audio.py. It draws nothing of its own:
it calls the SAME functions make_art.py / make_items.py use, with your
overrides applied, and writes the PNG -- Scale2x'd where those pipelines
Scale2x -- to art/<name>.png. Then it reminds you to import if the asset
is new (Godot cannot load an unimported texture).

    python tools/forge_art.py list [items|characters|tiles]
    python tools/forge_art.py <name> [key=value ...] [--force]

VALUE FORMS
    #rrggbb  /  #rgb  /  rrggbb        a colour

  characters (player, student_a..h, inspector, principal, mentor):
    hair= hair_d= shirt= shirt_d= legs= shoe=   colours
    skin=tan            one of: fair light tan brown dark  (or a #hex)
    hair_style=curly    one of: short long curly spiky bob bun buzz ponytail
    pattern=stripes     one of: plain stripes dungarees collar tie cardigan lanyard
    glasses=1  sleeves=short  long_hair=0  skirt=0
    (hair_d / shirt_d are auto-derived from hair / shirt if you omit them)

  furniture & items (desk, chair, globe, bookshelf, ...):
    wood=#8a5a2c  wood_d=#5a3a1c  steel=  cloth=  gold=  ...   patch a shared
                                        palette colour before the draw
    tint=#3a6ea5  strength=0.25         blend every fill toward a colour
                                        (the black outline is left alone)
    swap=#585c66:#2a2a2a                replace one exact colour (repeatable)

  tiles: floor_a= floor_b= wall= wall_l= wall_d= wall_top= wall_base=
         fleck= grout=      -- regenerates the whole tile_*.png set

EXAMPLES
    python tools/forge_art.py desk wood=#8a5a2c wood_d=#5a3a1c
    python tools/forge_art.py globe tint=#3a6ea5 strength=0.3
    python tools/forge_art.py student_c hair=#7a2f1a hair_style=curly glasses=1
    python tools/forge_art.py chair swap=#585c66:#2a2a2a
    python tools/forge_art.py tiles floor_a=#d8cdb4 floor_b=#cfc4aa

A sprite with a tools/sprites/<name>.txt hand-edited source is refused
unless you pass --force -- otherwise this would silently undo a hand edit,
the exact thing make_art.py's save_png() stands down to prevent.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "art")
sys.path.insert(0, HERE)

from PIL import Image
import make_art
import make_items


# --- value parsing --------------------------------------------------

def parse_colour(s):
    s = s.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        raise ValueError("not a colour: %r (want #rrggbb)" % s)
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def parse_value(v):
    """A CLI value -> colour tuple, bool, float, or bare string."""
    low = v.strip().lower()
    if low in ("1", "true", "yes", "on"):
        return True
    if low in ("0", "false", "no", "off"):
        return False
    if v.startswith("#") or (len(v) in (3, 6) and all(c in "0123456789abcdefABCDEF" for c in v)):
        try:
            return parse_colour(v)
        except ValueError:
            pass
    try:
        return float(v) if "." in v else int(v)
    except ValueError:
        return v


# --- pixel post-processing (items / furniture / tiles) -------------

def _protected(px):
    """Outline and shadow pixels a recolour must not touch."""
    return px[3] < 255 or px[:3] == make_art.LINE


def apply_swap(img, pairs):
    if not pairs:
        return img
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            for src, dst in pairs:
                if p[:3] == src:
                    px[x, y] = (dst[0], dst[1], dst[2], p[3])
                    break
    return img


def apply_tint(img, target, strength):
    if target is None or strength <= 0:
        return img
    strength = max(0.0, min(1.0, strength))
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if _protected(p):
                continue
            px[x, y] = tuple(
                int(round(p[i] * (1 - strength) + target[i] * strength))
                for i in range(3)) + (p[3],)
    return img


# --- the registry -------------------------------------------------

def _catalogue():
    """name -> ('character' | ('draw', module, fn) | 'tiles')."""
    cat = {}
    for name in make_art.CHARACTERS:
        cat[name] = ("character", None, None)
    for name, fn in make_art.FURNITURE.items():
        cat[name] = ("draw", make_art, fn)
    for name, fn in make_art.ITEM_ART.items():
        cat[name] = ("draw", make_art, fn)
    for name, fn in list(make_items.ITEMS.items()) + list(make_items.MESS_ITEMS.items()):
        cat[name] = ("draw", make_items, fn)
    cat["tiles"] = ("tiles", None, None)
    return cat


CHAR_KEYS = ("hair", "hair_d", "shirt", "shirt_d", "legs", "shoe", "skin",
             "hair_style", "pattern", "glasses", "sleeves", "long_hair", "skirt")
TILE_KEYS = {"floor_a": "FLOOR_A", "floor_b": "FLOOR_B", "wall": "WALL",
             "wall_l": "WALL_L", "wall_d": "WALL_D", "wall_top": "WALL_TOP",
             "wall_base": "WALL_BASE", "fleck": "FLOOR_FLECK", "grout": "FLOOR_GROUT"}


def _palette_consts(module):
    return {k.lower(): k for k, v in vars(module).items()
            if k.isupper() and isinstance(v, tuple) and len(v) == 3
            and all(isinstance(c, int) for c in v)}


# --- doing the work ---------------------------------------------

def _import_note(name):
    if not os.path.exists(os.path.join(OUT, name + ".png.import")):
        print("  NEW asset -- Godot cannot load it yet. Run:  Reimport Art.bat"
              "   (or: godot --headless --path . --import)")


def _hand_owned(name):
    return os.path.exists(os.path.join(HERE, "sprites", name + ".txt"))


def _limezu_owned(name):
    try:
        import limezu
        return name in limezu.owned_names()
    except ImportError:
        return False


def _hand_guard(name, force):
    """A sprite with a text-grid source is the pixel editor's (Browse
    Art.bat) job -- this tool has no canvas and cannot regenerate the .txt
    from a colour tweak. --force writes the PNG anyway, but says plainly
    that the source still owns it and the next make_art.py run reverts it."""
    if _limezu_owned(name) and not _hand_owned(name):
        if not force:
            sys.exit("%s comes from the LimeZu packs (tools/limezu_manifest.json or "
                     "limezu_cast.json). Change which sprite it uses there and run "
                     "import_limezu.py / limezu_chars.py, or pass --force for a throwaway "
                     "override." % name)
        print("  NOTE: %s is LimeZu-owned. The next import_limezu.py / limezu_chars.py "
              "run reverts what you just wrote." % name)
        return
    if not _hand_owned(name):
        return
    if not force:
        sys.exit("%s is hand-edited (tools/sprites/%s.txt). Edit it in Browse Art.bat, "
                 "or pass --force for a throwaway override." % (name, name))
    print("  NOTE: tools/sprites/%s.txt still owns this sprite. The next "
          "`python tools/make_art.py` reverts what you just wrote." % name)


def forge_character(name, kv, force):
    _hand_guard(name, force)
    pal = dict(make_art.CHARACTERS[name])
    for k, v in kv.items():
        if k not in CHAR_KEYS:
            sys.exit("character key %r is not one of: %s" % (k, " ".join(CHAR_KEYS)))
        pal[k] = v
    # a new base colour with no explicit dark tone -> derive one, so the
    # shading stays consistent instead of clashing with the old value
    if "hair" in kv and "hair_d" not in kv:
        pal["hair_d"] = make_art.darker(pal["hair"], 0.28)
    if "shirt" in kv and "shirt_d" not in kv:
        pal["shirt_d"] = make_art.darker(pal["shirt"], 0.28)

    make_art._HAND = make_art.hand_edited()
    if force:
        make_art._HAND.discard(name)
    make_art._STOOD_DOWN = []

    size = make_art.make_character(name, pal)
    print("art/%-18s %3dx%-3d" % (name + ".png", size[0], size[1]))
    if name != "examiner":
        psize = make_art.make_portrait(name, pal)
        print("art/%-18s %3dx%-3d" % ("portrait_" + name + ".png", psize[0], psize[1]))
    _import_note(name)


def forge_draw(name, module, fn, kv, force):
    _hand_guard(name, force)

    consts = _palette_consts(module)
    tint = kv.pop("tint", None)
    strength = float(kv.pop("strength", 0.3))
    swaps = kv.pop("_swaps", [])

    saved = {}
    for k, v in list(kv.items()):
        if k not in consts:
            sys.exit("%r takes no key %r. palette colours here: %s"
                     % (name, k, " ".join(sorted(consts))))
        if not isinstance(v, tuple):
            sys.exit("%s must be a colour, got %r" % (k, v))
        real = consts[k]
        saved[real] = getattr(module, real)
        setattr(module, real, v)
    try:
        img = fn()
    finally:
        for real, old in saved.items():
            setattr(module, real, old)

    img = img.convert("RGBA")
    apply_swap(img, swaps)
    apply_tint(img, tint, strength)
    img = make_art.scale2x(img)

    img.save(os.path.join(OUT, name + ".png"))
    print("art/%-18s %3dx%-3d" % (name + ".png", img.width, img.height))
    _import_note(name)


def forge_tiles(kv):
    saved = {}
    for k, v in kv.items():
        if k not in TILE_KEYS:
            sys.exit("tiles takes: %s" % " ".join(TILE_KEYS))
        real = TILE_KEYS[k]
        saved[real] = getattr(make_art, real)
        setattr(make_art, real, v)
    make_art._HAND = set()
    try:
        names = make_art.make_room_tiles()
    finally:
        for real, old in saved.items():
            setattr(make_art, real, old)
    print("rewrote %d tile PNGs: %s" % (len(names), ", ".join(names)))
    print("  Run:  Reimport Art.bat   (tiles are always re-imported anyway on next launch)")


# --- CLI --------------------------------------------------------

def do_list(which):
    cat = _catalogue()
    chars = [n for n in cat if cat[n][0] == "character"]
    draws_art = [n for n, e in cat.items() if e[0] == "draw" and e[1] is make_art]
    draws_items = [n for n, e in cat.items() if e[0] == "draw" and e[1] is make_items]
    if which in (None, "characters"):
        print("CHARACTERS  (keys: %s)" % " ".join(CHAR_KEYS))
        print("  " + "  ".join(sorted(chars)))
    if which in (None, "items"):
        art_keys = " ".join(sorted(_palette_consts(make_art)))
        item_keys = " ".join(sorted(_palette_consts(make_items)))
        print("\nFURNITURE / SCREEN ART  (make_art)")
        print("  palette keys: %s" % art_keys)
        print("  + tint=#hex strength=0..1   swap=#from:#to")
        print("  " + "  ".join(sorted(draws_art)))
        print("\nSHOP ITEMS & MESS  (make_items)")
        print("  palette keys: %s   + tint=  swap=" % item_keys)
        print("  " + "  ".join(sorted(draws_items)))
    if which in (None, "tiles"):
        print("\nTILES  ->  python tools/forge_art.py tiles [%s]"
              % " ".join(k + "=#hex" for k in TILE_KEYS))


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help") and len(argv) == 1:
        print(__doc__)
        return 0
    if argv[0] == "list":
        do_list(argv[1] if len(argv) > 1 else None)
        return 0
    if argv[0] == "names":
        # `list` is written for a human: headings, the palette keys, prose.
        # This is the same catalogue with nothing but the names, one per
        # line, for the Master Forge's dropdown -- which was parsing `list`
        # and offering the reader "&" and "(make_art)" as sprites.
        for n in sorted(_catalogue()):
            print(n)
        print("tiles")
        return 0

    name = argv[0]
    force = "--force" in argv[1:]
    is_random = "--random" in argv[1:]
    rest = [a for a in argv[1:] if a not in ("--force", "--random")]

    kv = {}
    swaps = []
    for a in rest:
        if "=" not in a:
            sys.exit("expected key=value, got %r" % a)
        k, v = a.split("=", 1)
        k = k.strip().lower()
        if k == "swap":
            src, _, dst = v.partition(":")
            swaps.append((parse_colour(src), parse_colour(dst)))
        else:
            kv[k] = parse_value(v)
    if swaps:
        kv["_swaps"] = swaps
    if is_random:
        kv["_random"] = True

    if name == "tiles":
        kv.pop("_swaps", None)
        forge_tiles(kv)
        return 0

    cat = _catalogue()
    if name not in cat:
        sys.exit("unknown sprite %r -- try:  python tools/forge_art.py list" % name)
    kind, module, fn = cat[name]
    if kind == "character":
        kv.pop("_swaps", None)
        forge_character(name, kv, force)
    else:
        forge_draw(name, module, fn, kv, force)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
