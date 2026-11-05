<#
.SYNOPSIS
DG Icon & Shortcut Changer
Version: 3.1.0
Author: DG
#>

param(
    [string]$InputPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Continue"

# Load Windows Forms & GDI+
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# High-resolution Icon Extractor from EXE/DLL
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class DgIconExtractor {
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    private static extern int ExtractIconEx(string file, int index, IntPtr[] large, IntPtr[] small, int count);
    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr h);
    public static Bitmap Get(string path, int index) {
        IntPtr[] large = new IntPtr[1];
        IntPtr[] small = new IntPtr[1];
        try {
            int n = ExtractIconEx(path, index, large, small, 1);
            if (n <= 0) return null;
            IntPtr h = large[0] != IntPtr.Zero ? large[0] : small[0];
            if (h == IntPtr.Zero) return null;
            using (Icon ic = Icon.FromHandle(h)) { return ic.ToBitmap(); }
        } catch { return null; }
        finally {
            if (large[0] != IntPtr.Zero) DestroyIcon(large[0]);
            if (small[0] != IntPtr.Zero) DestroyIcon(small[0]);
        }
    }
}
"@ -ReferencedAssemblies System.Drawing

# ===== HELPER: Load ANY icon or image as Bitmap =====
function Load-AnyIcoAsBitmap {
    param($Path)
    try {
        $img = [System.Drawing.Image]::FromFile($Path)
        $bmp = [System.Drawing.Bitmap]::new($img)
        $img.Dispose()
        return $bmp
    } catch {}
    try {
        $ic = [System.Drawing.Icon]::new($Path)
        $bmp = $ic.ToBitmap()
        $ic.Dispose()
        return $bmp
    } catch {}
    try {
        $ic = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)
        $bmp = $ic.ToBitmap()
        $ic.Dispose()
        return $bmp
    } catch {}
    return $null
}

# ===== HELPER: Save proper multi-bpp / PNG-compressed ICO =====
function Save-IconFile {
    param($Bitmap, $Path)
    try {
        $fs = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Create)
        $w = [System.IO.BinaryWriter]::new($fs)
        $w.Write([byte[]](0,0,1,0,1,0))
        $dim = if ($Bitmap.Width -ge 256 -or $Bitmap.Height -ge 256) { 0 } else { [byte]$Bitmap.Width }
        $w.Write([byte]$dim)
        $w.Write([byte]$dim)
        $w.Write([byte[]](0,0,1,0,32,0))
        $ms = [System.IO.MemoryStream]::new()
        $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bytes = $ms.ToArray()
        $ms.Close()
        $w.Write([int]$bytes.Length)
        $w.Write([int]22)
        $w.Write($bytes)
        $w.Close()
        return $true
    } catch { return $false }
}

# ===== HELPER: Recolour bitmap with shading preservation =====
function Recolour-Bitmap {
    param($Bitmap, $NewColor, $Mode = 0)
    for ($y=0; $y -lt $Bitmap.Height; $y++) {
        for ($x=0; $x -lt $Bitmap.Width; $x++) {
            $px = $Bitmap.GetPixel($x,$y)
            if ($px.A -gt 15) {
                if ($Mode -eq 0) {
                    # Preserve luminance & shading
                    $lum = ($px.R * 0.299 + $px.G * 0.587 + $px.B * 0.114) / 255.0
                    $r = [Math]::Min(255, [int]($NewColor.R * $lum * 1.25))
                    $g = [Math]::Min(255, [int]($NewColor.G * $lum * 1.25))
                    $b = [Math]::Min(255, [int]($NewColor.B * $lum * 1.25))
                    $Bitmap.SetPixel($x,$y, [System.Drawing.Color]::FromArgb($px.A, $r, $g, $b))
                } else {
                    # Flat tint
                    $Bitmap.SetPixel($x,$y, [System.Drawing.Color]::FromArgb($px.A, $NewColor.R, $NewColor.G, $NewColor.B))
                }
            }
        }
    }
}

# ===== HELPER: Get collision-safe output path =====
function Get-SafePath {
    param($Path, $Mode)
    if (-not (Test-Path -LiteralPath $Path)) { return $Path }
    if ($Mode -eq 2) { return $null } # skip existing
    if ($Mode -eq 0) { return $Path } # overwrite
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    $ext = [System.IO.Path]::GetExtension($Path)
    $n = 1
    do { $Path = Join-Path $dir "$base`_$n$ext"; $n++ } while (Test-Path -LiteralPath $Path)
    return $Path
}

