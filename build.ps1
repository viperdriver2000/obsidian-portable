# Obsidian Portable Builder
# Downloads the latest Obsidian version and builds a portable package

param(
    [string]$Version = "latest",
    [string]$Arch = "64"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ObsidianDir = "App\Obsidian"
$ToolsDir = "$PSScriptRoot\tools"
$7zExe = "$ToolsDir\7z.exe"
$Bootstrap7z = "$ToolsDir\7zr.exe"

Write-Host "=== Obsidian Portable Builder ===" -ForegroundColor Cyan

# Ensure tools directory
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

# ------------------------------------------------------------------
# 7-Zip: find system install or bootstrap
# ------------------------------------------------------------------
$needBootstrap = $false
if (-not (Test-Path $7zExe)) {
    $system7z = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($system7z) {
        $7zExe = $system7z
        Write-Host "7-Zip found: $7zExe" -ForegroundColor Gray
    } else {
        $needBootstrap = $true
    }
}

if ($needBootstrap) {
    Write-Host "7-Zip not found. Bootstrapping..." -ForegroundColor Yellow

    # Step 1: Download 7zr.exe (standalone, ~300KB, handles 7z/LZMA)
    if (-not (Test-Path $Bootstrap7z)) {
        Write-Host "  Downloading 7zr.exe..." -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile $Bootstrap7z
        } catch {
            Write-Host "  Primary mirror failed, trying GitHub..." -ForegroundColor DarkYellow
            Invoke-WebRequest -Uri "https://github.com/ip7z/7zip/releases/download/26.01/7zr.exe" -OutFile $Bootstrap7z
        }
    }

    if (-not (Test-Path $Bootstrap7z)) {
        Write-Error "Failed to download 7zr.exe"
        exit 1
    }
    Write-Host "  7zr.exe ready" -ForegroundColor Green

    # Step 2: Download 7-Zip Extra package (contains 7z.exe + 7z.dll with full codec support)
    $extra7z = "$ToolsDir\7z-extra.7z"
    if (-not (Test-Path $extra7z)) {
        Write-Host "  Downloading 7-Zip Extra..." -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri "https://www.7-zip.org/a/7z2601-extra.7z" -OutFile $extra7z
        } catch {
            try {
                Invoke-WebRequest -Uri "https://github.com/ip7z/7zip/releases/download/26.01/7z2601-extra.7z" -OutFile $extra7z
            } catch {
                Write-Error "Failed to download 7-Zip Extra package"
                exit 1
            }
        }
    }

    # Step 3: Use 7zr to extract 7z.exe + 7z.dll from the extra package
    Write-Host "  Extracting 7z.exe..." -ForegroundColor Gray
    $extractDir = "$ToolsDir\_extract"
    Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue

    # Extract 7z.exe and 7z.dll (7z.exe loads 7z.dll for full format support including NSIS)
    & $Bootstrap7z x $extra7z -o"$extractDir" "7z.exe" "7z.dll" -aoa 2>&1 | Out-Null

    $extracted7z = "$extractDir\7z.exe"
    $extractedDll = "$extractDir\7z.dll"

    if ((Test-Path $extracted7z) -and (Test-Path $extractedDll)) {
        Move-Item $extracted7z $7zExe -Force
        Move-Item $extractedDll "$ToolsDir\7z.dll" -Force
        Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
        Remove-Item $extra7z -ErrorAction SilentlyContinue
        Write-Host "  7z.exe + 7z.dll ready" -ForegroundColor Green
    } else {
        # If 7z.exe not in extras, try extracting 7za.exe as fallback
        Write-Host "  7z.exe not in extras, trying 7za.exe..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
        & $Bootstrap7z x $extra7z -o"$extractDir" "7za.exe" -aoa 2>&1 | Out-Null
        if (Test-Path "$extractDir\7za.exe") {
            Move-Item "$extractDir\7za.exe" $7zExe -Force
            Remove-Item $extra7z -ErrorAction SilentlyContinue
            Write-Host "  7za.exe ready (NSIS support may be limited)" -ForegroundColor DarkYellow
        } else {
            Write-Host "  Using 7zr.exe as fallback (7z/LZMA only)" -ForegroundColor DarkYellow
            $7zExe = $Bootstrap7z
        }
        Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
    }
}

Write-Host "7-Zip: $7zExe" -ForegroundColor Gray

