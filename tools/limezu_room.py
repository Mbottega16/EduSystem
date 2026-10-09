"""Build the room's shell -- floors, walls, windows, door -- from LimeZu's Room Builder.

    python tools/limezu_room.py                  write the 18 art/tile_*.png
    python tools/limezu_room.py --preview out.png   the whole 20x11 room, no writes
    python tools/limezu_room.py --check          is art/ what limezu_room.json builds?
    python tools/limezu_room.py --preview out.png office   the room in one of its LOOKS

LOOKS (Oct 2026): the classroom's own floor and wall are the default. "looks" in
limezu_room.json names other floor + wall pairs -- the principal's office, the rooms
you hold -- and each builds the same 18 tiles again with `_<look>` on the end of the
name (tile_floor_a0_office ...). RoomBuilder.LOOKS lists them for the game, which
loads a look's tile by that name (RoomBuilder._tile_img(name, look)).

The game stamps its room at runtime from 18 small tiles (RoomBuilder.compose_room):
eight floor variants, four wall pieces, a two-tile door, four window quarters.
This builds each of them from the packs, driven by tools/limezu_room.json, so
choosing a different floor or wall colour is editing two coordinates and re-running.

HOW THE PIECES COME OUT OF THE PACKS
    floor   one 3x2 block of the Floors sheet; its six tiles fill the eight floor
            slots (a0-a3, b0-b3 -- the game picks one by a position hash).
    walls   a Room Builder wall set is two tiles tall: row 0 = the wall's white cap
            + upper face, row 1 = lower face + skirting. The MIDDLE column of its 3-wide
            block tiles seamlessly sideways, so top0 = (mid, row 0), top1 = (mid, row 1).
            The bottom wall reuses the lower tile. The side wall is a plain face with
            the keyline down both edges.
    door    a Generic-sheet door (14x21) stood on the floor line of the 2-tile doorway,
            over the same plain wall.
    window  a Generic-sheet window (25x20) pasted under the wall's cap, across the 2x2
            tiles it spans, then cut into the four quarters the game expects.
Everything is built in 16x16 art space and doubled with NEAREST at the end.
"""
import json
import os
import sys

from PIL import Image

import limezu

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "limezu_room.json")

T = 16
BASE = (["tile_floor_a%d" % i for i in range(4)] + ["tile_floor_b%d" % i for i in range(4)]
        + ["tile_wall_top0", "tile_wall_top1", "tile_wall_side", "tile_wall_bottom",
           "tile_door_top", "tile_door_bottom",
           "tile_window_l0", "tile_window_l1", "tile_window_r0", "tile_window_r1"])


def load_config():
    with open(CONFIG, encoding="utf-8") as fh:
        return json.load(fh)


def looks(cfg):
    return list(cfg.get("looks", {}).keys())


def look_cfg(cfg, look):
    """The config with one look's floor and wall laid over the classroom's."""
    v = dict(cfg)
    lk = cfg["looks"][look]
    v["floor"] = dict(cfg["floor"], **lk.get("floor", {}))
    v["wall"] = dict(cfg["wall"], **lk.get("wall", {}))
    return v


def _outputs():
    if not os.path.exists(CONFIG):
        return list(BASE)
    out = list(BASE)
    for lk in looks(load_config()):
        out += ["%s_%s" % (n, lk) for n in BASE]
    return out


OUTPUTS = _outputs()


def build_all(cfg, pack):
    """{name: image} for the classroom's tiles and every look's."""
    tiles = build(cfg, pack)
    for lk in looks(cfg):
        for n, im in build(look_cfg(cfg, lk), pack).items():
            tiles["%s_%s" % (n, lk)] = im
    return tiles


def owned_names():
    return set(OUTPUTS) if os.path.exists(CONFIG) else set()


def tile(sheet, tx, ty):
    return sheet.crop((tx * T, ty * T, tx * T + T, ty * T + T))


