DGs image tools 1.2.0
=====================

A small Windows toolkit for Explorer, cleanup and power settings. Everything runs
locally from this folder.

Quick start
-----------
1. Open "DGs image tools" from the Desktop or the Start menu.
2. Choose a tool from the launcher.
3. Follow the prompts in the tool window or console.

Contents
--------
DGs image tools.exe            Launcher for the whole suite
DGs Explorer Toolkit.exe       GUI for the Explorer toolkit
ExplorerToolkit-3.1.2.ps1      Explorer views, options, context menus, renaming
HardenedToolkit-2.5.1.ps1      Cleaner, duplicate finder, scanner, uninstaller
insopti-PowerPlan-1.1.1.ps1    Import and activate a power plan
RenameTool-2.1.1.ps1           Safe batch renamer
icons\                         Icons used by shortcuts and the apps
README.txt                     This file

Tools
-----
Explorer Toolkit
  Reset or restore folder views, apply or revert Explorer options, rebuild the
  icon cache, reset Quick Access, manage context-menu extras, find duplicates,
  browse files and batch-rename copy suffixes.

Hardened Toolkit
  Opens in an elevated console. Includes the cleaner, duplicate finder, scanner
  and uninstall helper. Read each prompt before continuing.

insopti PowerPlan
  Imports and activates the included power plan. Opens in an elevated console.

Rename Tool
  Preview and apply safe batch renames with undo support.

Where your data lives
---------------------
Backups, saved searches, logs and generated icons are kept outside the program
folder so they survive updates:

  %LOCALAPPDATA%\DGsImageTools

Explorer Toolkit registry backups are in:

  %LOCALAPPDATA%\DGsImageTools\Backups

Shortcuts
---------
Desktop:  DGs image tools
Start menu: DGs image tools
  - DGs image tools (launcher)
  - DGs Explorer Toolkit
  - DGs Hardened Toolkit
  - DGs insopti PowerPlan
  - DGs Rename Tool
  - DGs image tools Read Me
  - Uninstall DGs image tools

Uninstall
---------
Use Start menu > DGs image tools > Uninstall DGs image tools, or the Uninstall
button in the launcher. Backups and logs in %LOCALAPPDATA% are kept.

Notes
-----
- The tools run with -NoProfile -ExecutionPolicy Bypass for that process only.
  They do not change your system-wide execution policy.
- Some actions restart Explorer or request administrator rights. Save your work
  before running them.
- Explorer Toolkit writes backups before changing views or context menus.
- If Windows asks about running scripts, allow the local scripts in this folder.

DGs image tools 1.2.0
