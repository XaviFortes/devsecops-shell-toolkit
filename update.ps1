$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $moduleManifest = Join-Path $HOME 'Documents\PowerShell\Modules\DevSecOpsToolkit\DevSecOpsToolkit.psd1'
}
else {
    $moduleManifest = Join-Path $HOME 'Documents\WindowsPowerShell\Modules\DevSecOpsToolkit\DevSecOpsToolkit.psd1'
}

if (Test-Path -LiteralPath $moduleManifest) {
    Import-Module $moduleManifest -Force
    Update-DevSecOpsToolkit -Reimport
}
else {
    $localManifest = Join-Path $PSScriptRoot 'src\powershell\DevSecOpsToolkit\DevSecOpsToolkit.psd1'
    Import-Module $localManifest -Force
    Write-Host 'Installed module not found. Running update logic from the local repository checkout.' -ForegroundColor Yellow
    Update-DevSecOpsToolkit -Reimport
}
