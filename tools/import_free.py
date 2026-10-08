"""Import sprites from the FREE art packs into art/ -- tools/free_manifest.json is the record.

    python tools/import_free.py                 build everything in the manifest
    python tools/import_free.py rocking_chair   just those names
    python tools/import_free.py --list          what is owned, from which pack, under what licence
    python tools/import_free.py --check         no writes: are the packs here, is every PNG what
                                                the manifest builds

The sibling of import_limezu.py for art that is NOT LimeZu's (Oct 2026: the owner asked for
every free pack that fits, to phase out the last procedural sprites and to give the room more
that moves). Same rules as LimeZu art:

  * THE PACKS STAY OUT OF THE REPO. Some forbid redistribution (the Midcentury furniture set),
    so none is committed; only the finished sprites are. A pack is found at
    <search dir>/<"find"> for each search dir in: $FREE_ART_DIR, the first line of
    tools/free_art_path.txt (untracked, per machine), then the same Desktop / Downloads
    folders tools/limezu.py searches.
  * EVERY NAME HERE IS OWNED. limezu.owned_names() unions this manifest in, so make_art.py,
    make_items.py and the forges stand down for these names, exactly as for a LimeZu one.
  * THE CREDIT IS RECORDED per pack, with its licence, and the credits page carries it.

HOW A SPRITE IS BUILT, so it sits in a LimeZu room
    cut "rect" ([x, y, w, h], frame 0; an animated sprite's frames sit side by side) out of the
    pack's "member" (or the pack file itself, for a loose PNG) ->
    a 32px-density pack is HALVED (box filter) onto the room's 16-art-px grid, then snapped to
    LimeZu's palette with its dark edge recoloured to his keyline ("outline": "conform");
    a 16px pack keeps its own colours and only has its near-black recoloured to the keyline
    ("outline": "keyline") -- snapping a saturated pack to LimeZu's palette turned a flag's pole
    magenta, so it is not done -> trim transparent rows (an animated strip by the union of its
    frames, so every frame lines up) -> double with NEAREST -> art/<name>.png, and for an
    animated one the strip too, art/<name>_anim.png, which data/balance.json's `anim` names.
"""
import io
import json
import os
import sys
import zipfile

from PIL import Image

import limezu
import lz_conform

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
ART = os.path.join(ROOT, "art")
SPRITES = os.path.join(TOOLS, "sprites")
ARCHIVE = os.path.join(SPRITES, "_replaced_by_free")
MANIFEST = os.path.join(TOOLS, "free_manifest.json")


def load_manifest():
    with io.open(MANIFEST, encoding="utf-8") as fh:
        return json.load(fh)


def search_dirs():
    out = []
    env = os.environ.get("FREE_ART_DIR")
    if env:
        out.append(env)
    f = os.path.join(TOOLS, "free_art_path.txt")
    if os.path.exists(f):
        with io.open(f, encoding="utf-8") as fh:
            first = fh.readline().strip()
        if first:
            out.append(first)
    out.extend(limezu.search_dirs())
    return [d for d in out if os.path.isdir(d)]


_found = {}


def find_pack(key, manifest):
    if key in _found:
        return _found[key]
    rel = manifest["packs"][key]["find"]
    hit = None
    for d in search_dirs():
        for cand in (os.path.join(d, rel), os.path.join(d, os.path.basename(rel))):
            if os.path.exists(cand):
                hit = cand
                break
        if hit:
            break
    _found[key] = hit
    return hit


def need_pack(key, manifest):
    p = find_pack(key, manifest)
    if p is None:
        raise SystemExit("Could not find the free pack '%s' (%s) under any of: %s\n"
                         "Download it from %s, or write its folder into tools/free_art_path.txt."
                         % (key, manifest["packs"][key]["find"], ", ".join(search_dirs()),
                            manifest["packs"][key].get("url", "its page")))
    return p


_images = {}


def pack_image(key, member, manifest):
    """One image out of a pack: a zip member (under the pack's "root"), or the file itself."""
    where = need_pack(key, manifest)
    k = (where, member)
    if k not in _images:
        if where.lower().endswith(".zip"):
            root = manifest["packs"][key].get("root", "")
            with zipfile.ZipFile(where) as z:
                _images[k] = Image.open(io.BytesIO(z.read(root + member))).convert("RGBA")
        else:
            _images[k] = Image.open(where).convert("RGBA")
    return _images[k].copy()


