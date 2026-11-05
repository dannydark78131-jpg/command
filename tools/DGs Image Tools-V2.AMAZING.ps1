Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class IconWriter {
    public static bool SaveIconSizes(Bitmap source, string path, int[] sizes, bool stretch, int padPct) {
        try {
            List<int> list = new List<int>();
            if (sizes != null) {
                foreach (int s in sizes) { if (s > 0 && s <= 256 && !list.Contains(s)) list.Add(s); }
            }
            if (list.Count == 0) list.Add(256);
            list.Sort();
            MemoryStream ms = new MemoryStream();
            BinaryWriter bw = new BinaryWriter(ms);
            bw.Write((short)0); bw.Write((short)1); bw.Write((short)list.Count);
            List<byte[]> frames = new List<byte[]>();
            foreach (int size in list) {
                using (Bitmap b = new Bitmap(size, size, PixelFormat.Format32bppArgb)) {
                    using (Graphics g = Graphics.FromImage(b)) {
                        g.Clear(Color.Transparent);
                        g.SmoothingMode = SmoothingMode.HighQuality;
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.CompositingQuality = CompositingQuality.HighQuality;
                        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        int pad = (int)Math.Round(size * padPct / 100.0 / 2.0);
                        int avail = size - pad * 2;
                        if (avail < 1) { avail = size; pad = 0; }
                        int dw = avail, dh = avail;
                        if (!stretch && source.Width > 0 && source.Height > 0) {
                            double r = Math.Min((double)avail / source.Width, (double)avail / source.Height);
                            dw = Math.Max(1, (int)Math.Round(source.Width * r));
                            dh = Math.Max(1, (int)Math.Round(source.Height * r));
                        }
                        int x = (size - dw) / 2;
                        int y = (size - dh) / 2;
                        g.DrawImage(source, new Rectangle(x, y, dw, dh));
                    }
                    using (MemoryStream s2 = new MemoryStream()) {
                        b.Save(s2, ImageFormat.Png);
                        frames.Add(s2.ToArray());
                    }
                }
            }
            int offset = 6 + 16 * list.Count;
            for (int i = 0; i < list.Count; i++) {
                int sz = list[i];
                bw.Write((byte)(sz >= 256 ? 0 : sz));
                bw.Write((byte)(sz >= 256 ? 0 : sz));
                bw.Write((byte)0); bw.Write((byte)0);
                bw.Write((short)1); bw.Write((short)32);
                bw.Write(frames[i].Length); bw.Write(offset);
                offset += frames[i].Length;
            }
            for (int i = 0; i < list.Count; i++) {
                bw.Write(frames[i]);
            }
            bw.Flush();
            File.WriteAllBytes(path, ms.ToArray());
            bw.Dispose();
            ms.Dispose();
            return true;
        } catch { return false; }
    }
}

public class ImageOps {
    public static Bitmap Tint(Bitmap src, Color c) {
        Bitmap work = src;
        bool own = false;
        if (src.PixelFormat != PixelFormat.Format32bppArgb) {
            work = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(work)) {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawImage(src, 0, 0, src.Width, src.Height);
            }
            own = true;
        }
        Bitmap dst = new Bitmap(work.Width, work.Height, PixelFormat.Format32bppArgb);
        Rectangle rect = new Rectangle(0, 0, work.Width, work.Height);
        BitmapData sd = work.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dd = dst.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int bytes = Math.Abs(sd.Stride) * work.Height;
        byte[] buf = new byte[bytes];
        Marshal.Copy(sd.Scan0, buf, 0, bytes);
        for (int i = 0; i < bytes; i += 4) {
            double lum = 0.299 * buf[i + 2] + 0.587 * buf[i + 1] + 0.114 * buf[i];
            buf[i] = (byte)Math.Min(255, Math.Round(c.B * lum / 255.0));
            buf[i + 1] = (byte)Math.Min(255, Math.Round(c.G * lum / 255.0));
            buf[i + 2] = (byte)Math.Min(255, Math.Round(c.R * lum / 255.0));
        }
        Marshal.Copy(buf, 0, dd.Scan0, bytes);
        work.UnlockBits(sd);
        dst.UnlockBits(dd);
        if (own) work.Dispose();
        return dst;
    }
    public static Bitmap FlatFill(Bitmap src, Color c) {
        Bitmap work = src;
        bool own = false;
        if (src.PixelFormat != PixelFormat.Format32bppArgb) {
            work = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(work)) {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawImage(src, 0, 0, src.Width, src.Height);
            }
            own = true;
        }
        Bitmap dst = new Bitmap(work.Width, work.Height, PixelFormat.Format32bppArgb);
        Rectangle rect = new Rectangle(0, 0, work.Width, work.Height);
        BitmapData sd = work.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dd = dst.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int bytes = Math.Abs(sd.Stride) * work.Height;
        byte[] buf = new byte[bytes];
        Marshal.Copy(sd.Scan0, buf, 0, bytes);
        for (int i = 0; i < bytes; i += 4) {
            buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R;
        }
        Marshal.Copy(buf, 0, dd.Scan0, bytes);
        work.UnlockBits(sd);
        dst.UnlockBits(dd);
        if (own) work.Dispose();
        return dst;
    }
}

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
            Bitmap bmp;
            using (Icon ic = Icon.FromHandle(h)) { bmp = ic.ToBitmap(); }
            return bmp;
        } catch { return null; }
        finally {
            if (large[0] != IntPtr.Zero) DestroyIcon(large[0]);
            if (small[0] != IntPtr.Zero) DestroyIcon(small[0]);
        }
    }
}
"@ -ReferencedAssemblies System.Drawing,System.IO

$script:C_BG = [System.Drawing.Color]::FromArgb(10,22,32)
$script:C_PANEL = [System.Drawing.Color]::FromArgb(26,47,63)
$script:C_LOG = [System.Drawing.Color]::FromArgb(15,30,45)
$script:C_TEXT = [System.Drawing.Color]::White
$script:C_MUTED = [System.Drawing.Color]::LightGray
$script:C_ACCENT = [System.Drawing.Color]::FromArgb(102,224,255)
$script:C_PRIMARY = [System.Drawing.Color]::FromArgb(0,170,136)
$script:C_GOLD = [System.Drawing.Color]::FromArgb(255,215,0)

$script:jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }

function New-Lbl {
    param([string]$text,[int]$x,[int]$y,[int]$w,[int]$h)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x,$y)
    $l.Size = New-Object System.Drawing.Size($w,$h)
    $l.ForeColor = $script:C_TEXT
    return $l
}

function New-Txt {
    param([int]$x,[int]$y,[int]$w,[int]$h)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x,$y)
    $t.Size = New-Object System.Drawing.Size($w,$h)
    return $t
}

function New-Num {
    param([int]$x,[int]$y,[int]$w,[int]$min,[int]$max,[int]$val)
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Location = New-Object System.Drawing.Point($x,$y)
    $n.Size = New-Object System.Drawing.Size($w,24)
    $n.Minimum = $min
    $n.Maximum = $max
    $n.Value = $val
    return $n
}

