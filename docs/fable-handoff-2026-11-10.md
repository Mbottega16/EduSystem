# EduSystem UI Overhaul — Handoff Document for Claude (Fable 5.2)
**Date:** 2026-11-10  
**Target Agent:** Claude / Claude Code (`claude-fable-5-2`)  
**Resumption Time:** ~4:50 PM EST (rate limit reset)  
**Branch:** `ui-overhaul-2026-11-10`  
**Working Directory:** `C:\Users\mbott\OneDrive\Desktop\EduSystem`  

---

## 1. Context & What Happened

At ~12:53 PM EST, Claude (Fable 5.2) hit the Anthropic 5-hour rate limit during an unattended autopilot session (`"You've hit your 5-hour limit · resets 4:50pm"`). 

### Why the Rate Limit Was Exhausted
In session `d7c0af5b-356e-424e-ba71-0489381b3c29.jsonl`, Claude performed extensive exploration, downloaded fonts, built a `fontlab` sandbox in `Temp/claude/.../scratchpad/fontlab/`, updated `tools/shot.gd`, and captured 23 baseline screenshots. It then ingested all 23 screenshots plus multiple zoomed crops into the multimodal vision context across 239 turns. Multimodal token weight rapidly consumed the 5-hour quota right as Phase 0 was wrapping up.

Antigravity stepped in at Michael's request to:
1. Audit and salvage everything Fable did.
2. Complete and finalize **Phase 0** (Visual Audit & Specifications).
3. Implement and verify **Phase 1** (Title Screen Pilot Proof & Foundation Systems).
4. Run full test suites and ensure zero regressions.
5. Prepare this handoff so you can hit the ground running without repeating any work or burning tokens.

---

## 2. What Antigravity Completed & Verified (The Gaps Filled)

### Phase 0: Screenshot Audit & Design Specs (100% Complete)
- **Screenshot Harness Updated:** Added missing screenshot routes (`cabinet`, `cabinet_empty`, and `pause_quit`) to `tools/shot.gd`. All 23 baseline "before" screenshots are preserved in `docs/ui-audit-2026-11-10/before/`.
- **Salvaged Artifacts:** Recovered mockup renders (`mock_title.png`, `mock_title2.png`, `mock_panels.png`) from the temporary scratchpad into `docs/ui-audit-2026-11-10/`.
- **Audit Report Authored:** `docs/ui-audit-2026-11-10.md` documents:
  - Baseline analysis of all 8 target panels.
  - Complete 11-item Cheat Tab Icon Inventory with visual descriptions (for Phase 3).
  - Complete End-of-Day Wrap-Up Specification (Desk Paper Report Sheet replacing the black terminal, for Phase 7).
  - Design tokens, color palette, and typography rules.
- **Committed:** Commit `d67f1f1` pushed to `origin/ui-overhaul-2026-11-10`.

### Phase 1: Title Screen Pilot Proof & Design Foundation (100% Complete)
- **Google Fonts Installed:**
  - `fonts/Kalam-Bold.ttf`, `fonts/Kalam-Regular.ttf` (handwritten chalk)
  - `fonts/PressStart2P-Regular.ttf` (retro display and key hints)
  - `fonts/VT323-Regular.ttf` (dense UI readouts and tables)
  - All OFL license files installed alongside them (`fonts/*-OFL.txt`).
- **Procedural Classroom Materials (`scripts/ui/material_box.gd`):**
  - Custom `StyleBox` generator for 3 procedural surfaces (zero image asset dependencies):
    - `CHALKBOARD`: Deep slate fill (`#134E4A`), outer wood frame (`#C4A77D` / `#B5651D`), subtle eraser smudges, and dust marks.
    - `PAPER`: Cream paper sheet (`#F5F0E1`), soft 2px drop shadow, bright top-left rim highlight, and microscopic fiber flecks.
    - `WOOD`: Directional wood planks with dark grain seams and warm highlight edges.
- **Chalk Texture Shader (`shaders/chalk.gdshader`):**
  - 2px-quantized canvas item shader adding subtle grit, edge breakup, and pressure variation to simulate real chalk on slate.
- **Central Design Tokens & Styles (`scripts/ui/ui_theme.gd`):**
  - Defines color palette constants matching the design system.
  - Factory methods: `make_chalkboard_box()`, `make_paper_box()`, `make_wood_box()`.
  - Shader material instance factory: `make_chalk_material()`.
  - Dynamic font loader: `load_font(res_path)` (see technical quirks below).
- **Global Theme Resource (`theme.tres`):**
  - Default font configured to `VT323-Regular.ttf`.
- **Title Screen Overhaul (`scripts/ui/title.gd`):**
  - Background replaced with procedural wood-framed chalkboard (`MaterialBox.Kind.CHALKBOARD`).
  - Title replaced with hand-lettered chalk `"EDUSystem"` (Kalam Bold 44px, `#FDFBF7`, chalk shader) with subtle ambient vertical breathing oscillation.
  - Menu choices styled in Kalam Regular (16px) with chalk shader.
  - Dedicated Accent Amber active cursor (`>`) in `#D97706`.
  - Page layout tuned: menu spans y=58 to y=274 without touching the prompt footer at y=312.
  - Windowed pagination added for Controls (`shown_rows = 8`) to prevent overflow.
  - Engine-native smooth fade/slide page transition tween (`_animate_transition`).
