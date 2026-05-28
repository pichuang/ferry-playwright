<#
.SYNOPSIS
    Bootstrap a new offline Playwright test/console project that uses only the
    bundled NuGet feed.

.DESCRIPTION
    Creates a new project directory, drops a project-local NuGet.config with
    `<clear />` + only the PlaywrightOfflineFeed, runs `dotnet new`, then adds
    Playwright + test-framework packages **pinned to the versions actually
    bundled** in the dev pack. This sidesteps both of the failure modes that
    plain `dotnet new nunit; dotnet add package Microsoft.Playwright.NUnit`
    runs into on an air-gapped machine:

    1. NuGet config layering — the user's `%AppData%\Roaming\NuGet\NuGet.Config`
       (or a solution-level config) declaring other remote sources causes
       restore to probe them, even with `nuget.org` disabled at machine scope.
       Our project-local `<clear />` wipes every inherited source.

    2. Template version mismatch — `dotnet new nunit` references whatever
       NUnit / Test.Sdk versions the SDK template ships, which may NOT be in
       our offline feed. We override with `dotnet add package --version` to
       pin everything to the bundled versions.

.PARAMETER Name
    Project / folder name. Required.

.PARAMETER Template
    One of: nunit (default), mstest, console.

.PARAMETER OutputDir
    Parent directory the project will be created under. Defaults to the
    current working directory.

.PARAMETER Force
    If set, overwrite the target directory if it already exists.

.EXAMPLE
    .\new-playwright-project.ps1 -Name MyTests
    # Creates .\MyTests with NUnit + Playwright wired up, offline.

.EXAMPLE
    .\new-playwright-project.ps1 -Name SmokeApp -Template console
    # Console app with Microsoft.Playwright only.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [ValidateSet('nunit', 'mstest', 'console')]
    [string]$Template = 'nunit',

    [string]$OutputDir = (Get-Location).Path,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Bundled versions — keep in sync with the package list pinned in
# src/PlaywrightOfflinePackager/Program.cs (synthesized shell csproj).
$Versions = @{
    'Microsoft.Playwright'        = '1.60.0'
    'Microsoft.Playwright.NUnit'  = '1.60.0'
    'Microsoft.Playwright.MSTest' = '1.60.0'
    'Microsoft.NET.Test.Sdk'      = '17.11.1'
    'NUnit'                       = '4.2.2'
    'NUnit3TestAdapter'           = '4.6.0'
    'MSTest.TestFramework'        = '3.6.4'
    'MSTest.TestAdapter'          = '3.6.4'
    'coverlet.collector'          = '6.0.2'
    'NUnit.Analyzers'             = '4.4.0'
    'MSTest.Analyzers'            = '3.6.4'
}

function Write-Section($t) {
    Write-Host ''
    Write-Host ('--- {0} ---' -f $t) -ForegroundColor Cyan
}

# 1) Resolve helper directory and locate NuGet.config.template (alongside this script).
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmpl      = Join-Path $scriptDir 'NuGet.config.template'
if (-not (Test-Path $tmpl)) {
    throw "NuGet.config.template not found next to this script (looked at: $tmpl). " +
          "Make sure you are running new-playwright-project.ps1 from the install / ZIP folder."
}

# 2) Verify dotnet SDK is present (helper does NOT install the SDK).
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
    throw "dotnet SDK not found on PATH. Install .NET 10 SDK first " +
          "(this offline ZIP only contains the runtime needed by PlaywrightSampleApp.exe)."
}

# 3) Compute target dir.
$projectDir = Join-Path $OutputDir $Name
if (Test-Path $projectDir) {
    if (-not $Force) {
        throw "Target directory already exists: $projectDir`nPass -Force to overwrite."
    }
    Write-Host "Removing existing directory: $projectDir" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $projectDir
}

New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host (' New Playwright offline project: {0}' -f $Name)                  -ForegroundColor Cyan
Write-Host (' Template : {0}' -f $Template)                                   -ForegroundColor Cyan
Write-Host (' Location : {0}' -f $projectDir)                                 -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan

# 4) Drop the project-local NuGet.config FIRST so any implicit restore uses only
#    our offline feed.
Write-Section 'Writing project-local NuGet.config (<clear /> + offline feed)'
Copy-Item -Path $tmpl -Destination (Join-Path $projectDir 'NuGet.config') -Force
Write-Host ' OK : NuGet.config (only PlaywrightOfflineFeed is visible to this project)'

Push-Location $projectDir
try {
    # 5) dotnet new — pass --no-restore so we control restore after pinning versions.
    Write-Section ('Running dotnet new {0} --no-restore' -f $Template)
    & dotnet new $Template --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet new $Template failed (exit $LASTEXITCODE)." }

    # 6) Pin / install packages from the bundled feed at versions we know exist.
    $packagesToAdd = switch ($Template) {
        'nunit'   { @('Microsoft.NET.Test.Sdk', 'NUnit', 'NUnit3TestAdapter', 'NUnit.Analyzers', 'coverlet.collector', 'Microsoft.Playwright', 'Microsoft.Playwright.NUnit') }
        'mstest'  { @('Microsoft.NET.Test.Sdk', 'MSTest.TestFramework', 'MSTest.TestAdapter', 'MSTest.Analyzers', 'coverlet.collector', 'Microsoft.Playwright', 'Microsoft.Playwright.MSTest') }
        'console' { @('Microsoft.Playwright') }
    }

    Write-Section 'Pinning packages to bundled versions'
    foreach ($pkg in $packagesToAdd) {
        $ver = $Versions[$pkg]
        Write-Host (" + {0} {1}" -f $pkg, $ver) -ForegroundColor Green
        & dotnet add package $pkg --version $ver --no-restore
        if ($LASTEXITCODE -ne 0) { throw "dotnet add package $pkg failed (exit $LASTEXITCODE)." }
    }

    # 7) Final restore — should be fully offline.
    Write-Section 'Restoring (offline)'
    & dotnet restore
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet restore failed (exit $LASTEXITCODE). " +
              "Check that setup-devpack.ps1 was run successfully on this machine."
    }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host ' Project created and restored 100% offline.'                      -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host ''
Write-Host (' cd "{0}"' -f $projectDir)
Write-Host ' dotnet build'
if ($Template -ne 'console') {
    Write-Host ' dotnet test'
}
Write-Host ''
