@echo off
REM Walk a real day and print what the game actually offers at each step.
REM Use this when the game says one thing and the tests say another.
REM
REM A narrator, not a gate: a human reads the steps and decides what they
REM mean. "Play a Whole Term.bat" is the one with a verdict and an exit
REM code, and the one .githooks/pre-push runs.
REM
REM It used to paste the Godot path in by hand -- the one launcher that
REM did, while CLAUDE.md's file map claimed every launcher read it from
REM tools\godot_path.txt.
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  echo Edit tools\godot_path.txt to point at it.
  pause
  exit /b 1
)

"%GODOT%" --path "%PROJECT%" res://tools/playtrace.tscn
echo.
pause
