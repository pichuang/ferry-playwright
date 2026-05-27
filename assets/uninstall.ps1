<#
.SYNOPSIS
    Remove the offline Playwright application installed by install.ps1.
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

Write-Host "Removing $InstallDir ..."
if (Test-Path $InstallDir) {
    # Stop any running instance
    Get-Process -Name 'PlaywrightSampleApp' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host ' Folder removed.'
} else {
    Write-Host ' Folder not present; skipping.'
}

Write-Host 'Clearing environment variables...'
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', $null, 'Machine')
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', $null, 'Machine')

Write-Host 'Removing shortcuts...'
$startMenuDir = Join-Path $Env:ProgramData 'Microsoft\Windows\Start Menu\Programs\PlaywrightApp'
if (Test-Path $startMenuDir) { Remove-Item $startMenuDir -Recurse -Force }
$desktopLnk = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'PlaywrightApp.lnk'
if (Test-Path $desktopLnk) { Remove-Item $desktopLnk -Force }

Write-Host 'Uninstall complete.' -ForegroundColor Green
