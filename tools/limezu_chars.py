"""Bake LimeZu people into the game's 15x4 character sheets -- Pillow only.

    python tools/limezu_chars.py                 bake every character in limezu_cast.json
    python tools/limezu_chars.py student_a       just that one
    python tools/limezu_chars.py --list          the cast, as the file describes it
    python tools/limezu_chars.py --preview out.png [names]   a contact sheet, no writes
    python tools/limezu_chars.py --check         is every art/<name>.png what the file builds?

This is LimeZu's "Character Generator" done in Python instead of Piskel: the
pack ships bodies, eyes, outfits, hairstyles and accessories as separate
transparent sheets that share one layout, to be stacked in a fixed order
(BODY, EYES, OUTFIT, HAIRSTYLE, ACCESSORY). The game, though, loads ONE flat
PNG per character (a 15x4 grid of 32x48 cells -- see Actor.WALK_CYCLE /
SIT_FRAME / POSE_*), so the layers are stacked and baked here, offline. No
engine-side compositing code is involved.

WHY THE FRAMES FIT
    A LimeZu chibi is 16 wide and about 22 tall (a kid about 19) inside a 16x32
    cell, bottom-aligned. The game's cell is 16x24 art pixels (32x48 once
    doubled). So: take the BOTTOM 24 rows of the LimeZu cell, double it with
    NEAREST, and it is the game's cell -- no resampling, no code change.

WHAT MAPS TO WHAT (LimeZu row, direction order right/up/left/down, 6 frames each)
    col 0  stand            idle   frame 0
    col 1  step             walk   frame 1
    col 2  stand            idle   frame 0
    col 3  the other step   walk   frame 4
    col 4  sit              idle   frame 0, raised so the face clears the desk
    col 5  handoff          idle + a sheet of paper held out
    col 6  chat             a different facing: turned to talk to a neighbour
    col 7  jump             idle, raised (the contact shadow stays on the floor)
    col 8  sad              idle with the head sunk onto the shoulders
    cols 9-14  walk         LimeZu's own six walk frames, in order (the real cycle:
                            the two big strides are frames 1 and 4, the other four
                            are the passing poses that give the body its bob).
                            Cols 0-8 are unchanged, so a 9-column sheet from before
                            this still plays: Actor falls back to the old 4-step
                            cycle when a sheet is only 9 wide.
  Rows are the game's: down, left, right, up. The pack has no front-facing seated
  pose, no mouths and no kid poses beyond idle/walk/sleep, so cols 4-8 are derived
  from the idle frames by small, deterministic edits -- the same approach for kids
  and adults, so every character has every pose.

PORTRAITS
    The HUD wants a 96x96 face (art/portrait_<name>.png). Modern UI's "Portrait
    Generator" supplies skins, eyes, hairstyles and accessories as 32x32 head
    portraits in a 10x3 grid of expressions. The head is 16 px wide, the same as a
    sprite's, so a 24x24 crop around it doubled twice is exactly 96x96. A character
    opts in with "portrait": {skin, eyes, hair, accessory}; the skin ids line up
    one-to-one with the adult Bodies.

RECOLOUR
    Skin and hair come in a few fixed colours (a kid has four skins and no black or
    blonde hair), so any layer may carry a "ramp": its fill colours are ranked by
    brightness and re-mapped, in order, onto a target ramp -- shading survives, the
    keyline (LimeZu's #3a3a50 family) and the soft hair shadows are untouched.
"""
import colorsys
import json
import os
import sys

from PIL import Image

import limezu

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")

CG = "2_Characters/Character_Generator/"
DIRS = ("right", "up", "left", "down")          # LimeZu's group order
GAME_ROWS = ("down", "left", "right", "up")     # Actor.DIR_DOWN / LEFT / RIGHT / UP
ROW_IDLE, ROW_WALK = 1, 2                       # row 0 is a 32px header of previews
CELL_H = 32
FRAME_W, FRAME_H = 16, 24                       # the game's cell, in art pixels
COLS = 15
WALK_FRAMES = 6                                 # LimeZu's walk row: 6 frames per direction

