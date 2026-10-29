@echo off
setlocal
echo ========================================================
echo   EduSystem Bot Telemetry Optimizer & Learning Loop
echo ========================================================
echo Analyzing autonomous bot telemetry and evolving teacher persona...
echo.

python "%~dp0tools\persona_optimizer.py" --analyze --evolve --report "%~dp0telemetry\learning_report.md"

echo.
echo Telemetry report written to telemetry\learning_report.md
echo.
pause
