$ErrorActionPreference = "Stop"

$PythonVersion = if ($env:PYTHON_VERSION) { $env:PYTHON_VERSION } else { "3.14" }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = $ScriptDir
$PyprojectPath = Join-Path $AppDir "pyproject.toml"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Install uv first: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
}

if (-not (Test-Path -LiteralPath $PyprojectPath)) {
    Write-Host "Cannot find app\pyproject.toml at: $AppDir" -ForegroundColor Red
    exit 1
}

Set-Location -LiteralPath $AppDir

Write-Host "Using Python $PythonVersion"
Write-Host "Creating virtual environment in .venv ..."
uv venv .venv --python $PythonVersion

Write-Host "Installing dependencies from pyproject.toml ..."
uv sync

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host "Run the app with:"
Write-Host "  uv run python main.py"
