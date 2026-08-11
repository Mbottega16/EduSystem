@echo off
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

REM Every image the game owns, on one screen. Also lists art nothing uses,
REM and art that code asks for but which does not exist.
start "" "%GODOT%" --path "%PROJECT%" res://tools/curator.tscn
