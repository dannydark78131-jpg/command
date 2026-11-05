<#
DG Toolkit - Combined Application
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
public class IconExtractor {
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    private static extern int ExtractIconEx(string file, int index, IntPtr[] large, IntPtr[] small, int count);
    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr h);
    public static Bitmap GetIcon(string path, int index) {
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
public class IconWriter {
    public static bool SaveIcon(Bitmap bitmap, string path) {
        try {
            Bitmap bmp = new Bitmap(256, 256, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(bmp)) {
                g.Clear(Color.Transparent);
                g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
                g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                g.DrawImage(bitmap, 0, 0, 256, 256);
            }
            using (MemoryStream ms = new MemoryStream()) {
                bmp.Save(ms, ImageFormat.Png);
                byte[] pngData = ms.ToArray();
                using (FileStream fs = new FileStream(path, FileMode.Create))
                using (BinaryWriter bw = new BinaryWriter(fs)) {
                    bw.Write((short)0); bw.Write((short)1); bw.Write((short)1);
                    bw.Write((byte)0); bw.Write((byte)0); bw.Write((byte)0); bw.Write((byte)0);
                    bw.Write((short)1); bw.Write((short)32);
                    bw.Write(pngData.Length); bw.Write(22);
                    bw.Write(pngData);
                }
            }
            bmp.Dispose();
            return true;
        } catch { return false; }
    }
}
"@ -ReferencedAssemblies System.Drawing,System.IO

$form = New-Object System.Windows.Forms.Form
$form.Text = "DGs Image Tools v1.0.3"
$form.Size = New-Object System.Drawing.Size(700,550)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(10,22,32)
$form.ForeColor = [System.Drawing.Color]::White

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "DGs IMAGE TOOLS"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(102,224,255)
$lblTitle.Location = New-Object System.Drawing.Point(20,20)
$lblTitle.Size = New-Object System.Drawing.Size(660,40)
$lblTitle.TextAlign = "MiddleCenter"
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Image to ICO â€¢ Icon Recolor â€¢ Color Variant Generator"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI",9)
$lblSub.ForeColor = [System.Drawing.Color]::LightGray
$lblSub.Location = New-Object System.Drawing.Point(20,60)
$lblSub.Size = New-Object System.Drawing.Size(660,20)
$lblSub.TextAlign = "MiddleCenter"
$form.Controls.Add($lblSub)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(20,100)
$tabs.Size = New-Object System.Drawing.Size(640,350)
$tabs.Font = New-Object System.Drawing.Font("Segoe UI",9)
$form.Controls.Add($tabs)

# Tab 1
$t1 = New-Object System.Windows.Forms.TabPage
$t1.Text = "Image to ICO"
$t1.BackColor = [System.Drawing.Color]::FromArgb(26,47,63)
$tabs.Controls.Add($t1)

$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = "Target Folder:"
$lbl1.Location = New-Object System.Drawing.Point(20,20)
$lbl1.Size = New-Object System.Drawing.Size(100,20)
$lbl1.ForeColor = [System.Drawing.Color]::White
$t1.Controls.Add($lbl1)

$txt1 = New-Object System.Windows.Forms.TextBox
$txt1.Location = New-Object System.Drawing.Point(20,45)
$txt1.Size = New-Object System.Drawing.Size(480,20)
$t1.Controls.Add($txt1)

$btn1b = New-Object System.Windows.Forms.Button
$btn1b.Text = "Browse"
$btn1b.Location = New-Object System.Drawing.Point(520,43)
$btn1b.Size = New-Object System.Drawing.Size(90,25)
$btn1b.BackColor = [System.Drawing.Color]::FromArgb(102,224,255)
$btn1b.ForeColor = [System.Drawing.Color]::Black
$t1.Controls.Add($btn1b)
$btn1b.Add_Click({ $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq "OK"){ $txt1.Text=$d.SelectedPath } })

