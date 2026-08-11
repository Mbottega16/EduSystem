@echo off
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

REM Plays whole terms headlessly under four player policies and prints the
REM curves. This is how the balance is checked without playing it.
"%GODOT%" --headless --path "%PROJECT%" res://tools/sim.tscn -- 24
echo.
pause
