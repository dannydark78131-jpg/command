#Requires -Version 5.1
# Bulk File Renamer - GUI edition v2.1.1
# Strips duplicate suffixes " (1)", " (2)", stacked " (1) (1)", plus find/replace,
# prefix/suffix, case change, trim. Preview-first, never closes after a run.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$script:Results = @()
$script:Folder  = ''

# ---------- helpers ----------
function Select-Folder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the folder containing the files to rename"
    $dlg.ShowNewFolderButton = $false
    $result = if ($form -and -not $form.IsDisposed) { $dlg.ShowDialog($form) } else { $dlg.ShowDialog() }
    if ($result -eq 'OK') {
        $script:Folder = $dlg.SelectedPath
        $txtFolder.Text = $script:Folder
        Set-Status "Folder selected: $script:Folder"
    }
}

function Set-Status($msg) { $lblStatus.Text = $msg }

function Reset-Options {
    $chkRecurse.Checked      = $true
    $chkPreview.Checked      = $true
    $chkStrip.Checked        = $true
    $numMaxDigits.Value      = 3
    $chkAnchor.Checked       = $true
    $chkFindReplace.Checked  = $false
    $txtFind.Text = ''; $txtReplace.Text = ''
    $txtPrefix.Text = ''; $txtSuffix.Text = ''
    $cmbCase.SelectedIndex   = 0
    $chkTrim.Checked         = $false
    $chkLog.Checked          = $true
    $lv.Items.Clear()
    $script:Results = @()
    Set-Status "Options reset"
}

function Get-Options {
    [PSCustomObject]@{
        Recurse     = $chkRecurse.Checked
        Preview     = $chkPreview.Checked
        Strip       = $chkStrip.Checked
        MaxDigits   = [int]$numMaxDigits.Value
        AnchorEnd   = $chkAnchor.Checked
        FindReplace = $chkFindReplace.Checked
        Find        = $txtFind.Text
        Replace     = $txtReplace.Text
        Prefix      = $txtPrefix.Text
        Suffix      = $txtSuffix.Text
        Case        = $cmbCase.SelectedItem.ToString()
        Trim        = $chkTrim.Checked
        Log         = $chkLog.Checked
    }
}

function Build-NewName($file, $o) {
    $base = $file.BaseName
    $ext  = $file.Extension

    if ($o.Strip) {
        $n = [Math]::Max(1, $o.MaxDigits)
        $pattern = "(\s*\(\d{1,$n}\))+"
        if ($o.AnchorEnd) { $pattern = $pattern + '$' }
        $base = $base -replace $pattern, ''
    }
    if ($o.FindReplace -and -not [string]::IsNullOrEmpty($o.Find)) {
        $base = $base -replace [regex]::Escape($o.Find), ($o.Replace -replace '\$','$$$$')
    }
    if (-not [string]::IsNullOrEmpty($o.Prefix)) { $base = $o.Prefix + $base }
    if (-not [string]::IsNullOrEmpty($o.Suffix)) { $base = $base + $o.Suffix }
    switch ($o.Case) {
        'lowercase'  { $base = $base.ToLower() }
        'UPPERCASE'  { $base = $base.ToUpper() }
        'Title Case' { $base = (Get-Culture).TextInfo.ToTitleCase($base.ToLower()) }
    }
    if ($o.Trim) { $base = ($base.Trim() -replace '\s+', ' ') }

    if ([string]::IsNullOrWhiteSpace($base)) { return $null }
    return ($base + $ext)
}

function Gather-Results($o) {
    $script:Results = @()
    if ([string]::IsNullOrWhiteSpace($script:Folder) -or -not (Test-Path -LiteralPath $script:Folder)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a folder first.", "No folder", "OK", "Warning")
        return $false
    }
    $files = Get-ChildItem -LiteralPath $script:Folder -File -Recurse:($o.Recurse) -ErrorAction SilentlyContinue
    $seen = @{}
    foreach ($f in $files) {
        $new = Build-NewName $f $o
        if (-not $new) {
            $script:Results += [PSCustomObject]@{ Old=$f.Name; New='(empty name)'; Status='Skipped'; FullPath=$f.FullName; DestPath='' }
            continue
        }
        $dest = Join-Path $f.DirectoryName $new
        $status = 'OK'
        $samePath = [string]::Equals($f.FullName, $dest, [System.StringComparison]::OrdinalIgnoreCase)
        if ($f.Name -ceq $new) { $status = 'No change' }
        elseif ($samePath) { $status = 'OK' }
        elseif (Test-Path -LiteralPath $dest) { $status = 'Skipped (exists)' }
        elseif ($seen.ContainsKey($dest.ToLower())) { $status = 'Skipped (collision)' }
        else { $seen[$dest.ToLower()] = $true }
        $script:Results += [PSCustomObject]@{ Old=$f.Name; New=$new; Status=$status; FullPath=$f.FullName; DestPath=$dest }
    }
    return $true
}

