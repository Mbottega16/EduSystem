@echo off
REM Everything CLAUDE.md's working rhythm asks for, in one command.
REM
REM It was five separate double-clicks, six of which held a console open
REM with a pause, so they could not be chained.
REM
REM This is now the ONLY thing running the slow checks. Both git hooks
REM are disarmed by default (see .githooks/pre-commit), so nothing runs
REM the suite or the walkthrough for you any more. Run this before a
REM push, or whenever you want the whole picture.
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
set "FAILED="

echo ================ 1/4  the suite
call "%~dp0Run Tests.bat" nopause
if errorlevel 1 set "FAILED=1"

echo.
echo ================ 2/4  the documents
python "%PROJECT%\tools\check_docs.py"
if errorlevel 1 set "FAILED=1"

echo.
echo ================ 3/4  the balance contract
set "SIMLOG=%TEMP%\edusystem_sim.log"
"%GODOT%" --headless --path "%PROJECT%" res://tools/sim.tscn > "%SIMLOG%" 2>&1
powershell -NoProfile -Command "$m = Select-String -Path $env:SIMLOG -Pattern 'CONTRACT CHECK' -Context 0,4; if (-not $m) { Write-Host 'no contract line - the simulator did not finish'; exit 1 }; $m.Context.PostContext | ForEach-Object { Write-Host $_ }; if ($m.Context.PostContext -match 'not ok') { exit 1 }"
if errorlevel 1 set "FAILED=1"

echo.
echo ================ 4/4  a whole term through the real buttons
REM Last, because it is the slow one (~3 min) and the three above are
REM fast -- a quick failure should not have to sit behind it. This used
REM to run automatically in .githooks/pre-push; that gate is disarmed
REM by default now, so this is where the walkthrough lives.
call "%~dp0Play a Whole Term.bat" nopause
if errorlevel 1 set "FAILED=1"

echo.
echo ==========================================
if defined FAILED (
  echo VERIFY FAILED - see above.
  pause
  exit /b 1
)
echo VERIFY PASSED - suite, docs, contract and a whole term all green.
pause
exit /b 0
