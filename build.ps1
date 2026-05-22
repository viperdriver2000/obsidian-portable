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
$7zExe = "$ToolsDir\7za.exe"

Write-Host "=== Obsidian Portable Builder ===" -ForegroundColor Cyan

# Ensure tools directory
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

# Find or download 7-Zip standalone
if (-not (Test-Path $7zExe)) {
    $system7z = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($system7z) {
        $7zExe = $system7z
        Write-Host "7-Zip found: $7zExe" -ForegroundColor Gray
    } else {
        Write-Host "7-Zip not found. Downloading standalone 7za.exe..." -ForegroundColor Yellow
        $7zUrl = "https://www.7-zip.org/a/7z2409-extra.7z"
        $7zDownload = "$ToolsDir\7z-extra.7z"
        
        if (-not (Test-Path $7zDownload)) {
            Invoke-WebRequest -Uri $7zUrl -OutFile $7zDownload
        }
        
        # Extract 7za.exe from the package using .NET (since we don't have 7z yet)
        # The 7z extra package contains 7za.exe directly at the root
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($7zDownload, "$ToolsDir\7z-extract")
        } catch {
            # Not a zip, try renaming to zip (some servers send wrong content-type)
        }
        
        if (Test-Path "$ToolsDir\7z-extract\7za.exe") {
            Copy-Item "$ToolsDir\7z-extract\7za.exe" $7zExe -Force
            Remove-Item -Recurse -Force "$ToolsDir\7z-extract" -ErrorAction SilentlyContinue
        } else {
            # Manual extraction with PowerShell - download the zip version instead
            Write-Host "Trying alternative download..." -ForegroundColor Yellow
            $7zAltUrl = "https://github.com/ip7z/7zip/releases/download/24.09/7z2409-extra.7z"
            Invoke-WebRequest -Uri $7zAltUrl -OutFile $7zDownload
            # Need 7z to extract 7z. Download older standalone version
            $standaloneUrl = "https://www.7-zip.org/a/7za920.zip"
            Invoke-WebRequest -Uri $standaloneUrl -OutFile "$ToolsDir\7za.zip"
            Expand-Archive -Path "$ToolsDir\7za.zip" -DestinationPath "$ToolsDir\7za-temp" -Force
            Copy-Item "$ToolsDir\7za-temp\7za.exe" "$ToolsDir\7z-bootstrap.exe" -Force
            Remove-Item -Recurse -Force "$ToolsDir\7za-temp" -ErrorAction SilentlyContinue
            
            # Use bootstrap to extract real 7za
            & "$ToolsDir\7z-bootstrap.exe" x $7zDownload -o"$ToolsDir\7z-extract" -aoa 2>&1 | Out-Null
            if (Test-Path "$ToolsDir\7z-extract\7za.exe") {
                Copy-Item "$ToolsDir\7z-extract\7za.exe" $7zExe -Force
            }
            Remove-Item -Recurse -Force "$ToolsDir\7z-extract" -ErrorAction SilentlyContinue
            Remove-Item "$ToolsDir\7z-bootstrap.exe" -ErrorAction SilentlyContinue
        }
        Remove-Item $7zDownload -ErrorAction SilentlyContinue
        Remove-Item "$ToolsDir\7za.zip" -ErrorAction SilentlyContinue
        
        if (Test-Path $7zExe) {
            Write-Host "7-Zip standalone ready: $7zExe" -ForegroundColor Green
        } else {
            Write-Error "Failed to download 7-Zip. Please install from https://7-zip.org/"
            exit 1
        }
    }
}
Write-Host "7-Zip: $7zExe" -ForegroundColor Gray

# Determine version
if ($Version -eq "latest") {
    Write-Host "Fetching latest version from GitHub..." -ForegroundColor Gray
    try {
        $headers = @{}
        if ($env:GITHUB_TOKEN) { $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" -Headers $headers -TimeoutSec 15
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

# Download installer
if (Test-Path $InstallerPath) {
    Write-Host "Installer already downloaded: $InstallerPath" -ForegroundColor Yellow
} else {
    Write-Host "Downloading Obsidian $Version..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
        Write-Host "Downloaded" -ForegroundColor Green
    } catch {
        Write-Error "Download failed: $_"
        exit 1
    }
}

# Extract app-64.7z from NSIS installer
Write-Host "Extracting from installer..." -ForegroundColor Gray
$extractTemp = "$DownloadDir\temp_extract"
Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null

# Extract everything from installer, then find app-64.7z
& $7zExe x "$InstallerPath" -o"$extractTemp" -aoa 2>&1 | Out-Null

$appArchive = Get-ChildItem -Path $extractTemp -Recurse -Filter "app-64.7z" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $appArchive) {
    Write-Host "Listing installer contents for debugging:" -ForegroundColor Yellow
    & $7zExe l "$InstallerPath" 2>&1 | Select-String "app-" | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    Write-Error "Cannot find app-64.7z in the installer. Format may have changed."
    exit 1
}

# Extract app files to target
Write-Host "Extracting application files..." -ForegroundColor Gray
$obsidianTarget = "$PSScriptRoot\$ObsidianDir"
Remove-Item -Recurse -Force $obsidianTarget -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $obsidianTarget | Out-Null

& $7zExe x $appArchive.FullName -o"$obsidianTarget" -aoa 2>&1 | Out-Null

# Cleanup
Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue

# Write version file
$Version | Out-File -FilePath "$PSScriptRoot\$ObsidianDir\..\version.txt" -NoNewline -Encoding ascii

Write-Host "Obsidian $Version extracted to: $obsidianTarget" -ForegroundColor Green

# Verify
$obsidianExe = "$obsidianTarget\Obsidian.exe"
if (Test-Path $obsidianExe) {
    $fileVersion = (Get-Item $obsidianExe).VersionInfo.ProductVersion
    Write-Host "Obsidian.exe version: $fileVersion" -ForegroundColor Green
} else {
    Write-Error "Obsidian.exe not found!"
    exit 1
}

Write-Host "=== Build complete ===" -ForegroundColor Cyan