# ------------------------------------------------------------------
# Determine version
# ------------------------------------------------------------------
if ($Version -eq "latest") {
    Write-Host "Fetching latest Obsidian version from GitHub..." -ForegroundColor Gray
    try {
        $headers = @{}
        if ($env:GITHUB_TOKEN) { $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" -Headers $headers -TimeoutSec 15
        $Version = $release.tag_name -replace '^v', ''
        Write-Host "Latest: v$Version" -ForegroundColor Green
    } catch {
        Write-Error "Failed to fetch latest version: $_"
        exit 1
    }
}

$InstallerUrl = "https://github.com/obsidianmd/obsidian-releases/releases/download/v$Version/Obsidian-$Version.exe"
$DownloadDir = "$PSScriptRoot\downloads"
$InstallerPath = "$DownloadDir\Obsidian-$Version.exe"

# ------------------------------------------------------------------
# Download installer
# ------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\$ObsidianDir" | Out-Null

if (-not (Test-Path $InstallerPath)) {
    Write-Host "Downloading Obsidian v$Version..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
        Write-Host "Downloaded" -ForegroundColor Green
    } catch {
        Write-Error "Download failed: $_"
        exit 1
    }
} else {
    Write-Host "Installer cached" -ForegroundColor Gray
}

# ------------------------------------------------------------------
# Extract Obsidian app files from NSIS installer
# ------------------------------------------------------------------
Write-Host "Extracting Obsidian..." -ForegroundColor Gray
$extractTemp = "$DownloadDir\temp_extract"
Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null

# Extract app-64.7z from NSIS installer using 7z
# Use cmd /c to avoid PowerShell argument parsing issues
$app7zPath = '$PLUGINSDIR/app-64.7z'
cmd /c "`"$7zExe`" x `"$InstallerPath`" -o`"$extractTemp`" $app7zPath -aoa" 2>&1 | Out-Null

$appArchive = Get-ChildItem -Path $extractTemp -Recurse -Filter "app-64.7z" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $appArchive) {
    Write-Host "  Targeted extraction failed. Trying full extract..." -ForegroundColor Yellow
    # Remove and recreate temp dir
    Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
    
    cmd /c "`"$7zExe`" x `"$InstallerPath`" -o`"$extractTemp`" -aoa" 2>&1 | Out-Null
    $appArchive = Get-ChildItem -Path $extractTemp -Recurse -Filter "app-64.7z" -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $appArchive) {
    Write-Host "  7z extraction failed. Trying silent NSIS install..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
    
    # Run NSIS installer silently (/S = silent, /D= must be last, no quotes on path)
    $proc = Start-Process -FilePath $InstallerPath -ArgumentList "/S", "/D=$extractTemp" -Wait -PassThru -NoNewWindow
    
    $installedExe = Get-ChildItem -Path $extractTemp -Recurse -Filter "Obsidian.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedExe) {
        $obsidianTarget = "$PSScriptRoot\$ObsidianDir"
        Remove-Item -Recurse -Force $obsidianTarget -ErrorAction SilentlyContinue
        $sourceDir = Split-Path -Parent $installedExe.FullName
        Move-Item -Path $sourceDir -Destination $obsidianTarget
        Write-Host "  Installed via NSIS" -ForegroundColor Green
        Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Contents of temp dir:" -ForegroundColor Gray
        Get-ChildItem -Path $extractTemp -Recurse -Depth 1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
        Write-Error "All extraction methods failed. Please install 7-Zip manually: https://7-zip.org/"
        exit 1
    }
} else {
    # Extract app-64.7z to target
    $obsidianTarget = "$PSScriptRoot\$ObsidianDir"
    Remove-Item -Recurse -Force $obsidianTarget -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $obsidianTarget | Out-Null

    cmd /c "`"$7zExe`" x `"$($appArchive.FullName)`" -o`"$obsidianTarget`" -aoa" 2>&1 | Out-Null
    Write-Host "  Extracted via 7z" -ForegroundColor Green
    Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
}

# Save installed version
$Version | Out-File -FilePath "$PSScriptRoot\App\version.txt" -NoNewline -Encoding ascii

# Cleanup
Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue

Write-Host "Obsidian v$Version installed" -ForegroundColor Green

# Verify
$obsidianExe = "$obsidianTarget\Obsidian.exe"
if (-not (Test-Path $obsidianExe)) {
    Write-Error "Obsidian.exe not found in $obsidianTarget"
    exit 1
}

Write-Host "=== Done ===" -ForegroundColor Cyan
