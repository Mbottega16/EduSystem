@echo off
setlocal
REM Launches all 6 EduSystem bots tiled in a 3x2 grid across your screen:
REM   Top Row (3 Recording Bots):
REM     - Top Left (0, 0):     TestTeacher1 (Pedagogy Master - Tier 4 High-Skill/ZPD)
REM     - Top Center (640, 0): TestTeacher2 (Steady Teacher - Tier 3 Cozy Routine)
REM     - Top Right (1280, 0): TestTeacher3 (Clueless Sub - Tier 1 Overwhelmed Novice)
REM   Bottom Row (3 Live Companion Bots):
REM     - Bottom Left (0, 510):    LiveTeacher4 (Distracted Sweeper - Tier 1 Chore-Fixated)
REM     - Bottom Center (640, 510): LiveTeacher5 (Strict Lecturer - Tier 2 Podium Bound)
REM     - Bottom Right (1280, 510): LiveTeacher6 (Furniture Nerd - Tier 3 Room Makeover)
REM
REM Usage:
REM   "Launch 6 Bots.bat"               (prompts for terms and roster preset)
REM   "Launch 6 Bots.bat" 0             (runs perpetual with diverse roster)
REM   "Launch 6 Bots.bat" 2 smart       (runs 2 terms with smart roster)
REM   "Launch 6 Bots.bat" 1 dumb        (runs 1 term with dumb roster)

set TERMS=%1
set ROSTER=%2

if "%TERMS%"=="" (
    echo ========================================================
    echo      EduSystem 6-Bot Autonomous Multi-Screen Fleet
    echo ========================================================
    echo Enter the number of school terms to run:
    echo   - Enter 0 or press ENTER for PERPETUAL (continuous play)
    echo   - Enter a number (e.g. 1, 2, 4) to stop after that many terms
    echo.
    set /p TERMS="Terms to run [0 = perpetual]: "
)
if "%TERMS%"=="" set TERMS=0

if "%ROSTER%"=="" (
    echo.
    echo Select fleet roster profile:
    echo   [1] diverse  - Spectrum of Tier 1 through Tier 4 (Smart + Dumb side-by-side)
    echo   [2] smart    - Only high-skill proficient teachers (Tiers 3 & 4)
    echo   [3] dumb     - Only novice/distracted teachers (Tiers 1 & 2)
    echo   [4] classic  - Original 3-persona setup
    echo.
    set /p RCHOICE="Choice [1=diverse]: "
    if "%RCHOICE%"=="2" set ROSTER=smart
    if "%RCHOICE%"=="3" set ROSTER=dumb
    if "%RCHOICE%"=="4" set ROSTER=classic
)
if "%ROSTER%"=="" set ROSTER=diverse

if "%TERMS%"=="0" (
    echo Starting 6 bots in PERPETUAL mode with roster [%ROSTER%]...
    python "%~dp0..\AI Projects\my-brain\projects\edusystem\promo\run_6_screens.py" --game "%~dp0." --perpetual --roster %ROSTER%
) else (
    echo Starting 6 bots to run for %TERMS% term(s) with roster [%ROSTER%]...
    python "%~dp0..\AI Projects\my-brain\projects\edusystem\promo\run_6_screens.py" --game "%~dp0." --terms %TERMS% --roster %ROSTER%
)

pause
