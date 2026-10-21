# EDUSystem — itch.io Listing Prep Checklist

**Status:** Ready for upload (copy complete, media guide prepared)  
**Date Prepared:** 2026-10-21  
**Last Updated:** 2026-10-21

This document is the checklist and summary for uploading EDUSystem to itch.io.

---

## What's Ready

### ✅ Copy & Text
All itch.io listing copy is prepared and located in `docs/ITCHIO_LISTING.md`:

- [ ] **Short Description** (60 chars) — Punchy one-liner
- [ ] **Project Description** (2–3 sentences) — For the page header
- [ ] **About Section** (features, target player, playtime)
  - What is EDUSystem
  - The pitch
  - Core features (5 major ones listed)
  - Target player profile
  - Playtime estimate
- [ ] **Content Warnings & Ratings**
  - Age rating: 7+
  - Content notes (no violence, mild frustration themes)
  - Accessibility info (colorblind, keyboard rebindable, etc.)
- [ ] **Tags** (for itch.io categorization)
- [ ] **Keywords** (for search/discovery)

**File:** `docs/ITCHIO_LISTING.md`

---

### ✅ Cover Art Specification
A detailed specification for the 460×215px capsule art:

- [ ] Dimensions and format specified (460×215px, PNG)
- [ ] Composition guidelines (title, tagline, classroom elements)
- [ ] Color palette documented (pulled from game assets)
- [ ] Typography specifications (pixel font, sizing, placement)
- [ ] Asset references listed (which `art/*.png` files to use)
- [ ] Build instructions for designer/owner
- [ ] Mockup and layout diagram provided
- [ ] Variations suggested (dark theme, alt layouts)

**File:** `docs/ITCHIO_COVER.md`

**Next step:** Someone (designer or owner) needs to build the 460×215px cover image using the specifications and existing game art assets.

---

### ✅ Screenshot Guide
A detailed walkthrough for capturing in-game screenshots:

- [ ] Recommended screenshot list (5–8 images)
  1. Title screen
  2. Classroom overview (day start)
  3. Lesson in progress
  4. Shop / furniture interface
  5. Grade report
  6. (Optional) Student chat/interaction
  7. (Optional) School delegation view
  8. (Optional) Exam setup
- [ ] Capture methods documented (headless Godot, direct play)
- [ ] Quality checklist provided
- [ ] File naming convention specified
- [ ] Post-processing guidelines
- [ ] Upload order recommended (for itch.io carousel)

**File:** `docs/ITCHIO_SCREENSHOTS.md`

**Next step:** Someone needs to capture the actual in-game screenshots using the guide.

---

## What Still Needs To Be Done

### ⏳ Capture In-Game Screenshots
**Owner action required.**

Using the guide in `docs/ITCHIO_SCREENSHOTS.md`:

1. **Start a game or use a save** near the start of day 1
2. **Capture 5–8 screenshots** showing:
   - Title screen
   - Full classroom view
   - Active lesson/teaching
   - Shop interface with items
   - Grade report or end-of-lesson summary
3. **Save to `shots/` directory** with consistent naming:
   - `shots/01_title.png`
   - `shots/02_classroom_overview.png`
   - `shots/03_lesson_in_progress.png`
   - `shots/04_shop.png`
   - `shots/05_grades.png`
   - (and optionally 06, 07, 08)
4. **Verify quality** against the checklist in the guide

**Tools available:**
- `Take a Screenshot.bat` — headless full-game screenshot
- `godot --headless --path . res://tools/title_shot.tscn -- out.png main` — title screen only
- Play the game directly and use the OS screenshot tool (Windows: Print Screen → paste into image editor)

---

### ⏳ Build the Cover Art (460×215px)
**Designer/owner action required.**

Using the specification in `docs/ITCHIO_COVER.md`:

1. **Create a new 460×215px image** (PNG, 72 DPI or 2x scale)
2. **Compose elements** from existing game art:
   - Title: **"EDUSYSTEM"** (pixel font, white, ~48px, dark outline)
   - Subtitle: **"Teach a class of eight"** (~14–16px)
   - Classroom diorama: teacher + 4–6 student portraits, simple desks
   - Decor: books, furniture silhouettes, or simple patterns on left/right
3. **Color palette:** Use warm cream background (`#F5E6D3`), skin tones from portraits, white text
4. **Test legibility** at 200px width (itch.io thumbnail size)
5. **Export as PNG** (no compression loss)
6. **Save to** `shots/ITCHIO_COVER.png` or `docs/ITCHIO_COVER.png`

