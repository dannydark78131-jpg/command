[CmdletBinding()]
param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
[System.Windows.Forms.Application]::Add_ThreadException({param($s,$e); try{[System.Windows.Forms.MessageBox]::Show($e.Exception.Message,'DGS Renamer','OK','Error')|Out-Null}catch{}})

$script:BG = [System.Drawing.Color]::FromArgb(14,17,23)
$script:CARD = [System.Drawing.Color]::FromArgb(22,28,37)
$script:INPUT = [System.Drawing.Color]::FromArgb(16,21,29)
$script:BORDER = [System.Drawing.Color]::FromArgb(42,52,66)
$script:TEXT = [System.Drawing.Color]::FromArgb(232,237,245)
$script:MUTED = [System.Drawing.Color]::FromArgb(139,151,168)
$script:ACCENT = [System.Drawing.Color]::FromArgb(61,139,255)
$script:GREEN = [System.Drawing.Color]::FromArgb(52,211,153)
$script:AMBER = [System.Drawing.Color]::FromArgb(251,191,36)
$script:RED = [System.Drawing.Color]::FromArgb(248,113,113)

$FBase = New-Object System.Drawing.Font('Segoe UI',9.5)
$FSemi = New-Object System.Drawing.Font('Segoe UI Semibold',9.5)
$FSmall = New-Object System.Drawing.Font('Segoe UI',8.5)
$FTiny = New-Object System.Drawing.Font('Segoe UI',8)
$FHead = New-Object System.Drawing.Font('Segoe UI Semibold',18)
$FTitle = New-Object System.Drawing.Font('Segoe UI Semibold',14)
$FSec = New-Object System.Drawing.Font('Segoe UI Semibold',8)

$AppData = Join-Path $env:APPDATA 'DGS Renamer'
$LogDir = Join-Path $AppData 'logs'
$StateDir = Join-Path $AppData 'state'
$UndoPath = Join-Path $StateDir 'last-run.json'
$SettingsPath = Join-Path $AppData 'settings.json'
New-Item -ItemType Directory -Force -Path $AppData,$LogDir,$StateDir | Out-Null

