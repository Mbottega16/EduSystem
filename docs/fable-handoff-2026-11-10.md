# EduSystem UI Overhaul — Handoff Document for Claude (Fable 5.2)
**Date:** 2026-11-10  
**Target Agent:** Claude / Claude Code (`claude-fable-5-2`)  
**Resumption Time:** ~9:50 PM EST (rate limit reset)  
**Branch:** `ui-overhaul-2026-11-10`  
**Working Directory:** `C:\Users\mbott\OneDrive\Desktop\EduSystem`  

---

## 1. Executive Summary & Session Timeline

- **12:53 PM EST:** Claude hit 5-hour limit during Phase 0 screenshot capture.
- **2:15 PM – 2:30 PM EST:** Antigravity salvaged 23 baseline screenshots, completed Phase 0 audit report (`docs/ui-audit-2026-11-10.md`), built initial Phase 1 foundation (`material_box.gd`, `chalk.gdshader`, `ui_theme.gd`, `theme.tres`), and pushed commit `891d38e`.
- **4:50 PM – 5:36 PM EST:** Claude resumed and pushed Phase 1 into production:
  - Wired `theme.tres` directly into `project.godot`.
  - Added letter-by-letter chalk write-on animation and ruled chalk underline to `scenes/ui/title.tscn` and `scripts/ui/title.gd`.
  - Added stepped row arrival animations, chalk volume tick bars, and two-column Controls layout.
  - Retired `art/title_bg.png` and `fonts/ui_theme.tres` in favor of procedural drawing.
  - Added `test_design_system()` to `tests/run.gd` (+34 assertions).
  - Captured after-screenshots for all 7 title screens in `docs/ui-audit-2026-11-10/after/`.
- **5:36 PM EST:** Claude hit the 5-hour limit again right after a background test run returned a GDScript syntax error in `tests/run.gd`.
- **6:00 PM – 7:10 PM EST:** Antigravity resolved the remaining blockers:
  - Fixed GDScript syntax error at line 10723 in `tests/run.gd` (unclosed parenthesis before multiline lambda).
  - Fixed `Page.CONTROLS` column overlap where wide action names ran into their key bindings by adjusting `COLUMNS[Page.CONTROLS]` to `[52.0, 480.0]`.
  - Re-captured `title_controls.png` and `title_main.png`.
  - Synced documentation assertion count across all repo docs to `3249 assertions`.
  - Fully verified: **3,249 / 3,249 assertions passing**, **341 / 341 doc facts passing**, balance contract intact.

---

## 2. Phase 1 Title Screen — Current State & Proofs

Phase 1 is **100% complete, fully verified, and committed**.

### Key Systems Available for All Subsequent Phases:
1. **Procedural Materials (`scripts/ui/material_box.gd`):**
   - `@tool class_name MaterialBox extends StyleBox`
   - `MaterialBox.Kind.CHALKBOARD`: Dark slate fill (`#134E4A`), outer wood frame (`#C4A77D` / `#B5651D`), chalk tray with erasers and chalk pieces, subtle eraser smudges and dust marks.
   - `MaterialBox.Kind.PAPER`: Cream paper sheet (`#F5F0E1`), soft 2px drop shadow, bright top-left rim highlight, and microscopic fiber flecks.
   - `MaterialBox.Kind.WOOD`: Directional wood planks with dark grain seams and warm highlight edges.
2. **Chalk Texture Shader (`shaders/chalk.gdshader`):**
   - 2px-quantized canvas item shader adding subtle grit, edge breakup, and pressure variation to simulate real chalk on slate.
3. **Design Tokens & Theme Provider (`scripts/ui/ui_theme.gd`):**
   - `UITheme.THEME`: Global theme reference.
   - Palette: `UITheme.color(&"token")`, `UITheme.hex(&"token")`, `UITheme.faded(&"token", alpha)`.
   - Fonts: `UITheme.font(&"voice")`, `UITheme.size(&"voice")`, `UITheme.text_width(text, voice)`.
   - Boxes: `UITheme.box(&"Chalkboard")`, `UITheme.box(&"PaperSheet")`, `UITheme.box(&"WoodPlank")`.
   - Shaders: `UITheme.chalk(&"text")`, `UITheme.chalk(&"title")`.
4. **Screenshots Verified in `docs/ui-audit-2026-11-10/after/`:**
   - `title_main.png`: Wood frame, chalk title with underline, chalk tray, amber active cursor (`>`), and red chalk line under "Erase save".
   - `title_settings.png`: Chalk sliders with 10-tick bars.
   - `title_controls.png`: Clean 2-column layout with 80px gutter, windowed pagination `(1-9 of 31)`.
   - `title_slots.png`, `title_howto.png`, `title_credits.png`, `title_confirm_wipe.png`.

