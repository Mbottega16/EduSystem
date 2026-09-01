@echo off
REM One menu for every launcher this project has. Each numbered item just
REM calls the .bat of the same name that already existed -- nothing about
REM how any individual tool runs changed, this is only a front door so you
REM are not hunting through a folder of a dozen icons to find the right one.
setlocal
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

:menu
cls
echo ================================================================
echo   EDUSystem Dev Console
echo ================================================================
echo.
echo   PLAY
echo    1) Play EDUSystem
echo    2) Open in Godot Editor
echo.
echo   VERIFY  (read the assertion COUNT, not just PASSED)
echo    3) Run Tests               (the 1150-assertion suite)
echo    4) Verify                  (suite + docs + balance contract, one shot)
echo    5) Simulate a Term         (the three contract rows)
echo    6) Simulate the School     (delegated rooms, hiring, the board)
echo.
echo   LOOK AT THE RUNNING GAME  (headless never proves this)
echo    7) Play a Whole Term       (20 real days, real buttons)
echo    8) Trace a Day             (one real day, real buttons)
echo    9) Audit the Room          (what both buttons offer, everywhere)
echo   10) Take a Screenshot       (real scene -^> PNG in shots\)
echo.
echo   ART
echo   11) Browse Art              (every sprite; edit any in place)
echo   12) Draw a Sprite           (hand-drawing editor, HTML, offline)
echo   13) Make a Sprite           (new character: palette -^> sheet -^> import)
echo.
echo    0) Exit
echo.
set "CH="
set /p "CH=Pick a number: "

if "%CH%"=="1"  (start "" "%HERE%\Play EDUSystem.bat" & goto menu)
if "%CH%"=="2"  (start "" "%HERE%\Open in Godot Editor.bat" & goto menu)
if "%CH%"=="3"  (call "%HERE%\Run Tests.bat" & goto menu)
if "%CH%"=="4"  (call "%HERE%\Verify.bat" & goto menu)
if "%CH%"=="5"  (call "%HERE%\Simulate a Term.bat" & goto menu)
if "%CH%"=="6"  (call "%HERE%\Simulate the School.bat" & goto menu)
if "%CH%"=="7"  (call "%HERE%\Play a Whole Term.bat" & goto menu)
if "%CH%"=="8"  (call "%HERE%\Trace a Day.bat" & goto menu)
if "%CH%"=="9"  (call "%HERE%\Audit the Room.bat" & goto menu)
if "%CH%"=="10" goto screenshot
if "%CH%"=="11" (call "%HERE%\Browse Art.bat" & goto menu)
if "%CH%"=="12" (call "%HERE%\Draw a Sprite.bat" & goto menu)
if "%CH%"=="13" (call "%HERE%\Make a Sprite.bat" & goto menu)
if "%CH%"=="0"  exit /b 0

echo.
echo Not a valid choice.
pause
goto menu

:screenshot
set "SCREEN="
echo.
echo Screens: quiz specialism hand school watch hiring career curriculum
echo unit_test student shop room staff class_list at_board at_bell title
echo inspection inspector_here teaching noise day run_over new_term exam
echo dashboard dashboard_items dashboard_skills marking dev_room
echo dev_room_bare weather hallway door office principal consumables
echo consumables_report
set /p "SCREEN=Which screen (blank = title): "
call "%HERE%\Take a Screenshot.bat" %SCREEN%
goto menu