# ===== HELPER: Process single ICO file =====
function Process-OneIcon {
    param($Src, $OutFolder, $Color, $Mode, $TintStyle = 0)
    try {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Src)
        $ext = [System.IO.Path]::GetExtension($Src)
        $suffix = if ($Mode -eq 1 -and (Test-Path (Join-Path $OutFolder (Split-Path $Src -Leaf)))) { "_coloured" } else { "" }
        $dst = Join-Path $OutFolder "$baseName$suffix$ext"
        $dst = Get-SafePath $dst $Mode
        if (-not $dst) { return "Skipped (already exists)" }
        if ($Mode -eq 0 -and (Test-Path -LiteralPath $dst)) { Remove-Item -LiteralPath $dst -Force }

        $bmp = Load-AnyIcoAsBitmap $Src
        if (-not $bmp) { return "FAIL: Could not decode icon file" }
        Recolour-Bitmap $bmp $Color $TintStyle
        $ok = Save-IconFile $bmp $dst
        $bmp.Dispose()
        if ($ok) { return "OK -> $(Split-Path $dst -Leaf)" }
        return "FAIL: Could not save icon"
    } catch { return "ERROR: $($_.Exception.Message)" }
}

# ===== HELPER: Process single LNK shortcut =====
function Process-OneShortcut {
    param($Src, $OutFolder, $Color, $Mode, $TintStyle = 0)
    try {
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($Src)
        $tgt = $lnk.TargetPath
        $iconSpec = $lnk.IconLocation
        $lnkArgs = $lnk.Arguments
        $wd = $lnk.WorkingDirectory

        $iconPath = $tgt; $iconIdx = 0
        if ($iconSpec -and $iconSpec -ne "") {
            $parts = $iconSpec -split ','
            $iconPath = $parts[0].Trim('"')
            if ($parts.Count -gt 1) { [int]::TryParse($parts[1].Trim(), [ref]$iconIdx) | Out-Null }
        }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Src)
        $newIco = Join-Path $OutFolder "$baseName`_coloured.ico"
        $newLnk = Join-Path $OutFolder "$baseName.lnk"

        $newIco = Get-SafePath $newIco $Mode
        $newLnk = Get-SafePath $newLnk $Mode
        if (-not $newIco -or -not $newLnk) { return "Skipped (already exists)" }
        if ($Mode -eq 0) {
            if (Test-Path -LiteralPath $newIco) { Remove-Item -LiteralPath $newIco -Force }
            if (Test-Path -LiteralPath $newLnk) { Remove-Item -LiteralPath $newLnk -Force }
        }

        $bmp = $null
        if ($iconPath -and (Test-Path -LiteralPath $iconPath)) {
            if ([System.IO.Path]::GetExtension($iconPath) -ieq ".ico") {
                $ico = $null
                try {
                    $ico = [System.Drawing.Icon]::new($iconPath, 256, 256)
                    $bmp = $ico.ToBitmap()
                } catch { $bmp = $null }
                finally { if ($ico) { $ico.Dispose() } }
            } else {
                $bmp = [DgIconExtractor]::Get($iconPath, $iconIdx)
            }
        }
        if (-not $bmp -and $tgt -and (Test-Path -LiteralPath $tgt)) {
            $bmp = [DgIconExtractor]::Get($tgt, 0)
        }
        if (-not $bmp) { return "SKIP: icon unreadable from target" }

        Recolour-Bitmap $bmp $Color $TintStyle
        $ok = Save-IconFile $bmp $newIco
        $bmp.Dispose()
        if (-not $ok) { return "FAIL: save icon" }

        # Update shortcut with new recolored icon
        $newShortcut = $sh.CreateShortcut($newLnk)
        $newShortcut.TargetPath = $tgt
        $newShortcut.Arguments = $lnkArgs
        $newShortcut.WorkingDirectory = $wd
        $newShortcut.IconLocation = "`"$newIco`",0"
        $newShortcut.Save()

        return "OK -> $(Split-Path $newLnk -Leaf)"
    } catch { return "ERROR: $($_.Exception.Message)" }
}

# ===== HELPER: Create Desktop Shortcut =====
function New-DgDesktopShortcut {
    param([string]$Name)
    try {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        $scriptDir = Split-Path -Parent $scriptPath
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$Name.lnk"
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($lnkPath)
        $lnk.TargetPath = (Get-Command powershell.exe).Source
        $lnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File `"$scriptPath`""
        $lnk.WorkingDirectory = $scriptDir
        $icon = Join-Path $scriptDir "DG-Visual-Toolkit.ico"
        if (Test-Path -LiteralPath $icon) { $lnk.IconLocation = "`"$icon`",0" }
        $lnk.Description = $Name
        $lnk.Save()
        [System.Windows.Forms.MessageBox]::Show("Desktop shortcut created:`n$lnkPath", "DG Visual Toolkit", "OK", "Information")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not create shortcut:`n$($_.Exception.Message)", "DG Visual Toolkit", "OK", "Error")
    }
}

