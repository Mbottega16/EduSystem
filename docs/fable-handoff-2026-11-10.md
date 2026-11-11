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

- **Unit Tests:** **3279 / 3279 assertions passing** (151 sections).
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

## 6. Phase 3: Cheat Tab (11 Custom Pixel Icons) — Completed & Verified

- **Target Files:** `scripts/ui/debug_panel.gd`, `tools/make_cheat_icons.py`, `tools/make_ui.py`, `art/icon_cheat_*.png`.
- **What was done:**
  - Generated 11 bespoke 20x20 pixel-art icons matching LimeZu density and palette:
    1. `all`: Master Golden Key with glints (`art/icon_cheat_all.png`)
    2. `coins`: Overflowing Burlap Coin Sack (`art/icon_cheat_coins.png`)
    3. `teacher`: Mortarboard with Gold Tassel & Rank Star (`art/icon_cheat_teacher.png`)
    4. `students`: Golden Apple & A+ Slate (`art/icon_cheat_students.png`)
    5. `ready`: Rolled Diploma with Red Ribbon (`art/icon_cheat_ready.png`)
    6. `furnish`: Bookshelf with Colored Books & Miniature Globe (`art/icon_cheat_furnish.png`)
    7. `enrol`: Group of Student Desks with Pencils (`art/icon_cheat_enrol.png`)
    8. `grow`: Blueprint with 4-Way Expanding Arrows (`art/icon_cheat_grow.png`)
    9. `day`: Tear-off Desk Calendar with Radiating Sun (`art/icon_cheat_day.png`)
    10. `term`: Brass Ringing Bell with Sound Waves (`art/icon_cheat_term.png`)
    11. `boss`: Red Wax-Sealed Exam Scroll (`art/icon_cheat_boss.png`)
  - Panel rebuilt using `MaterialBox.Kind.PAPER` (`UITheme.box(&"PaperSheet")`) on `theme.tres`.
  - Scannable 7-row windowed architecture with Amber selection highlight card, 3px leading stripe badge, 20x20 icon, crisp title in ink, short effect description in pencil, and dynamic status tags (`(ACTIVE)`, `[E] ACTIVATE`).
  - Tab cards for `[CHEATS]` / `[TUNING]` with sand separator. Restyled `TUNING` page with value nudges.
  - Test contract maintained for headless tests via synchronized `_label.text`.
  - Added 3 unit tests in `tests/run.gd` (+3 assertions, total 3255).
  - Captured after-screenshots in `docs/ui-audit-2026-11-10/after/` (`cheats.png`, `cheats_scrolled.png`, `cheats_tuning.png`).

---

## 7. Phase 4: Lesson Plan Tab & Curriculum Redesign — Completed & Verified

- **Target Files:** `scripts/ui/hud.gd`, `tests/run.gd`.
- **What was done:**
  - **Lesson Plan Card Redesign (`show_hand` / `_render_hand`):**
    - Left page: Formatted as a real teacher assignment document with 16x16 strand mark (`res://art/icon_<strand>.png`), capitalized strand label (`[MATH]`, `[ELA]`, `[SCI]`, etc.), assignment title in paper tint, rarity & pay multiplier indicator (`[Prestige/Rarity]  pays x%.2f`), standard citation code, and authentic handwritten pedagogical classroom notes via `_lesson_plan_note(form, strand)`.
    - Right page: Clean length difficulty bar, clear objective text with automatic fit protection for long objectives (up to 261 characters on `division`), and page turn pips.
  - **Curriculum Redesign (`show_curriculum`):**
    - Left page: Active teaching header (`You teach %s`, `trained in %s`, `Knowing your subjects %s`), selected lesson dossier with 16x16 strand mark, status badges (`[MASTERED]` in Olive `#6B7B3C`, `[PRACTICING]` in Amber `#D97706`, `[UNTOUCHED]` in pencil `#6B5F4A`), teaching count (`Taught %d times`), mastery description, prestige milestone status, and authentic teacher's pedagogical tip via `_curriculum_tip(lesson)`.
    - Right page: 7 scannable rows with active cursor (`[color=#D97706]>[/color]`), status badges (`+` prestige, `*` specialism), 16x16 strand icon, crisp name contrast (`#1A1A1A` on active selection), 5-cell difficulty bar, and mastery words in Olive/pencil without wrapping.
    - Preserved prose-never-numbers test assertion contract on every line of `rich.text`.
  - Added 3 unit tests in `tests/run.gd` (+3 assertions, total 3258).
  - Captured after-screenshots in `docs/ui-audit-2026-11-10/after/` (`hand.png`, `hand_long.png`, `curriculum.png`).

---

## 8. Phase 5: The Cabinet & Store — Completed & Verified

- **Target Files:** `scripts/ui/hud.gd`, `tests/run.gd`.
- **What was done:**
  - **Left-Page Table of Contents (`_shop_contents`):** Structured table of contents with ruled sand divider (`-----------------`), dynamic storage count badge (`Your cabinet (%d)`), amber active-page indicator (`[color=#D97706]>[/color] [b]%s[/b]`), and muted unselected section links.
  - **Empty Cabinet Warm Teacher Note (`cabinet_empty.png`):** Transformed the stark single-line empty message into an authentic classroom note with a bold header, ruled sand separator, warm invitation (`"Your shelves are ready for supplies."`), pedagogical quote (`"Every great classroom begins with a clear desk and an open mind."`), and clear navigation prompt in Accent Amber.
  - **Scannable Raised Rows in Cabinet & Store (`cabinet.png`, `shop.png`):**
    - Active row highlight with amber cursor (`>`), bold item name, quantity badge in Olive (`#6B7B3C`), and sell price tag in muted pencil without jitter.
    - Furniture Catalogue (`BUY` mode): bold active category header with bracketed tabs, amber selection indicator, bold item name, formatted price tags, and clean desk-item capacity indicators without text wrapping.
  - Added 3 unit tests in `tests/run.gd` (+3 assertions, total 3261).
  - Captured after-screenshots in `docs/ui-audit-2026-11-10/after/` (`cabinet.png`, `cabinet_empty.png`, `shop.png`).