function Show-Results {
    $lv.Items.Clear()
    $i = 1
    foreach ($r in $script:Results) {
        $item = New-Object System.Windows.Forms.ListViewItem([string]$i)
        [void]$item.SubItems.Add($r.Old)
        [void]$item.SubItems.Add($r.New)
        [void]$item.SubItems.Add($r.Status)
        switch -Wildcard ($r.Status) {
            'Skipped*' { $item.ForeColor = [System.Drawing.Color]::OrangeRed }
            'OK'       { $item.ForeColor = [System.Drawing.Color]::ForestGreen }
            'Renamed'  { $item.ForeColor = [System.Drawing.Color]::ForestGreen }
            'Error*'   { $item.ForeColor = [System.Drawing.Color]::Red }
            default    { $item.ForeColor = [System.Drawing.Color]::Gray }
        }
        [void]$lv.Items.Add($item)
        $i++
    }
}

function Write-Log($o) {
    if (-not $o.Log) { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logPath = Join-Path $script:Folder ("rename_log_$stamp.csv")
    try {
        $script:Results | Select-Object Old, New, Status, FullPath, DestPath | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Set-Status "Log written: $logPath"
    } catch {
        Set-Status "Could not write log (folder may be read-only): $($_.Exception.Message)"
    }
}

function Get-Breakdown {
    $total    = $script:Results.Count
    $change   = @($script:Results | Where-Object { $_.Status -eq 'OK' -or $_.Status -eq 'Renamed' }).Count
    $nochange = @($script:Results | Where-Object { $_.Status -eq 'No change' }).Count
    $skip     = @($script:Results | Where-Object { $_.Status -like 'Skipped*' }).Count
    $err      = @($script:Results | Where-Object { $_.Status -like 'Error*' }).Count
    return [PSCustomObject]@{ Total=$total; Change=$change; NoChange=$nochange; Skipped=$skip; Errors=$err }
}

function Invoke-Preview {
    $o = Get-Options
    if (-not (Gather-Results $o)) { return }
    Show-Results
    $b = Get-Breakdown
    $hint = ''
    if ($b.Change -eq 0 -and $b.Total -gt 0) {
        $hint = "`n`nNothing matched. If your files have ' (1)' suffixes, try unticking 'Only strip suffixes at end of name' or raise Max digits."
    }
    Set-Status "Preview: $($b.Total) files | $($b.Change) would rename | $($b.NoChange) no change | $($b.Skipped) skipped"
    if ($b.Change -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(("No files match the selected options.`nTotal: {0}`nNo change: {1}`nSkipped: {2}{3}" -f $b.Total, $b.NoChange, $b.Skipped, $hint), "Nothing to rename", "OK", "Information")
    }
}

function Invoke-Apply {
    $o = Get-Options
    if ($o.Preview) {
        $r = [System.Windows.Forms.MessageBox]::Show("Preview mode is still ON — no files will be changed.`nTurn it off (left panel) and click Apply again to actually rename.`n`nRun preview anyway?", "Preview mode on", "YesNo", "Question")
        if ($r -eq 'No') { return }
        Invoke-Preview
        return
    }
    if (-not (Gather-Results $o)) { return }
    $renamed = 0; $skipped = 0; $nochange = 0; $errors = 0
    $firstError = ''
    foreach ($r in $script:Results) {
        if ($r.Status -eq 'No change') { $nochange++; continue }
        if ($r.Status -ne 'OK') { $skipped++; continue }
        try {
            Rename-Item -LiteralPath $r.FullPath -NewName $r.New -ErrorAction Stop
            $r.Status = 'Renamed'
            $renamed++
        } catch {
            $r.Status = "Error: $($_.Exception.Message)"
            if (-not $firstError) { $firstError = $_.Exception.Message }
            $errors++
        }
    }
    Show-Results
    Write-Log $o
    $msg = "Renamed: $renamed`nNo change: $nochange`nSkipped: $skipped`nErrors: $errors"
    if ($firstError) { $msg += "`n`nFirst error: $firstError" }
    if ($renamed -eq 0 -and $errors -eq 0) {
        $msg += "`n`nNothing matched — try unticking 'Only strip suffixes at end of name' or pick a folder with ' (1)' files."
    }
    Set-Status "Done: renamed=$renamed nochange=$nochange skipped=$skipped errors=$errors — window stays open"
    [System.Windows.Forms.MessageBox]::Show($msg, "Operation complete", "OK", $(if ($errors -gt 0) { 'Warning' } else { 'Information' }))
}

# ---------- form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Bulk File Renamer v2.1.1"
$form.Size = New-Object System.Drawing.Size(960, 700)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(960, 560)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

# menu
$menu = New-Object System.Windows.Forms.MenuStrip
$mFile = $menu.Items.Add('&File')
$miOpen = $mFile.DropDownItems.Add('&Select Folder...')
$miOpen.Add_Click({ Select-Folder })
[void]$mFile.DropDownItems.Add('-')
$miExit = $mFile.DropDownItems.Add('E&xit')
$miExit.Add_Click({ $form.Close() })
$mTools = $menu.Items.Add('&Tools')
$miReset = $mTools.DropDownItems.Add('&Reset all options')
$miReset.Add_Click({ Reset-Options })
$miOpenFolder = $mTools.DropDownItems.Add('&Open folder in Explorer')
$miOpenFolder.Add_Click({ if ($script:Folder) { Start-Process $script:Folder } })
$mHelp = $menu.Items.Add('&Help')
$miAbout = $mHelp.DropDownItems.Add('&About')
$miAbout.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Bulk File Renamer v2.1.1`nPreview-first bulk rename tool.", "About", "OK", "Information") })
$form.MainMenuStrip = $menu

# folder panel (top)
$pnlFolder = New-Object System.Windows.Forms.Panel
$pnlFolder.Dock = 'Top'
$pnlFolder.Height = 48
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = 'Folder:'
$lblFolder.AutoSize = $true
$lblFolder.Location = '12, 16'
$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = '64, 13'
$txtFolder.Width = 760
$txtFolder.ReadOnly = $true
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = 'Browse...'
$btnBrowse.Location = '832, 11'
$btnBrowse.Width = 100
$btnBrowse.Add_Click({ Select-Folder })
$pnlFolder.Controls.AddRange(@($lblFolder, $txtFolder, $btnBrowse))

# options panel (left) — widened and width-capped to prevent horizontal scroll cutoff
$pnlOpts = New-Object System.Windows.Forms.Panel
$pnlOpts.Dock = 'Left'
$pnlOpts.Width = 340
$pnlOpts.AutoScroll = $true
$pnlOpts.Padding = New-Object System.Windows.Forms.Padding(10)

$y = 8
function Add-Check($parent, [ref]$yref, $text, $default = $false) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text
    $c.AutoSize = $true
    $c.MaximumSize = New-Object System.Drawing.Size(310, 0)
    $c.Location = "12, $($yref.Value)"
    $c.Checked = $default
    $parent.Controls.Add($c)
    $yref.Value += 26
    return $c
}

$chkRecurse = Add-Check $pnlOpts ([ref]$y) 'Include subfolders (recursive)' $true
$chkPreview = Add-Check $pnlOpts ([ref]$y) 'Preview mode (dry run, no changes)' $true
$chkStrip   = Add-Check $pnlOpts ([ref]$y) 'Strip duplicate suffixes "(1)", "(2)"' $true

$lblDigits = New-Object System.Windows.Forms.Label
$lblDigits.Text = '  Max digits in suffix (3 avoids years):'
$lblDigits.AutoSize = $true; $lblDigits.MaximumSize = New-Object System.Drawing.Size(300, 0)
$lblDigits.Location = "28, $y"; $pnlOpts.Controls.Add($lblDigits); $y += 22
$numMaxDigits = New-Object System.Windows.Forms.NumericUpDown
$numMaxDigits.Minimum = 1; $numMaxDigits.Maximum = 10; $numMaxDigits.Value = 3
$numMaxDigits.Location = "32, $y"; $numMaxDigits.Width = 60; $pnlOpts.Controls.Add($numMaxDigits); $y += 30
$chkAnchor = Add-Check $pnlOpts ([ref]$y) '  Only strip suffixes at end of name' $true

$y += 6
$chkFindReplace = Add-Check $pnlOpts ([ref]$y) 'Find & replace text in name' $false
$lblFind = New-Object System.Windows.Forms.Label; $lblFind.Text = '  Find:'; $lblFind.AutoSize = $true
$lblFind.Location = "28, $y"; $pnlOpts.Controls.Add($lblFind); $y += 20
$txtFind = New-Object System.Windows.Forms.TextBox; $txtFind.Location = "32, $y"; $txtFind.Width = 280; $pnlOpts.Controls.Add($txtFind); $y += 28
$lblReplace = New-Object System.Windows.Forms.Label; $lblReplace.Text = '  Replace with:'; $lblReplace.AutoSize = $true
$lblReplace.Location = "28, $y"; $pnlOpts.Controls.Add($lblReplace); $y += 20
$txtReplace = New-Object System.Windows.Forms.TextBox; $txtReplace.Location = "32, $y"; $txtReplace.Width = 280; $pnlOpts.Controls.Add($txtReplace); $y += 30

$lblPrefix = New-Object System.Windows.Forms.Label; $lblPrefix.Text = 'Add prefix:'; $lblPrefix.AutoSize = $true
$lblPrefix.Location = "12, $y"; $pnlOpts.Controls.Add($lblPrefix); $y += 20
$txtPrefix = New-Object System.Windows.Forms.TextBox; $txtPrefix.Location = "12, $y"; $txtPrefix.Width = 300; $pnlOpts.Controls.Add($txtPrefix); $y += 28
$lblSuffix = New-Object System.Windows.Forms.Label; $lblSuffix.Text = 'Add suffix (before extension):'; $lblSuffix.AutoSize = $true
$lblSuffix.Location = "12, $y"; $pnlOpts.Controls.Add($lblSuffix); $y += 20
$txtSuffix = New-Object System.Windows.Forms.TextBox; $txtSuffix.Location = "12, $y"; $txtSuffix.Width = 300; $pnlOpts.Controls.Add($txtSuffix); $y += 30

$lblCase = New-Object System.Windows.Forms.Label; $lblCase.Text = 'Change case:'; $lblCase.AutoSize = $true
$lblCase.Location = "12, $y"; $pnlOpts.Controls.Add($lblCase); $y += 20
$cmbCase = New-Object System.Windows.Forms.ComboBox
$cmbCase.DropDownStyle = 'DropDownList'
[void]$cmbCase.Items.AddRange(@('(none)', 'lowercase', 'UPPERCASE', 'Title Case'))
$cmbCase.SelectedIndex = 0
$cmbCase.Location = "12, $y"; $cmbCase.Width = 300; $pnlOpts.Controls.Add($cmbCase); $y += 30

$chkTrim = Add-Check $pnlOpts ([ref]$y) 'Trim & collapse extra spaces' $false
$chkLog  = Add-Check $pnlOpts ([ref]$y) 'Write CSV log after rename' $true

# results list (fill)
$lv = New-Object System.Windows.Forms.ListView
$lv.View = 'Details'
$lv.FullRowSelect = $true
$lv.GridLines = $true
$lv.Dock = 'Fill'
[void]$lv.Columns.Add('#', 40)
[void]$lv.Columns.Add('Original Name', 240)
[void]$lv.Columns.Add('New Name', 240)
[void]$lv.Columns.Add('Status', 150)

# button panel (bottom)
$pnlButtons = New-Object System.Windows.Forms.Panel
$pnlButtons.Dock = 'Bottom'
$pnlButtons.Height = 52
$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = 'Preview'
$btnPreview.Location = '12, 12'
$btnPreview.Width = 120; $btnPreview.Height = 30
$btnPreview.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
$btnPreview.Add_Click({ Invoke-Preview })
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Apply Rename'
$btnApply.Location = '142, 12'
$btnApply.Width = 120; $btnApply.Height = 30
$btnApply.BackColor = [System.Drawing.Color]::LightGreen
$btnApply.Add_Click({ Invoke-Apply })
$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = 'Clear List'
$btnClear.Location = '272, 12'
$btnClear.Width = 100; $btnClear.Height = 30
$btnClear.Add_Click({ $lv.Items.Clear(); $script:Results = @(); Set-Status 'Cleared' })
$pnlButtons.Controls.AddRange(@($btnPreview, $btnApply, $btnClear))

# status strip
$status = New-Object System.Windows.Forms.StatusStrip
$lblStatus = New-Object System.Windows.Forms.ToolStripStatusLabel
$lblStatus.Text = 'Ready — select a folder, choose options, then Preview first'
$lblStatus.Spring = $true
$lblStatus.TextAlign = 'MiddleLeft'
[void]$status.Items.Add($lblStatus)

# add controls in dock order (fill last)
$form.Controls.Add($lv)
$form.Controls.Add($pnlButtons)
$form.Controls.Add($pnlOpts)
$form.Controls.Add($pnlFolder)
$form.Controls.Add($menu)
$form.Controls.Add($status)

Set-Status 'Ready — select a folder, choose options, then Preview first'
[void]$form.ShowDialog()
