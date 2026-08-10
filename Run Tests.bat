@echo off
REM Double-click to run the test suite.
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --headless --path "%PROJECT%" res://tests/run.tscn
echo.
if errorlevel 1 (echo TESTS FAILED) else (echo TESTS PASSED)
pause
