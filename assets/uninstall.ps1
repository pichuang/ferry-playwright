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

Write-Host 'Removing offline NuGet feed registration...'
$nugetConfigPath = Join-Path $Env:ProgramData 'NuGet\NuGet.Config'
if (Test-Path $nugetConfigPath) {
    try {
        [xml]$cfg = Get-Content -Path $nugetConfigPath -Raw
        $changed = $false

        $srcParent = $cfg.configuration.packageSources
        if ($srcParent) {
            $toRemove = @($srcParent.add | Where-Object { $_.key -eq 'PlaywrightOfflineFeed' })
            foreach ($node in $toRemove) {
                [void]$srcParent.RemoveChild($node)
                $changed = $true
            }
        }

        $disabled = $cfg.configuration.disabledPackageSources
        if ($disabled) {
            $disNugetOrg = @($disabled.add | Where-Object { $_.key -eq 'nuget.org' })
            foreach ($node in $disNugetOrg) {
                [void]$disabled.RemoveChild($node)
                $changed = $true
            }
            if (-not $disabled.HasChildNodes) {
                [void]$cfg.configuration.RemoveChild($disabled)
            }
        }

        $sourcesEmpty = (-not $srcParent) -or (-not $srcParent.HasChildNodes)
        $onlyConfigRoot = ($cfg.configuration.ChildNodes.Count -eq 1) -and $sourcesEmpty

        if ($onlyConfigRoot) {
            # Nothing meaningful left; if a backup exists, restore the most recent one
            $latestBackup = Get-ChildItem -Path (Split-Path $nugetConfigPath) -Filter 'NuGet.Config.bak.*' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestBackup) {
                Copy-Item $latestBackup.FullName $nugetConfigPath -Force
                Write-Host " Restored NuGet.Config from backup: $($latestBackup.Name)"
            } else {
                Remove-Item $nugetConfigPath -Force
                Write-Host ' NuGet.Config removed (was only managing our feed).'
            }
        } elseif ($changed) {
            $cfg.Save($nugetConfigPath)
            Write-Host ' Removed PlaywrightOfflineFeed entry from NuGet.Config.'
        } else {
            Write-Host ' NuGet.Config did not contain our entries; left unchanged.'
        }
    } catch {
        Write-Warning " Could not cleanly edit '$nugetConfigPath': $($_.Exception.Message)"
    }
} else {
    Write-Host ' No machine-level NuGet.Config present.'
}

Write-Host 'Uninstall complete.' -ForegroundColor Green
