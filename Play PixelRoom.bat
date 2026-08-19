@echo off
REM Double-click this to play PixelRoom.
setlocal

call "%~dp0tools\_godot.bat"

REM %~dp0 always ends in a backslash, and a quoted path ending in one
REM makes the closing quote look escaped, which breaks the argument.
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at:
  echo   %GODOT%
  echo.
  echo Edit tools\godot_path.txt to point at it, or download Godot 4.7
  echo ^(standard, not .NET^) from godotengine.org and put godot.exe there.
  pause
  exit /b 1
)

if not exist "%PROJECT%\project.godot" (
  echo Could not find project.godot next to this file.
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%PROJECT%"
