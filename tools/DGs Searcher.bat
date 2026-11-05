@echo off
setlocal
title DGs Searcher
set "BATFILE=%~f0"
set "PS1=%TEMP%\FolderSearcher_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = Get-Content -LiteralPath $env:BATFILE -Raw -Encoding UTF8; $m = '#=====' + 'PSCODE' + '====='; $i = $c.IndexOf($m); if ($i -lt 0) { exit 1 }; $c.Substring($i + $m.Length) | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"
if errorlevel 1 (
    echo Failed to prepare the search tool.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del "%PS1%" >nul 2>&1
exit /b %RC%
#=====PSCODE=====
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms | Out-Null

$script:Root = $env:USERPROFILE
$script:Results = @()
$script:CfgDir = Join-Path $env:LOCALAPPDATA 'DGFolderSearcher'
if (-not (Test-Path -LiteralPath $script:CfgDir)) {
    New-Item -ItemType Directory -Path $script:CfgDir -Force | Out-Null
}
$script:RootFile = Join-Path $script:CfgDir 'root.txt'
$script:OutputFile = Join-Path $script:CfgDir 'output.txt'
$script:OutputDir = $script:CfgDir

if (Test-Path -LiteralPath $script:RootFile) {
    $saved = (Get-Content -LiteralPath $script:RootFile -Raw).Trim()
    if ($saved -and (Test-Path -LiteralPath $saved)) { $script:Root = $saved }
}

if (Test-Path -LiteralPath $script:OutputFile) {
    $savedOut = (Get-Content -LiteralPath $script:OutputFile -Raw).Trim()
    if ($savedOut -and (Test-Path -LiteralPath $savedOut)) { $script:OutputDir = $savedOut }
}

function Pause-Key {
    Write-Host ''
    [void](Read-Host 'Press Enter to continue')
}

function Select-Folder {
    param([string]$Initial, [string]$Title = 'Select the folder to search')
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $Title
    $dlg.ShowNewFolderButton = $true
    if ($Initial -and (Test-Path -LiteralPath $Initial)) { $dlg.SelectedPath = $Initial }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dlg.SelectedPath
    }
    return $null
}

function Select-Files {
    param([string]$Initial)
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Select file(s)'
    $dlg.Multiselect = $true
    $dlg.CheckFileExists = $true
    if ($Initial -and (Test-Path -LiteralPath $Initial)) { $dlg.InitialDirectory = $Initial }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return @($dlg.FileNames)
    }
    return @()
}

