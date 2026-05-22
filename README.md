# Obsidian Portable

Portable version of [Obsidian](https://obsidian.md) — the markdown note-taking app.

All settings, plugins, caches and vaults stay in the portable directory. No traces left on the host system. **Auto-updates on every launch.**

## Quick Start

1. **Clone or download** this repo
2. **Run `ObsidianPortable.bat`** — it downloads and sets up everything automatically
3. Your vault is at `Data\Obsidian Vault\`

## Features

- **Auto-update**: Checks for new Obsidian versions on each launch, downloads & updates if found
- **Auto-install 7-Zip**: Downloads standalone 7za.exe if 7-Zip is not installed
- **Fully portable**: `--user-data-dir` routes all Electron/Chromium data to `Data/`
- **Drive letter handling**: Vault paths automatically adapt when USB stick gets a different letter
- **No dependencies**: Just clone and run. No NSIS, no PortableApps.com Framework needed

## How It Works

| File | Purpose |
|------|---------|
| `ObsidianPortable.bat` | Launcher — checks for updates, fixes paths, starts Obsidian |
| `build.ps1` | Downloads latest Obsidian installer, extracts with 7-Zip |
| `fix-paths.ps1` | Updates vault paths on launch (placeholder + drive letter changes) |

## Manual Build

```powershell
.\build.ps1                  # Build latest version
.\build.ps1 -Version "1.12.7"  # Build specific version
```

## Structure

```
obsidian-portable/
├── ObsidianPortable.bat    # Launch script
├── build.ps1               # Download & extract Obsidian
├── fix-paths.ps1            # Path fixer
├── App/
│   ├── Obsidian/           # Obsidian app (auto-downloaded)
│   └── version.txt         # Installed version
├── Data/
│   ├── ObsidianAppData/    # User data (settings, plugins, cache)
│   └── Obsidian Vault/     # Default vault
├── tools/                  # 7za.exe (auto-downloaded)
└── downloads/              # Temp downloads (gitignored)
```

## Credits

Based on the original [PortableApps.com ObsidianPortable](https://github.com/xmha97/PortableApps/tree/main/PortableApps/ObsidianPortable) by xmha97. Simplified to a standalone wrapper.
