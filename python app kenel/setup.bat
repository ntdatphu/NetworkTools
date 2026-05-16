@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ============================================
echo   SETUP MOI TRUONG PYTHON VOI UV
echo ============================================
echo.

:: -----------------------------------------------
:: BUOC 1: Kiem tra uv da cai chua
:: -----------------------------------------------
echo [1/3] Kiem tra uv...

where uv >nul 2>&1
if %ERRORLEVEL% == 0 (
    for /f "tokens=*" %%i in ('uv --version') do set UV_VER=%%i
    echo   [OK] Da co uv: !UV_VER!
) else (
    echo   [!!] Chua co uv. Dang cai dat...
    echo.

    :: Tai va chay installer cua uv
    powershell -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"

    if !ERRORLEVEL! NEQ 0 (
        echo   [LOI] Cai dat uv that bai!
        echo   Vui long kiem tra ket noi mang hoac chay PowerShell voi quyen Admin.
        pause
        exit /b 1
    )

    :: Cap nhat PATH trong session hien tai
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
    set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"

    :: Kiem tra lai sau khi cai
    where uv >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo   [LOI] Khong tim thay uv sau khi cai.
        echo   Hay mo lai terminal va chay lai file nay.
        pause
        exit /b 1
    )

    echo   [OK] Cai dat uv thanh cong!
)

echo.

:: -----------------------------------------------
:: BUOC 2: Kiem tra pyproject.toml
:: -----------------------------------------------
if not exist "pyproject.toml" (
    echo   [LOI] Khong tim thay pyproject.toml trong thu muc hien tai!
    echo   Dam bao file .bat nay nam cung cap voi pyproject.toml.
    pause
    exit /b 1
)

:: -----------------------------------------------
:: BUOC 3: Tao virtual environment
:: -----------------------------------------------
echo [2/3] Tao virtual environment (.venv)...

if exist ".venv" (
    echo   [OK] Da co .venv, bo qua buoc tao moi.
) else (
    uv venv
    if !ERRORLEVEL! NEQ 0 (
        echo   [LOI] Tao venv that bai!
        pause
        exit /b 1
    )
    echo   [OK] Tao .venv thanh cong!
)

echo.

:: -----------------------------------------------
:: BUOC 4: Cai thu vien tu pyproject.toml
:: -----------------------------------------------
echo [3/3] Cai dat thu vien tu pyproject.toml...
echo.

uv pip install -e .

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   [LOI] Cai dat thu vien that bai!
    pause
    exit /b 1
)

echo.
echo ============================================
echo   HOAN TAT! Moi truong da san sang.
echo ============================================
echo.
echo   Kich hoat moi truong bang lenh:
echo     .venv\Scripts\activate
echo.
if exist ".venv\Scripts\activate" (
    echo   Dang kich hoat virtual environment...
    call .venv\Scripts\activate
) else (
    echo   [LOI] Khong tim thay .venv\Scripts\activate.
    echo   Vui long kich hoat tay.
)
echo.
pause
