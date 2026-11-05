"""
DG Command Center - Unified Windows utility hub
Version: 1.1.0
Author: DG
"""

import base64
import ctypes
import json
import os
import shutil
import subprocess
import sys
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

# --- High DPI Awareness for Crisp Windows 10/11 Rendering ---
def enable_high_dpi():
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        try:
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass

enable_high_dpi()

APP_TITLE = "DG Command Center"
FALLBACK_VERSION = "1.1.0"

CREATE_NO_WINDOW = 0x08000000
CREATE_NEW_CONSOLE = 0x00000010

FONT_FAMILY = "Segoe UI"
FONT_MONO = "Consolas"

# --- Curated Modern Themes ---
THEMES = {
    "Dark Modern": {
        "bg": "#0c141d",
        "header_bg": "#101b26",
        "panel": "#152230",
        "panel_hover": "#1c2e42",
        "panel_line": "#23374d",
        "log_bg": "#080d13",
        "text": "#ffffff",
        "text_muted": "#94a3b8",
        "accent": "#00d2ff",
        "accent_hover": "#38bdf8",
        "primary": "#00b894",
        "primary_hover": "#00d8a4",
        "gold": "#fbc531",
        "danger": "#ff5252",
        "card_bg": "#152230",
        "input_bg": "#0e1823",
    },
    "Obsidian Gold": {
        "bg": "#111215",
        "header_bg": "#17181d",
        "panel": "#1c1e24",
        "panel_hover": "#252830",
        "panel_line": "#2f333d",
        "log_bg": "#0a0a0c",
        "text": "#f8fafc",
        "text_muted": "#a1a1aa",
        "accent": "#f59e0b",
        "accent_hover": "#fbbf24",
        "primary": "#d97706",
        "primary_hover": "#f59e0b",
        "gold": "#fbbf24",
        "danger": "#ef4444",
        "card_bg": "#1c1e24",
        "input_bg": "#14151a",
    },
    "Midnight Neon": {
        "bg": "#0f0d1b",
        "header_bg": "#151226",
        "panel": "#1b1731",
        "panel_hover": "#252042",
        "panel_line": "#302958",
        "log_bg": "#08070e",
        "text": "#ffffff",
        "text_muted": "#a5b4fc",
        "accent": "#a855f7",
        "accent_hover": "#c084fc",
        "primary": "#06b6d4",
        "primary_hover": "#22d3ee",
        "gold": "#f472b6",
        "danger": "#f43f5e",
        "card_bg": "#1b1731",
        "input_bg": "#120f21",
    },
    "Emerald Slate": {
        "bg": "#091612",
        "header_bg": "#0d1f19",
        "panel": "#112620",
        "panel_hover": "#18362d",
        "panel_line": "#20463b",
        "log_bg": "#050d0a",
        "text": "#ecfdf5",
        "text_muted": "#6ee7b7",
        "accent": "#10b981",
        "accent_hover": "#34d399",
        "primary": "#059669",
        "primary_hover": "#10b981",
        "gold": "#f59e0b",
        "danger": "#f87171",
        "card_bg": "#112620",
        "input_bg": "#0b1a15",
    },
    "Nordic Slate": {
        "bg": "#1b1e24",
        "header_bg": "#21252d",
        "panel": "#262b35",
        "panel_hover": "#303643",
        "panel_line": "#3b4252",
        "log_bg": "#131519",
        "text": "#eceff4",
        "text_muted": "#9da5b4",
        "accent": "#88c0d0",
        "accent_hover": "#81a1c1",
        "primary": "#5e81ac",
        "primary_hover": "#81a1c1",
        "gold": "#ebcb8b",
        "danger": "#bf616a",
        "card_bg": "#262b35",
        "input_bg": "#1e222a",
    },
}

DEFAULT_THEME = "Dark Modern"


class Tool:
    def __init__(self, name, description, filename, tag, console=False, admin=False, icon_name=None, is_custom=False):
        self.name = name
        self.description = description
        self.filename = filename
        self.tag = tag
        self.console = console
        self.admin = admin
        self.icon_name = icon_name
        self.is_custom = is_custom

    def to_dict(self):
        return {
            "name": self.name,
            "description": self.description,
            "filename": self.filename,
            "tag": self.tag,
            "console": self.console,
            "admin": self.admin,
            "icon_name": self.icon_name,
            "is_custom": self.is_custom,
        }

    @classmethod
    def from_dict(cls, data):
        return cls(
            name=data.get("name", "Unnamed Tool"),
            description=data.get("description", ""),
            filename=data.get("filename", ""),
            tag=data.get("tag", "CUSTOM"),
            console=data.get("console", False),
            admin=data.get("admin", False),
            icon_name=data.get("icon_name"),
            is_custom=data.get("is_custom", True),
        )


BUILTIN_TOOLS = [
    Tool(
        name="Image Tools v2",
        description="Convert images, build multi-size ICOs, recolor icons and shortcuts, create color variants.",
        filename="DGs Image Tools-V2.AMAZING.ps1",
        tag="GUI",
        icon_name="Image Tools v2_coloured.ico",
    ),
    Tool(
        name="Icon & Shortcut Changer",
        description="Recolor individual .ico files or entire folders, and update .lnk shortcut icons (supports embedded icons).",
        filename="Icon-Color-Changer.v2.PS1",
        tag="GUI",
        icon_name="DG-Visual-Toolkit.ico",
    ),
    Tool(
        name="Color Variant Generator",
        description="Generate a full palette of recolored copies from one base image.",
        filename="DG_Color_GeneratoV2.ps1",
        tag="GUI",
        icon_name="Color Variant Generator_coloured.ico",
    ),
    Tool(
        name="Folder Searcher",
        description="Fast folder and file search with saved settings and interactive menus.",
        filename="DGs Searcher.bat",
        tag="CONSOLE",
        console=True,
        icon_name="DGs Searcher.ico",
    ),
    Tool(
        name="Explorer Toolkit v3",
        description="Explorer view reset, context-menu backup, icon cache rebuild, duplicates, renamer.",
        filename="ExplorerToolkit_v3.ps1",
        tag="CONSOLE",
        console=True,
        icon_name="explorer-toolkit-v3.ico",
    ),
    Tool(
        name="Fix Desktop Icons",
        description="Repair broken shortcut overlays and rebuild the Windows icon cache (Run as Admin).",
        filename="FixIcons.ps1",
        tag="ADMIN",
        console=True,
        admin=True,
        icon_name="Fix Desktop Icons_coloured.ico",
    ),
    Tool(
        name="Image Tools v1 (Legacy)",
        description="Classic version of the image converter and ICO builder.",
        filename="DGs Image Tools-LATEST.ps1",
        tag="GUI",
        icon_name="DG-Visual-Toolkit.ico",
    ),
    Tool(
        name="Convert Script to Light Theme",
        description="Create a light-theme version of a selected PowerShell or text script.",
        filename=r"DGs Command Center\Apps\Convert to Light Theme\Convert-To-LightTheme.ps1",
        tag="GUI",
        icon_name="DG-Visual-Toolkit.ico",
    ),
    Tool(
        name="DGS Renamer",
        description="Preview and batch-rename files using the DGS Suite renamer.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.Renamer.ps1",
        tag="GUI",
        icon_name=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.Renamer.ico",
    ),
    Tool(
        name="Rename Tool 2.1.1",
        description="Preview-first batch renaming with find/replace, prefixes, suffixes, and case changes.",
        filename=r"DGs Command Center\Apps\DGs Image Tools\RenameTool-2.1.1.ps1",
        tag="GUI",
        icon_name=r"DGs Command Center\Apps\DGs Image Tools\icons\Rename.ico",
    ),
    Tool(
        name="Explorer Toolkit 3.1.2",
        description="Explorer settings, context-menu backups, duplicate finder, and file tools.",
        filename=r"DGs Command Center\Apps\DGs Image Tools\ExplorerToolkit-3.1.2.ps1",
        tag="CONSOLE",
        console=True,
        icon_name=r"DGs Command Center\Apps\DGs Image Tools\icons\Explorer.ico",
    ),
    Tool(
        name="Hardened Toolkit 2.5.1",
        description="System cleanup, duplicate finding, and uninstall utilities; review actions before use.",
        filename=r"DGs Command Center\Apps\DGs Image Tools\HardenedToolkit-2.5.1.ps1",
        tag="ADMIN",
        admin=True,
        icon_name=r"DGs Command Center\Apps\DGs Image Tools\icons\Hardened.ico",
    ),
    Tool(
        name="DGS Light Theme",
        description="DGS Suite utility for switching Windows appearance settings.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.LightTheme.ps1",
        tag="GUI",
        icon_name=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.LightTheme.ico",
    ),
    Tool(
        name="DGS Debloat",
        description="Selectively remove bundled Windows apps; review selections and create a restore point first.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.Debloat.ps1",
        tag="ADMIN",
        admin=True,
        icon_name=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.Debloat.ico",
    ),
    Tool(
        name="Windows Debloat GUI",
        description="Windows app and privacy-tweak manager; review every selected change before applying.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.WINDOWS10-DEBLOAT-GUI.ps1",
        tag="ADMIN",
        admin=True,
        icon_name=r"DG-Visual-Toolkit.ico",
    ),
    Tool(
        name="DGS Environment Setup",
        description="Detect and install developer tools through winget; installation changes this PC.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.SetupEnv.ps1",
        tag="ADMIN",
        admin=True,
        icon_name=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.SetupEnv.ico",
    ),
    Tool(
        name="DGS Environment Planner",
        description="Plan or install developer tools; use its plan mode to review commands before installation.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.SETUP-ENV.ps1",
        tag="ADMIN",
        console=True,
        admin=True,
        icon_name=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.SetupEnv.ico",
    ),
    Tool(
        name="DGS WinUtil",
        description="System maintenance shortcuts and an elevated launch of the upstream WinUtil script.",
        filename=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.WINUTIL.ps1",
        tag="ADMIN",
        admin=True,
        icon_name=r"DGs Command Center\Apps\DGS Suite v1.0.4\DGS.WinUtil.ico",
    ),
    Tool(
        name="Power Plan 1.1.1",
        description="Download and activate a power plan from its upstream GitHub release.",
        filename=r"DGs Command Center\Apps\DGs Image Tools\insopti-PowerPlan-1.1.1.ps1",
        tag="ADMIN",
        admin=True,
        icon_name=r"DGs Command Center\Apps\DGs Image Tools\icons\insopti.ico",
    ),
]