function New-Cmb {
    param([string[]]$items,[int]$x,[int]$y,[int]$w)
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = "DropDownList"
    $c.Items.AddRange($items)
    $c.SelectedIndex = 0
    $c.Location = New-Object System.Drawing.Point($x,$y)
    $c.Size = New-Object System.Drawing.Size($w,24)
    return $c
}

function New-Chk {
    param([string]$text,[int]$x,[int]$y,[int]$w,[bool]$checked)
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text
    $c.Location = New-Object System.Drawing.Point($x,$y)
    $c.Size = New-Object System.Drawing.Size($w,20)
    $c.ForeColor = $script:C_TEXT
    $c.Checked = $checked
    return $c
}

function New-Btn {
    param([string]$text,[int]$x,[int]$y,[int]$w,[int]$h,[System.Drawing.Color]$color,[bool]$bold)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x,$y)
    $b.Size = New-Object System.Drawing.Size($w,$h)
    $b.BackColor = $color
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    if($bold){ $b.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold) }
    else { $b.Font = New-Object System.Drawing.Font("Segoe UI",9) }
    if($color.GetBrightness() -gt 0.62){ $b.ForeColor = [System.Drawing.Color]::Black }
    else { $b.ForeColor = [System.Drawing.Color]::White }
    return $b
}

function New-LogBox {
    param([int]$x,[int]$y,[int]$w,[int]$h)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true
    $t.ReadOnly = $true
    $t.ScrollBars = "Vertical"
    $t.Location = New-Object System.Drawing.Point($x,$y)
    $t.Size = New-Object System.Drawing.Size($w,$h)
    $t.BackColor = $script:C_LOG
    $t.ForeColor = [System.Drawing.Color]::LightGreen
    $t.Font = New-Object System.Drawing.Font("Consolas",8.25)
    return $t
}

function New-Progress {
    param([int]$x,[int]$y,[int]$w)
    $p = New-Object System.Windows.Forms.ProgressBar
    $p.Location = New-Object System.Drawing.Point($x,$y)
    $p.Size = New-Object System.Drawing.Size($w,16)
    $p.Style = "Continuous"
    return $p
}

function New-Tab {
    param([string]$text)
    $t = New-Object System.Windows.Forms.TabPage
    $t.Text = $text
    $t.BackColor = $script:C_PANEL
    return $t
}

function Enable-FolderDrop {
    param($tb)
    $tb.AllowDrop = $true
    $tb.Add_DragEnter({ param($sender,$e) if($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)){ $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy } })
    $tb.Add_DragDrop({
        param($sender,$e)
        $items = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        if($items -and $items.Count -gt 0){
            $p = $items[0]
            if(Test-Path -LiteralPath $p -PathType Leaf){ $p = Split-Path -LiteralPath $p -Parent }
            $sender.Text = $p
        }
    })
}

function Update-Ui { [System.Windows.Forms.Application]::DoEvents() }

