# Снимок окна 1С без вывода его на передний план (PrintWindow), с заданным размером окна.
# Запуск: capture.ps1 -Title "Загрузка прайса" -Out C:\...\shot.png [-Width 1600 -Height 900]
param([string]$Title, [string]$Out, [int]$Width = 1600, [int]$Height = 900, [int]$ProcessId = 0)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class Cap {
  public delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public static IntPtr Find(uint pid, string part) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
        if (sb.ToString().Contains(part)) { found = h; return false; } }
      return true; }, IntPtr.Zero);
    return found;
  }
}
"@
[Cap]::SetProcessDPIAware() | Out-Null
# -ProcessId нужен, когда открыто несколько 1С (например, на разных базах).
$p = if ($ProcessId -gt 0) { Get-Process -Id $ProcessId -ErrorAction Stop } else { Get-Process 1cv8t -ErrorAction Stop | Select-Object -First 1 }
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 60 -and $h -eq [IntPtr]::Zero; $i++) { $h = [Cap]::Find([uint32]$p.Id, $Title); if ($h -eq [IntPtr]::Zero) { Start-Sleep 1 } }
if ($h -eq [IntPtr]::Zero) { "окно «$Title» не найдено"; exit 1 }
[Cap]::ShowWindow($h, 4) | Out-Null   # SW_SHOWNOACTIVATE: из свёрнутого в обычное, не активируя
[Cap]::SetWindowPos($h, [IntPtr]::Zero, 40, 40, $Width, $Height, 0x0014) | Out-Null  # SWP_NOZORDER | SWP_NOACTIVATE
Start-Sleep -Milliseconds 1500
$r = New-Object Cap+RECT; [Cap]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L; $hh = $r.B - $r.T
$bmp = New-Object Drawing.Bitmap $w, $hh
$g = [Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
[Cap]::PrintWindow($h, $dc, 2) | Out-Null
$g.ReleaseHdc($dc); $g.Dispose()
# Рамку окна (тень Windows 10) обрезаем.
$crop = $bmp.Clone((New-Object Drawing.Rectangle 8, 0, ($w - 16), ($hh - 8)), $bmp.PixelFormat)
$crop.Save($Out, [Drawing.Imaging.ImageFormat]::Png)
"снимок $Out ($($crop.Width)x$($crop.Height))"