# LimeZu's keyline family. These (and fully transparent / soft-black shadow pixels)
# are never recoloured.
OUTLINE = {(0x3a, 0x3a, 0x50), (0x46, 0x46, 0x5e), (0x56, 0x59, 0x72), (0x6c, 0x59, 0x81)}
PAPER = (244, 242, 236)
PAPER_LINE = (150, 148, 160)
KEYLINE = (0x3a, 0x3a, 0x50)

KID_PARTS = {
    "body": ("Bodies_kids", "Body_%s_kid"),
    "eyes": ("Eyes_kids", "Eyes_kids_%s"),
    "outfit": ("Outfits_kids", "Outfit_kid_%s"),
    "hair": ("Hairstyles_kids", "Hairstyle_kid_%s"),
}
ADULT_PARTS = {
    "body": ("Bodies", "Body_%s"),
    "eyes": ("Eyes", "Eyes_%s"),
    "outfit": ("Outfits", "Outfit_%s"),
    "hair": ("Hairstyles", "Hairstyle_%s"),
    "accessory": ("Accessories", "Accessory_%s"),
}
ORDER = ("body", "eyes", "outfit", "hair", "accessory")


def part_member(kind, part, ident):
    folder, pattern = (KID_PARTS if kind == "kid" else ADULT_PARTS)[part]
    # ids are the file's own suffix: kid hair "3_3", adult outfit "05_01",
    # accessory "15_Glasses_02"
    return "%s%s/16x16/%s.png" % (CG, folder, pattern % str(ident))


# ---------------------------------------------------------------- recolour --

def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def ramp_recolor(im, ramp):
    """Re-map the fill colours of `im` onto `ramp` ([(r,g,b), ...] dark -> light)."""
    px = im.load()
    fills = set()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 255 and (r, g, b) not in OUTLINE:
                fills.add((r, g, b))
    if not fills:
        return im
    ranked = sorted(fills, key=lum)
    n = len(ranked)
    mapping = {}
    for i, c in enumerate(ranked):
        t = 0.0 if n == 1 else i / float(n - 1)
        pos = t * (len(ramp) - 1)
        lo = int(pos)
        hi = min(len(ramp) - 1, lo + 1)
        f = pos - lo
        mapping[c] = tuple(int(round(ramp[lo][k] * (1 - f) + ramp[hi][k] * f)) for k in range(3))
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 255 and (r, g, b) in mapping:
                nr, ng, nb = mapping[(r, g, b)]
                px[x, y] = (nr, ng, nb, 255)
    return im


def parse_ramp(r):
    return [limezu.parse_hex(c) for c in r]


def layer_image(pack, kind, part, entry, cast):
    """One layer of a character: {"id": "4"} plus optional "ramp" (a name from
    cast["ramps"] or a list of hex) and "hue" (degrees)."""
    if isinstance(entry, (str, int)):
        entry = {"id": entry}
    im = pack.image(part_member(kind, part, entry["id"]))
    ramp = entry.get("ramp")
    if ramp:
        ramp = cast["ramps"][ramp] if isinstance(ramp, str) else ramp
        im = ramp_recolor(im, parse_ramp(ramp))
    if entry.get("hue"):
        im = limezu.hue_shift(im, entry["hue"])
    return im


def compose(spec, cast, pack):
    kind = spec["kind"]
    if "premade" in spec:
        return pack.image("%s0_Premade_Characters/16x16/Premade_Character_%02d.png" % (CG, spec["premade"]))
    sheet = None
    for part in ORDER:
        if part not in spec:
            continue
        im = layer_image(pack, kind, part, spec[part], cast)
        if sheet is None:
            sheet = Image.new("RGBA", im.size, (0, 0, 0, 0))
        if im.width > sheet.width or im.height > sheet.height:
            grown = Image.new("RGBA", (max(sheet.width, im.width), max(sheet.height, im.height)), (0, 0, 0, 0))
            grown.alpha_composite(sheet)
            sheet = grown
        sheet.alpha_composite(im)
    return sheet


# ------------------------------------------------------------------ frames --

def lz_cell(sheet, row, d, k, per=6):
    """The 16x32 LimeZu cell: row (1 idle, 2 walk), direction index d, frame k."""
    col = d * per + k
    return sheet.crop((col * 16, row * CELL_H, col * 16 + 16, row * CELL_H + CELL_H))


