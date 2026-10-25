# Art pipeline — every art tool, and the rules that go with them

**Read this before any art work.** Moved word for word from `CLAUDE.md` on 2026-10-24,
so `CLAUDE.md` stays short; its *Rules & Gotchas* section keeps the rules that apply on
every task (LimeZu names are protected, the packs are never committed, the seam that
bites, the font sizes). What every PNG is and which tool draws it: `docs/ART_CATALOG.md`.

Characters **are palettes** — one drawn model, recoloured. A new character
is a data-table edit, not new artwork. The shared model (`draw_char()` in
`tools/make_art.py`) is chibi — big head, small body — *(Aug 2026)*, one
proportion change that every existing and future palette inherits for
free, rather than each character needing its own redraw.

| | |
|---|---|
| `Make a Sprite.bat` | New character: writes the palette, draws it, imports it, registers the name |
| `Draw a Sprite.bat` | Hand-drawing editor (HTML): brush, fill, soften, flatten, retint, onion skin |
| `Browse Art.bat` | Every sprite at once; flags unreferenced and missing art; select one and press Enter to EDIT it in place. Tools: brush / eraser / line / rect / ellipse (`1`-`7`), a 1-16 square or round nib (`[` `]`), Filled toggle, Fill, Eyedrop; wheel zooms to the cursor, MMB pans, `M` cycles mirror off/X/Y/XY (across the character cell on a sheet); interpolated strokes, per-stroke undo. Runs `--import` before it opens. Saving writes a `tools/sprites/<name>.txt` source + the PNG -- it does NOT re-import (a `--import` child of the running Godot has hung and frozen the tool). |
| `Reimport Art.bat` | Runs `--import` from a console. Use it to make the GAME pick up a `Browse Art` edit -- Save no longer does. |
| `tools/forge_art.py` | **CLI art forge** -- regenerate ONE sprite into `art/` with tweaks, no GUI. `python tools/forge_art.py list` \| `... <name> key=value`. Characters take palette keys (`hair=#hex hair_style=curly glasses=1 skin=tan pattern=stripes`) and rewrite the sheet + portrait. Furniture/items take shared palette-colour keys plus `tint=#hex strength=0..1` and `swap=#from:#to`. `tiles floor_a=#hex …` rewrites the tile set. A sprite with a `tools/sprites/*.txt` hand source is refused (edit it in Browse Art) unless `--force`. Sibling of `tools/forge_audio.py`. |

**LimeZu art (Oct 2026) -- the owner's chosen look.** Most sprites now come from the
LimeZu *Modern Interiors / Office / UI* packs, read in place from their zips (the
licence forbids redistributing them, so they are never committed; they must be on the
machine for these tools, and only the finished sprites live in `art/`):

| | |
|---|---|
| `tools/import_limezu.py` | props, fixtures, hats -> `art/*.png`, driven by `tools/limezu_manifest.json`. `--list` shows every owned sprite and its source; `--check` verifies |
| `tools/import_free.py` | sprites from FREE packs that are not LimeZu's (Ninja Adventure, CC0; the Midcentury Modern Furniture set by 0_mem0ry), driven by `tools/free_manifest.json`, which records each pack's licence and credit. Same rules: packs found on the machine (`$FREE_ART_DIR`, `tools/free_art_path.txt`, Desktop/Downloads), never committed; every name it owns is protected like a LimeZu one. `--list`, `--check` |
| `tools/limezu_room.py` | the 18 room `tile_*.png`, driven by `tools/limezu_room.json`; `--preview room.png` shows the whole room first |
| `tools/limezu_chars.py` | the 17 character sheets + HUD busts from the Character/Portrait Generators, driven by `tools/limezu_cast.json`; `--preview`, `--check` |
| `tools/limezu_ui.py` | UI pieces: `bubble_q` (LimeZu frame + our glyph) and `ui_frame` (the bamboo border the HUD 9-slices round every full-screen panel, and the cream slot behind a shop item) |
| `tools/limezu_catalog.py` | browse the packs as labelled contact sheets (`props <theme>`, `kids`, `adults`, `animated`, `ui`, `room` ...) into `shots/catalog/`; the ids are the ones the JSON files take |
| `tools/shot_all.py` | screenshot every named screen (deterministic: it clears the scratch save per shot) and `compare` two runs side by side -- Windows/Mac/Linux |
| `tools/lz_conform.py` | snap ANY image to LimeZu's real palette + the #3a3a50 keyline (`--build-palette` once; `tools/limezu_palette.json` is colours only) |

Rules: a LimeZu-owned name is protected -- `make_art.hand_edited()` includes it, so the
generators and all three forges (`forge_art.py`, `forge_items.py`, `forge_ui.py` -- the
Master Forge's tabs shell out to them) stand down. To change one, edit its manifest/cast entry and
re-run the importer, **not** the PNG. The suite's `LIMEZU ART` section guards the credit
to limezu.itch.io on the credits page (a licence condition), that every owned PNG loads at
the doubled scale, and that none has a hand source fighting it. The **FREE** Modern
Interiors edition is non-commercial -- never use it. Compare images with
`limezu.same_pixels`, not `ImageChops...getbbox()` (alpha-only on RGBA).

**Speech is printed on paper (Oct 2026, the owner's ask).** Anything a person
SAYS -- the dialogue box, the corner tip and day beat, a bubble in the room --
is black ink on LimeZu's white panel (`art/ui_speech.png`, from
`tools/limezu_ui.py`) in **Galmuri9 at 20px** (`fonts/`, SIL OFL, subset to
Latin). The owner asked for "the same font as Pokemon": Nintendo's own font
cannot ship in a Steam game, and Galmuri is an OFL font drawn after the
Nintendo DS text. 20px is its 10px em doubled, so one of its pixels is one
pixel of the room's art -- keep it on a multiple of 10. Faces beside speech are
drawn at 72px (the 24px bust at exactly 3x, `expand_mode` IGNORE_SIZE so the
rect cannot grow back to 96), and blink from `portrait_<art>_talk.png`.

**The whole player-facing UI is in that font too** (owner's call, Oct 2026):
`fonts/ui_theme.tres` sits on the HUD's root, and the title screen, the floaters
and the overhead key badges set it themselves. Two sizes only -- `UI_SIZE` (20)
and `UI_SMALL` (10) in `hud.gd` -- and a test fails on any size that is not a
multiple of 10. Galmuri's line is ~2px taller than the old font's, so every
line spacing came down by 2 to keep the 11-row budget. The dev tools (Master
Forge, Browse Art) keep the default font.

**The verbs on offer are the coloured badges over the teacher's head, and
nothing else.** The bar along the bottom used to repeat them word for word,
clipped; it is now only ever the speech box. A held verb's badge says "hold"
and fills as you hold. **The mentor's three moves** (dash, answer all, the
call) sit bottom right as icons with their keys, each shown only while it can
be used, shaded while it recharges (`_update_move_bar()`).

**The seam that bites:** `make_art.py`, `forge_art.py` and `Browse Art`
write PNGs but do not import them, and Godot cannot load an unimported
texture. After adding or editing art run `godot --headless --path .
--import` (or `Reimport Art.bat`). The suite now *loads* every PNG rather
than checking it exists.
