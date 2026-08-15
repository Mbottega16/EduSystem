@echo off
REM Stand at every landmark in every phase and print what is on offer.
REM Use this to spot anything offering nothing, or the wrong thing.
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

"%GODOT%" --path "%PROJECT%" res://tools/audit.tscn
echo.
pause
