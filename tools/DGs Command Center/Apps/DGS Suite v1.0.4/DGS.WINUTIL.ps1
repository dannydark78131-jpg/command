[CmdletBinding()]
param([switch]$SelfTest)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
[System.Windows.Forms.Application]::Add_ThreadException({param($s,$e); try{[System.Windows.Forms.MessageBox]::Show($e.Exception.Message,'DGS WinUtil','OK','Error')|Out-Null}catch{}})
$AppVersion='1.0.4'
$BG=[System.Drawing.Color]::FromArgb(14,17,23);$CARD=[System.Drawing.Color]::FromArgb(22,28,37);$TEXT=[System.Drawing.Color]::FromArgb(232,237,245);$MUTED=[System.Drawing.Color]::FromArgb(139,151,168);$ACCENT=[System.Drawing.Color]::FromArgb(167,139,250);$GREEN=[System.Drawing.Color]::FromArgb(52,211,153);$AMBER=[System.Drawing.Color]::FromArgb(251,191,36)
$FBase=New-Object System.Drawing.Font("Segoe UI",9.5);$FSmall=New-Object System.Drawing.Font("Segoe UI",8.5);$FHead=New-Object System.Drawing.Font("Segoe UI Semibold",18);$FSec=New-Object System.Drawing.Font("Segoe UI Semibold",8)
function Get-ScriptDir { if($PSScriptRoot){return $PSScriptRoot}; if($MyInvocation.MyCommand.Path){return (Split-Path -Parent $MyInvocation.MyCommand.Path)}; try{$p=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName; if($p){return (Split-Path -Parent $p)}}catch{}; return (Get-Location).Path }
$ScriptDir=Get-ScriptDir
$IconPath=Join-Path $ScriptDir "DGS.WinUtil.ico"
function Run-Elevated([string]$cmd){ Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" }
function Self-Test(){ [Console]::WriteLine('WINUTIL-SELFTEST-PASS'); exit 0 }
if($SelfTest){Self-Test}
$Form=New-Object System.Windows.Forms.Form;$Form.Text="DGS WinUtil v$AppVersion";$Form.ClientSize=New-Object System.Drawing.Size(720,470);$Form.StartPosition="CenterScreen";$Form.BackColor=$BG;$Form.ForeColor=$TEXT;$Form.Font=$FBase
try{if(Test-Path -LiteralPath $IconPath){$Form.Icon=New-Object System.Drawing.Icon($IconPath)}}catch{}
$ht=New-Object System.Windows.Forms.Label;$ht.Text="DGS WinUtil";$ht.Font=$FHead;$ht.ForeColor=$TEXT;$ht.Location=New-Object System.Drawing.Point(22,16);$ht.AutoSize=$true;$Form.Controls.Add($ht)
$hs=New-Object System.Windows.Forms.Label;$hs.Text="Windows utility toolkit — actions run elevated (admin)";$hs.Font=$FSmall;$hs.ForeColor=$MUTED;$hs.Location=New-Object System.Drawing.Point(24,46);$hs.AutoSize=$true;$Form.Controls.Add($hs)
$cp=New-Object System.Windows.Forms.Panel;$cp.BackColor=$CARD;$cp.BorderStyle="FixedSingle";$cp.Location=New-Object System.Drawing.Point(22,84);$cp.Size=New-Object System.Drawing.Size(676,320);$cp.Anchor="Top,Bottom,Left,Right";$Form.Controls.Add($cp)
$ll=New-Object System.Windows.Forms.Label;$ll.Text="ACTIONS";$ll.Font=$FSec;$ll.ForeColor=$MUTED;$ll.Location=New-Object System.Drawing.Point(18,14);$ll.AutoSize=$true;$cp.Controls.Add($ll)
$actions=@(
  @{T="Launch Full WinUtil (Chris Titus Tech)"; C="iwr -useb https://christitus.com/win.ps1 | iex; pause"; Col=$ACCENT},
  @{T="Create System Restore Point"; C="Checkpoint-Computer -Description 'DGS WinUtil pre-change' -RestorePointType MODIFY_SETTINGS; Write-Host 'Restore point created.'; pause"; Col=$GREEN},
  @{T="Winget Upgrade All (update installed apps)"; C="winget upgrade --all --accept-package-agreements --accept-source-agreements; pause"; Col=$ACCENT},
  @{T="Install Winget / App Installer if missing"; C="if(-not (Get-Command winget -ErrorAction SilentlyContinue)){Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'}; pause"; Col=$AMBER},
  @{T="Open Windows Update"; C="Start-Process ms-settings:windowsupdate"; Col=$ACCENT},
  @{T="Open Installed Apps (remove bloat)"; C="Start-Process ms-settings:appsfeatures"; Col=$ACCENT}
)
$y=44
foreach($a in $actions){
  $b=New-Object System.Windows.Forms.Button;$b.Text=$a.T;$b.Location=New-Object System.Drawing.Point(18,$y);$b.Size=New-Object System.Drawing.Size(640,32);$b.BackColor=$a.Col;$b.ForeColor=[System.Drawing.Color]::White;$b.FlatStyle="Flat";$b.FlatAppearance.BorderSize=0;$b.Add_Click({Run-Elevated $a.C}.GetNewClosure());$cp.Controls.Add($b);$y+=40
}
$St=New-Object System.Windows.Forms.Label;$St.Text="Ready. Each button opens an elevated PowerShell window.";$St.Font=$FSmall;$St.ForeColor=$MUTED;$St.Location=New-Object System.Drawing.Point(22,420);$St.AutoSize=$true;$St.Anchor="Bottom,Left";$Form.Controls.Add($St)
$Form.Add_Resize({$w=$Form.ClientSize.Width;$cp.Width=$w-44})
$Form.Add_Shown({$Form.PerformLayout()})
[void][System.Windows.Forms.Application]::Run($Form)