# ===== MODERN DARK UI SETUP =====
$C_BG     = [System.Drawing.Color]::FromArgb(15, 23, 32)
$C_PANEL  = [System.Drawing.Color]::FromArgb(22, 34, 48)
$C_BORDER = [System.Drawing.Color]::FromArgb(38, 58, 80)
$C_TEXT   = [System.Drawing.Color]::FromArgb(245, 245, 245)
$C_MUTED  = [System.Drawing.Color]::FromArgb(148, 163, 184)
$C_ACCENT = [System.Drawing.Color]::FromArgb(0, 210, 255)
$C_GREEN  = [System.Drawing.Color]::FromArgb(0, 184, 148)

$form = [System.Windows.Forms.Form]::new()
$form.Text = "DG Icon & Shortcut Changer v3.0"
$form.Size = [System.Drawing.Size]::new(720, 680)
$form.MinimumSize = [System.Drawing.Size]::new(680, 620)
$form.StartPosition = "CenterScreen"
$form.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$form.BackColor = $C_BG
$form.ForeColor = $C_TEXT

# Window Icon
$appIco = Join-Path (Split-Path -Parent $PSCommandPath) "DG-Visual-Toolkit.ico"
if (Test-Path $appIco) { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($appIco) }

# Header Banner
$panHeader = [System.Windows.Forms.Panel]@{Location=[System.Drawing.Point]::new(0,0);Size=[System.Drawing.Size]::new(720,55);BackColor=[System.Drawing.Color]::FromArgb(18,28,38);Dock="Top"}
$form.Controls.Add($panHeader)

$lblTitle = [System.Windows.Forms.Label]@{Text="DG ICON & SHORTCUT CHANGER";Location=[System.Drawing.Point]::new(20,10);AutoSize=$true;Font=[System.Drawing.Font]::new("Segoe UI",12,[System.Drawing.FontStyle]::Bold);ForeColor=$C_ACCENT}
$panHeader.Controls.Add($lblTitle)
$lblSub = [System.Windows.Forms.Label]@{Text="Recolor individual .ico files or entire folders, and update .lnk shortcut icons";Location=[System.Drawing.Point]::new(20,32);AutoSize=$true;Font=[System.Drawing.Font]::new("Segoe UI",8);ForeColor=$C_MUTED}
$panHeader.Controls.Add($lblSub)

$y = 65

# --- Input Section ---
$lblIn = [System.Windows.Forms.Label]@{Text="Input: Select Individual File (.ico / .lnk) OR Folder:";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(450,20);Font=[System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold);ForeColor=$C_TEXT}
$form.Controls.Add($lblIn)
$y += 24

$txtInput = [System.Windows.Forms.TextBox]@{Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(460,25);BackColor=$C_PANEL;ForeColor=$C_TEXT;BorderStyle="FixedSingle";AllowDrop=$true}
if ($InputPath) { $txtInput.Text = $InputPath }
$form.Controls.Add($txtInput)

# Drag and drop support
$txtInput.Add_DragEnter({
    if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = [System.Windows.Forms.DragDropEffects]::Copy }
})
$txtInput.Add_DragDrop({
    $dropped = $_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($dropped -and $dropped.Length -gt 0) {
        $txtInput.Text = $dropped[0]
        Update-Preview
    }
})

