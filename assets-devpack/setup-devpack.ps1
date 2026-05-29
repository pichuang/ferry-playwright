<#
.SYNOPSIS
    Install the ferry-playwright offline NuGet dev pack on Windows 11 / Windows Server 2022.

.DESCRIPTION
    Copies bundled .nupkg files into the user's default NuGet package folder
    (%USERPROFILE%\.nuget\packages), then registers that folder as a NuGet
    package source in the machine-level NuGet.Config so any
    .NET SDK / Visual Studio / VS Code project can `dotnet add package
    Microsoft.Playwright` and friends without internet access.

    - Self-elevates if not already running as Administrator.
    - **Disables nuget.org by default** so that `dotnet add package` resolves
      everything from the bundled offline feed (this is what most users on an
      air-gapped machine want — see `-KeepNuGetOrg` to override).
    - Pass `-KeepNuGetOrg` if your machine has occasional connectivity and you
      want nuget.org left enabled as a fallback.
    - (`-DisableNuGetOrg` is now a deprecated no-op kept for backward compat.)
    - Sets the same Playwright environment variables as the runtime installer
      (PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1, PLAYWRIGHT_BROWSERS_PATH=0) so the
      dev pack can be used standalone, without the runtime ZIP.
    - Backs up an existing machine NuGet.Config with a timestamped .bak before
      modifying.
#>