function Get-FileTags {
    param([Parameter(Mandatory)][string]$Path)
    $result = @()
    try {
        $raw = Get-Content -LiteralPath $Path -Stream 'DGTags' -ErrorAction Stop
        if ($raw) {
            $result = @(($raw -join ',') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
    } catch {
        $result = @()
    }
    return $result
}

function Add-FileTags {
    param([string]$Path, [string[]]$Tags)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($t in (Get-FileTags -Path $Path)) { [void]$set.Add($t) }
    foreach ($t in $Tags) {
        $clean = $t.Trim()
        if ($clean) { [void]$set.Add($clean) }
    }
    $joined = (@($set) -join ',')
    if ($joined) {
        Set-Content -LiteralPath $Path -Stream 'DGTags' -Value $joined -NoNewline -Encoding UTF8
    }
}

function Remove-FileTags {
    param([string]$Path, [string[]]$Tags)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($t in (Get-FileTags -Path $Path)) { [void]$set.Add($t) }
    foreach ($t in $Tags) { [void]$set.Remove($t.Trim()) }
    if ($set.Count -eq 0) {
        Remove-Item -LiteralPath $Path -Stream 'DGTags' -ErrorAction SilentlyContinue
    } else {
        Set-Content -LiteralPath $Path -Stream 'DGTags' -Value (@($set) -join ',') -NoNewline -Encoding UTF8
    }
}

function Show-Results {
    $i = 0
    foreach ($r in $script:Results) {
        $i++
        Write-Host ("[{0}] {1}" -f $i, $r.FullName) -ForegroundColor White
        $tagText = if ($r.Tags) { $r.Tags } else { '(none)' }
        Write-Host ("     Created: {0}   Modified: {1}" -f $r.Created.ToString('yyyy-MM-dd HH:mm:ss'), $r.Modified.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
        Write-Host ("     Size: {0} KB   Tags: {1}" -f $r.SizeKB, $tagText) -ForegroundColor DarkGray
    }
}

function Invoke-Search {
    param(
        [scriptblock]$Filter
    )
    if (-not (Test-Path -LiteralPath $script:Root)) {
        Write-Host 'Search folder does not exist.' -ForegroundColor Red
        Pause-Key
        return
    }
    Write-Host ''
    Write-Host ('Searching: ' + $script:Root) -ForegroundColor Cyan
    Write-Host 'Please wait...' -ForegroundColor DarkGray
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $found = @()
    try {
        $all = @(Get-ChildItem -LiteralPath $script:Root -File -Recurse -Force -ErrorAction SilentlyContinue)
        $found = @($all | Where-Object $Filter | ForEach-Object {
            [pscustomobject]@{
                FullName = $_.FullName
                Name     = $_.Name
                Created  = $_.CreationTime
                Modified = $_.LastWriteTime
                SizeKB   = [math]::Round($_.Length / 1KB, 1)
                Tags     = ((Get-FileTags -Path $_.FullName) -join ', ')
            }
        })
    } catch {
        Write-Host ('Search error: ' + $_.Exception.Message) -ForegroundColor Red
        Pause-Key
        return
    }
    $sw.Stop()
    $script:Results = $found
    Write-Host ''
    Write-Host ("Found {0} file(s) in {1:n1} s." -f $found.Count, $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    if ($found.Count -gt 0) {
        Show-Results
        $save = $found | ForEach-Object {
            "{0}`t{1}`t{2} KB`t{3}`t{4}" -f $_.Created.ToString('yyyy-MM-dd HH:mm:ss'), $_.Modified.ToString('yyyy-MM-dd HH:mm:ss'), $_.SizeKB, $_.Tags, $_.FullName
        }
        if (-not (Test-Path -LiteralPath $script:OutputDir)) {
            New-Item -ItemType Directory -Path $script:OutputDir -Force | Out-Null
        }
        $outFile = Join-Path $script:OutputDir ('SearchResults_' + (Get-Date).ToString('yyyyMMdd_HHmmss') + '.txt')
        Set-Content -LiteralPath $outFile -Value $save -Encoding UTF8
        Write-Host ('Results saved to: ' + $outFile) -ForegroundColor DarkGray
    }
    Pause-Key
}

function Set-SearchRoot {
    $p = Select-Folder -Initial $script:Root
    if ($p) {
        $script:Root = $p
        Set-Content -LiteralPath $script:RootFile -Value $p -Encoding UTF8
        Write-Host ('Search folder set to: ' + $p) -ForegroundColor Green
    } else {
        Write-Host 'No folder selected.' -ForegroundColor DarkGray
    }
    Pause-Key
}

function Set-OutputRoot {
    $p = Select-Folder -Initial $script:OutputDir -Title 'Select the folder for saved search results'
    if ($p) {
        $script:OutputDir = $p
        Set-Content -LiteralPath $script:OutputFile -Value $p -Encoding UTF8
        Write-Host ('Output folder set to: ' + $p) -ForegroundColor Green
    } else {
        Write-Host 'No folder selected.' -ForegroundColor DarkGray
    }
    Pause-Key
}

function Search-LastHours {
    $nText = Read-Host 'Created within the last N hours (for example 24)'
    $n = 0.0
    if (-not [double]::TryParse($nText, [ref]$n) -or $n -le 0) {
        Write-Host 'Please enter a positive number.' -ForegroundColor Red
        Pause-Key
        return
    }
    $cut = (Get-Date).AddHours(-$n)
    Invoke-Search -Filter { $_.CreationTime -ge $cut }.GetNewClosure()
}

function Search-HourOfDay {
    $hText = Read-Host 'Hour of day to match (0-23)'
    $h = -1
    if (-not [int]::TryParse($hText, [ref]$h) -or $h -lt 0 -or $h -gt 23) {
        Write-Host 'Please enter an hour from 0 to 23.' -ForegroundColor Red
        Pause-Key
        return
    }
    Invoke-Search -Filter { $_.CreationTime.Hour -eq $h }.GetNewClosure()
}

function Search-DateHour {
    $dText = Read-Host 'Date (YYYY-MM-DD)'
    $dt = [datetime]::MinValue
    $ok = [datetime]::TryParse($dText, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$dt)
    if (-not $ok) {
        Write-Host 'Invalid date. Use YYYY-MM-DD.' -ForegroundColor Red
        Pause-Key
        return
    }
    $hText = Read-Host 'Hour of day (0-23)'
    $h = -1
    if (-not [int]::TryParse($hText, [ref]$h) -or $h -lt 0 -or $h -gt 23) {
        Write-Host 'Please enter an hour from 0 to 23.' -ForegroundColor Red
        Pause-Key
        return
    }
    Invoke-Search -Filter { $_.CreationTime.Date -eq $dt.Date -and $_.CreationTime.Hour -eq $h }.GetNewClosure()
}

function Search-ByTag {
    $tag = Read-Host 'Tag to find'
    if (-not $tag -or -not $tag.Trim()) { return }
    $needle = $tag.Trim()
    Invoke-Search -Filter {
        $t = Get-FileTags -Path $_.FullName
        @($t | Where-Object { $_ -ieq $needle }).Count -gt 0
    }.GetNewClosure()
}

function Read-DateValue {
    param([string]$Prompt, [bool]$AllowBlank = $false)
    $text = Read-Host $Prompt
    if ($AllowBlank -and (-not $text -or -not $text.Trim())) { return $null }
    $dt = [datetime]::MinValue
    $ok = [datetime]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$dt)
    if (-not $ok) { throw ("Invalid date '" + $text + "'. Use YYYY-MM-DD.") }
    return $dt
}

function Read-SizeMB {
    param([string]$Prompt)
    $text = Read-Host $Prompt
    if (-not $text -or -not $text.Trim()) { return $null }
    $v = 0.0
    if (-not [double]::TryParse($text, [ref]$v) -or $v -lt 0) { throw ("Invalid size '" + $text + "'.") }
    return [double]($v * 1MB)
}

function Search-CreatedRange {
    try {
        $from = Read-DateValue -Prompt 'Created on or after (YYYY-MM-DD)'
        $to = Read-DateValue -Prompt 'Created on or before (YYYY-MM-DD)'
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Pause-Key
        return
    }
    $start = $from.Date
    $end = $to.Date.AddDays(1)
    Invoke-Search -Filter { $_.CreationTime -ge $start -and $_.CreationTime -lt $end }.GetNewClosure()
}

function Search-OlderThan {
    $nText = Read-Host 'Created more than N days ago'
    $n = 0.0
    if (-not [double]::TryParse($nText, [ref]$n) -or $n -le 0) {
        Write-Host 'Please enter a positive number.' -ForegroundColor Red
        Pause-Key
        return
    }
    $cut = (Get-Date).AddDays(-$n)
    Invoke-Search -Filter { $_.CreationTime -lt $cut }.GetNewClosure()
}

function Search-ModifiedLastHours {
    $nText = Read-Host 'Modified within the last N hours (for example 24)'
    $n = 0.0
    if (-not [double]::TryParse($nText, [ref]$n) -or $n -le 0) {
        Write-Host 'Please enter a positive number.' -ForegroundColor Red
        Pause-Key
        return
    }
    $cut = (Get-Date).AddHours(-$n)
    Invoke-Search -Filter { $_.LastWriteTime -ge $cut }.GetNewClosure()
}

function Search-ModifiedHourOfDay {
    $hText = Read-Host 'Modified hour of day to match (0-23)'
    $h = -1
    if (-not [int]::TryParse($hText, [ref]$h) -or $h -lt 0 -or $h -gt 23) {
        Write-Host 'Please enter an hour from 0 to 23.' -ForegroundColor Red
        Pause-Key
        return
    }
    Invoke-Search -Filter { $_.LastWriteTime.Hour -eq $h }.GetNewClosure()
}

function Search-ModifiedDateHour {
    try {
        $dt = Read-DateValue -Prompt 'Modified date (YYYY-MM-DD)'
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Pause-Key
        return
    }
    $hText = Read-Host 'Modified hour of day (0-23)'
    $h = -1
    if (-not [int]::TryParse($hText, [ref]$h) -or $h -lt 0 -or $h -gt 23) {
        Write-Host 'Please enter an hour from 0 to 23.' -ForegroundColor Red
        Pause-Key
        return
    }
    Invoke-Search -Filter { $_.LastWriteTime.Date -eq $dt.Date -and $_.LastWriteTime.Hour -eq $h }.GetNewClosure()
}

function Search-Name {
    $pattern = Read-Host 'Name or wildcard (e.g. report*, *.pdf)'
    if (-not $pattern -or -not $pattern.Trim()) { return }
    $pattern = $pattern.Trim()
    if ($pattern -notmatch '[*?]') { $pattern = '*' + $pattern + '*' }
    Invoke-Search -Filter { $_.Name -like $pattern }.GetNewClosure()
}

function Search-Extension {
    $text = Read-Host 'Extension(s), e.g. pdf,jpg'
    $exts = @($text -split '[,;\s]+' | ForEach-Object { $_.Trim().TrimStart('.').ToLower() } | Where-Object { $_ })
    if ($exts.Count -eq 0) { return }
    Invoke-Search -Filter { $exts -contains $_.Extension.TrimStart('.').ToLower() }.GetNewClosure()
}

function Search-Type {
    Write-Host ''
    Write-Host ' File types:' -ForegroundColor Cyan
    Write-Host '  1) Documents  (pdf, doc, docx, txt, rtf, xls, xlsx, ppt, pptx, csv, odt)' -ForegroundColor Gray
    Write-Host '  2) Images     (jpg, jpeg, png, gif, bmp, webp, tif, tiff, svg, ico, heic)' -ForegroundColor Gray
    Write-Host '  3) Video      (mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg)' -ForegroundColor Gray
    Write-Host '  4) Audio      (mp3, wav, flac, aac, ogg, m4a, wma, aiff)' -ForegroundColor Gray
    Write-Host '  5) Archives   (zip, rar, 7z, tar, gz, bz2, iso, cab)' -ForegroundColor Gray
    Write-Host '  6) Code       (ps1, bat, cmd, js, ts, html, css, py, java, cs, cpp, c, h, json, xml, sql)' -ForegroundColor Gray
    Write-Host '  7) Executables(exe, msi, dll, com, scr, bat, cmd)' -ForegroundColor Gray
    Write-Host '  8) Type any extensions yourself' -ForegroundColor Gray
    Write-Host ''
    $choice = Read-Host 'Choose a file type (1-8)'

    $exts = @()
    switch ($choice) {
        '1' { $exts = @('pdf','doc','docx','txt','rtf','xls','xlsx','ppt','pptx','csv','odt') }
        '2' { $exts = @('jpg','jpeg','png','gif','bmp','webp','tif','tiff','svg','ico','heic') }
        '3' { $exts = @('mp4','mkv','avi','mov','wmv','flv','webm','m4v','mpg','mpeg') }
        '4' { $exts = @('mp3','wav','flac','aac','ogg','m4a','wma','aiff') }
        '5' { $exts = @('zip','rar','7z','tar','gz','bz2','iso','cab') }
        '6' { $exts = @('ps1','bat','cmd','js','ts','html','htm','css','py','java','cs','cpp','c','h','json','xml','sql','sh') }
        '7' { $exts = @('exe','msi','dll','com','scr','bat','cmd') }
        '8' {
            $text = Read-Host 'Extension(s), e.g. pdf,jpg'
            $exts = @($text -split '[,;\s]+' | ForEach-Object { $_.Trim().TrimStart('.').ToLower() } | Where-Object { $_ })
        }
        default { return }
    }
    if ($exts.Count -eq 0) { return }
    Invoke-Search -Filter { $exts -contains $_.Extension.TrimStart('.').ToLower() }.GetNewClosure()
}

function Search-Size {
    $minSize = $null
    $maxSize = $null
    $v = 0.0
    $minText = Read-Host 'Minimum size in MB (blank = none)'
    if ($minText -and $minText.Trim()) {
        if (-not [double]::TryParse($minText, [ref]$v) -or $v -lt 0) {
            Write-Host 'Invalid minimum size.' -ForegroundColor Red
            Pause-Key
            return
        }
        $minSize = [double]($v * 1MB)
    }
    $maxText = Read-Host 'Maximum size in MB (blank = none)'
    if ($maxText -and $maxText.Trim()) {
        if (-not [double]::TryParse($maxText, [ref]$v) -or $v -lt 0) {
            Write-Host 'Invalid maximum size.' -ForegroundColor Red
            Pause-Key
            return
        }
        $maxSize = [double]($v * 1MB)
    }
    if ($minSize -eq $null -and $maxSize -eq $null) {
        Write-Host 'No size entered.' -ForegroundColor DarkGray
        Pause-Key
        return
    }
    Invoke-Search -Filter {
        ($minSize -eq $null -or $_.Length -ge $minSize) -and ($maxSize -eq $null -or $_.Length -le $maxSize)
    }.GetNewClosure()
}

function Search-Content {
    $needle = Read-Host 'Text to find inside files'
    if (-not $needle -or -not $needle.Trim()) { return }
    $needle = $needle.Trim()
    $extText = Read-Host 'Extensions to scan (e.g. txt,log,md; blank = common text files)'
    $common = @('txt','log','md','csv','json','xml','ini','cfg','ps1','bat','cmd','cs','cpp','c','h','js','ts','html','htm','css','py','java','sql','rtf')
    if ($extText -and $extText.Trim()) {
        $scanExts = @($extText -split '[,;\s]+' | ForEach-Object { $_.Trim().TrimStart('.').ToLower() } | Where-Object { $_ })
    } else {
        $scanExts = $common
    }
    Invoke-Search -Filter {
        $e = $_.Extension.TrimStart('.').ToLower()
        if ($scanExts -notcontains $e) { return $false }
        $txt = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $txt) { return $false }
        $txt.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    }.GetNewClosure()
}

function Search-Advanced {
    Write-Host 'Leave any answer blank to skip that criterion.' -ForegroundColor DarkGray
    $namePattern = Read-Host 'Name or wildcard (e.g. report*, *.pdf)'
    if ($namePattern -and ($namePattern -notmatch '[*?]')) { $namePattern = '*' + $namePattern + '*' }

    $extText = Read-Host 'Extensions (e.g. pdf,jpg; blank = any)'
    $exts = @()
    if ($extText -and $extText.Trim()) {
        $exts = @($extText -split '[,;\s]+' | ForEach-Object { $_.Trim().TrimStart('.').ToLower() } | Where-Object { $_ })
    }

    $createdAfter = $null
    $createdBefore = $null
    $modifiedAfter = $null
    $modifiedBefore = $null
    $minSize = $null
    $maxSize = $null
    $tagNeedle = $null
    $contentNeedle = $null
    $contentExts = @()

    try {
        $d = Read-DateValue -Prompt 'Created on or after (YYYY-MM-DD, blank = skip)' -AllowBlank $true
        if ($d) { $createdAfter = $d.Date }
        $d = Read-DateValue -Prompt 'Created on or before (YYYY-MM-DD, blank = skip)' -AllowBlank $true
        if ($d) { $createdBefore = $d.Date.AddDays(1) }
        $d = Read-DateValue -Prompt 'Modified on or after (YYYY-MM-DD, blank = skip)' -AllowBlank $true
        if ($d) { $modifiedAfter = $d.Date }
        $d = Read-DateValue -Prompt 'Modified on or before (YYYY-MM-DD, blank = skip)' -AllowBlank $true
        if ($d) { $modifiedBefore = $d.Date.AddDays(1) }
        $minSize = Read-SizeMB -Prompt 'Minimum size in MB (blank = skip)'
        $maxSize = Read-SizeMB -Prompt 'Maximum size in MB (blank = skip)'
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Pause-Key
        return
    }

    $tagText = Read-Host 'Tag (blank = skip)'
    if ($tagText -and $tagText.Trim()) { $tagNeedle = $tagText.Trim() }

    $contentNeedle = Read-Host 'Text inside files (blank = skip)'
    if ($contentNeedle) { $contentNeedle = $contentNeedle.Trim() }
    if ($contentNeedle) {
        $cExtText = Read-Host 'Content scan extensions (blank = common text files)'
        if ($cExtText -and $cExtText.Trim()) {
            $contentExts = @($cExtText -split '[,;\s]+' | ForEach-Object { $_.Trim().TrimStart('.').ToLower() } | Where-Object { $_ })
        } else {
            $contentExts = @('txt','log','md','csv','json','xml','ini','cfg','ps1','bat','cmd','cs','cpp','c','h','js','ts','html','htm','css','py','java','sql','rtf')
        }
    }

    $filter = {
        $f = $_
        if ($namePattern -and ($f.Name -notlike $namePattern)) { return $false }
        if ($exts.Count -gt 0) {
            $e = $f.Extension.TrimStart('.').ToLower()
            if ($exts -notcontains $e) { return $false }
        }
        if ($createdAfter -and ($f.CreationTime -lt $createdAfter)) { return $false }
        if ($createdBefore -and ($f.CreationTime -ge $createdBefore)) { return $false }
        if ($modifiedAfter -and ($f.LastWriteTime -lt $modifiedAfter)) { return $false }
        if ($modifiedBefore -and ($f.LastWriteTime -ge $modifiedBefore)) { return $false }
        if ($minSize -ne $null -and ($f.Length -lt $minSize)) { return $false }
        if ($maxSize -ne $null -and ($f.Length -gt $maxSize)) { return $false }
        if ($tagNeedle) {
            $t = Get-FileTags -Path $f.FullName
            if (@($t | Where-Object { $_ -ieq $tagNeedle }).Count -eq 0) { return $false }
        }
        if ($contentNeedle) {
            $e = $f.Extension.TrimStart('.').ToLower()
            if ($contentExts -notcontains $e) { return $false }
            $txt = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $txt) { return $false }
            if ($txt.IndexOf($contentNeedle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        }
        return $true
    }.GetNewClosure()

    Invoke-Search -Filter $filter
}

function Show-LastResults {
    if (@($script:Results).Count -eq 0) {
        Write-Host 'No results yet. Run a search first.' -ForegroundColor Yellow
        Pause-Key
        return
    }
    Show-Results
    Pause-Key
}

function Tag-Results {
    if (@($script:Results).Count -eq 0) {
        Write-Host 'No results to tag. Run a search first.' -ForegroundColor Yellow
        Pause-Key
        return
    }
    Write-Host ("This will add tags to {0} file(s)." -f @($script:Results).Count) -ForegroundColor Yellow
    $text = Read-Host 'Tags to add (comma separated)'
    $tags = @($text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($tags.Count -eq 0) {
        Write-Host 'No tags entered.' -ForegroundColor DarkGray
        Pause-Key
        return
    }
    $ok = 0
    foreach ($r in $script:Results) {
        try {
            Add-FileTags -Path $r.FullName -Tags $tags
            $r.Tags = ((Get-FileTags -Path $r.FullName) -join ', ')
            $ok++
        } catch {
            Write-Host ('Failed: ' + $r.FullName) -ForegroundColor Red
        }
    }
    Write-Host ("Tagged {0} file(s)." -f $ok) -ForegroundColor Green
    Pause-Key
}

function Tag-Files {
    $files = @(Select-Files -Initial $script:Root)
    if ($files.Count -eq 0) { return }
    $text = Read-Host 'Tags to add (comma separated)'
    $tags = @($text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($tags.Count -eq 0) { return }
    $ok = 0
    foreach ($f in $files) {
        try {
            Add-FileTags -Path $f -Tags $tags
            $ok++
        } catch {
            Write-Host ('Failed: ' + $f) -ForegroundColor Red
        }
    }
    Write-Host ("Tagged {0} file(s)." -f $ok) -ForegroundColor Green
    Pause-Key
}

function ShowTags-Files {
    $files = @(Select-Files -Initial $script:Root)
    if ($files.Count -eq 0) { return }
    foreach ($f in $files) {
        $tags = @(Get-FileTags -Path $f)
        Write-Host ''
        Write-Host $f -ForegroundColor White
        if ($tags.Count -eq 0) {
            Write-Host '  (no tags)' -ForegroundColor DarkGray
        } else {
            Write-Host ('  Tags: ' + ($tags -join ', ')) -ForegroundColor Yellow
        }
    }
    Pause-Key
}

function RemoveTags-Files {
    $files = @(Select-Files -Initial $script:Root)
    if ($files.Count -eq 0) { return }
    $text = Read-Host 'Tags to remove (comma separated)'
    $tags = @($text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($tags.Count -eq 0) { return }
    $ok = 0
    foreach ($f in $files) {
        try {
            Remove-FileTags -Path $f -Tags $tags
            $ok++
        } catch {
            Write-Host ('Failed: ' + $f) -ForegroundColor Red
        }
    }
    Write-Host ("Updated {0} file(s)." -f $ok) -ForegroundColor Green
    Pause-Key
}

function Open-Root {
    if (Test-Path -LiteralPath $script:Root) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:Root + '"')
    } else {
        Write-Host 'Search folder does not exist.' -ForegroundColor Red
        Pause-Key
    }
}

function Open-Output {
    if (Test-Path -LiteralPath $script:OutputDir) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:OutputDir + '"')
    } else {
        Write-Host 'Output folder does not exist.' -ForegroundColor Red
        Pause-Key
    }
}

function New-AppIcon {
    param([string]$IconPath)
    Add-Type -AssemblyName System.Drawing
    $sizes = @(256, 128, 64, 48, 32, 16)
    $base = [System.Drawing.Bitmap]::new(256, 256)
    $g = [System.Drawing.Graphics]::FromImage($base)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $rect = [System.Drawing.RectangleF]::new(12, 12, 232, 232)
    $d = 88.0
    $gp = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $gp.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $gp.AddArc(($rect.Right - $d), $rect.Y, $d, $d, 270, 90)
    $gp.AddArc(($rect.Right - $d), ($rect.Bottom - $d), $d, $d, 0, 90)
    $gp.AddArc($rect.X, ($rect.Bottom - $d), $d, $d, 90, 90)
    $gp.CloseFigure()

    $c1 = [System.Drawing.Color]::FromArgb(255, 37, 99, 235)
    $c2 = [System.Drawing.Color]::FromArgb(255, 6, 182, 212)
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, $c1, $c2, [single]45)
    $g.FillPath($brush, $gp)

    $glossRect = [System.Drawing.RectangleF]::new(12, 12, 232, 120)
    $gloss = [System.Drawing.Drawing2D.LinearGradientBrush]::new($glossRect, [System.Drawing.Color]::FromArgb(70, 255, 255, 255), [System.Drawing.Color]::FromArgb(0, 255, 255, 255), [single]90)
    $g.SetClip($gp)
    $g.FillRectangle($gloss, $glossRect)
    $g.ResetClip()

    $ring = [System.Drawing.Pen]::new([System.Drawing.Color]::White, [single]20)
    $ring.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $ring.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawEllipse($ring, 46, 40, 124, 124)
    $g.DrawLine($ring, 152, 148, 206, 202)

    $ring.Dispose()
    $brush.Dispose()
    $gloss.Dispose()
    $gp.Dispose()
    $g.Dispose()

    $pngs = New-Object System.Collections.ArrayList
    foreach ($s in $sizes) {
        $bmp = [System.Drawing.Bitmap]::new($s, $s)
        $gg = [System.Drawing.Graphics]::FromImage($bmp)
        $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $gg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $gg.DrawImage($base, [System.Drawing.Rectangle]::new(0, 0, $s, $s))
        $gg.Dispose()
        $ms = [System.IO.MemoryStream]::new()
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        [void]$pngs.Add($ms.ToArray())
        $ms.Dispose()
        $bmp.Dispose()
    }
    $base.Dispose()

    $fs = [System.IO.File]::Create($IconPath)
    $bw = [System.IO.BinaryWriter]::new($fs)
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i]
        $data = $pngs[$i]
        $dim = if ($s -ge 256) { 0 } else { $s }
        $bw.Write([byte]$dim)
        $bw.Write([byte]$dim)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$data.Length)
        $bw.Write([uint32]$offset)
        $offset += $data.Length
    }
    foreach ($data in $pngs) { $bw.Write($data) }
    $bw.Dispose()
    $fs.Dispose()
}

