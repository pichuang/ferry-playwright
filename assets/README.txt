Playwright Offline Package — End-User Instructions
===================================================

What's in this folder
---------------------
  app\               Self-contained .NET application + Playwright driver
  nuget\             Offline NuGet package feed (Microsoft.Playwright + deps)
  install.ps1        One-click installer (run as Administrator)
  uninstall.ps1      Removes the application
  BUILD-INFO.txt     Build metadata
  README.txt         This file

Prerequisites
-------------
  * Windows 11, or Windows Server 2022 (or newer).
  * Microsoft Edge installed (default on both Windows 11 and Windows Server 2022).
  * Administrator account.
  * NO internet connection required.

How to install
--------------
  1. Right-click 'install.ps1' and choose "Run with PowerShell".
     (Or open an elevated PowerShell and run:
         powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
     )
  2. Accept the UAC prompt if it appears.
  3. The script will:
       - Verify Windows version and Microsoft Edge.
       - Copy the application to "C:\Program Files\PlaywrightApp".
       - Set environment variables so Playwright never tries to download browsers.
       - Create Start Menu and Desktop shortcuts.
       - Copy bundled NuGet packages to "C:\Program Files\PlaywrightApp\nuget"
         and register them as a machine-scope NuGet source "PlaywrightOfflineFeed"
         (nuget.org is disabled to prevent accidental online restore — pass
         -KeepNuGetOrg to keep it enabled). Use -SkipNuGetFeed to skip entirely.

Offline NuGet feed
------------------
  After install, any `dotnet restore` on this machine that needs Microsoft.Playwright
  (and its dependencies) will pick them up from the bundled feed at
  "C:\Program Files\PlaywrightApp\nuget" without touching the internet.
  See nuget\INDEX.txt for the list of packages shipped in this build.

How to run
----------
  After install, open a NEW PowerShell or Command Prompt and run:

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe"

  Or pass a URL:

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" https://example.com

  The application launches the system-installed Microsoft Edge via Playwright,
  navigates to the URL, prints the page title, and waits for Enter to close.

How to uninstall
----------------
  Right-click 'uninstall.ps1' and choose "Run with PowerShell" (as Administrator).

Troubleshooting
---------------
  * "Microsoft Edge was not detected"
        - Confirm Edge is installed: check C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
        - If you are certain Edge is present, re-run install with: -SkipEdgeCheck
  * "Execution policy" errors when right-clicking
        - Open elevated PowerShell and run:
              powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
  * SmartScreen warning when running the .exe
        - The binary is unsigned. Click "More info" > "Run anyway",
          or have your organization sign it with your code-signing certificate.
