@echo off
REM Plays an entire twenty-day term through the REAL buttons, at raised
REM speed -- podium, teach, end lesson, bell, every day, twenty times --
REM and checks it actually reaches the exam.
REM
REM This had no launcher at all; running it meant typing the command by
REM hand. playtrace.gd proves one day works. This is the only thing that
REM proves twenty of them in a row reach the thing that resolves them.
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --path "%PROJECT%" res://tools/playterm.tscn
pause
