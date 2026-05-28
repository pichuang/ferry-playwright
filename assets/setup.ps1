<#
.SYNOPSIS
    One-shot offline installer (v0.6+) — installs the dev pack only.

.DESCRIPTION
    Thin wrapper around setup-devpack.ps1. From v0.6.0 onward there is no
    "runtime" portion to install: the ZIP no longer ships a precompiled
    PlaywrightSampleApp.exe. After running this script:

      - Bundled .nupkg files live in %ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages
      - Machine-level NuGet.Config registers PlaywrightOfflineFeed
      - Machine env vars PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1,
        PLAYWRIGHT_BROWSERS_PATH=0 are set
      - You can `cd samples\hello-nunit; dotnet test --settings .runsettings`

    To clean up an old v0.5.x install (PlaywrightApp under %ProgramFiles%),
    run uninstall.ps1 once — it will best-effort remove that legacy folder
    before installing.

    Forwards -KeepNuGetOrg to setup-devpack.ps1.
#>

[CmdletBinding()]
param(
    [switch]$KeepNuGetOrg,
    [switch]$DisableNuGetOrg  # deprecated alias; default is already offline-only
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SelfElevate {
    Write-Host 'Setup requires Administrator. Relaunching elevated...' -ForegroundColor Yellow
    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
    if ($KeepNuGetOrg)    { $argList += '-KeepNuGetOrg' }
    if ($DisableNuGetOrg) { $argList += '-DisableNuGetOrg' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ' Playwright Offline — setup (dev pack)'                            -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ''

# Best-effort: clear out a v0.5.x runtime install (no error if missing).
$legacyRuntimeDir = Join-Path $Env:ProgramFiles 'PlaywrightApp'
if (Test-Path $legacyRuntimeDir) {
    Write-Host "Detected legacy v0.5.x runtime install at: $legacyRuntimeDir" -ForegroundColor Yellow
    Write-Host 'Removing it (v0.6+ no longer installs a precompiled runtime).' -ForegroundColor Yellow
    try {
        Remove-Item -Recurse -Force -Path $legacyRuntimeDir
        Write-Host '  ✓ Legacy runtime folder removed.'
    } catch {
        Write-Warning "Could not fully remove $legacyRuntimeDir : $($_.Exception.Message)"
    }
    foreach ($shortcut in @(
        (Join-Path $Env:ProgramData 'Microsoft\Windows\Start Menu\Programs\PlaywrightApp.lnk'),
        (Join-Path $Env:PUBLIC 'Desktop\PlaywrightApp.lnk')
    )) {
        if (Test-Path $shortcut) {
            try { Remove-Item -Force -Path $shortcut } catch { }
        }
    }
}

# Run dev pack installer.
$setupDevpackPs1 = Join-Path $scriptDir 'setup-devpack.ps1'
if (-not (Test-Path $setupDevpackPs1)) {
    throw "setup-devpack.ps1 not found next to setup.ps1: $setupDevpackPs1"
}

$devpackArgs = @{}
if ($KeepNuGetOrg)    { $devpackArgs['KeepNuGetOrg']    = $true }
if ($DisableNuGetOrg) { $devpackArgs['DisableNuGetOrg'] = $true }
& $setupDevpackPs1 @devpackArgs

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host ' Dev pack installed.'                                              -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host ''
Write-Host ' Next steps:' -ForegroundColor Cyan
Write-Host ('   1) Copy "samples\hello-nunit" (or hello-mstest / hello-console) out of the ZIP folder.')
Write-Host ('   2) cd into the copy.')
Write-Host ('   3) Run: dotnet test --settings .runsettings   (or "dotnet run" for hello-console)')
Write-Host ''
Write-Host ' To start a fresh project, see: new-playwright-project.ps1'        -ForegroundColor Cyan
