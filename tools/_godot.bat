@echo off
REM The ONE place the Godot path lives. Every launcher calls this.
REM
REM It used to be pasted into nine .bat files, so changing Godot version
REM meant editing nine files and missing one.
REM
REM Edit tools\godot_path.txt to point somewhere else.
set "GODOT="
if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
if not defined GODOT set "GODOT=C:\Users\mbott\Projects\_tools\godot.exe"