$btnFileBrowse = [System.Windows.Forms.Button]@{Text="[File] Select File";Location=[System.Drawing.Point]::new(490,$y-1);Size=[System.Drawing.Size]::new(100,27);BackColor=$C_PANEL;ForeColor=$C_ACCENT;FlatStyle="Flat"}
$btnFileBrowse.FlatAppearance.BorderColor = $C_BORDER
$btnFileBrowse.Add_Click({
    $dlg = [System.Windows.Forms.OpenFileDialog]::new()
    $dlg.Title = "Select Individual Icon or Shortcut File"
    $dlg.Filter = "Icons and Shortcuts (*.ico;*.lnk)|*.ico;*.lnk|ICO Icon Files (*.ico)|*.ico|LNK Shortcuts (*.lnk)|*.lnk|All Files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInput.Text = $dlg.FileName
        Update-Preview
    }
})
$form.Controls.Add($btnFileBrowse)

$btnFolderBrowse = [System.Windows.Forms.Button]@{Text="[Folder] Folder";Location=[System.Drawing.Point]::new(596,$y-1);Size=[System.Drawing.Size]::new(90,27);BackColor=$C_PANEL;ForeColor=$C_TEXT;FlatStyle="Flat"}
$btnFolderBrowse.FlatAppearance.BorderColor = $C_BORDER
$btnFolderBrowse.Add_Click({
    $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dlg.Description = "Select folder containing icons or shortcuts to batch process"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInput.Text = $dlg.SelectedPath
        Update-Preview
    }
})
$form.Controls.Add($btnFolderBrowse)
$y += 36

# --- Output Section ---
$lblOut = [System.Windows.Forms.Label]@{Text="Output Folder (Leave blank to save alongside input):";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(450,20);Font=[System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold);ForeColor=$C_TEXT}
$form.Controls.Add($lblOut)
$y += 24

$txtOutput = [System.Windows.Forms.TextBox]@{Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(566,25);BackColor=$C_PANEL;ForeColor=$C_TEXT;BorderStyle="FixedSingle"}
if ($OutputPath) { $txtOutput.Text = $OutputPath }
$form.Controls.Add($txtOutput)

$btnOutBrowse = [System.Windows.Forms.Button]@{Text="Browse";Location=[System.Drawing.Point]::new(596,$y-1);Size=[System.Drawing.Size]::new(90,27);BackColor=$C_PANEL;ForeColor=$C_TEXT;FlatStyle="Flat"}
$btnOutBrowse.FlatAppearance.BorderColor = $C_BORDER
$btnOutBrowse.Add_Click({
    $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dlg.Description = "Where to save recolored files"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtOutput.Text = $dlg.SelectedPath }
})
$form.Controls.Add($btnOutBrowse)
$y += 38

# --- Recolor & Mode Section ---
$lblColor = [System.Windows.Forms.Label]@{Text="Recolor Tint:";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(120,20);Font=[System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold);ForeColor=$C_TEXT}
$form.Controls.Add($lblColor)

$lblTintStyle = [System.Windows.Forms.Label]@{Text="Shading Mode:";Location=[System.Drawing.Point]::new(230,$y);Size=[System.Drawing.Size]::new(120,20);Font=[System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold);ForeColor=$C_TEXT}
$form.Controls.Add($lblTintStyle)

$lblCollision = [System.Windows.Forms.Label]@{Text="If file exists:";Location=[System.Drawing.Point]::new(460,$y);Size=[System.Drawing.Size]::new(120,20);Font=[System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold);ForeColor=$C_TEXT}
$form.Controls.Add($lblCollision)
$y += 22

$script:selectedColour = [System.Drawing.Color]::FromArgb(0, 184, 148) # Default Mint Emerald

$btnColor = [System.Windows.Forms.Button]@{Text="[Color] Pick Color";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(130,28);BackColor=$script:selectedColour;ForeColor=[System.Drawing.Color]::White;FlatStyle="Flat"}
$form.Controls.Add($btnColor)

$lblHex = [System.Windows.Forms.Label]@{Text="#00B894";Location=[System.Drawing.Point]::new(155,$y+5);Size=[System.Drawing.Size]::new(65,20);Font=[System.Drawing.Font]::new("Consolas",9);ForeColor=$C_MUTED}
$form.Controls.Add($lblHex)

