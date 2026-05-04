param(
    [string]$RepositoryUrl,
    [string]$InstallRoot = (Join-Path $HOME '.devsecops-shell-toolkit'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function New-DirectoryIfMissing {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Ensure-GitAvailable {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required for repository-based install or update.'
    }
}

function Get-CurrentShellModuleRoot {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return (Join-Path $HOME 'Documents\PowerShell\Modules')
    }

    return (Join-Path $HOME 'Documents\WindowsPowerShell\Modules')
}

$repoRoot = $PSScriptRoot
$repoStoragePath = Join-Path $InstallRoot 'repo'

New-DirectoryIfMissing -Path $InstallRoot

if ($RepositoryUrl) {
    Ensure-GitAvailable

    if (-not (Test-Path -LiteralPath $repoStoragePath)) {
        git clone $RepositoryUrl $repoStoragePath
    }
    else {
        git -C $repoStoragePath pull --ff-only
    }

    $repoRoot = $repoStoragePath
}

$moduleSource = Join-Path $repoRoot 'src\powershell\DevSecOpsToolkit'
if (-not (Test-Path -LiteralPath $moduleSource)) {
    throw "Module source folder not found: $moduleSource"
}

$userModulesRoot = Get-CurrentShellModuleRoot
$moduleTarget = Join-Path $userModulesRoot 'DevSecOpsToolkit'
$configExample = Join-Path $repoRoot 'config\config.example.json'
$configTarget = Join-Path $InstallRoot 'config.json'
$metadataPath = Join-Path $InstallRoot 'install-metadata.json'

New-DirectoryIfMissing -Path $userModulesRoot
if ((Test-Path -LiteralPath $moduleTarget) -and $Force) {
    Remove-Item -LiteralPath $moduleTarget -Recurse -Force
}
New-DirectoryIfMissing -Path $moduleTarget

Copy-Item -Path (Join-Path $moduleSource '*') -Destination $moduleTarget -Recurse -Force

if ((Test-Path -LiteralPath $configExample) -and -not (Test-Path -LiteralPath $configTarget)) {
    Copy-Item -LiteralPath $configExample -Destination $configTarget -Force
}

$metadata = [PSCustomObject]@{
    RepositoryRoot = $repoRoot
    RepositoryUrl  = $RepositoryUrl
    InstalledAt    = (Get-Date).ToString('o')
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding UTF8

$profilePath = $PROFILE.CurrentUserAllHosts
$profileFolder = Split-Path -Path $profilePath -Parent
New-DirectoryIfMissing -Path $profileFolder
if (-not (Test-Path -LiteralPath $profilePath)) {
    New-Item -Path $profilePath -ItemType File -Force | Out-Null
}

$profileContent = Get-Content -LiteralPath $profilePath -Raw
$importLine = 'Import-Module DevSecOpsToolkit -DisableNameChecking -Force'
if ($profileContent -notmatch [regex]::Escape($importLine)) {
    Add-Content -LiteralPath $profilePath -Value "`r`n$importLine`r`n"
}

Import-Module (Join-Path $moduleTarget 'DevSecOpsToolkit.psd1') -Force
Write-Host 'DevSecOpsToolkit installed successfully.' -ForegroundColor Green
Write-Host "Config file: $configTarget" -ForegroundColor Cyan
Write-Host "Profile import ensured in: $profilePath" -ForegroundColor Cyan
Write-Host 'Open a new PowerShell session or import the module again to start using the commands.' -ForegroundColor Yellow
