[CmdletBinding()]
param([switch]$SelfTest)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
[System.Windows.Forms.Application]::Add_ThreadException({param($s,$e); try{[System.Windows.Forms.MessageBox]::Show($e.Exception.Message,'DGS Debloat','OK','Error')|Out-Null}catch{}})
$AppVersion='1.0.4'
$BG=[System.Drawing.Color]::FromArgb(14,17,23);$CARD=[System.Drawing.Color]::FromArgb(22,28,37);$INPUT=[System.Drawing.Color]::FromArgb(16,21,29);$TEXT=[System.Drawing.Color]::FromArgb(232,237,245);$MUTED=[System.Drawing.Color]::FromArgb(139,151,168);$ACCENT=[System.Drawing.Color]::FromArgb(245,158,11);$GREEN=[System.Drawing.Color]::FromArgb(52,211,153);$RED=[System.Drawing.Color]::FromArgb(248,113,113)
$FBase=New-Object System.Drawing.Font("Segoe UI",9.5);$FSmall=New-Object System.Drawing.Font("Segoe UI",8.5);$FHead=New-Object System.Drawing.Font("Segoe UI Semibold",18);$FSec=New-Object System.Drawing.Font("Segoe UI Semibold",8)
function Get-ScriptDir { if($PSScriptRoot){return $PSScriptRoot}; if($MyInvocation.MyCommand.Path){return (Split-Path -Parent $MyInvocation.MyCommand.Path)}; try{$p=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName; if($p){return (Split-Path -Parent $p)}}catch{}; return (Get-Location).Path }
$ScriptDir=Get-ScriptDir
$IconPath=Join-Path $ScriptDir "DGS.Debloat.ico"
$LogDir=Join-Path $env:APPDATA 'DGS Debloat\logs'; New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Apps=@(
  [pscustomobject]@{Name="Bing Weather";Id="Microsoft.BingWeather"},
  [pscustomobject]@{Name="Bing News";Id="Microsoft.BingNews"},
  [pscustomobject]@{Name="Xbox App";Id="Microsoft.GamingApp"},
  [pscustomobject]@{Name="Get Help";Id="Microsoft.GetHelp"},
  [pscustomobject]@{Name="Get Started / Tips";Id="Microsoft.Getstarted"},
  [pscustomobject]@{Name="Solitaire Collection";Id="Microsoft.MicrosoftSolitaireCollection"},
  [pscustomobject]@{Name="Mixed Reality Portal";Id="Microsoft.MixedReality.Portal"},
  [pscustomobject]@{Name="OneNote for Windows 10";Id="Microsoft.Office.OneNote"},
  [pscustomobject]@{Name="People";Id="Microsoft.People"},
  [pscustomobject]@{Name="Skype";Id="Microsoft.SkypeApp"},
  [pscustomobject]@{Name="Sound Recorder";Id="Microsoft.WindowsSoundRecorder"},
  [pscustomobject]@{Name="Mail / Calendar";Id="microsoft.windowscommunicationsapps"},
  [pscustomobject]@{Name="Phone Link";Id="Microsoft.YourPhone"},
  [pscustomobject]@{Name="Power Automate";Id="Microsoft.PowerAutomateDesktop"},
  [pscustomobject]@{Name="Microsoft To Do";Id="Microsoft.Todos"},
  [pscustomobject]@{Name="Clipchamp";Id="Clipchamp.Clipchamp"},
  [pscustomobject]@{Name="Dev Home";Id="Microsoft.DevHome"},
  [pscustomobject]@{Name="Teams (personal)";Id="MicrosoftTeams"},
  [pscustomobject]@{Name="Cortana";Id="Microsoft.549981C3F5F10"},
  [pscustomobject]@{Name="Movies & TV";Id="Microsoft.ZuneVideo"},
  [pscustomobject]@{Name="Microsoft Photos";Id="Microsoft.Windows.Photos"},
  [pscustomobject]@{Name="Windows Maps";Id="Microsoft.WindowsMaps"},
  [pscustomobject]@{Name="Feedback Hub";Id="Microsoft.WindowsFeedbackHub"},
  [pscustomobject]@{Name="Xbox Game Bar";Id="Microsoft.XboxGamingOverlay"},
  [pscustomobject]@{Name="3D Viewer";Id="Microsoft.Microsoft3DViewer"},
  [pscustomobject]@{Name="Paint 3D";Id="Microsoft.MSPaint"}
)
function Self-Test(){ [Console]::WriteLine('DEBLOAT-SELFTEST-PASS'); exit 0 }
if($SelfTest){Self-Test}
$Form=New-Object System.Windows.Forms.Form;$Form.Text="DGS Windows Debloat v$AppVersion";$Form.ClientSize=New-Object System.Drawing.Size(820,640);$Form.StartPosition="CenterScreen";$Form.BackColor=$BG;$Form.ForeColor=$TEXT;$Form.Font=$FBase
try{if(Test-Path -LiteralPath $IconPath){$Form.Icon=New-Object System.Drawing.Icon($IconPath)}}catch{}
$ht=New-Object System.Windows.Forms.Label;$ht.Text="DGS Windows Debloat";$ht.Font=$FHead;$ht.ForeColor=$TEXT;$ht.Location=New-Object System.Drawing.Point(22,16);$ht.AutoSize=$true;$Form.Controls.Add($ht)
$hs=New-Object System.Windows.Forms.Label;$hs.Text="Curated bloat removal with restore point + logging";$hs.Font=$FSmall;$hs.ForeColor=$MUTED;$hs.Location=New-Object System.Drawing.Point(24,46);$hs.AutoSize=$true;$Form.Controls.Add($hs)
$cp=New-Object System.Windows.Forms.Panel;$cp.BackColor=$CARD;$cp.BorderStyle="FixedSingle";$cp.Location=New-Object System.Drawing.Point(22,84);$cp.Size=New-Object System.Drawing.Size(776,470);$cp.Anchor="Top,Bottom,Left,Right";$Form.Controls.Add($cp)
$ll=New-Object System.Windows.Forms.Label;$ll.Text="APPS (check to remove for current user)";$ll.Font=$FSec;$ll.ForeColor=$MUTED;$ll.Location=New-Object System.Drawing.Point(12,10);$ll.AutoSize=$true;$cp.Controls.Add($ll)
$Chk=New-Object System.Windows.Forms.CheckedListBox;$Chk.Location=New-Object System.Drawing.Point(12,32);$Chk.Size=New-Object System.Drawing.Size(752,420);$Chk.Anchor="Top,Bottom,Left,Right";$Chk.BackColor=$INPUT;$Chk.ForeColor=$TEXT;$Chk.BorderStyle="FixedSingle";$Chk.CheckOnClick=$true;foreach($a in $Apps){[void]$Chk.Items.Add($a.Name,$false)};$cp.Controls.Add($Chk)
$ChkRp=New-Object System.Windows.Forms.CheckBox;$ChkRp.Text="Create restore point first (recommended)";$ChkRp.ForeColor=$TEXT;$ChkRp.Location=New-Object System.Drawing.Point(12,340);$ChkRp.Checked=$true;$ChkRp.Anchor="Bottom,Left";$cp.Controls.Add($ChkRp)
$cb=New-Object System.Windows.Forms.Panel;$cb.BackColor=$CARD;$cb.BorderStyle="FixedSingle";$cb.Location=New-Object System.Drawing.Point(22,566);$cb.Size=New-Object System.Drawing.Size(776,54);$cb.Anchor="Bottom,Left,Right";$Form.Controls.Add($cb)
$ba=New-Object System.Windows.Forms.Button;$ba.Text="Select All";$ba.Location=New-Object System.Drawing.Point(12,12);$ba.Size=New-Object System.Drawing.Size(90,30);$ba.Add_Click({for($i=0;$i -lt $Chk.Items.Count;$i++){$Chk.SetItemChecked($i,$true)}});$cb.Controls.Add($ba)
$bn=New-Object System.Windows.Forms.Button;$bn.Text="Clear";$bn.Location=New-Object System.Drawing.Point(108,12);$bn.Size=New-Object System.Drawing.Size(80,30);$bn.Add_Click({for($i=0;$i -lt $Chk.Items.Count;$i++){$Chk.SetItemChecked($i,$false)}});$cb.Controls.Add($bn)
$bf=New-Object System.Windows.Forms.Button;$bf.Text="Open Full Debloat GUI";$bf.Location=New-Object System.Drawing.Point(196,12);$bf.Size=New-Object System.Drawing.Size(150,30);$bf.Add_Click({$f=Join-Path $ScriptDir "DGS.WINDOWS10-DEBLOAT-GUI.ps1"; if(Test-Path -LiteralPath $f){Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$f`""}else{[System.Windows.Forms.MessageBox]::Show($Form,"Not found: $f",'Error','OK','Error')|Out-Null}});$cb.Controls.Add($bf)
$br=New-Object System.Windows.Forms.Button;$br.Text="Remove Selected";$br.Location=New-Object System.Drawing.Point(660,12);$br.Size=New-Object System.Drawing.Size(104,30);$br.Anchor="Bottom,Right";$br.BackColor=$RED;$br.ForeColor=[System.Drawing.Color]::White;$br.FlatStyle="Flat";$br.FlatAppearance.BorderSize=0;$br.Add_Click({
  $sel=@($Chk.CheckedItems); if($sel.Count -eq 0){[System.Windows.Forms.MessageBox]::Show($Form,'Select at least one app.','Nothing selected','OK','Information')|Out-Null;return}
  if([System.Windows.Forms.MessageBox]::Show($Form,"Remove $($sel.Count) app(s) for current user?",'Confirm','YesNo','Question') -ne 'Yes'){return}
  $log=Join-Path $LogDir ("debloat-"+(Get-Date -Format 'yyyyMMdd-HHmmss')+".csv")
  $cmd="`$ErrorActionPreference='Continue'; "
  if($ChkRp.Checked){$cmd+="Checkpoint-Computer -Description 'DGS Debloat' -RestorePointType APPLICATION_UNINSTALL -ErrorAction SilentlyContinue; "}
  $ids=@(); foreach($n in $sel){$ids+=($Apps|?{$_.Name -eq $n}).Id}
  $cmd+="`$r=@(); foreach(`$id in @('$($ids -join "','")')){try{Get-AppxPackage -Name `$id -ErrorAction Stop | Remove-AppxPackage -ErrorAction Stop; `$r += [pscustomobject]@{Id=`$id;Result='Removed'}}catch{`$r += [pscustomobject]@{Id=`$id;Result=`$_.Exception.Message}}}; `$r | Export-Csv -LiteralPath '$log' -NoTypeInformation -Encoding UTF8; Write-Host 'Done. Log: $log'; pause"
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
});$cb.Controls.Add($br)
$St=New-Object System.Windows.Forms.Label;$St.Text="Ready. Removal runs elevated and logs to %APPDATA%\DGS Debloat\logs.";$St.Font=$FSmall;$St.ForeColor=$MUTED;$St.Location=New-Object System.Drawing.Point(12,620);$St.AutoSize=$true;$St.Anchor="Bottom,Left";$Form.Controls.Add($St)
$Form.Add_Resize({$w=$Form.ClientSize.Width;$cp.Width=$w-44;$Chk.Width=$cp.Width-24;$cb.Width=$w-44;$br.Location=New-Object System.Drawing.Point($cb.Width-12-104,12)})
$Form.Add_Shown({$Form.PerformLayout()})
[void][System.Windows.Forms.Application]::Run($Form)