$btnColor.Add_Click({
    $cd = [System.Windows.Forms.ColorDialog]::new()
    $cd.Color = $script:selectedColour
    if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:selectedColour = $cd.Color
        $btnColor.BackColor = $script:selectedColour
        $btnColor.ForeColor = if ($script:selectedColour.GetBrightness() -lt 0.5) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black }
        $lblHex.Text = ("#{0:X2}{1:X2}{2:X2}" -f $script:selectedColour.R, $script:selectedColour.G, $script:selectedColour.B)
        Update-Preview
    }
})

$cmbTintStyle = [System.Windows.Forms.ComboBox]@{DropDownStyle="DropDownList";Location=[System.Drawing.Point]::new(230,$y+2);Size=[System.Drawing.Size]::new(210,25);BackColor=$C_PANEL;ForeColor=$C_TEXT}
[void]$cmbTintStyle.Items.AddRange(@("Colorize (Preserve Shading)", "Flat Tint (Solid Color)"))
$cmbTintStyle.SelectedIndex = 0
$cmbTintStyle.Add_SelectedIndexChanged({ Update-Preview })
$form.Controls.Add($cmbTintStyle)

$cmbCollision = [System.Windows.Forms.ComboBox]@{DropDownStyle="DropDownList";Location=[System.Drawing.Point]::new(460,$y+2);Size=[System.Drawing.Size]::new(226,25);BackColor=$C_PANEL;ForeColor=$C_TEXT}
[void]$cmbCollision.Items.AddRange(@("Overwrite existing files", "Add _coloured / _2 suffix", "Skip existing files"))
$cmbCollision.SelectedIndex = 1
$form.Controls.Add($cmbCollision)
$y += 36

# Preset Swatches
$lblPresets = [System.Windows.Forms.Label]@{Text="Quick Swatches:";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(100,20);ForeColor=$C_MUTED}
$form.Controls.Add($lblPresets)
$presets = @(
    @{ Name="Cyan"; Col=[System.Drawing.Color]::FromArgb(0, 210, 255) },
    @{ Name="Emerald"; Col=[System.Drawing.Color]::FromArgb(0, 184, 148) },
    @{ Name="Royal Blue"; Col=[System.Drawing.Color]::RoyalBlue },
    @{ Name="Amber Gold"; Col=[System.Drawing.Color]::FromArgb(245, 158, 11) },
    @{ Name="Crimson"; Col=[System.Drawing.Color]::FromArgb(239, 68, 68) },
    @{ Name="Purple"; Col=[System.Drawing.Color]::FromArgb(168, 85, 247) }
)
$px = 120
foreach ($p in $presets) {
    $sw = [System.Windows.Forms.Button]@{Text="";Location=[System.Drawing.Point]::new($px,$y-2);Size=[System.Drawing.Size]::new(22,22);BackColor=$p.Col;FlatStyle="Flat"}
    $sw.FlatAppearance.BorderColor = $C_BORDER
    $sw.Add_Click({
        param($sender)
        $script:selectedColour = $sender.BackColor
        $btnColor.BackColor = $script:selectedColour
        $btnColor.ForeColor = if ($script:selectedColour.GetBrightness() -lt 0.5) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black }
        $lblHex.Text = ("#{0:X2}{1:X2}{2:X2}" -f $script:selectedColour.R, $script:selectedColour.G, $script:selectedColour.B)
        Update-Preview
    })
    $form.Controls.Add($sw)
    $px += 28
}
$y += 28

# Filter checkboxes (when folders are processed)
$chkICO = [System.Windows.Forms.CheckBox]@{Text="Recolor .ICO icon files";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(190,24);Checked=$true;ForeColor=$C_TEXT}
$chkLNK = [System.Windows.Forms.CheckBox]@{Text="Recolor .LNK shortcut icons";Location=[System.Drawing.Point]::new(220,$y);Size=[System.Drawing.Size]::new(220,24);Checked=$true;ForeColor=$C_TEXT}
$form.Controls.Add($chkICO)
$form.Controls.Add($chkLNK)
$y += 30

# --- Live Icon Preview Frame ---
$panPreview = [System.Windows.Forms.Panel]@{Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(666,60);BackColor=$C_PANEL;BorderStyle="FixedSingle"}
$form.Controls.Add($panPreview)

$lblPrevTitle = [System.Windows.Forms.Label]@{Text="LIVE PREVIEW:";Location=[System.Drawing.Point]::new(10,20);AutoSize=$true;Font=[System.Drawing.Font]::new("Segoe UI",8,[System.Drawing.FontStyle]::Bold);ForeColor=$C_MUTED}
$panPreview.Controls.Add($lblPrevTitle)

