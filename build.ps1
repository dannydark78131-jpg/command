$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$mainFile = Join-Path $root "main.py"
$iconFile = Join-Path $root "assets\DG-Command-Center.ico"
$innoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"

$versionLine = Select-String -Path $mainFile -Pattern '^FALLBACK_VERSION = "([0-9]+\.[0-9]+\.[0-9]+)"$'
if (-not $versionLine) {
    throw "Could not read FALLBACK_VERSION from main.py."
}
$version = $versionLine.Matches[0].Groups[1].Value

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw "Python Launcher (py) is required. Install Python 3 and try again."
}
if (-not (Test-Path $innoCompiler)) {
    $resolvedCompiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($resolvedCompiler) {
        $innoCompiler = $resolvedCompiler.Source
    } else {
        throw "Inno Setup 6 is required to build the installer. Install it and rerun build.ps1."
    }
}

Push-Location $root
try {
    & py -3 (Join-Path $root "scripts\generate_icon.py") $iconFile
    if ($LASTEXITCODE -ne 0) {
        throw "Icon generation failed with exit code $LASTEXITCODE."
    }

    $buildArgs = @(
        "-3", "-m", "PyInstaller", "--noconfirm", "--clean", "--windowed", "--onedir",
        "--name", "DG Command Center", "--icon", $iconFile,
        "--workpath", (Join-Path $root "build\pyinstaller"),
        "--distpath", (Join-Path $root "dist\pyinstaller"),
        "--add-data", "$(Join-Path $root 'assets');assets",
        "--add-data", "$(Join-Path $root 'tools');tools",
        $mainFile
    )
    & py @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed with exit code $LASTEXITCODE."
    }

    & $innoCompiler "/DAppVersion=$version" (Join-Path $root "installer.iss")
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup failed with exit code $LASTEXITCODE."
    }
    Write-Host "Built DG Command Center $version installer in dist\installer."
} finally {
    Pop-Location
}
