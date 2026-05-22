# Obsidian Portable Builder
# Downloads the latest Obsidian version and builds a portable package

param(
    [string]$Version = "latest",
    [string]$Arch = "64",
    [string]$ObsidianDir = "App\Obsidian"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "=== Obsidian Portable Builder ===" -ForegroundColor Cyan

# Determine version
if ($Version -eq "latest") {
    Write-Host "Fetching latest version from GitHub..." -ForegroundColor Gray
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" -TimeoutSec 15
        $Version = $release.tag_name -replace '^v', ''
        Write-Host "Latest version: $Version" -ForegroundColor Green
    } catch {
        Write-Error "Failed to fetch latest version: $_"
        exit 1
    }
}

$InstallerUrl = "https://github.com/obsidianmd/obsidian-releases/releases/download/v$Version/Obsidian-$Version.exe"
$DownloadDir = "$PSScriptRoot\downloads"
$InstallerPath = "$DownloadDir\Obsidian-$Version.exe"

# Create directories
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\$ObsidianDir" | Out-Null

# Find 7z
$7z = $null
$7zPaths = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
    "$PSScriptRoot\tools\7z.exe"
)
foreach ($p in $7zPaths) {
    if (Test-Path $p) { $7z = $p; break }
}
if (-not $7z) {
    Write-Error "7-Zip not found. Install from https://7-zip.org/ or place 7z.exe in tools\"
    exit 1
}
Write-Host "7-Zip: $7z" -ForegroundColor Gray

# Download installer
if (Test-Path $InstallerPath) {
    Write-Host "Installer already downloaded: $InstallerPath" -ForegroundColor Yellow
} else {
    Write-Host "Downloading Obsidian $Version..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
        Write-Host "Downloaded: $InstallerPath" -ForegroundColor Green
    } catch {
        Write-Error "Download failed: $_"
        exit 1
    }
}

# Extract app-64.7z from NSIS installer
Write-Host "Extracting app-64.7z from installer..." -ForegroundColor Gray
$extractTemp = "$DownloadDir\temp_extract"
Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null

$nsisPluginDir = '$PLUGINSDIR'
$result = & $7z x "$InstallerPath" -o"$extractTemp" -aoa 2>&1

# Find the extracted app archive
$appArchive = Get-ChildItem -Path $extractTemp -Recurse -Filter "app-64.7z" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $appArchive) {
    # Try directly extracting from the installer
    $result = & $7z x "$InstallerPath" -o"$extractTemp" "`$PLUGINSDIR/app-64.7z" -r -aoa 2>&1
    $appArchive = Get-ChildItem -Path $extractTemp -Recurse -Filter "app-64.7z" -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $appArchive) {
    Write-Warning "Could not find app-64.7z in installer. Trying alternative extraction..."
    # Some installers have the file in a subdirectory
    $result = & $7z x "$InstallerPath" -o"$extractTemp" -aoa 2>&1
    $appArchive = Get-ChildItem -Path $extractTemp -Recurse -Filter "app-64.7z" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $appArchive) {
        # Last resort: list contents and try to find
        Write-Host "Listing installer contents..." -ForegroundColor Yellow
        & $7z l "$InstallerPath" | Select-String "app-64"
        Write-Error "Cannot find app-64.7z in the installer. The installer format may have changed."
        exit 1
    }
}

# Extract app files
Write-Host "Extracting application files..." -ForegroundColor Gray
$obsidianTarget = "$PSScriptRoot\$ObsidianDir"
Remove-Item -Recurse -Force $obsidianTarget -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $obsidianTarget | Out-Null

& $7z x $appArchive.FullName -o"$obsidianTarget" -aoa 2>&1 | Out-Null

# Cleanup
Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue

Write-Host "Obsidian $Version extracted to: $obsidianTarget" -ForegroundColor Green

# Verify
$obsidianExe = "$obsidianTarget\Obsidian.exe"
if (Test-Path $obsidianExe) {
    $fileVersion = (Get-Item $obsidianExe).VersionInfo.ProductVersion
    Write-Host "Obsidian.exe version: $fileVersion" -ForegroundColor Green
} else {
    Write-Error "Obsidian.exe not found in $obsidianTarget. Extraction may have failed."
    exit 1
}

Write-Host "=== Build complete ===" -ForegroundColor Cyan
Write-Host "Run ObsidianPortable.bat to launch the portable version." -ForegroundColor White