$chk1a = New-Object System.Windows.Forms.CheckBox
$chk1a.Text = "Include .PNG"
$chk1a.Checked = $true
$chk1a.Location = New-Object System.Drawing.Point(25,90)
$chk1a.Size = New-Object System.Drawing.Size(120,20)
$chk1a.ForeColor = [System.Drawing.Color]::White
$t1.Controls.Add($chk1a)

$chk1b = New-Object System.Windows.Forms.CheckBox
$chk1b.Text = "Include .JPG/.JPEG"
$chk1b.Checked = $true
$chk1b.Location = New-Object System.Drawing.Point(150,90)
$chk1b.Size = New-Object System.Drawing.Size(150,20)
$chk1b.ForeColor = [System.Drawing.Color]::White
$t1.Controls.Add($chk1b)

$chk1c = New-Object System.Windows.Forms.CheckBox
$chk1c.Text = "Search subfolders"
$chk1c.Location = New-Object System.Drawing.Point(320,90)
$chk1c.Size = New-Object System.Drawing.Size(150,20)
$chk1c.ForeColor = [System.Drawing.Color]::White
$t1.Controls.Add($chk1c)

$chk1d = New-Object System.Windows.Forms.CheckBox
$chk1d.Text = "Delete originals after conversion"
$chk1d.Location = New-Object System.Drawing.Point(25,115)
$chk1d.Size = New-Object System.Drawing.Size(250,20)
$chk1d.ForeColor = [System.Drawing.Color]::White
$t1.Controls.Add($chk1d)

$log1 = New-Object System.Windows.Forms.TextBox
$log1.Multiline = $true
$log1.ReadOnly = $true
$log1.ScrollBars = "Vertical"
$log1.Location = New-Object System.Drawing.Point(20,150)
$log1.Size = New-Object System.Drawing.Size(590,90)
$log1.BackColor = [System.Drawing.Color]::FromArgb(15,30,45)
$log1.ForeColor = [System.Drawing.Color]::LightGreen
$log1.Text = "Ready."
$t1.Controls.Add($log1)

$btn1go = New-Object System.Windows.Forms.Button
$btn1go.Text = "CONVERT TO ICO"
$btn1go.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$btn1go.Location = New-Object System.Drawing.Point(20,260)
$btn1go.Size = New-Object System.Drawing.Size(590,40)
$btn1go.BackColor = [System.Drawing.Color]::FromArgb(0,170,136)
$btn1go.ForeColor = [System.Drawing.Color]::White
$t1.Controls.Add($btn1go)

$btn1go.Add_Click({
    $p = $txt1.Text.Trim().Trim('"').Trim("'")
    if(-not (Test-Path $p -PathType Container)){ [System.Windows.Forms.MessageBox]::Show("Select valid folder","Error","OK","Error"); return }
    $filt=@(); if($chk1a.Checked){$filt+="*.png"}; if($chk1b.Checked){$filt+="*.jpg";$filt+="*.jpeg"}
    if($filt.Count -eq 0){[System.Windows.Forms.MessageBox]::Show("Select file type","Warning","OK","Warning"); return}
    $files=@(); foreach($x in $filt){ if($chk1c.Checked){$files+=Get-ChildItem $p -Filter $x -Recurse -File}else{$files+=Get-ChildItem $p -Filter $x -File}}
    if($files.Count -eq 0){$log1.Text="No files found."; return}
    $log1.Text="Processing $($files.Count) files...`r`n"; $t1.Refresh()
    $s=0;$fl=0; foreach($file in $files){ try{ $out=[IO.Path]::ChangeExtension($file.FullName,".ico"); $bmp=[Drawing.Bitmap]::FromFile($file.FullName); if([IconWriter]::SaveIcon($bmp,$out)){ $s++; if($chk1d.Checked){Remove-Item $file.FullName -Force} }else{$fl++}; $bmp.Dispose()}catch{$fl++} }
    $log1.Text="Done! Converted:$s Failed:$fl"; [System.Windows.Forms.MessageBox]::Show("Converted $s files","Done","OK","Information")
})

