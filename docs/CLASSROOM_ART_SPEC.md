# EduSystem — Classroom Aesthetics & Generative Art Specification

> **Purpose:** Detailed production guide, asset matrix, and generative AI prompt guardrails for transforming EduSystem into an authentic classroom simulator across 4 School Stages (Elementary, Middle, High, College) and 5 Core Subjects, featuring the **Floor Layering & Walk-Through Rugs System**.

---

## 1. The Core Innovation: Floor Layering & Walk-Through Rugs

In a real classroom, rugs define zones, and furniture sits **on** them. In standard tile grids, if a rug occupies a tile as a solid obstacle, players are forced to scatter furniture awkwardly around it in the walking aisles.

### The Floor Layering Architecture:
1. **Passable Floor Underlay (`layer: "underlay"`):**
   - Rugs, carpet tiles, and floor splat mats have **zero collision** (`walkable: true`).
   - Teachers and students walk across them smoothly with no deceleration or pathing bottlenecks.
2. **Furniture Stacking (`can_stack: true`):**
   - Any physical item—a wooden stool, floor cushion, reading lamp, student desk, or low bookshelf—can be placed **directly on top of a rug tile**.
   - Godot depth-sorting (`y_sort_enabled = true`) ensures furniture and characters render naturally above the rug graphics.
3. **Zone Formation (Synergy Buff):**
   - When complementary items are placed on or adjacent to a themed rug, they automatically snap into an official **Learning Center** (e.g. *Reading Nook*, *Discovery Lab*, *Creation Station*), activating a subtle ambient glow and a passive pedagogical perk.

---

## 2. Gemini Generative Art Guardrails (The LimeZu Aesthetic Formula)

Generative AI models easily drift toward generic 3D renders, high-resolution digital illustrations, or oversaturated "retro" pixel art. To ensure every generated asset fits seamlessly alongside the official **LimeZu Modern Interiors & Office** packs, adhere strictly to these six visual rules:

### Rule 1: 3/4 Oblique Top-Down Perspective
- **Camera Tilt:** Exactly ~45° oblique top-down perspective (standard 16-bit RPG / Stardew Valley / Pokemon Gen 3–4 style).
- **Surface Visibility:** Both the **top surface** and the **front face** of objects must be clearly visible. 
- Side surfaces are drawn in shadow; vertical wall-hung items are front-facing flat with slight drop shadows.
- **Never** render in isometric angle (diagonal 30° diamond grid), true bird's-eye 90° overhead, or 3D perspective.

### Rule 2: Grid Scale & Tile Geometry
- **Base Grid:** All assets are authored on a **16×16 art-pixel grid** (which Godot renders at doubled 32×32 pixel scale):
  - **Single Tile (1×1):** 16×16 px base (stool, microscope, potted plant, trash bin).
  - **Tall Single Tile (1×1 high):** 16×24 or 16×32 px (floor lamp, bookshelf, skeleton model).
  - **Wide Bench (2×1):** 32×16 px base (lab table, study desk, cubby unit).
  - **Medium Area Rug (2×2):** 32×32 px base (calm corner mat, science zone carpet).
  - **Large Classroom Rug (3×2 or 3×3):** 48×32 or 48×48 px base (ABC alphabet rug, world map rug).

### Rule 3: The 1px Cool Slate Keyline (`#3a3a50`)
- **Outer Silhouette:** Every physical object must be bordered by a continuous 1-pixel dark outline in the cool slate family:
  - **Primary Keyline:** `#3a3a50` (RGB: 58, 58, 80).
  - **Outline Family (internal seams & joints):** `#46465e`, `#565972`, `#6c5981`.
- **Absolute Bans:** **NEVER** use pitch black (`#000000`). **NEVER** use warm brown outlines. The cool slate keyline is LimeZu’s most recognizable signature.

### Rule 4: Palette & Color Harmony
- Colors must be soft, cozy, and desaturated, matching `tools/limezu_palette.json`:
  - **Woods:** Warm honey oak (`#d49b6a`), natural pine (`#e0b882`), and dark mahogany (`#8b5b43`).
  - **Classroom Metal & Slate:** Soft gray-blues (`#94a3b8`, `#64748b`), tarnished brass (`#c49a45`).
  - **School Plastics & Textiles:** Muted pastel teal (`#5eead4`), warm sunflower yellow (`#fde047`), dusty rose (`#f43f5e`), and chalk green (`#34d399`).