$picOrig = [System.Windows.Forms.PictureBox]@{Location=[System.Drawing.Point]::new(110,6);Size=[System.Drawing.Size]::new(48,48);SizeMode="Zoom"}
$panPreview.Controls.Add($picOrig)

$lblArrow = [System.Windows.Forms.Label]@{Text="->";Location=[System.Drawing.Point]::new(170,20);AutoSize=$true;Font=[System.Drawing.Font]::new("Segoe UI",11,[System.Drawing.FontStyle]::Bold);ForeColor=$C_ACCENT}
$panPreview.Controls.Add($lblArrow)

$picRecolor = [System.Windows.Forms.PictureBox]@{Location=[System.Drawing.Point]::new(205,6);Size=[System.Drawing.Size]::new(48,48);SizeMode="Zoom"}
$panPreview.Controls.Add($picRecolor)

$lblPrevDesc = [System.Windows.Forms.Label]@{Text="Select an individual .ico file to preview recolor";Location=[System.Drawing.Point]::new(270,20);AutoSize=$true;Font=[System.Drawing.Font]::new("Segoe UI",8);ForeColor=$C_MUTED}
$panPreview.Controls.Add($lblPrevDesc)
$y += 68

# --- Log Window ---
$txtLog = [System.Windows.Forms.TextBox]@{Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(666,130);Multiline=$true;ScrollBars="Vertical";ReadOnly=$true;BackColor=[System.Drawing.Color]::FromArgb(10,16,22);ForeColor=[System.Drawing.Color]::FromArgb(167,243,208);Font=[System.Drawing.Font]::new("Consolas",8.5);BorderStyle="FixedSingle"}
$form.Controls.Add($txtLog)
$y += 138

# --- Process Action Button ---
$btnProcess = [System.Windows.Forms.Button]@{Text="[*]  RECOLOR & PROCESS";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(666,42);BackColor=$C_GREEN;ForeColor=[System.Drawing.Color]::White;Font=[System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold);FlatStyle="Flat";Cursor="Hand"}
$btnProcess.FlatAppearance.BorderColor = $C_GREEN
$form.Controls.Add($btnProcess)
$y += 48

# Bottom utilities
$btnShortcut = [System.Windows.Forms.Button]@{Text="CREATE DESKTOP SHORTCUT";Location=[System.Drawing.Point]::new(20,$y);Size=[System.Drawing.Size]::new(325,28);BackColor=$C_PANEL;ForeColor=$C_MUTED;FlatStyle="Flat"}
$btnShortcut.FlatAppearance.BorderColor = $C_BORDER
$btnShortcut.Add_Click({ New-DgDesktopShortcut "DG Icon & Shortcut Changer" })
$form.Controls.Add($btnShortcut)

$btnOpenOut = [System.Windows.Forms.Button]@{Text="OPEN OUTPUT FOLDER";Location=[System.Drawing.Point]::new(360,$y);Size=[System.Drawing.Size]::new(326,28);BackColor=$C_PANEL;ForeColor=$C_ACCENT;FlatStyle="Flat"}
$btnOpenOut.FlatAppearance.BorderColor = $C_BORDER
$btnOpenOut.Add_Click({
    $out = $txtOutput.Text.Trim()
    if (-not $out) {
        $inp = $txtInput.Text.Trim()
        $out = if (Test-Path -LiteralPath $inp -PathType Container) { $inp } else { Split-Path -Parent $inp }
    }
    if (Test-Path -LiteralPath $out) { [System.Diagnostics.Process]::Start("explorer.exe", $out) }
    else { [System.Windows.Forms.MessageBox]::Show("Folder does not exist: $out", "Notice", "OK", "Information") }
})
$form.Controls.Add($btnOpenOut)

function Log {
    param($m)
    $stamp = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$stamp] $m`r`n")
    $txtLog.ScrollToCaret()
}

