#Requires -Version 5.1
<#
.SYNOPSIS
    Converts a dark-theme PowerShell / WPF-UI script into a light-theme version.

.DESCRIPTION
    Scans a .ps1 (or any text) file for color literals and remaps them to
    light-theme equivalents. Handles:

      * Hex colors : #RGB, #RRGGBB, #AARRGGBB (WPF alpha-first)
      * Named XAML colors inside quotes : "Black" / 'White' (swapped)

    Three conversion strategies:

      Auto   (default)  -> use the curated dark->light palette when the color is
                           known, otherwise invert lightness (keep hue/saturation)
      Map               -> only remap colors found in the curated palette
      Invert            -> always invert lightness for every color

    The curated palette covers the common Tailwind slate/gray, VS Code and
    GitHub-dark palettes. Inversion is the generic fallback that works on any
    dark UI: dark backgrounds become light and light foregrounds become dark
    while keeping the original hue.

.PARAMETER Path
    A .ps1 file, or a folder (with -Recurse to include sub-folders).

.PARAMETER Mode
    Auto | Map | Invert  (see description). Default: Auto.

.PARAMETER OutputPath
    Output file. Ignored for folder input. If omitted, a ".light" copy is
    created next to the source unless -InPlace is used.

.PARAMETER InPlace
    Overwrite the source file. A ".bak" backup is written first.

.PARAMETER Recurse
    Recurse into sub-folders when Path is a folder.

.PARAMETER NoColorNames
    Do not touch quoted named colors (Black/White), only hex values.

.PARAMETER MappingFile
    Optional text file of extra "oldhex=newhex" pairs (one per line, '#'
    optional). Overrides the built-in palette for those keys.

.PARAMETER Preview
    Show the distinct color conversions and do not write any file.

.EXAMPLE
    .\Convert-To-LightTheme.ps1 -Path '.\MyGui.ps1'
    Writes MyGui.light.ps1 next to the source.

.EXAMPLE
    .\Convert-To-LightTheme.ps1 -Path '.\MyGui.ps1' -InPlace
    Replaces MyGui.ps1 (backup at MyGui.ps1.bak).

.EXAMPLE
    .\Convert-To-LightTheme.ps1 -Path '.\Scripts' -Recurse -InPlace
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path,

    [ValidateSet('Auto', 'Map', 'Invert')]
    [string]$Mode = 'Auto',

    [string]$OutputPath,

    [switch]$InPlace,

    [switch]$Recurse,

    [switch]$NoColorNames,

    [string]$MappingFile,

    [switch]$Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Curated dark -> light palette (hex without '#', uppercase) ────────────────
$script:DarkToLightMap = [ordered]@{
    # Tailwind slate
    '0F172A' = 'F8FAFC'; '1E293B' = 'F1F5F9'; '334155' = 'E2E8F0'; '475569' = 'CBD5E1'
    '64748B' = '94A3B8'; '94A3B8' = '64748B'; 'CBD5E1' = '475569'; 'E2E8F0' = '334155'
    'F1F5F9' = '1E293B'; 'F8FAFC' = '0F172A'
    # Tailwind gray
    '111827' = 'F9FAFB'; '1F2937' = 'F3F4F6'; '374151' = 'E5E7EB'; '4B5563' = 'D1D5DB'
    '6B7280' = '9CA3AF'; '9CA3AF' = '6B7280'; 'D1D5DB' = '4B5563'; 'E5E7EB' = '374151'
    'F3F4F6' = '1F2937'; 'F9FAFB' = '111827'
    # Neutral / VS Code Dark+
    '1E1E1E' = 'F3F3F3'; '252526' = 'FFFFFF'; '2D2D30' = 'F3F3F3'; '3E3E42' = 'E5E5E5'
    '333333' = 'F2F2F2'; '2B2B2B' = 'F4F4F4'; '181818' = 'FFFFFF'; '121212' = 'FFFFFF'
    '0A0A0A' = 'FFFFFF'; '202020' = 'FFFFFF'; '1A1A1A' = 'FFFFFF'
    # GitHub dark
    '0D1117' = 'FFFFFF'; '161B22' = 'F6F8FA'; '21262D' = 'EAEEF2'; '30363D' = 'D0D7DE'
    '8B949E' = '57606A'; 'C9D1D9' = '24292F'; 'F0F6FC' = '24292F'; '58A6FF' = '0969DA'
    # Pure
    'FFFFFF' = '0F172A'; '000000' = 'FFFFFF'
}

