@echo off
REM Everything CLAUDE.md's working rhythm asks for, in one command.
REM
REM It was five separate double-clicks, six of which held a console open
REM with a pause, so they could not be chained.
setlocal

call "%~dp0tools\_godot.bat"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
set "FAILED="

echo ================ 1/3  the suite
call "%~dp0Run Tests.bat" nopause
if errorlevel 1 set "FAILED=1"

echo.
echo ================ 2/3  the documents
python "%PROJECT%\tools\check_docs.py"
if errorlevel 1 set "FAILED=1"

echo.
echo ================ 3/3  the balance contract
set "SIMLOG=%TEMP%\edusystem_sim.log"
"%GODOT%" --headless --path "%PROJECT%" res://tools/sim.tscn > "%SIMLOG%" 2>&1
powershell -NoProfile -Command "$m = Select-String -Path $env:SIMLOG -Pattern 'CONTRACT CHECK' -Context 0,4; if (-not $m) { Write-Host 'no contract line - the simulator did not finish'; exit 1 }; $m.Context.PostContext | ForEach-Object { Write-Host $_ }; if ($m.Context.PostContext -match 'not ok') { exit 1 }"
if errorlevel 1 set "FAILED=1"

echo.
echo ==========================================
if defined FAILED (
  echo VERIFY FAILED - see above.
  pause
  exit /b 1
)
echo VERIFY PASSED - suite, docs and contract all green.
pause
exit /b 0
