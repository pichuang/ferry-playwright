<#
.SYNOPSIS
    One-shot offline installer: runtime + dev pack.

.DESCRIPTION
    Wraps install.ps1 (Playwright runtime app) and setup-devpack.ps1 (offline
    NuGet feed) so end users only need one double-click.

    - Self-elevates once; both inner scripts inherit the elevated session.
    - Runtime install runs first; if it fails the dev pack step is skipped.
    - Forwards -SkipEdgeCheck to install.ps1, and -KeepNuGetOrg /
      -DisableNuGetOrg (deprecated alias) to setup-devpack.ps1.
#>

[CmdletBinding()]
param(
    [switch]$SkipEdgeCheck,
    [switch]$KeepNuGetOrg,
    [switch]$DisableNuGetOrg,
    [string]$InstallDir = (Join-Path $Env:ProgramFiles 'PlaywrightApp')
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
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"",
                 '-InstallDir', "`"$InstallDir`"")
    if ($SkipEdgeCheck)   { $argList += '-SkipEdgeCheck' }
    if ($KeepNuGetOrg)    { $argList += '-KeepNuGetOrg' }
    if ($DisableNuGetOrg) { $argList += '-DisableNuGetOrg' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ' Playwright Offline — combined setup (runtime + dev pack)'       -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ''

# ---- Step 1: runtime ----
$installPs1 = Join-Path $scriptDir 'install.ps1'
if (-not (Test-Path $installPs1)) {
    throw "install.ps1 not found next to setup.ps1: $installPs1"
}
Write-Host '[1/2] Installing Playwright runtime...' -ForegroundColor Cyan
$installArgs = @{ InstallDir = $InstallDir }
if ($SkipEdgeCheck) { $installArgs['SkipEdgeCheck'] = $true }
& $installPs1 @installArgs

# ---- Step 2: dev pack ----
$setupDevpackPs1 = Join-Path $scriptDir 'setup-devpack.ps1'
if (-not (Test-Path $setupDevpackPs1)) {
    throw "setup-devpack.ps1 not found next to setup.ps1: $setupDevpackPs1"
}
Write-Host ''
Write-Host '[2/2] Installing offline NuGet dev pack...' -ForegroundColor Cyan
$devpackArgs = @{}
if ($KeepNuGetOrg)    { $devpackArgs['KeepNuGetOrg']    = $true }
if ($DisableNuGetOrg) { $devpackArgs['DisableNuGetOrg'] = $true }
& $setupDevpackPs1 @devpackArgs

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host ' All done. Runtime + dev pack are installed.'                    -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
