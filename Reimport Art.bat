@echo off
REM Make the GAME pick up any PNG you edited in Browse Art.
REM
REM The art forge writes art\*.png straight to disk. Godot only shows the
REM new pixels after an import pass, and standalone Godot -- the game, and
REM the forge itself -- does not run one on its own. This does.
REM
REM Save in the forge no longer tries to do this itself: spawned from
REM inside Godot the import has hung and frozen the tool. From this console
REM window it is reliable, and you can see it finish.
setlocal

set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --headless --path "%PROJECT%" --import
echo.
echo Art reimported. Launch the game to see your changes.
pause