# Tab 2
$t2 = New-Object System.Windows.Forms.TabPage
$t2.Text = "Icon Recolor"
$t2.BackColor = [System.Drawing.Color]::FromArgb(26,47,63)
$tabs.Controls.Add($t2)

$lbl2a = New-Object System.Windows.Forms.Label
$lbl2a.Text = "Input:"
$lbl2a.Location = New-Object System.Drawing.Point(20,20)
$lbl2a.Size = New-Object System.Drawing.Size(60,20)
$lbl2a.ForeColor = [System.Drawing.Color]::White
$t2.Controls.Add($lbl2a)

$txt2a = New-Object System.Windows.Forms.TextBox
$txt2a.Location = New-Object System.Drawing.Point(90,20)
$txt2a.Size = New-Object System.Drawing.Size(410,20)
$t2.Controls.Add($txt2a)

$btn2a = New-Object System.Windows.Forms.Button
$btn2a.Text = "Browse"
$btn2a.Location = New-Object System.Drawing.Point(520,18)
$btn2a.Size = New-Object System.Drawing.Size(90,25)
$btn2a.BackColor = [System.Drawing.Color]::FromArgb(102,224,255)
$btn2a.ForeColor = [System.Drawing.Color]::Black
$t2.Controls.Add($btn2a)
$btn2a.Add_Click({ $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq "OK"){$txt2a.Text=$d.SelectedPath} })

$lbl2b = New-Object System.Windows.Forms.Label
$lbl2b.Text = "Output:"
$lbl2b.Location = New-Object System.Drawing.Point(20,55)
$lbl2b.Size = New-Object System.Drawing.Size(60,20)
$lbl2b.ForeColor = [System.Drawing.Color]::White
$t2.Controls.Add($lbl2b)

$txt2b = New-Object System.Windows.Forms.TextBox
$txt2b.Location = New-Object System.Drawing.Point(90,55)
$txt2b.Size = New-Object System.Drawing.Size(410,20)
$t2.Controls.Add($txt2b)

$btn2b = New-Object System.Windows.Forms.Button
$btn2b.Text = "Browse"
$btn2b.Location = New-Object System.Drawing.Point(520,53)
$btn2b.Size = New-Object System.Drawing.Size(90,25)
$btn2b.BackColor = [System.Drawing.Color]::FromArgb(102,224,255)
$btn2b.ForeColor = [System.Drawing.Color]::Black
$t2.Controls.Add($btn2b)
$btn2b.Add_Click({ $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq "OK"){$txt2b.Text=$d.SelectedPath} })

$script:col2 = [System.Drawing.Color]::RoyalBlue
$btn2c = New-Object System.Windows.Forms.Button
$btn2c.Text = "Pick Color"
$btn2c.Location = New-Object System.Drawing.Point(90,90)
$btn2c.Size = New-Object System.Drawing.Size(110,25)
$btn2c.BackColor = $script:col2
$btn2c.ForeColor = [System.Drawing.Color]::White
$t2.Controls.Add($btn2c)
$btn2c.Add_Click({ $cd=New-Object System.Windows.Forms.ColorDialog; if($cd.ShowDialog() -eq "OK"){ $script:col2=$cd.Color; $btn2c.BackColor=$script:col2; if($script:col2.GetBrightness() -lt 0.5){$btn2c.ForeColor=[System.Drawing.Color]::White}else{$btn2c.ForeColor=[System.Drawing.Color]::Black} } })

$chk2a = New-Object System.Windows.Forms.CheckBox
$chk2a.Text = ".ICO files"
$chk2a.Checked = $true
$chk2a.Location = New-Object System.Drawing.Point(230,92)
$chk2a.Size = New-Object System.Drawing.Size(100,20)
$chk2a.ForeColor = [System.Drawing.Color]::White
$t2.Controls.Add($chk2a)

