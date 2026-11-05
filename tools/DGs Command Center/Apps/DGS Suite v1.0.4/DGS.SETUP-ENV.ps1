<#
.SYNOPSIS
    PC Environment Setup for GitHub EXE Build Workflow - v4
.DESCRIPTION
    Scans the machine, shows which developer tools are missing, and can either:
      * DRY-RUN (default): Produce an INSTALL PLAN with exact commands.
      * INSTALL NOW: Actually install the missing tools (requires ADMIN).
    Modes:
      1) GUI mode      : run Setup-Env-GUI.ps1 and pick tools with checkboxes.
      2) Auto plan     : Setup-Env-GUI.ps1 -> "AUTO PLAN ALL"
      3) Auto install  : Setup-Env-GUI.ps1 -> "INSTALL NOW (ADMIN)"
      4) CLI plan      : Setup-Env.ps1 -Install git,python,vscode
      5) CLI install   : Setup-Env.ps1 -Install git,python -InstallNow
      6) Classic CLI   : no -Install switch -> interactive selection (plan only)
    Keys: git, python, packages, vscode, gh, gitlfs, ghdesktop, cppbuild,
          inno, 7zip, node, rust, terminal, powershell7, pipx
    Use the special key "all" for everything.
.PARAMETER Install
    Comma-separated list of tool keys to plan/install without prompting.
.PARAMETER InstallNow
    When specified, actually INSTALLS the missing tools (auto-elevates to ADMIN).
    DRY-RUN is the default when this switch is omitted.
.PARAMETER SkipGit
.PARAMETER SkipPython
.PARAMETER SkipPackages
.PARAMETER SkipVSCode
.PARAMETER SkipGitHubCLI
    Legacy classic-mode switches (ignored when -Install is used).
