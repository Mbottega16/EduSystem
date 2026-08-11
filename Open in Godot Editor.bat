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

REM Opens the project in the Godot editor, where scenes and layout can be
REM nudged directly instead of by hand-editing .tscn text.
start "" "%GODOT%" --editor --path "%PROJECT%"
