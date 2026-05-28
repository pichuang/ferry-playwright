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
    [switch]$SkipEdgeCheck
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

function Compare-SemVer {
    param([string]$a, [string]$b)
    # Returns -1 if a<b, 0 if equal, 1 if a>b. Lenient: ignores build metadata, falls back to string compare on parse failure.
    function Get-Parts($v) {
        if (-not $v) { return $null }
        $core = ($v -split '[-+]', 2)[0]
        $parts = $core -split '\.'
        $nums = New-Object int[] 3
        for ($i = 0; $i -lt 3; $i++) {
            $n = 0
            if ($i -lt $parts.Length -and [int]::TryParse($parts[$i], [ref]$n)) { $nums[$i] = $n }
        }
        return $nums
    }
    $pa = Get-Parts $a
    $pb = Get-Parts $b
    if ($null -eq $pa -or $null -eq $pb) { return [string]::Compare($a, $b) }
    for ($i = 0; $i -lt 3; $i++) {
        if ($pa[$i] -lt $pb[$i]) { return -1 }
        if ($pa[$i] -gt $pb[$i]) { return 1 }
    }
    return 0
}

function Invoke-SelfElevate {
    Write-Host 'This installer requires Administrator privileges. Relaunching elevated...' -ForegroundColor Yellow
    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
    if ($InstallDir)    { $argList += @('-InstallDir', "`"$InstallDir`"") }
    if ($NoShortcuts)   { $argList += '-NoShortcuts' }
    if ($SkipEdgeCheck) { $argList += '-SkipEdgeCheck' }
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

# Read version info — new version from ZIP root, old from prior install
$newVersionFile = Join-Path $scriptDir 'VERSION.txt'
$newVersion = if (Test-Path $newVersionFile) { (Get-Content $newVersionFile -Raw).Trim() } else { 'unknown' }

$oldVersionFile = Join-Path $InstallDir 'VERSION.txt'
$oldVersion = if (Test-Path $oldVersionFile) { (Get-Content $oldVersionFile -Raw).Trim() } else { $null }

Write-Section 'Version'
if ($null -eq $oldVersion) {
    Write-Host (" Installing PlaywrightApp v{0} (fresh install)" -f $newVersion) -ForegroundColor Green
} elseif ($oldVersion -eq $newVersion) {
    Write-Host (" Reinstalling PlaywrightApp v{0}" -f $newVersion) -ForegroundColor Yellow
} else {
    $cmp = Compare-SemVer $oldVersion $newVersion
    if ($cmp -lt 0) {
        Write-Host (" Upgrading PlaywrightApp: v{0} -> v{1}" -f $oldVersion, $newVersion) -ForegroundColor Green
    } elseif ($cmp -gt 0) {
        Write-Warning (" Downgrade detected: v{0} -> v{1}. Proceeding anyway." -f $oldVersion, $newVersion)
    } else {
        Write-Host (" Replacing PlaywrightApp v{0} -> v{1}" -f $oldVersion, $newVersion) -ForegroundColor Yellow
    }
}

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
if (Test-Path $newVersionFile) {
    Copy-Item -Path $newVersionFile -Destination (Join-Path $InstallDir 'VERSION.txt') -Force
}

# Stage the offline-project bootstrap helper alongside the runtime exe so users
# can run it from any new shell after install:
#   & "$Env:ProgramFiles\PlaywrightApp\new-playwright-project.ps1" -Name MyTests
$helperFiles = @('new-playwright-project.ps1', 'NuGet.config.template')
foreach ($hf in $helperFiles) {
    $src = Join-Path $scriptDir $hf
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $InstallDir $hf) -Force
        Write-Host (" + helper    : {0}" -f $hf)
    }
}
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

Write-Section 'Installation complete'
Write-Host ' Location : ' -NoNewline; Write-Host $InstallDir -ForegroundColor Green
Write-Host ''
Write-Host ' To run from a new shell:'
Write-Host (" & '{0}\{1}' https://example.com" -f $InstallDir, $exeName)
Write-Host ''
Write-Host ' To uninstall, run uninstall.ps1 as Administrator (from the original extracted folder).'
