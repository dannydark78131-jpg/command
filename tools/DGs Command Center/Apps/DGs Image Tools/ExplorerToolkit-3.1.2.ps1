#Requires -Version 5.1
<#
.SYNOPSIS
    Explorer Toolkit v3.1.2 - reset/restore views, extra Explorer options,
    context-menu backup, icon cache rebuild, file & folder browser,
    duplicate finder, renamer, services reset and desktop shortcut
    installer with a freshly generated .ico.
.VERSION
    3.1.2 (2026-10-28)
.USAGE
    .\ExplorerToolkit-3.1.2.ps1                 # interactive menu
    .\ExplorerToolkit-3.1.2.ps1 -Action Browse  # jump straight to the browser
    .\ExplorerToolkit-3.1.2.ps1 -Action Install  # desktop/start-menu shortcut + fresh .ico
#>

param(
    [ValidateSet('Menu','ResetViews','RestoreViews','ApplyExtras','RevertExtras','SaveCtx','RestoreCtx','RebuildIcons','QuickAccess','Browse','Install','Uninstall','Icon','Rename','Services','CtxAddons','CtxRemove','Duplicates')]
    [string]$Action = 'Menu',
    [string]$Target,        # open/search target for the browser
    [string]$BackupFile,
    [string]$SearchRoot,
    [string]$Pattern = '*'
)

$ErrorActionPreference = 'Stop'

# ===========================================================================
# Shared helpers
# ===========================================================================
$Adv      = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$Themes   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

$DataRoot   = Join-Path $env:LOCALAPPDATA 'DGsImageTools'
$BackupDir  = Join-Path $DataRoot 'Backups'
$ResultsDir = Join-Path $DataRoot 'SearchResults'
$IconDir    = Join-Path $DataRoot 'Icons'
foreach ($dir in @($DataRoot, $BackupDir, $ResultsDir, $IconDir)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}
$DefaultIcon = Join-Path $IconDir 'explorer-toolkit-v3.1.2.ico'

$ShellKeys = @(
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags',
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU',
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\COMB\Bags',
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\COMB\BagMRU',
    'HKCU:\Software\Microsoft\Windows\Shell\Bags',
    'HKCU:\Software\Microsoft\Windows\Shell\BagMRU',
    'HKCU:\Software\Microsoft\Windows\ShellNoRoam\Bags',
    'HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU'
)

function Stop-Explorer {
    if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
        Stop-Process -Name explorer -Force
        Start-Sleep -Seconds 2
    }
}

function Start-Explorer {
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
        Start-Sleep -Seconds 2
    }
}

function Get-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ===========================================================================
# 1. Reset all folder / desktop views to Icons (+ backup)
# ===========================================================================
function Remove-ShellKeys {
    foreach ($key in $ShellKeys) {
        if (Test-Path -LiteralPath $key) {
            Remove-Item -LiteralPath $key -Recurse -Force
            Write-Host "Removed: $key"
        }
    }
}

function Export-RegistryRoots {
    param([string[]]$Roots, [string]$OutFile)

    $blocks = New-Object System.Collections.Generic.List[string]
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath "Registry::$root")) { continue }
        $tmp = Join-Path $env:TEMP ("reg_{0}.reg" -f ([guid]::NewGuid().ToString('N')))
        try {
            & reg.exe export $root $tmp /y | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Registry export failed: $root" }
            $lines = Get-Content -LiteralPath $tmp -Encoding Unicode
            if ($lines.Count -gt 2) { $blocks.Add(($lines[2..($lines.Count - 1)] -join "`r`n")) }
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    if ($blocks.Count -eq 0) { throw 'No registry entries found to back up.' }

    $content = "Windows Registry Editor Version 5.00`r`n`r`n" + ($blocks -join "`r`n`r`n")
    Set-Content -LiteralPath $OutFile -Value $content -Encoding Unicode
}