$chk2b = New-Object System.Windows.Forms.CheckBox
$chk2b.Text = ".LNK shortcuts"
$chk2b.Location = New-Object System.Drawing.Point(350,92)
$chk2b.Size = New-Object System.Drawing.Size(130,20)
$chk2b.ForeColor = [System.Drawing.Color]::White
$t2.Controls.Add($chk2b)

$log2 = New-Object System.Windows.Forms.TextBox
$log2.Multiline = $true
$log2.ReadOnly = $true
$log2.ScrollBars = "Vertical"
$log2.Location = New-Object System.Drawing.Point(20,130)
$log2.Size = New-Object System.Drawing.Size(590,110)
$log2.BackColor = [System.Drawing.Color]::FromArgb(15,30,45)
$log2.ForeColor = [System.Drawing.Color]::LightGreen
$t2.Controls.Add($log2)

$btn2go = New-Object System.Windows.Forms.Button
$btn2go.Text = "PROCESS"
$btn2go.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$btn2go.Location = New-Object System.Drawing.Point(20,260)
$btn2go.Size = New-Object System.Drawing.Size(590,40)
$btn2go.BackColor = [System.Drawing.Color]::FromArgb(0,170,136)
$btn2go.ForeColor = [System.Drawing.Color]::White
$t2.Controls.Add($btn2go)

function Recolor-Bmp {
    param($bmp,$c)
    for($y=0;$y -lt $bmp.Height;$y++){
        for($x=0;$x -lt $bmp.Width;$x++){
            $p=$bmp.GetPixel($x,$y)
            if($p.A -gt 60){ $bmp.SetPixel($x,$y,[Drawing.Color]::FromArgb($p.A,$c.R,$c.G,$c.B)) }
        }
    }
}

