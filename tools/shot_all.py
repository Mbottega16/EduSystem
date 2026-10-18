"""Screenshot every named screen of the REAL game, then compare two runs -- Windows, Mac, Linux.

    python tools/shot_all.py shoot before                 shoot every screen into shots/before/
    python tools/shot_all.py shoot after day teaching     just these screens into shots/after/
    python tools/shot_all.py compare before after         side-by-side sheets: shots/compare_before_after_N.png
    python tools/shot_all.py list                         the screens

Why a tool and not the .bat: an art pass has to be judged on the whole game, before AND
after, and `Take a Screenshot.bat` does one screen per double-click. Two traps this
tool removes:
  * the screenshot harness works on a scratch save (user://edusystem_SHOT_save.json) that
    persists between runs, so "day 1" in one shot is "day 6" in the next unless that file
    is deleted first -- this deletes it before EVERY shot, so a run is deterministic;
  * Godot instances must never overlap (they kill each other), so it is strictly serial.

Godot is found via $GODOT, then tools/godot_path.txt (the Windows path the .bat files
use), then the usual macOS spots, then `godot` on PATH. A screenshot needs a window --
this is NOT headless -- so a window will flash up for each shot.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "shots")

SCREENS = """day teaching dev_room dev_room_bare student shop hand quiz class_list curriculum career alumni
staff craft at_board at_bell title inspection inspector_here noise run_over new_term exam dashboard
dashboard_items dashboard_skills dashboard_wardrobe marking marking_stamp ads weather hallway door office
principal consumables mess mess_janitor hat hat_bow hat_wizard hat_mortarboard auto_teach consumables_report
intro intro_walk intro_line term_paths desk_interruption mentor mentor_demo mentor_chain boss_fight
fight_report skip skip_report school watch hiring unit_test specialism hand_shuffle staff_scrolled
boot_title room ideas ideas_science ideas_explorers ideas_calm birthday
desk_cold_snap desk_book_fair chatter chatter_build chatter_file
folder folder_place folder_shop grade_book grade_book_empty at_desk help_sheet
grade_book_register at_curriculum butterfly_out butterfly_in""".split()


def godot():
    env = os.environ.get("GODOT")
    if env and os.path.exists(env):
        return env
    f = os.path.join(ROOT, "tools", "godot_path.txt")
    if os.path.exists(f):
        with open(f, encoding="utf-8") as fh:
            p = fh.readline().strip()
        if p and os.path.exists(p):
            return p
    home = os.path.expanduser("~")
    for p in (os.path.join(home, "Applications", "Godot.app", "Contents", "MacOS", "Godot"),
              "/Applications/Godot.app/Contents/MacOS/Godot"):
        if os.path.exists(p):
            return p
    return "godot"


def scratch_save():
    name = "edusystem_SHOT_save.json"
    if sys.platform.startswith("win"):
        base = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "EDUSystem")
    elif sys.platform == "darwin":
        base = os.path.join(os.path.expanduser("~"), "Library", "Application Support", "Godot", "app_userdata", "EDUSystem")
    else:
        base = os.path.join(os.path.expanduser("~"), ".local", "share", "godot", "app_userdata", "EDUSystem")
    return os.path.join(base, name)


def shoot(label, screens):
    out = os.path.join(SHOTS, label)
    os.makedirs(out, exist_ok=True)
    exe = godot()
    save = scratch_save()
    failed = []
    for i, s in enumerate(screens, 1):
        if os.path.exists(save):
            os.remove(save)
        path = os.path.join(out, s + ".png")
        # Small and off-screen from the first frame (--position/--resolution
        # are read before the window opens), so a 70-screen run does not
        # throw a full-screen window in front of whoever is working nearby.
        cmd = [exe, "--position", "-6000,-6000", "--resolution", "640x352",
               "--path", ROOT, "res://tools/shot.tscn", "--", path, "90", "640", "352", "0", s]
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        ok = os.path.exists(path)
        if not ok:
            failed.append(s)
        errs = [ln for ln in r.stdout.splitlines() if "SCRIPT ERROR" in ln or "Parse Error" in ln]
        print("[%2d/%d] %-22s %s%s" % (i, len(screens), s, "ok" if ok else "NO IMAGE", ("   !! " + errs[0][:90]) if errs else ""))
    print("%d shot(s) in %s%s" % (len(screens) - len(failed), os.path.relpath(out, ROOT),
                                  ("; missing: " + ", ".join(failed)) if failed else ""))
    return 1 if failed else 0


def compare(a, b):
    from PIL import Image, ImageDraw
    da, db = os.path.join(SHOTS, a), os.path.join(SHOTS, b)
    names = sorted(f[:-4] for f in os.listdir(db) if f.endswith(".png") and os.path.exists(os.path.join(da, f)))
    per = 4
    W = 640 * 2 + 8
    for n in range(0, len(names), per):
        group = names[n:n + per]
        sheet = Image.new("RGB", (W, len(group) * (352 + 16)), (24, 24, 32))
        d = ImageDraw.Draw(sheet)
        for k, name in enumerate(group):
            y = k * (352 + 16)
            d.text((2, y + 1), "%s    %s | %s" % (name, a, b), fill=(255, 255, 200))
            for j, folder in enumerate((da, db)):
                sheet.paste(Image.open(os.path.join(folder, name + ".png")).convert("RGB"), (j * (640 + 8), y + 14))
        path = os.path.join(SHOTS, "compare_%s_%s_%d.png" % (a, b, n // per))
        sheet.save(path)
        print("  ", os.path.relpath(path, ROOT))
    return 0


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == "list":
        print(" ".join(SCREENS))
        return 0
    if argv[0] == "shoot" and len(argv) >= 2:
        return shoot(argv[1], argv[2:] or SCREENS)
    if argv[0] == "compare" and len(argv) == 3:
        return compare(argv[1], argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
