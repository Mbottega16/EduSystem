"""Browse the LimeZu packs as labelled contact sheets -- the ids are the ones the
manifest and the cast file use, so what you see is what you can paste.

    python tools/limezu_catalog.py themes                 every prop theme and how many singles
    python tools/limezu_catalog.py props classroom        sheets of classroom#1, #2, ...
    python tools/limezu_catalog.py props office           the Modern Office singles
    python tools/limezu_catalog.py kids                   kid skins, eyes, outfits, hair (cast ids)
    python tools/limezu_catalog.py adults                 adult skins, eyes, hair (all colours), outfits (all colours)
    python tools/limezu_catalog.py accessories            hats, glasses, beards, backpacks ...
    python tools/limezu_catalog.py portraits              Portrait Generator skins, eyes, hair
    python tools/limezu_catalog.py animated               the first frame of every animated object
    python tools/limezu_catalog.py ui                     the UI sheet with a 16px grid (for sheet+rect cuts)
    python tools/limezu_catalog.py room                   the Room Builder floors and walls with tile coords

Sheets land in shots/catalog/ (gitignored). Each sprite is drawn at 3x on a grey
ground with its id above it. `props` is chunked (--chunk N sprites per sheet,
default 90) so a theme of 500 is five sheets, not one unreadable one.

A prop id like `classroom#26` goes in tools/limezu_manifest.json as "ref"; a kid id
like `3_3` (hair) or `4` (body) and an adult id like `05_02` (outfit) go in
tools/limezu_cast.json. Everything is read from the 16x16 folders.
"""
import io
import os
import re
import sys

from PIL import Image, ImageDraw

import limezu

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "shots", "catalog")
CG = "2_Characters/Character_Generator/"
GREY = (120, 120, 135)


def natkey(s):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]


def flow(items, out, scale=3, width=1700, pad=4, label_h=11):
    """items: [(label, RGBA image)] -> a shelf-packed sheet saved to `out`."""
    placed, x, y, rowh = [], 0, 0, 0
    for label, im in items:
        w = max(im.width * scale + pad * 2, 8 * len(str(label)) // 2 + 8)
        h = im.height * scale + pad * 2 + label_h
        if x + w > width:
            x, y, rowh = 0, y + rowh, 0
        placed.append((x, y, w, h))
        x += w
        rowh = max(rowh, h)
    sheet = Image.new("RGBA", (width, y + rowh), GREY + (255,))
    d = ImageDraw.Draw(sheet)
    for (label, im), (px, py, w, h) in zip(items, placed):
        d.rectangle([px, py, px + w - 1, py + h - 1], outline=(95, 95, 110))
        d.text((px + 2, py + 1), str(label), fill=(255, 255, 200))
        sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST),
                              (px + pad, py + pad + label_h))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.convert("RGB").save(out)
    print("  ", os.path.relpath(out, ROOT), "(%d sprites)" % len(items))


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield i // n, seq[i:i + n]


def theme_items(m, key):
    theme = m["themes"][key]
    pack = limezu.need_pack(theme["pack"])
    files = limezu._theme_files(pack, theme)
    return [(n, pack.image(files[n])) for n in sorted(files)]


def cmd_themes(m, argv):
    for key, theme in m["themes"].items():
        pack = limezu.find_pack(theme["pack"])
        n = len(limezu._theme_files(pack, theme)) if pack else "pack not found"
        print("  %-12s %-6s %s" % (key, n, theme["dir"]))


def cmd_props(m, argv):
    key = argv[0]
    chunk = int(argv[argv.index("--chunk") + 1]) if "--chunk" in argv else 90
    items = [("%s#%d" % (key, n), im) for n, im in theme_items(m, key)]
    for i, part in chunks(items, chunk):
        flow(part, os.path.join(OUT, "props_%s_%d.png" % (key, i)))


def part_sheet_cell(sheet, col=18, row=1):
    """The down-facing idle frame of a LimeZu character sheet, cropped to the game's 16x24."""
    return sheet.crop((col * 16, row * 32 + 8, col * 16 + 16, row * 32 + 32))