---

## 9. Phase 6: Watching Panel (Other Teachers' Classrooms) — Completed & Verified

- **Target Files:** `scripts/ui/desk_sheet.gd`, `scripts/ui/hud.gd`, `tools/shot.gd`, `tests/run.gd`.
- **What was done:**
  - Created `scripts/ui/desk_sheet.gd` (`DeskSheet.Kind.CLIPBOARD` and `DeskSheet.Kind.DESK`) providing a shared clipboard and desk-report sheet node with wood backing, cream paper, brass spring clip, status tag, side-by-side comparison cards, tilted rubber stamp, right-hand ledger column, pencil on the wood desk, and bottom key caps.
  - Rebuilt `show_watch()`, `show_auto_teach()`, and `set_visit_room()` in `scripts/ui/hud.gd`:
    - Clipboard observation motif (`[OBSERVING]` in olive for a colleague's room, `[YOUR ROOM]` in amber for auto-teach) over a lighter room dim (`PAPER_DIM = 0.38`) so the classroom remains visible behind the clipboard.
    - Side-by-side comparison cards (`THEIR ROOM ?` / `YOUR ROOM B`, or `TODAY ?` for auto-teach) that fill in with the final letter grade at the bell.
    - Student status rows packed two to a line with coloured status words; automatic shrink to small print when a large class or long bell tally would overflow.
    - Small framed chalkboard plate (`visit_plate`) at the top-left when walking inside a colleague's room (`ROOM 1 · MS. REYES — THE DRILL SERGEANT`) while keeping the main top status strip untouched.
    - Fixed navigation bug where pressing `Esc` from a clipboard opened inside a visited room jumped to the school board instead of returning to the visited room.
  - Added 12 unit tests in `tests/run.gd` (+12 assertions, total 3273).
  - Captured after-screenshots in `docs/ui-audit-2026-11-10/after/` (`watch.png`, `watch_bell.png`, `watch_full.png`, `auto_teach.png`, `visit.png`).

---

## 10. Phase 7: End-of-Day Wrap-Up Summary — Completed & Verified

- **Target Files:** `scripts/ui/hud.gd` (`show_day_report`, `_grade_rows`, `_part_line`, `_diagnosis`, `_pacing_line` using `DeskSheet.Kind.DESK`), `tests/run.gd`.
- **What was done:**
  - Replaced the old dark bamboo modal on `show_day_report()` with `DeskSheet.Kind.DESK` (`DAY_SHEET_RECT := Rect2(24, 12, 592, 300)`): full-screen oak desk (`WoodPlank`), cream paper sheet (`PaperSheet`), and yellow pencil on the wood.
  - Added printed display heading (`DAY %d`, `%d DAYS LEFT IN TERM %d`) and tilted rubber grade stamp (`GRADE %s` in `olive`, `amber`, `terracotta`, or `destructive`).
  - Aligned the 4 grade part rows (`the room`, `the lesson`, `homework`, `what you know`) on the left with the 4-line financial/homework ledger (`+%d coins`, `-%d upkeep`, `purse %d`, `homework %d of %d`) down the right behind a vertical sand rule.
  - Styled all diagnosis and news sentences in the teacher's handwritten voice (`Patrick Hand` 18px via `_note()`), with bottom-up overflow shrinking into `_small_print()` and an `E close` key cap on the wood.
  - Captured and visually verified `day.png`, `day_admin.png`, and `consumables_report.png` in `docs/ui-audit-2026-11-10/after/`.
  - Added 6 unit tests in `tests/run.gd` (+6 assertions, total 3279).

---

## 11. Phase 8: Flavor Pass (Proposals Only) — Completed

- **Target File:** `docs/ui-audit-2026-11-10.md` (Section 13).
- **What was done:**
  - Wrote 6 concrete, sized proposals in Section 13 of `docs/ui-audit-2026-11-10.md` (nothing built, per plan):
    1. *Put the School Board and Hiring Sheet on a Staffroom Noticeboard* (`show_school`, `show_hiring` — Medium)
    2. *Move the Other End-of-Lesson and End-of-Term Reports onto Desk Sheets* (`show_lesson_report`, `show_quiz_report`, `show_test_report`, `show_inspection`, `show_exam`, `show_new_term`, `show_run_over` — Medium–Large)
    3. *Student File and Class Register as a Manila Dossier Folder* (`show_class_list`, `show_student` — Medium)
    4. *Teacher Dashboard, Career Wall, and Staff Rota on Paper Cards* (`show_dashboard`, `show_career`, `show_rota` — Medium)
    5. *One Body Voice Across All Paper Screens (`VT323` vs `Galmuri9`)* (Medium)
    6. *Small Tactile Paper Details (Red Margin Rule, Three-Ring Holes, Stamp Thud)* (Small)
- **Status:** All phases (0 through 8) of `ui-overhaul-plan-2026-11-10.md` are complete and ready for owner review.
