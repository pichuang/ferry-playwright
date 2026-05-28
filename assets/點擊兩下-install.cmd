@echo off
REM Double-clickable launcher for install.ps1.
REM Invokes PowerShell with bypassed execution policy and forwards any arguments.
setlocal
set "SCRIPT_DIR=%~dp0"
echo Launching Playwright Offline installer...
echo (You will see a UAC prompt to grant Administrator rights.)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*
echo.
echo Installer finished. Press any key to close this window.
pause >nul
endlocal