function Install-Shortcut {
    $bat = $env:BATFILE
    if (-not $bat -or -not (Test-Path -LiteralPath $bat)) {
        Write-Host 'Cannot find the program file.' -ForegroundColor Red
        Pause-Key
        return
    }
    $scriptDir = Split-Path -Parent $bat
    $icon = Join-Path $scriptDir 'DGs Searcher.ico'
    if (-not (Test-Path -LiteralPath $icon)) {
        try {
            New-AppIcon -IconPath $icon
        } catch {
            Write-Host ('Could not create icon: ' + $_.Exception.Message) -ForegroundColor Red
        }
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = Join-Path $desktop 'DGs Searcher.lnk'
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnk)
        $sc.TargetPath = $bat
        $sc.WorkingDirectory = $scriptDir
        if (Test-Path -LiteralPath $icon) { $sc.IconLocation = ($icon + ',0') }
        $sc.Description = 'DGs Searcher - search files by time, type, size, tag and content'
        $sc.Save()
        Write-Host ('Desktop shortcut created: ' + $lnk) -ForegroundColor Green
    } catch {
        Write-Host ('Could not create shortcut: ' + $_.Exception.Message) -ForegroundColor Red
    }
    Pause-Key
}

function Show-Menu {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host '              DGs SEARCHER' -ForegroundColor Cyan
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host (' Search folder : ' + $script:Root) -ForegroundColor White
    Write-Host (' Output folder : ' + $script:OutputDir) -ForegroundColor White
    Write-Host (' Last results  : ' + @($script:Results).Count + ' file(s)') -ForegroundColor White
    Write-Host ''
    Write-Host ' 1) Browse for search folder' -ForegroundColor Gray
    Write-Host ' --- Search by date/time ---' -ForegroundColor DarkCyan
    Write-Host ' 2) Created within last N hours' -ForegroundColor Gray
    Write-Host ' 3) Created during hour of day (0-23)' -ForegroundColor Gray
    Write-Host ' 4) Created on a date at an hour' -ForegroundColor Gray
    Write-Host ' 5) Created between two dates' -ForegroundColor Gray
    Write-Host ' 6) Created more than N days ago' -ForegroundColor Gray
    Write-Host ' 7) Modified within last N hours' -ForegroundColor Gray
    Write-Host ' 8) Modified during hour of day (0-23)' -ForegroundColor Gray
    Write-Host ' 9) Modified on a date at an hour' -ForegroundColor Gray
    Write-Host ' --- Search by name/type/size/tag/content ---' -ForegroundColor DarkCyan
    Write-Host '10) By name or wildcard' -ForegroundColor Gray
    Write-Host '11) By file type (documents, images, video...)' -ForegroundColor Gray
    Write-Host '12) By extension (pdf, jpg...)' -ForegroundColor Gray
    Write-Host '13) By size range (MB)' -ForegroundColor Gray
    Write-Host '14) By tag' -ForegroundColor Gray
    Write-Host '15) By text content' -ForegroundColor Gray
    Write-Host '16) Advanced search (combine criteria)' -ForegroundColor Gray
    Write-Host ' --- Results and tags ---' -ForegroundColor DarkCyan
    Write-Host '17) Show last results' -ForegroundColor Gray
    Write-Host '18) Apply tags to last results' -ForegroundColor Gray
    Write-Host '19) Apply tags to files (browse)' -ForegroundColor Gray
    Write-Host '20) Show tags of files (browse)' -ForegroundColor Gray
    Write-Host '21) Remove tags from files (browse)' -ForegroundColor Gray
    Write-Host '22) Open search folder' -ForegroundColor Gray
    Write-Host '23) Browse for output folder' -ForegroundColor Gray
    Write-Host '24) Open output folder' -ForegroundColor Gray
    Write-Host '25) Install: create desktop shortcut' -ForegroundColor Yellow
    Write-Host ' 0) Exit' -ForegroundColor Gray
    Write-Host ''
}

while ($true) {
    Show-Menu
    $choice = Read-Host 'Select an option'
    switch ($choice) {
        '1'  { Set-SearchRoot }
        '2'  { Search-LastHours }
        '3'  { Search-HourOfDay }
        '4'  { Search-DateHour }
        '5'  { Search-CreatedRange }
        '6'  { Search-OlderThan }
        '7'  { Search-ModifiedLastHours }
        '8'  { Search-ModifiedHourOfDay }
        '9'  { Search-ModifiedDateHour }
        '10' { Search-Name }
        '11' { Search-Type }
        '12' { Search-Extension }
        '13' { Search-Size }
        '14' { Search-ByTag }
        '15' { Search-Content }
        '16' { Search-Advanced }
        '17' { Show-LastResults }
        '18' { Tag-Results }
        '19' { Tag-Files }
        '20' { ShowTags-Files }
        '21' { RemoveTags-Files }
        '22' { Open-Root }
        '23' { Set-OutputRoot }
        '24' { Open-Output }
        '25' { Install-Shortcut }
        '0'  { return }
        default { }
    }
}
