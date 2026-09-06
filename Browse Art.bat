@echo off
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

REM Bring the import cache up to date FIRST. The editor half of this tool
REM writes PNGs straight into art\, and standalone Godot does not re-import
REM on its own -- so without this the gallery shows yesterday's pixels.
REM Run from a console (not from inside Godot), --import is reliable; the
REM same call spawned from inside the tool is what used to hang it, which
REM is why Save no longer does it.
"%GODOT%" --headless --path "%PROJECT%" --import

REM Every image the game owns, on one screen. Also lists art nothing uses,
REM and art that code asks for but which does not exist.
start "" "%GODOT%" --path "%PROJECT%" res://tools/curator.tscn