# Extra user-supplied mappings
if ($MappingFile) {
    if (-not (Test-Path -LiteralPath $MappingFile)) { throw "MappingFile not found: $MappingFile" }
    foreach ($line in (Get-Content -LiteralPath $MappingFile)) {
        $line = ($line -split '#')[0].Trim()
        if (-not $line) { continue }
        if ($line -match '^#?(?<a>[0-9A-Fa-f]{3,8})\s*=\s*#?(?<b>[0-9A-Fa-f]{3,8})$') {
            $script:DarkToLightMap[$Matches.a.ToUpper()] = $Matches.b.ToUpper()
        }
    }
}

# ── Color math helpers ────────────────────────────────────────────────────────
function Convert-HueToRgb {
    param([double]$p, [double]$q, [double]$t)
    if ($t -lt 0) { $t += 1 }
    if ($t -gt 1) { $t -= 1 }
    if ($t -lt (1.0 / 6.0)) { return $p + ($q - $p) * 6 * $t }
    if ($t -lt (1.0 / 2.0)) { return $q }
    if ($t -lt (2.0 / 3.0)) { return $p + ($q - $p) * ((2.0 / 3.0) - $t) * 6 }
    return $p
}

function Convert-RgbToHsl {
    param([double]$R, [double]$G, [double]$B)
    $rr = $R / 255.0; $gg = $G / 255.0; $bb = $B / 255.0
    $max = [Math]::Max($rr, [Math]::Max($gg, $bb))
    $min = [Math]::Min($rr, [Math]::Min($gg, $bb))
    $l = ($max + $min) / 2.0
    if ($max -eq $min) { return @(0.0, 0.0, $l) }
    $d = $max - $min
    $s = if ($l -gt 0.5) { $d / (2.0 - $max - $min) } else { $d / ($max + $min) }
    if ($max -eq $rr) { $h = (($gg - $bb) / $d) + $(if ($gg -lt $bb) { 6 } else { 0 }) }
    elseif ($max -eq $gg) { $h = (($bb - $rr) / $d) + 2 }
    else { $h = (($rr - $gg) / $d) + 4 }
    return @(($h / 6.0), $s, $l)
}

function Convert-HslToRgb {
    param([double]$H, [double]$S, [double]$L)
    if ($S -eq 0) { $v = [int][Math]::Round($L * 255); return @($v, $v, $v) }
    $q = if ($L -lt 0.5) { $L * (1 + $S) } else { $L + $S - $L * $S }
    $p = 2 * $L - $q
    $r = Convert-HueToRgb $p $q ($H + 1.0 / 3.0)
    $g = Convert-HueToRgb $p $q $H
    $b = Convert-HueToRgb $p $q ($H - 1.0 / 3.0)
    return @([int][Math]::Round($r * 255), [int][Math]::Round($g * 255), [int][Math]::Round($b * 255))
}

# ── Single color conversion ───────────────────────────────────────────────────
$script:PreviewMap = [ordered]@{}