#>
param(
    [string]$Install = "",
    [switch]$InstallNow,
    [switch]$SkipGit,
    [switch]$SkipPython,
    [switch]$SkipPackages,
    [switch]$SkipVSCode,
    [switch]$SkipGitHubCLI
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
# ============================================================
# Manifest of available tools
# ============================================================
$Tools = @(
    @{ Key = "git";         Name = "Git";                      Winget = "Git.Git";                          Desc = "Version control" },
    @{ Key = "python";      Name = "Python 3.11";              Winget = "Python.Python.3.11";               Desc = "Python runtime for PyInstaller builds" },
    @{ Key = "packages";    Name = "PyInstaller + data libs";  Winget = "";                                Desc = "pyinstaller, requests, pandas, numpy, openpyxl" },
    @{ Key = "vscode";      Name = "Visual Studio Code";       Winget = "Microsoft.VisualStudioCode";      Desc = "Code editor" },
    @{ Key = "gh";          Name = "GitHub CLI";               Winget = "GitHub.cli";                      Desc = "gh: repos, PRs, releases from terminal" },
    @{ Key = "gitlfs";      Name = "Git LFS";                  Winget = "GitHub.GitLFS";                   Desc = "Large-file versioning" },
    @{ Key = "ghdesktop";   Name = "GitHub Desktop";           Winget = "GitHub.GitHubDesktop";            Desc = "GUI for git/GitHub" },
    @{ Key = "cppbuild";    Name = "C++ Build Tools (MSVC)";   Winget = "Microsoft.VisualStudio.2022.BuildTools"; Desc = "Native modules + wheels for PyInstaller" },
    @{ Key = "inno";        Name = "Inno Setup";               Winget = "JRSoftware.InnoSetup";            Desc = "Build setup.exe installers" },
    @{ Key = "7zip";        Name = "7-Zip";                    Winget = "7zip.7zip";                       Desc = "Archiving for release bundles" },
    @{ Key = "node";        Name = "Node.js (LTS)";            Winget = "OpenJS.NodeJS.LTS";               Desc = "JS/TS runtime + npm" },
    @{ Key = "rust";        Name = "Rust (rustup)";            Winget = "Rustlang.Rustup";                 Desc = "Modern systems language" },
    @{ Key = "terminal";    Name = "Windows Terminal";         Winget = "Microsoft.WindowsTerminal";       Desc = "Modern terminal app" },
    @{ Key = "powershell7"; Name = "PowerShell 7";             Winget = "Microsoft.PowerShell";            Desc = "pwsh: cross-platform shell" },
    @{ Key = "pipx";        Name = "pipx";                     Winget = "";                                Desc = "Run Python CLI tools in isolation" }
)
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$envLog = Join-Path $scriptDir "setup-log.txt"
$planFile = Join-Path $scriptDir "setup-plan.txt"
$installLog = Join-Path $scriptDir "install-log.txt"
# ============================================================
# Helpers
# ============================================================
function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}
function Confirm-Install {
    param([string]$Message)
    $response = Read-Host "$Message (Y/N)"
    return ($response -eq "Y" -or $response -eq "y")
}
function Test-Msvc {
    $msvcDir = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC"
    return [bool](Test-Path -LiteralPath $msvcDir) -and [bool](Get-ChildItem -LiteralPath $msvcDir -ErrorAction SilentlyContinue)
}
function Test-Installed {
    param($tool)
    switch ($tool.Key) {
        "git"         { return [bool](Test-Command git) }
        "python"      { return [bool](Test-Command python) -or [bool](Test-Command py) }
        "packages"    { return [bool](Test-Command pyinstaller) }
        "vscode"      { return [bool](Test-Command code) }
        "gh"          { return [bool](Test-Command gh) }
        "gitlfs"      { return [bool](Test-Command git-lfs) }
        "ghdesktop"   { return [bool](Test-Path -LiteralPath "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe") }
        "cppbuild"    { return Test-Msvc }
        "inno"        { return [bool](Test-Path -LiteralPath "C:\Program Files (x86)\Inno Setup 6\ISCC.exe") }
        "7zip"        { return [bool](Test-Command 7z) }
        "node"        { return [bool](Test-Command node) }
        "rust"        { return [bool](Test-Command cargo) }
        "terminal"    { return [bool](Test-Command wt) }
        "powershell7" { return [bool](Test-Command pwsh) }
        "pipx"        { return [bool](Test-Command pipx) }
    }
    return $false
}
function Get-ToolCommands {
    param($tool)
    $useWinget = Test-Command winget
    $wingetPrefix = "winget install --id {0} -e --accept-source-agreements --accept-package-agreements --silent"
    switch ($tool.Key) {
        "git" {
            if ($useWinget) { return @(($wingetPrefix -f "Git.Git")) }
            return @("# Git: winget unavailable - download from https://git-scm.com/downloads and run the installer")
        }
        "python" {
            if ($useWinget) { return @(($wingetPrefix -f "Python.Python.3.11")) }
            return @("# Python: winget unavailable - download from https://www.python.org/downloads/ (tick 'Add to PATH')")
        }
        "packages" {
            return @(
                "python -m pip install --upgrade pip",
                "python -m pip install `"pyinstaller>=6.0`" requests pandas numpy openpyxl"
            )
        }
        "pipx" {
            return @(
                "python -m pip install --user pipx",
                "# then restart your terminal so pipx resolves from ~\.local\bin"
            )
        }
        default {
            if ($tool.Winget) {
                if ($useWinget) { return @(($wingetPrefix -f $tool.Winget)) }
                return @("# {0}: winget unavailable - install '{1}' from its vendor website before continuing" -f $tool.Name, $tool.Winget)
            }
            return @("# {0}: no automated install command defined - install manually" -f $tool.Name)
        }
    }
}
function New-EnvShortcut {
    param([string]$ScriptDir)
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $desktop = [Environment]::GetFolderPath("Desktop")
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut((Join-Path $desktop "PC Environment Setup.lnk"))
        $lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
        $lnk.Arguments = "`"$ScriptDir\Setup-Env-GUI.vbs`""
        $lnk.WorkingDirectory = $ScriptDir
        $lnk.IconLocation = "$ScriptDir\setup-env.ico,0"
        $lnk.Description = "PC Environment Setup"
        $lnk.Save()
        Write-Host ("[OK] Desktop shortcut created: PC Environment Setup.lnk") -ForegroundColor Green
    } catch {
        Write-Host ("[WARN] Could not create desktop shortcut: {0}" -f $_) -ForegroundColor Yellow
    }
}
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Invoke-AdminRelaunch {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Install) { $argList += " -Install `"$Install`"" }
    if ($InstallNow) { $argList += " -InstallNow" }
    Write-Host "[ELEVATE] Requesting Administrator privileges..." -ForegroundColor Yellow
    try {
        Start-Process powershell -ArgumentList $argList -Verb RunAs -Wait
    } catch {
        Write-Host "[ERROR] Admin elevation was cancelled or failed." -ForegroundColor Red
        exit 1
    }
    exit 0
}
function Invoke-ToolInstall {
    param($tool, [string]$LogFile)
    $cmds = Get-ToolCommands $tool
    $results = @()
    foreach ($cmd in $cmds) {
        if ($cmd -match '^\s*#') {
            Write-Host "    $cmd" -ForegroundColor Gray
            $results += @{ Command = $cmd; Success = $false; Note = "Skipped (comment)" }
            continue
        }
        Write-Host "    > $cmd" -ForegroundColor Cyan
        try {
            $output = & cmd /c "$cmd 2>&1"
            $exitCode = $LASTEXITCODE
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] CMD: $cmd`r`nEXIT: $exitCode`r`nOUTPUT:`r`n$($output -join "`r`n")`r`n---"
            Add-Content -LiteralPath $LogFile -Value $logEntry -Encoding UTF8
            if ($exitCode -eq 0 -or $exitCode -eq $null) {
                Write-Host "    [OK] $($tool.Name) installed successfully" -ForegroundColor Green
                $results += @{ Command = $cmd; Success = $true; ExitCode = $exitCode }
            } else {
                Write-Host "    [WARN] $($tool.Name) exited with code $exitCode (may still be OK - check log)" -ForegroundColor Yellow
                $results += @{ Command = $cmd; Success = $false; ExitCode = $exitCode }
            }
        } catch {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -LiteralPath $LogFile -Value "[$timestamp] CMD: $cmd`r`nERROR: $_`r`n---" -Encoding UTF8
            Write-Host "    [FAIL] $_" -ForegroundColor Red
            $results += @{ Command = $cmd; Success = $false; Error = $_ }
        }
    }
    return $results
}
# ============================================================
# Resolve which tools to include
# ============================================================
$selected = @()
if ($Install) {
    if ($Install -eq "all") {
        $selected = @($Tools.Key)
    } else {
        $selected = @($Install -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    }
} elseif ($InstallNow) {
    $selected = @($Tools.Key)
} else {
    $selected = @("git", "python", "packages")
    if (-not $SkipVSCode -and (Confirm-Install "Plan Visual Studio Code?")) { $selected += "vscode" }
    if (-not $SkipGitHubCLI -and (Confirm-Install "Plan GitHub CLI?")) { $selected += "gh" }
}
$known = @($Tools.Key)
$toInstall = @($selected | Where-Object { $_ -in $known })
$already = @($Tools | Where-Object { $_.Key -in $toInstall -and (Test-Installed $_) })
$missing = @($Tools | Where-Object { $_.Key -in $toInstall -and -not (Test-Installed $_) })
# ============================================================
# INSTALL NOW MODE
# ============================================================
if ($InstallNow) {
    if (-not (Test-Admin)) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "  ADMIN PRIVILEGES REQUIRED FOR INSTALLATION" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "  Installing system software requires Administrator rights."
        Write-Host "  You will now see a UAC prompt - click YES to continue."
        Write-Host ""
        Invoke-AdminRelaunch
        exit 0
    }
    # Start install log
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $installHeader = @"
============================================================
  PC ENVIRONMENT SETUP - LIVE INSTALLATION LOG
  Started: $timestamp
  User: $env:USERNAME
  Admin: YES
  Tools to attempt: $($missing.Count)
============================================================

"@
    Set-Content -LiteralPath $installLog -Value $installHeader -Encoding UTF8
    if ($Install) {
        try { Start-Transcript -Path $envLog -Force | Out-Null } catch { }
    }
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  PC ENVIRONMENT SETUP - LIVE INSTALLATION" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Running as ADMIN" -ForegroundColor Green
    Write-Host "  Tools to install: $($missing.Count)"
    Write-Host "  Already OK: $($already.Count)"
    Write-Host ""
    if ($missing.Count -eq 0) {
        Write-Host "  Nothing to install - all selected tools are already present." -ForegroundColor Green
        Write-Host ""
        Add-Content -LiteralPath $installLog -Value "Nothing to install - all tools already present.`r`n" -Encoding UTF8
    } else {
        $successCount = 0
        $failCount = 0
        $i = 0
        foreach ($t in $missing) {
            $i++
            Write-Host ""
            Write-Host "[$i/$($missing.Count)] Installing: $($t.Name)" -ForegroundColor White
            Write-Host "  $($t.Desc)" -ForegroundColor Gray
            $results = Invoke-ToolInstall $t $installLog
            $allFail = $results | Where-Object { $_.Success -eq $false -and -not $_.Note }
            if ($allFail.Count -eq 0) { $successCount++ } else { $failCount++ }
        }
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  INSTALLATION SUMMARY" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  Successful: $successCount" -ForegroundColor Green
        Write-Host "  Had issues: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })
        Write-Host "  Already OK: $($already.Count)"
        Write-Host ""
        Write-Host "  Full install log: $installLog" -ForegroundColor Gray
        Write-Host ""
        if ($failCount -gt 0) {
            Write-Host "  Some tools had issues. Check the log above or re-run the installer." -ForegroundColor Yellow
        } else {
            Write-Host "  All tools installed successfully!" -ForegroundColor Green
        }
        Write-Host "  IMPORTANT: Restart your terminal so new tools appear on PATH." -ForegroundColor Yellow
        Add-Content -LiteralPath $installLog -Value "`r`n=== INSTALLATION COMPLETE ===`r`nSuccessful: $successCount`r`nHad issues: $failCount`r`n" -Encoding UTF8
    }
    New-EnvShortcut -ScriptDir $scriptDir
    if ($Install) {
        try { Stop-Transcript | Out-Null } catch { }
    } else {
        Write-Host ""
        Read-Host "Press Enter to close this window"
    }
    exit 0
}
# ============================================================
# DRY-RUN MODE (default)
# ============================================================
if ($Install) {
    try { Start-Transcript -Path $envLog -Force | Out-Null } catch { }
}
$plan = [System.Collections.Generic.List[string]]::new()
$plan.Add("============================================================")
$plan.Add("  PC ENVIRONMENT SETUP - DRY-RUN INSTALL PLAN")
$plan.Add("  No software was installed. This is only a plan.")
$plan.Add("============================================================")
$plan.Add("Generated : " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$plan.Add("Requested : " + $toInstall.Count + " tool(s)")
$plan.Add("Already OK: " + $already.Count + "   Missing: " + $missing.Count)
$plan.Add("")
$plan.Add("TO INSTALL (" + $missing.Count + "):")
if ($missing.Count -eq 0) {
    $plan.Add("  (nothing - every selected tool is already installed)")
} else {
    $i = 0
    foreach ($t in $missing) {
        $i++
        $plan.Add("  " + $i + ". " + $t.Name)
        foreach ($cmd in (Get-ToolCommands $t)) {
            $plan.Add("      > " + $cmd)
        }
    }
}
$plan.Add("")
$plan.Add("ALREADY INSTALLED (no action):")
if ($already.Count -eq 0) {
    $plan.Add("  (none)")
} else {
    foreach ($t in $already) {
        $plan.Add("  - " + $t.Name + "   (" + $t.Desc + ")")
    }
}
$plan.Add("")
$plan.Add("COMMANDS TO RUN IN AN ADMIN POWERSHELL:")
if ($missing.Count -eq 0) {
    $plan.Add("  (no commands needed)")
} else {
    foreach ($t in $missing) {
        foreach ($cmd in (Get-ToolCommands $t)) {
            $plan.Add("  " + $cmd)
        }
    }
}
$plan.Add("")
$plan.Add("--- OR, TO LET THIS SCRIPT INSTALL EVERYTHING FOR YOU ---")
$plan.Add("  Open an ADMIN PowerShell in this folder and run:")
if ($missing.Count -gt 0) {
    $keys = ($missing.Key -join ",")
    $plan.Add("    .\Setup-Env.ps1 -Install `"$keys`" -InstallNow")
}
$plan.Add("    or simply:  .\Setup-Env.ps1 -Install all -InstallNow")
$planText = $plan -join [Environment]::NewLine
Write-Host ""
foreach ($line in $plan) { Write-Host $line }
Write-Host ""
try { Set-Content -LiteralPath $planFile -Value $planText -Encoding UTF8 } catch {
    Write-Host "[WARN] Could not save plan file: $planFile" -ForegroundColor Yellow
}
New-EnvShortcut -ScriptDir $scriptDir
Write-Host ""
Write-Host "DRY-RUN complete - nothing was installed." -ForegroundColor Green
Write-Host ("Plan saved to: " + $planFile) -ForegroundColor Cyan
Write-Host ""
Write-Host "To install for real:"
Write-Host "  Option A: Open an ADMIN PowerShell and paste the COMMANDS block above."
Write-Host "  Option B: Run this script with -InstallNow (auto-elevates to admin)."
Write-Host ""
if ($Install) {
    try { Stop-Transcript | Out-Null } catch { }
} else {
    Read-Host "Press Enter to exit"
}
