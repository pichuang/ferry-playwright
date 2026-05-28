<#
.SYNOPSIS
    One-shot offline uninstaller (v0.6+) — removes the dev pack and any
    legacy v0.5.x runtime install.

.DESCRIPTION
    Thin wrapper around uninstall-devpack.ps1. Also best-effort removes
    %ProgramFiles%\PlaywrightApp (the v0.5.x runtime location) for users
    upgrading from older releases.
#>

[CmdletBinding()]
param()

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
                        '-File', "`"$scriptPath`"") `
        -Verb RunAs
    exit
}

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ' Playwright Offline — uninstall'                                  -ForegroundColor Cyan
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
        Write-Warning 'Continuing with legacy runtime cleanup.'
    }
} else {
    Write-Host '[1/2] uninstall-devpack.ps1 not found; skipping dev pack cleanup.' -ForegroundColor Yellow
}

# ---- Step 2: best-effort cleanup of legacy v0.5.x runtime ----
$legacyRuntimeDir = Join-Path $Env:ProgramFiles 'PlaywrightApp'
Write-Host ''
Write-Host '[2/2] Cleaning up any legacy v0.5.x runtime install...' -ForegroundColor Cyan
if (Test-Path $legacyRuntimeDir) {
    try {
        Remove-Item -Recurse -Force -Path $legacyRuntimeDir
        Write-Host "  ✓ Removed $legacyRuntimeDir"
    } catch {
        Write-Warning "Could not fully remove $legacyRuntimeDir : $($_.Exception.Message)"
    }
} else {
    Write-Host '  (none found)'
}

foreach ($shortcut in @(
    (Join-Path $Env:ProgramData 'Microsoft\Windows\Start Menu\Programs\PlaywrightApp.lnk'),
    (Join-Path $Env:PUBLIC 'Desktop\PlaywrightApp.lnk')
)) {
    if (Test-Path $shortcut) {
        try {
            Remove-Item -Force -Path $shortcut
            Write-Host "  ✓ Removed shortcut: $shortcut"
        } catch { }
    }
}

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host ' Uninstall complete.'                                              -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