- **No Neon:** Avoid pure RGB primaries, radioactive greens, or harsh digital glows.

### Rule 5: Per-Surface Form Shading
- Light source is **Top-Left**:
  - Horizontal top surfaces are brightest (highlight tone).
  - Front vertical faces are mid-tone.
  - Right and bottom edges carry the shadow tone.
- **Dark Plank Seams:** Wood planks or panel joints are drawn with a distinct 1–2px dark shadow crevice, giving wooden desks and tables tactile structure rather than flat coloring.
- **Texture Grain:** Large flat surfaces (like rugs and tabletops) carry subtle, curated pixel flecks/noise rather than perfectly flat fills.

### Rule 6: Clean Edges & Transparent Background
- Crisp, hard-edge pixels only. **Zero antialiasing, zero gaussian blur, zero soft alpha halos**.
- Deliver on a transparent background (or solid `#FF00FF` magenta chroma-key for clean automated cutout).

---

## 3. Master Gemini Art Generation Prompt Template

When generating missing assets with Gemini or the image subagent, use this structured prompt:

```text
[TASK]: 16-bit pixel art asset for an educational management simulation game.
[ITEM]: {Detailed Description of Item}
[STYLE]: Authentic 16-bit Japanese RPG pixel art matching LimeZu Modern Interiors.
[CAMERA]: 3/4 top-down oblique view (camera tilted 45 degrees looking down, showing both the top horizontal surface and the front vertical face).
[OUTLINE]: Clean 1-pixel outer keyline outline in dark cool slate-blue (#3a3a50). NEVER use pure pitch black (#000000).
[SHADING]: Crisp per-surface lighting from top-left. Top faces are highlighted, front faces are mid-tone, right sides in soft shadow. Distinct dark joint lines between planks/panels. Subtle speckle texture on large surfaces. No blurry gradients, no antialiasing, no pillow shading.
[COLORS]: Soft, cozy educational palette from the LimeZu Modern Interiors palette: warm honey oak woods, muted slate metals, soft pastel textiles.
[DIMENSIONS]: {Width}x{Height} art pixels on a 16px tile grid.
[BACKGROUND]: Perfectly solid flat magenta background (#FF00FF) with crisp, razor-sharp pixel edges for automated alpha cutout.
```

---

## 4. Item Catalog & Production Matrix

### Stage 1: Elementary School (Ages 5–10)
*Theme: Tactile, warm, primary colors, visual learning, meltdown-prevention.*

| Item ID | Display Name | Grid Size | Layer / Type | Production Source | Gemini Generation Brief |
|---|---|---|---|---|---|
| `rug_alphabet_circle` | Alphabet Storytime Rug | 3×3 (48×48) | Underlay (Passable) | **GENERATE (Gemini)** | Large circular classroom reading rug with a ring of colorful alphabet letters around the perimeter and a cheerful smiling sun in the center. |
| `reading_rocking_chair` | Teacher's Rocking Chair | 1×1 (16×24) | Solid Seating | **GENERATE (Gemini)** | Cozy curved wooden rocking chair made of warm honey oak with a soft padded red cushion on the seat. 3/4 perspective. |
| `picture_book_ledge` | Low Picture Book Display | 2×1 (32×24) | Solid Surface | **GENERATE (Gemini)** | Low two-tier wooden front-facing book ledge displaying colorful illustrated children's picture book covers facing forward. |
| `bug_hatching_cage` | Butterfly Hatching Net | 1×1 (16×24) | Solid Surface | **GENERATE (Gemini)** | Cylindrical green mesh pop-up butterfly habitat cage with leafy twigs inside and small colorful butterflies resting on the mesh. |
| `counting_bears_tray` | Plastic Counting Bears | 1×1 (16×16) | Tabletop / Prop | **GENERATE (Gemini)** | Wooden sorting tray holding small brightly colored plastic toy counting bears (red, blue, yellow, green) grouped in divided compartments. |
| `art_splat_mat` | Washable Splat Mat | 2×2 (32×32) | Underlay (Passable) | **GENERATE (Gemini)** | Flat vinyl floor splat mat in light yellow with playful, colorful paint splatters and handprints scattered across the surface. |
| `playdough_table` | Modeling Dough Table | 2×1 (32×16) | Solid Surface | **COMPOSE / RETINT** | Retint existing `side_table.png` with colorful tubs of dough and plastic rolling pins. |
| `abacus` | Wooden Bead Abacus | 1×1 (16×16) | Solid Prop | **EXISTING ASSET** | Already in `art/abacus.png`. |
| `art_easel` | Dual-Sided Art Easel | 1×1 (16×24) | Solid Prop | **EXISTING ASSET** | Already in `art/art_easel.png`. |
| `cubby_row` | Kindergarten Cubby Unit | 2×1 (32×32) | Solid Storage | **GENERATE (Gemini)** | Wooden cubby shelf unit with 4 open square compartments, each holding a colorful children's backpack, with coat hooks above. |

