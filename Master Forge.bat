@echo off
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

REM Bring the import cache up to date first.
"%GODOT%" --headless --path "%PROJECT%" --import

REM Launch the Master Forge
start "" "%GODOT%" --path "%PROJECT%" res://tools/master_forge.tscn