function Invoke-ResetViews {
    $stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = if ($BackupFile) { $BackupFile } else { Join-Path $BackupDir "ExplorerViews_Backup_$stamp.reg" }

    $viewRoots = @(
        'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell',
        'HKCU\Software\Microsoft\Windows\Shell',
        'HKCU\Software\Microsoft\Windows\ShellNoRoam'
    )
    Export-RegistryRoots -Roots $viewRoots -OutFile $backup
    Write-Host "View backup saved: $backup" -ForegroundColor Yellow

    Stop-Explorer
    Remove-ShellKeys

    if (-not (Test-Path -LiteralPath $Adv)) { New-Item -Path $Adv -Force | Out-Null }
    Set-ItemProperty -Path $Adv -Name HideIcons      -Value 0 -Type DWord
    Set-ItemProperty -Path $Adv -Name ShowSuperHidden -Value 0 -Type DWord
    Set-ItemProperty -Path $Adv -Name LaunchTo        -Value 1 -Type DWord
    Remove-ItemProperty -Path $Adv -Name NonEnum -ErrorAction SilentlyContinue

    & ie4uinit.exe -show
    Start-Explorer
    Write-Host 'All folder and desktop views were reset to default (Icons).' -ForegroundColor Green
    Write-Host "Restore old views: powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action RestoreViews -BackupFile `"$backup`"" -ForegroundColor Cyan
}

function Invoke-RestoreViews {
    if (-not $BackupFile -or -not (Test-Path -LiteralPath $BackupFile)) {
        throw 'Backup file not found. Use -BackupFile <path.reg>.'
    }
    & reg.exe import "$BackupFile"
    if ($LASTEXITCODE -ne 0) { throw 'View restore failed' }
    Stop-Explorer
    Start-Explorer
    & ie4uinit.exe -show
    Write-Host "Views restored from: $BackupFile" -ForegroundColor Green
}

# ===========================================================================
# 2. Extra Explorer options (apply / revert)
# ===========================================================================
$ExtraTweaks = @(
    @{ Path = $Adv;    Name = 'HideFileExt';            Set = 0; Default = 1; Description = 'Show file extensions' },
    @{ Path = $Adv;    Name = 'Hidden';                 Set = 1; Default = 2; Description = 'Show hidden files' },
    @{ Path = $Adv;    Name = 'ShowSuperHidden';        Set = 1; Default = 0; Description = 'Show protected OS files' },
    @{ Path = $Adv;    Name = 'NavPaneExpandToCurrentFolder'; Set = 1; Default = 0; Description = 'Expand nav pane to current folder' },
    @{ Path = $Adv;    Name = 'ShowSyncProviderNotifications'; Set = 0; Default = 1; Description = 'Hide OneDrive/sync notifications' },
    @{ Path = $Adv;    Name = 'LaunchTo';               Set = 1; Default = 2; Description = 'Open Explorer to This PC' },
    @{ Path = $Adv;    Name = 'SeparateProcess';        Set = 1; Default = 0; Description = 'Each Explorer window in own process' },
    @{ Path = $Adv;    Name = 'ServerAdminUI';          Set = 0; Default = 1; Description = 'Full context menu (no "Show more options")' },
    @{ Path = $Adv;    Name = 'AutoCheckSelect';        Set = 1; Default = 0; Description = 'Item check boxes always on' },
    @{ Path = $Adv;    Name = 'DontPrettyPath';         Set = 0; Default = 1; Description = 'Keep uppercase path display' },
    @{ Path = $Adv;    Name = 'HideIcons';              Set = 0; Default = 1; Description = 'Always show desktop icons' },
    @{ Path = $Adv;    Name = 'IconsOnly';              Set = 0; Default = 1; Description = 'Show thumbnails (not just icons)' },
    @{ Path = $Adv;    Name = 'TaskbarAl';              Set = 0; Default = 1; Description = 'Taskbar icons aligned left' },
    @{ Path = $Adv;    Name = 'ShowCortanaButton';      Set = 0; Default = 1; Description = 'Hide Cortana button' },
    @{ Path = $Adv;    Name = 'ShowTaskViewButton';     Set = 0; Default = 1; Description = 'Hide Task View button' },
    @{ Path = $Adv;    Name = 'TaskbarMn';              Set = 0; Default = 1; Description = 'Hide Taskbar Widgets' },
    @{ Path = $Adv;    Name = 'TaskbarDa';              Set = 0; Default = 1; Description = 'Hide Taskbar Chat/Copilot' },
    @{ Path = $Adv;    Name = 'MMTaskbarEnabled';       Set = 1; Default = 0; Description = 'Show taskbar on all monitors' },
    @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'MenuShowDelay'; Set = '150'; Default = '400'; String = $true; Description = 'Faster menus (delay 150ms)' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{20D04FE0-3AEA-1069-A2D8-08002B30309D}'; Set = 0; Default = 1; Description = 'Show "This PC" on desktop' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'; Set = 0; Default = 1; Description = 'Show "Network" on desktop' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}'; Set = 0; Default = 1; Description = 'Show "Control Panel" on desktop' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{645FF040-5081-101B-9F08-00AA002F954E}'; Set = 0; Default = 1; Description = 'Show "Recycle Bin" on desktop' },
    @{ Path = $Themes; Name = 'AppsUseLightTheme';      Set = 0; Default = 1; Description = 'Dark mode (apps/Explorer)' },
    @{ Path = $Themes; Name = 'SystemUsesLightTheme';   Set = 0; Default = 1; Description = 'Dark mode (system/taskbar)' },
    @{ Path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Name = '(Default)'; Set = ''; Default = $null; String = $true; Description = 'Classic context menu (Win11)' }
)

function Set-ExtraTweaks {
    param([switch]$Revert)
    foreach ($t in $ExtraTweaks) {
        if (-not (Test-Path -LiteralPath $t.Path)) {
            if ($Revert -and $null -eq $t.Default) { continue }
            New-Item -Path $t.Path -Force | Out-Null
        }
        $value = if ($Revert) { if ($null -eq $t.Default) { '' } else { $t.Default } } else { $t.Set }

        if ($t.String -or $value -is [string]) {
            Set-ItemProperty -Path $t.Path -Name $t.Name -Value $value -Type String
        } else {
            Set-ItemProperty -Path $t.Path -Name $t.Name -Value $value -Type DWord
        }
        Write-Host ("{0,-8}: {1}" -f $(if ($Revert) { 'Reverted' } else { 'Applied' }), $t.Description)
    }
}

function Invoke-Extras {
    param([switch]$Revert)
    Stop-Explorer
    Set-ExtraTweaks -Revert:$Revert
    if ($Revert) {
        Remove-Item -LiteralPath 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue
    }
    & ie4uinit.exe -show
    Start-Explorer
    Write-Host ("Extra Explorer options {0}." -f $(if ($Revert) { 'reverted to defaults' } else { 'applied' })) -ForegroundColor Green
}

# ===========================================================================
# 3. Context-menu save / restore
# ===========================================================================
$ContextMenuRoots = @(
    'HKCU\Software\Classes\*\shell',
    'HKCU\Software\Classes\*\shellex',
    'HKCU\Software\Classes\AllFilesystemObjects\shell',
    'HKCU\Software\Classes\AllFilesystemObjects\shellex',
    'HKCU\Software\Classes\Directory\shell',
    'HKCU\Software\Classes\Directory\shellex',
    'HKCU\Software\Classes\Directory\Background\shell',
    'HKCU\Software\Classes\Directory\Background\shellex',
    'HKCU\Software\Classes\Folder\shell',
    'HKCU\Software\Classes\Folder\shellex',
    'HKCU\Software\Classes\Drive\shell',
    'HKCU\Software\Classes\Drive\shellex',
    'HKCU\Software\Classes\LibraryFolder\shell',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Shell\Approved'
)

function Save-ContextMenu {
    $stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $cmFile = if ($BackupFile) { $BackupFile } else { Join-Path $BackupDir "ContextMenu_Backup_$stamp.reg" }

    $blocks = New-Object System.Collections.Generic.List[string]
    foreach ($root in $ContextMenuRoots) {
        if (-not (Test-Path -LiteralPath "Registry::$root")) { continue }
        $tmp = Join-Path $env:TEMP ("cm_{0}.reg" -f ([guid]::NewGuid().ToString('N')))
        & reg.exe export $root $tmp /y | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "Export failed: $root"; continue }
        $lines = Get-Content -LiteralPath $tmp -Encoding Unicode
        if ($lines.Count -gt 2) { $blocks.Add(($lines[2..($lines.Count - 1)] -join "`r`n")) }
        Remove-Item -LiteralPath $tmp -Force
    }
    if ($blocks.Count -eq 0) { throw 'No context-menu entries found to save.' }

    $content = "Windows Registry Editor Version 5.00`r`n`r`n" + ($blocks -join "`r`n`r`n")
    Set-Content -LiteralPath $cmFile -Value $content -Encoding Unicode

    Write-Host "Saved $($blocks.Count) context-menu section(s) -> $cmFile" -ForegroundColor Green
}

function Restore-ContextMenu {
    if (-not $BackupFile -or -not (Test-Path -LiteralPath $BackupFile)) { throw "Not found: $BackupFile" }
    & reg.exe import "$BackupFile"
    if ($LASTEXITCODE -ne 0) { throw 'reg import failed' }
    & ie4uinit.exe -show
    Write-Host "Context menu restored from: $BackupFile" -ForegroundColor Green
}

# ===========================================================================
# 4. Rebuild icon cache + reset Quick Access
# ===========================================================================
function Invoke-RebuildIcons {
    Stop-Explorer
    $cacheDirs = @($env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'))
    foreach ($dir in $cacheDirs) {
        Get-ChildItem -LiteralPath $dir -Filter 'iconcache*' -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $dir -Filter 'thumbcache*' -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'IconCache.db') -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Adv) { Set-ItemProperty -Path $Adv -Name 'IconCacheRebuild' -Value 1 -Type DWord -ErrorAction SilentlyContinue }
    & ie4uinit.exe -show
    Start-Explorer
    Write-Host 'Icon cache rebuilt.' -ForegroundColor Green
}

function Invoke-QuickAccessReset {
    $ad = Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations'
    $cd = Join-Path $env:APPDATA 'Microsoft\Windows\Recent\CustomDestinations'
    Stop-Explorer
    Get-ChildItem -LiteralPath $ad -Filter '*.automaticDestinations-ms' -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $cd -Filter '*.customDestinations-ms' -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Start-Explorer
    Write-Host 'Quick Access (pinned folders / recent files) reset.' -ForegroundColor Green
}

# ===========================================================================
# 5. File & folder browser
# ===========================================================================
function Invoke-OpenItem {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        if (Test-Path -LiteralPath $Path -PathType Container) { Start-Process explorer.exe -ArgumentList "`"$Path`"" }
        else { Start-Process -FilePath $Path }
    } else { Write-Warning "Not found: $Path" }
}

