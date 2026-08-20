# Art catalog

Every PNG in `art/`, grouped by what draws it and how it's used. Generated
by hand against the live `art/` folder on 2026-08-20 — if this drifts,
`tools/check_docs.py` doesn't currently check it (nothing here is a
numeric claim), so re-sweep it by eye after an art pass rather than
trusting it's still accurate.

## Characters — animated sheets (`tools/make_art.py::make_character`)

One 288&times;192 PNG per character: 9 columns &times; 4 rows of
32&times;48 cells (`Sprite2D(hframes=9, vframes=4)`), same layout for
everyone because a character is a palette through one shared
`draw_char()`, not separate artwork.

| file | who |
|---|---|
| `player.png` | the teacher (you) |
| `student_a.png` .. `student_h.png` | the eight starting/possible students |
| `inspector.png` | the inspector NPC |
| `principal.png` | the principal (tutorial mascot portrait elsewhere) |

Columns, left to right: **walk cycle** (stand, step, stand, step) ·
**sit** (col 5, `Actor.SIT_FRAME`) · **one-shot poses** (cols 6-9,
`Actor.POSE_HANDOFF/CHAT/JUMP/SAD`) played for a fixed beat and then
handed back to idle/seated. Rows: facing down, left, right, up.
`tools/sprite_editor.html` is the hand-editor for this exact 9&times;4
grid; `Make a Sprite.bat` generates a brand new character (new palette)
through `make_art.py` instead of hand-drawing one.

## Room tiles — auto-tiled at runtime (`tools/make_art.py` room section)

Not placed by hand; `scripts/world/room_builder.gd` picks among the
floor/wall variants per-tile so the room doesn't read as one stamped
texture repeated.

| file | role |
|---|---|
| `tile_floor_a0..a3`, `tile_floor_b0..b3` | floor variants, two families |
| `tile_wall_top0`, `tile_wall_top1`, `tile_wall_side`, `tile_wall_bottom` | wall faces |
| `tile_door_top`, `tile_door_bottom` | the doorway |
| `tile_window_l0`, `tile_window_l1`, `tile_window_r0`, `tile_window_r1` | window quarters |

## Furniture & shop items (`tools/make_art.py`, `tools/make_items.py`)

Placed by the player via the shop/placement system
(`scripts/world/placement.gd`), one PNG per catalog entry in the items
data. Everything from `bookshelf.png` down is this category:

`bookshelf`, `lab_bench`, `art_easel`, `rug`, `plant`, `stool`,
`beanbag`, `bench`, `floor_cushion`, `side_table`, `cabinet`, `crate`,
`globe`, `abacus`, `microscope`, `whiteboard`, `reading_nook`,
`maths_tiles`, `music_corner`, `lamp`, `water_cooler`, `radiator`,
`coat_hooks`, `wall_clock`, `alphabet_frieze`, `fish_tank`,
`class_banner`, `pot_of_pens`, `coffee`, `sticker_chart`, `bake_sale`,
`photocopies`, `desk`, `chair`, `table`, `podium`, `bell`,
`teacher_desk`, `noticeboard`, `supply_shelf`.

`tools/check_items.py` validates a new furniture entry against this data
before it's wired in.

## Daily room mess (`tools/make_items.py::MESS_ITEMS`)

Not purchasable and not in the shop's `ITEMS` catalogue — transient
clutter `scripts/world/classroom.gd` spawns fresh each day
(`Classroom._spawn_mess()`), placed by `RoomBuilder.build_mess()` on an
open floor tile that stays walkable. Cleaned via the ordinary E verb
(`scripts/interact/mess.gd`), held for a couple of seconds, any time —
before the lesson, mid-lesson, or after. Purely cosmetic legwork: it pays
no coins or XP and touches nothing the balance contract measures.

| file | role |
|---|---|
| `mess_trash.png` | dropped paper/wrapper clutter |
| `mess_spill.png` | a floor spill, drawn without an outline so it reads as flat and wet rather than a solid object |

## UI & effects

| file | role |
|---|---|
| `logo.png` | title screen wordmark |
| `title_bg.png` | title screen backdrop |
| `bubble_q.png` | the "stuck" speech bubble over a student's head |
| `paper.png` | the carried-work icon |
| `poster_abc.png` | one hand-drawn one-off (`tools/sprites/poster_abc.txt`) — the exception to "everything is generated"; edited by hand in `Draw a Sprite.bat` / `Browse Art.bat`, not `make_art.py` |
| `shadow.png` | the shared runtime contact shadow every actor and placed item sits on |
| `dust.png` | a 2&times;2 particle |

## Which tool draws which category

| tool | scope |
|---|---|
| `python tools/make_art.py` | characters, room tiles, furniture, UI/effects — everything parametric |
| `Make a Sprite.bat` | one new *character*: writes the palette, draws the 9&times;4 sheet, imports it, registers the name |
| `Draw a Sprite.bat` / `Browse Art.bat` | hand-drawing editor for one-off art like `poster_abc.png`; also lets you open and re-edit any generated PNG in place |
| `tools/sprite_editor.html` | the dedicated character-sheet editor — the 9&times;4 walk/sit/pose grid specifically, standalone HTML, no Godot/Python needed |

After adding or changing any PNG, remember the seam that bites:
`godot --headless --path . --import`, or Godot has a file on disk it still
can't load.
