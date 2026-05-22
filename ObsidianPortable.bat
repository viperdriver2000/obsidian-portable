@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "APP_DIR=%SCRIPT_DIR%\App\Obsidian"
set "DATA_DIR=%SCRIPT_DIR%\Data\ObsidianAppData"
set "OBSIDIAN_EXE=%APP_DIR%\Obsidian.exe"
set "VERSION_FILE=%SCRIPT_DIR%\App\version.txt"

:: Check if Obsidian needs installation
if not exist "%OBSIDIAN_EXE%" goto :install

:: Check for updates
echo [Obsidian Portable] Checking for new version...
set "UPDATE_AVAILABLE=0"
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $r = Invoke-RestMethod 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest' -TimeoutSec 10; ^
     Write-Host $($r.tag_name -replace '^v','') } catch { Write-Host 'unknown' }" 2^>nul') do set "LATEST_VER=%%i"

if "%LATEST_VER%"=="unknown" goto :skip_update
if "%LATEST_VER%"=="" goto :skip_update

:: Compare with installed version
if exist "%VERSION_FILE%" (
    for /f "delims=" %%i in (%VERSION_FILE%) do set "CURRENT_VER=%%i"
    if not "!CURRENT_VER!"=="%LATEST_VER%" (
        echo [Obsidian Portable] Update available: !CURRENT_VER! -^> %LATEST_VER%
        echo [Obsidian Portable] Updating...
        call :update "%LATEST_VER%"
    ) else (
        echo [Obsidian Portable] Up to date ^(!CURRENT_VER!^)
    )
) else (
    echo [Obsidian Portable] No version info, building latest...
    call :update "latest"
)
goto :skip_update

:install
echo [Obsidian Portable] Installing...
call :update "latest"
goto :skip_update

:update
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\build.ps1" -Version "%~1"
if errorlevel 1 (
    echo [Obsidian Portable] Update/install failed.
    pause
    exit /b 1
)
exit /b

:skip_update

:: Ensure Obsidian exists
if not exist "%OBSIDIAN_EXE%" (
    echo [Obsidian Portable] Obsidian.exe not found. Install failed.
    pause
    exit /b 1
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
