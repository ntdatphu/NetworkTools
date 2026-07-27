@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if "%~1"=="" goto menu
if /I "%~1"=="sync" goto sync
if /I "%~1"=="build" goto build
if /I "%~1"=="setup" goto setup
if /I "%~1"=="check" goto check
if /I "%~1"=="run" goto run
if /I "%~1"=="all" goto all
echo Usage: %~nx0 [sync^|build^|setup^|check^|run^|all]
exit /b 2

:require_uv
where uv >nul 2>nul
if errorlevel 1 (
    echo ERROR: uv is not installed or is not available in PATH.
    echo Install uv from https://docs.astral.sh/uv/ and run this script again.
    exit /b 1
)
uv --version
exit /b 0

:sync
call :require_uv
if errorlevel 1 exit /b %errorlevel%
echo Synchronizing application and Cython build dependencies...
uv sync --extra speed
exit /b %errorlevel%

:build
call :require_uv
if errorlevel 1 exit /b %errorlevel%
echo Building optional Cython acceleration modules...
uv run --extra speed python setup_cython.py build_ext --inplace --force
if errorlevel 1 exit /b %errorlevel%
goto check

:setup
call :sync
if errorlevel 1 exit /b %errorlevel%
call :build
exit /b %errorlevel%

:check
call :require_uv
if errorlevel 1 exit /b %errorlevel%
uv run --extra speed python -c "from pathlib import Path; from features.devices.sync import _engine; p=Path(_engine.__file__); print(f'sync engine: {p}'); raise SystemExit(0 if p.suffix in {'.so', '.pyd'} else 1)"
exit /b %errorlevel%

:run
call :require_uv
if errorlevel 1 exit /b %errorlevel%
echo Starting NetworkTools...
uv run --extra speed python main.py
exit /b %errorlevel%

:all
call :setup
if errorlevel 1 exit /b %errorlevel%
goto run

:menu
echo.
echo NetworkTools
echo   1^) Sync dependencies
echo   2^) Build and verify Cython
echo   3^) Full setup ^(sync + Cython^)
echo   4^) Check Cython status
echo   5^) Run application
echo   6^) Full setup and run
echo   0^) Exit
choice /C 1234560 /N /M "Select: "
if errorlevel 7 exit /b 0
if errorlevel 6 goto all
if errorlevel 5 goto run
if errorlevel 4 goto check
if errorlevel 3 goto setup
if errorlevel 2 goto build
if errorlevel 1 goto sync
