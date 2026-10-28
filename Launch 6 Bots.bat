@echo off
setlocal
REM Launches all 6 EduSystem bots tiled in a 3x2 grid across your screen:
REM   Top Row (3 Recording Bots):
REM     - Top Left (0, 0):     TestTeacher1 (Pedagogy Master - High-Skill/ZPD)
REM     - Top Center (640, 0): TestTeacher2 (Steady Teacher - Cozy Routine)
REM     - Top Right (1280, 0): TestTeacher3 (Furniture Nerd - Room Makeover)
REM   Bottom Row (3 Live Bots):
REM     - Bottom Left (0, 510):    LiveTeacher4 (Room Makeover Designer)
REM     - Bottom Center (640, 510): LiveTeacher5 (Pedagogy Master)
REM     - Bottom Right (1280, 510): LiveTeacher6 (Steady Teacher)
REM
REM Usage:
REM   "Launch 6 Bots.bat"          (prompts: 0 = perpetual, or enter number of terms)
REM   "Launch 6 Bots.bat" 0        (runs perpetual immediately)
REM   "Launch 6 Bots.bat" 2        (runs 2 terms immediately)

set TERMS=%1
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

if "%TERMS%"=="0" (
    echo Starting 6 bots in PERPETUAL mode...
    python "%~dp0..\AI Projects\my-brain\projects\edusystem\promo\run_6_screens.py" --game "%~dp0." --perpetual
) else (
    echo Starting 6 bots to run for %TERMS% term(s)...
    python "%~dp0..\AI Projects\my-brain\projects\edusystem\promo\run_6_screens.py" --game "%~dp0." --terms %TERMS%
)

pause