function Open-Folder {
    param([string]$path)
    if($path -and (Test-Path -LiteralPath $path)){ Start-Process explorer.exe -ArgumentList "`"$path`"" }
}

function Get-ImageFiles {
    param([string]$dir,[string[]]$patterns,[bool]$recurse)
    $files = @()
    foreach($p in $patterns){
        if($recurse){ $files += Get-ChildItem -LiteralPath $dir -Filter $p -Recurse -File -ErrorAction SilentlyContinue }
        else { $files += Get-ChildItem -LiteralPath $dir -Filter $p -File -ErrorAction SilentlyContinue }
    }
    return @($files | Sort-Object FullName -Unique)
}

function Get-RelDir {
    param($file,[string]$root)
    $r = $root.TrimEnd('\')
    $d = $file.DirectoryName
    if(-not $d -or $d.Length -le $r.Length){ return "" }
    return $d.Substring($r.Length).TrimStart('\')
}

function To-Bitmap32 {
    param($img)
    $b = New-Object System.Drawing.Bitmap($img.Width,$img.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try { $b.SetResolution($img.HorizontalResolution,$img.VerticalResolution) } catch {}
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img,0,0,$img.Width,$img.Height)
    $g.Dispose()
    return $b
}

function Load-ImageSource {
    param([string]$path)
    try { return [System.Drawing.Image]::FromFile($path) }
    catch {
        $ic = New-Object System.Drawing.Icon($path,256,256)
        $bmp = $ic.ToBitmap()
        $ic.Dispose()
        return $bmp
    }
}

function Save-BitmapAs {
    param($bmp,[string]$path,[string]$fmt,[int]$quality)
    $fmt = $fmt.ToLower()
    try {
        if($fmt -eq "jpg" -or $fmt -eq "jpeg"){
            $flat = New-Object System.Drawing.Bitmap($bmp.Width,$bmp.Height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $g = [System.Drawing.Graphics]::FromImage($flat)
            $g.Clear([System.Drawing.Color]::White)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.DrawImage($bmp,0,0,$bmp.Width,$bmp.Height)
            $g.Dispose()
            $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,[long]$quality)
            $flat.Save($path,$script:jpegCodec,$ep)
            $flat.Dispose()
        }
        elseif($fmt -eq "png"){ $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png) }
        elseif($fmt -eq "bmp"){ $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Bmp) }
        elseif($fmt -eq "gif"){ $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Gif) }
        elseif($fmt -eq "tiff"){ $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Tiff) }
        elseif($fmt -eq "ico"){ return [IconWriter]::SaveIconSizes($bmp,$path,@(16,24,32,48,64,128,256),$true,0) }
        else { return $false }
        return $true
    } catch { return $false }
}

function Tint-Bitmap {
    param($bmp,[System.Drawing.Color]$color,[int]$mode)
    if($mode -eq 1){ return [ImageOps]::FlatFill($bmp,$color) }
    return [ImageOps]::Tint($bmp,$color)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "DGs Image Tools v2.0.1"
$form.Size = New-Object System.Drawing.Size(780,720)
$form.MinimumSize = New-Object System.Drawing.Size(780,720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.BackColor = $script:C_BG
$form.ForeColor = $script:C_TEXT
$form.GetType().GetProperty("DoubleBuffered",[Reflection.BindingFlags]"Instance,NonPublic").SetValue($form,$true,$null)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "DGs IMAGE TOOLS"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $script:C_ACCENT
$lblTitle.Location = New-Object System.Drawing.Point(20,16)
$lblTitle.Size = New-Object System.Drawing.Size(730,40)
$lblTitle.TextAlign = "MiddleCenter"
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "v2.0.1  |  Convert  |  Build ICO  |  Recolor Icons & Shortcuts  |  Generate Color Variants"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI",9)
$lblSub.ForeColor = $script:C_MUTED
$lblSub.Location = New-Object System.Drawing.Point(20,56)
$lblSub.Size = New-Object System.Drawing.Size(730,20)
$lblSub.TextAlign = "MiddleCenter"
$form.Controls.Add($lblSub)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(20,92)
$tabs.Size = New-Object System.Drawing.Size(730,515)
$tabs.Font = New-Object System.Drawing.Font("Segoe UI",9)
$form.Controls.Add($tabs)

$t0 = New-Tab "Image Converter"
$tabs.Controls.Add($t0)

$t0.Controls.Add((New-Lbl "Source folder (drag a folder here):" 15 10 300 18))
$txt0src = New-Txt 15 30 560 24
$t0.Controls.Add($txt0src)
Enable-FolderDrop $txt0src
$btn0src = New-Btn "Browse" 582 29 100 26 $script:C_ACCENT
$t0.Controls.Add($btn0src)
$btn0src.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt0src.Text = $d.SelectedPath } })

$t0.Controls.Add((New-Lbl "Output folder (blank = same as source):" 15 62 300 18))
$txt0out = New-Txt 15 82 560 24
$t0.Controls.Add($txt0out)
Enable-FolderDrop $txt0out
$btn0out = New-Btn "Browse" 582 81 100 26 $script:C_ACCENT
$t0.Controls.Add($btn0out)
$btn0out.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt0out.Text = $d.SelectedPath } })

$t0.Controls.Add((New-Lbl "Source types:" 15 114 90 18))
$srcTypes = @("PNG","JPG","JPEG","BMP","GIF","TIFF","ICO","All")
$chk0src = @{}
$x0 = 108
foreach($st in $srcTypes){
    $cb = New-Chk $st $x0 113 56 $true
    if($st -eq "All"){ $cb.Size = New-Object System.Drawing.Size(42,20) }
    $t0.Controls.Add($cb)
    $chk0src[$st] = $cb
    $x0 += $(if($st -eq "JPEG"){60}elseif($st -eq "All"){44}else{54})
}

$t0.Controls.Add((New-Lbl "Convert to:" 15 142 78 18))
$cmb0 = New-Cmb @("PNG","JPG","BMP","GIF","TIFF","ICO") 95 140 88
$t0.Controls.Add($cmb0)
$t0.Controls.Add((New-Lbl "Quality:" 195 142 55 18))
$num0q = New-Num 252 140 58 1 100 92
$t0.Controls.Add($num0q)
$chk0multi = New-Chk "Multi-size ICO (16-256)" 322 140 178 $false
$t0.Controls.Add($chk0multi)
$t0.Controls.Add((New-Lbl "Suffix:" 508 142 46 18))
$txt0suffix = New-Txt 556 140 126 24
$t0.Controls.Add($txt0suffix)

$t0.Controls.Add((New-Lbl "Resize (px, blank = original):" 15 172 200 18))
$t0.Controls.Add((New-Lbl "W:" 15 198 18 18))
$txt0w = New-Txt 35 196 60 24
$t0.Controls.Add($txt0w)
$t0.Controls.Add((New-Lbl "H:" 103 198 18 18))
$txt0h = New-Txt 123 196 60 24
$t0.Controls.Add($txt0h)
$chk0ratio = New-Chk "Keep aspect ratio" 195 196 140 $true
$t0.Controls.Add($chk0ratio)
$lbl0tip = New-Lbl "Leave blank to keep original dimensions" 345 198 340 18
$lbl0tip.ForeColor = $script:C_MUTED
$t0.Controls.Add($lbl0tip)

$chk0sub = New-Chk "Search subfolders (keep structure)" 15 228 230 $false
$t0.Controls.Add($chk0sub)
$chk0over = New-Chk "Overwrite existing" 255 228 140 $false
$t0.Controls.Add($chk0over)
$chk0del = New-Chk "Delete originals after conversion" 405 228 250 $false
$t0.Controls.Add($chk0del)

$log0 = New-LogBox 15 254 670 130
$log0.Text = "Ready."
$t0.Controls.Add($log0)
$prg0 = New-Progress 15 390 670
$t0.Controls.Add($prg0)
$btn0go = New-Btn "CONVERT IMAGES" 15 414 450 36 $script:C_PRIMARY $true
$t0.Controls.Add($btn0go)
$btn0open = New-Btn "OPEN OUTPUT FOLDER" 480 414 205 36 $script:C_ACCENT
$t0.Controls.Add($btn0open)
$btn0open.Add_Click({ Open-Folder $txt0out.Text })

$btn0go.Add_Click({
    $srcDir = $txt0src.Text.Trim().Trim('"').Trim("'")
    if(-not (Test-Path -LiteralPath $srcDir -PathType Container)){ [System.Windows.Forms.MessageBox]::Show("Select a valid source folder","Error","OK","Error"); return }
    $outDir = $txt0out.Text.Trim().Trim('"').Trim("'")
    if(-not $outDir){ $outDir = $srcDir }
    if(-not (Test-Path -LiteralPath $outDir)){ New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    $map = @{"PNG"="*.png";"JPG"="*.jpg";"JPEG"="*.jpeg";"BMP"="*.bmp";"GIF"="*.gif";"TIFF"="*.tif";"ICO"="*.ico"}
    $exts = @()
    if($chk0src["All"].Checked){ $exts = @("*.png","*.jpg","*.jpeg","*.bmp","*.gif","*.tif","*.tiff","*.ico") }
    else {
        foreach($k in @("PNG","JPG","JPEG","BMP","GIF","TIFF","ICO")){
            if($chk0src[$k].Checked){ $exts += $map[$k] }
        }
        if($chk0src["TIFF"].Checked){ $exts += "*.tiff" }
    }
    $exts = @($exts | Select-Object -Unique)
    if($exts.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select at least one source type","Warning","OK","Warning"); return }

    $files = Get-ImageFiles $srcDir $exts $chk0sub.Checked
    if($files.Count -eq 0){ $log0.Text = "No matching files found."; return }

    $target = $cmb0.SelectedItem.ToString().ToLower()
    $targetExt = ".$target"
    $quality = [int]$num0q.Value
    $suffix = $txt0suffix.Text.Trim()
    $tw = 0; $th = 0
    if($txt0w.Text.Trim() -ne ""){ [int]::TryParse($txt0w.Text.Trim(),[ref]$tw) | Out-Null }
    if($txt0h.Text.Trim() -ne ""){ [int]::TryParse($txt0h.Text.Trim(),[ref]$th) | Out-Null }
    $keep = $chk0ratio.Checked
    $multi = $chk0multi.Checked
    $overwrite = $chk0over.Checked
    $delOrig = $chk0del.Checked
    $recurse = $chk0sub.Checked

    $ok = 0; $fail = 0; $skip = 0; $i = 0
    $prg0.Minimum = 0; $prg0.Maximum = $files.Count; $prg0.Value = 0
    $log0.Clear()
    $log0.AppendText("Converting $($files.Count) file(s) to $($target.ToUpper())...`r`n")
    $btn0go.Enabled = $false
    $form.UseWaitCursor = $true
    try {
        foreach($f in $files){
            $i++
            $img = $null; $bmp = $null
            try {
                $destDir = $outDir
                if($recurse){
                    $rel = Get-RelDir $f $srcDir
                    if($rel){ $destDir = Join-Path $outDir $rel }
                }
                if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                $outPath = Join-Path $destDir ($f.BaseName + $suffix + $targetExt)
                if([IO.Path]::GetFullPath($outPath) -eq [IO.Path]::GetFullPath($f.FullName)){ $skip++; continue }
                if((Test-Path -LiteralPath $outPath) -and -not $overwrite){ $skip++; $log0.AppendText("SKIP (exists): $($f.Name)`r`n"); continue }

                $img = Load-ImageSource $f.FullName
                $sw = $img.Width; $sh = $img.Height; $nw = $sw; $nh = $sh
                if($tw -gt 0 -or $th -gt 0){
                    if($keep){
                        if($tw -gt 0 -and $th -gt 0){
                            $r = [Math]::Min($tw / [double]$sw, $th / [double]$sh)
                            $nw = [Math]::Max(1,[int][Math]::Round($sw * $r)); $nh = [Math]::Max(1,[int][Math]::Round($sh * $r))
                        } elseif($tw -gt 0){
                            $r = $tw / [double]$sw; $nw = $tw; $nh = [Math]::Max(1,[int][Math]::Round($sh * $r))
                        } else {
                            $r = $th / [double]$sh; $nh = $th; $nw = [Math]::Max(1,[int][Math]::Round($sw * $r))
                        }
                    } else {
                        if($tw -gt 0){ $nw = $tw }
                        if($th -gt 0){ $nh = $th }
                    }
                }

                $saved = $false
                if($target -eq "ico"){
                    $src32 = To-Bitmap32 $img
                    if($multi){ $saved = [IconWriter]::SaveIconSizes($src32,$outPath,@(16,24,32,48,64,128,256),$true,0) }
                    else { $saved = [IconWriter]::SaveIconSizes($src32,$outPath,@(256),$true,0) }
                    $src32.Dispose()
                } else {
                    $bmp = New-Object System.Drawing.Bitmap($nw,$nh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                    try { $bmp.SetResolution($img.HorizontalResolution,$img.VerticalResolution) } catch {}
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    if($target -eq "jpg"){ $g.Clear([System.Drawing.Color]::White) } else { $g.Clear([System.Drawing.Color]::Transparent) }
                    $g.DrawImage($img,0,0,$nw,$nh)
                    $g.Dispose()
                    $saved = Save-BitmapAs $bmp $outPath $target $quality
                    $bmp.Dispose(); $bmp = $null
                }
                $img.Dispose(); $img = $null
                if($saved){
                    $ok++
                    if($delOrig){ Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
                } else { $fail++; $log0.AppendText("FAIL: $($f.Name)`r`n") }
            } catch {
                $fail++
                $log0.AppendText("ERR: $($f.Name) - $($_.Exception.Message)`r`n")
                if($bmp){ try { $bmp.Dispose() } catch {} }
                if($img){ try { $img.Dispose() } catch {} }
            }
            $prg0.Value = $i
            if(($i % 3) -eq 0){ Update-Ui }
        }
    } finally {
        $btn0go.Enabled = $true
        $form.UseWaitCursor = $false
    }
    $log0.AppendText("Done. Converted: $ok  Skipped: $skip  Failed: $fail`r`n")
    [System.Windows.Forms.MessageBox]::Show("Converted: $ok`nSkipped: $skip`nFailed: $fail`n`nOutput: $outDir","Conversion Complete","OK","Information")
})
$t1 = New-Tab "Image to ICO"
$tabs.Controls.Add($t1)

$t1.Controls.Add((New-Lbl "Source folder (drag a folder here):" 15 10 300 18))
$txt1src = New-Txt 15 30 560 24
$t1.Controls.Add($txt1src)
Enable-FolderDrop $txt1src
$btn1src = New-Btn "Browse" 582 29 100 26 $script:C_ACCENT
$t1.Controls.Add($btn1src)
$btn1src.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt1src.Text = $d.SelectedPath } })

$t1.Controls.Add((New-Lbl "Output folder (blank = same as source):" 15 62 300 18))
$txt1out = New-Txt 15 82 560 24
$t1.Controls.Add($txt1out)
Enable-FolderDrop $txt1out
$btn1out = New-Btn "Browse" 582 81 100 26 $script:C_ACCENT
$t1.Controls.Add($btn1out)
$btn1out.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt1out.Text = $d.SelectedPath } })

$t1.Controls.Add((New-Lbl "Source images:" 15 114 90 18))
$srcMap1 = [ordered]@{"PNG"="*.png";"JPG"="*.jpg";"JPEG"="*.jpeg";"BMP"="*.bmp";"GIF"="*.gif";"TIFF"="*.tif"}
$chk1src = @{}
$x1 = 108
foreach($k in $srcMap1.Keys){
    $cb = New-Chk $k $x1 113 56 $true
    $t1.Controls.Add($cb)
    $chk1src[$k] = $cb
    $x1 += $(if($k -eq "JPEG"){60}else{54})
}

$t1.Controls.Add((New-Lbl "Icon sizes:" 15 144 90 18))
$icoSizesAll = @(16,24,32,48,64,128,256)
$chk1sizes = @{}
$x1 = 108
foreach($sz in $icoSizesAll){
    $cb = New-Chk ([string]$sz) $x1 143 46 $true
    $t1.Controls.Add($cb)
    $chk1sizes[$sz] = $cb
    $x1 += 46
}

$t1.Controls.Add((New-Lbl "Fit mode:" 15 176 60 18))
$cmb1fit = New-Cmb @("Fit (letterbox)","Stretch to fill") 78 174 140
$t1.Controls.Add($cmb1fit)
$t1.Controls.Add((New-Lbl "Padding %:" 236 176 68 18))
$num1pad = New-Num 306 174 58 0 40 0
$t1.Controls.Add($num1pad)
$lbl1hint = New-Lbl "Padding adds a transparent margin inside each icon size" 378 176 310 18
$lbl1hint.ForeColor = $script:C_MUTED
$t1.Controls.Add($lbl1hint)

$chk1sub = New-Chk "Search subfolders (keep structure)" 15 206 230 $false
$t1.Controls.Add($chk1sub)
$chk1over = New-Chk "Overwrite existing" 255 206 140 $false
$t1.Controls.Add($chk1over)
$chk1del = New-Chk "Delete originals after conversion" 405 206 250 $false
$t1.Controls.Add($chk1del)

$log1 = New-LogBox 15 234 670 130
$log1.Text = "Ready."
$t1.Controls.Add($log1)
$prg1 = New-Progress 15 370 670
$t1.Controls.Add($prg1)
$btn1go = New-Btn "BUILD ICO FILES" 15 394 450 36 $script:C_PRIMARY $true
$t1.Controls.Add($btn1go)
$btn1open = New-Btn "OPEN OUTPUT FOLDER" 480 394 205 36 $script:C_ACCENT
$t1.Controls.Add($btn1open)
$btn1open.Add_Click({ Open-Folder $txt1out.Text })

$btn1go.Add_Click({
    $srcDir = $txt1src.Text.Trim().Trim('"').Trim("'")
    if(-not (Test-Path -LiteralPath $srcDir -PathType Container)){ [System.Windows.Forms.MessageBox]::Show("Select a valid source folder","Error","OK","Error"); return }
    $outDir = $txt1out.Text.Trim().Trim('"').Trim("'")
    if(-not $outDir){ $outDir = $srcDir }
    if(-not (Test-Path -LiteralPath $outDir)){ New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    $exts = @()
    foreach($k in $srcMap1.Keys){
        if($chk1src[$k].Checked){ $exts += $srcMap1[$k] }
    }
    if($chk1src["TIFF"].Checked){ $exts += "*.tiff" }
    $exts = @($exts | Select-Object -Unique)
    if($exts.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select at least one source image type","Warning","OK","Warning"); return }

    $sizes = @()
    foreach($sz in $icoSizesAll){ if($chk1sizes[$sz].Checked){ $sizes += $sz } }
    if($sizes.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select at least one icon size","Warning","OK","Warning"); return }

    $files = Get-ImageFiles $srcDir $exts $chk1sub.Checked
    if($files.Count -eq 0){ $log1.Text = "No matching files found."; return }

    $stretch = ($cmb1fit.SelectedIndex -eq 1)
    $pad = [int]$num1pad.Value
    $overwrite = $chk1over.Checked
    $delOrig = $chk1del.Checked
    $recurse = $chk1sub.Checked

    $ok = 0; $fail = 0; $skip = 0; $i = 0
    $prg1.Minimum = 0; $prg1.Maximum = $files.Count; $prg1.Value = 0
    $log1.Clear()
    $log1.AppendText("Building $($files.Count) icon file(s)...`r`n")
    $btn1go.Enabled = $false
    $form.UseWaitCursor = $true
    try {
        foreach($f in $files){
            $i++
            $img = $null; $bmp = $null
            try {
                $destDir = $outDir
                if($recurse){
                    $rel = Get-RelDir $f $srcDir
                    if($rel){ $destDir = Join-Path $outDir $rel }
                }
                if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                $outPath = Join-Path $destDir ($f.BaseName + ".ico")
                if((Test-Path -LiteralPath $outPath) -and -not $overwrite){ $skip++; $log1.AppendText("SKIP (exists): $($f.Name)`r`n"); continue }

                $img = Load-ImageSource $f.FullName
                $bmp = To-Bitmap32 $img
                $img.Dispose(); $img = $null
                $saved = [IconWriter]::SaveIconSizes($bmp,$outPath,$sizes,$stretch,$pad)
                $bmp.Dispose(); $bmp = $null
                if($saved){
                    $ok++
                    if($delOrig){ Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
                } else { $fail++; $log1.AppendText("FAIL: $($f.Name)`r`n") }
            } catch {
                $fail++
                $log1.AppendText("ERR: $($f.Name) - $($_.Exception.Message)`r`n")
                if($bmp){ try { $bmp.Dispose() } catch {} }
                if($img){ try { $img.Dispose() } catch {} }
            }
            $prg1.Value = $i
            if(($i % 3) -eq 0){ Update-Ui }
        }
    } finally {
        $btn1go.Enabled = $true
        $form.UseWaitCursor = $false
    }
    $log1.AppendText("Done. Created: $ok  Skipped: $skip  Failed: $fail`r`n")
    [System.Windows.Forms.MessageBox]::Show("Created: $ok`nSkipped: $skip`nFailed: $fail`n`nOutput: $outDir","ICO Build Complete","OK","Information")
})
$t2 = New-Tab "Icon Recolor"
$tabs.Controls.Add($t2)

$t2.Controls.Add((New-Lbl "Input folder (drag a folder here):" 15 10 300 18))
$txt2src = New-Txt 15 30 560 24
$t2.Controls.Add($txt2src)
Enable-FolderDrop $txt2src
$btn2file = New-Btn "File" 582 29 48 26 $script:C_ACCENT
$t2.Controls.Add($btn2file)
$btn2file.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Title = "Select Individual Icon or Shortcut"
    $d.Filter = "Icons and Shortcuts (*.ico;*.lnk)|*.ico;*.lnk|All Files (*.*)|*.*"
    if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt2src.Text = $d.FileName }
})
$btn2src = New-Btn "Folder" 634 29 55 26 $script:C_ACCENT
$t2.Controls.Add($btn2src)
$btn2src.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt2src.Text = $d.SelectedPath } })

$t2.Controls.Add((New-Lbl "Output folder (blank = same as input):" 15 62 300 18))
$txt2out = New-Txt 15 82 560 24
$t2.Controls.Add($txt2out)
Enable-FolderDrop $txt2out
$btn2out = New-Btn "Browse" 582 81 100 26 $script:C_ACCENT
$t2.Controls.Add($btn2out)
$btn2out.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt2out.Text = $d.SelectedPath } })

$script:col2 = [System.Drawing.Color]::RoyalBlue
$t2.Controls.Add((New-Lbl "Tint color:" 15 116 70 18))
$btn2pick = New-Btn "Pick Color" 92 112 120 28 $script:col2
$t2.Controls.Add($btn2pick)
$pan2swatch = New-Object System.Windows.Forms.Panel
$pan2swatch.Location = New-Object System.Drawing.Point(222,116)
$pan2swatch.Size = New-Object System.Drawing.Size(26,20)
$pan2swatch.BorderStyle = "FixedSingle"
$t2.Controls.Add($pan2swatch)
$lbl2hex = New-Lbl "#4169E1" 256 116 80 18
$lbl2hex.ForeColor = $script:C_MUTED
$t2.Controls.Add($lbl2hex)
$t2.Controls.Add((New-Lbl "Mode:" 350 116 45 18))
$cmb2mode = New-Cmb @("Colorize (keep shading)","Flat fill") 397 114 180
$t2.Controls.Add($cmb2mode)
$t2.Controls.Add((New-Lbl "Suffix:" 15 150 46 18))
$txt2suffix = New-Txt 62 148 100 24
$txt2suffix.Text = "_col"
$t2.Controls.Add($txt2suffix)
$lbl2tip = New-Lbl "Colorize tints bright areas strongly and keeps shadows dark." 175 150 500 18
$lbl2tip.ForeColor = $script:C_MUTED
$t2.Controls.Add($lbl2tip)

$chk2ico = New-Chk ".ICO files" 15 182 90 $true
$t2.Controls.Add($chk2ico)
$chk2lnk = New-Chk ".LNK shortcuts" 115 182 120 $true
$t2.Controls.Add($chk2lnk)
$chk2sub = New-Chk "Search subfolders" 245 182 140 $false
$t2.Controls.Add($chk2sub)
$chk2over = New-Chk "Overwrite existing" 395 182 150 $false
$t2.Controls.Add($chk2over)

$log2 = New-LogBox 15 208 670 138
$log2.Text = "Ready."
$t2.Controls.Add($log2)
$prg2 = New-Progress 15 352 670
$t2.Controls.Add($prg2)
$btn2go = New-Btn "RECOLOR ICONS & SHORTCUTS" 15 376 450 36 $script:C_PRIMARY $true
$t2.Controls.Add($btn2go)
$btn2open = New-Btn "OPEN OUTPUT FOLDER" 480 376 205 36 $script:C_ACCENT
$t2.Controls.Add($btn2open)
$btn2open.Add_Click({ Open-Folder $txt2out.Text })

$btn2pick.Add_Click({
    $cd = New-Object System.Windows.Forms.ColorDialog
    if($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        $script:col2 = $cd.Color
        $btn2pick.BackColor = $script:col2
        if($script:col2.GetBrightness() -gt 0.62){ $btn2pick.ForeColor = [System.Drawing.Color]::Black }
        else { $btn2pick.ForeColor = [System.Drawing.Color]::White }
        $pan2swatch.BackColor = $script:col2
        $lbl2hex.Text = ("#{0:X2}{1:X2}{2:X2}" -f $script:col2.R,$script:col2.G,$script:col2.B)
    }
})
$pan2swatch.BackColor = $script:col2

$btn2go.Add_Click({
    $inDir = $txt2src.Text.Trim().Trim('"').Trim("'")
    if(-not (Test-Path -LiteralPath $inDir)){ [System.Windows.Forms.MessageBox]::Show("Select a valid input file (.ico/.lnk) or folder","Error","OK","Error"); return }
    $isSingle = Test-Path -LiteralPath $inDir -PathType Leaf
    if(-not $chk2ico.Checked -and -not $chk2lnk.Checked){ [System.Windows.Forms.MessageBox]::Show("Select .ICO and/or .LNK","Warning","OK","Warning"); return }
    $outDir = $txt2out.Text.Trim().Trim('"').Trim("'")
    if(-not $outDir){ $outDir = $inDir }
    if(-not (Test-Path -LiteralPath $outDir)){ New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $suffix = $txt2suffix.Text.Trim()
    $mode = $cmb2mode.SelectedIndex
    $color = $script:col2
    $overwrite = $chk2over.Checked
    $recurse = $chk2sub.Checked

    $files = @()
    if($isSingle){
        $files = @(Get-Item -LiteralPath $inDir)
    } else {
        if($chk2ico.Checked){ $files += Get-ImageFiles $inDir @("*.ico") $recurse }
        if($chk2lnk.Checked){ $files += Get-ImageFiles $inDir @("*.lnk") $recurse }
    }
    $files = @($files | Sort-Object FullName -Unique)
    if($files.Count -eq 0){ $log2.Text = "No matching files found."; return }

    $sh = New-Object -ComObject WScript.Shell
    $ok = 0; $fail = 0; $skip = 0; $i = 0
    $prg2.Minimum = 0; $prg2.Maximum = $files.Count; $prg2.Value = 0
    $log2.Clear()
    $log2.AppendText(("Recoloring $($files.Count) item(s) to #{0:X2}{1:X2}{2:X2}...`r`n" -f $color.R,$color.G,$color.B))
    $btn2go.Enabled = $false
    $form.UseWaitCursor = $true
    try {
        foreach($f in $files){
            $i++
            $img = $null; $bmp = $null; $res = $null
            try {
                $destDir = $outDir
                if($recurse){
                    $rel = Get-RelDir $f $inDir
                    if($rel){ $destDir = Join-Path $outDir $rel }
                }
                if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

                if($f.Extension -ieq ".ico"){
                    $targetIco = Join-Path $destDir ($f.BaseName + $suffix + ".ico")
                    if((Test-Path -LiteralPath $targetIco) -and -not $overwrite){ $skip++; $log2.AppendText("SKIP (exists): $($f.Name)`r`n"); continue }
                    $img = Load-ImageSource $f.FullName
                    $bmp = To-Bitmap32 $img
                    $img.Dispose(); $img = $null
                    $res = Tint-Bitmap $bmp $color $mode
                    $bmp.Dispose(); $bmp = $null
                    $saved = [IconWriter]::SaveIconSizes($res,$targetIco,@(16,24,32,48,64,128,256),$true,0)
                    $res.Dispose(); $res = $null
                    if($saved){ $ok++; $log2.AppendText("OK: $($f.Name) -> $(Split-Path $targetIco -Leaf)`r`n") }
                    else { $fail++; $log2.AppendText("FAIL: $($f.Name)`r`n") }
                }
                else {
                    $lnk = $sh.CreateShortcut($f.FullName)
                    $icLoc = $lnk.IconLocation
                    $icPath = ""; $icIdx = 0
                    if($icLoc){
                        $parts = $icLoc -split ','
                        $icPath = $parts[0].Trim('"')
                        if($parts.Count -gt 1){ [int]::TryParse($parts[1].Trim(),[ref]$icIdx) | Out-Null }
                    }
                    if(-not $icPath -or -not (Test-Path -LiteralPath $icPath)){
                        $icPath = $lnk.TargetPath
                        $icIdx = 0
                    }
                    if(-not $icPath -or -not (Test-Path -LiteralPath $icPath)){ $skip++; $log2.AppendText("SKIP (no icon): $($f.Name)`r`n"); continue }

                    $targetLnk = Join-Path $destDir ($f.BaseName + $suffix + ".lnk")
                    $targetIco = Join-Path $destDir ($f.BaseName + $suffix + ".ico")
                    if((Test-Path -LiteralPath $targetLnk) -and -not $overwrite){ $skip++; $log2.AppendText("SKIP (exists): $($f.Name)`r`n"); continue }

                    if([IO.Path]::GetExtension($icPath) -ieq ".ico"){ $img = Load-ImageSource $icPath }
                    else { $img = [IconExtractor]::GetIcon($icPath,$icIdx) }
                    if(-not $img){ $skip++; $log2.AppendText("SKIP (icon unreadable): $($f.Name)`r`n"); continue }

                    $bmp = To-Bitmap32 $img
                    $img.Dispose(); $img = $null
                    $res = Tint-Bitmap $bmp $color $mode
                    $bmp.Dispose(); $bmp = $null
                    $saved = [IconWriter]::SaveIconSizes($res,$targetIco,@(16,24,32,48,64,128,256),$true,0)
                    $res.Dispose(); $res = $null

                    if($saved){
                        $ns = $sh.CreateShortcut($targetLnk)
                        $ns.TargetPath = $lnk.TargetPath
                        $ns.Arguments = $lnk.Arguments
                        $ns.WorkingDirectory = $lnk.WorkingDirectory
                        $ns.WindowStyle = $lnk.WindowStyle
                        $ns.Description = $lnk.Description
                        $ns.Hotkey = $lnk.Hotkey
                        $ns.IconLocation = "`"$targetIco`",0"
                        $ns.Save()
                        $ok++
                        $log2.AppendText("OK: $($f.Name) -> $(Split-Path $targetLnk -Leaf)`r`n")
                    } else { $fail++; $log2.AppendText("FAIL: $($f.Name)`r`n") }
                }
            } catch {
                $fail++
                $log2.AppendText("ERR: $($f.Name) - $($_.Exception.Message)`r`n")
                if($res){ try { $res.Dispose() } catch {} }
                if($bmp){ try { $bmp.Dispose() } catch {} }
                if($img){ try { $img.Dispose() } catch {} }
            }
            $prg2.Value = $i
            if(($i % 3) -eq 0){ Update-Ui }
        }
    } finally {
        $btn2go.Enabled = $true
        $form.UseWaitCursor = $false
    }
    $log2.AppendText("Done. Recolored: $ok  Skipped: $skip  Failed: $fail`r`n")
    [System.Windows.Forms.MessageBox]::Show("Recolored: $ok`nSkipped: $skip`nFailed: $fail`n`nOutput: $outDir","Recolor Complete","OK","Information")
})
$t3 = New-Tab "Color Variants"
$tabs.Controls.Add($t3)

