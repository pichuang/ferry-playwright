# Copilot instructions — ferry-playwright

This repo produces a **one-click offline installer ZIP** of a Playwright-for-.NET app for
Windows 11 / Windows Server 2022. Target machines never reach the internet during install or run.

## Big picture

Two .NET 10 console projects working as a pipeline:

1. **`src/PlaywrightSampleApp/`** — the *payload*. Uses `Microsoft.Playwright` with
   `Channel = "msedge"` so it drives the **system-installed Edge** instead of a
   downloaded Chromium. No browser binaries are ever bundled.
2. **`src/PlaywrightOfflinePackager/`** — the *builder*. Runs `dotnet publish -r win-x64
   --self-contained`, verifies the Playwright Node driver (`.playwright/node/win32_x64/node.exe`)
   came along, copies scripts from `assets/`, then zips everything into `output/`.

The resulting ZIP is fully self-contained: .NET runtime + Playwright managed assemblies +
node-based Playwright driver + `install.ps1` / `uninstall.ps1` / `README.txt`.

**Offline contract** rests on three things, all must hold:
- Self-contained publish (no .NET install needed on target)
- `Channel = "msedge"` (no browser download needed)
- `install.ps1` sets machine env vars `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` and
  `PLAYWRIGHT_BROWSERS_PATH=0` so Playwright never attempts a download at runtime

## Build / run / package

```bash
# Build everything
dotnet build

# Build a single project
dotnet build src/PlaywrightSampleApp

# Run the sample app interactively (opens Edge, waits for ENTER)
dotnet run --project src/PlaywrightSampleApp -- https://example.com

# Run the sample app in CI mode (headless, no readline, exits immediately)
CI=true dotnet run --project src/PlaywrightSampleApp -- --ci

# Produce the offline ZIP (writes to output/PlaywrightOffline-win-x64-<timestamp>.zip)
dotnet run --project src/PlaywrightOfflinePackager

# Override packager options
dotnet run --project src/PlaywrightOfflinePackager -- --rid win-x64 --config Release --output output
```

There is **no test project**. The "test" is the packager's `Verify Playwright driver present`
step (must find `node.exe` under `.playwright/node/win32_x64/`) plus the CI offline self-test.

## CI: how the release pipeline proves "offline-safe"

`.github/workflows/release.yml` has three jobs, and the offline contract is enforced by job 2
before any release is published:

1. **`package` (ubuntu-latest)** — runs the packager, computes SHA256, builds a
   `release-notes.md` with **Summary**, **Self-test results**, and **Changes since previous tag**
   (`git log` + `git diff --stat`). Uploads ZIP + notes as the `offline-package` artifact.
2. **`verify-offline` (windows-2022)** — the strict gate:
   1. Baseline-check that the runner currently has internet (avoids false-pass on a broken runner).
   2. Set `Set-NetFirewallProfile -DefaultOutboundAction Block` + a loopback allow rule.
   3. Re-verify the block by failing if `Test-NetConnection www.microsoft.com 443` succeeds.
   4. Snapshot TCP connections, run `install.ps1`, run `PlaywrightSampleApp.exe --ci`.
   5. Audit: any TCP tuple in the *after* snapshot that is not in the *before* snapshot and
      is not loopback/link-local → **fail the build**.
   6. **`always()`** cleanup restores the firewall **before** the audit-artifact upload
      (the upload itself needs internet). Step order matters here.
3. **`release` (ubuntu-latest, tag `v*` only)** — `softprops/action-gh-release@v2`
   with `body_path: release-notes.md` + `generate_release_notes: true` + ZIP attached.

Triggers: push tag `v*`, or `workflow_dispatch`. The release job is gated by the tag.

## Conventions specific to this repo

- **.NET version** is pinned in `global.json` (`10.0.100`, `rollForward: latestFeature`,
  `allowPrerelease: true`). GitHub Actions uses `actions/setup-dotnet@v4` with
  `global-json-file: global.json` and `dotnet-quality: preview`.
- **Solution file** is the new SLNX format: `ferry-playwright.slnx`. Standard `dotnet`
  commands work; do not regenerate as `.sln`.
- **Shared MSBuild settings** live in `Directory.Build.props` (`Nullable`, `ImplicitUsings`,
  `LangVersion=latest`). Don't duplicate these in individual `.csproj` files.
- **Sample-app modes**: interactive is default; CI mode is enabled by either the `--ci` arg
  or env vars `CI=true` / `PLAYWRIGHT_CI=1`. In CI mode: `Headless = true`, no
  `Console.ReadLine()`, default URL is `about:blank`. Preserve this contract — the
  workflow's offline test depends on it.