$btn2go.Add_Click({
    $in=$txt2a.Text; $out=$txt2b.Text
    if(-not (Test-Path $in)){[System.Windows.Forms.MessageBox]::Show("Invalid input","Error","OK","Error"); return}
    if(-not $out){$out=$in}
    if(-not (Test-Path $out)){New-Item -ItemType Directory -Path $out -Force|Out-Null}
    $log2.Clear()
    if($chk2a.Checked){
        Get-ChildItem $in -Filter *.ico -File | %{
            try{
                $dst=Join-Path $out $_.Name
                $bmp=[Drawing.Bitmap]::FromFile($_.FullName)
                Recolor-Bmp $bmp $script:col2
                [IconWriter]::SaveIcon($bmp,$dst)|Out-Null
                $bmp.Dispose()
                $log2.AppendText("OK: $($_.Name)`r`n")
            }catch{ $log2.AppendText("ERR: $($_.Name)`r`n") }
        }
    }
    if($chk2b.Checked){
        $sh=New-Object -ComObject WScript.Shell
        Get-ChildItem $in -Filter *.lnk -File | %{
            try{
                $lnk=$sh.CreateShortcut($_.FullName)
                $tgt=$lnk.TargetPath
                $ic=$lnk.IconLocation
                if($ic -and $ic -ne ""){
                    $parts=$ic -split ','
                    $ip=$parts[0].Trim('"')
                    $idx=0
                    if($parts.Count -gt 1){ [int]::TryParse($parts[1].Trim(),[ref]$idx) | Out-Null }
                    if(Test-Path $ip){
                        $bmp=$null
                        if([IO.Path]::GetExtension($ip) -ieq ".ico"){ $bmp=[Drawing.Bitmap]::FromFile($ip) }
                        else { $bmp=[IconExtractor]::GetIcon($ip,$idx) }
                        if(-not $bmp){ $log2.AppendText("SKIP (icon unreadable): $($_.Name)`r`n") }
                        else {
                            Recolor-Bmp $bmp $script:col2
                            $nic=Join-Path $out ([IO.Path]::GetFileNameWithoutExtension($_.Name)+"_col.ico")
                            [IconWriter]::SaveIcon($bmp,$nic)|Out-Null
                            $bmp.Dispose()
                            $nl=Join-Path $out $_.Name
                            $ns=$sh.CreateShortcut($nl)
                            $ns.TargetPath=$tgt
                            $ns.Arguments=$lnk.Arguments
                            $ns.WorkingDirectory=$lnk.WorkingDirectory
                            $ns.IconLocation="`"$nic`",0"
                            $ns.Save()
                            $log2.AppendText("OK: $($_.Name)`r`n")
                        }
                    }else{$log2.AppendText("SKIP: $($_.Name)`r`n")}
                }else{$log2.AppendText("SKIP: $($_.Name)`r`n")}
            }catch{ $log2.AppendText("ERR: $($_.Name)`r`n") }
        }
    }
    $log2.AppendText("Done.`r`n")
})

# Tab 3
$t3 = New-Object System.Windows.Forms.TabPage
$t3.Text = "Color Variants"
$t3.BackColor = [System.Drawing.Color]::FromArgb(26,47,63)
$tabs.Controls.Add($t3)

$script:src3=$null
$script:out3=Join-Path ([Environment]::GetFolderPath("MyPictures")) "DG_ColorVariants"
if(-not (Test-Path $script:out3)){New-Item -ItemType Directory -Path $script:out3 -Force|Out-Null}

$lbl3a = New-Object System.Windows.Forms.Label
$lbl3a.Text = "Base Image:"
$lbl3a.Location = New-Object System.Drawing.Point(20,20)
$lbl3a.Size = New-Object System.Drawing.Size(100,20)
$lbl3a.ForeColor = [System.Drawing.Color]::White
$t3.Controls.Add($lbl3a)

$btn3a = New-Object System.Windows.Forms.Button
$btn3a.Text = "Select Image"
$btn3a.Location = New-Object System.Drawing.Point(20,45)
$btn3a.Size = New-Object System.Drawing.Size(140,30)
$btn3a.BackColor = [System.Drawing.Color]::FromArgb(102,224,255)
$btn3a.ForeColor = [System.Drawing.Color]::Black
$t3.Controls.Add($btn3a)

$lbl3path = New-Object System.Windows.Forms.Label
$lbl3path.Text = "No file selected"
$lbl3path.Location = New-Object System.Drawing.Point(180,50)
$lbl3path.Size = New-Object System.Drawing.Size(430,20)
$lbl3path.ForeColor = [System.Drawing.Color]::Yellow
$t3.Controls.Add($lbl3path)

$lbl3b = New-Object System.Windows.Forms.Label
$lbl3b.Text = "Format:"
$lbl3b.Location = New-Object System.Drawing.Point(20,95)
$lbl3b.Size = New-Object System.Drawing.Size(60,20)
$lbl3b.ForeColor = [System.Drawing.Color]::White
$t3.Controls.Add($lbl3b)

$cmb3 = New-Object System.Windows.Forms.ComboBox
$cmb3.DropDownStyle = "DropDownList"
$cmb3.Items.AddRange(@("PNG","JPG","ICO"))
$cmb3.SelectedIndex = 0
$cmb3.Location = New-Object System.Drawing.Point(90,93)
$cmb3.Size = New-Object System.Drawing.Size(80,25)
$t3.Controls.Add($cmb3)

$lbl3c = New-Object System.Windows.Forms.Label
$lbl3c.Text = "Output:"
$lbl3c.Location = New-Object System.Drawing.Point(200,95)
$lbl3c.Size = New-Object System.Drawing.Size(60,20)
$lbl3c.ForeColor = [System.Drawing.Color]::White
$t3.Controls.Add($lbl3c)

$lbl3out = New-Object System.Windows.Forms.Label
$lbl3out.Text = $script:out3
$lbl3out.Location = New-Object System.Drawing.Point(270,95)
$lbl3out.Size = New-Object System.Drawing.Size(250,20)
$lbl3out.ForeColor = [System.Drawing.Color]::LightGray
$t3.Controls.Add($lbl3out)

$btn3b = New-Object System.Windows.Forms.Button
$btn3b.Text = "Change"
$btn3b.Location = New-Object System.Drawing.Point(520,91)
$btn3b.Size = New-Object System.Drawing.Size(90,25)
$btn3b.BackColor = [System.Drawing.Color]::FromArgb(102,224,255)
$btn3b.ForeColor = [System.Drawing.Color]::Black
$t3.Controls.Add($btn3b)

$pres = [ordered]@{"blue"="#0088FF";"brown"="#8B5A2B";"coral"="#FF7F50";"crimson"="#DC143C";"cyan"="#00FFFF";"emerald"="#50C878";"fuchsia"="#FF00FF";"gold"="#FFD700";"graphite"="#4B4B4B";"green"="#00FF00";"indigo"="#4B0082";"lime"="#32CD32";"magenta"="#FF00CC";"orange"="#FF8C00";"pink"="#FF69B4";"purple"="#9370DB";"red"="#FF0000";"rose"="#FF4080";"salmon"="#FA8072";"silver"="#C0C0C0";"sky"="#87CEEB";"slate"="#708090";"teal"="#008080";"violet"="#EE82EE";"white"="#FFFFFF";"yellow"="#FFFF00"}

$lbl3d = New-Object System.Windows.Forms.Label
$lbl3d.Text = "$($pres.Count) variants"
$lbl3d.Location = New-Object System.Drawing.Point(20,135)
$lbl3d.Size = New-Object System.Drawing.Size(150,20)
$lbl3d.ForeColor = [System.Drawing.Color]::LightGreen
$t3.Controls.Add($lbl3d)

$log3 = New-Object System.Windows.Forms.TextBox
$log3.Multiline = $true
$log3.ReadOnly = $true
$log3.ScrollBars = "Vertical"
$log3.Location = New-Object System.Drawing.Point(20,165)
$log3.Size = New-Object System.Drawing.Size(590,90)
$log3.BackColor = [System.Drawing.Color]::FromArgb(15,30,45)
$log3.ForeColor = [System.Drawing.Color]::LightGreen
$log3.Text = "Ready"
$t3.Controls.Add($log3)

$btn3go = New-Object System.Windows.Forms.Button
$btn3go.Text = "GENERATE ALL VARIANTS"
$btn3go.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$btn3go.Location = New-Object System.Drawing.Point(20,275)
$btn3go.Size = New-Object System.Drawing.Size(590,40)
$btn3go.BackColor = [System.Drawing.Color]::FromArgb(0,170,136)
$btn3go.ForeColor = [System.Drawing.Color]::White
$t3.Controls.Add($btn3go)

$btn3a.Add_Click({ $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="Images|*.jpg;*.jpeg;*.png;*.bmp"; if($dlg.ShowDialog() -eq "OK"){ $script:src3=$dlg.FileName; $lbl3path.Text="SELECTED: $(Split-Path $script:src3 -Leaf)"; $lbl3path.ForeColor=[System.Drawing.Color]::LightGreen; $log3.Text="Loaded" } })
$btn3b.Add_Click({ $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq "OK"){ $script:out3=$d.SelectedPath; $lbl3out.Text=$script:out3 } })

function H2C([string]$h){ $h=$h.TrimStart('#'); $r=[Convert]::ToInt32($h.Substring(0,2),16); $g=[Convert]::ToInt32($h.Substring(2,2),16); $b=[Convert]::ToInt32($h.Substring(4,2),16); return [Drawing.Color]::FromArgb(255,$r,$g,$b) }

$btn3go.Add_Click({
    if(-not $script:src3 -or -not (Test-Path $script:src3)){[System.Windows.Forms.MessageBox]::Show("Select image","Error","OK","Error"); return}
    if(-not (Test-Path $script:out3)){New-Item -ItemType Directory -Path $script:out3 -Force|Out-Null}
    $ext=$cmb3.SelectedItem.ToString().ToLower(); $base=[IO.Path]::GetFileNameWithoutExtension($script:src3)
    try{$img=[Drawing.Image]::FromFile($script:src3)}catch{[System.Windows.Forms.MessageBox]::Show("Cannot load","Error","OK","Error"); return}
    $log3.Text="Generating...`r`n"; $t3.Refresh(); $i=0
    foreach($kv in $pres.GetEnumerator()){
        $i++; $n=$kv.Key; $c=H2C $kv.Value
        $log3.Text="Processing $i/$($pres.Count) - $n`r`n"; $t3.Refresh()
        $bmp=New-Object Drawing.Bitmap($img.Width,$img.Height)
        $bmp.SetResolution($img.HorizontalResolution,$img.VerticalResolution)
        $g=[Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $cm=New-Object Drawing.Imaging.ColorMatrix
        $cm.Matrix00=$c.R/255;$cm.Matrix11=$c.G/255;$cm.Matrix22=$c.B/255;$cm.Matrix33=1
        $attr=New-Object Drawing.Imaging.ImageAttributes
        $attr.SetColorMatrix($cm)
        $g.DrawImage($img,[Drawing.Rectangle]::new(0,0,$img.Width,$img.Height),0,0,$img.Width,$img.Height,[Drawing.GraphicsUnit]::Pixel,$attr)
        $op=Join-Path $script:out3 "$base-$n.$ext"
        if($ext -eq "jpg"){
            $wb=New-Object Drawing.Bitmap($img.Width,$img.Height)
            $wg=[Drawing.Graphics]::FromImage($wb)
            $wg.Clear([Drawing.Color]::White)
            $wg.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::HighQuality
            $wg.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $wg.DrawImage($bmp,0,0)
            $codecs=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | ? {$_.MimeType -eq 'image/jpeg'}
            $ep=New-Object Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0]=New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality,[long]95)
            $wb.Save($op,$codecs,$ep)
            $wg.Dispose();$wb.Dispose()
        }elseif($ext -eq "ico"){
            [IconWriter]::SaveIcon($bmp,$op)|Out-Null
        }else{
            $codecs=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | ? {$_.MimeType -eq 'image/png'}
            $ep=New-Object Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0]=New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality,[long]100)
            $bmp.Save($op,$codecs,$ep)
        }
        $g.Dispose();$bmp.Dispose()
    }
    $img.Dispose()
    $log3.Text="DONE! $($pres.Count) variants saved to $script:out3"
    [System.Windows.Forms.MessageBox]::Show("Generated $($pres.Count) variants`n$script:out3","Complete","OK","Information")
})

$btnInst = New-Object System.Windows.Forms.Button
$btnInst.Text = "CREATE DESKTOP SHORTCUT"
$btnInst.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$btnInst.Location = New-Object System.Drawing.Point(20,460)
$btnInst.Size = New-Object System.Drawing.Size(640,40)
$btnInst.BackColor = [System.Drawing.Color]::FromArgb(255,215,0)
$btnInst.ForeColor = [System.Drawing.Color]::Black
$form.Controls.Add($btnInst)

$btnInst.Add_Click({
    try{
        $scriptPath = $PSCommandPath
        if(-not $scriptPath){ $scriptPath = $MyInvocation.MyCommand.Path }
        $scriptDir = Split-Path -Parent $scriptPath
        $lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "DGs Image Tools (Legacy).lnk"
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnk)
        $sc.TargetPath = "powershell.exe"
        $sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File `"$scriptPath`""
        $sc.WorkingDirectory = $scriptDir
        $icon = Join-Path $scriptDir "DG-Visual-Toolkit.ico"
        if(Test-Path -LiteralPath $icon){ $sc.IconLocation = "`"$icon`",0" }
        $sc.Description = "DGs Image Tools v1 (Legacy)"
        $sc.Save()
        [System.Windows.Forms.MessageBox]::Show("Desktop shortcut created:`n$lnk","Success","OK","Information")
    }catch{
        [System.Windows.Forms.MessageBox]::Show("Error: $_","Error","OK","Error")
    }
})

[System.Windows.Forms.Application]::Run($form)
