<#
.SYNOPSIS
    Uninstall the Playwright offline NuGet dev pack from this machine.
#>

[CmdletBinding()]
param(
    [string]$FeedDir = (Join-Path ${env:ProgramFiles(x86)} 'Microsoft SDKs\NuGetPackages'),
    [string]$SourceName = 'PlaywrightOfflineFeed'
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

Write-Section 'Playwright Offline Dev Pack Uninstaller'

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexFile = Join-Path $scriptDir 'nuget\INDEX.txt'

# Step 1 — unregister NuGet source
$nugetConfig = Join-Path $env:ProgramData 'NuGet\NuGet.Config'
if (Test-Path $nugetConfig) {
    Write-Section 'Removing NuGet source'
    try {
        [xml]$cfg = Get-Content $nugetConfig
        $packageSources = $cfg.configuration.SelectSingleNode('packageSources')
        if ($packageSources) {
            $existing = @($packageSources.SelectNodes("add[@key='$SourceName']"))
            foreach ($n in $existing) { $packageSources.RemoveChild($n) | Out-Null }
        }
        $cfg.Save($nugetConfig)
        Write-Host (" - Removed <{0}> from {1}" -f $SourceName, $nugetConfig)
    } catch {
        Write-Warning "Could not parse $nugetConfig — leaving untouched. Error: $_"
    }
} else {
    Write-Host " NuGet.Config not found at $nugetConfig — nothing to unregister."
}

# Step 2 — remove the .nupkg files we copied (use INDEX.txt to know which)
Write-Section 'Removing bundled .nupkg files from feed'
if (Test-Path $indexFile) {
    $removed = 0
    Get-Content $indexFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $candidate = Join-Path $FeedDir $line
        if (Test-Path $candidate) {
            Remove-Item -Path $candidate -Force
            Write-Host " - $line"
            $removed++
        }
    }
    Write-Host (" Removed {0} package file(s) from {1}" -f $removed, $FeedDir)
} else {
    Write-Warning "INDEX.txt not found alongside this script ($indexFile). Skipping nupkg removal."
}

Write-Section 'Dev pack uninstalled'
Write-Host ' Note: %USERPROFILE%\.nuget\packages was intentionally NOT touched.' -ForegroundColor Yellow
Write-Host ' Note: PLAYWRIGHT_* environment variables were intentionally NOT cleared,'
Write-Host '       because the runtime installer may still be using them.'
