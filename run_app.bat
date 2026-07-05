@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%app"
set "MAIN_PATH=%APP_DIR%\main.py"

where uv >nul 2>nul
if errorlevel 1 (
    echo uv is not installed or not in PATH.
    echo Run app\setup_app.ps1 first, or install uv: https://docs.astral.sh/uv/getting-started/installation/
    exit /b 1
)

if not exist "%MAIN_PATH%" (
    echo Cannot find app\main.py at: %MAIN_PATH%
    exit /b 1
)

cd /d "%APP_DIR%"
uv run python main.py

endlocal
