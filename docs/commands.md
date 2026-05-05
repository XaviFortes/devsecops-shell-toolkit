# Commands guide

## Setup and health

- `Get-DevSecOpsToolkitStatus`: shows install metadata, current Azure subscription, current Kubernetes context, and missing dependencies.
- `Test-DevSecOpsToolkitDependencies`: checks whether required external tools are installed.
- `Install-DevSecOpsToolkitDependencies`: guided dependency installation when `winget` is available, with manual links otherwise.
- `Update-DevSecOpsToolkit`: updates the installed toolkit from the tracked repository.

## Azure and AKS

- `asx`: fuzzy-pick the active Azure subscription.
- `aks-sync`: fuzzy-pick AKS clusters and pull their kubeconfig credentials.
- `Get-AksSpExpiry`: scan AKS service principal secret expiry across subscriptions.
- `get-sp-expiry`: inspect the expiry of a specific Azure app registration secret.

## Kubernetes

- `k-clean`: remove failed, evicted, or errored pods across namespaces.
- `Find-KubeResource -Name api`: search Kubernetes resources across all namespaces.
- aliases: `k`, `kx`, `kn`

## Jenkins and automation

- `Find-JenkinsUserUsage`: search Jenkins credentials usage by user or service principal.
- `New-BmcAzureTicket`: launch the configured automation for Azure secret renewal requests.

## Recommended first-run flow

1. `Get-DevSecOpsToolkitStatus`
2. `Install-DevSecOpsToolkitDependencies`
3. `Update-DevSecOpsToolkit`