# Live preview function for single icon
function Update-Preview {
    try {
        $inPath = $txtInput.Text.Trim().Trim('"').Trim("'")
        if ((Test-Path -LiteralPath $inPath -PathType Leaf) -and ([System.IO.Path]::GetExtension($inPath) -ieq ".ico")) {
            $bmpOrig = Load-AnyIcoAsBitmap $inPath
            if (-not $bmpOrig) { return }

            $bmpRecolored = $bmpOrig.Clone()
            Recolour-Bitmap $bmpRecolored $script:selectedColour $cmbTintStyle.SelectedIndex

            $picOrig.Image = $bmpOrig
            $picRecolor.Image = $bmpRecolored
            $lblPrevDesc.Text = "Individual Icon: $(Split-Path $inPath -Leaf)"
            $lblPrevDesc.ForeColor = $C_TEXT
        } else {
            $picOrig.Image = $null
            $picRecolor.Image = $null
            if (Test-Path -LiteralPath $inPath -PathType Container) {
                $lblPrevDesc.Text = "Folder batch mode selected (Preview available on single .ico files)"
            } else {
                $lblPrevDesc.Text = "Select an individual .ico file to preview recolor"
            }
            $lblPrevDesc.ForeColor = $C_MUTED
        }
    } catch {}
}

$txtInput.Add_TextChanged({ Update-Preview })

# ===== EXECUTION ACTION =====
$btnProcess.Add_Click({
    $inPath = $txtInput.Text.Trim().Trim('"').Trim("'")
    if (-not $inPath -or -not (Test-Path -LiteralPath $inPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid input file (.ico/.lnk) or a folder.", "Input Required", "OK", "Warning")
        return
    }

    $outDir = $txtOutput.Text.Trim().Trim('"').Trim("'")
    $isSingleFile = Test-Path -LiteralPath $inPath -PathType Leaf

    if (-not $outDir) {
        $outDir = if ($isSingleFile) { Split-Path -Parent $inPath } else { $inPath }
    }
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $mode = $cmbCollision.SelectedIndex
    $tintStyle = $cmbTintStyle.SelectedIndex
    $color = $script:selectedColour

    $btnProcess.Enabled = $false
    $form.UseWaitCursor = $true
    $txtLog.Clear()

    Log "Starting icon recolor process..."
    Log "Color: #$("{0:X2}{1:X2}{2:X2}" -f $color.R, $color.G, $color.B) | Shading: $(if ($tintStyle -eq 0) { 'Preserve' } else { 'Flat' })"
    Log "Output Destination: $outDir"

    try {
        if ($isSingleFile) {
            # === INDIVIDUAL FILE MODE ===
            $ext = [System.IO.Path]::GetExtension($inPath).ToLower()
            Log "Mode: Single File Processing ($(Split-Path $inPath -Leaf))"

            if ($ext -eq ".ico") {
                $res = Process-OneIcon $inPath $outDir $color $mode $tintStyle
                Log "Result: $res"
            } elseif ($ext -eq ".lnk") {
                $res = Process-OneShortcut $inPath $outDir $color $mode $tintStyle
                Log "Result: $res"
            } else {
                Log "Unsupported file format: $ext. Please select a .ico or .lnk file."
            }
        } else {
            # === FOLDER BATCH MODE ===
            Log "Mode: Folder Batch Processing"
            $icoList = @()
            $lnkList = @()
            if ($chkICO.Checked) { $icoList = @(Get-ChildItem -LiteralPath $inPath -Filter *.ico -File -ErrorAction SilentlyContinue) }
            if ($chkLNK.Checked) { $lnkList = @(Get-ChildItem -LiteralPath $inPath -Filter *.lnk -File -ErrorAction SilentlyContinue) }

            $total = $icoList.Count + $lnkList.Count
            if ($total -eq 0) {
                Log "No .ICO or .LNK files found in: $inPath"
            } else {
                Log "Found $($icoList.Count) ICO file(s) and $($lnkList.Count) LNK shortcut(s)."
                foreach ($f in $icoList) {
                    $res = Process-OneIcon $f.FullName $outDir $color $mode $tintStyle
                    Log "ICO: $res"
                }
                foreach ($f in $lnkList) {
                    $res = Process-OneShortcut $f.FullName $outDir $color $mode $tintStyle
                    Log "LNK: $res"
                }
            }
        }
        Log "`n[OK] COMPLETED! All processed files ready in output folder."
    } catch {
        Log "[ERROR] $($_.Exception.Message)"
    } finally {
        $btnProcess.Enabled = $true
        $form.UseWaitCursor = $false
    }
})

# Trigger initial preview if path provided
if ($InputPath) { Update-Preview }

[void]$form.ShowDialog()