function Get-ScriptDir {
  if($PSScriptRoot){return $PSScriptRoot}
  if($MyInvocation.MyCommand.Path){return (Split-Path -Parent $MyInvocation.MyCommand.Path)}
  try{$p=[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;if($p){return (Split-Path -Parent $p)}}catch{}
  return (Get-Location).Path
}
$ScriptDir = Get-ScriptDir
$IconPath = Join-Path $ScriptDir 'DGS.Renamer.ico'
$Preview = New-Object System.Collections.ArrayList

function Clean-Base([string]$b,[bool]$dup,[bool]$sp,[bool]$tc){
  $n=$b
  if($dup){$n=[regex]::Replace($n,'(?:\s*\(\d+\))+$','')}
  if($sp){$n=($n -replace '\s+',' ').Trim()}
  if($tc){try{$n=(Get-Culture).TextInfo.ToTitleCase($n.ToLower())}catch{}}
  if([string]::IsNullOrWhiteSpace($n)){return $b}
  return $n
}

function Get-Prev([string]$folder,[bool]$rec,[bool]$dup,[bool]$sp,[bool]$tc){
  $items=New-Object System.Collections.ArrayList
  if([string]::IsNullOrWhiteSpace($folder)){return @()}
  try{
    if(-not(Test-Path -LiteralPath $folder -PathType Container)){return @()}
  }catch{return @()}
  try{
    $files=Get-ChildItem -LiteralPath $folder -File -Recurse:$rec -ErrorAction SilentlyContinue
    $root=[IO.Path]::GetFullPath($folder).TrimEnd('\','/')
    foreach($f in $files){
      $nb=Clean-Base $f.BaseName $dup $sp $tc
      $nn=$nb+$f.Extension
      if($nn -ceq $f.Name){continue}
      $df=[IO.Path]::GetFullPath($f.DirectoryName).TrimEnd('\','/')
      $dp=[IO.Path]::GetFullPath((Join-Path $df $nn))
      $st='Ready';$dt=''
      try{
        if(Test-Path -LiteralPath $dp){
          if(-not [string]::Equals($dp,[IO.Path]::GetFullPath($f.FullName),[StringComparison]::OrdinalIgnoreCase)){$st='Conflict';$dt='Exists'}
        }
      }catch{}
      $rel='.'
      if($df.Length -gt $root.Length){$rel=$df.Substring($root.Length).TrimStart('\','/')}
      [void]$items.Add([pscustomobject]@{Src=[IO.Path]::GetFullPath($f.FullName);Dir=$df;Old=$f.Name;New=$nn;DFull=$dp;Rel=$rel;Status=$st;Detail=$dt;Apply=($st -eq 'Ready')})
    }
    $grp=@{}
    foreach($it in $items){$k=($it.Dir+'|'+$it.New).ToLowerInvariant();if(-not $grp.ContainsKey($k)){$grp[$k]=New-Object System.Collections.ArrayList};[void]$grp[$k].Add($it)}
    foreach($k in $grp.Keys){$g=$grp[$k];if($g.Count -gt 1){foreach($it in $g){if($it.Status -eq 'Ready'){$it.Status='Duplicate';$it.Detail='Target conflict';$it.Apply=$false}}}}
    return @($items)
  }catch{return @()}
}

function Ren-One([string]$src,[string]$leaf){
  $dir=Split-Path -Parent $src; $dest=Join-Path $dir $leaf
  $ci=[string]::Equals($src,$dest,[StringComparison]::OrdinalIgnoreCase); $ex=[string]::Equals($src,$dest,[StringComparison]::Ordinal)
  if($ci -and -not $ex){$tmp='~dgs_'+[guid]::NewGuid().ToString('N')+'.tmp'; Rename-Item -LiteralPath $src -NewName $tmp -ErrorAction Stop; try{Rename-Item -LiteralPath (Join-Path $dir $tmp) -NewName $leaf -ErrorAction Stop}catch{try{Rename-Item -LiteralPath (Join-Path $dir $tmp) -NewName (Split-Path -Leaf $src) -ErrorAction Stop}catch{};throw}}
  else{Rename-Item -LiteralPath $src -NewName $leaf -ErrorAction Stop}
  return $dest
}

function WLog($rows,$lbl){if(-not $rows -or $rows.Count -eq 0){return ''};$st=Get-Date -Format 'yyyyMMdd-HHmmss';$p=Join-Path $LogDir ('r-'+$st+'-'+$lbl+'.csv');try{$rows|Export-Csv -LiteralPath $p -NoTypeInformation -Encoding UTF8}catch{return ''};return $p}

function Scan(){
  $f=$Txt.Text.Trim(); if([string]::IsNullOrWhiteSpace($f)){$St.Text='Choose a folder.';return}
  try{
    if(-not(Test-Path -LiteralPath $f -PathType Container)){$St.Text='Folder not found.';return}
  }catch{$St.Text='Folder not found.';return}
  $old=$Form.Cursor; $Form.Cursor=[System.Windows.Forms.Cursors]::WaitCursor; $St.Text='Scanning...'
  try{
    $its=Get-Prev $f $ChkRec.Checked $ChkDup.Checked $ChkSp.Checked $ChkTc.Checked
    $Preview.Clear(); if($its){ foreach($x in $its){[void]$Preview.Add($x)} }
    $Grid.Rows.Clear()
    foreach($it in $Preview){
      $i=$Grid.Rows.Add($it.Apply,$it.Old,$it.New,$it.Rel,$it.Status)
      $r=$Grid.Rows[$i]; $r.Tag=$it
      if($it.Status -eq 'Ready'){$r.Cells[4].Style.ForeColor=$GREEN}elseif($it.Status -eq 'Duplicate'){$r.Cells[4].Style.ForeColor=$AMBER}else{$r.Cells[4].Style.ForeColor=$RED}
      if($it.Status -ne 'Ready'){$r.Cells[2].Style.ForeColor=$MUTED}
    }
    $rd=@($Preview|Where-Object{$_.Status -eq 'Ready'}).Count; $cd=$Preview.Count-$rd
    if($Preview.Count -eq 0){$St.Text='No changes.'}elseif($rd -eq 0){$St.Text="All conflict ($cd)."}else{$St.Text="Ready: $rd, Conflicts: $cd."}
    $Cnt.Text="Changes: $($Preview.Count) | Ready: $rd"
  }catch{$St.Text='Error: '+$_.Exception.Message}finally{$Form.Cursor=$old}
  Save-Set; Upd-Undo
}

function Save-Set(){
  try{[ordered]@{Folder=$Txt.Text;Rec=$ChkRec.Checked;Dup=$ChkDup.Checked;Sp=$ChkSp.Checked;Tc=$ChkTc.Checked;Cf=$ChkCf.Checked}|ConvertTo-Json|Set-Content -LiteralPath $SettingsPath -Encoding UTF8}catch{}
}
function Load-Set(){
  $r=[pscustomobject]@{Folder='';Rec=$true;Dup=$true;Sp=$true;Tc=$false;Cf=$true}
  if(Test-Path -LiteralPath $SettingsPath){try{$s=Get-Content -LiteralPath $SettingsPath -Raw|ConvertFrom-Json;foreach($p in $r.PSObject.Properties){$v=$s.PSObject.Properties[$p.Name];if($null -ne $v){$p.Value=$v.Value}}}catch{}}
  return $r
}
function Upd-Undo(){ if($BtnU){$BtnU.Enabled=(Test-Path -LiteralPath $UndoPath)} }

function Do-Rename(){
  $sel=@($Preview|?{$_.Apply -and $_.Status -eq 'Ready'})
  if($sel.Count -eq 0){[System.Windows.Forms.MessageBox]::Show($Form,'Select ready items.','Nothing selected','OK','Information')|Out-Null;return}
  if($ChkCf.Checked){if([System.Windows.Forms.MessageBox]::Show($Form,"Rename $($sel.Count) file(s)?",'Confirm','YesNo','Question') -ne [System.Windows.Forms.DialogResult]::Yes){return}}
  $old=$Form.Cursor;$Form.Cursor=[System.Windows.Forms.Cursors]::WaitCursor
  $log=New-Object System.Collections.ArrayList; $undo=New-Object System.Collections.ArrayList; $rn=0;$fl=0;$ts=(Get-Date).ToString('o')
  try{
    foreach($it in $sel){try{$d=Ren-One $it.Src $it.New;$rn++;[void]$log.Add([pscustomobject]@{Timestamp=$ts;Action='Rename';Result='OK';From=$it.Src;To=$d});[void]$undo.Add([pscustomobject]@{From=$it.Src;To=$d})}catch{$fl++;[void]$log.Add([pscustomobject]@{Timestamp=$ts;Action='Rename';Result='Failed';From=$it.Src;To=$it.DFull;Note=$_.Exception.Message})}}
    if($undo.Count -gt 0){try{[pscustomobject]@{Timestamp=$ts;Count=$undo.Count;Entries=@($undo)}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $UndoPath -Encoding UTF8}catch{}}
    $lp=WLog $log 'rename'; $msg="Renamed: $rn"; if($fl -gt 0){$msg+=" Failed: $fl"}; if($lp){$msg+="`r`nLog: $lp"}; [System.Windows.Forms.MessageBox]::Show($Form,$msg,'Done','OK','Information')|Out-Null
  }finally{$Form.Cursor=$old; Upd-Undo; Scan}
}

function Do-Undo(){
  if(-not(Test-Path -LiteralPath $UndoPath)){[System.Windows.Forms.MessageBox]::Show($Form,'No undo record.','Undo','OK','Information')|Out-Null;return}
  try{$d=Get-Content -LiteralPath $UndoPath -Raw|ConvertFrom-Json;$ent=@($d.Entries)}catch{return}
  if($ent.Count -eq 0){return}
  if([System.Windows.Forms.MessageBox]::Show($Form,"Restore $($ent.Count) names?",'Undo','YesNo','Question') -ne [System.Windows.Forms.DialogResult]::Yes){return}
  $old=$Form.Cursor;$Form.Cursor=[System.Windows.Forms.Cursors]::WaitCursor; $log=New-Object System.Collections.ArrayList;$rs=0;$fl=0;$ts=(Get-Date).ToString('o')
  try{
    for($i=$ent.Count-1;$i -ge 0;$i--){$e=$ent[$i];$cur=[string]$e.To;$orig=[string]$e.From;$ol=Split-Path -Leaf $orig;try{if(-not(Test-Path -LiteralPath $cur)){throw 'missing'};if(Test-Path -LiteralPath $orig){throw 'exists'};$x=Ren-One $cur $ol;$rs++;[void]$log.Add([pscustomobject]@{Timestamp=$ts;Action='Undo';Result='OK';From=$cur;To=$x})}catch{$fl++;[void]$log.Add([pscustomobject]@{Timestamp=$ts;Action='Undo';Result='Failed';From=$cur;To=$orig;Note=$_.Exception.Message})}}
    try{Remove-Item -LiteralPath $UndoPath -Force}catch{}; $lp=WLog $log 'undo'; $msg="Restored: $rs"; if($fl -gt 0){$msg+=" Failed: $fl"}; if($lp){$msg+="`r`nLog: $lp"}; [System.Windows.Forms.MessageBox]::Show($Form,$msg,'Undo done','OK','Information')|Out-Null
  }finally{$Form.Cursor=$old; Upd-Undo; Scan}
}

function Export-Csv(){
  if($Preview.Count -eq 0){[System.Windows.Forms.MessageBox]::Show($Form,'Nothing to export.','Export','OK','Information')|Out-Null;return}
  $d=New-Object System.Windows.Forms.SaveFileDialog;$d.Title='Export';$d.Filter='CSV (*.csv)|*.csv';$d.FileName='DGS-RenamePreview-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.csv'
  try{if($d.ShowDialog($Form) -ne 'OK'){return}; $Preview|Select-Object @{N='Apply';E={$_.Apply}},@{N='Old';E={$_.Old}},@{N='New';E={$_.New}},@{N='Folder';E={$_.Rel}},@{N='Status';E={$_.Status}}|Export-Csv -LiteralPath $d.FileName -NoTypeInformation -Encoding UTF8;$St.Text='Exported'}catch{[System.Windows.Forms.MessageBox]::Show($Form,$_.Exception.Message,'Error','OK','Error')|Out-Null}finally{$d.Dispose()}
}

function Self-Test(){
  $root=Join-Path ([IO.Path]::GetTempPath()) ('DGR_'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $root -Force|Out-Null
  try{
    $d1=Join-Path $root 't1'; New-Item -ItemType Directory -Path $d1|Out-Null; 'a'|Set-Content (Join-Path $d1 'x (1).txt'); 'b'|Set-Content (Join-Path $d1 'x (2).txt'); $it=Get-Prev $d1 $false $true $true $false; if(($it|?{$_.Status -ne 'Duplicate'}).Count -ne 0){throw 'dup'}
    $d2=Join-Path $root 't2'; New-Item -ItemType Directory -Path $d2|Out-Null; 'c'|Set-Content (Join-Path $d2 'a   b (1).md'); $it2=Get-Prev $d2 $false $true $true $false; if($it2[0].New -ne 'a b.md'){throw 'sp'}
    $d3=Join-Path $root 't3'; New-Item -ItemType Directory -Path $d3|Out-Null; $p3=Join-Path $d3 'f (1).log'; 'd'|Set-Content $p3; $it3=Get-Prev $d3 $false $true $true $false; $dst=Ren-One $it3[0].Src $it3[0].New; if(-not(Test-Path $dst)){throw 'ren'}
  }finally{try{Remove-Item $root -Recurse -Force}catch{}}
  [Console]::WriteLine('RENAMER-SELFTEST-PASS'); exit 0
}
if($SelfTest){Self-Test}

$Form = New-Object System.Windows.Forms.Form
$AppVersion='1.0.4'; $Form.Text="DGS Renamer v$AppVersion"; $Form.ClientSize=New-Object System.Drawing.Size(980,700); $Form.StartPosition='CenterScreen'; $Form.BackColor=$BG; $Form.ForeColor=$TEXT; $Form.Font=$FBase
try{if(Test-Path $IconPath){$Form.Icon=New-Object System.Drawing.Icon($IconPath)}}catch{}

$ht = New-Object System.Windows.Forms.Label;$ht.Text='DGS Renamer';$ht.Font=$FHead;$ht.ForeColor=$TEXT;$ht.Location=New-Object System.Drawing.Point(24,18);$ht.AutoSize=$true;$Form.Controls.Add($ht)
$hs = New-Object System.Windows.Forms.Label;$hs.Text='Clean duplicate suffixes with preview and undo';$hs.Font=$FSmall;$hs.ForeColor=$MUTED;$hs.Location=New-Object System.Drawing.Point(26,48);$hs.AutoSize=$true;$Form.Controls.Add($hs)

$cp = New-Object System.Windows.Forms.Panel;$cp.BackColor=$CARD;$cp.BorderStyle='FixedSingle';$cp.Location=New-Object System.Drawing.Point(24,86);$cp.Size=New-Object System.Drawing.Size(932,76);$cp.Anchor='Top,Left,Right';$Form.Controls.Add($cp)
$lf = New-Object System.Windows.Forms.Label;$lf.Text='FOLDER';$lf.Font=$FSec;$lf.ForeColor=$MUTED;$lf.Location=New-Object System.Drawing.Point(12,10);$lf.AutoSize=$true;$cp.Controls.Add($lf)
$Txt = New-Object System.Windows.Forms.TextBox;$Txt.Location=New-Object System.Drawing.Point(12,32);$Txt.Size=New-Object System.Drawing.Size(720,24);$Txt.Anchor='Top,Left,Right';$Txt.BackColor=$INPUT;$Txt.ForeColor=$TEXT;$Txt.BorderStyle='FixedSingle';$Txt.Add_KeyDown({param($s,$e)if($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter){$e.SuppressKeyPress=$true;Scan}});$cp.Controls.Add($Txt)
$bb = New-Object System.Windows.Forms.Button;$bb.Text='Browse';$bb.Location=New-Object System.Drawing.Point(740,30);$bb.Size=New-Object System.Drawing.Size(88,28);$bb.Anchor='Top,Right';$bb.Add_Click({$bd=New-Object System.Windows.Forms.FolderBrowserDialog;$bd.ShowNewFolderButton=$false;if(-not [string]::IsNullOrWhiteSpace($Txt.Text) -and (Test-Path -LiteralPath $Txt.Text.Trim())){$bd.SelectedPath=$Txt.Text.Trim()};if($bd.ShowDialog($Form)-eq 'OK' -and $bd.SelectedPath){$Txt.Text=$bd.SelectedPath;Scan};$bd.Dispose()});$cp.Controls.Add($bb)
$bs = New-Object System.Windows.Forms.Button;$bs.Text='Scan';$bs.Location=New-Object System.Drawing.Point(836,30);$bs.Size=New-Object System.Drawing.Size(82,28);$bs.Anchor='Top,Right';$bs.BackColor=$ACCENT;$bs.ForeColor=[System.Drawing.Color]::White;$bs.FlatStyle='Flat';$bs.FlatAppearance.BorderSize=0;$bs.Add_Click({Scan});$cp.Controls.Add($bs)

$co = New-Object System.Windows.Forms.Panel;$co.BackColor=$CARD;$co.BorderStyle='FixedSingle';$co.Location=New-Object System.Drawing.Point(24,174);$co.Size=New-Object System.Drawing.Size(932,76);$co.Anchor='Top,Left,Right';$Form.Controls.Add($co)
$lo = New-Object System.Windows.Forms.Label;$lo.Text='OPTIONS';$lo.Font=$FSec;$lo.ForeColor=$MUTED;$lo.Location=New-Object System.Drawing.Point(12,10);$lo.AutoSize=$true;$co.Controls.Add($lo)
$ChkDup = New-Object System.Windows.Forms.CheckBox;$ChkDup.Text='Remove (1),(2)...';$ChkDup.ForeColor=$TEXT;$ChkDup.Location=New-Object System.Drawing.Point(12,36);$ChkDup.Checked=$true;$co.Controls.Add($ChkDup)
$ChkSp = New-Object System.Windows.Forms.CheckBox;$ChkSp.Text='Clean spacing';$ChkSp.ForeColor=$TEXT;$ChkSp.Location=New-Object System.Drawing.Point(200,36);$ChkSp.Checked=$true;$co.Controls.Add($ChkSp)
$ChkTc = New-Object System.Windows.Forms.CheckBox;$ChkTc.Text='Title Case';$ChkTc.ForeColor=$TEXT;$ChkTc.Location=New-Object System.Drawing.Point(360,36);$co.Controls.Add($ChkTc)
$ChkRec = New-Object System.Windows.Forms.CheckBox;$ChkRec.Text='Subfolders';$ChkRec.ForeColor=$TEXT;$ChkRec.Location=New-Object System.Drawing.Point(500,36);$ChkRec.Checked=$true;$co.Controls.Add($ChkRec)
$ChkCf = New-Object System.Windows.Forms.CheckBox;$ChkCf.Text='Confirm';$ChkCf.ForeColor=$TEXT;$ChkCf.Location=New-Object System.Drawing.Point(640,36);$ChkCf.Checked=$true;$co.Controls.Add($ChkCf)

$cg = New-Object System.Windows.Forms.Panel;$cg.BackColor=$CARD;$cg.BorderStyle='FixedSingle';$cg.Location=New-Object System.Drawing.Point(24,262);$cg.Size=New-Object System.Drawing.Size(932,320);$cg.Anchor='Top,Bottom,Left,Right';$Form.Controls.Add($cg)
$lp = New-Object System.Windows.Forms.Label;$lp.Text='PREVIEW';$lp.Font=$FSec;$lp.ForeColor=$MUTED;$lp.Location=New-Object System.Drawing.Point(12,10);$lp.AutoSize=$true;$cg.Controls.Add($lp)
$Cnt = New-Object System.Windows.Forms.Label;$Cnt.Text='';$Cnt.Font=$FSmall;$Cnt.ForeColor=$MUTED;$Cnt.Location=New-Object System.Drawing.Point(820,12);$Cnt.Anchor='Top,Right';$Cnt.AutoSize=$true;$cg.Controls.Add($Cnt)
$Grid = New-Object System.Windows.Forms.DataGridView;$Grid.Location=New-Object System.Drawing.Point(12,34);$Grid.Size=New-Object System.Drawing.Size(908,274);$Grid.Anchor='Top,Bottom,Left,Right';$Grid.BackgroundColor=$CARD;$Grid.BorderStyle='None';$Grid.RowHeadersVisible=$false;$Grid.AllowUserToAddRows=$false;$Grid.SelectionMode='FullRowSelect';$Grid.EditMode='EditOnEnter';$Grid.AutoSizeColumnsMode='Fill';$Grid.ColumnHeadersHeight=28;$Grid.RowTemplate.Height=24;$Grid.DefaultCellStyle.BackColor=$CARD;$Grid.DefaultCellStyle.ForeColor=$TEXT;$Grid.DefaultCellStyle.SelectionBackColor=[System.Drawing.Color]::FromArgb(30,51,80);$Grid.EnableHeadersVisualStyles=$false;$Grid.ColumnHeadersDefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(27,35,48);$Grid.ColumnHeadersDefaultCellStyle.ForeColor=$MUTED;[void]$Grid.Columns.Add((New-Object System.Windows.Forms.DataGridViewCheckBoxColumn -Property @{HeaderText='';Width=40;AutoSizeMode='None'}));[void]$Grid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{HeaderText='CURRENT';ReadOnly=$true;FillWeight=36}));[void]$Grid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{HeaderText='NEW';ReadOnly=$true;FillWeight=36}));[void]$Grid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{HeaderText='FOLDER';ReadOnly=$true;FillWeight=22}));[void]$Grid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{HeaderText='STATUS';ReadOnly=$true;Width=100;AutoSizeMode='None'}));$Grid.Add_CellValueChanged({param($s,$e)if($e.RowIndex -ge 0 -and $e.ColumnIndex -eq 0){$it=$Grid.Rows[$e.RowIndex].Tag;if($it){if($it.Status -ne 'Ready'){$Grid.Rows[$e.RowIndex].Cells[0].Value=$false;$it.Apply=$false}else{$it.Apply=[bool]$Grid.Rows[$e.RowIndex].Cells[0].Value}}$rd=@($Preview|?{$_.Status -eq 'Ready'}).Count;$Cnt.Text="Changes: $($Preview.Count) | Ready: $rd"}});$cg.Controls.Add($Grid)

