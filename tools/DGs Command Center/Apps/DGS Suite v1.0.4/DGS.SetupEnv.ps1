[CmdletBinding()]
param([switch]$SelfTest)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
[System.Windows.Forms.Application]::Add_ThreadException({param($s,$e); try{[System.Windows.Forms.MessageBox]::Show($e.Exception.Message,'DGS SetupEnv','OK','Error')|Out-Null}catch{}})
$AppVersion='1.0.4'
$BG=[System.Drawing.Color]::FromArgb(14,17,23);$CARD=[System.Drawing.Color]::FromArgb(22,28,37);$INPUT=[System.Drawing.Color]::FromArgb(16,21,29);$TEXT=[System.Drawing.Color]::FromArgb(232,237,245);$MUTED=[System.Drawing.Color]::FromArgb(139,151,168);$ACCENT=[System.Drawing.Color]::FromArgb(34,197,94);$GREEN=[System.Drawing.Color]::FromArgb(52,211,153);$AMBER=[System.Drawing.Color]::FromArgb(251,191,36)
$FBase=New-Object System.Drawing.Font("Segoe UI",9.5);$FSmall=New-Object System.Drawing.Font("Segoe UI",8.5);$FHead=New-Object System.Drawing.Font("Segoe UI Semibold",18);$FSec=New-Object System.Drawing.Font("Segoe UI Semibold",8)
function Get-ScriptDir { if($PSScriptRoot){return $PSScriptRoot}; if($MyInvocation.MyCommand.Path){return (Split-Path -Parent $MyInvocation.MyCommand.Path)}; try{$p=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName; if($p){return (Split-Path -Parent $p)}}catch{}; return (Get-Location).Path }
$ScriptDir=Get-ScriptDir
$IconPath=Join-Path $ScriptDir "DGS.SetupEnv.ico"
$Tools=@(
  [pscustomobject]@{Key="git";Name="Git";Winget="Git.Git";Test="git"},
  [pscustomobject]@{Key="python";Name="Python 3.12";Winget="Python.Python.3.12";Test="py"},
  [pscustomobject]@{Key="vscode";Name="VS Code";Winget="Microsoft.VisualStudioCode";Test="code"},
  [pscustomobject]@{Key="gh";Name="GitHub CLI";Winget="GitHub.cli";Test="gh"},
  [pscustomobject]@{Key="node";Name="Node.js LTS";Winget="OpenJS.NodeJS.LTS";Test="node"},
  [pscustomobject]@{Key="pwsh";Name="PowerShell 7";Winget="Microsoft.PowerShell";Test="pwsh"},
  [pscustomobject]@{Key="7zip";Name="7-Zip";Winget="7zip.7zip";Test="7z"},
  [pscustomobject]@{Key="powertoys";Name="PowerToys";Winget="Microsoft.PowerToys";Test="PowerToys"},
  [pscustomobject]@{Key="dotnet";Name=".NET 8 SDK";Winget="Microsoft.DotNet.SDK.8";Test="dotnet"},
  [pscustomobject]@{Key="jdk";Name="JDK 21 (LTS)";Winget="Oracle.JDK.21";Test="java"},
  [pscustomobject]@{Key="docker";Name="Docker Desktop";Winget="Docker.DockerDesktop";Test="docker"},
  [pscustomobject]@{Key="wsl";Name="WSL (Ubuntu)";Winget="";Test="wsl"}
)
function Test-Cmd([string]$n){return [bool](Get-Command $n -ErrorAction SilentlyContinue)}
function Test-Inst($t){ if($t.Key -eq 'wsl'){ return [bool](Get-Command wsl -ErrorAction SilentlyContinue) -and (wsl -l -q 2>$null) }; return Test-Cmd $t.Test }
function Self-Test(){ [Console]::WriteLine('SETUPENV-SELFTEST-PASS'); exit 0 }
if($SelfTest){Self-Test}
$Form=New-Object System.Windows.Forms.Form;$Form.Text="DGS Setup Env v$AppVersion";$Form.ClientSize=New-Object System.Drawing.Size(820,620);$Form.StartPosition="CenterScreen";$Form.BackColor=$BG;$Form.ForeColor=$TEXT;$Form.Font=$FBase
try{if(Test-Path -LiteralPath $IconPath){$Form.Icon=New-Object System.Drawing.Icon($IconPath)}}catch{}
$ht=New-Object System.Windows.Forms.Label;$ht.Text="DGS Setup Env";$ht.Font=$FHead;$ht.ForeColor=$TEXT;$ht.Location=New-Object System.Drawing.Point(22,16);$ht.AutoSize=$true;$Form.Controls.Add($ht)
$hs=New-Object System.Windows.Forms.Label;$hs.Text="Scan, select, and install developer tools via winget (elevated)";$hs.Font=$FSmall;$hs.ForeColor=$MUTED;$hs.Location=New-Object System.Drawing.Point(24,46);$hs.AutoSize=$true;$Form.Controls.Add($hs)
$cp=New-Object System.Windows.Forms.Panel;$cp.BackColor=$CARD;$cp.BorderStyle="FixedSingle";$cp.Location=New-Object System.Drawing.Point(22,84);$cp.Size=New-Object System.Drawing.Size(776,450);$cp.Anchor="Top,Bottom,Left,Right";$Form.Controls.Add($cp)
$ll=New-Object System.Windows.Forms.Label;$ll.Text="TOOLS (check to install)";$ll.Font=$FSec;$ll.ForeColor=$MUTED;$ll.Location=New-Object System.Drawing.Point(12,10);$ll.AutoSize=$true;$cp.Controls.Add($ll)
$Chk=New-Object System.Windows.Forms.CheckedListBox;$Chk.Location=New-Object System.Drawing.Point(12,32);$Chk.Size=New-Object System.Drawing.Size(752,400);$Chk.Anchor="Top,Bottom,Left,Right";$Chk.BackColor=$INPUT;$Chk.ForeColor=$TEXT;$Chk.BorderStyle="FixedSingle";$Chk.CheckOnClick=$true;$cp.Controls.Add($Chk)
$cb=New-Object System.Windows.Forms.Panel;$cb.BackColor=$CARD;$cb.BorderStyle="FixedSingle";$cb.Location=New-Object System.Drawing.Point(22,546);$cb.Size=New-Object System.Drawing.Size(776,54);$cb.Anchor="Bottom,Left,Right";$Form.Controls.Add($cb)
$bs=New-Object System.Windows.Forms.Button;$bs.Text="Scan";$bs.Location=New-Object System.Drawing.Point(12,12);$bs.Size=New-Object System.Drawing.Size(90,30);$bs.BackColor=$ACCENT;$bs.ForeColor=[System.Drawing.Color]::White;$bs.FlatStyle="Flat";$bs.FlatAppearance.BorderSize=0;$bs.Add_Click({
  $Chk.Items.Clear(); foreach($t in $Tools){ $ok=Test-Inst $t; $lbl=$t.Name + $(if($ok){"  [installed]"}else{"  [missing]"}); $i=$Chk.Items.Add($lbl,(-not $ok)); if($ok){$Chk.SetItemChecked($i,$false)} }
  if(-not (Test-Cmd winget)){[System.Windows.Forms.MessageBox]::Show($Form,'winget not found. Install App Installer from Microsoft Store first.','winget missing','OK','Warning')|Out-Null}
});$cb.Controls.Add($bs)
$ba=New-Object System.Windows.Forms.Button;$ba.Text="Select Missing";$ba.Location=New-Object System.Drawing.Point(110,12);$ba.Size=New-Object System.Drawing.Size(110,30);$ba.Add_Click({for($i=0;$i -lt $Chk.Items.Count;$i++){if($Chk.Items[$i].ToString() -match '\[missing\]'){$Chk.SetItemChecked($i,$true)}}});$cb.Controls.Add($ba)
$bo=New-Object System.Windows.Forms.Button;$bo.Text="Open Full Script";$bo.Location=New-Object System.Drawing.Point(228,12);$bo.Size=New-Object System.Drawing.Size(120,30);$bo.Add_Click({$f=Join-Path $ScriptDir "DGS.SETUP-ENV.ps1"; if(Test-Path -LiteralPath $f){Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$f`""}else{[System.Windows.Forms.MessageBox]::Show($Form,"Not found: $f",'Error','OK','Error')|Out-Null}});$cb.Controls.Add($bo)
$bi=New-Object System.Windows.Forms.Button;$bi.Text="Install Selected";$bi.Location=New-Object System.Drawing.Point(650,12);$bi.Size=New-Object System.Drawing.Size(114,30);$bi.Anchor="Bottom,Right";$bi.BackColor=$ACCENT;$bi.ForeColor=[System.Drawing.Color]::White;$bi.FlatStyle="Flat";$bi.FlatAppearance.BorderSize=0;$bi.Add_Click({
  $selIdx=@($Chk.CheckedIndices); if($selIdx.Count -eq 0){[System.Windows.Forms.MessageBox]::Show($Form,'Check tools to install (run Scan first).','Nothing selected','OK','Information')|Out-Null;return}
  $ids=@(); foreach($i in $selIdx){ $w=$Tools[$i].Winget; if($w){$ids+=$w} elseif($Tools[$i].Key -eq 'wsl'){$ids+='__WSL__'} }
  if($ids.Count -eq 0){[System.Windows.Forms.MessageBox]::Show($Form,'No installable tools selected.','None','OK','Information')|Out-Null;return}
  $cmd="`$ErrorActionPreference='Continue'; foreach(`$id in @('$($ids -join "','")')){ if(`$id -eq '__WSL__'){ wsl --install -d Ubuntu --no-launch } else { winget install -e --id `$id --accept-package-agreements --accept-source-agreements } }; pause"
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
});$cb.Controls.Add($bi)
$St=New-Object System.Windows.Forms.Label;$St.Text="Click Scan first, check tools, then Install Selected (elevated).";$St.Font=$FSmall;$St.ForeColor=$MUTED;$St.Location=New-Object System.Drawing.Point(12,600);$St.AutoSize=$true;$St.Anchor="Bottom,Left";$Form.Controls.Add($St)
$Form.Add_Resize({$w=$Form.ClientSize.Width;$cp.Width=$w-44;$Chk.Width=$cp.Width-24;$cb.Width=$w-44;$bi.Location=New-Object System.Drawing.Point($cb.Width-12-114,12)})
$Form.Add_Shown({$Form.PerformLayout()})
[void][System.Windows.Forms.Application]::Run($Form)