---

### Stage 2: Middle School (Ages 11–13)
*Theme: Hands-on exploration, collaborative tables, structured discovery, social dynamics.*

| Item ID | Display Name | Grid Size | Layer / Type | Production Source | Gemini Generation Brief |
|---|---|---|---|---|---|
| `middle_science_bench` | Student Science Lab Table | 2×1 (32×20) | Solid Surface | **GENERATE (Gemini)** | Sturdy dark-wood school science workstation table with a starter brass compound microscope and specimen jars on top. |
| `topographical_globe` | Raised-Relief Desk Globe | 1×1 (16×20) | Tabletop / Prop | **GENERATE (Gemini)** | Detailed desk globe mounted on a bronze meridian stand showing colorful green/brown continent topography and blue oceans. |
| `wall_timeline_banner` | Historical Timeline Scroll | 3×1 (48×16) | Wall Mounted | **GENERATE (Gemini)** | Horizontal parchment-colored wall banner showing an illustrated chronological timeline with tiny icons of ancient pyramids, castles, and ships. |
| `robotics_starter_kit` | Programmable Robotics Kit | 2×1 (32×16) | Solid Surface | **GENERATE (Gemini)** | Low workshop table with an assembled Lego-style wheeled rover robot, small tool caddy, and a laptop with code blocks on screen. |
| `drafting_craft_table` | Student Drafting Desk | 2×1 (32×20) | Solid Surface | **GENERATE (Gemini)** | Slanted wooden drafting desk with a metal T-square ruler, architectural grid paper roll, and a clip-on task lamp. |
| `paperback_bookshelf` | Middle-Grade Novel Shelf | 1×1 (16×32) | Solid Storage | **EXISTING / RETINT** | Adapt `art/bookshelf.png` with paperbacks arranged vertically in varied colors. |
| `rock_fossil_tray` | Rock & Fossil Specimen Tray | 1×1 (16×16) | Tabletop / Prop | **EXISTING ASSET** | Already in `art/rock_tray.png`. |
| `microscope` | Compound Microscope | 1×1 (16×16) | Tabletop / Prop | **EXISTING ASSET** | Already in `art/microscope.png`. |
| `graphing_grid_board` | Chalkboard Graphing Grid | 2×1 (32×24) | Wall Mounted | **GENERATE (Gemini)** | Wall-mounted green chalkboard pre-printed with a white Cartesian coordinate grid and an plotted parabolic curve. |

---

### Stage 3: High School (Ages 14–18)
*Theme: Departmentalized, rigorous, scientific chemistry, Socratic discussion, sleepiness.*

| Item ID | Display Name | Grid Size | Layer / Type | Production Source | Gemini Generation Brief |
|---|---|---|---|---|---|
| `chem_lab_bench` | Chemical Resistant Lab Station | 2×1 (32×24) | Solid Surface | **GENERATE (Gemini)** | Heavy black epoxy resin laboratory workbench with a central stainless steel goose-neck sink faucet and dual brass gas valves. |
| `bunsen_glassware_rack` | Bunsen Burner & Flask Rack | 1×1 (16×20) | Tabletop / Prop | **GENERATE (Gemini)** | Test tube rack with glass vials containing colorful chemical liquids, an Erlenmeyer flask, and a small metal Bunsen burner with a tiny blue flame. |
| `debate_podium` | Socratic Debate Lectern | 1×1 (16×24) | Solid Fixture | **GENERATE (Gemini)** | Dark walnut debate lectern with an angled speech paper rest, small brass microphone, and a school seal carved on the front panel. |
| `printer_3d_station` | 3D Printing Enclosure | 2×1 (32×24) | Solid Surface | **GENERATE (Gemini)** | Clear acrylic enclosed 3D printer running on a utility table, with a visible spool of blue filament and a printed geometric cube inside. |
| `periodic_table_wall` | Large Periodic Table Banner | 3×1 (48×20) | Wall Mounted | **GENERATE (Gemini)** | Large detailed classroom wall chart displaying the complete Periodic Table of Elements in color-coded chemical family columns. |
| `graphing_calc_dock` | Graphing Calculator Dock | 1×1 (16×16) | Tabletop / Prop | **GENERATE (Gemini)** | Desktop charging organizer holding 10 black handheld graphing calculators with bright blue accents. |
| `seminar_table_corner` | Socratic Discussion Table | 2×2 (32×32) | Solid Surface | **COMPOSE** | Modular oak seminar table composed of interlocking 16×16 corner and straight desk segments. |
| `vote_box` | Student Voting Ballot Box | 1×1 (16×16) | Solid Prop | **EXISTING ASSET** | Already in `art/vote_box.png`. |