$cb = New-Object System.Windows.Forms.Panel;$cb.BackColor=$CARD;$cb.BorderStyle='FixedSingle';$cb.Location=New-Object System.Drawing.Point(24,594);$cb.Size=New-Object System.Drawing.Size(932,66);$cb.Anchor='Bottom,Left,Right';$Form.Controls.Add($cb)
$St = New-Object System.Windows.Forms.Label;$St.Text='Ready';$St.Font=$FSmall;$St.ForeColor=$TEXT;$St.Location=New-Object System.Drawing.Point(12,12);$St.AutoSize=$true;$cb.Controls.Add($St)
$BtnU = New-Object System.Windows.Forms.Button;$BtnU.Text='Undo Last Run';$BtnU.Location=New-Object System.Drawing.Point(620,18);$BtnU.Size=New-Object System.Drawing.Size(110,30);$BtnU.Anchor='Bottom,Right';$BtnU.Enabled=$false;$BtnU.Add_Click({Do-Undo});$cb.Controls.Add($BtnU)
$Be = New-Object System.Windows.Forms.Button;$Be.Text='Export CSV';$Be.Location=New-Object System.Drawing.Point(738,18);$Be.Size=New-Object System.Drawing.Size(92,30);$Be.Anchor='Bottom,Right';$Be.Add_Click({Export-Csv});$cb.Controls.Add($Be)
$Br = New-Object System.Windows.Forms.Button;$Br.Text='Rename Selected';$Br.Location=New-Object System.Drawing.Point(838,18);$Br.Size=New-Object System.Drawing.Size(134,30);$Br.Anchor='Bottom,Right';$Br.BackColor=$ACCENT;$Br.ForeColor=[System.Drawing.Color]::White;$Br.FlatStyle='Flat';$Br.FlatAppearance.BorderSize=0;$Br.Add_Click({Do-Rename});$cb.Controls.Add($Br)

