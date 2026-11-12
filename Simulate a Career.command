#!/bin/bash
# Double-click to play whole careers headlessly and see how long a run lasts.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
GODOT="$(head -n 1 tools/godot_path.mac.txt 2>/dev/null)"
[ -x "$GODOT" ] || GODOT="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT" --headless --path "$HERE" res://tools/careersim.tscn -- all 3 10
read -n 1 -s -r -p "Press any key to close"