---

### Stage 4: College / University (Higher Ed)
*Theme: Independent research, specialized equipment, quiet study carrels, professional mastery.*

| Item ID | Display Name | Grid Size | Layer / Type | Production Source | Gemini Generation Brief |
|---|---|---|---|---|---|
| `fume_hood` | Laboratory Chemical Fume Hood | 2×1 (32×32) | Solid Fixture | **GENERATE (Gemini)** | Professional tall stainless-steel fume hood with a sliding tempered glass sash window, interior lighting, and exhaust ventilation duct on top. |
| `centrifuge_bench` | Digital Centrifuge Station | 2×1 (32×20) | Solid Surface | **GENERATE (Gemini)** | Clean white research counter with a round benchtop centrifuge unit, digital LCD display, and a micro-pipette rack. |
| `research_carrel` | Oak Study Carrel Desk | 1×1 (16×28) | Solid Seating/Desk | **GENERATE (Gemini)** | Private library study carrel desk with high oak privacy partitions on three sides, an integrated overhead book shelf, and a warm task light. |
| `sliding_slate_board` | Double-Sliding Slate Board | 3×1 (48×24) | Wall Mounted | **GENERATE (Gemini)** | Wall-mounted academic double-tiered sliding black slate chalkboard covered in dense chalk calculus equations and geometric proofs. |
| `archival_terminal` | Microfilm / Data Terminal | 1×1 (16×20) | Tabletop / Prop | **GENERATE (Gemini)** | Vintage university research microfiche reader machine with a glowing curved greenish CRT screen and paper spool reels. |
| `cnc_mill_station` | Desktop CNC Milling Machine | 2×1 (32×24) | Solid Surface | **GENERATE (Gemini)** | Compact enclosed desktop CNC milling machine with an emergency stop button, transparent safety shield, and routed wooden block. |
| `law_library_shelf` | Heavy Leather-Bound Shelf | 1×1 (16×32) | Solid Storage | **COMPOSE / RETINT** | Retint existing `art/bookshelf.png` with rich dark leather bindings, gilded spines, and brass corner plates. |

---

## 5. Automated Post-Processing Pipeline (`tools/lz_conform.py`)

Whenever Gemini generates a raw sprite image, it must pass through the automated conformance pipeline before landing in the game engine:

```bash
# Example: Conforming a newly generated Alphabet Circle Rug (3x3 tiles = 48x48 art-pixels)
python tools/lz_conform.py shots/gen_art/raw_rug_alphabet.png art/rug_alphabet_circle.png --grid 48x48 --x2

# Example: Conforming a Chemical Lab Bench (2x1 tiles = 32x24 art-pixels)
python tools/lz_conform.py shots/gen_art/raw_chem_bench.png art/chem_lab_bench.png --grid 32x24 --x2

# Re-import into Godot engine:
python tools/reimport_art.py
```

### What `lz_conform.py` Automatically Enforces:
1. **Background Removal:** Clips away flat magenta (`#FF00FF`) or white backdrops into clean PNG transparency.
2. **Palette Quantization:** Snaps every pixel to the nearest exact color in `tools/limezu_palette.json` (192 authentic tones).
3. **Keyline Application:** Automatically traces the outer silhouette and applies the signature `#3a3a50` cool slate outline.
4. **Doubling Scale (`--x2`):** Scales the 16px tile art up to Godot's doubled 32px display resolution with zero distortion (Nearest Neighbor).
