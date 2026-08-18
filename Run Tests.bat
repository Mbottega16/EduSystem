@echo off
REM Double-click to run the test suite.
REM Pass any argument to skip the pause, so it can be chained.
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  echo Edit tools\godot_path.txt to point at it.
  if "%~1"=="" pause
  exit /b 1
)

REM DO NOT TRUST ERRORLEVEL ALONE.
REM
REM A GDScript parse error makes Godot exit 0 while the suite never runs,
REM so this printed TESTS PASSED with no assertion count at all. Twice in
REM one session. The success LINE is the only proof it actually finished.
set "LOG=%TEMP%\pixelroom_tests.log"
"%GODOT%" --headless --path "%PROJECT%" res://tests/run.tscn > "%LOG%" 2>&1
set "CODE=%ERRORLEVEL%"
type "%LOG%"
echo.

findstr /C:"Parse error" "%LOG%" >nul && (
  echo TESTS FAILED - a script did not compile, so the suite never ran.
  if "%~1"=="" pause
  exit /b 1
)
findstr /C:"ALL PIXELROOM CHECKS PASSED" "%LOG%" >nul || (
  echo TESTS FAILED - no completion line. The suite did not finish.
  if "%~1"=="" pause
  exit /b 1
)
if not "%CODE%"=="0" (
  echo TESTS FAILED
  if "%~1"=="" pause
  exit /b 1
)
echo TESTS PASSED
if "%~1"=="" pause
exit /b 0
