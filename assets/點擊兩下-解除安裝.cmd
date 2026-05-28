@echo off
chcp 65001 >nul
REM Double-clickable launcher for uninstall.ps1.
REM Invokes PowerShell with bypassed execution policy and forwards any arguments.
setlocal
set "SCRIPT_DIR=%~dp0"
echo Launching Playwright Offline uninstaller...
echo (You will see a UAC prompt to grant Administrator rights.)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%uninstall.ps1" %*
echo.
echo Uninstaller finished. Press any key to close this window.
pause >nul
endlocal