def to_frame(cell, up=0):
    """16x32 cell -> the game's 16x24 frame, bottom-aligned; `up` raises the figure.

    Never raised past the top of the frame: the shift is capped at the figure's own
    headroom, so a hat or a head is not clipped to make room."""
    bb = cell.getbbox()
    top = bb[1] if bb else CELL_H
    headroom = max(0, top - (CELL_H - FRAME_H))
    up = min(up, headroom)
    # Look `up` rows lower in the cell than usual: the figure moves up in the frame.
    padded = Image.new("RGBA", (16, CELL_H * 2), (0, 0, 0, 0))
    padded.paste(cell, (0, 0))
    top_row = CELL_H - FRAME_H + up
    return padded.crop((0, top_row, 16, top_row + FRAME_H))


def droop(frame, rows=1):
    """Head sunk onto the shoulders: the top 14 figure-rows slide down `rows`."""
    bb = frame.getbbox()
    if not bb:
        return frame
    top = bb[1]
    cut = min(FRAME_H, top + 14)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    out.alpha_composite(frame.crop((0, cut, FRAME_W, FRAME_H)), (0, cut))     # body stays
    out.alpha_composite(frame.crop((0, top, FRAME_W, cut)), (0, top + rows))   # head sinks (draws over the neck)
    return out


def held_paper(frame, row_name):
    """A sheet of paper held out in front -- the handoff."""
    f = frame.copy()
    px = f.load()
    bb = f.getbbox()
    base = (bb[1] if bb else 6) + 11          # roughly chest height on a chibi
    cx = {"down": 8, "up": 12, "left": 4, "right": 12}[row_name]
    x0, y0 = cx - 2, base
    for dy in range(6):
        for dx in range(5):
            x, y = x0 + dx, y0 + dy
            if not (0 <= x < FRAME_W and 0 <= y < FRAME_H):
                continue
            edge = dx in (0, 4) or dy in (0, 5)
            if edge:
                px[x, y] = KEYLINE + (255,)
            else:
                px[x, y] = (PAPER_LINE if (dy in (2, 4) and dx in (1, 2, 3)) else PAPER) + (255,)
    return f


def build_frames(sheet, tuning):
    """-> {row_name: [15 frames of 16x24]} in the game's column order."""
    sit_up = tuning.get("sit_up", 3)
    jump_up = tuning.get("jump_up", 3)
    out = {}
    for row_name in GAME_ROWS:
        d = DIRS.index(row_name)
        stand = to_frame(lz_cell(sheet, ROW_IDLE, d, 0))
        step_a = to_frame(lz_cell(sheet, ROW_WALK, d, 1))
        step_b = to_frame(lz_cell(sheet, ROW_WALK, d, 4))
        sit = to_frame(lz_cell(sheet, ROW_IDLE, d, 0), up=sit_up)
        handoff = held_paper(stand, row_name)
        turned = "right" if row_name in ("down", "up") else "down"
        chat = to_frame(lz_cell(sheet, ROW_IDLE, DIRS.index(turned), 0))
        jump = to_frame(lz_cell(sheet, ROW_IDLE, d, 0), up=jump_up)
        sad = droop(stand)
        walk = [to_frame(lz_cell(sheet, ROW_WALK, d, k)) for k in range(WALK_FRAMES)]
        out[row_name] = [stand, step_a, stand, step_b, sit, handoff, chat, jump, sad] + walk
    return out


def bake(name, spec, cast, pack):
    sheet = compose(spec, cast, pack)
    frames = build_frames(sheet, spec.get("tune", {}))
    out = Image.new("RGBA", (COLS * FRAME_W * 2, 4 * FRAME_H * 2), (0, 0, 0, 0))
    for r, row_name in enumerate(GAME_ROWS):
        for c, fr in enumerate(frames[row_name]):
            out.alpha_composite(limezu.up2(fr), (c * FRAME_W * 2, r * FRAME_H * 2))
    return out


# ---------------------------------------------------------------- portraits --

PG = "16x16/Portrait_Generator/"
PG_PARTS = {
    "skin": ("Skins", "PG_Skin_%s"),
    "eyes": ("Eyes", "PG_Eyes_%s"),
    "hair": ("Hairstyles", "PG_Hairstyle_%s"),
    "accessory": ("Accessories", "PG_Accessory_%s"),
}
PG_ORDER = ("skin", "eyes", "hair", "accessory")
BUST = 24                # art pixels cropped round the head; x4 = the 96px bust


