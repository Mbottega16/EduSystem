# EDUSystem — itch.io Screenshot Guide

## Overview
Five to eight carefully chosen in-game screenshots that showcase the core gameplay loop and visual style. All screenshots should be:
- **Captured from the actual running game** (not the Godot editor)
- **Headless or native window, no editor UI visible**
- **Full game resolution (640×352)**
- **Representative of default gameplay** (not max-expanded schools or heavily modded rooms)
- **Clean, well-lit scenes** (avoid mid-animation or visual glitches)

---

## Recommended Screenshot Set (5–8 images)

### Screenshot 1: Title Screen
**What to show:** The main menu/title screen  
**Why:** First impression of the game's art style and tone  
**Capture method:** `godot --headless --path . res://tools/title_shot.tscn -- out.png main`

**Appearance checklist:**
- [ ] Game logo visible
- [ ] Main menu options visible (Play, Settings, etc.)
- [ ] Clean, readable at half-size (320px wide)
- [ ] Shows the pixel-art style and color palette

---

### Screenshot 2: Classroom Overview (Start of Day)
**What to show:** A fresh classroom at the start of a lesson, full classroom view, teacher standing at the podium  
**Why:** Establishes the core gameplay loop: "you stand at the front and teach"  
**Key elements visible:**
- [ ] Teacher (player) standing at the podium (front of room)
- [ ] Full classroom with 6–8 students seated at desks
- [ ] Furniture arrangement (bookshelves, chairs, etc.)
- [ ] The room layout grid and the player's position clearly visible
- [ ] HUD showing action badges above the teacher's head
- [ ] Day counter, coins, and other status info in top-left HUD

**Capture method:** Play the game, start a new term, let a few students sit down at the start of day 1, stand at the podium, take a screenshot via `Take a Screenshot.bat` or headless capture

**Notes:**
- Avoid partial animations (students sitting, etc.)
- Ensure at least 5–6 desks are visible with students seated
- Show a well-balanced, readable classroom layout

---

### Screenshot 3: Teaching/Work in Progress
**What to show:** Mid-lesson activity—the teacher teaching at the podium with students engaged  
**Why:** Shows the core mechanic: work advances while the teacher is present  
**Key elements visible:**
- [ ] Teacher standing at podium (visible teaching position)
- [ ] Students with work visible (worksheets, books, or activity indicators)
- [ ] Visual feedback (thought bubbles, progress bars, or mood indicators)
- [ ] The classroom alive and in motion

**Capture method:** In a lesson, stand at the podium for 5–10 seconds until a few students show visible progress/engagement

**Notes:**
- Captures the "real-time management" feel
- Shows the consequence mechanic: work only advances when you're there

---

### Screenshot 4: Room Customization / Shop
**What to show:** The shopping interface showing furniture, cost, and effect information  
**Why:** Demonstrates the "furniture matters" pillar—placement and purchases are strategic  
**Key elements visible:**
- [ ] The furniture shop interface (list of items, prices, descriptions)
- [ ] Cost visible (coins) and bonus/effect descriptions
- [ ] A mix of different furniture types (seating, learning tools, decorations)
- [ ] The "blurb" text explaining why each item matters (e.g., "Improves focus for readers")
- [ ] Teacher's current coins and available budget

**Capture method:** In the classroom, walk to the shop (furniture buying landmark), open the shop menu

**Notes:**
- Avoid showing items you've already bought (less dramatic)
- Show 3–5 available items with clear descriptions
- The UI must show prices and effects without truncation

---

### Screenshot 5: Grade/Progress Report
**What to show:** The grade book or end-of-term report showing student progress  
**Why:** Demonstrates the grading system (letters, not numbers) and the "real consequences" pillar  
**Key elements visible:**
- [ ] Letter grades (A, B, C, D, E) for the class
- [ ] Per-student progress or effort notes (if available)
- [ ] Term end summary or mid-lesson grade readout
- [ ] No raw decimals—only prose descriptions and letter grades

**Capture method:** End a lesson (ring the bell), or take a screenshot of the grade book screen (Key U, or end of a term)

**Notes:**
- Focus on readability of the grade display
- Ensure no decimal scores appear (enforces the "prose not numbers" rule)
- Show the narrative feedback alongside grades if available

---

### Screenshot 6 (Optional): Desk Chat / Social Dynamics
**What to show:** Two students interacting (chatting) at adjacent desks with a chat bubble  
**Why:** Shows the social simulation aspect—students aren't isolated drones  
**Key elements visible:**
- [ ] Two students at nearby desks
- [ ] A lilac chat bubble or conversation indicator above/between them
- [ ] The teacher able to walk over and "hush" the chat (show the decision point)
- [ ] The classroom layout showing desk proximity matters

**Capture method:** Arrange two desks closely (within `chat.reach_tiles`), let students sit, ignore them for 10+ seconds until a chat starts