$script:src3 = $null
$script:previewImg = $null
$script:out3 = Join-Path ([Environment]::GetFolderPath("MyPictures")) "DG_ColorVariants"
if(-not (Test-Path -LiteralPath $script:out3)){ New-Item -ItemType Directory -Path $script:out3 -Force | Out-Null }

$btn3a = New-Btn "SELECT IMAGE" 15 15 135 30 $script:C_ACCENT
$t3.Controls.Add($btn3a)
$lbl3path = New-Lbl "No file selected (or drag an image onto the preview)" 158 21 245 18
$lbl3path.ForeColor = $script:C_MUTED
$t3.Controls.Add($lbl3path)

$pic3 = New-Object System.Windows.Forms.PictureBox
$pic3.Location = New-Object System.Drawing.Point(420,12)
$pic3.Size = New-Object System.Drawing.Size(265,140)
$pic3.BackColor = $script:C_LOG
$pic3.BorderStyle = "FixedSingle"
$pic3.SizeMode = "Zoom"
$t3.Controls.Add($pic3)

$t3.Controls.Add((New-Lbl "Format:" 15 58 50 18))
$cmb3 = New-Cmb @("PNG","JPG","BMP","GIF","TIFF","ICO") 68 56 85
$t3.Controls.Add($cmb3)
$t3.Controls.Add((New-Lbl "Quality:" 166 58 52 18))
$num3q = New-Num 220 56 58 1 100 95
$t3.Controls.Add($num3q)