$Form.Add_Resize({$w=$Form.ClientSize.Width;$cp.Width=$w-48;$co.Width=$w-48;$cg.Width=$w-48;$Txt.Width=$cp.Width-12-88-8-82-8;$bb.Location=New-Object System.Drawing.Point($cp.Width-12-88-8-82,30);$bs.Location=New-Object System.Drawing.Point($cp.Width-12-82,30);$Grid.Width=$cg.Width-24;$Grid.Height=$cg.Height-46;$cb.Width=$w-48;$Cnt.Location=New-Object System.Drawing.Point($cg.Width-12-$Cnt.Width,12);$BtnU.Location=New-Object System.Drawing.Point($cb.Width-12-110-8-92-8-134,18);$Be.Location=New-Object System.Drawing.Point($cb.Width-12-92-8-134,18);$Br.Location=New-Object System.Drawing.Point($cb.Width-12-134,18)})

$s=Load-Set;$Txt.Text=$s.Folder;$ChkRec.Checked=$s.Rec;$ChkDup.Checked=$s.Dup;$ChkSp.Checked=$s.Sp;$ChkTc.Checked=$s.Tc;$ChkCf.Checked=$s.Cf;Upd-Undo
$tm=New-Object System.Windows.Forms.Timer;$tm.Interval=400;$tm.Add_Tick({$tm.Stop();if($Txt.Text.Trim()){Scan}})
$opt={$tm.Stop();$tm.Start()};$ChkRec.Add_CheckedChanged($opt);$ChkDup.Add_CheckedChanged($opt);$ChkSp.Add_CheckedChanged($opt);$ChkTc.Add_CheckedChanged($opt);$ChkCf.Add_CheckedChanged({Save-Set})
$Form.Add_Shown({$Form.PerformLayout();$Form.Add_Resize;if($Txt.Text.Trim()){Scan}})
[void][System.Windows.Forms.Application]::Run($Form)