**Notes:**
- Captures the management aspect (crowd control)
- Shows the aesthetic of the game's UI (the chat bubble design)
- Optional but adds variety to the screenshot set

---

### Screenshot 7 (Optional): School/Delegation View
**What to show:** The principal's office or school overview, showing hired staff and delegated rooms  
**Why:** Shows the "two altitudes" of play—you can stay in the room or expand to manage a school  
**Key elements visible:**
- [ ] Office layout or the hallway with multiple room doors
- [ ] Evidence of hired staff (a desk, a room occupied by others)
- [ ] The interface showing room status or staff assignments
- [ ] A sense of scale/growth

**Capture method:** Progress to a second term, hire an aide or open a new room, then screenshot the hallway or the hiring interface

**Notes:**
- Optional—focus on the 5 core screenshots first
- Shows the game's scalability without leaving the "walking" mechanic

---

### Screenshot 8 (Optional): Exam/Milestone Screen
**What to show:** The exam setup or a high-stakes grading moment  
**Why:** Demonstrates the "real consequences" pillar—exams are pass-or-fail  
**Key elements visible:**
- [ ] The exam interface or lesson selection for the exam
- [ ] The target/goal clearly stated (prose, not a raw number)
- [ ] A sense of tension/importance

**Capture method:** Reach the last day of a term, take the exam screen screenshot (before running it)

**Notes:**
- Optional, more advanced
- Captures the "meaningful consequence" aspect

---

## Capture Workflow

### Using headless Godot (recommended for consistency)

```bash
# Title screen
godot --headless --path . res://tools/title_shot.tscn -- shots/01_title.png main

# Full HUD view (day start)
godot --headless --path . res://tools/full_hud.tscn -- shots/02_classroom.png

# [Other scenes as needed]
```

### Using the game directly

1. **Start a new game**
2. **Play through Day 1 Phase 1** (students sitting down)
3. **Position camera at the classroom overview** (full view)
4. **Open the game's built-in screenshot tool** (if available) or press PrtScn
5. **Save screenshots to `shots/`**

### Batch capture (if available)

The project may have a batch screenshot tool. Check:
- `tools/shot_all.py` — runs all named scenes
- `tools/shot_compare.py` — compares before/after

---

## Quality Checklist

For each screenshot:

- [ ] Resolution is exactly 640×352 (no scaling or letterboxing)
- [ ] No editor UI, debug text, or console visible
- [ ] Game UI is readable (not cut off, not too small)
- [ ] The scene represents normal gameplay (not a rare edge case)
- [ ] Lighting is natural (not too dark, not washed out)
- [ ] File format is PNG (lossless)
- [ ] File size is < 200 KB per image
- [ ] Aspect ratio is correct for itch.io
- [ ] No personal/testing artifacts (e.g., "TESTSAVE" in the UI)

---

## Post-Processing (Optional, in image editor)

Once captured, you may optionally:
- **Crop to 460×215** if creating a smaller promo image
- **Add a frame/border** to separate images in a gallery view
- **Add subtle labels** (screenshot number, feature highlight)
- **Adjust brightness** if the headless capture is too dark

**Do NOT:**
- Add filters, blur, or effects that obscure the pixel art
- Resize in a way that breaks the crisp pixel grid (always use integer scaling)
- Add watermarks or logos that compete with the game
- Modify the actual game state (cheating, debug mode)

---

## File Naming Convention

Save as:
- `shots/01_title.png` — Title screen
- `shots/02_classroom_overview.png` — Classroom start of day
- `shots/03_lesson_in_progress.png` — Teaching/work ongoing
- `shots/04_shop.png` — Furniture shopping interface
- `shots/05_grades.png` — Grade report/book
- `shots/06_chat.png` — (optional) Student interaction
- `shots/07_school.png` — (optional) Delegation/school view
- `shots/08_exam.png` — (optional) Exam setup

---

## Uploading to itch.io

itch.io displays screenshots in this order on the game page:
1. The first image becomes the "hero" image (shown large above the fold)
2. The next 2–4 images appear as a carousel below
3. More can be added to a scrollable gallery

**Recommended upload order for maximum impact:**

1. **Screenshot 2** (Classroom overview) — shows the core gameplay
2. **Screenshot 3** (Lesson in progress) — shows the mechanic in action
3. **Screenshot 4** (Shop) — shows the strategic depth
4. **Screenshot 5** (Grades) — shows the consequences and feedback loop
5. **Screenshot 1** (Title) — if space; establishes visual identity

**The Title screen can go first if branding is a priority.**

---

## Notes

- Do **NOT** use screenshots from the "EduSystems prototype" (the old HTML/JS version)
- All screenshots must be from **EDUSystem** (the current Godot 4.7 project)
- Keep a consistent visual style across all shots (same room layout, same classroom state)
- Avoid screenshots of debugging features, cheats panel, or tutorial overlays unless they're core to the pitch

