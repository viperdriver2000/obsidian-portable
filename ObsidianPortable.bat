@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "APP_DIR=%SCRIPT_DIR%\App\Obsidian"
set "DATA_DIR=%SCRIPT_DIR%\Data\ObsidianAppData"
set "OBSIDIAN_EXE=%APP_DIR%\Obsidian.exe"

:: Check if Obsidian exists
if not exist "%OBSIDIAN_EXE%" (
    echo [Obsidian Portable] Obsidian not found. Running build script...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\build.ps1"
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

:: Fix portable paths (placeholder + drive letter)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\fix-paths.ps1" -DataDir "%DATA_DIR%"

echo [Obsidian Portable] Starting Obsidian...
echo [Obsidian Portable] Data: %DATA_DIR%

:: Launch Obsidian with portable data directory
start "" "%OBSIDIAN_EXE%" --user-data-dir="%DATA_DIR%"

endlocal
