@echo off
setlocal
chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"
echo Launching Playwright Offline Dev Pack installer...
echo (You will see a UAC prompt to grant Administrator rights.)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-devpack.ps1" %*
echo.
echo Setup finished. Press any key to close this window.
pause >nul
endlocal
