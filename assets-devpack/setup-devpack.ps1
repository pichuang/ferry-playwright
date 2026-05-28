<#
.SYNOPSIS
    Install the Playwright offline NuGet dev pack on Windows 11 / Windows Server 2022.

.DESCRIPTION
    Copies bundled .nupkg files into the standard machine-wide offline NuGet feed
    folder (%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages), then registers that
    folder as a NuGet package source in the machine-level NuGet.Config so any
    .NET SDK / Visual Studio / VS Code project can `dotnet add package
    Microsoft.Playwright` and friends without internet access.

    - Self-elevates if not already running as Administrator.
    - Does NOT disable nuget.org by default (machines with intermittent
      connectivity can still pull other packages when online).
      Pass -DisableNuGetOrg for strict offline.
    - Sets the same Playwright environment variables as the runtime installer
      (PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1, PLAYWRIGHT_BROWSERS_PATH=0) so the
      dev pack can be used standalone, without the runtime ZIP.
    - Backs up an existing machine NuGet.Config with a timestamped .bak before
      modifying.
#>

[CmdletBinding()]
param(
    [string]$FeedDir = (Join-Path ${env:ProgramFiles(x86)} 'Microsoft SDKs\NuGetPackages'),
    [string]$SourceName = 'PlaywrightOfflineFeed',
    [switch]$DisableNuGetOrg
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
    if ($DisableNuGetOrg)  { $argList += '-DisableNuGetOrg' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

# ---------- entry ----------

Write-Section 'Playwright Offline Dev Pack Installer'

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

# Step 1 — copy nupkgs to machine-wide feed
Write-Section 'Copying packages to machine-wide offline feed'
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

$addEl = $cfg.CreateElement('add')
$addEl.SetAttribute('key', $SourceName)
$addEl.SetAttribute('value', $FeedDir)
$packageSources.AppendChild($addEl) | Out-Null

if ($DisableNuGetOrg) {
    $disabled = $cfg.configuration.SelectSingleNode('disabledPackageSources')
    if (-not $disabled) {
        $disabled = $cfg.CreateElement('disabledPackageSources')
        $cfg.configuration.AppendChild($disabled) | Out-Null
    }
    $disExisting = @($disabled.SelectNodes("add[@key='nuget.org']"))
    foreach ($n in $disExisting) { $disabled.RemoveChild($n) | Out-Null }
    $dis = $cfg.CreateElement('add')
    $dis.SetAttribute('key', 'nuget.org')
    $dis.SetAttribute('value', 'true')
    $disabled.AppendChild($dis) | Out-Null
    Write-Host ' nuget.org  : DISABLED (strict offline mode)' -ForegroundColor Yellow
} else {
    Write-Host ' nuget.org  : left untouched (use -DisableNuGetOrg for strict offline)'
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

Write-Section 'Dev pack installed'
Write-Host ' You can now write Playwright tests on this offline machine. Try:' -ForegroundColor Green
Write-Host ''
Write-Host '   mkdir hello-playwright; cd hello-playwright'
Write-Host '   dotnet new nunit'
Write-Host '   dotnet add package Microsoft.Playwright.NUnit'
Write-Host '   dotnet test'
Write-Host ''
Write-Host ' To uninstall, run uninstall-devpack.ps1 as Administrator.'
