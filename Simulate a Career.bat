@echo off
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

REM Plays whole careers headlessly, term after term, under three player
REM policies, and prints how long a run lasts for each. Usage for other
REM numbers: godot --headless --path . res://tools/careersim.tscn -- policy seeds max_terms
"%GODOT%" --headless --path "%PROJECT%" res://tools/careersim.tscn -- all 3 10
echo.
pause
