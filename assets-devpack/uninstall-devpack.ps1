<#
.SYNOPSIS
    Uninstall the ferry-playwright offline NuGet dev pack from this machine.
#>

[CmdletBinding()]
param(
    [string]$FeedDir = (Join-Path $env:USERPROFILE '.nuget\packages'),
    [string]$SourceName = 'ferry-playwright-feed'
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
    Write-Host 'This uninstaller requires Administrator privileges. Relaunching elevated...' -ForegroundColor Yellow
    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
    if ($FeedDir)    { $argList += @('-FeedDir',    "`"$FeedDir`"") }
    if ($SourceName) { $argList += @('-SourceName', "`"$SourceName`"") }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

# ---------- entry ----------

Write-Section 'ferry-playwright Offline Dev Pack Uninstaller'

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexFile = Join-Path $scriptDir 'nuget\INDEX.txt'
$sentinelName = 'ferry-playwright-feed.INDEX.txt'
$sentinelPath = Join-Path $FeedDir $sentinelName
# v0.6.x sentinel filename — read it too so uninstall covers older installs.
$legacySentinelName = 'PlaywrightOfflineFeed.INDEX.txt'
$legacySentinelPath = Join-Path $FeedDir $legacySentinelName

# Step 1 — unregister NuGet source (current + legacy v0.6.x key)
$nugetConfig = Join-Path $env:ProgramData 'NuGet\NuGet.Config'
if (Test-Path $nugetConfig) {
    Write-Section 'Removing NuGet source'
    try {
        [xml]$cfg = Get-Content $nugetConfig
        $packageSources = $cfg.configuration.SelectSingleNode('packageSources')
        if ($packageSources) {
            foreach ($key in @($SourceName, 'PlaywrightOfflineFeed') | Select-Object -Unique) {
                $existing = @($packageSources.SelectNodes("add[@key='$key']"))
                foreach ($n in $existing) {
                    $packageSources.RemoveChild($n) | Out-Null
                    Write-Host (" - Removed <{0}> from {1}" -f $key, $nugetConfig)
                }
            }
        }
        $cfg.Save($nugetConfig)
    } catch {
        Write-Warning "Could not parse $nugetConfig - leaving untouched. Error: $_"
    }
} else {
    Write-Host " NuGet.Config not found at $nugetConfig - nothing to unregister."
}

# Step 2 — remove .nupkg files we deployed. Prefer the FeedDir sentinel (covers files
# accumulated across upgrades); fall back to bundled INDEX.txt for compatibility.
Write-Section 'Removing bundled .nupkg files from feed'
$listSource = $null
$lines = $null
if (Test-Path $sentinelPath) {
    $listSource = $sentinelPath
    $lines = Get-Content $sentinelPath
    Write-Host " Using sentinel: $sentinelPath"
} elseif (Test-Path $indexFile) {
    $listSource = $indexFile
    $lines = Get-Content $indexFile
    Write-Host " Sentinel not found; falling back to bundled INDEX.txt: $indexFile"
} else {
    Write-Warning "Neither sentinel ($sentinelPath) nor bundled INDEX.txt ($indexFile) found. Skipping nupkg removal."
}

if ($lines) {
    $removed = 0
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $candidate = Join-Path $FeedDir $line
        if (Test-Path $candidate) {
            $displayPath = Resolve-Path -Path $candidate -Relative
            Remove-Item -Path $candidate -Force
            Write-Host (" - {0}" -f $displayPath)
            $removed++
        }
    }
    Write-Host (" Removed {0} package file(s) from {1}" -f $removed, $FeedDir)

    if (Test-Path $sentinelPath) {
        Remove-Item -Path $sentinelPath -Force
        Write-Host " - $sentinelName (sentinel)"
    }
}

# Also delete the legacy v0.6.x sentinel (and its listed nupkgs) if it lingered.
if (Test-Path $legacySentinelPath) {
    Write-Host " Cleaning legacy v0.6.x sentinel: $legacySentinelPath"
    $legacyLines = Get-Content $legacySentinelPath
    foreach ($raw in $legacyLines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $candidate = Join-Path $FeedDir $line
        if (Test-Path $candidate) {
            Remove-Item -Path $candidate -Force
            Write-Host (" - {0}" -f $line)
        }
    }
    try { Remove-Item -Path $legacySentinelPath -Force } catch { }
}

Write-Section 'Dev pack uninstalled'
Write-Host ' Note: only the allow-listed dev pack package files were removed from %USERPROFILE%\.nuget\packages.' -ForegroundColor Yellow
Write-Host ' Note: PLAYWRIGHT_* environment variables were intentionally NOT cleared,'
Write-Host '       because the runtime installer may still be using them.'
