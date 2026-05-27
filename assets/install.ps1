<#
.SYNOPSIS
    Install the offline Playwright application on Windows 11 / Windows Server 2022.

.DESCRIPTION
    - Verifies Windows version and Microsoft Edge presence.
    - Copies the self-contained .NET application to %ProgramFiles%\PlaywrightApp.
    - Sets machine-scope environment variables so Playwright never tries to download browsers.
    - Creates Start Menu and Desktop shortcuts.
    - Requires Administrator privileges (will self-elevate if needed).
#>

[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $Env:ProgramFiles 'PlaywrightApp'),
    [switch]$NoShortcuts,
    [switch]$SkipEdgeCheck,
    [switch]$SkipNuGetFeed,
    [switch]$KeepNuGetOrg
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
    if ($InstallDir)    { $argList += @('-InstallDir', "`"$InstallDir`"") }
    if ($NoShortcuts)   { $argList += '-NoShortcuts' }
    if ($SkipEdgeCheck) { $argList += '-SkipEdgeCheck' }
    if ($SkipNuGetFeed) { $argList += '-SkipNuGetFeed' }
    if ($KeepNuGetOrg)  { $argList += '-KeepNuGetOrg' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

function Test-EdgeInstalled {
    $candidates = @(
        (Join-Path ${Env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $Env:ProgramFiles        'Microsoft\Edge\Application\msedge.exe')
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Edge\BLBeacon',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\BLBeacon'
    )
    foreach ($r in $regPaths) {
        if (Test-Path $r) { return '(registry-detected)' }
    }
    return $null
}

# ---------- entry ----------

Write-Section 'Playwright Offline Installer'

if (-not (Test-IsAdmin)) { Invoke-SelfElevate }

# Windows version check
$os = Get-CimInstance Win32_OperatingSystem
Write-Host (" OS         : {0} ({1})" -f $os.Caption, $os.Version)
$verParts = $os.Version.Split('.')
$major = [int]$verParts[0]
$build = [int]$verParts[2]
$supported = ($major -ge 10 -and $build -ge 17763)
if (-not $supported) {
    throw "Unsupported OS. Requires Windows 11 or Windows Server 2022 (build >= 17763). Detected: $($os.Version)"
}

# Edge check
if (-not $SkipEdgeCheck) {
    $edge = Test-EdgeInstalled
    if ($null -eq $edge) {
        throw "Microsoft Edge was not detected. Windows 11 and Windows Server 2022 normally ship with Edge. Re-run with -SkipEdgeCheck to bypass this check (not recommended)."
    }
    Write-Host (" Edge       : found ({0})" -f $edge)
} else {
    Write-Host ' Edge       : check skipped'
}

# Locate payload (script directory must contain 'app' folder)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload   = Join-Path $scriptDir 'app'
if (-not (Test-Path $payload)) {
    throw "Payload folder not found: $payload. Make sure you extracted the ZIP and run install.ps1 from inside the extracted folder."
}
Write-Host " Payload    : $payload"
Write-Host " InstallDir : $InstallDir"

# Stop running instance if any
$exeName = 'PlaywrightSampleApp.exe'
Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($exeName)) -ErrorAction SilentlyContinue |
    ForEach-Object {
        Write-Host (" Stopping running process PID {0}..." -f $_.Id)
        $_ | Stop-Process -Force
    }

# Copy files
Write-Section 'Copying files'
if (Test-Path $InstallDir) {
    Write-Host " Target exists. Refreshing contents..."
    Remove-Item -Path $InstallDir -Recurse -Force
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $payload '*') -Destination $InstallDir -Recurse -Force
Write-Host ' Done.'

# Environment variables (machine scope)
Write-Section 'Setting environment variables (machine scope)'
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', '1', 'Machine')
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', '0', 'Machine')
Write-Host ' PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = 1'
Write-Host ' PLAYWRIGHT_BROWSERS_PATH         = 0'

# Shortcuts
if (-not $NoShortcuts) {
    Write-Section 'Creating shortcuts'
    $targetExe = Join-Path $InstallDir $exeName
    if (-not (Test-Path $targetExe)) {
        Write-Warning "Executable not found at $targetExe; skipping shortcut creation."
    } else {
        $shell = New-Object -ComObject WScript.Shell

        $startMenuDir = Join-Path $Env:ProgramData 'Microsoft\Windows\Start Menu\Programs\PlaywrightApp'
        New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
        $startLnk = Join-Path $startMenuDir 'PlaywrightApp.lnk'
        $sc = $shell.CreateShortcut($startLnk)
        $sc.TargetPath = $targetExe
        $sc.WorkingDirectory = $InstallDir
        $sc.Description = 'Playwright Offline (Edge)'
        $sc.Save()
        Write-Host " Start Menu : $startLnk"

        $desktopLnk = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'PlaywrightApp.lnk'
        $sc2 = $shell.CreateShortcut($desktopLnk)
        $sc2.TargetPath = $targetExe
        $sc2.WorkingDirectory = $InstallDir
        $sc2.Description = 'Playwright Offline (Edge)'
        $sc2.Save()
        Write-Host " Desktop    : $desktopLnk"
    }
}

# Offline NuGet feed (machine scope)
if (-not $SkipNuGetFeed) {
    Write-Section 'Registering offline NuGet feed (machine scope)'

    $nugetSrcDir = Join-Path $scriptDir 'nuget'
    if (-not (Test-Path $nugetSrcDir)) {
        Write-Warning " 'nuget' folder not found in payload; skipping offline NuGet feed setup."
    } else {
        $nugetDstDir = Join-Path $InstallDir 'nuget'
        Write-Host " Copying nupkg folder -> $nugetDstDir"
        if (Test-Path $nugetDstDir) { Remove-Item $nugetDstDir -Recurse -Force }
        New-Item -ItemType Directory -Path $nugetDstDir -Force | Out-Null
        Copy-Item -Path (Join-Path $nugetSrcDir '*') -Destination $nugetDstDir -Recurse -Force

        $nugetConfigDir  = Join-Path $Env:ProgramData 'NuGet'
        $nugetConfigPath = Join-Path $nugetConfigDir 'NuGet.Config'
        New-Item -ItemType Directory -Path $nugetConfigDir -Force | Out-Null

        if (Test-Path $nugetConfigPath) {
            $backup = "$nugetConfigPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $nugetConfigPath $backup -Force
            Write-Host " Existing NuGet.Config backed up to: $backup"
        }

        $disableNugetOrgBlock = if ($KeepNuGetOrg) {
            ''
        } else {
            @"
  <disabledPackageSources>
    <add key="nuget.org" value="true" />
  </disabledPackageSources>
"@
        }

        $configXml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="PlaywrightOfflineFeed" value="$nugetDstDir" />
  </packageSources>
$disableNugetOrgBlock</configuration>
"@
        Set-Content -Path $nugetConfigPath -Value $configXml -Encoding UTF8
        Write-Host " NuGet.Config written: $nugetConfigPath"
        Write-Host "   Source 'PlaywrightOfflineFeed' = $nugetDstDir"
        if (-not $KeepNuGetOrg) {
            Write-Host '   nuget.org disabled (pass -KeepNuGetOrg to keep it enabled)'
        }
    }
}

Write-Section 'Installation complete'
Write-Host ' Location : ' -NoNewline; Write-Host $InstallDir -ForegroundColor Green
Write-Host ''
Write-Host ' To run from a new shell:'
Write-Host (" & '{0}\{1}' https://example.com" -f $InstallDir, $exeName)
Write-Host ''
Write-Host ' To uninstall, run uninstall.ps1 as Administrator (from the original extracted folder).'