def portrait_layer(ui, part, entry, cast):
    if isinstance(entry, (str, int)):
        entry = {"id": entry}
    folder, pattern = PG_PARTS[part]
    im = ui.image("%s%s/%s.png" % (PG, folder, pattern % str(entry["id"])))
    ramp = entry.get("ramp")
    if ramp:
        ramp = cast["ramps"][ramp] if isinstance(ramp, str) else ramp
        im = ramp_recolor(im, parse_ramp(ramp))
    return im


def bake_portrait(spec, cast, ui, col=0, row=0):
    """The 96x96 face: expression (col,row) of a 10x3 portrait sheet, cropped and x4."""
    p = spec["portrait"]
    sheet = None
    for part in PG_ORDER:
        if part not in p:
            continue
        layer = portrait_layer(ui, part, p[part], cast)
        sheet = layer.copy() if sheet is None else sheet
        if layer is not sheet:
            sheet.alpha_composite(layer)
    face = sheet.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))
    bb = face.getbbox()
    cx = (bb[0] + bb[2]) // 2
    x0 = max(0, min(32 - BUST, cx - BUST // 2))
    y0 = max(0, min(32 - BUST, bb[1] - 1))     # head top ~4px down, where the old busts had theirs
    out = face.crop((x0, y0, x0 + BUST, y0 + BUST))
    return out.resize((BUST * 4, BUST * 4), Image.NEAREST)


# --------------------------------------------------------------------- CLI --

def same(a, b):
    return limezu.same_pixels(a, b)


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    names = [a for a in argv if not a.startswith("--") and not a.endswith(".png")]
    cast = limezu.load_cast()
    chars = cast.get("characters", {})
    todo = [n for n in chars if not names or n in names]
    if names and set(names) - set(chars):
        sys.exit("not in limezu_cast.json: %s" % ", ".join(sorted(set(names) - set(chars))))

    if "--list" in flags:
        for n in todo:
            print("%-12s %s" % (n, json.dumps({k: v for k, v in chars[n].items() if k != "why"})))
        return 0

    pack = limezu.need_pack("interiors")
    if "--preview" in flags:
        out = [a for a in argv if a.endswith(".png")][0]
        S = 4
        tiles = []
        for n in todo:
            sheet = bake(n, chars[n], cast, pack)
            tiles.append((n, sheet))
        W = COLS * 32 * S
        H = sum(4 * 48 * S + 14 for _ in tiles)
        canvas = Image.new("RGBA", (W, H), (118, 118, 132, 255))
        from PIL import ImageDraw
        d = ImageDraw.Draw(canvas)
        y = 0
        for n, sheet in tiles:
            d.text((4, y), n, fill=(255, 255, 200))
            canvas.alpha_composite(sheet.resize((sheet.width * S, sheet.height * S), Image.NEAREST), (0, y + 14))
            y += 4 * 48 * S + 14
        canvas.convert("RGB").save(out)
        print("preview ->", out)
        return 0

    check = "--check" in flags
    wrote = bad = 0
    ui = limezu.need_pack("ui") if any(isinstance(chars[n].get("portrait"), dict) for n in todo) else None
    for n in todo:
        outputs = [(n, bake(n, chars[n], cast, pack))]
        if isinstance(chars[n].get("portrait"), dict):
            outputs.append(("portrait_" + n, bake_portrait(chars[n], cast, ui)))
        for out_name, img in outputs:
            path = os.path.join(ART, out_name + ".png")
            have = Image.open(path).convert("RGBA") if os.path.exists(path) else None
            if have is not None and same(have, img):
                continue
            if check:
                bad += 1
                print("DIFFERS  %s" % out_name)
                continue
            hand = os.path.join(ROOT, "tools", "sprites", out_name + ".txt")
            if os.path.exists(hand):
                sys.exit("%s has a hand-drawn source (tools/sprites/%s.txt); move it aside first." % (out_name, out_name))
            img.save(path)
            wrote += 1
            print("art/%-24s %dx%d" % (out_name + ".png", img.width, img.height))
    print("%d baked%s" % (wrote, (", %d differ" % bad) if check else ""))
    if wrote:
        print("Godot cannot load new or changed PNGs until:  godot --headless --path . --import")
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
