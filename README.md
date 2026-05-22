# Obsidian Portable

Portable version of [Obsidian](https://obsidian.md) — the markdown note-taking app.

All settings, plugins, caches and vaults stay in the portable directory. No traces left on the host system.

## Quick Start

1. **Clone or download** this repo
2. **Run `ObsidianPortable.bat`** — it auto-downloads and extracts the latest Obsidian version on first launch
3. Your vault is at `Data\Obsidian Vault\`

## How It Works

- `ObsidianPortable.bat` — Launcher, sets `--user-data-dir` to `Data\ObsidianAppData\` so all Electron/Chromium data (settings, plugins, caches) stays portable
- `build.ps1` — Downloads the latest Obsidian from GitHub Releases and extracts it to `App\Obsidian\`
- Vault paths in `obsidian.json` are automatically updated on each launch (handles drive letter changes for USB sticks)
- Auto-update is disabled (`updateDisabled: true`) to prevent Obsidian from replacing the portable setup

## Manual Build

```powershell
.\build.ps1                  # Build latest version
.\build.ps1 -Version "1.12.7"  # Build specific version
```

Requires [7-Zip](https://7-zip.org/) installed.

## Structure

```
obsidian-portable/
├── ObsidianPortable.bat    # Launch script
├── build.ps1               # Download & extract latest Obsidian
├── App/Obsidian/           # Obsidian application (auto-downloaded)
├── Data/
│   ├── ObsidianAppData/    # User data (settings, plugins, cache)
│   └── Obsidian Vault/     # Default vault
└── downloads/              # Temp downloads (gitignored)
```

## Credits

Based on the original [PortableApps.com ObsidianPortable](https://github.com/xmha97/PortableApps/tree/main/PortableApps/ObsidianPortable) by xmha97. Simplified to a standalone wrapper without NSIS dependencies.