def build(cfg, pack):
    rb = cfg["room_builder"]
    floors = pack.image(rb["floors"])
    walls = pack.image(rb["walls"])
    generic = pack.image(cfg["generic"])
    keyline = limezu.parse_hex(cfg["keyline"]) + (255,)
    out = {}

    # --- floor: six tiles of one block -> eight slots
    fx, fy = cfg["floor"]["block"]
    six = [tile(floors, fx + (i % 3), fy + (i // 3)) for i in range(6)]
    for i, idx in enumerate(cfg["floor"]["a"]):
        out["tile_floor_a%d" % i] = six[idx]
    for i, idx in enumerate(cfg["floor"]["b"]):
        out["tile_floor_b%d" % i] = six[idx]

    # --- walls
    wx, wy = cfg["wall"]["set"]            # top-left tile of the wall set's 3x2 block
    cap = tile(walls, wx + 1, wy)          # middle column tiles seamlessly
    base = tile(walls, wx + 1, wy + 1)
    out["tile_wall_top0"] = cap
    out["tile_wall_top1"] = base
    out["tile_wall_bottom"] = base
    face = cap.getpixel((8, T - 3))        # flat wall colour, below the cap
    plain = Image.new("RGBA", (T, T), face)
    for y in range(T):
        plain.putpixel((0, y), keyline)
        plain.putpixel((T - 1, y), keyline)
    out["tile_wall_side"] = plain

    # --- door: 14x21 stood on the floor line of the 2-tile doorway
    dx, dy, dw, dh = cfg["door"]["rect"]
    door = generic.crop((dx, dy, dx + dw, dy + dh))
    doorway = Image.new("RGBA", (T, 2 * T), (0, 0, 0, 0))
    doorway.alpha_composite(plain, (0, 0))
    doorway.alpha_composite(plain, (0, T))
    doorway.alpha_composite(door, ((T - dw) // 2, 2 * T - dh))
    out["tile_door_top"] = doorway.crop((0, 0, T, T))
    out["tile_door_bottom"] = doorway.crop((0, T, T, 2 * T))

    # --- window: over the 2x2 wall tiles it spans, then cut into quarters
    wxr, wyr, ww, wh = cfg["window"]["rect"]
    win = generic.crop((wxr, wyr, wxr + ww, wyr + wh))
    bay = Image.new("RGBA", (2 * T, 2 * T), (0, 0, 0, 0))
    for col in (0, 1):
        bay.alpha_composite(cap, (col * T, 0))
        bay.alpha_composite(base, (col * T, T))
    bay.alpha_composite(win, ((2 * T - ww) // 2, cfg["window"].get("top", 9)))
    out["tile_window_l0"] = bay.crop((0, 0, T, T))
    out["tile_window_r0"] = bay.crop((T, 0, 2 * T, T))
    out["tile_window_l1"] = bay.crop((0, T, T, 2 * T))
    out["tile_window_r1"] = bay.crop((T, T, 2 * T, 2 * T))
    return {name: limezu.up2(im) for name, im in out.items()}


def window_col(tx, w):
    if tx < 5 or tx >= w - 2:
        return -1
    off = (tx - 5) % 7
    return off if off <= 1 else -1


def compose_room(t, w=20, h=11, top=2, door=((0, 7), (0, 8))):
    """RoomBuilder.compose_room, in Python -- for previews."""
    S = 32
    im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    floors = []
    for i in range(4):
        floors += [t["tile_floor_a%d" % i], t["tile_floor_b%d" % i]]
    win = [[t["tile_window_l0"], t["tile_window_r0"]], [t["tile_window_l1"], t["tile_window_r1"]]]
    for ty in range(h):
        for tx in range(w):
            if (tx, ty) in door:
                img = t["tile_door_top"] if (tx, ty) == door[0] else t["tile_door_bottom"]
            elif ty < top and window_col(tx, w) >= 0:
                img = win[ty][window_col(tx, w)]
            elif ty == 0:
                img = t["tile_wall_top0"]
            elif ty < top:
                img = t["tile_wall_top1"]
            elif ty == h - 1:
                img = t["tile_wall_bottom"]
            elif tx == 0 or tx == w - 1:
                img = t["tile_wall_side"]
            else:
                shade = (tx + ty) % 2
                v = abs(tx * 7919 + ty * 104729) % 4
                img = floors[v * 2 + shade]
            im.alpha_composite(img, (tx * S, ty * S))
    return im


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    cfg = load_config()
    pack = limezu.need_pack("interiors")
    if "--preview" in flags:
        out = [a for a in argv if a.endswith(".png")][0]
        want = [a for a in argv if not a.startswith("--") and not a.endswith(".png")]
        tiles = build(look_cfg(cfg, want[0]) if want else cfg, pack)
        compose_room(tiles).convert("RGB").save(out)
        print("preview ->", out)
        return 0
    tiles = build_all(cfg, pack)
    check = "--check" in flags
    wrote = bad = 0
    for name in OUTPUTS:
        path = os.path.join(ART, name + ".png")
        have = Image.open(path).convert("RGBA") if os.path.exists(path) else None
        if have is not None and limezu.same_pixels(have, tiles[name]):
            continue
        if check:
            bad += 1
            print("DIFFERS  %s" % name)
            continue
        tiles[name].save(path)
        wrote += 1
        print("art/%-22s %dx%d" % (name + ".png", tiles[name].width, tiles[name].height))
    print("%d written%s" % (wrote, (", %d differ" % bad) if check else ""))
    if wrote:
        print("Godot cannot load changed PNGs until:  godot --headless --path . --import")
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
