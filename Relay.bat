@echo off
REM The Claude <-> Gemini relay: whose turn is it, and what was said last.
REM
REM Double-click this to see the state of the conversation without
REM remembering the CLI. Rules: docs\relay\PROTOCOL.md
setlocal

cd /d "%~dp0"

python tools\relay.py status
echo.
echo ================= the last two turns =================
echo.
python tools\relay.py read --last 2
echo.
echo To answer:  python tools\relay.py template --agent ^<you^> ^> turn.md
echo             python tools\relay.py check --file turn.md
echo             python tools\relay.py post --agent ^<you^> --file turn.md
echo.
pause
