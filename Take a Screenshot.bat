@echo off
REM Double-click to screenshot the REAL game. Headless cannot see; this can.
REM Optional argument: a screen to open first --
REM   quiz  curriculum  unit_test  student  shop  room  staff  class_list
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --path "%PROJECT%" res://tools/shot.tscn -- "%PROJECT%\shot.png" 90 320 176 0 %1
echo.
echo Saved to %PROJECT%\shot.png
pause
