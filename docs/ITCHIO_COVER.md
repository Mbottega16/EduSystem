# EDUSystem — itch.io Cover Art (460 × 215 px)

## Design Specification

### Overview
A bright, welcoming pixel-art cover that conveys "teaching in a classroom" at a glance. The cover balances the game's grounded design philosophy with an inviting, readable appearance suitable for the itch.io storefront.

### Dimensions
- **Final cover:** 460 × 215 pixels
- **Aspect ratio:** 2.14:1 (landscape, itch.io "capsule" format)
- **Scale:** Must remain readable at thumbnail size (~200px wide)

### Composition & Layout

The cover is divided into three zones:

```
[LEFT (100px)]  [CENTER (260px)]  [RIGHT (100px)]
      |               |                  |
   DECOR        TITLE + TAGLINE       DECOR
      |               |                  |
```

#### Left & Right Zones (Decor) — 100px each
- **Purpose:** Frame the title and add visual interest
- **Content options (pick 2–3):**
  - Stack of books (from `book_stack.png` or similar)
  - A few students from `player.png` spritesheet (scaled 2-3x)
  - Furniture silhouettes (desk, chair from game assets, ~48px tall)
  - Curriculum poster corner or chalkboard edge
  - Apple icon from the `logo.png`
  - Color blocks in the game's palette (subtle background pattern)

#### Center Zone (Core Content) — 260px
- **Layout (top to bottom):**
  1. **Game title** (top 60px)
     - Text: **"EDUSYSTEM"** in all caps
     - Font: Pixel font, bold, white text with a 1-2px darker outline
     - Size: ~48px tall (scales the full width with small margins)
     - Background: Semi-transparent dark box or gradient (20–40% opacity dark overlay)
  
  2. **Subtitle/Tagline** (middle 40px)
     - Text: **"Teach a class of eight"** (or "A Classroom Management Sim")
     - Font: Smaller pixel font, white or light color
     - Size: ~14–16px
     - Styling: Lighter weight, possibly italic or subtle shadow
  
  3. **Visual accent** (bottom 115px)
     - A small diorama showing:
       - A simplified classroom layout (top-down view, ~80×50px)
       - 1 teacher sprite (scaled 3–4x from `player.png`, standing at front)
       - 4–6 student portraits (scaled 2–3x, seated at desks)
       - Simple desk/chair shapes in silhouette or low detail
       - Warm/neutral background color (cream, light wood)
     - **OR** a single large student portrait (scaled 6–8x) with the teacher in the corner

### Color Palette

Pull colors directly from the game's existing art:

- **Skin tones:** From student portraits (tans, browns: `#D4956C`, `#B8825F`)
- **Clothing:** Blues, greens, warm earth tones from character sheets
- **Background:** Warm cream (`#F5E6D3` or similar from game UI panels)
- **Text:** Pure white (`#FFFFFF`) with dark outline (`#3A3A50`, the LimeZu keyline)
- **Accents:** Apple red (`#E74C3C` or similar) for highlights

### Typography

- **Font:** Use a pixel-art font matching the game (Galmuri9 or similar)
- **Title:** Bold, uppercase, ~48px, white with 1–2px dark outline
- **Subtitle:** 14–16px, white or off-white, regular weight
- **Avoid:** Thin fonts, gradients, heavy shadows—they disappear at thumbnail size

### Artistic Guidelines

1. **Readability first.** The cover must be legible when scaled down to ~200px wide (itch.io thumbnail).
2. **Pixel-perfect.** Maintain crisp edges; no anti-aliasing or blur.
3. **Warmth.** The color palette should feel welcoming and educational, not cold or clinical.
4. **Depth hints:** Use subtle layering and overlapping to suggest a 3D classroom without perspective tricks that muddy the pixel grid.
5. **Whitespace:** Leave breathing room. The cover should not feel cramped.

### Specific Asset References

The following files are candidates for composition (paths relative to `art/`):

- **Characters:** `player.png` (teacher spritesheet, pick a standing frame)
- **Student portraits:** `portrait_student_a.png`, `portrait_student_b.png`, `portrait_student_c.png` (scale to ~32–48px face width)
- **Furniture:** `desk.png`, `chair.png` (scale to ~24–32px, may desaturate or outline)
- **Props:** `book_stack.png` (for left/right decor), `pencil.png` (if available)
- **Background:** Use a light, warm solid color or a simple pattern from existing UI panels

### Do Not Use

- Animated sprites (`.png.import` files, or anything marked `_anim`)
- Complex backgrounds that compete with text
- Gradients or effects that blur at small scale
- More than 3–4 distinct character/prop elements (visual noise)

### Build Instructions (for designer/owner)

1. Create a 460 × 215 px canvas, 72 DPI (or 2×scale for sharper pixel art, then downscale)
2. Fill background with warm cream or light wood color
3. Place title in the center-top with a subtle dark background box
4. Add left & right decor (books, student silhouettes, or simple furniture)
5. Compose a small classroom diorama in the lower-center using sprites from the game
6. Add white text label with the tagline
7. Export as PNG (no compression loss, or minimal)
8. **Test at 200px wide to ensure readability**

### Mockup Notes

A quick text-based mockup of the layout:

```
╔════════════════════════════════════════════════╗
║  📚                                       ✏️   ║
║                                              ║
║           🎮 EDUSYSTEM 🎮                    ║
║      Teach a class of eight                  ║
║                                              ║
║    👨‍🏫                                      ║
║   [DESK]  [DESK]  [DESK]                     ║
║   👦 [D]  👧 [D]  👦 [D]                     ║
║                                              ║
║                                              ║
╚════════════════════════════════════════════════╝
```

### Variations to Consider

1. **Dark background version** (for dark theme on itch.io)
   - Swap cream background to a darker tone
   - Swap white text to a lighter shade (cream/yellow)
   - Use the same sprite assets
   
2. **Classroom-centric version** (emphasizes the "room" aspect)
   - Larger diorama, smaller title
   - Show more desks and students
   - Less decor on left/right
   
3. **Character-focused version** (emphasizes the teacher/student relationship)
   - Large teacher portrait on left
   - 2–3 student portraits on right
   - Minimal furniture
   - Title overlaid on top

---

## Final Checklist

Before exporting:

- [ ] Title is legible at 200px wide
- [ ] Colors match the game's existing palette (no new hues)
- [ ] No anti-aliased edges; all pixels are crisp
- [ ] File size is reasonable (< 50 KB for PNG)
- [ ] Aspect ratio is exactly 460 × 215
- [ ] No animated or import-only assets used
- [ ] Text has sufficient contrast against the background
- [ ] Layout balances title visibility with visual interest

---

## Next Steps

1. **Option A (In-engine):** Use Godot or a pixel-art tool to composite sprites from the game into the final cover
2. **Option B (External tool):** Export the needed sprites and use Photoshop, GIMP, or aseprite to build the cover
3. **Option C (Screenshot approach):** Capture a classroom scene headless, crop and adjust to 460×215, overlay the title

