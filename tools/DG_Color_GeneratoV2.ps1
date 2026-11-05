<#
DG OS Color Variant Generator - SCOPE FIXED
Build 2026.10 - Variable bug resolved
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

$form = New-Object System.Windows.Forms.Form
$form.Text = "DG OS - Color Generator"
$form.Size = New-Object System.Drawing.Size(600,580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0A1620")
$form.ForeColor = [System.Drawing.Color]::White

# Make variables accessible everywhere
$script:sourceFile = $null
$script:outputDir = Join-Path ([Environment]::GetFolderPath("MyPictures")) "DG_ColorVariants"

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "DG // OS - Color Variant Generator"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#66E0FF")
$lblTitle.Location = New-Object System.Drawing.Point(20,15)
$lblTitle.Size = New-Object System.Drawing.Size(540,30)
$form.Controls.Add($lblTitle)

$btnSelect = New-Object System.Windows.Forms.Button
$btnSelect.Text = "Select Base Image"
$btnSelect.Location = New-Object System.Drawing.Point(20,65)
$btnSelect.Size = New-Object System.Drawing.Size(240,35)
$btnSelect.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1A2F3F")
$btnSelect.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($btnSelect)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "No file selected"
$lblPath.Location = New-Object System.Drawing.Point(280,72)
$lblPath.Size = New-Object System.Drawing.Size(300,40)
$lblPath.ForeColor = [System.Drawing.Color]::Yellow
$form.Controls.Add($lblPath)

# 26 colors - exact match to your list
$presetColors = [ordered]@{
    "blue"="#0088FF"
    "brown"="#8B5A2B"
    "coral"="#FF7F50"
    "crimson"="#DC143C"
    "cyan"="#00FFFF"
    "emerald"="#50C878"
    "fuchsia"="#FF00FF"
    "gold"="#FFD700"
    "graphite"="#4B4B4B"
    "green"="#00FF00"
    "indigo"="#4B0082"
    "lime"="#32CD32"
    "magenta"="#FF00CC"
    "orange"="#FF8C00"
    "pink"="#FF69B4"
    "purple"="#9370DB"
    "red"="#FF0000"
    "rose"="#FF4080"
    "salmon"="#FA8072"
    "silver"="#C0C0C0"
    "sky"="#87CEEB"
    "slate"="#708090"
    "teal"="#008080"
    "violet"="#EE82EE"
    "white"="#FFFFFF"
    "yellow"="#FFFF00"
}

$lblColors = New-Object System.Windows.Forms.Label
$lblColors.Text = "OK - 26 Preset Colors Loaded"
$lblColors.Location = New-Object System.Drawing.Point(20,130)
$lblColors.Size = New-Object System.Drawing.Size(540,20)
$lblColors.ForeColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($lblColors)

$lblFormat = New-Object System.Windows.Forms.Label
$lblFormat.Text = "Output Format:"
$lblFormat.Location = New-Object System.Drawing.Point(20,170)
$lblFormat.Size = New-Object System.Drawing.Size(120,25)
$form.Controls.Add($lblFormat)

$cmbFormat = New-Object System.Windows.Forms.ComboBox
$cmbFormat.DropDownStyle = "DropDownList"
$cmbFormat.Items.AddRange(@("JPG","PNG","ICO"))
$cmbFormat.SelectedIndex = 0
$cmbFormat.Location = New-Object System.Drawing.Point(140,168)
$cmbFormat.Size = New-Object System.Drawing.Size(120,25)
$form.Controls.Add($cmbFormat)

$btnOutFolder = New-Object System.Windows.Forms.Button
$btnOutFolder.Text = "Output Folder"
$btnOutFolder.Location = New-Object System.Drawing.Point(20,210)
$btnOutFolder.Size = New-Object System.Drawing.Size(240,35)
$btnOutFolder.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1A2F3F")
$btnOutFolder.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($btnOutFolder)

$lblOutFolder = New-Object System.Windows.Forms.Label
$lblOutFolder.Text = "$script:outputDir"
$lblOutFolder.Location = New-Object System.Drawing.Point(280,217)
$lblOutFolder.Size = New-Object System.Drawing.Size(300,20)
$lblOutFolder.ForeColor = [System.Drawing.Color]::LightGray
$form.Controls.Add($lblOutFolder)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready - select your base image"
$lblStatus.Location = New-Object System.Drawing.Point(20,280)
$lblStatus.Size = New-Object System.Drawing.Size(540,25)
$lblStatus.ForeColor = [System.Drawing.Color]::LightBlue
$form.Controls.Add($lblStatus)

$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = "Generate All Variants"
$btnGenerate.Location = New-Object System.Drawing.Point(170,330)
$btnGenerate.Size = New-Object System.Drawing.Size(260,50)
$btnGenerate.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$btnGenerate.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#00AA88")
$btnGenerate.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($btnGenerate)

$btnShortcut = New-Object System.Windows.Forms.Button
$btnShortcut.Text = "Create Desktop Shortcut"
$btnShortcut.Location = New-Object System.Drawing.Point(20,405)
$btnShortcut.Size = New-Object System.Drawing.Size(560,32)
$btnShortcut.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1A2F3F")
$btnShortcut.ForeColor = [System.Drawing.Color]::White
$btnShortcut.Add_Click({ New-DgDesktopShortcut "DG Color Variant Generator" })
$form.Controls.Add($btnShortcut)

# --- SELECT IMAGE - NOW SETS VARIABLE CORRECTLY ---
$btnSelect.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "All Files (*.*)|*.*"
    $dlg.Title = "Select your base image"
    if ($dlg.ShowDialog() -eq "OK") {
        $script:sourceFile = $dlg.FileName
        if (Test-Path $script:sourceFile) {
            $lblPath.Text = "SELECTED: $(Split-Path $script:sourceFile -Leaf)"
            $lblPath.ForeColor = [System.Drawing.Color]::LightGreen
            $lblStatus.Text = "LOADED - ready to generate"
            $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
        } else {
            $lblPath.Text = "ERROR: File not found!"
            $lblPath.ForeColor = [System.Drawing.Color]::Red
            $script:sourceFile = $null
        }
    }
})