function Find-OnPC {
    param([string]$Root, [string]$Patt, [switch]$Folders, [int]$Limit = 300)

    if (-not $Root) {
        $Root = Read-Host 'Search root (e.g. C:\ , D:\ , or leave blank for your profile)'
        if (-not $Root) { $Root = $env:USERPROFILE }
    }
    if (-not (Test-Path -LiteralPath $Root)) { Write-Warning "Path does not exist: $Root"; return @() }
    if (-not $Patt -or $Patt -eq '*') {
        $Patt = Read-Host 'Name or wildcard (e.g. report, *.pdf, *.jpg)'
        if (-not $Patt) { $Patt = '*' }
    }

    Write-Host "Searching '$Root' for $Patt (up to $Limit results, this may take a moment)..." -ForegroundColor Yellow

    $isWild = $Patt -match '[\*\?]'
    if ($Folders) {
        $results = Get-ChildItem -Path $Root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*$Patt*" } |
            Select-Object -First $Limit
    } elseif ($isWild) {
        $results = Get-ChildItem -Path $Root -Filter $Patt -Recurse -File -Force -ErrorAction SilentlyContinue |
            Select-Object -First $Limit
    } else {
        $results = Get-ChildItem -Path $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*$Patt*" } |
            Select-Object -First $Limit
    }
    return @($results)
}