- **Packager pipeline order** (in `src/PlaywrightOfflinePackager/Program.cs`) — produces a
  **single combined ZIP** (`PlaywrightOffline-win-x64-<timestamp>.zip`, ~350 MB) containing
  both runtime (`app/`) and dev pack (`nuget/`):
  `Restore` → `Publish` → **`Verify Playwright driver present`** → `Restore dev pack (NuGet graph)`
  (synthesized shell.csproj pinning Microsoft.Playwright + .NUnit + .MSTest + Test.Sdk +
  NUnit + MSTest at fixed versions) → `Collect .nupkg files` (flatten + dedupe + write
  `nuget/INDEX.txt`) → `Stage runtime assets` (from `assets/`) → `Stage dev pack assets`
  (from `assets-devpack/`) → `Write BUILD-INFO.txt` → `Create ZIP`. The driver-presence
  verification is the single most important guard — keep it. ZIP must include
  `app/.playwright/node/win32_x64/node.exe` and `nuget/microsoft.playwright.1.60.0.nupkg`.
- **Entry scripts inside the ZIP** (all at ZIP root):
  - `點擊兩下-setup.cmd` → `setup.ps1` → chains `install.ps1` (runtime) then
    `setup-devpack.ps1` (offline NuGet feed). One UAC prompt covers both.
  - `點擊兩下-uninstall.cmd` → `uninstall.ps1` → chains `uninstall-devpack.ps1` then
    `uninstall-runtime.ps1`. Dev pack failures are non-fatal so runtime cleanup still runs.
  - `點擊兩下-install.cmd` / `install.ps1` — runtime-only install (advanced users).
  - `setup-devpack.ps1` / `uninstall-devpack.ps1` — dev-pack-only flow (advanced users).
- **install.ps1** self-elevates, requires Edge unless `-SkipEdgeCheck` is passed, installs
  to `%ProgramFiles%\PlaywrightApp`, sets *machine-scope* env vars, creates Start Menu +
  Desktop shortcuts. Mirror any change in `uninstall-runtime.ps1`.
- **setup-devpack.ps1** (in `assets-devpack/`) self-elevates, copies bundled `.nupkg` files
  into `%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages` (the standard Microsoft offline
  feed folder), registers it as `PlaywrightOfflineFeed` in `%ProgramData%\NuGet\NuGet.Config`
  (idempotent XML edit with `.bak.YYYYMMDD-HHMMSS` backup), and idempotently sets the same
  `PLAYWRIGHT_*` env vars as `install.ps1` so the dev pack can run standalone. Does NOT
  disable nuget.org by default. `uninstall-devpack.ps1` removes only the .nupkg files
  listed in `nuget/INDEX.txt` — never sweeps the shared folder.
- **Versioning / changelog**: bumps go in `CHANGELOG.md` (Keep a Changelog style) and are
  released by pushing a `vX.Y.Z` tag. The workflow auto-generates the diff-vs-previous-tag
  block in the release body — don't try to write that part by hand.
- **Cross-publish from macOS/Linux**: supported and used by CI. Don't add `RuntimeIdentifier`
  to the sample `.csproj`; the packager passes `-r win-x64` on the command line so the
  project stays portable.

## When making changes — quick checklist

- Touching the sample app? Keep `Channel = "msedge"` and the CI-mode branch intact, then
  `dotnet run --project src/PlaywrightOfflinePackager` locally to confirm the ZIP still
  validates.
- Touching `install.ps1` / `uninstall.ps1`? Lint with
  `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile(...)"`
  (no PSScriptAnalyzer is configured) and mirror changes across both scripts.
- Touching the workflow? `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
  before committing. Remember the artifact-upload-after-firewall-restore ordering.

## MCP (Model Context Protocol)

`.vscode/mcp.json` registers a workspace-scoped **Playwright MCP server** so VS Code
Copilot (and other MCP-aware clients) can drive a browser during chat-based work.

- Server: `@playwright/mcp@latest` launched via `npx -y` (no global install needed).
- `--browser msedge` is hard-coded to mirror the runtime contract of this repo
  (the sample app uses `Channel = "msedge"` and never downloads Chromium).
- First run will fetch `@playwright/mcp` from npm; this is a **developer-machine**
  dependency and does **not** affect the offline ZIP we ship.
- If you change the sample app's browser channel, update the `--browser` flag here too.
