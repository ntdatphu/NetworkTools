@echo off
cd /d "%~dp0"
start "" cmd /c "uv run main.py"
exit