function Get-LightColor {
    param([string]$Hex)

    $h = $Hex.TrimStart('#')
    $alpha = ''
    if ($h.Length -eq 8) {
        $alpha = $h.Substring(0, 2).ToUpper()
        $h = $h.Substring(2)
    } elseif ($h.Length -eq 3) {
        $h = '' + $h[0] + $h[0] + $h[1] + $h[1] + $h[2] + $h[2]
    }
    if ($h.Length -ne 6) { return $Hex }

    $h = $h.ToUpper()
    $r = [Convert]::ToInt32($h.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($h.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($h.Substring(4, 2), 16)

    $mapped = $script:DarkToLightMap[$h]
    if ($Mode -ne 'Invert' -and $mapped) {
        $new = $mapped
    } elseif ($Mode -eq 'Map') {
        $new = $h
    } else {
        $hsl = Convert-RgbToHsl $r $g $b
        $rgb = Convert-HslToRgb $hsl[0] $hsl[1] (1.0 - $hsl[2])
        $new = ('{0:X2}{1:X2}{2:X2}' -f $rgb[0], $rgb[1], $rgb[2])
    }

    $result = '#' + $alpha + $new
    $script:PreviewMap[$Hex.ToUpper()] = $result
    return $result
}

# ── Text conversion ───────────────────────────────────────────────────────────
$script:HexRegex = [regex]'#[0-9A-Fa-f]{8}\b|#[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{3}\b'
$script:NameRegex = [regex]'(?<q>["''])(?<c>Black|White)(?<q2>["''])'

function Convert-ThemeText {
    param([string]$Text)

    $evaluator = { param($m) Get-LightColor $m.Value }
    $out = $script:HexRegex.Replace($Text, $evaluator)

    if (-not $NoColorNames) {
        $nameEval = {
            param($m)
            $rep = if ($m.Groups['c'].Value -ieq 'Black') { 'White' } else { 'Black' }
            return $m.Groups['q'].Value + $rep + $m.Groups['q2'].Value
        }
        $out = $script:NameRegex.Replace($out, $nameEval)
    }
    return $out
}

# ── File helpers ──────────────────────────────────────────────────────────────
function Read-TextPreserveBom {
    param([string]$File)
    $bytes = [IO.File]::ReadAllBytes($File)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $text = if ($hasBom) { $utf8.GetString($bytes, 3, $bytes.Length - 3) } else { $utf8.GetString($bytes) }
    return [PSCustomObject]@{ Text = $text; Bom = $hasBom }
}

function Write-TextWithBom {
    param([string]$File, [string]$Text, [bool]$Bom)
    $enc = New-Object System.Text.UTF8Encoding($Bom)
    [IO.File]::WriteAllText($File, $Text, $enc)
}

# ── Collect targets ───────────────────────────────────────────────────────────
$resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
$isFolder = Test-Path -LiteralPath $resolved -PathType Container

$files = @()
if ($isFolder) {
    $gci = @{ LiteralPath = $resolved; Filter = '*.ps1'; File = $true }
    if ($Recurse) { $gci.Recurse = $true }
    $files = @(Get-ChildItem @gci)
    if ($files.Count -eq 0) { Write-Warning "No .ps1 files found in $resolved"; return }
} else {
    $files = @(Get-Item -LiteralPath $resolved)
}

# ── Process ───────────────────────────────────────────────────────────────────
$total = 0
foreach ($file in $files) {
    $src = $file.FullName
    $data = Read-TextPreserveBom $src
    $converted = Convert-ThemeText $data.Text

    $changed = -not [string]::Equals($data.Text, $converted, [System.StringComparison]::Ordinal)

    if ($Preview) {
        Write-Host ""
        Write-Host "=== $src ===" -ForegroundColor Cyan
        foreach ($k in $script:PreviewMap.Keys) { Write-Host ("  {0,-12} ->  {1}" -f $k, $script:PreviewMap[$k]) }
        if (-not $changed) { Write-Host "  (no color changes)" -ForegroundColor DarkGray }
        continue
    }

    if (-not $changed) {
        Write-Host "No color changes: $src" -ForegroundColor DarkGray
        continue
    }

    $dest = if ($InPlace) { $src }
            elseif ($OutputPath -and -not $isFolder) { $OutputPath }
            else { [IO.Path]::Combine($file.DirectoryName, ($file.BaseName + '.light' + $file.Extension)) }

    if ($InPlace) {
        $bak = $src + '.bak'
        if ($PSCmdlet.ShouldProcess($bak, 'Write backup')) {
            [IO.File]::WriteAllBytes($bak, [IO.File]::ReadAllBytes($src))
        }
    }

    if ($PSCmdlet.ShouldProcess($dest, 'Write light-theme script')) {
        Write-TextWithBom $dest $converted $data.Bom
        Write-Host "Wrote: $dest" -ForegroundColor Green
        $total++
    }
}

if (-not $Preview) { Write-Host "`nDone. $total file(s) converted." -ForegroundColor Green }