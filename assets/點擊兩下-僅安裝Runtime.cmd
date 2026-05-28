@echo off
chcp 65001 >nul
REM Double-clickable launcher for install.ps1 (runtime only — Edge driver app).
REM For the recommended runtime + dev pack combo, use 點擊兩下-完整安裝(推薦).cmd.
setlocal
set "SCRIPT_DIR=%~dp0"
echo Launching Playwright Offline RUNTIME-only installer...
echo (For the full Runtime + Dev pack install, use 點擊兩下-完整安裝(推薦).cmd instead.)
echo (You will see a UAC prompt to grant Administrator rights.)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*
echo.
echo Installer finished. Press any key to close this window.
pause >nul
endlocal
