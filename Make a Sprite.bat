@echo off
REM Make a new character: pick a palette, see it, put it in the game.
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

"%GODOT%" --path "%PROJECT%" res://tools/spritegen.tscn
