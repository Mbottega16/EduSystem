# PixelRoom

An embodied classroom. **You are the teacher** — you walk the room, and the
walking is the game.

> **Status: Phases 0–1 complete, plus the classwork loop.** The class files in
> through the door and sits down; you assign work at the podium, they take
> five seconds to finish it, and you walk round collecting sheets and hand
> them in at your own desk. Grading, homework and buying items are still to
> come — see the plan for the remaining phases.

## Play

Double-click **`Play PixelRoom.bat`**, or the **Play PixelRoom** shortcut on
the Desktop.

- **Arrow keys / WASD** — walk
- **E / Space** — interact with whatever the prompt at the bottom names

The loop: walk to the **podium** and assign work → the class works for five
seconds → a sheet appears on each finished desk → walk to a desk to **collect**
it → carry the pile to **your own desk** and hand it in.

You pick up what you are facing, so approaching a desk from the aisle selects
that desk and not its neighbour.

The launcher just starts Godot on this folder. If Godot moves, edit the
`GODOT=` line at the top of the .bat. Godot 4.7.x (standard, not .NET) —
<https://godotengine.org/download>.

## Test

Double-click **`Run Tests.bat`**, or:

```
godot --headless --path . res://tests/run.tscn
```

85 assertions. Exits 0/1 so it can gate a commit.

**Never use `create_timer()` in a test.** `Engine.max_physics_steps_per_frame`
(default 8) clamps catch-up, so any main-thread stall desyncs simulation time
from wall-clock time and every timer-based assertion silently lies. Step
physics frames instead — `SPEED = 60` at 60Hz is exactly 1px per frame, so
movement assertions are integer arithmetic.

## Redraw the art

All art is drawn in code. Edit a colour or a shape and re-run:

```
python tools/make_art.py
```

Characters — each an 80x96 sheet: 4 facings (down, left, right, up) x 5 frames
of 16x24. Frames 0–3 are the walk cycle, **frame 4 is the seated pose**. All
nine come out of one drawing routine with different palettes; `long_hair` and
`skirt` flags separate them.

- `art/player.png` — the teacher
- `art/student_a.png` … `art/student_h.png` — eight students

Furniture is drawn in the room's 3/4 view. **The bottom row of pixels is where
the piece meets the floor** — that is the point the whole game positions and
depth-sorts by, and every sprite obeys it, including the seated pose.

- `art/chair.png` (16x18), `art/desk.png` (16x20), `art/table.png` (32x20)
- `art/room.png` — 320x176: 20x11 tiles of 16px, 2-tile-tall top wall

## Layout

```
project.godot              window, input actions, physics layers, Game autoload
scenes/main.tscn           Main > World (y-sorted) + UI (CanvasLayer)
scenes/actors/*.tscn       player and student, packed so $Sprite2D always resolves

scripts/autoload/game.gd   the run: day, coins, phase, roster, SEEDED rng
scripts/data/              StudentData (a RefCounted, not a Node), name pool
scripts/actors/actor.gd    shared walk + facing + seated pose
scripts/world/grid.gd      tile maths, occupancy, AStarGrid2D — the spatial authority
scripts/world/layout.gd    where the desks, podium, bell and door are
scripts/world/room_builder.gd  layout + state -> nodes
scripts/world/classroom.gd     the World root; builds and spawns

tools/make_art.py          draws every image
tests/run.gd               the suite
```

### Two rules worth knowing before editing

**Everything is positioned by where it meets the floor.** Not its centre. That
one convention is what makes y-sorting work with no special cases — a chair at
`seat_y - 1`, the student at `seat_y`, the desk at `seat_y + 16`, so the desk
occludes the student's lap. The 1px chair offset is deliberate: exact y ties in
Godot fall back to tree order, which is silently order-dependent.

**All randomness goes through `Game.rng`, which is seeded.** Never call the
global `randi()`/`randf()`. Without this the grading and homework tests can't
exist at all.