def keyline_dark(im):
    """Near-black -> LimeZu's keyline #3a3a50. Colours otherwise untouched."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and lz_conform._lum((r, g, b)) < 40:
                px[x, y] = lz_conform.KEYLINE + (a,)
    return im


def to_room(im, pack):
    """One frame, cut out of its pack -> art pixels on the room's 16px grid, LimeZu-toned."""
    if int(pack.get("density", 16)) == 32:
        im = im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.BOX)
    if pack.get("outline") == "conform":
        im = lz_conform.snap(im, lz_conform.load_palette())
        if lz_conform.already_outlined(im):
            im = lz_conform.recolor_outline(im)
    else:
        alpha = im.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        im.putalpha(alpha)
        im = keyline_dark(im)
    return im


def build(name, manifest):
    """-> (still art at game scale, animation strip at game scale or None)."""
    spec = manifest["props"][name]
    pack = manifest["packs"][spec["pack"]]
    sheet = pack_image(spec["pack"], spec.get("member", ""), manifest)
    x, y, w, h = spec["rect"]
    n = int(spec.get("anim", {}).get("frames", 1))
    frames = [to_room(sheet.crop((x + i * w, y, x + (i + 1) * w, y + h)), pack) for i in range(n)]
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    top = min(b[1] for b in boxes)
    bottom = max(b[3] for b in boxes)
    frames = [f.crop((0, top, f.width, bottom)) for f in frames]
    still = limezu.up2(frames[0])
    if n == 1:
        return still, None
    strip = Image.new("RGBA", (frames[0].width * n, frames[0].height), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * f.width, 0))
    return still, limezu.up2(strip)


def balance_problems(name, spec):
    with io.open(os.path.join(ROOT, "data", "balance.json"), encoding="utf-8") as fh:
        items = json.load(fh)["items"]
    out = []
    for k, v in items.items():
        if v.get("art", k) != name:
            continue
        a = v.get("anim")
        if "anim" in spec:
            if not a or a.get("art") != name + "_anim" or int(a.get("frames", 0)) != int(spec["anim"]["frames"]):
                out.append("%s: balance.json anim %s does not match the manifest (%s_anim, %s frames)"
                           % (k, a, name, spec["anim"]["frames"]))
        elif a:
            out.append("%s: balance.json animates %s but the manifest does not" % (k, name))
    return out


def archive_hand_source(name):
    src = os.path.join(SPRITES, name + ".txt")
    if not os.path.exists(src):
        return None
    os.makedirs(ARCHIVE, exist_ok=True)
    dst = os.path.join(ARCHIVE, name + ".txt")
    os.replace(src, dst)
    return dst


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    names = [a for a in argv if not a.startswith("--")]
    manifest = load_manifest()
    todo = [n for n in manifest["props"] if not names or n in names]
    if set(names) - set(todo):
        sys.exit("not in the manifest: %s" % ", ".join(sorted(set(names) - set(todo))))
    if "--list" in flags:
        for n in todo:
            spec = manifest["props"][n]
            pack = manifest["packs"][spec["pack"]]
            print("%-16s %-11s %s" % (n, spec["pack"], pack["licence"]))
        print("\n%d sprites owned by the free-pack importer" % len(todo))
        return 0
    check = "--check" in flags
    wrote = same = bad = 0
    for n in todo:
        spec = manifest["props"][n]
        still, strip = build(n, manifest)
        # A particle is only ever played, never stood in the room, so it has no
        # still picture to keep -- just the strip ("strip_only").
        if spec.get("strip_only"):
            still = None
        for out_name, img in ((n, still), (n + "_anim", strip)):
            if img is None:
                continue
            path = os.path.join(ART, out_name + ".png")
            have = Image.open(path).convert("RGBA") if os.path.exists(path) else None
            if have is not None and limezu.same_pixels(have, img):
                same += 1
                continue
            if check:
                bad += 1
                print("DIFFERS  %s" % out_name)
                continue
            moved = archive_hand_source(out_name)
            img.save(path)
            wrote += 1
            print("art/%-20s %3dx%-3d <- %s%s" % (out_name + ".png", img.width, img.height, spec["pack"],
                                                 ("  (hand source archived)" if moved else "")))
        for problem in balance_problems(n, spec):
            bad += 1
            print("  !! " + problem)
    print("\n%d written, %d already up to date%s" % (wrote, same, (", %d differ" % bad) if check else ""))
    if wrote:
        print("Godot cannot load new or changed PNGs until:  godot --headless --path . --import")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
