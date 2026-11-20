@echo off
cd /d "%~dp0"
python -u "tools\preview_web.py"
if errorlevel 1 pause
