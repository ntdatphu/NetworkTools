$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = Join-Path $ScriptDir "app"
$MainPath = Join-Path $AppDir "main.py"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Run app\setup_app.ps1 first, or install uv: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
}

if (-not (Test-Path -LiteralPath $MainPath)) {
    Write-Host "Cannot find app\main.py at: $MainPath" -ForegroundColor Red
    exit 1
}

Set-Location -LiteralPath $AppDir
uv run python main.py