$t3.Controls.Add((New-Lbl "Output:" 15 92 50 18))
$txt3out = New-Txt 68 90 355 24
$txt3out.Text = $script:out3
$t3.Controls.Add($txt3out)
Enable-FolderDrop $txt3out
$btn3b = New-Btn "Change" 430 89 90 26 $script:C_ACCENT
$t3.Controls.Add($btn3b)

$t3.Controls.Add((New-Lbl "Palette (click colors to toggle, click more to multi-select):" 15 148 420 18))
$lbl3count = New-Lbl "" 520 148 165 18
$lbl3count.ForeColor = $script:C_MUTED
$t3.Controls.Add($lbl3count)

$script:palColors = [ordered]@{
    "blue"="#0088FF"; "navy"="#001F7A"; "sky"="#87CEEB"; "cyan"="#00FFFF"; "turquoise"="#40E0D0"; "teal"="#008080";
    "emerald"="#50C878"; "green"="#00CC44"; "lime"="#32CD32"; "olive"="#808000"; "forest"="#228B22"; "yellow"="#FFD700";
    "gold"="#FFC000"; "orange"="#FF8C00"; "coral"="#FF7F50"; "red"="#FF2222"; "crimson"="#DC143C"; "rose"="#FF4080";
    "pink"="#FF69B4"; "magenta"="#FF00CC"; "fuchsia"="#FF00FF"; "purple"="#9370DB"; "violet"="#8A2BE2"; "indigo"="#4B0082";
    "lavender"="#B57EDC"; "brown"="#8B5A2B"; "tan"="#D2B48C"; "silver"="#C0C0C0"; "graphite"="#4B4B4B"; "white"="#FFFFFF"; "black"="#000000"
}

