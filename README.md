# DG Command Center 1.1.0

One refreshed Windows dashboard for the DG Visual Toolkit and the source-based utilities from DGs Command Center. The unified home screen brings search, quick filters, live tool counts, theme selection, favorites, launch activity, and shortcuts together.

## Run from source

On Windows 10 or 11, install Python 3 with Tkinter and Windows PowerShell 5.1, then run:

```powershell
py -3 main.py
```

No Python packages need to be installed. Keep the `tools` and `assets` folders beside `main.py`; the launcher uses those paths to find the scripts and icons.

## Build the Windows installer

Install Python 3, PyInstaller (`py -3 -m pip install pyinstaller`), and Inno Setup 6, then run from the project folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

The script generates the multi-size `assets\DG-Command-Center.ico`, packages the dashboard and source tools as a Windows app, and compiles the per-user installer. Find the setup executable under `dist\installer`. Installer settings are stored in `%LOCALAPPDATA%\DG Command Center`; the source-run configuration remains beside `main.py`.

The visual refresh adds a welcome panel, live readiness/system/favorites counts, improved spacing, and an updated application identity. The release version is **1.1.0**.

## Included tools

The dashboard combines image and desktop utilities from DG Visual Toolkit 3.1.0 with source utilities from DGs Command Center 1.1 and DGS Suite 1.0.4. The catalog includes image/icon conversion and recoloring, folder search, Explorer tools, file renamers, Windows appearance tools, environment setup, and system maintenance.

The original Command Center launcher is replaced by this dashboard rather than nested inside it. Only source scripts, their small icon assets, and relevant upstream documentation are included. Compiled applications, installers, release/build folders, and caches were intentionally left out; binary-only cards from the original Visual Toolkit catalog were removed so every listed tool has a source file in this repository.

Use the search box or the **GUI**, **CONSOLE**, **ADMIN**, and **FAVORITES** filters to find tools. Use **Settings & Preferences** to change the theme, paths, launch confirmations, and favorites.

## Safety

Opening the dashboard does not run any tools. Tool cards launch the included upstream script or batch file only when selected. Review a script before running it, especially system-changing utilities:

- **ADMIN** tools request Windows elevation (UAC). Debloat utilities can remove apps or change settings; make a restore point and review selections first.
- The environment setup tools can install software through winget. Use the planner's plan mode to inspect proposed commands before installing.
- Power Plan downloads and activates a power profile. DGS WinUtil can launch an upstream script from the internet; verify its source and contents before use.
- Some tools require an internet connection or additional Windows components. The launcher does not install dependencies automatically.

Building the installer packages the source tools but does not run them. No installer or OS-tuning action runs until a user explicitly starts it.

## Attribution and licensing

The dashboard is based on the DG Visual Toolkit 3.1.0 source (author attribution retained in `main.py`) and incorporates selected source utilities and documentation from DGs Command Center 1.1 / DGS Suite 1.0.4. Individual source headers retain their original attribution. No license file was present in either supplied archive, so licensing terms for the upstream code and assets remain unspecified; check with the respective authors before redistribution.
