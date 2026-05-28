# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Dev Pack ZIP** (`PlaywrightDevPack-win-x64-*.zip`) — separate, opt-in
  offline NuGet bundle for **dev machines that want to write new Playwright
  tests offline**. Produced by packager when called with `--devpack`.
  - Contains `Microsoft.Playwright`, `Microsoft.Playwright.NUnit`,
    `Microsoft.Playwright.MSTest`, `Microsoft.NET.Test.Sdk`, NUnit, MSTest,
    and their dependencies (≈ 280 MB, 26 nupkgs).
  - `setup-devpack.ps1` self-elevates, copies `.nupkg` files into the
    **standard machine-wide offline feed**
    (`%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages`) — the same folder
    Visual Studio Installer uses — and registers a NuGet source in
    `%ProgramData%\NuGet\NuGet.Config`. After setup, any project on the
    machine can `dotnet add package Microsoft.Playwright` with no internet.
  - Also sets `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` and
    `PLAYWRIGHT_BROWSERS_PATH=0` so the dev pack works standalone (no need
    to also install the runtime ZIP).
  - Existing `NuGet.Config` is backed up to `.bak.YYYYMMDD-HHMMSS` before
    editing. `nuget.org` is **not** disabled by default; pass
    `-DisableNuGetOrg` for strict offline mode.
  - `uninstall-devpack.ps1` removes the source entry and the .nupkg files
    we deployed (by `INDEX.txt` allow-list, so other Microsoft offline
    packages in the shared folder are untouched).
- Release workflow now builds and attaches both ZIPs to every GitHub
  Release. The `verify-offline` job intentionally only tests the runtime
  ZIP — exercising the dev pack on the runner would make invasive
  machine-wide NuGet config changes.

## [0.3.0] - 2026-05-28

### Documentation
- README: new section **「想在這台機器寫自己的 Playwright 測試？」** with
  step-by-step guides for VS Code, Visual Studio, and PowerShell. Explains
  the .NET SDK prerequisite, the machine-scope env vars our installer sets,
  and the `Channel = "msedge"` pattern that keeps everything offline.

### Changed
- Renamed double-click launchers to `點擊兩下-install.cmd` /
  `點擊兩下-uninstall.cmd` so end users see the "double-click" hint
  directly in the filename. The underlying `install.ps1` / `uninstall.ps1`
  scripts keep their original names.
- End-user `assets/README.txt` rewritten in Traditional Chinese
  (UTF-8 with BOM) so it displays correctly in Notepad on Windows.
- Packager now writes the ZIP with UTF-8 entry name encoding (sets
  General-purpose bit 11) so Chinese filenames survive Windows
  Explorer's built-in extractor.

## [0.2.0] - 2026-05-28

### Added
- Hello-World self-test embedded in `PlaywrightSampleApp`: navigates to a
  built-in `data:` URL with a "Hello, Playwright!" page, asserts the page
  title, DOM text content, and a JS-evaluated value, then prints a clear
  `RESULT: PASS` / `RESULT: FAIL` line and exits with the matching code.
  No network required; works on a fully air-gapped Windows machine.
- Double-click launchers `install.cmd` / `uninstall.cmd` so end users no
  longer need to right-click the .ps1 files. The .cmd wrappers forward
  arguments to the underlying PowerShell scripts and `pause` so the user
  can read the output before the window closes.

## [0.1.0] - 2026-05-27

### Added
- Initial release of the offline Playwright packager.
- `PlaywrightSampleApp` (.NET 10 console) that launches the system-installed
  Microsoft Edge via Playwright (`Channel="msedge"`) — no browser downloads needed.
- CI mode in the sample app (`--ci` or `CI=true`): headless, non-interactive,
  defaults to `about:blank` for offline smoke testing.
- `PlaywrightOfflinePackager` (.NET 10 console) that produces a self-contained
  `win-x64` ZIP bundle including:
  - The published application with embedded .NET runtime
  - Playwright's Node driver (`.playwright/node/win32_x64/node.exe`)
  - PowerShell `install.ps1` / `uninstall.ps1`
  - `README.txt` for end users
- `install.ps1`: self-elevation, Windows-version and Edge presence checks,
  installs to `%ProgramFiles%\PlaywrightApp`, sets machine-scope environment
  variables `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` and `PLAYWRIGHT_BROWSERS_PATH=0`,
  creates Start Menu and Desktop shortcuts.
- GitHub Actions release workflow with three jobs:
  1. **package** — runs the packager on Ubuntu and produces the ZIP plus
     a generated `release-notes.md` containing version diff vs previous tag.
  2. **verify-offline** — on `windows-2022`, blocks all outbound traffic with
     Windows Defender Firewall, installs and runs the application, and audits
     TCP connections to prove no external network calls occur.
  3. **release** — only on `v*` tags; publishes a GitHub Release containing
     the ZIP and auto-generated release notes.
