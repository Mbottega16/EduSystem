# PixelRoom

A pixel character you can walk around a room. That's the whole thing.

## Play

Needs Godot 4.7.x (standard, not .NET) — <https://godotengine.org/download>.

```
godot --path .
```

**Arrow keys** or **WASD** to walk.

## Redraw the art

Both images are drawn in code. Edit a colour or a shape and re-run:

```
python tools/make_art.py
```

- `art/player.png` — 64x96 sheet: 4 facings (down, left, right, up) x 4 walk frames of 16x24
- `art/room.png` — 320x176: 20x11 tiles of 16px, wall border, 2-tile-tall top wall

## Files

```
project.godot          window + pixel-art settings
scenes/main.tscn       entry point
scripts/main.gd        builds the room, its walls, and the player
scripts/player.gd      movement + walk animation
tools/make_art.py      draws both images
art/                   the two images
```
