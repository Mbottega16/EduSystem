@echo off
REM Walk a real day and print what the game actually offers at each step.
REM Use this when the game says one thing and the tests say another.
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

"%GODOT%" --path "%PROJECT%" res://tools/playtrace.tscn
echo.
pause