function H2C {
    param([string]$h)
    $h = $h.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(255,[Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16))
}

$palette = New-Object System.Windows.Forms.ListBox
$palette.Location = New-Object System.Drawing.Point(15,170)
$palette.Size = New-Object System.Drawing.Size(385,150)
$palette.BackColor = $script:C_LOG
$palette.ForeColor = $script:C_TEXT
$palette.BorderStyle = "FixedSingle"
$palette.DrawMode = "OwnerDrawFixed"
$palette.ItemHeight = 22
$palette.SelectionMode = "MultiSimple"
$palette.IntegralHeight = $false
foreach($k in $script:palColors.Keys){ $palette.Items.Add($k) | Out-Null }
$t3.Controls.Add($palette)

$palette.Add_DrawItem({
    param($sender,$e)
    if($e.Index -lt 0){ return }
    $g = $e.Graphics
    $rect = $e.Bounds
    $item = $sender.Items[$e.Index]
    $col = $script:palColors[$item]
    $bg = New-Object System.Drawing.SolidBrush($script:C_LOG)
    $g.FillRectangle($bg,$rect)
    $bg.Dispose()
    $sb = New-Object System.Drawing.SolidBrush($col)
    $g.FillRectangle($sb,$rect.X+4,$rect.Y+3,20,$rect.Height-6)
    $sb.Dispose()
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90,90,90))
    $g.DrawRectangle($pen,$rect.X+4,$rect.Y+3,20,$rect.Height-6)
    $pen.Dispose()
    $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.DrawString($item,$e.Font,$tb,$rect.X+32,$rect.Y+4)
    $tb.Dispose()
    if(($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0){
        $hp = New-Object System.Drawing.Pen($script:C_ACCENT,1)
        $g.DrawRectangle($hp,$rect.X,$rect.Y,$rect.Width-1,$rect.Height-1)
        $hp.Dispose()
    }
})