$btnOutFolder.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") {
        $script:outputDir = $dlg.SelectedPath
        $lblOutFolder.Text = $script:outputDir
    }
})

function Convert-HexToColor {
    param([string]$hex)
    try {
        $hex = $hex.TrimStart('#')
        $r = [Convert]::ToInt32($hex.Substring(0,2),16)
        $g = [Convert]::ToInt32($hex.Substring(2,2),16)
        $b = [Convert]::ToInt32($hex.Substring(4,2),16)
        return [System.Drawing.Color]::FromArgb(255,$r,$g,$b)
    }
    catch { return $null }
}

function Save-IconFile {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    try {
        $ms = New-Object System.IO.MemoryStream
        $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $png = $ms.ToArray()
        $ms.Dispose()

        $fs = [System.IO.File]::Create($Path)
        $bw = New-Object System.IO.BinaryWriter($fs)
        $bw.Write([uint16]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]1)
        $dim = if ($Bitmap.Width -ge 256 -or $Bitmap.Height -ge 256) { 0 } else { [byte]$Bitmap.Width }
        $bw.Write([byte]$dim)
        $bw.Write([byte]$dim)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$png.Length)
        $bw.Write([uint32]22)
        $bw.Write($png)
        $bw.Dispose()
        $fs.Dispose()
        return $true
    }
    catch { return $false }
}

# --- GENERATE - CHECKS THE CORRECT VARIABLE ---
$btnGenerate.Add_Click({
    if (-not $script:sourceFile -or -not (Test-Path $script:sourceFile)) {
        [System.Windows.Forms.MessageBox]::Show(
            "No image selected! Click 'Select Base Image' first.",
            "Error", "OK", "Error"
        )
        return
    }

    if (-not (Test-Path $script:outputDir)) {
        New-Item -ItemType Directory -Path $script:outputDir -Force | Out-Null
    }

    $ext = $cmbFormat.SelectedItem.ToString().ToLower()
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($script:sourceFile)

    try {
        $img = [System.Drawing.Image]::FromFile($script:sourceFile)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Cannot load that file. Select a valid image.", "Error", "OK", "Error")
        return
    }

    $total = $presetColors.Count
    $count = 0

    foreach ($kvp in $presetColors.GetEnumerator()) {
        $count++
        $name = $kvp.Key
        $clr = Convert-HexToColor $kvp.Value

        $lblStatus.Text = "Processing $count/$total - $name..."
        $form.Refresh()

        $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
        $bmp.SetResolution($img.HorizontalResolution, $img.VerticalResolution)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.SmoothingMode = "AntiAlias"

        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        $cm.Matrix00 = $clr.R/255
        $cm.Matrix11 = $clr.G/255
        $cm.Matrix22 = $clr.B/255
        $cm.Matrix33 = 1
        $cm.Matrix44 = 1
        $attr = New-Object System.Drawing.Imaging.ImageAttributes
        $attr.SetColorMatrix($cm)

        $rect = New-Object System.Drawing.Rectangle(0,0,$img.Width,$img.Height)
        $gfx.DrawImage($img, $rect, 0,0,$img.Width,$img.Height, "Pixel", $attr)

        $outPath = Join-Path $script:outputDir "$baseName-$name.$ext"

        if ($ext -eq "jpg") {
            $wb = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
            $wg = [System.Drawing.Graphics]::FromImage($wb)
            $wg.Clear([System.Drawing.Color]::White)
            $wg.DrawImage($bmp,0,0)
            $wb.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $wg.Dispose()
            $wb.Dispose()
        }
        elseif ($ext -eq "ico") {
            $ib = New-Object System.Drawing.Bitmap($bmp,256,256)
            [void](Save-IconFile $ib $outPath)
            $ib.Dispose()
        }
        else {
            $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }

        $gfx.Dispose()
        $bmp.Dispose()
    }

    $img.Dispose()
    $lblStatus.Text = "DONE! $total variants saved"
    $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
    [System.Windows.Forms.MessageBox]::Show(
        "Generated $total variants`nSaved to: $script:outputDir",
        "Complete", "OK", "Info"
    )
})

$form.ShowDialog() | Out-Null