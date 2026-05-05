param(
    [string]$RepositoryUrl = 'https://github.com/XaviFortes/devsecops-shell-toolkit.git',
    [switch]$Force,
    [switch]$ConfigureDependencies = $true
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$installScriptUrl = 'https://raw.githubusercontent.com/XaviFortes/devsecops-shell-toolkit/main/install.ps1'
$tempScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("devsecops-toolkit-install-{0}.ps1" -f [guid]::NewGuid().ToString('N'))

try {
    Invoke-WebRequest -Uri $installScriptUrl -OutFile $tempScriptPath
    & $tempScriptPath -RepositoryUrl $RepositoryUrl -Force:$Force -ConfigureDependencies:$ConfigureDependencies
}
finally {
    if (Test-Path -LiteralPath $tempScriptPath) {
        Remove-Item -LiteralPath $tempScriptPath -Force -ErrorAction SilentlyContinue
    }
}
