param(
    [switch]$Clean,
    [switch]$CleanAll,
    [string]$File = "main.tex"
)

$outDir = "build"

if ($CleanAll) {
    latexmk -C -outdir=$outDir $File
    if (Test-Path -LiteralPath $outDir) {
        Remove-Item -LiteralPath $outDir -Recurse -Force
    }
    exit 0
}

if ($Clean) {
    latexmk -c -outdir=$outDir $File
    exit 0
}

if (!(Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

if (!(Test-Path -LiteralPath $File)) {
    Write-Host "Không tìm thấy file: $File" -ForegroundColor Red
    exit 1
}

Write-Host "Building: $File" -ForegroundColor Cyan

latexmk `
  -xelatex `
  -interaction=nonstopmode `
  -halt-on-error `
  -outdir=$outDir `
  $File

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed: $File" -ForegroundColor Red
    exit 1
}

$pdfName = [System.IO.Path]::GetFileNameWithoutExtension($File) + ".pdf"
$pdfPath = Join-Path $outDir $pdfName

if (Test-Path -LiteralPath $pdfPath) {
    Copy-Item -LiteralPath $pdfPath -Destination ".\$pdfName" -Force
    Write-Host "Done: $pdfName" -ForegroundColor Green
} else {
    Write-Host "Không tìm thấy PDF: $pdfPath" -ForegroundColor Red
    exit 1
}
