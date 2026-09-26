@echo off
REM Double-click to screenshot the REAL game. Headless cannot see; this can.
REM Optional argument: a screen to open first. All 59:
REM   quiz specialism hand hand_shuffle school watch hiring career alumni curriculum unit_test
REM   student shop room staff staff_scrolled class_list at_board at_bell title
REM   inspection inspector_here teaching noise day run_over new_term exam
REM   dashboard dashboard_items dashboard_skills marking marking_stamp ads
REM   dev_room dev_room_bare weather hallway door office principal consumables
REM   mess mess_janitor dashboard_wardrobe hat auto_teach
REM   consumables_report intro intro_walk intro_line
REM   term_paths desk_interruption mentor mentor_demo mentor_chain boss_fight fight_report
REM   skip skip_report
REM Saves into shots\ (gitignored), named after the screen so repeat runs
REM do not overwrite each other and nothing lands in the tracked root the
REM way six shot_*.png files once did.
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
if not exist "%PROJECT%\shots" mkdir "%PROJECT%\shots"

set "SCREEN=%~1"
if "%SCREEN%"=="" set "SCREEN=title"

if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --path "%PROJECT%" res://tools/shot.tscn -- "%PROJECT%\shots\%SCREEN%.png" 90 640 352 0 %SCREEN%
echo.
echo Saved to shots\%SCREEN%.png
pause
