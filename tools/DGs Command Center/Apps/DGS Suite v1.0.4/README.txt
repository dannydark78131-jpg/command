DGS SUITE — v1.0.4 FIXED
=========================

WHAT WAS FIXED (from errors.txt)
--------------------------------
1. DGS.Renamer — CRASH FIXED. Clicking "Browse" with an empty folder field
   threw "Cannot bind argument to parameter 'Path' because it is an empty
   string." Root cause: Test-Path received an empty string. Guarded with a
   null/whitespace check. Also added a global error handler so future errors
   show a friendly message instead of the JIT "Continue/Quit" dialog.
   Version shown in title bar: v1.0.4.

2. DGS.WinUtil — "does nothing" FIXED. Root cause: (a) $ScriptDir resolved to
   the current working directory when compiled to .exe, so it could not find
   its own files; (b) the launch button tried to launch itself (no full
   WinUtil was bundled). Now the "Launch Full WinUtil" button runs the official
   Chris Titus Tech WinUtil (iwr christitus.com/win.ps1 | iex) elevated. Added
   quick actions: Create Restore Point, Winget Upgrade All, Install Winget,
   Open Windows Update, Open Installed Apps. All run elevated.

3. DGS.Debloat — GUI updated + features added. Was a shell: a list of 4 apps
   with NO remove button. Now: 26 curated bloat apps, Select All / Clear,
   "Create restore point first" checkbox (default on), "Remove Selected"
   button (runs elevated, logs to %APPDATA%\DGS Debloat\logs), and a working
   "Open Full Debloat GUI" button (launches DGS.WINDOWS10-DEBLOAT-GUI.ps1).

4. DGS.SetupEnv (Environment) — features added. Was Scan-only (no install).
   Now: 12 tools (Git, Python 3.12, VS Code, GitHub CLI, Node LTS, PowerShell
   7, 7-Zip, PowerToys, .NET 8 SDK, JDK 21, Docker Desktop, WSL), Scan with
   installed/missing detection, "Select Missing", "Install Selected" via
   winget (elevated), working "Open Full Script" button. Checks for winget
   and warns if missing.

5. ROOT CAUSE fixed across all tools: $ScriptDir / $dir resolution. When
   compiled to .exe, $PSScriptRoot is empty; the old code fell back to the
   current directory (often System32), so every "launch external script"
   button silently failed. All tools now fall back to the actual .exe
   location via Process.MainModule.FileName. Also removed hardcoded developer
   paths (C:\Users\DG\Desktop\...) from DGS.AppLauncher.

HOW TO USE
----------
1. On Windows, run  INSTALL-PREREQUISITES.bat  (one time) — checks .NET 4.8,
   installs the ps2exe module, checks winget.
2. Run  COMPILE.bat  — rebuilds ALL .exe files with the fixed .ps1 sources,
   version 1.0.4. (The .exe files in this zip are still the OLD v1.0.2 builds;
   the fixes live in the .ps1 source files and must be compiled. You cannot
   compile on this Linux machine — that's why COMPILE.bat is included.)
3. The fixed .ps1 files can also be run directly: right-click > Run with
   PowerShell, or: powershell -ExecutionPolicy Bypass -File DGS.Renamer.ps1

FILES
-----
Fixed/rewritten .ps1 sources: DGS.WINUTIL.ps1, DGS.Debloat.ps1,
DGS.SetupEnv.ps1, DGS.Renamer.ps1 (patched), DGS.AppLauncher.ps1 (patched),
DGS.LightTheme.ps1 (patched), DGS.Suite.Installer.ps1 (patched).
Unchanged (launched by the tools above): DGS.WINDOWS10-DEBLOAT-GUI.ps1,
DGS.SETUP-ENV.ps1.
New: INSTALL-PREREQUISITES.bat, COMPILE.bat, this README.

ADDING MORE APPS LATER
----------------------
Drop a new .ps1 + .ico in this folder, add one line to COMPILE.bat
(follow the existing pattern), and re-run it. The windows-codegen skill's
templates (bootstrap.ps1, launcher.bat, installer.iss) can scaffold the
next app quickly.
