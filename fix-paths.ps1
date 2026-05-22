# Fix vault paths in obsidian.json for portability
# Handles: first-run placeholder replacement and drive letter changes

param(
    [string]$DataDir = $null
)

if (-not $DataDir) {
    $DataDir = Join-Path $PSScriptRoot "Data\ObsidianAppData"
}

$jsonPath = Join-Path $DataDir "obsidian.json"
if (-not (Test-Path $jsonPath)) {
    # Copy template on first run
    $templatePath = Join-Path $PSScriptRoot "Data\ObsidianAppData\obsidian.json"
    if (Test-Path $templatePath) {
        Copy-Item $templatePath $jsonPath -Force
    } else {
        exit 0
    }
}

$scriptDir = (Get-Item $PSScriptRoot).FullName.TrimEnd('\')
$content = Get-Content $jsonPath -Raw
$changed = $false

# Replace placeholder with actual portable directory
if ($content -match '__VAULT_DIR__') {
    $escapedDir = $scriptDir.Replace('\', '\\')
    $content = $content -replace '__VAULT_DIR__', $escapedDir
    $changed = $true
}

# Fix drive letter changes for existing vault paths
# This handles the case where the portable drive gets a different letter
$content = $content -replace '"path":"([A-Za-z]):(\\[^"]+)"', {
    $drive = $Matches[1]
    $rest = $Matches[2]
    $currentDrive = $scriptDir.Substring(0, 1)
    if ($drive -ne $currentDrive) {
        $changed = $true
        return '"path":"' + $currentDrive + ':' + $rest + '"'
    }
    return $Matches[0]
}

if ($changed) {
    Set-Content $jsonPath -Value $content -NoNewline
}