[CmdletBinding()]
param(
    [string]$FeedDir = (Join-Path $env:USERPROFILE '.nuget\packages'),
    [string]$SourceName = 'ferry-playwright-feed',
    [switch]$KeepNuGetOrg,
    [switch]$DisableNuGetOrg  # deprecated alias; offline-only is now the default
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Section($text) {
    Write-Host ''
    Write-Host '================================================================' -ForegroundColor Cyan
    Write-Host " $text" -ForegroundColor Cyan
    Write-Host '================================================================' -ForegroundColor Cyan
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SelfElevate {
    Write-Host 'This installer requires Administrator privileges. Relaunching elevated...' -ForegroundColor Yellow
    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
    if ($FeedDir)          { $argList += @('-FeedDir',    "`"$FeedDir`"") }
    if ($SourceName)       { $argList += @('-SourceName', "`"$SourceName`"") }
    if ($KeepNuGetOrg)     { $argList += '-KeepNuGetOrg' }
    if ($DisableNuGetOrg)  { $argList += '-DisableNuGetOrg' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

# ---------- entry ----------

Write-Section 'ferry-playwright Offline Dev Pack Installer'

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nupkgSource = Join-Path $scriptDir 'nuget'
if (-not (Test-Path $nupkgSource)) {
    throw "Bundled nuget folder not found: $nupkgSource. Extract the dev pack ZIP and run setup-devpack.ps1 from inside the extracted folder."
}

$nupkgFiles = Get-ChildItem -Path $nupkgSource -Filter '*.nupkg' -File
if ($nupkgFiles.Count -eq 0) {
    throw "No .nupkg files found in $nupkgSource"
}

Write-Host (" FeedDir    : {0}" -f $FeedDir)
Write-Host (" SourceName : {0}" -f $SourceName)
Write-Host (" Packages   : {0} .nupkg file(s)" -f $nupkgFiles.Count)

# Helper: parse "<id>.<version>.nupkg" into (id, version). Versions can contain dots and dashes.
function Get-NupkgIdVersion {
    param([string]$fileName)
    $leaf = Split-Path -Leaf $fileName
    $base = [IO.Path]::GetFileNameWithoutExtension($leaf)
    # First chunk starting with a digit is the version.
    if ($base -match '^(?<id>.+?)\.(?<ver>\d[\w\.\-\+]*)$') {
        return [pscustomobject]@{ Id = $matches['id'].ToLowerInvariant(); Version = $matches['ver']; FileName = $leaf }
    }
    return $null
}

# Step 0 — clean up older versions of bundled package ids using sentinel left by previous install.
$sentinelName = 'ferry-playwright-feed.INDEX.txt'
$sentinelPath = Join-Path $FeedDir $sentinelName
# v0.6.x sentinel filename — read it too so upgrades from v0.6 still clean correctly.
$legacySentinelName = 'PlaywrightOfflineFeed.INDEX.txt'
$legacySentinelPath = Join-Path $FeedDir $legacySentinelName

$newNupkgInfo = @($nupkgFiles | ForEach-Object { Get-NupkgIdVersion $_.Name } | Where-Object { $_ })
if ($newNupkgInfo.Count -ne $nupkgFiles.Count) {
    throw 'Could not parse one or more bundled .nupkg file names into package id/version.'
}
$newIds = @{}
foreach ($info in $newNupkgInfo) { $newIds[$info.Id] = $info }
$newFileNames = @{}
foreach ($info in $newNupkgInfo) { $newFileNames[$info.FileName] = $true }

if (Test-Path $sentinelPath) {
    Write-Section 'Cleaning obsolete dev pack packages from previous install'
    $previous = @(Get-Content $sentinelPath | Where-Object { $_ -and -not $_.StartsWith('#') })
    $removed = 0
    foreach ($prevFile in $previous) {
        if ($newFileNames.ContainsKey($prevFile)) { continue }  # same file in new bundle - keep
        $prevInfo = Get-NupkgIdVersion $prevFile
        if ($null -eq $prevInfo) { continue }
        if (-not $newIds.ContainsKey($prevInfo.Id)) { continue } # id not in new bundle - leave it alone
        $oldPath = Join-Path $FeedDir $prevFile
        if (Test-Path $oldPath) {
            Remove-Item -Path $oldPath -Force
            Write-Host (" - {0}" -f $prevFile)
            $removed++
        }
    }
    if ($removed -eq 0) { Write-Host ' Nothing to remove.' }
}

# Same cleanup against v0.6.x sentinel (legacy filename) — keep upgrades clean.
if (Test-Path $legacySentinelPath) {
    Write-Section 'Cleaning obsolete dev pack packages from v0.6.x install'
    $previous = @(Get-Content $legacySentinelPath | Where-Object { $_ -and -not $_.StartsWith('#') })
    $removed = 0
    foreach ($prevFile in $previous) {
        if ($newFileNames.ContainsKey($prevFile)) { continue }
        $prevInfo = Get-NupkgIdVersion $prevFile
        if ($null -eq $prevInfo) { continue }
        if (-not $newIds.ContainsKey($prevInfo.Id)) { continue }
        $oldPath = Join-Path $FeedDir $prevFile
        if (Test-Path $oldPath) {
            Remove-Item -Path $oldPath -Force
            Write-Host (" - {0}" -f $prevFile)
            $removed++
        }
    }
    if ($removed -eq 0) { Write-Host ' Nothing to remove.' }
    try { Remove-Item -Path $legacySentinelPath -Force } catch { }
}

# Step 1 — copy nupkgs to the user's default NuGet package folder
Write-Section 'Copying packages to user NuGet package folder'
New-Item -ItemType Directory -Path $FeedDir -Force | Out-Null
foreach ($f in $nupkgFiles) {
    $target = Join-Path $FeedDir $f.Name
    Copy-Item -Path $f.FullName -Destination $target -Force
    Write-Host (" + {0}" -f $f.Name)
}
Write-Host (" Done. {0} package(s) deployed to {1}" -f $nupkgFiles.Count, $FeedDir)

# Step 2 — register feed in machine-level NuGet.Config
Write-Section 'Registering NuGet source (machine scope)'
$nugetConfigDir = Join-Path $env:ProgramData 'NuGet'
$nugetConfig    = Join-Path $nugetConfigDir 'NuGet.Config'
New-Item -ItemType Directory -Path $nugetConfigDir -Force | Out-Null

if (Test-Path $nugetConfig) {
    $bak = "$nugetConfig.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $nugetConfig -Destination $bak -Force
    Write-Host " Backup     : $bak"
    [xml]$cfg = Get-Content $nugetConfig
} else {
    [xml]$cfg = '<?xml version="1.0" encoding="utf-8"?><configuration><packageSources></packageSources></configuration>'
}

$packageSources = $cfg.configuration.SelectSingleNode('packageSources')
if (-not $packageSources) {
    $packageSources = $cfg.CreateElement('packageSources')
    $cfg.configuration.AppendChild($packageSources) | Out-Null
}

# Idempotent add: remove any existing entry with the same key, then append.
$existing = @($packageSources.SelectNodes("add[@key='$SourceName']"))
foreach ($n in $existing) { $packageSources.RemoveChild($n) | Out-Null }

# Also drop any legacy v0.6.x source key so we don't leave two entries pointing at the same folder.
foreach ($legacyKey in @('PlaywrightOfflineFeed')) {
    if ($legacyKey -eq $SourceName) { continue }
    $legacyNodes = @($packageSources.SelectNodes("add[@key='$legacyKey']"))
    foreach ($n in $legacyNodes) {
        $packageSources.RemoveChild($n) | Out-Null
        Write-Host " (cleanup)  : removed legacy NuGet source '$legacyKey'" -ForegroundColor DarkGray
    }
}

$addEl = $cfg.CreateElement('add')
$addEl.SetAttribute('key', $SourceName)
$addEl.SetAttribute('value', $FeedDir)
$packageSources.AppendChild($addEl) | Out-Null

if ($DisableNuGetOrg -and -not $KeepNuGetOrg) {
    Write-Host ' (info)     : -DisableNuGetOrg is now the default; flag is deprecated.' -ForegroundColor DarkGray
}

# Default since v0.5.1: offline-only. nuget.org gets added to disabledPackageSources
# so that `dotnet add package <id>` does NOT query api.nuget.org for "latest version".
# Pass -KeepNuGetOrg to keep nuget.org enabled (useful when the machine has
# intermittent connectivity and you want fallback access).
$disableNugetOrg = -not $KeepNuGetOrg

$disabled = $cfg.configuration.SelectSingleNode('disabledPackageSources')
$existingDisabled = if ($disabled) { @($disabled.SelectNodes("add[@key='nuget.org']")) } else { @() }

if ($disableNugetOrg) {
    if (-not $disabled) {
        $disabled = $cfg.CreateElement('disabledPackageSources')
        $cfg.configuration.AppendChild($disabled) | Out-Null
    }
    foreach ($n in $existingDisabled) { $disabled.RemoveChild($n) | Out-Null }
    $dis = $cfg.CreateElement('add')
    $dis.SetAttribute('key', 'nuget.org')
    $dis.SetAttribute('value', 'true')
    $disabled.AppendChild($dis) | Out-Null
    Write-Host ' nuget.org  : DISABLED (offline-only, default)' -ForegroundColor Yellow
} else {
    # User explicitly wants nuget.org kept; remove any prior disable entry we wrote.
    if ($disabled) {
        foreach ($n in $existingDisabled) { $disabled.RemoveChild($n) | Out-Null }
    }
    Write-Host ' nuget.org  : kept enabled (-KeepNuGetOrg passed)' -ForegroundColor Green
}

$cfg.Save($nugetConfig)
Write-Host (" Config     : {0}" -f $nugetConfig)
Write-Host (" Source     : <{0}> -> {1}" -f $SourceName, $FeedDir)

# Step 3 — set Playwright env vars (machine scope) so dev pack works standalone
Write-Section 'Setting Playwright environment variables (machine scope)'
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', '1', 'Machine')
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH',         '0', 'Machine')
Write-Host ' PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = 1'
Write-Host ' PLAYWRIGHT_BROWSERS_PATH         = 0'

# Step 4 — write/refresh sentinel so the next upgrade knows what we deployed
$pkgVersionFile = Join-Path $scriptDir 'VERSION.txt'
$pkgVersion = if (Test-Path $pkgVersionFile) { (Get-Content $pkgVersionFile -Raw).Trim() } else { 'unknown' }
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# ferry-playwright-feed sentinel — files written by setup-devpack.ps1')
[void]$sb.AppendLine('# Do NOT edit by hand. Used by uninstall-devpack.ps1 and upgrade cleanup.')
[void]$sb.AppendLine("# PackageVersion: $pkgVersion")
[void]$sb.AppendLine("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
foreach ($f in $nupkgFiles) { [void]$sb.AppendLine($f.Name) }
Set-Content -Path $sentinelPath -Value $sb.ToString() -Encoding UTF8
Write-Host (" Sentinel   : {0}" -f $sentinelPath)

Write-Section 'Dev pack installed'
Write-Host ' You can now write ferry-playwright tests on this offline machine. Try:' -ForegroundColor Green
Write-Host ''
Write-Host '   mkdir hello-playwright; cd hello-playwright'
Write-Host '   dotnet new nunit'
Write-Host '   dotnet add package Microsoft.Playwright.NUnit'
Write-Host '   dotnet test'
Write-Host ''
Write-Host ' To uninstall, run uninstall-devpack.ps1 as Administrator.'
