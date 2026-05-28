# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Dev-pack setup now places bundled `.nupkg` files under the user's default
  NuGet package location (`%USERPROFILE%\.nuget\packages`) instead of the
  machine-wide Visual Studio offline package folder, while still registering
  `PlaywrightOfflineFeed` for strict offline restores.

## [0.6.0] - 2026-05-28

### BREAKING
- **ZIP no longer contains a precompiled `PlaywrightSampleApp.exe`** under
  `app/`. The "runtime" portion of the package has been removed because the
  binary on its own has little reference value for users learning to write
  offline Playwright projects.
- Removed: `install.ps1`, `uninstall-runtime.ps1`,
  `點擊兩下-僅安裝Runtime.cmd`, Start Menu / Desktop shortcuts.
- `setup.ps1` is now a thin wrapper around `setup-devpack.ps1` (only the
  dev pack gets installed). Both `setup.ps1` and `uninstall.ps1` will
  best-effort clean up the legacy `%ProgramFiles%\PlaywrightApp` folder
  if it exists (for users upgrading from v0.5.x).

### Added
- **Three reference sample projects** bundled under `samples/`:
  - `samples/hello-nunit/`  — NUnit + `Microsoft.Playwright.NUnit` test
  - `samples/hello-mstest/` — MSTest + `Microsoft.Playwright.MSTest` test
  - `samples/hello-console/` — pure console + `Microsoft.Playwright`
  Each is fully wired for offline use: project-local `NuGet.config`
  (`<clear />` + offline feed), `.csproj` with PackageReferences pinned to
  the bundled versions, ready-to-run source, `.runsettings` (for tests)
  pointing Playwright at Edge channel, and a short `README.md`.
- The CI `verify-offline` job now proves offline readiness by running
  `dotnet restore` + `dotnet build` against `samples/hello-console` with
  all outbound traffic firewalled.

### Changed
- `src/PlaywrightSampleApp/` is retained in the repo (so the codebase
  still builds end-to-end) but the packager no longer publishes or
  bundles it.
- ZIP filename format unchanged: `PlaywrightOffline-vX.Y.Z-win-x64-<ts>.zip`.

### Migration from v0.5.x
1. Unzip the new release.
2. Double-click `點擊兩下-完整安裝(推薦).cmd` — it will clean up the old
   `%ProgramFiles%\PlaywrightApp` and install the v0.6 dev pack.
3. Use the new `samples/` projects (or `new-playwright-project.ps1`) as
   your starting point.

## [0.5.3] - 2026-05-28

### Fixed
- `dotnet restore` (and `dotnet new nunit` / `dotnet new mstest` implicit restore)
  no longer fails with `NU1101: 找不到套件 coverlet.collector` /
  `nunit.analyzers` on air-gapped machines. The SDK's `nunit` / `mstest`
  project templates implicitly add `PackageReference` entries for these
  "nice-to-have" analyzers/coverage packages, which v0.5.2's offline feed
  did not bundle.

### Added
- Dev pack now bundles three additional packages so the stock `dotnet new
  nunit` / `dotnet new mstest` templates restore fully offline:
  - `coverlet.collector` 6.0.2 (code-coverage collector — both templates)
  - `NUnit.Analyzers` 4.4.0 (matches NUnit 4.x)
  - `MSTest.Analyzers` 3.6.4 (matches bundled MSTest.* 3.6.4)
- `new-playwright-project.ps1` now pins these extras via
  `dotnet add package --version` for `nunit` and `mstest` templates, so
  restore always resolves them against the bundled feed even if a newer
  SDK ships a template that wants a different patch level.

## [0.5.2] - 2026-05-28

### Added
- **`new-playwright-project.ps1` helper script** — bootstraps a new offline
  Playwright project in one command:
  ```
  & "$Env:ProgramFiles\PlaywrightApp\new-playwright-project.ps1" -Name MyTests
  ```
  Supports `-Template nunit | mstest | console`. The helper drops a project-local
  `NuGet.config` with `<clear />` + only `PlaywrightOfflineFeed`, runs
  `dotnet new <template> --no-restore`, then `dotnet add package` with versions
  pinned to what the dev pack actually bundles (Playwright 1.60.0, NUnit 4.2.2,
  MSTest 3.6.4, Test.Sdk 17.11.1), then `dotnet restore`. Fully offline.
- **`NuGet.config.template`** — a copy-paste-ready project-local NuGet config
  for users who want to bootstrap manually instead of using the helper.
- Both files are staged into `%ProgramFiles%\PlaywrightApp\` by `install.ps1`
  AND included at the ZIP root for the dev-pack-only path.

### Fixed
- `dotnet new nunit` / `dotnet add package <id>` no longer report
  `The SSL connection could not be established` / `received an unexpected EOF`
  on machines whose user-scope `%AppData%\Roaming\NuGet\NuGet.Config` (or group
  policy) declares additional remote NuGet sources beyond `nuget.org` (for
  example, a corporate Azure DevOps feed). v0.5.1's machine-scope disable
  only covered `nuget.org`; the new project-local `NuGet.config` (via the
  helper or the template) uses `<clear />` to wipe **every** inherited source,
  regardless of layer or how it was injected.

## [0.5.1] - 2026-05-28

### Changed
- **Strict offline by default for the dev pack**: `setup-devpack.ps1` now
  writes `<disabledPackageSources><add key="nuget.org" value="true"/></disabledPackageSources>`
  into machine `NuGet.Config` so that `dotnet add package <id>` (without an
  explicit version) no longer queries `api.nuget.org` to look up the latest
  version. This fixes "無法識別這台主機 api.nuget.org" on fully air-gapped
  machines.
- **Clearer double-click launcher names** — renamed to reduce confusion between
  "install" and "setup":
  - `點擊兩下-setup.cmd` → **`點擊兩下-完整安裝(推薦).cmd`**
  - `點擊兩下-install.cmd` → **`點擊兩下-僅安裝Runtime.cmd`**
  - `點擊兩下-uninstall.cmd` → **`點擊兩下-解除安裝.cmd`**
  The inner PowerShell scripts (`setup.ps1` / `install.ps1` / `uninstall.ps1`)
  keep their names; only the user-visible launchers changed.

### Added
- `setup-devpack.ps1` and `setup.ps1` accept a new `-KeepNuGetOrg` switch for
  machines with intermittent connectivity that want to keep nuget.org enabled
  as a fallback. Passing it on a re-run also removes any prior disable entry,
  so you can flip back to hybrid mode without manually editing NuGet.Config.

### Deprecated
- `-DisableNuGetOrg` on `setup-devpack.ps1` / `setup.ps1` is now redundant
  (it has become the default). The flag continues to work for backward
  compatibility and prints an info line; it will be removed in a future major.

## [0.5.0] - 2026-05-28

### Added
- **Seamless upgrade**: running `點擊兩下-完整安裝(推薦).cmd` from a newer ZIP now
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
- New top-level entry script **`setup.ps1`** / **`點擊兩下-完整安裝(推薦).cmd`** runs
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
- Renamed double-click launchers to `點擊兩下-僅安裝Runtime.cmd` /
  `點擊兩下-解除安裝.cmd` so end users see the "double-click" hint
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
