import json
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import make_items

def parse_val(v):
    if v.lower() == "true": return True
    if v.lower() == "false": return False
    if v.startswith("#"):
        v = v.lstrip("#")
        return tuple(int(v[i:i+2], 16) for i in (0, 2, 4))
    if "," in v:
        try:
            return tuple(int(x.strip()) for x in v.split(","))
        except ValueError:
            pass
    return v


def _hand_owned(name):
    return os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                       "sprites", name + ".txt"))


def _limezu_owned(name):
    """A sprite imported from the LimeZu packs (tools/limezu_*.json) belongs to its importer."""
    try:
        import limezu
        return name in limezu.owned_names()
    except ImportError:
        return False


def _hand_guard(name, force):
    """Refuse to overwrite a hand-drawn OR a LimeZu-imported sprite, the same
    way forge_art.py does. Added after this tool silently flattened
    art/stool.png back to its generator output -- tools/sprites/stool.txt had
    owned that sprite for weeks and nothing here was looking; and extended when
    LimeZu art arrived, because this tool would otherwise paint straight over an
    imported prop with no hand source to warn it off."""
    if _limezu_owned(name) and not _hand_owned(name):
        if not force:
            sys.exit("%s comes from the LimeZu packs (tools/limezu_manifest.json). Change which "
                     "sprite it uses there and run import_limezu.py, or pass --force for a "
                     "throwaway override." % name)
        print("  NOTE: %s is LimeZu-owned. The next import_limezu.py run reverts what you just wrote." % name)
        return
    if not _hand_owned(name):
        return
    if not force:
        sys.exit("%s is hand-edited (tools/sprites/%s.txt). Edit it in "
                 "Browse Art.bat, or pass --force for a throwaway override."
                 % (name, name))
    print("  NOTE: tools/sprites/%s.txt still owns this sprite. The next "
          "`python tools/make_art.py` reverts what you just wrote." % name)


def main():
    if len(sys.argv) < 2:
        print("Usage: python forge_items.py <item_name> [COLOR=#hex]")
        sys.exit(1)

    item_name = sys.argv[1]
    if item_name == "list":
        # The Master Forge's Items tab reads this to fill its dropdown, so
        # nobody has to remember whether it is "fish_tank" or "fishtank".
        for n in sorted(list(make_items.ITEMS) + list(make_items.MESS_ITEMS)):
            print(n)
        return
    
    force = "--force" in sys.argv[2:]
    _hand_guard(item_name, force)

    for arg in sys.argv[2:]:
        if "=" in arg:
            k, v = arg.split("=", 1)
            parsed = parse_val(v)
            setattr(make_items, k, parsed)
            print(f"Set {k} = {parsed}")
            
            # Save to palette.json
            pal_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'palette.json')
            if os.path.exists(pal_path):
                with open(pal_path, 'r') as pf:
                    pal_data = json.load(pf)
                pal_data[k] = list(parsed) if isinstance(parsed, tuple) else parsed
                with open(pal_path, 'w') as pf:
                    json.dump(pal_data, pf, indent=4)
            
    import make_art
    func = make_items.ITEMS.get(item_name) or make_items.MESS_ITEMS.get(item_name)
    if not func:
        print(f"Unknown item: {item_name}")
        sys.exit(1)
        
    img = make_art.scale2x(func())
    png_path = os.path.join(make_art.OUT, f"{item_name}.png")
    img.save(png_path)
    print(f"Successfully forged art/{item_name}.png")

if __name__ == "__main__":
    main()
