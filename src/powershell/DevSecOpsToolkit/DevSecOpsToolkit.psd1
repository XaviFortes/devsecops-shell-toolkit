@{
    RootModule        = 'DevSecOpsToolkit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '8f994343-a85c-4654-8465-f9186bb4e5ae'
    Author            = 'Xavi Fortes'
    CompanyName       = 'XaviFortes'
    Copyright         = '(c) 2026 Xavi Fortes. All rights reserved.'
    Description       = 'Reusable PowerShell commands for DevSecOps workflows with install and update support.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'aks-sync',
        'asx',
        'k-clean',
        'Find-KubeResource',
        'get-sp-expiry',
        'Get-AksSpExpiry',
        'Find-JenkinsUserUsage',
        'New-BmcAzureTicket',
        'Get-DevSecOpsToolkitConfig',
        'Get-DevSecOpsToolkitStatus',
        'Test-DevSecOpsToolkitDependencies',
        'Install-DevSecOpsToolkitDependencies',
        'Update-DevSecOpsToolkit'
    )

    AliasesToExport = @(
        'k',
        'kx',
        'kn'
    )
}