**Assets to reference:**
- `art/logo.png` — the EDUSystem logo
- `art/player.png` — teacher spritesheet (pick a standing frame)
- `art/portrait_student_a.png`, `_b.png`, `_c.png` — student faces
- `art/book_stack.png` — for side decor
- `art/desk.png`, `art/chair.png` — furniture elements

**Tools available:**
- Godot (if compositing in-engine)
- Photoshop, GIMP, Aseprite, or any pixel-art editor
- Python/PIL script to composite PNGs (if automation preferred)

---

## How to Use This for itch.io Upload

Once all pieces are ready (copy, cover, screenshots):

1. **Go to itch.io** → Your games → EDUSystem → Edit (draft mode)
2. **Fill in the following fields:**
   - **Game title:** EDUSystem (or "EDUSystem — Classroom Management Sim" if space allows)
   - **Short description:** Copy from `ITCHIO_LISTING.md` → "Short Description"
   - **Description (main text):** Copy from `ITCHIO_LISTING.md` → "About Section"
   - **Game tagline** (if field exists): "Teach a class of eight"
   - **Tags:** Use the list from `ITCHIO_LISTING.md` → Tags
   - **Content rating:** See content warnings section (Age 7+)
   - **Mobility, Audio, Colorblind accessibility checkboxes:** Check as appropriate

3. **Upload media:**
   - **Cover image (capsule):** Upload the 460×215px cover built from the spec
   - **Screenshots:** Upload 5–8 images in the order recommended in the guide
   - **GIF/trailer** (optional): If a game trailer GIF exists, upload it

4. **Set pricing & availability:**
   - Free / pay-what-you-want / paid (owner's decision)
   - Release status (public, private, draft, etc.)

5. **Save and publish** (or keep as draft until owner confirms)

---

## File Reference Summary

| What | File | Status |
|---|---|---|
| **Copy & text** | `docs/ITCHIO_LISTING.md` | ✅ Done |
| **Cover spec** | `docs/ITCHIO_COVER.md` | ✅ Done |
| **Screenshot guide** | `docs/ITCHIO_SCREENSHOTS.md` | ✅ Done |
| **Cover image (460×215)** | `shots/ITCHIO_COVER.png` | ⏳ Needed |
| **Screenshots** | `shots/01_*.png` – `shots/05_*.png` (+ optional) | ⏳ Needed |

---

## Accessibility & Quality Notes

### Copy Quality
- All text follows "Simplified Technical English" guidelines
- No jargon or unexplained references
- Prose-based (no hidden numbers or decimals)
- British-flavoured English, plain and direct

### Visual Quality
- Pixel art maintained (no anti-aliasing or blurring)
- High contrast text for readability at small sizes
- Color palette consistent with game assets
- No animated GIFs or moving elements (unless intentional)

### Game Representation
- Screenshots show the real game, not edited or filtered versions
- Copy accurately reflects the game's mechanics and tone
- Warnings are honest (e.g., "grading you can fail" is accurate)
- No false promises or misleading marketing

---

## Contingencies & Backups

### If screenshots are hard to capture:
1. Use `Take a Screenshot.bat` with various screen names (listed in the .bat file's comments)
2. Run a game instance and use Windows' built-in screenshot tool (Windows+Shift+S)
3. Record a 5-second video and extract frames as PNG

### If cover design is needed quickly:
1. Use a simple title + solid background + game logo (minimal but functional)
2. Composite character portraits with Photoshop or GIMP from existing `art/*.png` files
3. Reference the mockup in `ITCHIO_COVER.md` for layout

### If copy needs tweaking:
1. All major sections are editable in `docs/ITCHIO_LISTING.md`
2. Tone is consistent; changing a few words won't break the vibe
3. Tags and keywords can be reordered based on itch.io's recommendation engine

---

## Sign-Off

**Prepared by:** Claude Code (Mosaic crew agent)  
**Date:** 2026-10-21  
**Ready for:** Founder to review and upload

**What the founder needs to do:**
1. ✅ Review the copy in `ITCHIO_LISTING.md` (may edit for tone/accuracy)
2. ⏳ Capture 5–8 in-game screenshots following `ITCHIO_SCREENSHOTS.md`
3. ⏳ Build the cover image (460×215px) following `ITCHIO_COVER.md`
4. ⏳ Upload all media + copy to itch.io draft
5. ⏳ Publish (or keep private until marketing is ready)

**Questions?** Check the referenced docs for detail. All specifications are self-contained and include examples, mockups, and step-by-step guides.

