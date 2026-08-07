$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path "build" | Out-Null
typst compile main.typ build/networktools.pdf
Write-Host "Built: build/networktools.pdf"