---

## 3. Important Quirks & Guidelines

1. **Test Runner Hangs:**
   - Do NOT run bare `Run Tests.bat` without arguments in background tasks — on test failure, lines 30/35/40 will execute `pause`, leaving the process hanging indefinitely.
   - Always run Godot test runner directly:
     ```powershell
     cmd /c '""C:\Users\mbott\Projects\_tools\godot.exe" --headless --path "C:\Users\mbott\OneDrive\Desktop\EduSystem" res://tests/run.tscn"'
     ```
2. **Lambda Syntax in GDScript 4:**
   - Never wrap a multiline `func(): ...` in parentheses like `(func() -> bool: ...).call()`. Use explicit local variables:
     ```gdscript
     var check_fn := func() -> bool:
         return ...
     chk("label", check_fn.call())
     ```
3. **Doc Assertion Sync:**
   - Whenever test assertion count increases, `python tools/check_docs.py` checks all markdown files (`CLAUDE.md`, `README.md`, `docs/GDD.md`, `docs/SALVAGE.md`). Always write digits without commas (e.g., `3249 assertions`, not `3,249 assertions`), because the regex `r"(\d+) assertions"` in `check_docs.py` only captures the trailing digits if a comma is present.

---

## 4. Current Verification State

- **Unit Tests:** **3,252 / 3,252 assertions passing** (152 sections).
- **Doc Checks:** `python tools/check_docs.py` -> **341 / 341 checks passing**.
- **Balance Contract:** Intact (`0.63 C / 0.72 C / 0.97 A` in `data/balance.json`).
- **Git Branch:** `ui-overhaul-2026-11-10`.

---

## 5. Phase 2: Pause Menu (Esc) — Completed & Verified

- **Target File:** `scripts/ui/hud.gd` (pause panel system).
- **What was done:**
  - Panel rebuilt using `MaterialBox.Kind.PAPER` (`UITheme.box(&"PaperSheet")`), replacing the old bamboo ninepatch texture with procedural cream paper and drop shadow.
  - Active-row highlight card and leading accent badge added.
  - "Resume" clearly highlighted in Olive (`#6B7B3C`) as the primary safe action.
  - Destructive exit actions ("Save and quit to title", "Save and quit the game") highlighted with Destructive Red warning card and badge (`#DC2626`).
  - Subtle sand separator line added below the section header.
  - Stepped motion integrated.
  - All 4 after-screenshots captured in `docs/ui-audit-2026-11-10/after/` (`pause.png`, `pause_quit.png`, `pause_settings.png`, `pause_tutorials.png`).
  - 3 new unit tests added in `tests/run.gd` validating paper material, olive safe highlight, and red destructive highlight.

---

## 6. Next Up: Phase 3 — Cheat Tab (11 Custom Pixel Icons)

Consult the master plan: `projects/edusystem/ui-overhaul-plan-2026-11-10.md` and Section 4 of `docs/ui-audit-2026-11-10.md`.

### Phase 3 Implementation Guide:
- **Target File:** `scripts/ui/debug_panel.gd` (and `scenes/ui/debug_panel.tscn`).
- **Requirements from Audit Spec:**
  - All 11 cheats currently in `debug_panel.gd` lack visuals.
  - Add 11 custom pixel-art icons (16x16 or 20x20) matching the LimeZu palette / classroom art style (procedural in `tools/make_art.py` or pixel-drawn into `art/`).
  - Cheat inventory from Section 4 of `docs/ui-audit-2026-11-10.md`:
    1. `all`: EVERYTHING (dev room) — Master Golden Key
    2. `coins`: Unlimited coins — Burlap Coin Sack
    3. `teacher`: Max teacher + all perks — Mortarboard with Gold Tassel
    4. `students`: Max every student — Golden Apple & Slate
    5. `ready`: Everyone ready to graduate — Rolled Diploma
    6. `furnish`: One of every item, placed — Bookshelf & Globe
    7. `enrol`: Fill the class to capacity — Group of Student Desks
    8. `grow`: Bigger room — Diagonal Arrows on Grid
    9. `day`: Skip a day — Tear-off Calendar & Sun
    10. `term`: End the term now — Brass School Bell
    11. `boss`: Boss paper now — Red Wax-Sealed Exam Scroll
  - Card/Row layout: `[Icon] [Cheat Title] — [Brief Description]`.
  - Rebuild base panel with `MaterialBox` on `theme.tres`.
  - Capture before/after shots using `tools/shot.gd` route `cheats`.
  - Ensure all unit tests and doc checks remain green.
