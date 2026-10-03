"""Import LimeZu props and room tiles into art/ -- the manifest is the record.

    python tools/import_limezu.py                 build everything in the manifest
    python tools/import_limezu.py desk chair      just those names
    python tools/import_limezu.py --list          what is owned, from where, how big
    python tools/import_limezu.py --check         no writes: are sources reachable,
                                                  is every PNG what the manifest says

Every sprite named in tools/limezu_manifest.json ("props", "tiles") is OWNED by
this importer: make_art.py, make_items.py and forge_art.py stand down for it
(limezu.owned_names() is unioned into make_art.hand_edited()), exactly as they
do for a hand-drawn tools/sprites/<name>.txt. People (characters, portraits)
are the other importer's job -- limezu_chars.py.

HOW A SPRITE IS BUILT
    fetch from the pack (16x16 folder, shadowless singles -- the game casts its
    own contact shadow, so a baked one would double up) -> optional crop / flip
    / recolour -> trim transparent rows top and bottom -> double with NEAREST ->
    art/<name>.png. The game anchors a prop by its BOTTOM edge, so the trim is
    what puts a LimeZu object's feet on the tile's bottom edge.

WHAT IT WILL NOT DO
    Overwrite a sprite someone has hand-edited since (tools/sprites/<name>.txt
    that is NOT the one this importer archived) -- pass --force for that. And it
    never touches the packs: they are read-only, and never copied into the repo.

When it takes over a name that already had a hand source, the old .txt is MOVED
to tools/sprites/_replaced_by_limezu/ (archived, never deleted), because the
suite insists every live .txt matches its PNG's dimensions.
"""
import os
import sys

from PIL import Image

import limezu

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
SPRITES = os.path.join(ROOT, "tools", "sprites")
ARCHIVE = os.path.join(SPRITES, "_replaced_by_limezu")


def source_label(spec):
    if "ref" in spec:
        return spec["ref"]
    if "join" in spec:
        return "+".join(spec["join"])
    return spec.get("sheet", "?").split("/")[-1]


def entries(manifest):
    out = []
    for section in ("props", "tiles"):
        for name, spec in manifest.get(section, {}).items():
            out.append((section, name, spec))
    return out


def build(section, name, manifest):
    spec = manifest[section][name]
    return limezu.build_prop(spec, manifest)


def same_image(a, b):
    return limezu.same_pixels(a, b)


def archive_hand_source(name, force):
    src = os.path.join(SPRITES, name + ".txt")
    if not os.path.exists(src):
        return None
    os.makedirs(ARCHIVE, exist_ok=True)
    dst = os.path.join(ARCHIVE, name + ".txt")
    if os.path.exists(dst) and not force:
        sys.exit("%s was hand-edited again after the importer archived the old source "
                 "(tools/sprites/%s.txt exists next to its archived copy).\n"
                 "Keep the new hand edit and delete its manifest entry, or pass --force "
                 "to archive it and re-import." % (name, name))
    os.replace(src, dst)
    return dst


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    names = [a for a in argv if not a.startswith("--")]
    manifest = limezu.load_manifest()
    todo = [e for e in entries(manifest) if not names or e[1] in names]
    if names:
        unknown = set(names) - set(e[1] for e in todo)
        if unknown:
            sys.exit("not in the manifest: %s" % ", ".join(sorted(unknown)))

    if "--list" in flags:
        for section, name, spec in todo:
            p = os.path.join(ART, name + ".png")
            size = Image.open(p).size if os.path.exists(p) else None
            print("%-22s %-7s %-18s %s" % (name, section, source_label(spec), size))
        print("\n%d sprites owned by the LimeZu importer" % len(todo))
        return 0

    check = "--check" in flags
    force = "--force" in flags
    wrote = same = bad = 0
    for section, name, spec in todo:
        img = build(section, name, manifest)
        path = os.path.join(ART, name + ".png")
        have = Image.open(path).convert("RGBA") if os.path.exists(path) else None
        if have is not None and same_image(have, img):
            same += 1
            continue
        if check:
            bad += 1
            print("DIFFERS  %-22s (art/%s.png is %s, the manifest builds %s)"
                  % (name, name, have.size if have else "missing", img.size))
            continue
        moved = archive_hand_source(name, force)
        img.save(path)
        wrote += 1
        print("art/%-22s %3dx%-3d  <- %-14s%s" % (
            name + ".png", img.width, img.height, source_label(spec),
            ("   (hand source archived: %s)" % os.path.relpath(moved, ROOT)) if moved else ""))
    print("\n%d written, %d already up to date%s" % (wrote, same, ("" if not check else ", %d differ" % bad)))
    if wrote:
        print("Godot cannot load new or changed PNGs until:  godot --headless --path . --import")
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