def base_dir():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def resource_dir():
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        return Path(meipass)
    return base_dir()


class ConfigManager:
    DEFAULT_CONFIG = {
        "app_name": APP_TITLE,
        "version": FALLBACK_VERSION,
        "author": "DG",
        "theme": DEFAULT_THEME,
        "tools_dir": "",
        "shortcuts_dir": "",
        "confirm_admin": True,
        "confirm_launch": False,
        "log_timestamps": True,
        "max_log_lines": 300,
        "favorites": ["Image Tools v2", "Icon & Shortcut Changer"],
        "custom_tools": [],
        "ui": {
            "remember_window": True,
            "last_filter": "ALL",
            "search_on_type": True,
        },
    }

    def __init__(self):
        if getattr(sys, "frozen", False):
            user_data = Path(os.environ.get("LOCALAPPDATA", Path.home()))
            self.path = user_data / "DG Command Center" / "config.json"
        else:
            self.path = base_dir() / "config.json"
        self.data = self.load()

    def load(self):
        config = dict(self.DEFAULT_CONFIG)
        if self.path.is_file():
            try:
                with self.path.open("r", encoding="utf-8") as f:
                    loaded = json.load(f)
                    if isinstance(loaded, dict):
                        config.update(loaded)
            except Exception:
                pass
        config["version"] = FALLBACK_VERSION
        return config

    def save(self):
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            with self.path.open("w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=2)
            return True
        except Exception:
            return False

    def get(self, key, default=None):
        return self.data.get(key, default)

    def set(self, key, value):
        self.data[key] = value

    def is_favorite(self, tool_name):
        return tool_name in self.data.get("favorites", [])

    def toggle_favorite(self, tool_name):
        favs = list(self.data.get("favorites", []))
        if tool_name in favs:
            favs.remove(tool_name)
        else:
            favs.append(tool_name)
        self.data["favorites"] = favs
        self.save()
        return tool_name in favs


def get_tools_dir(config):
    custom_dir = config.get("tools_dir", "").strip()
    if custom_dir:
        cand = Path(custom_dir)
        if cand.is_dir():
            return cand
    candidates = [base_dir() / "tools"]
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        candidates.append(Path(meipass) / "tools")
    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    return candidates[0]


def powershell_exe():
    found = shutil.which("powershell.exe")
    if found:
        return found
    root = os.environ.get("SystemRoot", r"C:\Windows")
    return str(Path(root) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe")


def desktop_dir(config=None):
    if config:
        custom = config.get("shortcuts_dir", "").strip()
        if custom and Path(custom).is_dir():
            return Path(custom)
    buffer = ctypes.create_unicode_buffer(260)
    try:
        if ctypes.windll.shell32.SHGetFolderPathW(None, 0x10, None, 0, buffer) == 0:
            if buffer.value:
                return Path(buffer.value)
    except Exception:
        pass
    return Path.home() / "Desktop"


def ps_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def shortcut_icon(tool, config):
    folder = get_tools_dir(config)
    # Check tool-specific assigned icon
    if getattr(tool, "icon_name", None):
        for candidate_dir in [folder, base_dir(), base_dir() / "assets"]:
            candidate = candidate_dir / tool.icon_name
            if candidate.is_file():
                return candidate

    # Fallback to general toolkit icons
    if tool.filename.lower().endswith(".bat"):
        searcher_icon = folder / "DGs Searcher.ico"
        if searcher_icon.is_file():
            return searcher_icon

    for candidate_dir in [resource_dir() / "assets", folder, base_dir()]:
        default_icon = candidate_dir / "DG-Command-Center.ico"
        if default_icon.is_file():
            return default_icon

    root = os.environ.get("SystemRoot", r"C:\Windows")
    return Path(root) / "System32" / "shell32.dll"


def make_shortcut(tool, config):
    folder = get_tools_dir(config)
    path = folder / tool.filename
    if not path.is_file() and not Path(tool.filename).is_file():
        raise FileNotFoundError(f"Tool not found: {path}")

    actual_path = path if path.is_file() else Path(tool.filename)
    desktop = desktop_dir(config)
    if not desktop.is_dir():
        raise FileNotFoundError(f"Destination folder not found: {desktop}")
    lnk_path = desktop / f"{tool.name}.lnk"

    if actual_path.suffix.lower() == ".bat" or actual_path.suffix.lower() == ".cmd":
        target = str(actual_path)
        args = ""
        run_as_admin = False
    elif actual_path.suffix.lower() == ".exe":
        target = str(actual_path)
        args = ""
        run_as_admin = tool.admin
    elif actual_path.suffix.lower() == ".py":
        target = sys.executable
        args = f'"{actual_path}"'
        run_as_admin = tool.admin
    else:
        parts = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-STA"]
        if tool.console or tool.admin:
            parts.append("-NoExit")
        else:
            parts.extend(["-WindowStyle", "Hidden"])
        parts.extend(["-File", str(actual_path)])
        target = powershell_exe()
        args = subprocess.list2cmdline(parts)
        run_as_admin = tool.admin

    icon = shortcut_icon(tool, config)
    icon_location = f'"{icon}",0' if icon.suffix.lower() == ".ico" else f"{icon},0"

    lines = [
        "$ErrorActionPreference = 'Stop'",
        "$sh = New-Object -ComObject WScript.Shell",
        f"$lnk = $sh.CreateShortcut({ps_quote(lnk_path)})",
        f"$lnk.TargetPath = {ps_quote(target)}",
        f"$lnk.Arguments = {ps_quote(args)}",
        f"$lnk.WorkingDirectory = {ps_quote(actual_path.parent)}",
        f"$lnk.IconLocation = {ps_quote(icon_location)}",
        f"$lnk.Description = {ps_quote(tool.description)}",
        "$lnk.Save()",
    ]
    if run_as_admin:
        lines.extend([
            f"$bytes = [IO.File]::ReadAllBytes({ps_quote(lnk_path)})",
            "$bytes[0x15] = $bytes[0x15] -bor 0x20",
            f"[IO.File]::WriteAllBytes({ps_quote(lnk_path)}, $bytes)",
        ])
    script = "\n".join(lines)
    encoded = base64.b64encode(script.encode("utf-16-le")).decode("ascii")

    result = subprocess.run(
        [powershell_exe(), "-NoProfile", "-EncodedCommand", encoded],
        creationflags=CREATE_NO_WINDOW,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not lnk_path.is_file():
        detail = (result.stderr or result.stdout or "PowerShell failed to create shortcut").strip()
        raise RuntimeError(detail)
    return lnk_path


def set_window_icon(root):
    preferred = resource_dir() / "assets" / "DG-Command-Center.ico"
    candidates = [preferred]
    for folder in (base_dir(), base_dir() / "assets", base_dir() / "tools"):
        if folder.is_dir():
            candidates.extend(folder.glob("*.ico"))
    for icon in candidates:
        try:
            root.iconbitmap(default=str(icon))
            return
        except Exception:
            pass


# =========================================================================
# SETTINGS DIALOG
# =========================================================================
class SettingsDialog(tk.Toplevel):
    def __init__(self, parent, suite_app):
        super().__init__(parent)
        self.suite_app = suite_app
        self.config_mgr = suite_app.config_mgr
        self.theme = suite_app.theme

        self.title(f"Settings & Preferences - {APP_TITLE}")
        self.geometry("740x580")
        self.minsize(680, 500)
        self.configure(bg=self.theme["bg"])
        self.transient(parent)
        self.grab_set()

        set_window_icon(self)

        self.notebook = None
        self.theme_var = tk.StringVar(value=self.config_mgr.get("theme", DEFAULT_THEME))
        self.tools_dir_var = tk.StringVar(value=self.config_mgr.get("tools_dir", ""))
        self.shortcuts_dir_var = tk.StringVar(value=self.config_mgr.get("shortcuts_dir", ""))
        self.confirm_admin_var = tk.BooleanVar(value=self.config_mgr.get("confirm_admin", True))
        self.confirm_launch_var = tk.BooleanVar(value=self.config_mgr.get("confirm_launch", False))
        self.log_timestamps_var = tk.BooleanVar(value=self.config_mgr.get("log_timestamps", True))
        self.max_log_lines_var = tk.IntVar(value=self.config_mgr.get("max_log_lines", 300))

        self.build_ui()
        self.center_window(parent)

    def center_window(self, parent):
        self.update_idletasks()
        pw = parent.winfo_width()
        ph = parent.winfo_height()
        px = parent.winfo_x()
        py = parent.winfo_y()
        w = self.winfo_width()
        h = self.winfo_height()
        x = px + max(0, (pw - w) // 2)
        y = py + max(0, (ph - h) // 2)
        self.geometry(f"+{x}+{y}")

    def build_ui(self):
        t = self.theme

        # Header
        header = tk.Frame(self, bg=t["header_bg"], padx=20, pady=14)
        header.pack(fill="x")

        tk.Label(
            header,
            text="⚙  SETTINGS & PREFERENCES",
            font=(FONT_FAMILY, 14, "bold"),
            fg=t["accent"],
            bg=t["header_bg"],
        ).pack(side="left")

        tk.Label(
            header,
            text=f"{APP_TITLE} v{self.suite_app.version}",
            font=(FONT_FAMILY, 9),
            fg=t["text_muted"],
            bg=t["header_bg"],
        ).pack(side="right", pady=3)

        # Style TTK Notebook
        style = ttk.Style(self)
        style.theme_use("default")
        style.configure("Settings.TNotebook", background=t["bg"], borderwidth=0)
        style.configure(
            "Settings.TNotebook.Tab",
            background=t["panel"],
            foreground=t["text"],
            padding=[14, 8],
            font=(FONT_FAMILY, 9, "bold"),
            borderwidth=0,
        )
        style.map(
            "Settings.TNotebook.Tab",
            background=[("selected", t["accent_hover"]), ("active", t["panel_hover"])],
            foreground=[("selected", "#000000"), ("active", t["text"])],
        )

        self.notebook = ttk.Notebook(self, style="Settings.TNotebook")
        self.notebook.pack(fill="both", expand=True, padx=20, pady=12)

        # Tabs
        self.build_appearance_tab()
        self.build_paths_tab()
        self.build_behavior_tab()
        self.build_custom_tools_tab()
        self.build_about_tab()

        # Bottom Action Bar
        footer = tk.Frame(self, bg=t["bg"], padx=20, pady=12)
        footer.pack(fill="x")

        save_btn = tk.Button(
            footer,
            text="✔  SAVE & APPLY",
            command=self.save_and_apply,
            bg=t["primary"],
            fg="#ffffff",
            activebackground=t["primary_hover"],
            activeforeground="#ffffff",
            font=(FONT_FAMILY, 9, "bold"),
            relief="flat",
            padx=18,
            pady=8,
            cursor="hand2",
        )
        save_btn.pack(side="right", padx=(8, 0))

        cancel_btn = tk.Button(
            footer,
            text="CANCEL",
            command=self.destroy,
            bg=t["panel"],
            fg=t["text_muted"],
            activebackground=t["panel_line"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 9),
            relief="flat",
            padx=14,
            pady=8,
            cursor="hand2",
        )
        cancel_btn.pack(side="right")

    def build_appearance_tab(self):
        t = self.theme
        frame = tk.Frame(self.notebook, bg=t["bg"], padx=18, pady=16)
        self.notebook.add(frame, text="🎨  Appearance")

        tk.Label(
            frame,
            text="Visual Theme",
            font=(FONT_FAMILY, 11, "bold"),
            fg=t["text"],
            bg=t["bg"],
        ).pack(anchor="w")

        tk.Label(
            frame,
            text="Choose your preferred color theme. Changes apply across all toolkit windows.",
            font=(FONT_FAMILY, 8),
            fg=t["text_muted"],
            bg=t["bg"],
        ).pack(anchor="w", pady=(2, 12))

        theme_cards = tk.Frame(frame, bg=t["bg"])
        theme_cards.pack(fill="x", pady=4)

        for theme_name in THEMES:
            tinfo = THEMES[theme_name]
            rframe = tk.Frame(
                theme_cards,
                bg=t["panel"],
                highlightthickness=1,
                highlightbackground=t["panel_line"],
                padx=12,
                pady=10,
            )
            rframe.pack(fill="x", pady=4)

            rb = tk.Radiobutton(
                rframe,
                text=theme_name,
                variable=self.theme_var,
                value=theme_name,
                bg=t["panel"],
                fg=t["text"],
                selectcolor=tinfo["accent"],
                activebackground=t["panel"],
                activeforeground=t["text"],
                font=(FONT_FAMILY, 10, "bold"),
                cursor="hand2",
            )
            rb.pack(side="left")

            # Color swatches
            swatch_box = tk.Frame(rframe, bg=t["panel"])
            swatch_box.pack(side="right")
            for color in (tinfo["bg"], tinfo["panel"], tinfo["accent"], tinfo["primary"]):
                s = tk.Frame(swatch_box, bg=color, width=20, height=20, highlightthickness=1, highlightbackground=t["panel_line"])
                s.pack(side="left", padx=2)

    def build_paths_tab(self):
        t = self.theme
        frame = tk.Frame(self.notebook, bg=t["bg"], padx=18, pady=16)
        self.notebook.add(frame, text="📁  Directories")

        # Tools Dir
        tk.Label(
            frame,
            text="Tools Directory",
            font=(FONT_FAMILY, 10, "bold"),
            fg=t["text"],
            bg=t["bg"],
        ).pack(anchor="w")
        tk.Label(
            frame,
            text="Default folder containing .ps1 and .bat tool scripts. Leave empty for auto-detection.",
            font=(FONT_FAMILY, 8),
            fg=t["text_muted"],
            bg=t["bg"],
        ).pack(anchor="w", pady=(2, 6))

        box1 = tk.Frame(frame, bg=t["bg"])
        box1.pack(fill="x", pady=(0, 16))

        entry1 = tk.Entry(
            box1,
            textvariable=self.tools_dir_var,
            font=(FONT_FAMILY, 9),
            bg=t["input_bg"],
            fg=t["text"],
            insertbackground=t["text"],
            relief="flat",
            highlightthickness=1,
            highlightbackground=t["panel_line"],
        )
        entry1.pack(side="left", fill="x", expand=True, ipady=5, padx=(0, 6))

        tk.Button(
            box1,
            text="Browse...",
            command=self.browse_tools_dir,
            bg=t["panel"],
            fg=t["accent"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=10,
            pady=4,
            cursor="hand2",
        ).pack(side="left")

        tk.Button(
            box1,
            text="Reset",
            command=lambda: self.tools_dir_var.set(""),
            bg=t["panel"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 8),
            relief="flat",
            padx=8,
            pady=4,
            cursor="hand2",
        ).pack(side="left", padx=(4, 0))

        # Shortcuts Dir
        tk.Label(
            frame,
            text="Desktop Shortcut Export Destination",
            font=(FONT_FAMILY, 10, "bold"),
            fg=t["text"],
            bg=t["bg"],
        ).pack(anchor="w")
        tk.Label(
            frame,
            text="Target location when clicking 'SHORTCUT'. Default is current user Desktop.",
            font=(FONT_FAMILY, 8),
            fg=t["text_muted"],
            bg=t["bg"],
        ).pack(anchor="w", pady=(2, 6))

        box2 = tk.Frame(frame, bg=t["bg"])
        box2.pack(fill="x", pady=(0, 16))

        entry2 = tk.Entry(
            box2,
            textvariable=self.shortcuts_dir_var,
            font=(FONT_FAMILY, 9),
            bg=t["input_bg"],
            fg=t["text"],
            insertbackground=t["text"],
            relief="flat",
            highlightthickness=1,
            highlightbackground=t["panel_line"],
        )
        entry2.pack(side="left", fill="x", expand=True, ipady=5, padx=(0, 6))

        tk.Button(
            box2,
            text="Browse...",
            command=self.browse_shortcuts_dir,
            bg=t["panel"],
            fg=t["accent"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=10,
            pady=4,
            cursor="hand2",
        ).pack(side="left")

        tk.Button(
            box2,
            text="Reset",
            command=lambda: self.shortcuts_dir_var.set(""),
            bg=t["panel"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 8),
            relief="flat",
            padx=8,
            pady=4,
            cursor="hand2",
        ).pack(side="left", padx=(4, 0))

        # System Path Info
        info_box = tk.Frame(frame, bg=t["panel"], highlightthickness=1, highlightbackground=t["panel_line"], padx=12, pady=10)
        info_box.pack(fill="x", pady=6)
        tk.Label(
            info_box,
            text=f"PowerShell Binary: {powershell_exe()}",
            font=(FONT_MONO, 8),
            fg=t["text_muted"],
            bg=t["panel"],
            anchor="w",
        ).pack(fill="x")
        tk.Label(
            info_box,
            text=f"Default Desktop: {desktop_dir()}",
            font=(FONT_MONO, 8),
            fg=t["text_muted"],
            bg=t["panel"],
            anchor="w",
            pady=2,
        ).pack(fill="x")

    def browse_tools_dir(self):
        chosen = filedialog.askdirectory(title="Select Tools Directory", parent=self)
        if chosen:
            self.tools_dir_var.set(chosen)

    def browse_shortcuts_dir(self):
        chosen = filedialog.askdirectory(title="Select Shortcuts Export Directory", parent=self)
        if chosen:
            self.shortcuts_dir_var.set(chosen)

    def build_behavior_tab(self):
        t = self.theme
        frame = tk.Frame(self.notebook, bg=t["bg"], padx=18, pady=16)
        self.notebook.add(frame, text="⚡  Behavior")

        tk.Label(
            frame,
            text="Execution & Safety",
            font=(FONT_FAMILY, 10, "bold"),
            fg=t["text"],
            bg=t["bg"],
        ).pack(anchor="w")

        tk.Checkbutton(
            frame,
            text="Confirm before launching Administrator-level tools (UAC elevation)",
            variable=self.confirm_admin_var,
            bg=t["bg"],
            fg=t["text"],
            selectcolor=t["panel"],
            activebackground=t["bg"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 9),
            cursor="hand2",
        ).pack(anchor="w", pady=(8, 4))

        tk.Checkbutton(
            frame,
            text="Confirm before launching any regular tool",
            variable=self.confirm_launch_var,
            bg=t["bg"],
            fg=t["text"],
            selectcolor=t["panel"],
            activebackground=t["bg"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 9),
            cursor="hand2",
        ).pack(anchor="w", pady=4)

        tk.Frame(frame, height=1, bg=t["panel_line"]).pack(fill="x", pady=14)

        tk.Label(
            frame,
            text="Activity Console Log Settings",
            font=(FONT_FAMILY, 10, "bold"),
            fg=t["text"],
            bg=t["bg"],
        ).pack(anchor="w")

        tk.Checkbutton(
            frame,
            text="Include timestamps in activity log output ([HH:MM:SS])",
            variable=self.log_timestamps_var,
            bg=t["bg"],
            fg=t["text"],
            selectcolor=t["panel"],
            activebackground=t["bg"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 9),
            cursor="hand2",
        ).pack(anchor="w", pady=(8, 6))

        spin_frame = tk.Frame(frame, bg=t["bg"])
        spin_frame.pack(anchor="w", pady=4)
        tk.Label(
            spin_frame,
            text="Maximum retained log history (lines): ",
            font=(FONT_FAMILY, 9),
            fg=t["text_muted"],
            bg=t["bg"],
        ).pack(side="left")
        spin = tk.Spinbox(
            spin_frame,
            from_=50,
            to=2000,
            increment=50,
            textvariable=self.max_log_lines_var,
            width=8,
            font=(FONT_FAMILY, 9),
            bg=t["input_bg"],
            fg=t["text"],
            insertbackground=t["text"],
            relief="flat",
            highlightthickness=1,
            highlightbackground=t["panel_line"],
        )
        spin.pack(side="left")

    def build_custom_tools_tab(self):
        t = self.theme
        frame = tk.Frame(self.notebook, bg=t["bg"], padx=18, pady=16)
        self.notebook.add(frame, text="🧩  Custom Tools")

        tk.Label(
            frame,
            text="Add Custom Scripts & Tools",
            font=(FONT_FAMILY, 10, "bold"),
            fg=t["text"],
            bg=t["bg"],
        ).pack(anchor="w")

        tk.Label(
            frame,
            text="Easily add your own PowerShell scripts (.ps1), batch files (.bat/.cmd), or EXEs.",
            font=(FONT_FAMILY, 8),
            fg=t["text_muted"],
            bg=t["bg"],
        ).pack(anchor="w", pady=(2, 10))

        # Add Form
        add_box = tk.Frame(frame, bg=t["panel"], highlightthickness=1, highlightbackground=t["panel_line"], padx=12, pady=10)
        add_box.pack(fill="x", pady=(0, 12))

        f_name_row = tk.Frame(add_box, bg=t["panel"])
        f_name_row.pack(fill="x", pady=2)
        tk.Label(f_name_row, text="Name: ", width=10, anchor="w", fg=t["text_muted"], bg=t["panel"], font=(FONT_FAMILY, 8, "bold")).pack(side="left")
        self.c_name_ent = tk.Entry(f_name_row, bg=t["input_bg"], fg=t["text"], insertbackground=t["text"], relief="flat", highlightthickness=1, highlightbackground=t["panel_line"])
        self.c_name_ent.pack(side="left", fill="x", expand=True, ipady=3)

        f_desc_row = tk.Frame(add_box, bg=t["panel"])
        f_desc_row.pack(fill="x", pady=2)
        tk.Label(f_desc_row, text="Description: ", width=10, anchor="w", fg=t["text_muted"], bg=t["panel"], font=(FONT_FAMILY, 8, "bold")).pack(side="left")
        self.c_desc_ent = tk.Entry(f_desc_row, bg=t["input_bg"], fg=t["text"], insertbackground=t["text"], relief="flat", highlightthickness=1, highlightbackground=t["panel_line"])
        self.c_desc_ent.pack(side="left", fill="x", expand=True, ipady=3)

        f_file_row = tk.Frame(add_box, bg=t["panel"])
        f_file_row.pack(fill="x", pady=2)
        tk.Label(f_file_row, text="File / Script: ", width=10, anchor="w", fg=t["text_muted"], bg=t["panel"], font=(FONT_FAMILY, 8, "bold")).pack(side="left")
        self.c_file_ent = tk.Entry(f_file_row, bg=t["input_bg"], fg=t["text"], insertbackground=t["text"], relief="flat", highlightthickness=1, highlightbackground=t["panel_line"])
        self.c_file_ent.pack(side="left", fill="x", expand=True, ipady=3, padx=(0, 4))
        tk.Button(
            f_file_row,
            text="Browse...",
            command=self.browse_custom_file,
            bg=t["bg"],
            fg=t["accent"],
            font=(FONT_FAMILY, 8),
            relief="flat",
            padx=8,
            pady=2,
            cursor="hand2",
        ).pack(side="left")

        opt_row = tk.Frame(add_box, bg=t["panel"])
        opt_row.pack(fill="x", pady=(4, 2))
        self.c_console_var = tk.BooleanVar(value=False)
        self.c_admin_var = tk.BooleanVar(value=False)
        tk.Checkbutton(opt_row, text="Open Console", variable=self.c_console_var, bg=t["panel"], fg=t["text"], selectcolor=t["bg"]).pack(side="left", padx=(0, 8))
        tk.Checkbutton(opt_row, text="Requires Admin", variable=self.c_admin_var, bg=t["panel"], fg=t["text"], selectcolor=t["bg"]).pack(side="left")

        tk.Button(
            opt_row,
            text="➕ Add Custom Tool",
            command=self.add_custom_tool_action,
            bg=t["primary"],
            fg="#ffffff",
            activebackground=t["primary_hover"],
            activeforeground="#ffffff",
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=12,
            pady=4,
            cursor="hand2",
        ).pack(side="right")

        # List of existing custom tools
        self.custom_listbox_frame = tk.Frame(frame, bg=t["panel"], highlightthickness=1, highlightbackground=t["panel_line"])
        self.custom_listbox_frame.pack(fill="both", expand=True)

        self.custom_listbox = tk.Listbox(
            self.custom_listbox_frame,
            bg=t["panel"],
            fg=t["text"],
            font=(FONT_FAMILY, 9),
            selectbackground=t["accent_hover"],
            selectforeground="#000000",
            relief="flat",
            borderwidth=0,
        )
        self.custom_listbox.pack(side="left", fill="both", expand=True, padx=6, pady=6)

        del_btn = tk.Button(
            frame,
            text="🗑 Remove Selected Tool",
            command=self.delete_selected_custom_tool,
            bg=t["panel"],
            fg=t["danger"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=10,
            pady=4,
            cursor="hand2",
        )
        del_btn.pack(anchor="e", pady=(6, 0))

        self.refresh_custom_listbox()

    def browse_custom_file(self):
        chosen = filedialog.askopenfilename(
            title="Select Tool Executable or Script",
            filetypes=[
                ("Supported Tools", "*.ps1;*.bat;*.cmd;*.exe;*.py"),
                ("PowerShell Scripts", "*.ps1"),
                ("Batch Files", "*.bat;*.cmd"),
                ("Executables", "*.exe"),
                ("All Files", "*.*"),
            ],
            parent=self,
        )
        if chosen:
            self.c_file_ent.delete(0, "end")
            self.c_file_ent.insert(0, chosen)
            if not self.c_name_ent.get().strip():
                self.c_name_ent.insert(0, Path(chosen).stem.replace("-", " ").replace("_", " ").title())

    def add_custom_tool_action(self):
        name = self.c_name_ent.get().strip()
        filename = self.c_file_ent.get().strip()
        desc = self.c_desc_ent.get().strip() or "Custom user tool."
        if not name or not filename:
            messagebox.showwarning("Incomplete Form", "Please provide at least a Tool Name and File Path.", parent=self)
            return

        tag = "ADMIN" if self.c_admin_var.get() else ("CONSOLE" if self.c_console_var.get() else "CUSTOM")
        tool = Tool(
            name=name,
            description=desc,
            filename=filename,
            tag=tag,
            console=self.c_console_var.get(),
            admin=self.c_admin_var.get(),
            is_custom=True,
        )
        c_tools = self.config_mgr.get("custom_tools", [])
        c_tools.append(tool.to_dict())
        self.config_mgr.set("custom_tools", c_tools)
        self.config_mgr.save()

        self.c_name_ent.delete(0, "end")
        self.c_desc_ent.delete(0, "end")
        self.c_file_ent.delete(0, "end")
        self.refresh_custom_listbox()
        self.suite_app.refresh()

    def delete_selected_custom_tool(self):
        sel = self.custom_listbox.curselection()
        if not sel:
            return
        idx = sel[0]
        c_tools = self.config_mgr.get("custom_tools", [])
        if 0 <= idx < len(c_tools):
            removed = c_tools.pop(idx)
            self.config_mgr.set("custom_tools", c_tools)
            self.config_mgr.save()
            self.refresh_custom_listbox()
            self.suite_app.refresh()

    def refresh_custom_listbox(self):
        self.custom_listbox.delete(0, "end")
        c_tools = self.config_mgr.get("custom_tools", [])
        for item in c_tools:
            name = item.get("name", "Tool")
            fn = Path(item.get("filename", "")).name
            tag = item.get("tag", "CUSTOM")
            self.custom_listbox.insert("end", f"[{tag}] {name} ({fn})")

    def build_about_tab(self):
        t = self.theme
        frame = tk.Frame(self.notebook, bg=t["bg"], padx=18, pady=16)
        self.notebook.add(frame, text="ℹ  About & Reset")

        tk.Label(
            frame,
            text=f"{self.suite_app.title} v{self.suite_app.version}",
            font=(FONT_FAMILY, 12, "bold"),
            fg=t["accent"],
            bg=t["bg"],
        ).pack(anchor="w")

        desc = (
            "An all-in-one desktop hub for visual utilities, icon recoloring, shortcut repair, "
            "and file management.\nBuilt for Windows with native PowerShell automation.\n"
            "Author: DG\n"
        )
        tk.Label(
            frame,
            text=desc,
            font=(FONT_FAMILY, 9),
            fg=t["text"],
            bg=t["bg"],
            justify="left",
        ).pack(anchor="w", pady=(4, 12))

        btn_row = tk.Frame(frame, bg=t["bg"])
        btn_row.pack(fill="x", pady=6)

        tk.Button(
            btn_row,
            text="📄 Open config.json in Notepad",
            command=self.open_config_file,
            bg=t["panel"],
            fg=t["text"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=12,
            pady=6,
            cursor="hand2",
        ).pack(side="left", padx=(0, 8))

        tk.Button(
            btn_row,
            text="🔄 Restore Defaults",
            command=self.restore_defaults,
            bg=t["panel"],
            fg=t["danger"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=12,
            pady=6,
            cursor="hand2",
        ).pack(side="left")

    def open_config_file(self):
        path = self.config_mgr.path
        if path.is_file():
            try:
                subprocess.Popen(["notepad.exe", str(path)])
            except Exception as e:
                messagebox.showerror("Error", f"Failed to open config: {e}", parent=self)

    def restore_defaults(self):
        if messagebox.askyesno("Restore Defaults", "Reset all settings back to default values?", parent=self):
            self.config_mgr.data = dict(ConfigManager.DEFAULT_CONFIG)
            self.config_mgr.save()
            messagebox.showinfo("Reset Complete", "Settings reset to default. Restarting theme...", parent=self)
            self.suite_app.apply_theme()
            self.destroy()

    def save_and_apply(self):
        self.config_mgr.set("theme", self.theme_var.get())
        self.config_mgr.set("tools_dir", self.tools_dir_var.get().strip())
        self.config_mgr.set("shortcuts_dir", self.shortcuts_dir_var.get().strip())
        self.config_mgr.set("confirm_admin", self.confirm_admin_var.get())
        self.config_mgr.set("confirm_launch", self.confirm_launch_var.get())
        self.config_mgr.set("log_timestamps", self.log_timestamps_var.get())
        self.config_mgr.set("max_log_lines", self.max_log_lines_var.get())
        self.config_mgr.save()

        self.suite_app.log("Settings saved successfully.")
        self.suite_app.apply_theme()
        self.suite_app.refresh()
        self.destroy()


# =========================================================================
# MAIN SUITE APPLICATION
# =========================================================================
class SuiteApp:
    def __init__(self, root):
        self.root = root
        self.config_mgr = ConfigManager()
        self.version = str(self.config_mgr.get("version", FALLBACK_VERSION))
        self.title = str(self.config_mgr.get("app_name", APP_TITLE))
        self.theme_name = self.config_mgr.get("theme", DEFAULT_THEME)
        self.theme = THEMES.get(self.theme_name, THEMES[DEFAULT_THEME])

        self.tools = []
        self.active_filter = "ALL"
        self.search_query = tk.StringVar(value="")
        self.search_query.trace_add("write", lambda *_: self.on_search_changed())

        # Root setup
        root.title(f"{self.title} v{self.version}")
        root.geometry("1120x900")
        root.minsize(980, 760)
        root.configure(bg=self.theme["bg"])
        set_window_icon(root)

        # Keyboard shortcuts
        root.bind("<Control-f>", lambda _: self.search_entry.focus_set())
        root.bind("<Escape>", lambda _: self.clear_search())
        root.bind("<F5>", lambda _: self.refresh())
        root.bind("<Control-comma>", lambda _: self.open_settings())
        root.bind("<Control-l>", lambda _: self.clear_log())

        # Load Logo if available
        self.logo_img = None
        self.load_logo()

        # Build UI Structure
        self.build_header()
        self.build_overview()
        self.build_filter_bar()
        self.build_tools_scroll_area()
        self.build_activity_log()
        self.build_footer()

        # Initial Render
        self.refresh()

    def load_logo(self):
        logo_path = resource_dir() / "assets" / "DG-Visual-Toolkit-1024.png"
        if logo_path.is_file():
            try:
                full_img = tk.PhotoImage(file=str(logo_path))
                # Subsample 1024px to ~42px
                self.logo_img = full_img.subsample(24, 24)
            except Exception:
                self.logo_img = None

    def apply_theme(self):
        self.theme_name = self.config_mgr.get("theme", DEFAULT_THEME)
        self.theme = THEMES.get(self.theme_name, THEMES[DEFAULT_THEME])
        t = self.theme

        self.root.configure(bg=t["bg"])
        self.header_frame.configure(bg=t["header_bg"])
        self.title_lbl.configure(bg=t["header_bg"], fg=t["accent"])
        self.subtitle_lbl.configure(bg=t["header_bg"], fg=t["text_muted"])
        self.badge_lbl.configure(bg=t["panel_line"], fg=t["text"])

        self.overview_frame.configure(bg=t["bg"])
        self.hero_panel.configure(bg=t["panel"], highlightbackground=t["panel_line"])
        self.hero_kicker.configure(bg=t["panel"], fg=t["accent"])
        self.hero_title.configure(bg=t["panel"], fg=t["text"])
        self.hero_description.configure(bg=t["panel"], fg=t["text_muted"])
        self.metric_values.configure(bg=t["bg"])
        for card, label, value in self.metric_cards:
            card.configure(bg=t["card_bg"], highlightbackground=t["panel_line"])
            label.configure(bg=t["card_bg"], fg=t["text_muted"])
            value.configure(bg=t["card_bg"], fg=t["text"])

        self.filter_bar_frame.configure(bg=t["bg"])
        self.search_box.configure(bg=t["panel"], highlightbackground=t["panel_line"])
        self.search_icon_lbl.configure(bg=t["panel"], fg=t["text_muted"])
        self.search_entry.configure(bg=t["panel"], fg=t["text"], insertbackground=t["text"])
        self.search_clear_btn.configure(bg=t["panel"], fg=t["text_muted"])
        self.stats_lbl.configure(bg=t["bg"], fg=t["text_muted"])

        self.canvas.configure(bg=t["bg"])
        self.scroll_content.configure(bg=t["bg"])

        self.log_header.configure(bg=t["header_bg"])
        self.log_title_lbl.configure(bg=t["header_bg"], fg=t["accent"])
        self.log_body.configure(bg=t["log_bg"], highlightbackground=t["panel_line"])
        self.log_box.configure(bg=t["log_bg"], fg="#a7f3d0")

        self.footer_frame.configure(bg=t["bg"])
        self.path_label.configure(bg=t["bg"], fg=t["text_muted"])
        self.theme_indicator_lbl.configure(bg=t["panel"], fg=t["accent"], highlightbackground=t["panel_line"])

        self.render_filter_pills()
        self.update_overview()
        self.render_tools()

    def build_header(self):
        t = self.theme
        self.header_frame = tk.Frame(self.root, bg=t["header_bg"], padx=20, pady=12)
        self.header_frame.pack(fill="x")

        left = tk.Frame(self.header_frame, bg=t["header_bg"])
        left.pack(side="left")

        if self.logo_img:
            self.logo_lbl = tk.Label(left, image=self.logo_img, bg=t["header_bg"])
            self.logo_lbl.pack(side="left", padx=(0, 12))

        title_box = tk.Frame(left, bg=t["header_bg"])
        title_box.pack(side="left")

        top_line = tk.Frame(title_box, bg=t["header_bg"])
        top_line.pack(anchor="w")

        self.title_lbl = tk.Label(
            top_line,
            text=self.title.upper(),
            bg=t["header_bg"],
            fg=t["accent"],
            font=(FONT_FAMILY, 15, "bold"),
            anchor="w",
        )
        self.title_lbl.pack(side="left")

        self.badge_lbl = tk.Label(
            top_line,
            text=f" v{self.version} ",
            bg=t["panel_line"],
            fg=t["text"],
            font=(FONT_FAMILY, 8, "bold"),
            padx=4,
            pady=1,
        )
        self.badge_lbl.pack(side="left", padx=(8, 0), pady=(3, 0))

        self.subtitle_lbl = tk.Label(
            title_box,
            text="One focused home for your everyday Windows utilities",
            bg=t["header_bg"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 8),
            anchor="w",
        )
        self.subtitle_lbl.pack(anchor="w", pady=(2, 0))

        # Top Right Actions
        right = tk.Frame(self.header_frame, bg=t["header_bg"])
        right.pack(side="right", pady=4)

        self.settings_btn = tk.Button(
            right,
            text="⚙  SETTINGS",
            command=self.open_settings,
            bg=t["panel"],
            fg=t["accent"],
            activebackground=t["panel_line"],
            activeforeground=t["accent_hover"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=12,
            pady=6,
            cursor="hand2",
            highlightthickness=1,
            highlightbackground=t["accent"],
        )
        self.settings_btn.pack(side="left", padx=4)

        self.refresh_btn = tk.Button(
            right,
            text="🔄  REFRESH",
            command=self.refresh,
            bg=t["panel"],
            fg=t["text"],
            activebackground=t["panel_line"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=12,
            pady=6,
            cursor="hand2",
        )
        self.refresh_btn.pack(side="left", padx=4)

        self.folder_btn = tk.Button(
            right,
            text="📂  TOOLS",
            command=self.open_tools_folder,
            bg=t["panel"],
            fg=t["text_muted"],
            activebackground=t["panel_line"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 8, "bold"),
            relief="flat",
            padx=12,
            pady=6,
            cursor="hand2",
        )
        self.folder_btn.pack(side="left", padx=4)

    def build_overview(self):
        t = self.theme
        self.overview_frame = tk.Frame(self.root, bg=t["bg"], padx=20, pady=8)
        self.overview_frame.pack(fill="x")

        self.hero_panel = tk.Frame(
            self.overview_frame,
            bg=t["panel"],
            highlightthickness=1,
            highlightbackground=t["panel_line"],
            padx=20,
            pady=16,
        )
        self.hero_panel.pack(fill="x")

        self.hero_kicker = tk.Label(
            self.hero_panel,
            text="YOUR WINDOWS TOOLKIT",
            bg=t["panel"],
            fg=t["accent"],
            font=(FONT_FAMILY, 8, "bold"),
            anchor="w",
        )
        self.hero_kicker.pack(anchor="w")
        self.hero_title = tk.Label(
            self.hero_panel,
            text="Everything you need. One command center.",
            bg=t["panel"],
            fg=t["text"],
            font=(FONT_FAMILY, 19, "bold"),
            anchor="w",
        )
        self.hero_title.pack(anchor="w", pady=(3, 1))
        self.hero_description = tk.Label(
            self.hero_panel,
            text="Find a tool, pick up where you left off, and keep system-level actions clearly in view.",
            bg=t["panel"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 9),
            anchor="w",
        )
        self.hero_description.pack(anchor="w")

        self.metric_values = tk.Frame(self.overview_frame, bg=t["bg"])
        self.metric_values.pack(fill="x", pady=(8, 0))
        self.metric_cards = []
        for title in ("READY TO USE", "SYSTEM TOOLS", "FAVORITES"):
            card = tk.Frame(
                self.metric_values,
                bg=t["card_bg"],
                highlightthickness=1,
                highlightbackground=t["panel_line"],
                padx=14,
                pady=9,
            )
            card.pack(side="left", fill="x", expand=True, padx=(0, 8))
            label = tk.Label(
                card,
                text=title,
                bg=t["card_bg"],
                fg=t["text_muted"],
                font=(FONT_FAMILY, 7, "bold"),
                anchor="w",
            )
            label.pack(anchor="w")
            value = tk.Label(
                card,
                text="0",
                bg=t["card_bg"],
                fg=t["text"],
                font=(FONT_FAMILY, 16, "bold"),
                anchor="w",
            )
            value.pack(anchor="w", pady=(2, 0))
            self.metric_cards.append((card, label, value))
        self.metric_cards[-1][0].pack_configure(padx=(0, 0))

    def update_overview(self):
        if not hasattr(self, "metric_cards"):
            return
        folder = get_tools_dir(self.config_mgr.data)
        ready = 0
        system = 0
        favorites = 0
        for tool in self.tools:
            custom_path = Path(tool.filename)
            path = custom_path if tool.is_custom and custom_path.is_file() else folder / tool.filename
            ready += path.is_file()
            system += tool.admin
            favorites += self.config_mgr.is_favorite(tool.name)
        for (_, _, value), count in zip(self.metric_cards, (ready, system, favorites)):
            value.configure(text=str(count))

    def build_filter_bar(self):
        t = self.theme
        self.filter_bar_frame = tk.Frame(self.root, bg=t["bg"], padx=20, pady=6)
        self.filter_bar_frame.pack(fill="x")

        # Search Bar
        search_wrap = tk.Frame(self.filter_bar_frame, bg=t["bg"])
        search_wrap.pack(fill="x", pady=(0, 8))

        self.search_box = tk.Frame(
            search_wrap,
            bg=t["panel"],
            highlightthickness=1,
            highlightbackground=t["panel_line"],
        )
        self.search_box.pack(side="left", fill="x", expand=True)

        self.search_icon_lbl = tk.Label(
            self.search_box,
            text="⌕",
            bg=t["panel"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 17),
        )
        self.search_icon_lbl.pack(side="left", padx=(6, 2))

        self.search_entry = tk.Entry(
            self.search_box,
            textvariable=self.search_query,
            font=(FONT_FAMILY, 9),
            bg=t["panel"],
            fg=t["text"],
            insertbackground=t["text"],
            relief="flat",
            borderwidth=0,
        )
        self.search_entry.pack(side="left", fill="x", expand=True, ipady=6)

        self.search_clear_btn = tk.Button(
            self.search_box,
            text="×",
            command=self.clear_search,
            bg=t["panel"],
            fg=t["text_muted"],
            activebackground=t["panel"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 8),
            relief="flat",
            bd=0,
            padx=10,
            cursor="hand2",
        )
        self.search_clear_btn.pack(side="right")

        # Stats label
        self.stats_lbl = tk.Label(
            search_wrap,
            text="0 tools",
            bg=t["bg"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 8),
        )
        self.stats_lbl.pack(side="right", padx=(12, 0))

        # Filter Pills Frame
        self.pills_frame = tk.Frame(self.filter_bar_frame, bg=t["bg"])
        self.pills_frame.pack(fill="x")
        self.render_filter_pills()

    def render_filter_pills(self):
        t = self.theme
        for child in self.pills_frame.winfo_children():
            child.destroy()

        categories = [
            ("ALL", "All Tools"),
            ("FAVORITES", "⭐ Favorites"),
            ("GUI", "🖥 GUI Tools"),
            ("CONSOLE", "⚡ Console"),
            ("ADMIN", "🛡 Admin"),
            ("CUSTOM", "🧩 Custom"),
        ]

        for cat_key, cat_label in categories:
            is_active = (self.active_filter == cat_key)
            bg_col = t["accent"] if is_active else t["panel"]
            fg_col = "#000000" if is_active else t["text_muted"]

            btn = tk.Button(
                self.pills_frame,
                text=cat_label,
                command=lambda k=cat_key: self.set_filter(k),
                bg=bg_col,
                fg=fg_col,
                activebackground=t["accent_hover"],
                activeforeground="#000000",
                font=(FONT_FAMILY, 8, "bold" if is_active else "normal"),
                relief="flat",
                bd=0,
                padx=10,
                pady=3,
                cursor="hand2",
            )
            btn.pack(side="left", padx=(0, 6))

    def set_filter(self, cat_key):
        self.active_filter = cat_key
        self.render_filter_pills()
        self.render_tools()

    def on_search_changed(self):
        self.render_tools()

    def clear_search(self):
        self.search_query.set("")
        self.search_entry.focus_set()

    def build_tools_scroll_area(self):
        t = self.theme
        container = tk.Frame(self.root, bg=t["bg"], padx=20, pady=4)
        container.pack(fill="both", expand=True)

        self.canvas = tk.Canvas(
            container,
            bg=t["bg"],
            highlightthickness=0,
            borderwidth=0,
        )
        self.scrollbar = tk.Scrollbar(
            container,
            orient="vertical",
            command=self.canvas.yview,
            bg=t["panel"],
            troughcolor=t["bg"],
            activebackground=t["panel_line"],
        )
        self.scroll_content = tk.Frame(self.canvas, bg=t["bg"])

        self.canvas_window = self.canvas.create_window((0, 0), window=self.scroll_content, anchor="nw")

        self.scroll_content.bind(
            "<Configure>",
            lambda _: self.canvas.configure(scrollregion=self.canvas.bbox("all")),
        )
        self.canvas.bind(
            "<Configure>",
            lambda e: self.canvas.itemconfig(self.canvas_window, width=e.width),
        )

        # Mouse wheel support
        self.canvas.bind_all("<MouseWheel>", self.on_mousewheel)

        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")

    def on_mousewheel(self, event):
        # Scroll canvas with mouse wheel
        if self.canvas.winfo_exists():
            delta = -1 * (event.delta // 120)
            self.canvas.yview_scroll(delta, "units")

    def build_activity_log(self):
        t = self.theme
        wrapper = tk.Frame(self.root, bg=t["bg"], padx=20, pady=4)
        wrapper.pack(fill="x")

        self.log_header = tk.Frame(wrapper, bg=t["header_bg"], padx=10, pady=4)
        self.log_header.pack(fill="x")

        self.log_title_lbl = tk.Label(
            self.log_header,
            text="ACTIVITY LOG",
            bg=t["header_bg"],
            fg=t["accent"],
            font=(FONT_FAMILY, 8, "bold"),
            anchor="w",
        )
        self.log_title_lbl.pack(side="left")

        actions = tk.Frame(self.log_header, bg=t["header_bg"])
        actions.pack(side="right")

        tk.Button(
            actions,
            text="📋 Copy Log",
            command=self.copy_log,
            bg=t["header_bg"],
            fg=t["text_muted"],
            activebackground=t["panel"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 7),
            relief="flat",
            bd=0,
            cursor="hand2",
        ).pack(side="left", padx=4)

        tk.Button(
            actions,
            text="🧹 Clear",
            command=self.clear_log,
            bg=t["header_bg"],
            fg=t["text_muted"],
            activebackground=t["panel"],
            activeforeground=t["text"],
            font=(FONT_FAMILY, 7),
            relief="flat",
            bd=0,
            cursor="hand2",
        ).pack(side="left")

        self.log_body = tk.Frame(wrapper, bg=t["log_bg"], highlightthickness=1, highlightbackground=t["panel_line"])
        self.log_body.pack(fill="x")

        log_scroll = tk.Scrollbar(self.log_body, bg=t["panel"], troughcolor=t["log_bg"], activebackground=t["panel_line"])
        log_scroll.pack(side="right", fill="y")

        self.log_box = tk.Text(
            self.log_body,
            height=4,
            bg=t["log_bg"],
            fg="#a7f3d0",
            insertbackground=t["text"],
            relief="flat",
            borderwidth=0,
            font=(FONT_MONO, 8),
            yscrollcommand=log_scroll.set,
            state="disabled",
            wrap="word",
        )
        self.log_box.pack(side="left", fill="x", expand=True, padx=8, pady=4)
        log_scroll.configure(command=self.log_box.yview)

    def build_footer(self):
        t = self.theme
        self.footer_frame = tk.Frame(self.root, bg=t["bg"], padx=20, pady=4)
        self.footer_frame.pack(fill="x")

        self.path_label = tk.Label(
            self.footer_frame,
            text=f"📁 Tools Directory: {get_tools_dir(self.config_mgr.data)}",
            bg=t["bg"],
            fg=t["text_muted"],
            font=(FONT_FAMILY, 8),
            anchor="w",
        )
        self.path_label.pack(side="left", fill="x", expand=True)

        self.theme_indicator_lbl = tk.Label(
            self.footer_frame,
            text=f" Theme: {self.theme_name} ",
            bg=t["panel"],
            fg=t["accent"],
            font=(FONT_FAMILY, 8, "bold"),
            highlightthickness=1,
            highlightbackground=t["panel_line"],
            padx=6,
            pady=2,
        )
        self.theme_indicator_lbl.pack(side="right")

    def log(self, message, level="INFO"):
        max_lines = self.config_mgr.get("max_log_lines", 300)
        show_time = self.config_mgr.get("log_timestamps", True)
        stamp = f"[{datetime.now().strftime('%H:%M:%S')}] " if show_time else ""
        badge = f"[{level}] " if level != "INFO" else ""

        self.log_box.configure(state="normal")
        self.log_box.insert("end", f"{stamp}{badge}{message}\n")

        # Trim log lines if exceeding max
        lines = int(self.log_box.index("end-1c").split(".")[0])
        if lines > max_lines:
            self.log_box.delete("1.0", f"{lines - max_lines}.0")

        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def copy_log(self):
        text = self.log_box.get("1.0", "end-1c")
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        self.log("Log contents copied to clipboard.")

    def clear_log(self):
        self.log_box.configure(state="normal")
        self.log_box.delete("1.0", "end")
        self.log_box.configure(state="disabled")

    def open_settings(self):
        SettingsDialog(self.root, self)

    def open_tools_folder(self):
        folder = get_tools_dir(self.config_mgr.data)
        try:
            os.startfile(str(folder))
            self.log(f"Opened tools folder: {folder}")
        except Exception as exc:
            messagebox.showerror(self.title, f"Could not open the tools folder:\n{exc}", parent=self.root)

    def load_all_tools(self):
        tools = list(BUILTIN_TOOLS)
        known_files = {t.filename.lower() for t in tools}

        # Auto-discover any unlisted scripts or executables in tools folder
        folder = get_tools_dir(self.config_mgr.data)
        if folder.is_dir():
            for f in folder.iterdir():
                if f.is_file() and f.suffix.lower() in [".exe", ".ps1", ".bat", ".cmd", ".py"]:
                    if f.name.lower() not in known_files:
                        tag = "CONSOLE" if f.suffix.lower() in [".bat", ".cmd"] else "GUI"
                        clean_name = f.stem.replace("-", " ").replace("_", " ").title()
                        tools.append(Tool(
                            name=clean_name,
                            description=f"Auto-discovered utility ({f.name}) in tools folder.",
                            filename=f.name,
                            tag=tag,
                            console=(f.suffix.lower() in [".bat", ".cmd"]),
                            admin=False,
                            icon_name="DG-Visual-Toolkit.ico",
                            is_custom=False,
                        ))
                        known_files.add(f.name.lower())

        # Load user custom tools from config
        custom_data = self.config_mgr.get("custom_tools", [])
        for item in custom_data:
            try:
                tools.append(Tool.from_dict(item))
            except Exception:
                pass
        return tools

    def refresh(self):
        self.tools = self.load_all_tools()
        folder = get_tools_dir(self.config_mgr.data)
        self.path_label.configure(text=f"📁 Tools Directory: {folder}")
        self.render_tools()

    def get_filtered_tools(self):
        query = self.search_query.get().strip().lower()
        filtered = []
        for tool in self.tools:
            # Category filter
            if self.active_filter == "FAVORITES" and not self.config_mgr.is_favorite(tool.name):
                continue
            if self.active_filter == "GUI" and tool.tag != "GUI":
                continue
            if self.active_filter == "CONSOLE" and tool.tag != "CONSOLE":
                continue
            if self.active_filter == "ADMIN" and tool.tag != "ADMIN":
                continue
            if self.active_filter == "CUSTOM" and not tool.is_custom:
                continue

            # Search query filter
            if query:
                match = (
                    query in tool.name.lower()
                    or query in tool.description.lower()
                    or query in tool.filename.lower()
                    or query in tool.tag.lower()
                )
                if not match:
                    continue
            filtered.append(tool)
        return filtered

    def render_tools(self):
        for child in self.scroll_content.winfo_children():
            child.destroy()

        t = self.theme
        folder = get_tools_dir(self.config_mgr.data)
        filtered = self.get_filtered_tools()

        self.stats_lbl.configure(text=f"{len(filtered)} tools")
        self.update_overview()

        if not filtered:
            empty_box = tk.Frame(self.scroll_content, bg=t["card_bg"], padx=20, pady=30, highlightthickness=1, highlightbackground=t["panel_line"])
            empty_box.pack(fill="x", pady=20)
            tk.Label(
                empty_box,
                text="🔍 No tools match your current filter or search query.",
                font=(FONT_FAMILY, 10, "bold"),
                fg=t["text_muted"],
                bg=t["card_bg"],
            ).pack()
            return

        missing_count = 0
        for tool in filtered:
            if tool.is_custom and Path(tool.filename).is_file():
                exists = True
                tool_path = Path(tool.filename)
            else:
                tool_path = folder / tool.filename
                exists = tool_path.is_file()

            if not exists:
                missing_count += 1

            is_fav = self.config_mgr.is_favorite(tool.name)

            # Card Container
            card = tk.Frame(
                self.scroll_content,
                bg=t["card_bg"],
                highlightthickness=1,
                highlightbackground=t["panel_line"],
                padx=14,
                pady=10,
            )
            card.pack(fill="x", pady=4)

            # Hover highlight
            def on_enter(e, c=card):
                c.configure(highlightbackground=t["accent"])

            def on_leave(e, c=card):
                c.configure(highlightbackground=t["panel_line"])

            card.bind("<Enter>", on_enter)
            card.bind("<Leave>", on_leave)

            # Left side Info
            info = tk.Frame(card, bg=t["card_bg"])
            info.pack(side="left", fill="x", expand=True)

            top_row = tk.Frame(info, bg=t["card_bg"])
            top_row.pack(fill="x")

            # Favorite Toggle Button
            fav_star = "★" if is_fav else "☆"
            fav_col = t["gold"] if is_fav else t["text_muted"]
            fav_btn = tk.Button(
                top_row,
                text=fav_star,
                command=lambda tn=tool.name: self.toggle_fav_tool(tn),
                bg=t["card_bg"],
                fg=fav_col,
                activebackground=t["card_bg"],
                activeforeground=t["gold"],
                font=(FONT_FAMILY, 11),
                relief="flat",
                bd=0,
                cursor="hand2",
            )
            fav_btn.pack(side="left", padx=(0, 6))

            # Tool Name
            tk.Label(
                top_row,
                text=tool.name,
                bg=t["card_bg"],
                fg=t["text"],
                font=(FONT_FAMILY, 10, "bold"),
                anchor="w",
            ).pack(side="left")

            # Type Tag
            tag_color = t["danger"] if tool.admin else (t["gold"] if tool.console else t["accent"])
            if tool.is_custom:
                tag_color = "#c084fc"

            tk.Label(
                top_row,
                text=f" {tool.tag} ",
                bg=t["header_bg"],
                fg=tag_color,
                font=(FONT_FAMILY, 7, "bold"),
                padx=4,
                pady=1,
            ).pack(side="left", padx=(8, 0))

            # Status Badge
            status_text = "● READY" if exists else "● MISSING"
            status_color = t["primary"] if exists else t["danger"]
            tk.Label(
                top_row,
                text=status_text,
                bg=t["card_bg"],
                fg=status_color,
                font=(FONT_FAMILY, 7, "bold"),
            ).pack(side="left", padx=(8, 0))

            # Description
            tk.Label(
                info,
                text=tool.description,
                bg=t["card_bg"],
                fg=t["text_muted"],
                font=(FONT_FAMILY, 8),
                anchor="w",
                justify="left",
            ).pack(fill="x", pady=(3, 2))

            # File Badge
            tk.Label(
                info,
                text=f"📄 {tool_path.name}",
                bg=t["card_bg"],
                fg="#64748b",
                font=(FONT_MONO, 7),
                anchor="w",
            ).pack(fill="x")

            # Right Side Buttons
            btns = tk.Frame(card, bg=t["card_bg"])
            btns.pack(side="right", padx=(8, 0), pady=2)

            # More Options (...) Context Button
            more_btn = tk.Button(
                btns,
                text="⋯",
                command=lambda t=tool, p=tool_path, b=btns: self.show_tool_context_menu(t, p, b),
                bg=t["panel"],
                fg=t["text_muted"],
                activebackground=t["panel_line"],
                activeforeground=t["text"],
                relief="flat",
                bd=0,
                font=(FONT_FAMILY, 9, "bold"),
                padx=8,
                pady=5,
                cursor="hand2",
            )
            more_btn.pack(side="right", padx=(4, 0))

            # Launch Button
            if exists:
                launch_btn = tk.Button(
                    btns,
                    text="🚀 LAUNCH",
                    command=lambda t=tool: self.launch_tool(t),
                    bg=t["primary"],
                    fg="#ffffff",
                    activebackground=t["primary_hover"],
                    activeforeground="#ffffff",
                    relief="flat",
                    bd=0,
                    font=(FONT_FAMILY, 8, "bold"),
                    padx=14,
                    pady=6,
                    cursor="hand2",
                )
            else:
                launch_btn = tk.Button(
                    btns,
                    text="MISSING",
                    state="disabled",
                    bg=t["panel_line"],
                    fg=t["text_muted"],
                    relief="flat",
                    bd=0,
                    font=(FONT_FAMILY, 8, "bold"),
                    padx=12,
                    pady=6,
                )
            launch_btn.pack(side="right", padx=(4, 0))

            # Shortcut Button
            if exists:
                sc_btn = tk.Button(
                    btns,
                    text="🔗 SHORTCUT",
                    command=lambda t=tool: self.create_tool_shortcut(t),
                    bg=t["panel"],
                    fg=t["gold"],
                    activebackground=t["panel_line"],
                    activeforeground=t["gold"],
                    relief="flat",
                    bd=0,
                    font=(FONT_FAMILY, 8, "bold"),
                    padx=10,
                    pady=6,
                    cursor="hand2",
                )
            else:
                sc_btn = tk.Button(
                    btns,
                    text="SHORTCUT",
                    state="disabled",
                    bg=t["panel_line"],
                    fg=t["text_muted"],
                    relief="flat",
                    bd=0,
                    font=(FONT_FAMILY, 8),
                    padx=10,
                    pady=6,
                )
            sc_btn.pack(side="right")

    def toggle_fav_tool(self, tool_name):
        new_state = self.config_mgr.toggle_favorite(tool_name)
        status = "Added to" if new_state else "Removed from"
        self.log(f"{status} favorites: {tool_name}")
        self.render_tools()

    def show_tool_context_menu(self, tool, tool_path, button_widget):
        menu = tk.Menu(self.root, tearoff=0, bg=self.theme["panel"], fg=self.theme["text"], activebackground=self.theme["accent"], activeforeground="#000000")
        menu.add_command(label="🚀 Launch", command=lambda: self.launch_tool(tool))
        if "Icon" in tool.name:
            menu.add_command(label="🎨 Recolor Specific Icon File...", command=lambda: self.pick_and_recolor_icon(tool))
        menu.add_command(label="🛡 Run as Administrator", command=lambda: self.launch_tool(tool, force_admin=True))
        menu.add_separator()
        menu.add_command(label="🔗 Create Desktop Shortcut", command=lambda: self.create_tool_shortcut(tool))
        menu.add_separator()
        menu.add_command(label="✏ Edit Script in Notepad", command=lambda: self.edit_tool_script(tool_path))
        menu.add_command(label="📂 Reveal in File Explorer", command=lambda: self.reveal_file(tool_path))
        menu.add_command(label="📋 Copy Full Path", command=lambda: self.copy_path(tool_path))

        x = button_widget.winfo_rootx()
        y = button_widget.winfo_rooty() + button_widget.winfo_height()
        menu.tk_popup(x, y)

    def pick_and_recolor_icon(self, tool):
        chosen = filedialog.askopenfilename(
            title="Select Individual Icon or Shortcut to Recolor",
            filetypes=[
                ("Icons and Shortcuts", "*.ico;*.lnk"),
                ("ICO Files", "*.ico"),
                ("Shortcuts", "*.lnk"),
                ("All Files", "*.*"),
            ],
            parent=self.root,
        )
        if chosen:
            self.log(f"Opening Icon Changer for individual file: {chosen}")
            self.launch_tool_with_args(tool, f'-InputPath "{chosen}"')

    def launch_tool_with_args(self, tool, extra_args):
        folder = get_tools_dir(self.config_mgr.data)
        path = folder / tool.filename
        if not path.is_file():
            messagebox.showerror(self.title, f"Tool file not found: {path}", parent=self.root)
            return
        ps = powershell_exe()
        cmd = f'{ps} -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{path}" {extra_args}'
        subprocess.Popen(cmd, cwd=str(folder))
        self.log(f"Launched {tool.name} with custom arguments.", level="SUCCESS")

    def edit_tool_script(self, tool_path):
        if not tool_path.is_file():
            messagebox.showerror(self.title, f"File does not exist: {tool_path}", parent=self.root)
            return
        try:
            subprocess.Popen(["notepad.exe", str(tool_path)])
            self.log(f"Opened in Notepad: {tool_path.name}")
        except Exception as exc:
            self.log(f"Failed to open editor: {exc}", level="ERROR")

    def reveal_file(self, tool_path):
        if not tool_path.exists():
            messagebox.showerror(self.title, f"Path does not exist: {tool_path}", parent=self.root)
            return
        try:
            subprocess.Popen(["explorer.exe", f"/select,{tool_path}"])
            self.log(f"Revealed in Explorer: {tool_path.name}")
        except Exception as exc:
            self.log(f"Failed to reveal file: {exc}", level="ERROR")

    def copy_path(self, tool_path):
        self.root.clipboard_clear()
        self.root.clipboard_append(str(tool_path))
        self.log(f"Path copied to clipboard: {tool_path}")

    def create_tool_shortcut(self, tool):
        try:
            link = make_shortcut(tool, self.config_mgr.data)
            self.log(f"Shortcut created: {link.name} -> {link.parent}", level="SUCCESS")
            messagebox.showinfo(self.title, f"Desktop shortcut created successfully!\n\nTarget:\n{link}", parent=self.root)
        except Exception as exc:
            self.log(f"Shortcut failed for {tool.name}: {exc}", level="ERROR")
            messagebox.showerror(self.title, f"Could not create shortcut:\n{exc}", parent=self.root)

    def launch_tool(self, tool, force_admin=False):
        folder = get_tools_dir(self.config_mgr.data)
        if tool.is_custom and Path(tool.filename).is_file():
            path = Path(tool.filename)
        else:
            path = folder / tool.filename

        if not path.is_file():
            messagebox.showerror(self.title, f"Tool file not found:\n{path}", parent=self.root)
            return

        run_as_admin = force_admin or tool.admin

        # Confirmations
        if run_as_admin and self.config_mgr.get("confirm_admin", True):
            if not messagebox.askyesno(
                "Administrator Elevation Required",
                f"The tool '{tool.name}' requires administrator privileges.\n\nDo you want to proceed with UAC elevation?",
                parent=self.root,
            ):
                return

        if not run_as_admin and self.config_mgr.get("confirm_launch", False):
            if not messagebox.askyesno("Confirm Launch", f"Launch '{tool.name}'?", parent=self.root):
                return

        ps = powershell_exe()
        try:
            if run_as_admin:
                if path.suffix.lower() == ".bat" or path.suffix.lower() == ".cmd":
                    result = ctypes.windll.shell32.ShellExecuteW(
                        None, "runas", "cmd.exe", f'/c "{path}"', str(path.parent), 1
                    )
                else:
                    args = f'-NoProfile -ExecutionPolicy Bypass -STA -NoExit -File "{path}"'
                    result = ctypes.windll.shell32.ShellExecuteW(
                        None, "runas", ps, args, str(path.parent), 1
                    )
                if result <= 32:
                    raise RuntimeError("Administrator elevation was cancelled or denied.")
            elif path.suffix.lower() == ".bat" or path.suffix.lower() == ".cmd":
                subprocess.Popen(
                    ["cmd.exe", "/c", "call", str(path)],
                    cwd=str(path.parent),
                    creationflags=CREATE_NEW_CONSOLE if tool.console else CREATE_NO_WINDOW,
                )
            elif path.suffix.lower() == ".exe":
                subprocess.Popen([str(path)], cwd=str(path.parent))
            elif path.suffix.lower() == ".py":
                subprocess.Popen([sys.executable, str(path)], cwd=str(path.parent))
            else:
                args = [ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-STA"]
                if tool.console:
                    args.append("-NoExit")
                args.extend(["-File", str(path)])
                subprocess.Popen(
                    args,
                    cwd=str(path.parent),
                    creationflags=CREATE_NEW_CONSOLE if tool.console else CREATE_NO_WINDOW,
                )
            self.log(f"Launched {tool.name} ({'Admin' if run_as_admin else 'Standard'})", level="SUCCESS")
        except Exception as exc:
            self.log(f"Failed to launch {tool.name}: {exc}", level="ERROR")
            messagebox.showerror(self.title, f"Could not start {tool.name}:\n{exc}", parent=self.root)


def main():
    root = tk.Tk()
    SuiteApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
