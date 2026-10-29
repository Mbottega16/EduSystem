#!/usr/bin/env python3
"""Canva Art Ingestion & Conformance Pipeline for EduSystem.

Allows bulk generation from Canva and automated conformance of raw Canva PNG
exports into authentic LimeZu 16-bit RPG sprites with cool #3a3a50 keylines.

Usage:
    # 1. Export all Canva prompts to CSV or Markdown:
    python tools/canva_art_pipeline.py --export-csv canva_bulk.csv
    python tools/canva_art_pipeline.py --export-md tools/CANVA_PROMPTS.md

    # 2. Automatically conform and import downloaded Canva images:
    # (Drop images into shots/canva_imports/ named after item IDs, e.g. rug_alphabet_circle.png)
    python tools/canva_art_pipeline.py --import
"""
import argparse
import glob
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ROOT = os.path.dirname(HERE)
CANVA_IMPORT_DIR = os.path.join(GAME_ROOT, "shots", "canva_imports")

NEGATIVE_PROMPT = (
    "3D render, realistic, photorealistic, isometric, blurry, antialiasing, "
    "black outline, drop shadow, neon, gradient, cartoon vector, soft edges, "
    "text, watermark"
)

ITEMS = [
    # Elementary (Ages 5-10)
    {
        "id": "rug_alphabet_circle",
        "name": "Alphabet Storytime Rug",
        "stage": "elementary",
        "subject": "Structure",
        "grid": "48x48",
        "cat": "comfort",
        "cost": 180,
        "bonus": 0.08,
        "range": 5,
        "layer": "underlay",
        "prompt": "16-bit pixel art of a large colorful circular classroom reading rug with a ring of colorful alphabet letters around the perimeter and a cheerful smiling sun in the center, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, muted warm educational colors, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels, no blur."
    },
    {
        "id": "reading_rocking_chair",
        "name": "Teacher's Storytime Rocking Chair",
        "stage": "elementary",
        "subject": "Literacy",
        "grid": "16x24",
        "cat": "seating",
        "cost": 95,
        "bonus": 0.05,
        "range": 3,
        "layer": "solid",
        "prompt": "16-bit pixel art of a cozy curved wooden rocking chair made of warm honey oak with a soft padded red cushion on the seat, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, crisp per-surface shading, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels, no blur."
    },
    {
        "id": "picture_book_ledge",
        "name": "Front-Facing Picture Book Ledge",
        "stage": "elementary",
        "subject": "Literacy",
        "grid": "32x24",
        "cat": "learning",
        "cost": 130,
        "bonus": 0.07,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a low two-tier wooden front-facing book ledge displaying colorful illustrated children's picture book covers facing forward, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, honey oak wood texture with dark plank seams, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "bug_hatching_cage",
        "name": "Butterfly & Caterpillar Hatching Net",
        "stage": "elementary",
        "subject": "Science",
        "grid": "16x24",
        "cat": "learning",
        "cost": 85,
        "bonus": 0.05,
        "range": 3,
        "layer": "solid",
        "prompt": "16-bit pixel art of a cylindrical green mesh pop-up butterfly caterpillar habitat cage with leafy twigs inside and small colorful butterflies resting on the mesh, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "counting_bears_tray",
        "name": "Plastic Counting Bears Tray",
        "stage": "elementary",
        "subject": "Math",
        "grid": "16x16",
        "cat": "learning",
        "cost": 50,
        "bonus": 0.03,
        "range": 2,
        "layer": "prop",
        "prompt": "16-bit pixel art of a wooden sorting tray holding small brightly colored plastic toy counting bears in red, blue, yellow, and green grouped in divided compartments, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "art_splat_mat",
        "name": "Washable Floor Splat Mat",
        "stage": "elementary",
        "subject": "Arts & Tech",
        "grid": "32x32",
        "cat": "comfort",
        "cost": 110,
        "bonus": 0.05,
        "range": 3,
        "layer": "underlay",
        "prompt": "16-bit pixel art of a flat vinyl floor splat mat in light yellow with playful colorful paint splatters and handprints scattered across the surface, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "cubby_row",
        "name": "Kindergarten Cubby & Backpack Unit",
        "stage": "elementary",
        "subject": "Structure",
        "grid": "32x32",
        "cat": "comfort",
        "cost": 140,
        "bonus": 0.06,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a wooden cubby shelf unit with 4 open square compartments holding colorful children's backpacks and shoes, with coat hooks above holding little jackets, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, honey oak wood texture with dark plank seams, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "weather_calendar_chart",
        "name": "Daily Weather & Calendar Pocket Chart",
        "stage": "elementary",
        "subject": "Social Studies",
        "grid": "16x24",
        "cat": "decor",
        "cost": 75,
        "bonus": 0.04,
        "range": 4,
        "layer": "wall",
        "prompt": "16-bit pixel art of a blue fabric wall pocket chart showing calendar numbers, days of the week cards, and cute sun and rain cloud weather cards, 3/4 top-down oblique front view, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },

    # Middle School (Ages 11-13)
    {
        "id": "middle_science_bench",
        "name": "Student Science Lab Workstation",
        "stage": "middle",
        "subject": "Science",
        "grid": "32x20",
        "cat": "learning",
        "cost": 210,
        "bonus": 0.09,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a sturdy dark-wood school science workstation table with a starter brass compound microscope, glass slides, and specimen jars on top, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "topographical_globe",
        "name": "Raised-Relief Topographical Globe",
        "stage": "middle",
        "subject": "Social Studies",
        "grid": "16x20",
        "cat": "learning",
        "cost": 120,
        "bonus": 0.06,
        "range": 3,
        "layer": "prop",
        "prompt": "16-bit pixel art of a detailed desk globe mounted on an ornate bronze meridian stand showing colorful green and brown continent topography and blue oceans, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "wall_timeline_banner",
        "name": "Historical Chronology Timeline Banner",
        "stage": "middle",
        "subject": "Social Studies",
        "grid": "48x16",
        "cat": "decor",
        "cost": 135,
        "bonus": 0.06,
        "range": 5,
        "layer": "wall",
        "prompt": "16-bit pixel art of a horizontal parchment-colored wall banner showing an illustrated chronological timeline with tiny pixel icons of ancient pyramids, castles, and sailing ships, 3/4 top-down oblique front view, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "robotics_starter_kit",
        "name": "Programmable Robotics Workbench",
        "stage": "middle",
        "subject": "Arts & Tech",
        "grid": "32x16",
        "cat": "learning",
        "cost": 230,
        "bonus": 0.10,
        "range": 3,
        "layer": "solid",
        "prompt": "16-bit pixel art of a low workshop table with an assembled wheeled rover robot, small plastic tool caddy, and a laptop with code blocks on screen, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "drafting_craft_table",
        "name": "Student Slanted Drafting Desk",
        "stage": "middle",
        "subject": "Arts & Tech",
        "grid": "32x20",
        "cat": "learning",
        "cost": 180,
        "bonus": 0.08,
        "range": 3,
        "layer": "solid",
        "prompt": "16-bit pixel art of a slanted wooden drafting desk with a metal T-square ruler, architectural grid paper roll, and a clip-on task lamp, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "graphing_grid_board",
        "name": "Cartesian Grid Chalkboard",
        "stage": "middle",
        "subject": "Math",
        "grid": "32x24",
        "cat": "learning",
        "cost": 190,
        "bonus": 0.08,
        "range": 4,
        "layer": "wall",
        "prompt": "16-bit pixel art of a wall-mounted green chalkboard pre-printed with a white Cartesian coordinate grid and an plotted parabolic curve, 3/4 top-down oblique front view, LimeZu modern interiors style, wooden frame, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "paperback_bookshelf",
        "name": "Middle-Grade Adventure Novel Shelf",
        "stage": "middle",
        "subject": "Literacy",
        "grid": "16x32",
        "cat": "learning",
        "cost": 150,
        "bonus": 0.08,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a tall honey-oak wooden bookshelf filled with colorful vertical spines of paperback adventure and mystery novels, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },

    # High School (Ages 14-18)
    {
        "id": "chem_lab_bench",
        "name": "Chemical Resistant Lab Station",
        "stage": "high",
        "subject": "Science",
        "grid": "32x24",
        "cat": "learning",
        "cost": 290,
        "bonus": 0.12,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a heavy black epoxy resin laboratory workbench with a central stainless steel gooseneck sink faucet and dual brass gas valves, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF), crisp clean pixels."
    },
    {
        "id": "bunsen_glassware_rack",
        "name": "Bunsen Burner & Flask Rack",
        "stage": "high",
        "subject": "Science",
        "grid": "16x20",
        "cat": "learning",
        "cost": 170,
        "bonus": 0.08,
        "range": 3,
        "layer": "prop",
        "prompt": "16-bit pixel art of a wooden test tube rack with glass vials containing colorful chemical liquids, an Erlenmeyer flask, and a small metal Bunsen burner with a tiny blue flame, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "debate_podium",
        "name": "Socratic Debate Lectern",
        "stage": "high",
        "subject": "Literacy",
        "grid": "16x24",
        "cat": "learning",
        "cost": 220,
        "bonus": 0.10,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a dark walnut debate lectern with an angled speech paper rest, small brass gooseneck microphone, and a school seal carved on the front panel, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "printer_3d_station",
        "name": "Enclosed 3D Printer Station",
        "stage": "high",
        "subject": "Arts & Tech",
        "grid": "32x24",
        "cat": "learning",
        "cost": 310,
        "bonus": 0.12,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a clear acrylic enclosed 3D printer running on a utility table, with a visible spool of blue filament and a printed geometric cube inside, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "periodic_table_wall",
        "name": "Periodic Table Wall Tapestry",
        "stage": "high",
        "subject": "Science",
        "grid": "48x20",
        "cat": "decor",
        "cost": 160,
        "bonus": 0.07,
        "range": 5,
        "layer": "wall",
        "prompt": "16-bit pixel art of a large detailed classroom wall chart displaying the complete Periodic Table of Elements in color-coded chemical family columns, 3/4 top-down oblique front view, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "graphing_calc_dock",
        "name": "Graphing Calculator Charging Dock",
        "stage": "high",
        "subject": "Math",
        "grid": "16x16",
        "cat": "learning",
        "cost": 110,
        "bonus": 0.06,
        "range": 3,
        "layer": "prop",
        "prompt": "16-bit pixel art of a desktop charging organizer holding 10 black handheld graphing calculators with bright blue accents, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },

    # College / University (Higher Ed)
    {
        "id": "fume_hood",
        "name": "Laboratory Chemical Fume Hood",
        "stage": "college",
        "subject": "Science",
        "grid": "32x32",
        "cat": "learning",
        "cost": 380,
        "bonus": 0.15,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a professional tall stainless-steel chemical fume hood with a sliding tempered glass sash window, interior lighting, and exhaust ventilation duct on top, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "centrifuge_bench",
        "name": "Digital Centrifuge & Pipette Bench",
        "stage": "college",
        "subject": "Science",
        "grid": "32x20",
        "cat": "learning",
        "cost": 340,
        "bonus": 0.14,
        "range": 3,
        "layer": "solid",
        "prompt": "16-bit pixel art of a clean white research counter with a round benchtop centrifuge unit, digital LCD display, and a micro-pipette rack, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "research_carrel",
        "name": "Oak Library Study Carrel Desk",
        "stage": "college",
        "subject": "Literacy",
        "grid": "16x28",
        "cat": "seating",
        "cost": 210,
        "bonus": 0.10,
        "range": 3,
        "layer": "solid",
        "prompt": "16-bit pixel art of a private library study carrel desk with high oak privacy partitions on three sides, an integrated overhead book shelf, and a warm task light, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "sliding_slate_board",
        "name": "Double-Sliding Slate Chalkboard",
        "stage": "college",
        "subject": "Math",
        "grid": "48x24",
        "cat": "learning",
        "cost": 320,
        "bonus": 0.12,
        "range": 5,
        "layer": "wall",
        "prompt": "16-bit pixel art of a wall-mounted academic double-tiered sliding black slate chalkboard covered in dense chalk calculus equations and geometric proofs, 3/4 top-down oblique front view, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "archival_terminal",
        "name": "University Microfilm / Microfiche Reader",
        "stage": "college",
        "subject": "Social Studies",
        "grid": "16x20",
        "cat": "learning",
        "cost": 190,
        "bonus": 0.08,
        "range": 3,
        "layer": "prop",
        "prompt": "16-bit pixel art of a vintage university research microfiche reader machine with a glowing curved greenish CRT screen and paper spool reels, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    },
    {
        "id": "cnc_mill_station",
        "name": "Desktop CNC Milling Station",
        "stage": "college",
        "subject": "Arts & Tech",
        "grid": "32x24",
        "cat": "learning",
        "cost": 360,
        "bonus": 0.13,
        "range": 4,
        "layer": "solid",
        "prompt": "16-bit pixel art of a compact enclosed desktop CNC milling machine with an emergency stop button, transparent safety shield, and routed wooden block, 3/4 top-down oblique view camera tilted 45 degrees, LimeZu modern interiors style, 1-pixel dark cool slate-blue outline (#3a3a50), solid flat magenta background (#FF00FF)."
    }
]


def export_csv(out_path):
    import csv
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ID", "Name", "Stage", "Subject", "Grid", "Category", "Cost", "Canva_Prompt", "Negative_Prompt"])
        for it in ITEMS:
            writer.writerow([
                it["id"], it["name"], it["stage"], it["subject"], it["grid"],
                it["cat"], it["cost"], it["prompt"], NEGATIVE_PROMPT
            ])
    print(f"Exported {len(ITEMS)} Canva prompts to CSV: {out_path}")


def export_md(out_path):
    lines = ["# EduSystem — Master Canva Classroom Prompts\n"]
    lines.append(f"> **Universal Negative Prompt for Canva:** `{NEGATIVE_PROMPT}`\n")
    lines.append("---\n")
    for it in ITEMS:
        lines.append(f"### {it['name']} (`{it['id']}`)")
        lines.append(f"- **Stage:** {it['stage'].title()} | **Subject:** {it['subject']} | **Size:** {it['grid']} | **Type:** {it['layer']}")
        lines.append(f"- **Canva Prompt:**\n```\n{it['prompt']}\n```\n")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Exported {len(ITEMS)} Canva prompts to Markdown: {out_path}")


def import_canva_images(import_dir=CANVA_IMPORT_DIR):
    """Scan import_dir for downloaded Canva PNGs, run lz_conform.py, and place into art/."""
    os.makedirs(import_dir, exist_ok=True)
    files = glob.glob(os.path.join(import_dir, "*.png"))
    if not files:
        print(f"No Canva export PNGs found in: {import_dir}")
        print("Drop your Canva downloads into that folder, named after item IDs (e.g. rug_alphabet_circle.png), and re-run.")
        return 0

    item_map = {it["id"]: it for it in ITEMS}
    lz_conform = os.path.join(HERE, "lz_conform.py")
    conformed_count = 0

    for fpath in files:
        base = os.path.splitext(os.path.basename(fpath))[0]
        # Match base filename to item id
        it = item_map.get(base)
        if not it:
            # Try fuzzy match
            for candidate_id in item_map:
                if candidate_id in base.lower():
                    it = item_map[candidate_id]
                    break

        if not it:
            print(f"Warning: Could not match image {os.path.basename(fpath)} to a known item ID. Skipping.")
            continue

        target_png = os.path.join(GAME_ROOT, "art", f"{it['id']}.png")
        grid = it["grid"]

        print(f"Conforming [{it['id']}] ({grid}) -> art/{it['id']}.png...")
        cmd = [
            sys.executable, lz_conform,
            fpath, target_png,
            "--grid", grid,
            "--x2"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0 and os.path.exists(target_png):
            print(f"  [OK] Successfully conformed and installed {it['id']}.png")
            conformed_count += 1
        else:
            print(f"  [FAIL] Conformance failed: {res.stderr}")

    if conformed_count > 0:
        print(f"\nConformed {conformed_count} items into art/.")
        godot_txt = os.path.join(HERE, "godot_path.txt")
        if os.path.exists(godot_txt):
            godot = open(godot_txt).read().strip()
            print("Triggering Godot headless art re-import...")
            subprocess.run([godot, "--headless", "--path", GAME_ROOT, "--import"], check=False)
            print("Re-import complete!")

    return conformed_count


def main():
    parser = argparse.ArgumentParser(description="Canva Art Ingestion & Conformance Pipeline")
    parser.add_argument("--export-csv", help="Export all prompts to CSV for Canva bulk create")
    parser.add_argument("--export-md", help="Export all prompts to single markdown file")
    parser.add_argument("--import", dest="do_import", action="store_true", help="Import & conform downloaded Canva images")
    parser.add_argument("--dir", default=CANVA_IMPORT_DIR, help="Canva imports directory")
    args = parser.parse_args()

    if args.export_csv:
        export_csv(args.export_csv)
    elif args.export_md:
        export_md(args.export_md)
    elif args.do_import:
        import_canva_images(args.dir)
    else:
        # Default: print summary and export default markdown
        default_md = os.path.join(HERE, "CANVA_CLASSROOM_PROMPTS.md")
        export_md(default_md)
        print(f"\nInteractive Visual Generator: tools/canva_art_generator.html")
        print(f"Drop Canva downloads into:    {CANVA_IMPORT_DIR}")


if __name__ == "__main__":
    main()
