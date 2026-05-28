# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Seamless upgrade**: running `點擊兩下-setup.cmd` from a newer ZIP now
  smoothly upgrades an existing install without requiring an uninstall first.
  - Each ZIP carries a top-level **`VERSION.txt`** (semver), and `install.ps1`
    compares it to the version of the existing install to print
    `Upgrading vOLD -> vNEW` / `Reinstalling` / `Downgrade warning` /
    `Fresh install` banners.
  - `setup-devpack.ps1` writes a sentinel
    `<FeedDir>\PlaywrightOfflineFeed.INDEX.txt` listing every `.nupkg` it
    deployed. On the next install, packages whose id is in the new bundle but
    whose version differs are removed before the new files are copied — so
    obsolete versions don't accumulate. Other Microsoft offline packages (e.g.
    those left by Visual Studio Installer) are never touched.
  - `uninstall-devpack.ps1` now prefers the FeedDir sentinel (which covers
    everything accumulated across upgrades) and falls back to the bundled
    `nuget/INDEX.txt` for compatibility.
- Packager accepts `--version <semver>` (or `PACKAGE_VERSION` env var, or
  `git describe --tags` fallback) and stamps it into `VERSION.txt`,
  `BUILD-INFO.txt`, the dev pack `INDEX.txt` header, and the produced ZIP
  filename (`PlaywrightOffline-v<ver>-<rid>-<timestamp>.zip`).
- Release workflow passes `PACKAGE_VERSION` to the packager (from the git tag
  on tag builds) so every release ZIP carries the matching version string.

### Changed
- **BREAKING (packaging)**: collapsed the two release artifacts
  (`PlaywrightOffline-*.zip` runtime + `PlaywrightDevPack-*.zip` dev pack) into
  a **single** `PlaywrightOffline-*.zip` (~350 MB) containing both `app/`
  (runtime) and `nuget/` (offline NuGet feed). Removed the `--devpack` packager
  flag — the combined ZIP is always produced.
- New top-level entry script **`setup.ps1`** / **`點擊兩下-setup.cmd`** runs
  `install.ps1` (runtime) and `setup-devpack.ps1` (offline NuGet feed)
  back-to-back after a single UAC prompt.
- Top-level **`uninstall.ps1`** is now a wrapper that runs
  `uninstall-devpack.ps1` then `uninstall-runtime.ps1`. The previous runtime
  uninstall script was renamed `uninstall.ps1` → `uninstall-runtime.ps1`.
- README inside the ZIP is now a single combined document covering both
  runtime and dev pack flows.
- Release workflow simplified: only one ZIP is produced, verified, and
  attached to the GitHub Release. Verify-offline still only exercises the
  runtime portion (dev pack would make invasive machine-level changes).

### Removed
- Standalone `PlaywrightDevPack-*.zip` artifact (contents merged into the
  combined ZIP).
- `assets-devpack/點擊兩下-setup-devpack.cmd` and
  `assets-devpack/點擊兩下-uninstall-devpack.cmd` (advanced users can call the
  individual `.ps1` files directly).

## [0.4.0] - 2026-05-28

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
