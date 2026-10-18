# Art catalog

Every PNG in `art/`, grouped by what draws it and how it's used. Generated
by hand against the live `art/` folder on 2026-08-20 — if this drifts,
`tools/check_docs.py` doesn't currently check it (nothing here is a
numeric claim), so re-sweep it by eye after an art pass rather than
trusting it's still accurate.

> **Provenance, 2026-10-02.** Most of what this catalog describes as drawn by
> `make_art.py` / `make_items.py` is now **LimeZu's art**, imported by
> `tools/import_limezu.py` (props/hats, `limezu_manifest.json`), `limezu_room.py`
> (the 18 `tile_*`), `limezu_chars.py` (the 17 character sheets and 16 busts,
> `limezu_cast.json`) and `limezu_ui.py` (`bubble_q`, `ui_frame`). `python tools/import_limezu.py
> --list` prints every owned sprite and where it came from. The generators below
> stand down for those names and still draw everything else: **still procedural** --
> the book and its page turns, the logo and title backdrop, the exterior backdrop tile,
> `shadow`, `dust`, `paper`, the two floor-mess sprites, the bow
> and mortarboard hats, the subject icons and mood faces, and 8 shop items (maths_tiles,
> abacus, microscope, sound_cards, number_line, rock_tray, vote_box, season_wheel).
> Credit to limezu.itch.io is a licence condition and is on the credits page.
>
> **Free packs, 2026-10-08.** `tools/import_free.py` (`free_manifest.json`) owns the
> sprites taken from free packs that are not LimeZu's: `rocking_chair`, `hammock_chair`,
> `window_seat`, `low_shelf` (Midcentury Modern Furniture, 0_mem0ry), and `sand_timer`,
> the waving `state_flag` (+ `_anim`, which `winners_flag` also plays) and the weather
> particles `fx_rain_anim`, `fx_snow_anim`, `fx_sparkle_anim` (Ninja Adventure, CC0).
> The same pass moved more onto LimeZu, much of it animated: `terrarium` (the pack's frog
> in a mossy tank), `server_rack`, `cuckoo_clock` (seeded on the wall in place of the
> plain clock), `teacher_coffee` (a steaming mug on the teacher's desk), `desk_fan` (a
> pedestal fan whose grille flickers as it spins), `pot_of_pens` and `chalk_border`.
> A second pass animated five more from stills or LimeZu's own sheets: `globe` (turns),
> `computer` (a monitor and keyboard, its page scrolling), `paper_mobile` (drifts on its
> hook), `telephone` (message light blinks) and `robot_kit` (its face light pulses).
> Thirteen shop items now move; the suite checks every strip's frames really differ.
> The room itself: sunlight lies on the floor under each window (drawn, not art --
> `RoomBuilder.build_sunlight`, gone on wet and cold days) with dust drifting
> through it, and on someone's birthday three of LimeZu's party balloons
> (`balloon_red`, `balloon_blue`, `balloon_yellow`, + `_anim`) bob over the
> teacher's desk. Everyone blinks: LimeZu's idle-row blink is baked into the
> character sheets as columns 16-17.
>
> **The back wall, 2026-10-18.** The bell and the reward poster are LimeZu's now: `bell` is
> the school intercom on the wall (jail#124) that rings the end of the day, and `ad_poster`
> (+ `_anim`, 57 frames) is the pack's advertising screen cycling its adverts. New:
> `treat_shelf` (three jars, kitchen#127 -- the treats used to float round the locker),
> `curriculum_poster` (the alphabet poster with its last row of letters left off: the
> curriculum's own fixture, so it is not the shop's Letter Frieze twice), `butterfly_fly`
> (+ `_anim`, the window butterfly in flight) and `window_open` (`limezu_room.py`: the
> window opened, sky and trees through it, which the butterfly flies out of).
> `teacher_desk` has its pencil pot painted out (the manifest's new `fill`), and the window
> quarters sit two art pixels higher, clear of the skirting.
> The other spaces caught up: the hallway (`hallway.gd`) and the mentor's room
> (`mentor_room.gd`) were flat dark rectangles with props on them. Both are now
> painted from the classroom's own tiles -- walls, floor, skirting, the door --
> and the corridor's top wall is lined with lockers, boards, a clock, a plant, a
> water cooler, coat hooks and a fish tank that swims.
> Other days put something on the teacher's desk, that day only
> (`RoomBuilder.EVENT_DESK`): a `snow_globe` (+ `_anim`, its snow swirling) on a
> cold snap, `ice_cream` in a heatwave, a `tissue_box` when half the class has a
> bug, a `desk_ball` on sports day, `cash_bills` when a budget or grant comes
> through, a `donut_plate` on parents' evening and a `flower_vase` for a new face
> -- all LimeZu's. The `book_stack` for the book fair is the one exception: no
> pack draws books lying flat, so it is hand-drawn in his palette and keyline
> (`tools/sprites/book_stack.txt`, every art pixel doubled).
> The hallway's trophy case is LimeZu's museum vitrine made long enough for six
> (`trophy_case`: its left end, its middle three times, its right end, with the
> bar across its front taken out -- the importer's `parts` and `rows`), and
> `trophy_case_glass` is only its glass, drawn back over the cups inside
> (`glare_over`). The cups: `trophy_gold`, `trophy_silver`, `trophy_bronze`,
> `trophy_gold_silver`, `trophy_gilt`, `trophy_grand`, one per boss (the `art` key
> in `scripts/data/trophies.gd`). The principal's office adds `principal_desk`,
> `exec_chair`, `office_chart`, `office_art` and `office_plant`, and puts the
> principal's own sheet (`principal.png`) to use: she sits at her desk.
> The teachers you hire have faces now: `staff_a` .. `staff_d`, four adult sheets
> baked from `limezu_cast.json` (no portraits), picked by name (`Staff.art_for`)
> and seen when you walk into a room you hold (`visit_room.gd`).
> Spaces off the corridor wear their own floor and walls: `tools/limezu_room.json`
> `looks` names six more Room Builder floor + wall pairs (`office`, `room_a` ..
> `room_e`), each building the same 18 room tiles again as `tile_*_<look>` (108
> PNGs). The principal's office is dark wood under a cream-and-green wall; each room
> you hold takes the next room look in turn (`RoomBuilder.ROOM_LOOKS`).

## Characters — animated sheets (`tools/make_art.py::make_character`)

One PNG per character, 4 rows of 32&times;48 cells. Procedural characters
(`make_art.py`) are 288&times;192: 9 columns (`hframes=9`). LimeZu characters
(`limezu_chars.py`) are 576&times;192: the same 9 columns plus the pack's own
six-frame walk in columns 9-14, the slump in 15, and (Oct 2026) the standing and
seated frames with the eyes shut in 16-17 -- LimeZu's idle row blinks, and
`Actor.tick_blink()` shows it for a beat every few seconds. `Actor` reads the
column count off the texture width, so every width plays. Same layout for everyone because a
character is a palette through one shared `draw_char()`, not separate artwork.

*(Sept 2026, the pixel-grid pass.)* Each frame is BUILT at 32&times;48
for the facial detail, then quantised to 16&times;24 and `scale2x`'d back
before it is stored — the exact pipeline every tile and every furniture
item uses (16 art-px per tile, Scale2x to 32). The cast used to be the
one thing drawn straight at 32&times;48, so a teacher's pixels were half
the size of the desk beside them. The frame, the sheet and the on-screen
size are all unchanged; only the texel size is, and it now matches the
set. The fine face survives only in the portrait bust below.

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

A palette (`CHARACTERS` in `tools/make_art.py`) still has just the
original required keys (`hair`/`hair_d`, `shirt`/`shirt_d`, `legs`,
`shoe`, `long_hair`, `skirt`), but *(Sept 2026, the art overhaul)* can
say a lot more, each with a safe default so an old entry keeps drawing
unchanged: `hair_style` (one of `HAIR_STYLES` -- short/long/curly/spiky/
bob/bun/buzz/ponytail), `skin` (a name from `SKINS` or a raw `(r,g,b)`),
`glasses` (bool), `pattern` (one of `PATTERNS` -- plain/stripes/
dungarees/collar/tie/cardigan/lanyard; `tie`/`cardigan`/`lanyard` are the
adults' cues, the rest are the kids'), and `sleeves` ("long" or "short").
Every frame also gets `rim_light()` -- lit upper-left, shaded
lower-right -- the same shading rule `finish()` gives furniture (see
below), so a character and the desk they are standing next to agree
about where the window is.

## Portraits (`tools/make_art.py::make_portrait`)

One 96&times;96 transparent bust per `CHARACTERS` entry --
`portrait_player.png`, `portrait_student_a.png`, and so on -- for a
future HUD bio/mascot panel that wants an actual face rather than a
32&times;48 sheet frame at desk distance. *(Sept 2026, the art
overhaul.)* Not wired into any scene yet: drawing the busts was the art
pass's job, wiring one into a panel is a UI change and stayed out of
scope. `tests/run.gd::test_portraits()` is the only thing currently
checking they exist and are 96&times;96, since nothing on-screen loads
them yet either.

Excluded: `portrait_examiner.png`. The `examiner` character itself is
owned by a parallel session working in the main repo -- this pass did
not generate any art for it, portrait included.

## Cosmetics (`tools/make_art.py::HAT_ART`)

Worn on the head, at runtime, by whoever `Game.hat_id` names (currently
only the player) — see `scripts/data/cosmetics.gd` and
`Player.refresh_hat()`. Built at their full size for the shape, then
quantised and `scale2x`'d back — the same pixel-grid pass `draw_char()`
does per frame, so a hat sits on the same texel grid as the head under
it and the room around it. One flat icon per hat, not a 9x4 sheet —
chibi heads are round enough from every facing that a single sprite
reads convincingly regardless of which way the wearer is walking.

| file | hat | id |
|---|---|---|
| `cap.png` | a beanie, not a baseball cap — a brim read as a disconnected floating block at this scale | `cap` |
| `bow.png` | a bow-tie shape | `bow` |
| `wizard.png` | a pointed hat with a star tip | `wizard` |
| `mortarboard.png` | a graduation cap: a flat board and a hanging tassel (Oct 2026, style-referenced against the Modern Farm pack's shaded accessory hats -- the only one of the four with `rim_light` rather than a flat fill) | `mortarboard` |

Backgrounds (the other half of the same cosmetics hook) are flat
colours behind the portrait, not art files — see `Cosmetics.BACKGROUNDS`.

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

*(Sept 2026, the art overhaul.)* The walls are warm painted plaster, not
red brick -- one of the launch complaints was "heavy flat-red-brick
walls". `tile_wall_bottom` (the near wall) is the one exception: it is a
painted wood dado with a chair rail and a skirting board instead, since
that tile is the wall's whole visible height rather than a strip at the
foot of a taller plastered one. Windows carry a dusk sky gradient (cool
blue-violet up top, warm and glowing at the sill) and a curtain drawn
back to each outer edge. The door has a raised panel mould and a proper
round handle.

## Furniture & shop items (`tools/make_art.py`, `tools/make_items.py`)

Placed by the player via the shop/placement system
(`scripts/world/placement.gd`), one PNG per catalog entry in the items
data. Everything from `bookshelf.png` down is this category:

`bookshelf`, `lab_bench`, `art_easel`, `rug`, `plant`, `stool`,
`beanbag`, `bench`, `floor_cushion`, `side_table`, `cabinet`, `crate`,
`globe`, `abacus`, `microscope`, `whiteboard`, `reading_nook`,
`maths_tiles`, `music_corner`, `lamp`, `water_cooler`, `radiator`,
`coat_hooks`, `wall_clock`, `alphabet_frieze`, `fish_tank`,
`class_banner`, `pot_of_pens`, `library_ladder`, `computer`, `printer`,
`telephone`, `certificate`, `server_rack`, `backpack`, `sofa`,
`robot_kit`, `world_map`, `coffee`, `sticker_chart`, `bake_sale`,
`photocopies`, `desk`, `chair`, `table`, `podium`, `bell`,
`teacher_desk`, `noticeboard`, `supply_shelf`.

`tools/check_items.py` validates a new furniture entry against this data
before it's wired in.

*(Sept 2026, the art overhaul.)* Every generator-drawn piece above ends
in `finish(im)` rather than a bare `outline(im)` -- the furniture
equivalent of characters' `rim_light()`: the same lit-upper-left,
shaded-lower-right pass, at a gentler amount since flat furniture fills
band more visibly than a 32x48 character sprite. A hand-edited
`tools/sprites/<name>.txt` source (see its own `README.md`) still wins
over the generator when one exists; `bell`, `whiteboard`, `table`,
`side_table`, `lab_bench`, `art_easel`, `microscope`, `rug`, `radiator`,
`lamp`, `alphabet_frieze`, `reading_nook`, `class_banner`, and
`photocopies` had theirs deleted this pass once the generator's own
version, with `finish()` applied, read better than the hand source it
was standing down for.

## Daily room mess (`tools/make_items.py::MESS_ITEMS`)

Not purchasable and not in the shop's `ITEMS` catalogue — transient
clutter `scripts/world/classroom.gd` spawns fresh each day
(`Classroom._spawn_mess()`), placed by `RoomBuilder.build_mess()` on an
open floor tile that stays walkable. Cleaned via the ordinary E verb
(`scripts/interact/mess.gd`) — mashed, not held, `Balance.
mess_clean_presses` times — any time before the lesson, mid-lesson, or
after. Pays a flat `Balance.mess_clean_reward` coins on the last press
(`room_upkeep` in `data/balance.json`); still legwork, not a grade input,
so it touches nothing the balance contract measures.

| file | role |
|---|---|
| `mess_trash.png` | dropped paper/wrapper clutter |
| `mess_spill.png` | a floor spill, drawn without an outline so it reads as flat and wet rather than a solid object |

## UI & effects

| file | role |
|---|---|
| `logo.png` | title screen wordmark: filled chalk letters, an outline, a drop shadow, and a small chalk-apple motif *(Sept 2026)* |
| `title_bg.png` | title screen backdrop: the chalkboard the menu sits on (unchanged, for text contrast) plus a dusk classroom scene down the left margin the menu text never reaches -- a curtained window, a wood dado and floor, and the game's own `desk.png`/`chair.png` pasted in as dusk silhouettes *(Sept 2026)* |
| `bubble_q.png` | the "stuck" speech bubble over a student's head |
| `ui_frame.png` | LimeZu Modern UI Style 1 bamboo frame; the HUD draws it as a 9-slice round every overlay panel (centre clear) and as the cream item slot in the shop (centre filled) || `paper.png` | the carried-work icon |
| `poster_abc.png` | one hand-drawn one-off (`tools/sprites/poster_abc.txt`) — the exception to "everything is generated"; edited by hand in `Draw a Sprite.bat` / `Browse Art.bat`, not `make_art.py` |
| `shadow.png` | the shared runtime contact shadow every actor and placed item sits on |
| `dust.png` | a 2&times;2 particle |
| `book_open.png`, `book_open_blue.png`, `book_open_green.png`, `book_flip0..3.png` | the book the lesson plans and grade book (red), the furniture catalogue (blue) and the curriculum (green) are read out of, and four frames of a page turning (`tools/make_ui.py`). Rectangular boards and paper, textured rather than curved *(Sept 2026)* |
| `icon_ela.png`, `icon_math.png`, `icon_science.png`, `icon_social.png` | one subject mark per curriculum STRAND, 16&times;16 (`tools/make_ui.py::strand_icon`) — a book, a plus, a flask, a globe, each in that strand's own `STRAND_COLOUR` from `hud.gd`. Four, not forty: the row already carries the lesson's name, so what the mark adds is the family. Doubled with plain NEAREST, not `scale2x`, which rounded the plus into a diamond *(Sept 2026)* |
| `tile_backdrop.png` | what shows AROUND the room now the stretch aspect is `expand` — tiled behind everything by `main.tscn`'s Backdrop layer. A dim schoolyard (lawn + a soft hedge-line silhouette along the top edge standing in for trees) as of Oct 2026 — was a far corridor wall before that. Four tiles wide, not one, so the hedge silhouette varies before repeating |

Not built yet: a per-`Game.CRAFT_STYLES` icon, one per lesson-craft
style, the same shape as the four strand marks above (16&times;16, one
flat colour). `docs/CRAFT_STYLES.md` names the five styles, each one's
colour, and the `art/icon_craft_<stem>.png` naming a future pass should
follow — written down now so the stem a style resolves to doesn't drift
before the art exists to test it against.

## Which tool draws which category

| tool | scope |
|---|---|
| `python tools/make_art.py` | characters, cosmetics, room tiles, furniture, UI/effects — everything parametric |
| `Make a Sprite.bat` | one new *character*: writes the palette, draws the 9&times;4 sheet, imports it, registers the name |
| `Draw a Sprite.bat` / `Browse Art.bat` | hand-drawing editor for one-off art like `poster_abc.png`; also lets you open and re-edit any generated PNG in place |
| `tools/sprite_editor.html` | the dedicated character-sheet editor — the 9&times;4 walk/sit/pose grid specifically, standalone HTML, no Godot/Python needed |

After adding or changing any PNG, remember the seam that bites:
`godot --headless --path . --import`, or Godot has a file on disk it still
can't load.