function Show-Results {
    param($Items, [string]$Title)
    if (-not $Items -or $Items.Count -eq 0) { Write-Host 'No results found.' -ForegroundColor Yellow; return }
    Write-Host "`n=== $Title ($($Items.Count)) ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $kind = if ($Items[$i].PSIsContainer) { '[DIR] ' } else { '      ' }
        Write-Host ('{0,4}) {1}{2}' -f ($i + 1), $kind, $Items[$i].FullName)
    }
    while ($true) {
        $c = Read-Host "`nNumber=select, s=save list to file, Enter=done"
        if (-not $c) { return }
        if ($c -eq 's') {
            $listFile = Join-Path $ResultsDir "SearchResults_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
            $Items | Select-Object -ExpandProperty FullName | Set-Content -LiteralPath $listFile
            Write-Host "Saved -> $listFile" -ForegroundColor Green
            continue
        }
        $n = 0
        if ([int]::TryParse($c, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) {
            $sel = $Items[$n - 1]
            Write-Host '[o]=open  [f]=show in folder  [c]=copy path'
            $act = Read-Host 'Action'
            switch ($act) {
                'o' { Invoke-OpenItem -Path $sel.FullName }
                'f' { Start-Process explorer.exe -ArgumentList "/select,`"$($sel.FullName)`"" }
                'c' { Set-Clipboard -Value $sel.FullName; Write-Host 'Path copied.' -ForegroundColor Green }
                default { Invoke-OpenItem -Path $sel.FullName }
            }
            return
        }
        Write-Host "Invalid: $c" -ForegroundColor Yellow
    }
}

function Start-Browser {
    if ($Target) {
        if (Test-Path -LiteralPath $Target -PathType Container) { Start-Process explorer.exe -ArgumentList "`"$Target`""; return }
        Show-Results -Items (,([pscustomobject]@{ FullName = $Target; PSIsContainer = $false })) -Title 'Target'
        return
    }

    $current = $env:USERPROFILE
    $history = New-Object System.Collections.Generic.Stack[string]

    while ($true) {
        Write-Host "`n================ FILE & FOLDER BROWSER ================" -ForegroundColor Cyan
        Write-Host "Current: $current"
        Write-Host "[Enter]=open item by number | u=up | b=back | o=open in new window | s=search files | d=search folders | q=quit"
        Write-Host '------------------------------------------------------'

        $dirs  = @()
        $files = @()
        try {
            $dirs  = @(Get-ChildItem -LiteralPath $current -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)
            $files = @(Get-ChildItem -LiteralPath $current -File -Force -ErrorAction SilentlyContinue | Sort-Object Name)
        } catch { Write-Warning $_.Exception.Message }

        $n = 0
        foreach ($d in $dirs)  { $n++; Write-Host ('{0,4}. [DIR]  {1}' -f $n, $d.Name) -ForegroundColor Yellow }
        foreach ($f in $files) { $n++; Write-Host ('{0,4}.       {1}  ({2})' -f $n, $f.Name, $f.Extension) }
        if ($n -eq 0) { Write-Host '   (empty or access denied)' -ForegroundColor DarkGray }

        $choice = Read-Host 'Choice'
        switch ($choice.ToLower()) {
            'q' { return }
            'u' {
                $parent = Split-Path -Path $current -Parent
                if ($parent) { $history.Push($current); $current = $parent }
            }
            'b' {
                if ($history.Count -gt 0) { $current = $history.Pop() } else { Write-Host 'No history.' -ForegroundColor Yellow }
            }
            'o' {
                $num = 0
                $sel = Read-Host 'Open item number in new window'
                if ([int]::TryParse($sel, [ref]$num)) {
                    $all = @($dirs) + @($files)
                    if ($num -ge 1 -and $num -le $all.Count) {
                        Start-Process explorer.exe -ArgumentList "`"$($all[$num-1].FullName)`"" }
                }
            }
            's' { Show-Results -Items (Find-OnPC -Root $current -Patt $null) -Title 'Files' }
            'd' { Show-Results -Items (Find-OnPC -Root $current -Patt $null -Folders) -Title 'Folders' }
            'g' { $g = Read-Host 'Go to path'; if ($g -and (Test-Path -LiteralPath $g)) { $history.Push($current); $current = (Get-Item -LiteralPath $g).FullName } else { Write-Warning 'Invalid path.' } }
            default {
                $num = 0
                if ([int]::TryParse($choice, [ref]$num)) {
                    $all = @($dirs) + @($files)
                    if ($num -ge 1 -and $num -le $all.Count) {
                        $picked = $all[$num - 1]
                        if ($picked.PSIsContainer) { $history.Push($current); $current = $picked.FullName }
                        else { Invoke-OpenItem -Path $picked.FullName }
                    } else { Write-Host 'Invalid number.' -ForegroundColor Yellow }
                } elseif ($choice) { Write-Host "Unknown: $choice" -ForegroundColor Yellow }
            }
        }
    }
}

# ===========================================================================
# 6. Fresh .ico generator + installer
# ===========================================================================
function Get-RoundRectPath {
    param([System.Drawing.Rectangle]$Rect, [float]$Rad)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [int]($Rad * 2)
    $p.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $p.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $p.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $p.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function New-FreshIcon {
    param([string]$OutFile)
    Add-Type -AssemblyName System.Drawing

    $sizes  = @(16, 24, 32, 48, 64, 128, 256)
    $frames = @()

    foreach ($s in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($s, $s)
        $g   = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = 'ClearTypeGridFit'
        $g.Clear([System.Drawing.Color]::Transparent)

        $margin = [int][Math]::Max(1, ($s * 0.04))
        $rect   = New-Object System.Drawing.Rectangle($margin, $margin, ($s - 2 * $margin), ($s - 2 * $margin))
        $rad    = [Math]::Max(2, ($s * 0.22))
        $path   = Get-RoundRectPath -Rect $rect -Rad $rad

        $c1 = [System.Drawing.Color]::FromArgb(255, 47, 128, 247)
        $c2 = [System.Drawing.Color]::FromArgb(255, 15, 76, 180)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 55)
        $g.FillPath($brush, $path)

        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 255, 255), ([float][Math]::Max(1, $s * 0.045)))
        $g.DrawPath($pen, $path)

        $font = New-Object System.Drawing.Font('Segoe UI', ([float]($s * 0.50)), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $sf   = New-Object System.Drawing.StringFormat
        $sf.Alignment      = 'Center'
        $sf.LineAlignment  = 'Center'
        $textRect = New-Object System.Drawing.RectangleF($rect.X, $rect.Y, $rect.Width, $rect.Height)
        $g.DrawString('E', $font, ([System.Drawing.Brushes]::White), $textRect, $sf)

        $g.Dispose()

        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $frames += ,@{ Size = $s; Bytes = $ms.ToArray() }
        $ms.Dispose(); $bmp.Dispose()
    }

    # Build the .ico container (PNG-compressed frames)
    $out = New-Object System.IO.MemoryStream
    $bw  = New-Object System.IO.BinaryWriter($out)
    $bw.Write([uint16]0)                       # reserved
    $bw.Write([uint16]1)                       # type = icon
    $bw.Write([uint16]$frames.Count)
    $offset = 6 + (16 * $frames.Count)
    foreach ($f in $frames) {
        $dim = if ($f.Size -ge 256) { 0 } else { [byte]$f.Size }
        $bw.Write([byte]$dim)                  # width
        $bw.Write([byte]$dim)                  # height
        $bw.Write([byte]0)                     # colors
        $bw.Write([byte]0)                     # reserved
        $bw.Write([uint16]1)                   # planes
        $bw.Write([uint16]32)                  # bit count
        $bw.Write([uint32]$f.Bytes.Length)
        $bw.Write([uint32]$offset)
        $offset += $f.Bytes.Length
    }
    foreach ($f in $frames) { $bw.Write([byte[]]$f.Bytes) }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($OutFile, $out.ToArray())
    $bw.Dispose(); $out.Dispose()

    Write-Host "Fresh icon created: $OutFile" -ForegroundColor Green
    return $OutFile
}

$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$LnkName    = 'Explorer Toolkit 3.1.2.lnk'

function Install-Shortcut {
    $icoPath = $DefaultIcon
    New-FreshIcon -OutFile $icoPath | Out-Null

    $shell     = New-Object -ComObject WScript.Shell
    $desktop   = [Environment]::GetFolderPath('Desktop')
    $programs  = Join-Path ([Environment]::GetFolderPath('Programs')) $LnkName
    $targets   = @((Join-Path $desktop $LnkName), $programs)

    foreach ($lnkPath in $targets) {
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath       = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $lnk.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Action Menu"
        $lnk.WorkingDirectory = $PSScriptRoot
        $lnk.IconLocation     = "$icoPath,0"
        $lnk.Description      = 'Explorer Toolkit v3.1.2 - views, options, context menu, browser, duplicates'
        $lnk.Save()
        Write-Host "Shortcut created: $lnkPath" -ForegroundColor Green
    }
    Write-Host 'Use the desktop shortcut any time to open the toolkit menu.' -ForegroundColor Cyan
}

function Uninstall-Shortcut {
    $desktop  = [Environment]::GetFolderPath('Desktop')
    $programs = Join-Path ([Environment]::GetFolderPath('Programs')) $LnkName
    foreach ($p in @((Join-Path $desktop $LnkName), $programs)) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Write-Host "Removed: $p" }
    }
}

# ===========================================================================
# 9. Explorer context-menu add-ons (Open PowerShell/CMD here, Copy path)
# ===========================================================================
function Set-ContextMenuAddons {
    param([switch]$Remove)

    $addons = @(
        @{ Key = 'PowerShellHere'; Verb = 'Open PowerShell here'
           Cmd = "powershell.exe -NoExit -Command Set-Location -LiteralPath '%V'"
           Icon = 'powershell.exe,0'
           Roots = @('Directory\shell','Directory\Background\shell','Drive\shell') },
        @{ Key = 'CmdHere'; Verb = 'Open CMD here'
           Cmd = "cmd.exe /k cd /d `"%V`""
           Icon = 'cmd.exe,0'
           Roots = @('Directory\shell','Directory\Background\shell','Drive\shell') },
        @{ Key = 'CopyPath'; Verb = 'Copy path to clipboard'
           Cmd = "powershell.exe -NoProfile -WindowStyle Hidden -Command ""Set-Clipboard -Value '%1'"""
           Icon = 'imageres.dll,2'
           Roots = @('Directory\shell','Drive\shell','*\shell') },
        @{ Key = 'CopyPath'; Verb = 'Copy folder path to clipboard'
           Cmd = "powershell.exe -NoProfile -WindowStyle Hidden -Command ""Set-Clipboard -Value '%V'"""
           Icon = 'imageres.dll,2'
           Roots = @('Directory\Background\shell') }
    )

    foreach ($a in $addons) {
        foreach ($root in $a.Roots) {
            $path = "HKCU:\Software\Classes\$root\$($a.Key)"
            if ($Remove) {
                if (Test-Path -LiteralPath $path) {
                    Remove-Item -LiteralPath $path -Recurse -Force
                    Write-Host "Removed: $($a.Verb)  ($root)"
                }
            } else {
                if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
                Set-ItemProperty -LiteralPath $path -Name '(Default)' -Value $a.Verb -Type String
                Set-ItemProperty -LiteralPath $path -Name 'Icon' -Value $a.Icon -Type String
                $cmdPath = Join-Path $path 'command'
                if (-not (Test-Path -LiteralPath $cmdPath)) { New-Item -Path $cmdPath -Force | Out-Null }
                Set-ItemProperty -LiteralPath $cmdPath -Name '(Default)' -Value $a.Cmd -Type String
                Write-Host "Added: $($a.Verb)  ($root)"
            }
        }
    }
    & ie4uinit.exe -show
    $state = if ($Remove) { 'removed' } else { 'added' }
    Write-Host "Context-menu add-ons $state. Right-click a folder/file to see them." -ForegroundColor Green
}

# ===========================================================================
# 7. Batch renamer - strip " (1)" / " (1) (1)" copy suffixes
# ===========================================================================
function Invoke-Renamer {
    param([string]$Folder)

    $script:renamedDone = 0
    $script:renamedSkip = 0

    if (-not $Folder) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the folder containing the files you want to rename'
        $dialog.ShowNewFolderButton = $false
        $result = $dialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }))
        if ($result -ne 'OK' -or [string]::IsNullOrEmpty($dialog.SelectedPath)) {
            Write-Warning 'Folder selection was canceled. No files were renamed.'; return
        }
        $Folder = $dialog.SelectedPath
    }
    if (-not (Test-Path -LiteralPath $Folder)) { throw "Folder not found: $Folder" }
    Write-Host "Selected folder: $Folder" -ForegroundColor Cyan

    $renamed = 0; $skipped = 0
    Get-ChildItem -Path $Folder -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $old = $_.Name
        $newBase = $_.BaseName -replace '(\s*\(\d{1,3}\))+$', ''
        $new = $newBase + $_.Extension
        if ($old -ne $new) {
            $dest = Join-Path -Path $_.DirectoryName -ChildPath $new
            if (Test-Path -LiteralPath $dest) {
                Write-Warning "Skipped: '$old' -> '$new' already exists."
                $script:renamedSkip++
            } else {
                Rename-Item -LiteralPath $_.FullName -NewName $new
                Write-Host "Renamed: '$old' -> '$new'" -ForegroundColor Green
                $script:renamedDone++
            }
        }
    }
    Write-Host ("Done. Renamed: {0}, Skipped: {1}" -f $script:renamedDone, $script:renamedSkip) -ForegroundColor Cyan
}

# ===========================================================================
# 8. Reset services (Atmosphere pack)
# ===========================================================================
$AtmosphereServicesPath = Join-Path $env:windir 'AtmosphereDesktop\6. Advanced Configuration\Services'
$AtmosphereOtherPath    = Join-Path $env:windir 'AtmosphereModules\Other'

function Invoke-ServicesReset {
    if (-not (Test-Path -LiteralPath $AtmosphereServicesPath)) {
        Write-Warning "Services in Atmosphere folder not found, can't continue. ($AtmosphereServicesPath)"; return
    }
    Write-Host 'This will reset the configuration of services in the Atmosphere folder.' -ForegroundColor Yellow
    Write-Host 'Disabling services often breaks features, and if you are experiencing an issue, this might help.'
    $confirm = Read-Host 'Continue? [y/n]'
    if ($confirm.ToLower() -ne 'y') { return }

    if (-not (Get-IsAdmin)) { Write-Warning 'Run as Administrator for a full services restore.' }

    Write-Host 'Enabling services in the Atmosphere folder... This might take a while.' -ForegroundColor Cyan
    $scripts = Get-ChildItem -Path $AtmosphereServicesPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*(default)*' }
    foreach ($s in $scripts) {
        Write-Host "Running $($s.Name)..."
        Start-Process -FilePath $s.FullName -ArgumentList '/silent' -WindowStyle Minimized -Wait
    }

    $winServices    = Join-Path $AtmosphereOtherPath 'winServices.reg'
    $atmosServices  = Join-Path $AtmosphereOtherPath 'AtmosphereServices.reg'
    if ((Test-Path -LiteralPath $winServices) -and (Test-Path -LiteralPath $atmosServices)) {
        Write-Host ''
        Write-Host 'Full services restoration:'
        Write-Host ' 1) Restore a full backup of the DEFAULT Windows services'
        Write-Host ' 2) Restore a full backup of the DEFAULT Atmosphere services'
        Write-Host ' 3) Nothing'
        $pick = Read-Host 'Choose 1/2/3'
        switch ($pick) {
            '1' { & reg.exe import $winServices | Out-Null; Write-Host 'Windows services restored.' -ForegroundColor Green }
            '2' { & reg.exe import $atmosServices | Out-Null; Write-Host 'Atmosphere services restored.' -ForegroundColor Green }
        }
    }

    Write-Host 'Finished.' -ForegroundColor Green
    $restart = Read-Host 'A restart is required. Restart now? [y/n]'
    if ($restart.ToLower() -eq 'y') { shutdown /r /t 0 }
}

# ===========================================================================
# 10. Duplicate file finder (with delete options)
# ===========================================================================
function Remove-DuplicateFile {
    param([string]$Path, [switch]$Recycle)
    Add-Type -AssemblyName Microsoft.VisualBasic
    if ($Recycle) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    } else {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Invoke-FindDuplicates {
    param([string]$Folder)

    if (-not $Folder) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the folder to scan for duplicate files'
        $dialog.ShowNewFolderButton = $false
        $result = $dialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }))
        if ($result -ne 'OK' -or [string]::IsNullOrEmpty($dialog.SelectedPath)) {
            Write-Warning 'Folder selection was canceled.'; return
        }
        $Folder = $dialog.SelectedPath
    }
    if (-not (Test-Path -LiteralPath $Folder)) { throw "Folder not found: $Folder" }

    Write-Host "Scan mode:" -ForegroundColor Cyan
    Write-Host ' 1) Fast - same file name + size (may include false positives)'
    Write-Host ' 2) Exact - identical content (hash, slower)'
    $mode = Read-Host 'Choose 1/2'
    $exact = $mode -eq '2'

    $recycleAnswer = Read-Host 'Send deleted duplicates to Recycle Bin? [y/n]'
    $useRecycle = $recycleAnswer.ToLower() -eq 'y'

    Write-Host "Scanning '$Folder' ..." -ForegroundColor Yellow
    $files = @(Get-ChildItem -Path $Folder -File -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
    Write-Host "Found $($files.Count) non-empty files. Grouping..." -ForegroundColor Yellow

    $groups = @()
    if ($exact) {
        $map = @{}
        $i = 0
        foreach ($f in $files) {
            $i++
            if ($i % 200 -eq 0) { Write-Progress -Activity 'Hashing files' -Status "$i / $($files.Count)" -PercentComplete (($i * 100) / $files.Count) }
            $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA1 -ErrorAction SilentlyContinue).Hash
            if (-not $hash) { continue }
            if (-not $map.ContainsKey($hash)) { $map[$hash] = New-Object System.Collections.Generic.List[object] }
            $map[$hash].Add($f)
        }
        Write-Progress -Activity 'Hashing files' -Completed
        $groups = @($map.Values | Where-Object { $_.Count -gt 1 })
    } else {
        $map = @{}
        foreach ($f in $files) {
            $key = "$($f.Name)|$($f.Length)"
            if (-not $map.ContainsKey($key)) { $map[$key] = New-Object System.Collections.Generic.List[object] }
            $map[$key].Add($f)
        }
        $groups = @($map.Values | Where-Object { $_.Count -gt 1 })
    }

    if ($groups.Count -eq 0) { Write-Host 'No duplicates found.' -ForegroundColor Green; return }
    Write-Host "Found $($groups.Count) duplicate group(s)." -ForegroundColor Green

    $deleted = 0; $freed = [long]0; $skipped = 0; $auto = $false
    $gnum = 0
    foreach ($g in $groups) {
        $gnum++
        $sorted = @($g | Sort-Object LastWriteTimeUtc -Descending)
        $sizeMB = [Math]::Round($sorted[0].Length / 1MB, 2)
        Write-Host "`n=== Group $gnum ($($sorted.Count) copies, $($sorted[0].Length) bytes each, $sizeMB MB) ===" -ForegroundColor Cyan
        for ($j = 0; $j -lt $sorted.Count; $j++) {
            $tag = if ($j -eq 0) { ' [NEWEST]' } elseif ($j -eq $sorted.Count - 1) { ' [OLDEST]' } else { '' }
            Write-Host (' {0}) {1}{2}' -f ($j + 1), $sorted[$j].FullName, $tag)
        }

        $action = $null
        if ($auto) { $action = 'n' }
        while ($true) {
            if (-not $action) {
                Write-Host '[n]=keep newest, [o]=keep oldest, [f]=keep first listed, [s]=skip, [a]=auto keep-newest for all remaining, [q]=quit'
                $action = Read-Host 'Choice'
            }
            switch ($action.ToLower()) {
                'q' { Write-Host "Stopped. Deleted so far: $deleted"; return }
                's' { $skipped++; $action = $null; break }
                'a' { $auto = $true; $action = 'n' }
                { $_ -in 'n', 'o', 'f' } {
                    $keepIndex = switch ($action.ToLower()) { 'n' { 0 } 'o' { $sorted.Count - 1 } default { 0 } }
                    for ($j = 0; $j -lt $sorted.Count; $j++) {
                        if ($j -eq $keepIndex) { continue }
                        $victim = $sorted[$j].FullName
                        try {
                            Remove-DuplicateFile -Path $victim -Recycle:$useRecycle
                            Write-Host "Deleted: $victim" -ForegroundColor Green
                            $deleted++; $freed += $sorted[$j].Length
                        } catch { Write-Warning "Failed: $victim - $($_.Exception.Message)"; $skipped++ }
                    }
                    $action = $null
                    break
                }
                default { Write-Host "Unknown: $action" -ForegroundColor Yellow; $action = $null }
            }
            if (-not $action) { break }
        }
    }
    Write-Host "`nDone. Duplicates deleted: $deleted, Freed: $([Math]::Round($freed / 1MB, 2)) MB, Skipped: $skipped" -ForegroundColor Green
}