def cmd_kids(m, argv):
    pack = limezu.need_pack("interiors")
    base = None
    items = []
    for i in range(1, 5):
        items.append(("body %d" % i, part_sheet_cell(pack.image("%sBodies_kids/16x16/Body_%d_kid.png" % (CG, i)))))
    body = pack.image("%sBodies_kids/16x16/Body_2_kid.png" % CG)
    for i in range(1, 7):
        c = part_sheet_cell(body)
        c.alpha_composite(part_sheet_cell(pack.image("%sEyes_kids/16x16/Eyes_kids_%d.png" % (CG, i))))
        items.append(("eyes %d" % i, c))
    names = sorted(n for n in pack.names() if n.startswith(CG + "Outfits_kids/16x16/") and n.endswith(".png"))
    for n in names:
        c = part_sheet_cell(body)
        c.alpha_composite(part_sheet_cell(pack.image(n)))
        items.append(("outfit " + os.path.basename(n)[len("Outfit_kid_"):-4], c))
    names = sorted((n for n in pack.names() if n.startswith(CG + "Hairstyles_kids/16x16/") and n.endswith(".png")), key=natkey)
    for n in names:
        c = part_sheet_cell(body)
        c.alpha_composite(part_sheet_cell(pack.image(n)))
        items.append(("hair " + os.path.basename(n)[len("Hairstyle_kid_"):-4], c))
    flow(items, os.path.join(OUT, "kids.png"), scale=5)


def cmd_adults(m, argv):
    pack = limezu.need_pack("interiors")
    body = part_sheet_cell(pack.image("%sBodies/16x16/Body_03.png" % CG))
    body.alpha_composite(part_sheet_cell(pack.image("%sEyes/16x16/Eyes_06.png" % CG)))
    bodies = [("body %02d" % i, part_sheet_cell(pack.image("%sBodies/16x16/Body_%02d.png" % (CG, i)))) for i in range(1, 10)]
    eyes = []
    for i in range(1, 8):
        c = part_sheet_cell(pack.image("%sBodies/16x16/Body_03.png" % CG))
        c.alpha_composite(part_sheet_cell(pack.image("%sEyes/16x16/Eyes_%02d.png" % (CG, i))))
        eyes.append(("eyes %02d" % i, c))
    flow(bodies + eyes, os.path.join(OUT, "adults_bodies_eyes.png"), scale=4)
    for kind, label in (("Hairstyles", "Hairstyle_"), ("Outfits", "Outfit_")):
        names = sorted((n for n in pack.names() if n.startswith("%s%s/16x16/" % (CG, kind)) and n.endswith(".png")), key=natkey)
        items = []
        for n in names:
            c = body.copy()
            layer = part_sheet_cell(pack.image(n))
            c.alpha_composite(layer)
            items.append((os.path.basename(n)[len(label):-4], c))
        for i, part in chunks(items, 110):
            flow(part, os.path.join(OUT, "adults_%s_%d.png" % (kind.lower(), i)), scale=3, pad=2)


def cmd_accessories(m, argv):
    pack = limezu.need_pack("interiors")
    body = part_sheet_cell(pack.image("%sBodies/16x16/Body_03.png" % CG))
    names = sorted((n for n in pack.names() if n.startswith(CG + "Accessories/16x16/") and n.endswith(".png")), key=natkey)
    items = []
    for n in names:
        c = body.copy()
        c.alpha_composite(part_sheet_cell(pack.image(n)))
        items.append((os.path.basename(n)[len("Accessory_"):-4], c))
    for i, part in chunks(items, 60):
        flow(part, os.path.join(OUT, "accessories_%d.png" % i), scale=4, pad=2)


def cmd_portraits(m, argv):
    ui = limezu.need_pack("ui")
    pg = "16x16/Portrait_Generator/"
    def cell(path):
        return ui.image(path).crop((0, 0, 32, 32))
    skin = cell(pg + "Skins/PG_Skin_3.png")
    skins = [("skin %d" % i, cell(pg + "Skins/PG_Skin_%d.png" % i)) for i in range(1, 10)]
    eyes = []
    for i in range(1, 8):
        c = skin.copy()
        c.alpha_composite(cell(pg + "Eyes/PG_Eyes_%02d.png" % i))
        eyes.append(("eyes %02d" % i, c))
    flow(skins + eyes, os.path.join(OUT, "portraits_skins_eyes.png"), scale=4)
    base = skin.copy()
    base.alpha_composite(cell(pg + "Eyes/PG_Eyes_06.png"))
    names = sorted((n for n in ui.names() if n.startswith(pg + "Hairstyles/") and n.endswith(".png")), key=natkey)
    items = []
    for n in names:
        c = base.copy()
        c.alpha_composite(cell(n))
        items.append((os.path.basename(n)[len("PG_Hairstyle_"):-4], c))
    for i, part in chunks(items, 110):
        flow(part, os.path.join(OUT, "portraits_hair_%d.png" % i), scale=3, pad=2)