- **Proof Screenshots Captured:**
  - `docs/ui-audit-2026-11-10/title_main_after.png` (Main Menu)
  - `docs/ui-audit-2026-11-10/title_settings_after.png` (Settings)
  - `docs/ui-audit-2026-11-10/title_controls_after.png` (Controls)
- **Audit Doc Updated:** Section 8 appended to `docs/ui-audit-2026-11-10.md`.

---

## 3. Technical Quirks & Engine Lessons Learned

Keep these in mind when working on Phases 2–8:

1. **TTF Loading in Headless Godot:**
   - Preloading bare `.ttf` files (e.g. `preload("res://fonts/VT323-Regular.ttf")`) will fail in headless Godot with `Resource file has no resource loaders (unrecognized file extension)` unless Godot's desktop editor has generated `.import` files for them.
   - **Solution:** Always use `UITheme.load_font("res://fonts/...")` which calls `FontFile.new().load_dynamic_font(path)` with graceful fallback to `res://fonts/Galmuri9.ttf`.
2. **Headless Class Name Cache:**
   - Headless script compilation occasionally throws `Identifier not declared in current scope` for `class_name` scripts like `UITheme` and `MaterialBox`.
   - **Solution:** Add explicit preloads at the top of your scripts:
     ```gdscript
     const UITheme := preload("res://scripts/ui/ui_theme.gd")
     const MaterialBox := preload("res://scripts/ui/material_box.gd")
     ```
3. **Kalam Font Metrics:**
   - Kalam is a handwriting font with taller line metrics than bitmap fonts. For menus with 7–9 items, use font size 16–18 and line spacing 0–1 to prevent colliding with screen bottom or footer text.
4. **Capturing Title Screenshots:**
   - `tools/title_shot.gd` takes two arguments: output path and page name (`main`, `settings`, `controls`, `slots`, etc.).
   - Invoke via:
     ```powershell
     cmd /c '""C:\Users\mbott\Projects\_tools\godot.exe" --position -6000,-6000 --resolution 640x352 --path "C:\Users\mbott\OneDrive\Desktop\EduSystem" res://tools/title_shot.tscn -- "<out_path>" <page_name>"'
     ```
5. **Running General Screenshots:**
   - `tools/shot.gd` handles all in-game panels (`pause`, `shop`, `lesson_plans`, etc.):
     ```powershell
     cmd /c '""C:\Users\mbott\Projects\_tools\godot.exe" --position -6000,-6000 --resolution 640x352 --path "C:\Users\mbott\OneDrive\Desktop\EduSystem" res://tools/shot.tscn -- "<out_path>" <route>"'
     ```

---

## 4. Current Verification State

- **Unit Tests:** `Run Tests.bat 1` -> **3,215 / 3,215 assertions passing** (151 sections).
- **Doc Checks:** `python tools/check_docs.py` -> **341 / 341 checks passing**.
- **Balance Contract:** Intact (`0.63 C / 0.72 C / 0.97 A` in `data/balance.json`).
- **Git Branch:** `ui-overhaul-2026-11-10`.

---

## 5. Where Claude Should Go Next (Phase 2 & Beyond)

Consult the master plan: `projects/edusystem/ui-overhaul-plan-2026-11-10.md`.

### Next Task: Phase 2 — Pause Menu (Esc)
- **Target File:** `scripts/ui/pause.gd` (and `scenes/ui/pause.tscn` if applicable).
- **Sub-pages:** Main Pause, Settings, Tutorials, Confirm Quit.
- **Requirements from Plan:**
  1. Base panel: Use `MaterialBox.Kind.PAPER` (or `CHALKBOARD` if styled as teacher's slate) with unified border from `UITheme`.
  2. Hierarchy:
     - "Resume" clearly framed as the primary safe option (Accent Amber cursor or Olive highlight).
     - Settings / Tutorials in standard UI ink.
     - Destructive actions ("Quit to Title" / "Abandon") clearly styled in Destructive Red (`#DC2626`).
  3. Typography:
     - Section headers / Key hints: Press Start 2P (`UITheme.get_font(UITheme.FontRole.DISPLAY, 12)`).
     - Options list / Descriptions: VT323 (`UITheme.get_font(UITheme.FontRole.BODY, 20)`).
  4. Animations: Smooth stepped fade/slide entrance and exit transitions matching Phase 1 style.
  5. Validation:
     - Capture `pause_after.png` and `pause_quit_after.png`.
     - Run `Run Tests.bat 1` (verify all 3,215 tests pass).
     - Run `python tools/check_docs.py`.
     - Log in `HISTORY.md` and commit.

### Remaining Roadmap
- **Phase 3:** Cheats Panel (`scripts/ui/debug_panel.gd` + 11 custom pixel icons from Section 4 of `docs/ui-audit-2026-11-10.md`).
- **Phase 4:** Lesson Plan Tab & Curriculum Card Redesign.
- **Phase 5:** The Cabinet & Store (Book Metaphor & Paper Cards).
- **Phase 6:** Watching Panel (Classroom Observation Clipboard).
- **Phase 7:** End-of-Day Wrap-Up Summary (Desk Paper Report Sheet).
- **Phase 8:** Final Cohesion, Motion Polish, and Cross-Platform Verification.

You have all tokens, materials, shaders, and baseline captures ready. Happy coding!
