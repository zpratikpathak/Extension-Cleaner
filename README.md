<p align="center">
  <img src="icon.svg" alt="Extension Cleaner icon" width="160">
</p>

<h1 align="center">Extension Cleaner</h1>

<p align="center">
  Are unwanted extensions being installed automatically even after you remove the software that added them? Extension Cleaner helps you find and remove the leftover registry entries and policies responsible.
</p>

<p align="center">
  <a href="https://github.com/zpratikpathak/Extension-Cleaner">GitHub Repository</a>
</p>

<p align="center">
  An interactive PowerShell utility for finding and removing registry-installed and policy-forced extensions from Chrome, Edge, and Brave on Windows.
</p>

## Quick Start

Open PowerShell, paste this one-line command, and press Enter:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/zpratikpathak/Extension-Cleaner/home/remove.ps1 | iex"
```

Windows will display a User Account Control prompt because administrator access is required to remove machine-level registry entries.

## Features

- Supports Google Chrome, Microsoft Edge, and Brave.
- Scans user, machine, and 32-bit registry locations.
- Detects extensions enforced through browser policies.
- Resolves extension names from local manifests and localized message files.
- Checks the appropriate browser store only when a name cannot be found locally.
- Provides an interactive keyboard-driven selection menu.
- Automatically requests administrator privileges when required.
- Supports safe cancellation with `Esc` or `Ctrl+C`.

## Manual Usage

1. Download the [Extension Cleaner ZIP archive](https://github.com/zpratikpathak/Extension-Cleaner/archive/refs/heads/home.zip).
2. Extract the downloaded ZIP file.
3. Open a terminal inside the extracted `Extension-Cleaner-home` folder.
4. Run:

```powershell
powershell -ExecutionPolicy Bypass -c ".\remove.ps1"
```

The script automatically relaunches itself as administrator when necessary.

## Controls

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move through detected extensions |
| `Space` | Select or deselect an extension |
| `Enter` | Remove selected extensions |
| `Esc` / `Ctrl+C` | Exit without removing anything |

## How It Works

Extension Cleaner scans Chromium extension registry keys and managed policy lists under `HKCU` and `HKLM`. It first resolves names from locally installed extension manifests. If no local name is available, it checks Microsoft Edge Add-ons for Edge entries and then the Chrome Web Store as a fallback.

Only items selected in the interactive menu are removed. The script does not delete browser profile data or unrelated extensions.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- Administrator access
- Internet access for the quick-start download and unresolved extension-name lookups

## Author

Created by [Pratik Pathak](https://github.com/zpratikpathak).
