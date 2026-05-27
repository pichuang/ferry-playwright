# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Double-click launchers `install.cmd` / `uninstall.cmd` so end users no
  longer need to right-click the .ps1 files. The .cmd wrappers forward
  arguments to the underlying PowerShell scripts and `pause` so the user
  can read the output before the window closes.
- Bundle the sample project's NuGet restore graph (`Microsoft.Playwright` and
  its dependencies) as `.nupkg` files inside the offline ZIP under `nuget/`.
- New packager step `Stage NuGet packages` runs `dotnet restore --packages --runtime`
  for the sample project, flattens the resulting `.nupkg` files, and writes
  `nuget/INDEX.txt` listing them.
- `install.ps1` now copies `nuget/` into `%InstallDir%\nuget` and writes a
  machine-level `%ProgramData%\NuGet\NuGet.Config` that registers
  `PlaywrightOfflineFeed`. Adds `-SkipNuGetFeed` and `-KeepNuGetOrg` switches.
- `uninstall.ps1` removes the source entry (restoring any backed-up config) and
  deletes the bundled `nuget/` folder.

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