def cmd_animated(m, argv):
    pack = limezu.need_pack("interiors")
    base = "3_Animated_objects/16x16/spritesheets/"
    names = sorted(n for n in pack.names() if n.startswith(base) and n.endswith(".png"))
    items = []
    for n in names:
        im = pack.image(n)
        h = im.height
        # frames are laid side by side; show the first, and say how many there are
        frames = max(1, im.width // h) if h else 1
        items.append(("%s [%d f]" % (os.path.basename(n)[len("animated_"):-4][:30], frames), im.crop((0, 0, min(h, im.width), h))))
    for i, part in chunks(items, 80):
        flow(part, os.path.join(OUT, "animated_%d.png" % i), scale=3)
    print("  (an animated sheet is `sheet` + `rect` [0, 0, frame_w, frame_h] in the manifest; the label's [N f] guesses frames as width/height)")


def grid_sheet(im, out, scale, label_every=1):
    bg = Image.new("RGBA", im.size, GREY + (255,))
    bg.alpha_composite(im)
    big = bg.resize((im.width * scale, im.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for tx in range(im.width // 16 + 1):
        d.line([(tx * 16 * scale, 0), (tx * 16 * scale, big.height)], fill=(255, 255, 255, 50))
        if tx % label_every == 0:
            d.text((tx * 16 * scale + 2, 1), str(tx), fill=(0, 255, 255))
    for ty in range(im.height // 16 + 1):
        d.line([(0, ty * 16 * scale), (big.width, ty * 16 * scale)], fill=(255, 255, 255, 50))
        if ty % label_every == 0:
            d.text((1, ty * 16 * scale + 1), str(ty), fill=(255, 255, 0))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    big.convert("RGB").save(out)
    print("  ", os.path.relpath(out, ROOT), big.size)


def cmd_ui(m, argv):
    pack = limezu.need_pack("interiors")
    grid_sheet(pack.image("4_User_Interface_Elements/UI_16x16.png"), os.path.join(OUT, "ui.png"), 4)
    grid_sheet(pack.image("4_User_Interface_Elements/UI_thinking_emotes_animation_16x16.png"), os.path.join(OUT, "ui_emotes.png"), 4)
    ui = limezu.find_pack("ui")
    if ui:
        for name in ("Modern_UI_Style_1", "Modern_UI_Style_2", "Modern_UI_Gamepad"):
            p = "16x16/%s.png" % name
            if ui.has(p):
                grid_sheet(ui.image(p), os.path.join(OUT, "ui_%s.png" % name.lower()), 2, label_every=2)
    print("  (cell coords x, y are 16px tiles; a cut is rect [x*16, y*16, w, h] -- measure the real bounds with Image.getbbox())")


def cmd_room(m, argv):
    pack = limezu.need_pack("interiors")
    rb = "1_Interiors/16x16/Room_Builder_subfiles/"
    grid_sheet(pack.image(rb + "Room_Builder_Floors_16x16.png"), os.path.join(OUT, "room_floors.png"), 3)
    grid_sheet(pack.image(rb + "Room_Builder_Walls_16x16.png"), os.path.join(OUT, "room_walls.png"), 3)
    grid_sheet(pack.image("1_Interiors/16x16/Theme_Sorter_Shadowless/1_Generic_Shadowless.png"),
               os.path.join(OUT, "generic_sheet.png"), 3, label_every=2)
    print("  (limezu_room.json: floor.block / wall.set are the top-left TILE of a 3x2 block; door/window rects are pixels in the Generic sheet)")


COMMANDS = {"themes": cmd_themes, "props": cmd_props, "kids": cmd_kids, "adults": cmd_adults,
            "accessories": cmd_accessories, "portraits": cmd_portraits, "animated": cmd_animated,
            "ui": cmd_ui, "room": cmd_room}


def main(argv):
    if not argv or argv[0] not in COMMANDS or (argv[0] == "props" and len(argv) < 2):
        print(__doc__)
        return 2
    m = limezu.load_manifest()
    COMMANDS[argv[0]](m, argv[1:])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