$btn3all = New-Btn "Select All" 410 170 110 26 $script:C_ACCENT
$t3.Controls.Add($btn3all)
$btn3clear = New-Btn "Clear" 410 202 110 26 $script:C_ACCENT
$t3.Controls.Add($btn3clear)
$btn3custom = New-Btn "Add Custom" 410 234 110 26 $script:C_ACCENT
$t3.Controls.Add($btn3custom)

$log3 = New-LogBox 15 330 670 72
$log3.Text = "Ready."
$t3.Controls.Add($log3)
$prg3 = New-Progress 15 408 670
$t3.Controls.Add($prg3)
$btn3go = New-Btn "GENERATE VARIANTS" 15 432 450 36 $script:C_PRIMARY $true
$t3.Controls.Add($btn3go)
$btn3open = New-Btn "OPEN OUTPUT FOLDER" 480 432 205 36 $script:C_ACCENT
$t3.Controls.Add($btn3open)
$btn3open.Add_Click({ Open-Folder $txt3out.Text })

function Select-AllPalette {
    for($i=0;$i -lt $palette.Items.Count;$i++){ $palette.SetSelected($i,$true) }
    $lbl3count.Text = "$($palette.SelectedItems.Count) of $($palette.Items.Count) selected"
}

function Set-BaseImage {
    param([string]$path)
    try {
        if($pic3.Image){ $pic3.Image = $null }
        if($script:previewImg){ $script:previewImg.Dispose(); $script:previewImg = $null }
        $im = Load-ImageSource $path
        $script:previewImg = $im
        $script:src3 = $path
        $pic3.Image = $im
        $lbl3path.Text = Split-Path -Leaf $path
        $lbl3path.ForeColor = $script:C_TEXT
        $log3.Text = "Loaded: $path"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not load image: $($_.Exception.Message)","Error","OK","Error")
    }
}

