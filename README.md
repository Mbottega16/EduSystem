# PixelRoom

A pixel character you can walk around a room. That's the whole thing.

## Play

Double-click **`Play PixelRoom.bat`**, or the **Play PixelRoom** shortcut on
the Desktop.

**Arrow keys** or **WASD** to walk. Close the window to quit.

The launcher just starts Godot on this folder. If Godot moves, edit the
`GODOT=` line at the top of the .bat. Godot 4.7.x (standard, not .NET) —
<https://godotengine.org/download>.

Note: the .bat must keep CRLF line endings or `cmd` mangles it; that is what
`.gitattributes` pins.

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
Play PixelRoom.bat     double-click launcher
art/                   the two images
```
