@echo off
REM Answer the Phase 1 gate: is a delegated term worth reading?
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

"%GODOT%" --headless --path "%PROJECT%" res://tools/schoolsim.tscn
echo.
pause
