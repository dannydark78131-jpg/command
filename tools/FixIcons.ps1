# Requires -RunAsAdministrator

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  WINDOWS DESKTOP SHORTCUT WHITE BOX REPAIR  " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Clear registry values that cause broken overlay blocks
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons"
if (Test-Path $RegistryPath) {
    if ((Get-ItemProperty -Path $RegistryPath -Name "29" -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Removing corrupt shortcut arrow overlay registry link..." -ForegroundColor Yellow
        Remove-ItemProperty -Path $RegistryPath -Name "29" -Force
    }
}

# 2. Safely stop Windows Explorer to unlock cache databases
Write-Host "[*] Terminating Windows Explorer process..." -ForegroundColor Yellow
Stop-Process -Name "explorer" -Force
Start-Sleep -Seconds 2

# 3. Locate and delete localized icon and thumbnail cache files on C: drive
Write-Host "[*] Purging broken cache files from C: drive..." -ForegroundColor Yellow
$LocalAppData = $env:LOCALAPPDATA

if (Test-Path "$LocalAppData\IconCache.db") {
    Remove-Item -Path "$LocalAppData\IconCache.db" -Force -ErrorAction SilentlyContinue
}

$ExplorerCachePath = "$LocalAppData\Microsoft\Windows\Explorer"
if (Test-Path $ExplorerCachePath) {
    Get-ChildItem -Path $ExplorerCachePath -Filter "iconcache*" | Remove-Item -Force -ErrorAction SilentlyContinue
}

# 4. Fire Windows Explorer back up
Write-Host "[*] Restarting Windows Explorer..." -ForegroundColor Yellow
Start-Process "explorer.exe"

Write-Host "`n[SUCCESS] Operation completed! Refreshing your desktop display." -ForegroundColor Green

# 5. Optional desktop shortcut
Write-Host ""
$answer = Read-Host "Create a desktop shortcut to this tool? (Y/N)"
if ($answer -match '^(?i)y') {
    try {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        $scriptDir = Split-Path -Parent $scriptPath
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Fix Desktop Icons.lnk"
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($lnkPath)
        $lnk.TargetPath = (Get-Command powershell.exe).Source
        $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $lnk.WorkingDirectory = $scriptDir
        $icon = Join-Path $scriptDir "DG-Visual-Toolkit.ico"
        if (Test-Path -LiteralPath $icon) { $lnk.IconLocation = "`"$icon`",0" }
        $lnk.Description = "Fix broken desktop shortcut icons and rebuild the icon cache"
        $lnk.Save()
        $bytes = [IO.File]::ReadAllBytes($lnkPath)
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [IO.File]::WriteAllBytes($lnkPath, $bytes)
        Write-Host "[OK] Desktop shortcut created: $lnkPath" -ForegroundColor Green
    } catch {
        Write-Host "[!] Could not create shortcut: $($_.Exception.Message)" -ForegroundColor Red
    }
}