# ===========================================================================
# Interactive menu
# ===========================================================================
function Show-Menu {
    while ($true) {
        Write-Host ''
        Write-Host '============ EXPLORER TOOLKIT v3.1.2 ============' -ForegroundColor Cyan
        Write-Host ' 1. Reset all views (folders + desktop -> Icons)'
        Write-Host ' 2. Apply extra Explorer options'
        Write-Host ' 3. Revert extra Explorer options'
        Write-Host ' 4. Save context menu entries (.reg)'
        Write-Host ' 5. Restore context menu entries (.reg)'
        Write-Host ' 6. Rebuild icon / thumbnail cache'
        Write-Host ' 7. Reset Quick Access (pins + recent)'
        Write-Host ' 8. Browser - find files / folders on PC'
        Write-Host ' 9. Generate fresh .ico'
        Write-Host '10. Install (desktop + start menu shortcut)'
        Write-Host '11. Uninstall shortcuts'
        Write-Host '12. Batch renamer - strip " (1)" copy suffixes'
        Write-Host '13. Reset services (Atmosphere pack)'
        Write-Host '14. Add context-menu extras (PowerShell/CMD here, Copy path)'
        Write-Host '15. Remove context-menu extras'
        Write-Host '16. Find duplicate files (with delete options)'
        Write-Host '17. Restore views from backup (.reg)'
        Write-Host ' X. Exit'
        Write-Host '=============================================' -ForegroundColor Cyan

        $c = Read-Host 'Pick 1-17 / X'
        try {
            switch ($c.Trim().ToUpper()) {
                '1'  { $BackupFile = $null; Invoke-ResetViews }
                '2'  { Invoke-Extras }
                '3'  { Invoke-Extras -Revert }
                '4'  { $BackupFile = $null; Save-ContextMenu }
                '5'  {
                    $f = Read-Host 'Path to context-menu .reg'
                    if ($f) { $BackupFile = $f; $script:BackupFile = $f; Restore-ContextMenu }
                }
                '6'  { Invoke-RebuildIcons }
                '7'  { Invoke-QuickAccessReset }
                '8'  { Start-Browser }
                '9'  { New-FreshIcon -OutFile $DefaultIcon | Out-Null }
                '10' { Install-Shortcut }
                '11' { Uninstall-Shortcut }
                '12' { Invoke-Renamer }
                '13' { Invoke-ServicesReset }
                '14' { Set-ContextMenuAddons }
                '15' { Set-ContextMenuAddons -Remove }
                '16' { Invoke-FindDuplicates }
                '17' {
                    $f = Read-Host 'Path to views backup .reg'
                    if ($f) { $BackupFile = $f; $script:BackupFile = $f; Invoke-RestoreViews }
                }
                'X'  { return }
                default { Write-Host "Unknown choice: $c" -ForegroundColor Yellow }
            }
        } catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red }
    }
}

# ===========================================================================
# Entry point
# ===========================================================================
switch ($Action) {
    'Menu'         { Show-Menu }
    'ResetViews'   { Invoke-ResetViews }
    'RestoreViews' { Invoke-RestoreViews }
    'ApplyExtras'  { Invoke-Extras }
    'RevertExtras' { Invoke-Extras -Revert }
    'SaveCtx'      { Save-ContextMenu }
    'RestoreCtx'   { Restore-ContextMenu }
    'RebuildIcons' { Invoke-RebuildIcons }
    'QuickAccess'  { Invoke-QuickAccessReset }
    'Browse'       { Start-Browser }
    'Install'      { Install-Shortcut }
    'Uninstall'    { Uninstall-Shortcut }
    'Icon'         { New-FreshIcon -OutFile $DefaultIcon | Out-Null }
    'Rename'       { Invoke-Renamer -Folder $Target }
    'Services'     { Invoke-ServicesReset }
    'CtxAddons'    { Set-ContextMenuAddons }
    'CtxRemove'    { Set-ContextMenuAddons -Remove }
    'Duplicates'   { Invoke-FindDuplicates -Folder $Target }
}
