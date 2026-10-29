@echo off
setlocal
echo ========================================================
echo       EduSystem Canva Art Auto-Conformer & Importer
echo ========================================================
echo.
echo Scanning shots\canva_imports\ for downloaded Canva PNGs...
echo.

python "%~dp0tools\canva_art_pipeline.py" --import

echo.
pause