$btn3a.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff;*.ico|All files|*.*"
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ Set-BaseImage $dlg.FileName }
})
$btn3b.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ $txt3out.Text = $d.SelectedPath } })
$btn3all.Add_Click({ Select-AllPalette })
$btn3clear.Add_Click({ $palette.ClearSelected(); $lbl3count.Text = "0 of $($palette.Items.Count) selected" })
$palette.Add_SelectedIndexChanged({ $lbl3count.Text = "$($palette.SelectedItems.Count) of $($palette.Items.Count) selected" })
$btn3custom.Add_Click({
    $cd = New-Object System.Windows.Forms.ColorDialog
    if($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        $n = 1
        while($script:palColors.Contains("custom$n")){ $n++ }
        $name = "custom$n"
        $script:palColors[$name] = $cd.Color
        $palette.Items.Add($name) | Out-Null
        $palette.SetSelected($palette.Items.Count-1,$true)
        $lbl3count.Text = "$($palette.SelectedItems.Count) of $($palette.Items.Count) selected"
    }
})

$palKeys = @($script:palColors.Keys)
foreach($k in $palKeys){ $script:palColors[$k] = H2C $script:palColors[$k] }
Select-AllPalette

$pic3.AllowDrop = $true
$pic3.Add_DragEnter({ param($sender,$e) if($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)){ $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy } })
$pic3.Add_DragDrop({
    param($sender,$e)
    $items = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if($items -and $items.Count -gt 0){ Set-BaseImage $items[0] }
})

$btn3go.Add_Click({
    if(-not $script:src3 -or -not (Test-Path -LiteralPath $script:src3)){ [System.Windows.Forms.MessageBox]::Show("Select a base image first","Error","OK","Error"); return }
    $outDir = $txt3out.Text.Trim().Trim('"').Trim("'")
    if(-not $outDir){ $outDir = $script:out3 }
    if(-not (Test-Path -LiteralPath $outDir)){ New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $chosen = @($palette.SelectedItems)
    if($chosen.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select at least one palette color","Warning","OK","Warning"); return }

    $target = $cmb3.SelectedItem.ToString().ToLower()
    $quality = [int]$num3q.Value
    $base = [IO.Path]::GetFileNameWithoutExtension($script:src3)
    $img = $null; $bmp = $null
    try {
        $img = Load-ImageSource $script:src3
        $bmp = To-Bitmap32 $img
        $img.Dispose(); $img = $null

        $ok = 0; $fail = 0; $i = 0
        $prg3.Minimum = 0; $prg3.Maximum = $chosen.Count; $prg3.Value = 0
        $log3.Clear()
        $log3.AppendText("Generating $($chosen.Count) variant(s) as $($target.ToUpper())...`r`n")
        $btn3go.Enabled = $false
        $form.UseWaitCursor = $true
        try {
            foreach($name in $chosen){
                $i++
                $res = $null
                try {
                    $c = $script:palColors[$name]
                    $res = [ImageOps]::Tint($bmp,$c)
                    $outPath = Join-Path $outDir ("$base-$name.$target")
                    $saved = Save-BitmapAs $res $outPath $target $quality
                    if($saved){ $ok++ }
                    else { $fail++; $log3.AppendText("FAIL: $name`r`n") }
                    $res.Dispose(); $res = $null
                } catch {
                    $fail++
                    $log3.AppendText("ERR: $name - $($_.Exception.Message)`r`n")
                    if($res){ try { $res.Dispose() } catch {} }
                }
                $prg3.Value = $i
                if(($i % 3) -eq 0){ Update-Ui }
            }
        } finally {
            $btn3go.Enabled = $true
            $form.UseWaitCursor = $false
        }
    } finally {
        if($bmp){ $bmp.Dispose() }
        if($img){ $img.Dispose() }
    }
    $log3.AppendText("Done. Created: $ok  Failed: $fail`r`n")
    [System.Windows.Forms.MessageBox]::Show("Created: $ok`nFailed: $fail`n`nOutput: $outDir","Variants Complete","OK","Information")
})

$btnInst = New-Btn "CREATE DESKTOP SHORTCUT" 20 620 730 40 $script:C_GOLD $true
$form.Controls.Add($btnInst)

$btnInst.Add_Click({
    try {
        $scriptPath = $PSCommandPath
        if(-not $scriptPath){ $scriptPath = $MyInvocation.MyCommand.Path }
        $scriptDir = Split-Path -Parent $scriptPath
        $lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "DGs Image Tools.lnk"
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnk)
        $sc.TargetPath = "powershell.exe"
        $sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File `"$scriptPath`""
        $sc.WorkingDirectory = $scriptDir
        $icon = Join-Path $scriptDir "DG-Visual-Toolkit.ico"
        if(Test-Path -LiteralPath $icon){ $sc.IconLocation = "`"$icon`",0" }
        $sc.Description = "DGs Image Tools v2"
        $sc.Save()
        [System.Windows.Forms.MessageBox]::Show("Desktop shortcut created:`n$lnk","Success","OK","Information")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $_","Error","OK","Error")
    }
})

$form.Add_FormClosed({
    if($script:previewImg){ try { $script:previewImg.Dispose() } catch {} }
})

$script:designW = $form.ClientSize.Width
$script:designH = $form.ClientSize.Height
$script:baseBounds = @{}
$script:baseFonts = @{}
$script:liveFonts = @{}

function Capture-Layout {
    param([System.Windows.Forms.Control]$parent)
    foreach($c in $parent.Controls){
        $script:baseBounds[$c] = New-Object System.Drawing.Rectangle($c.Left,$c.Top,$c.Width,$c.Height)
        $script:baseFonts[$c] = $c.Font
        if($c.Controls.Count -gt 0){ Capture-Layout $c }
    }
}

function Apply-Layout {
    param([System.Windows.Forms.Control]$parent,[double]$sx,[double]$sy,[double]$fs)
    foreach($c in $parent.Controls){
        $b = $script:baseBounds[$c]
        if($null -ne $b -and -not ($c -is [System.Windows.Forms.TabPage])){
            $c.SetBounds([int][Math]::Round($b.X*$sx),[int][Math]::Round($b.Y*$sy),[Math]::Max(1,[int][Math]::Round($b.Width*$sx)),[Math]::Max(1,[int][Math]::Round($b.Height*$sy)))
        }
        $bf = $script:baseFonts[$c]
        if($null -ne $bf -and -not ($c -is [System.Windows.Forms.TabControl]) -and -not ($c -is [System.Windows.Forms.TabPage])){
            try {
                if($script:liveFonts.ContainsKey($c)){ $script:liveFonts[$c].Dispose(); $script:liveFonts.Remove($c) }
                if([Math]::Abs($fs-1) -gt 0.001){
                    $nf = New-Object System.Drawing.Font($bf.FontFamily,[single]([Math]::Max(1,($bf.Size*$fs))),$bf.Style,$bf.Unit)
                    $script:liveFonts[$c] = $nf
                    $c.Font = $nf
                } else {
                    $c.Font = $bf
                }
            } catch {}
        }
        if($c.Controls.Count -gt 0){ Apply-Layout $c $sx $sy $fs }
    }
}

Capture-Layout $form
$form.Add_Resize({
    if($form.WindowState -eq "Minimized"){ return }
    $sx = $form.ClientSize.Width / [double]$script:designW
    $sy = $form.ClientSize.Height / [double]$script:designH
    Apply-Layout $form $sx $sy ([Math]::Min($sx,$sy))
})

[System.Windows.Forms.Application]::Run($form)
