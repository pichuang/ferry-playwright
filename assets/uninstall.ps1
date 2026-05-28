<#
.SYNOPSIS
    One-shot offline uninstaller: dev pack + runtime.

.DESCRIPTION
    Wraps uninstall-devpack.ps1 (offline NuGet feed) and uninstall-runtime.ps1
    (Playwright runtime app) so end users only need one double-click.

    - Self-elevates once.
    - Dev pack uninstall runs first; failures are non-fatal so runtime cleanup
      still proceeds.
#>

[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $Env:ProgramFiles 'PlaywrightApp')
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SelfElevate {
    Write-Host 'Uninstall requires Administrator. Relaunching elevated...' -ForegroundColor Yellow
    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass',
                        '-File', "`"$scriptPath`"",
                        '-InstallDir', "`"$InstallDir`"") `
        -Verb RunAs
    exit
}

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ' Playwright Offline — combined uninstall (dev pack + runtime)'   -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ''

# ---- Step 1: dev pack (non-fatal) ----
$uninstallDevpackPs1 = Join-Path $scriptDir 'uninstall-devpack.ps1'
if (Test-Path $uninstallDevpackPs1) {
    Write-Host '[1/2] Removing offline NuGet dev pack...' -ForegroundColor Cyan
    try {
        & $uninstallDevpackPs1
    } catch {
        Write-Warning "Dev pack uninstall reported an error: $($_.Exception.Message)"
        Write-Warning 'Continuing with runtime uninstall.'
    }
} else {
    Write-Host '[1/2] uninstall-devpack.ps1 not found; skipping dev pack cleanup.' -ForegroundColor Yellow
}

# ---- Step 2: runtime ----
$uninstallRuntimePs1 = Join-Path $scriptDir 'uninstall-runtime.ps1'
if (-not (Test-Path $uninstallRuntimePs1)) {
    throw "uninstall-runtime.ps1 not found next to uninstall.ps1: $uninstallRuntimePs1"
}
Write-Host ''
Write-Host '[2/2] Removing Playwright runtime...' -ForegroundColor Cyan
& $uninstallRuntimePs1 -InstallDir $InstallDir

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host ' Uninstall complete.'                                              -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
