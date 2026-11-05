[CmdletBinding()]
param([switch]$SelfTest)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
$BG=[System.Drawing.Color]::FromArgb(14,17,23);$CARD=[System.Drawing.Color]::FromArgb(22,28,37);$INPUT=[System.Drawing.Color]::FromArgb(16,21,29);$BORDER=[System.Drawing.Color]::FromArgb(42,52,66);$TEXT=[System.Drawing.Color]::FromArgb(232,237,245);$MUTED=[System.Drawing.Color]::FromArgb(139,151,168);$ACCENT=[System.Drawing.Color]::FromArgb(34,211,238)
$FBase=New-Object System.Drawing.Font("Segoe UI",9.5);$FSemi=New-Object System.Drawing.Font("Segoe UI Semibold",9.5);$FSmall=New-Object System.Drawing.Font("Segoe UI",8.5);$FHead=New-Object System.Drawing.Font("Segoe UI Semibold",18);$FSec=New-Object System.Drawing.Font("Segoe UI Semibold",8)
function Get-ScriptDir { if($PSScriptRoot){return $PSScriptRoot}; if($MyInvocation.MyCommand.Path){return (Split-Path -Parent $MyInvocation.MyCommand.Path)}; try{$p=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName; if($p){return (Split-Path -Parent $p)}}catch{}; return (Get-Location).Path }; $ScriptDir = Get-ScriptDir
$IconPath=Join-Path $ScriptDir "DGS.LightTheme.ico"
function Get-Light([string]$h){
  $hx=$h.TrimStart("#"); if($hx.Length -eq 3){$hx=$hx[0]+$hx[0]+$hx[1]+$hx[1]+$hx[2]+$hx[2]}; if($hx.Length -ne 6){return $h}
  $map=@{"0F172A"="F8FAFC";"1E293B"="F1F5F9";"111827"="F9FAFB";"1F2937"="F3F4F6";"1E1E1E"="F3F3F3";"252526"="FFFFFF";"0D1117"="FFFFFF";"161B22"="F6F8FA";"21262D"="EAEEF2";"FFFFFF"="0F172A";"000000"="FFFFFF"}
  $m=$map[$hx.ToUpper()]; if($m){return "#"+$m}
  try{$r=[Convert]::ToInt32($hx.Substring(0,2),16);$g=[Convert]::ToInt32($hx.Substring(2,2),16);$b=[Convert]::ToInt32($hx.Substring(4,2),16);$nr=255-$r;$ng=255-$g;$nb=255-$b;return ("#{0:X2}{1:X2}{2:X2}" -f $nr,$ng,$nb)}catch{return $h}
}
function Conv-Text([string]$t){$rx=[regex]"#[0-9A-Fa-f]{6}\b";return $rx.Replace($t,{param($m)Get-Light $m.Value})}
function Conv-File([string]$src,[string]$dst){$txt=Get-Content -LiteralPath $src -Raw -Encoding UTF8;$out=Conv-Text $txt;Set-Content -LiteralPath $dst -Value $out -Encoding UTF8}
function Self-Test(){
  $root=Join-Path $env:TEMP ('DLT_'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $root -Force|Out-Null
  try{$p=Join-Path $root 't.ps1'; '$bg="#0F172A";$fg="#FFFFFF"'|Set-Content -Path $p -Encoding UTF8; $out=Join-Path $root 't.light.ps1'; Conv-File $p $out; $c=Get-Content -Raw $out; if($c -notmatch 'F8FAFC'){throw 'bad'}}finally{try{Remove-Item $root -Recurse -Force}catch{}}
  [Console]::WriteLine('LIGHTTHEME-SELFTEST-PASS'); exit 0
}
if($SelfTest){Self-Test}
$Form=New-Object System.Windows.Forms.Form;$Form.Text="DGS Light Theme Converter";$Form.ClientSize=New-Object System.Drawing.Size(860,520);$Form.StartPosition="CenterScreen";$Form.BackColor=$BG;$Form.ForeColor=$TEXT;$Form.Font=$FBase
try{if(Test-Path $IconPath){$Form.Icon=New-Object System.Drawing.Icon($IconPath)}}catch{}
$ht=New-Object System.Windows.Forms.Label;$ht.Text="DGS Light Theme Converter";$ht.Font=$FHead;$ht.ForeColor=$TEXT;$ht.Location=New-Object System.Drawing.Point(22,16);$ht.AutoSize=$true;$Form.Controls.Add($ht)
$hs=New-Object System.Windows.Forms.Label;$hs.Text="Convert dark hex colors to light equivalents";$hs.Font=$FSmall;$hs.ForeColor=$MUTED;$hs.Location=New-Object System.Drawing.Point(24,46);$hs.AutoSize=$true;$Form.Controls.Add($hs)
$cp=New-Object System.Windows.Forms.Panel;$cp.BackColor=$CARD;$cp.BorderStyle="FixedSingle";$cp.Location=New-Object System.Drawing.Point(22,84);$cp.Size=New-Object System.Drawing.Size(816,90);$cp.Anchor="Top,Left,Right";$Form.Controls.Add($cp)
$lf=New-Object System.Windows.Forms.Label;$lf.Text="SOURCE FILE";$lf.Font=$FSec;$lf.ForeColor=$MUTED;$lf.Location=New-Object System.Drawing.Point(12,10);$lf.AutoSize=$true;$cp.Controls.Add($lf)
$Src=New-Object System.Windows.Forms.TextBox;$Src.Location=New-Object System.Drawing.Point(12,32);$Src.Size=New-Object System.Drawing.Size(620,24);$Src.Anchor="Top,Left,Right";$Src.BackColor=$INPUT;$Src.ForeColor=$TEXT;$Src.BorderStyle="FixedSingle";$cp.Controls.Add($Src)
$bs=New-Object System.Windows.Forms.Button;$bs.Text="Browse...";$bs.Location=New-Object System.Drawing.Point(642,30);$bs.Size=New-Object System.Drawing.Size(86,28);$bs.Anchor="Top,Right";$bs.Add_Click({$d=New-Object System.Windows.Forms.OpenFileDialog;$d.Filter="PowerShell (*.ps1)|*.ps1|All (*.*)|*.*";if($d.ShowDialog()-eq "OK"){$Src.Text=$d.FileName};$d.Dispose()});$cp.Controls.Add($bs)
$bc=New-Object System.Windows.Forms.Button;$bc.Text="Convert";$bc.Location=New-Object System.Drawing.Point(738,30);$bc.Size=New-Object System.Drawing.Size(66,28);$bc.Anchor="Top,Right";$bc.BackColor=$ACCENT;$bc.ForeColor=[System.Drawing.Color]::White;$bc.FlatStyle="Flat";$bc.FlatAppearance.BorderSize=0;$bc.Add_Click({if(-not(Test-Path $Src.Text)){[System.Windows.Forms.MessageBox]::Show($Form,"Pick a file.","Error","OK","Error")|Out-Null;return};$dst=[IO.Path]::Combine([IO.Path]::GetDirectoryName($Src.Text),([IO.Path]::GetFileNameWithoutExtension($Src.Text)+".light"+[IO.Path]::GetExtension($Src.Text)));Conv-File $Src.Text $dst;[System.Windows.Forms.MessageBox]::Show($Form,"Wrote:`r`n"+$dst,"Done","OK","Information")|Out-Null});$cp.Controls.Add($bc)
$lp=New-Object System.Windows.Forms.Panel;$lp.BackColor=$CARD;$lp.BorderStyle="FixedSingle";$lp.Location=New-Object System.Drawing.Point(22,190);$lp.Size=New-Object System.Drawing.Size(816,280);$lp.Anchor="Top,Bottom,Left,Right";$Form.Controls.Add($lp)
$ll=New-Object System.Windows.Forms.Label;$ll.Text="OUTPUT";$ll.Font=$FSec;$ll.ForeColor=$MUTED;$ll.Location=New-Object System.Drawing.Point(12,10);$ll.AutoSize=$true;$lp.Controls.Add($ll)
$Out=New-Object System.Windows.Forms.RichTextBox;$Out.Location=New-Object System.Drawing.Point(12,32);$Out.Size=New-Object System.Drawing.Size(792,236);$Out.Anchor="Top,Bottom,Left,Right";$Out.ReadOnly=$true;$Out.BackColor=$INPUT;$Out.ForeColor=$TEXT;$Out.Font=New-Object System.Drawing.Font("Consolas",9);$Out.Text="Select a .ps1 and click Convert. Creates a .light copy.";$lp.Controls.Add($Out)
$Form.Add_Resize({$w=$Form.ClientSize.Width;$cp.Width=$w-44;$Src.Width=$cp.Width-12-86-8-66-8;$bs.Location=New-Object System.Drawing.Point($cp.Width-12-86-8-66,30);$bc.Location=New-Object System.Drawing.Point($cp.Width-12-66,30);$lp.Width=$w-44;$lp.Height=$Form.ClientSize.Height-226;$Out.Width=$lp.Width-24;$Out.Height=$lp.Height-56})
$Form.Add_Shown({$Form.PerformLayout()})
[void][System.Windows.Forms.Application]::Run($Form)
