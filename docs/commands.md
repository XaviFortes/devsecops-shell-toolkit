# Commands guide

## Help and discovery

- `Start-DevSecOpsToolkit`: opens the main interactive menu for the toolkit.
- `dso`: shortcut alias for the main menu.
- `Get-DevSecOpsToolkitHelp`: lists all toolkit commands with usage.
- `Get-DevSecOpsToolkitHelp -CommandName Get-KubePodRestartReport`: shows detailed usage for one command.
- `Get-DevSecOpsToolkitHelp -Interactive`: opens a simple numbered menu in the terminal.

## Setup and health

- `Get-DevSecOpsToolkitStatus`: shows install metadata, current Azure subscription, current Kubernetes context, and missing dependencies.
- `Test-DevSecOpsToolkitDependencies`: checks whether required external tools are installed.
- `Install-DevSecOpsToolkitDependencies`: guided dependency installation when `winget` is available, with manual links otherwise.
- `Update-DevSecOpsToolkit`: updates the installed toolkit from the tracked repository.

## Azure and AKS

- `Get-AzureSubscriptionSummary`: lists Azure subscriptions and highlights the active one.
- `asx`: fuzzy-pick the active Azure subscription.
- `aks-sync`: fuzzy-pick AKS clusters and pull their kubeconfig credentials.
- `Get-AksSpExpiry`: scan AKS service principal secret expiry across subscriptions.
- `get-sp-expiry`: inspect the expiry of a specific Azure app registration secret.

## Kubernetes

- `k-clean`: remove failed, evicted, or errored pods across namespaces.
- `Find-KubeResource -Name api`: search Kubernetes resources across all namespaces.
- `Get-KubePodRestartReport`: show pods with the highest restart counts.
- `Get-KubeImageInventory`: inventory images currently running in the cluster.
- aliases: `k`, `kx`, `kn`

## Security

- `Test-TlsEndpoint -Url https://example.com`: check TLS certificate issuer, expiry, and days remaining.

## Jenkins and automation

- `Find-JenkinsUserUsage`: search Jenkins credentials usage by user or service principal.
- `New-BmcAzureTicket`: launch the configured automation for Azure secret renewal requests.

## Recommended first-run flow

1. `Get-DevSecOpsToolkitStatus`
2. `Install-DevSecOpsToolkitDependencies`
3. `Update-DevSecOpsToolkit`
