# PixelRoom

An embodied classroom. **You are the teacher** — you walk the room, and the
walking is the game.

> **Status: complete and playable.** Every phase of the plan is in: the class
> files in and sits, you run a lesson, students get stuck and need reaching,
> grades come out of it, you set and mark homework, and you spend the coins on
> furniture that actually changes results.

## Play

Double-click **`Play PixelRoom.bat`**, or the **Play PixelRoom** shortcut on
the Desktop.

- **Arrow keys / WASD** — walk
- **E / Space** — do whatever the prompt at the bottom names
- **Esc** — back out of a menu

### A day

Each day has a **subject** (Maths, Reading, Science, …) shown on the status
strip and on the podium prompt.

1. The class files in through the door and takes its seats.
2. **Podium** — start the lesson. Everyone begins a piece of work.
3. A **progress bar** over each head fills as they work. They get stuck: a
   **"?"** appears, the bar turns red and *stops dead* until you walk over
   and help. This is the game — you cannot reach everyone, so you choose.
4. A finished sheet appears on each desk. **Collect** them, carry the pile to
   **your own desk**, hand it in.
5. **Podium** — end the lesson. Everyone is graded, and tonight's homework is
   set.
6. **Noticeboard** — the furniture shop. **Tab** swaps between the buy list
   and the sell list (selling gives back half). Ordering something drops you
   into a ghost cursor: arrows move it, **E** puts it down. It refuses any
   spot that would wall the class off from the door.
   To **move** something you already own, walk up to it and press E — same
   cursor, and it costs nothing.
7. **Bell** — end the day. You get paid, and homework comes back overnight to
   be collected and marked.

You interact with whatever you are **facing**, so approaching a desk from the
aisle picks that desk, not its neighbour.

### How grades work

**The room sets the floor, you set the ceiling.**

| | |
|---|---|
| Perfect furniture, never helped anyone | a **C** |
| Bare room, gave one student everything | a **C** |
| Both | an **A** |

Neither alone gets near the top. Furniture effects are **range-based from the
item's tile**, so *where* you put a bookshelf matters as much as owning one.
Those three rows are asserted in the test suite so tuning can't quietly break
the design.

The launcher just starts Godot on this folder. If Godot moves, edit the
`GODOT=` line at the top of the .bat. Godot 4.7.x (standard, not .NET) —
<https://godotengine.org/download>.

## Test

Double-click **`Run Tests.bat`**, or:

```
godot --headless --path . res://tests/run.tscn
```

218 assertions. Exits 0/1 so it can gate a commit.

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
