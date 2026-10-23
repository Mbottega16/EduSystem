#!/bin/bash
# Double-click this to play EduSystem.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path "$HERE"
