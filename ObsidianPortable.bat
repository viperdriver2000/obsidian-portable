@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%App\Obsidian"
set "DATA_DIR=%SCRIPT_DIR%Data\ObsidianAppData"
set "OBSIDIAN_EXE=%APP_DIR%\Obsidian.exe"

:: Remove trailing backslash for clean paths
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Check if Obsidian exists
if not exist "%OBSIDIAN_EXE%" (
    echo [Obsidian Portable] Obsidian not found. Running build script...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build.ps1"
    if errorlevel 1 (
        echo [Obsidian Portable] Build failed.
        pause
        exit /b 1
    )
    if not exist "%OBSIDIAN_EXE%" (
        echo [Obsidian Portable] Obsidian.exe still not found after build.
        pause
        exit /b 1
    )
)

:: Ensure data directories exist
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

:: Initialize obsidian.json if it doesn't exist
if not exist "%DATA_DIR%\obsidian.json" (
    if exist "%SCRIPT_DIR%\Data\ObsidianAppData\obsidian.json" (
        copy "%SCRIPT_DIR%\Data\ObsidianAppData\obsidian.json" "%DATA_DIR%\obsidian.json" >nul
    )
)

:: Fix up vault paths - convert placeholder and update drive letters
if exist "%DATA_DIR%\obsidian.json" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$dataDir = '%DATA_DIR%'; ^
         $scriptDir = '%SCRIPT_DIR%'; ^
         $jsonPath = Join-Path $dataDir 'obsidian.json'; ^
         if (-not (Test-Path $jsonPath)) { exit 0 }; ^
         $content = Get-Content $jsonPath -Raw; ^
         $changed = $false; ^
         if ($content -match '__VAULT_DIR__') { ^
             $content = $content -replace '__VAULT_DIR__', $scriptDir.Replace('\', '\\'); ^
             $changed = $true; ^
         }; ^
         if ($changed) { Set-Content $jsonPath -Value $content -NoNewline }"
)

echo [Obsidian Portable] Data dir: %DATA_DIR%
echo [Obsidian Portable] Starting Obsidian...

:: Set user data path for Electron/Chromium
set "OBSIDIAN_USER_DATA_PATH=%DATA_DIR%"

:: Launch Obsidian with portable data directory
start "" "%OBSIDIAN_EXE%" --user-data-dir="%DATA_DIR%"

endlocal
