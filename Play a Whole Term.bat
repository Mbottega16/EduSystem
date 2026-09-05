@echo off
REM Plays an entire twenty-day term through the REAL buttons, at raised
REM speed -- podium, teach, end lesson, bell, every day, twenty times --
REM and checks it actually reaches the exam.
REM
REM This had no launcher at all; running it meant typing the command by
REM hand. playtrace.gd proves one day works. This is the only thing that
REM proves twenty of them in a row reach the thing that resolves them.
REM
REM Pass any argument to skip the pause, so it can be chained.
REM
REM DO NOT TRUST ERRORLEVEL ALONE -- the same lesson Run Tests.bat learned
REM the hard way. A script that will not compile never runs, and says so
REM in neither the exit code nor a missing failure: the VERDICT LINE is
REM the only proof a term was actually played. This tool used to print
REM prose at a human and exit 0 no matter what happened, which is how a
REM broken day 18, a clean run, and a script that never compiled all
REM looked identical from the outside for four days.
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

echo Playing a whole term through the real buttons.
echo Takes about three minutes, and prints nothing until it is done.
echo.

set "LOG=%TEMP%\edusystem_walkthrough.log"
set "ERRLOG=%TEMP%\edusystem_walkthrough.err"
REM One place for the limit, so the message cannot drift from the kill.
set "LIMIT_S=660"
set /a LIMIT_MS=%LIMIT_S%*1000

REM Run it with a HARD wall-clock limit. A parse error does not merely make
REM Godot exit 0 -- with the scene's script unloadable, _ready() never runs,
REM nothing ever calls quit(), and headless Godot sits there forever. That
REM was measured, not guessed: this launcher hung for five minutes on a
REM deliberately broken playterm.gd. playterm.gd's own watchdog cannot help,
REM because a script that will not compile cannot arm one. Batch has no way
REM to time out a child, so PowerShell runs it -- the same escape hatch
REM Verify.bat already uses for its contract check.
REM Clear both logs first. A launch that fails before Godot even starts
REM would otherwise leave the PREVIOUS run's log in place, and every
REM check below would happily read a stale WALKTHROUGH PASSED. Seen
REM exactly once, in testing, which is once more than is comfortable.
del /q "%LOG%" "%ERRLOG%" >nul 2>&1
powershell -NoProfile -Command "$p = Start-Process -FilePath $env:GODOT -ArgumentList '--headless','--path',$env:PROJECT,'res://tools/playterm.tscn' -RedirectStandardOutput $env:LOG -RedirectStandardError $env:ERRLOG -PassThru -NoNewWindow; if (-not $p.WaitForExit([int]$env:LIMIT_MS)) { $p.Kill(); $p.WaitForExit(); exit 124 }; exit $p.ExitCode"
set "CODE=%ERRORLEVEL%"
type "%ERRLOG%" >> "%LOG%"

if "%CODE%"=="124" (
  type "%LOG%"
  echo WALKTHROUGH FAILED - it hung. Killed after %LIMIT_S% seconds.
  if "%~1"=="" pause
  exit /b 1
)
type "%LOG%"
echo.

findstr /I /C:"parse error" "%LOG%" >nul && (
  echo WALKTHROUGH FAILED - a script did not compile, so nothing was played.
  if "%~1"=="" pause
  exit /b 1
)
findstr /C:"WALKTHROUGH FAILED" "%LOG%" >nul && (
  echo See the WALKTHROUGH FAILED line above for the day and the reason.
  if "%~1"=="" pause
  exit /b 1
)
findstr /C:"WALKTHROUGH PASSED" "%LOG%" >nul || (
  echo WALKTHROUGH FAILED - no verdict line. It never reached the end.
  if "%~1"=="" pause
  exit /b 1
)
if not "%CODE%"=="0" (
  echo WALKTHROUGH FAILED - it said PASSED but exited %CODE%.
  if "%~1"=="" pause
  exit /b 1
)
if "%~1"=="" pause
exit /b 0
