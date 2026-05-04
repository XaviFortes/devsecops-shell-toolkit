# DevSecOps Shell Toolkit

Shareable shell commands for day-to-day DevSecOps work.

This repository starts with PowerShell support and is already structured to add Bash commands later without changing the layout.

## Repository layout

- `src/powershell/DevSecOpsToolkit`: PowerShell module
- `shells/bash`: future Bash commands and placeholder install/update scripts
- `config/config.example.json`: optional local settings for org-specific integrations
- `install.ps1`: installs the module locally
- `update.ps1`: updates a local installation from the cloned repository

## What is included now

### PowerShell commands

- `aks-sync`
- `asx`
- `k-clean`
- `get-sp-expiry`
- `Get-AksSpExpiry`
- `Find-JenkinsUserUsage`
- `New-BmcAzureTicket`
- `Update-DevSecOpsToolkit`
- aliases: `k`, `kx`, `kn`

## Quick start

### Install from a local clone

1. Clone this repository.
2. Run `./install.ps1` from the repo root.
3. Open a new PowerShell session.

### Install from GitHub directly

After you publish the repo, people can install it with:

`./install.ps1 -RepositoryUrl https://github.com/XaviFortes/devsecops-shell-toolkit.git`

The installer will:

- clone or refresh the repo under `$HOME/.devsecops-shell-toolkit/repo`
- copy the PowerShell module to the user module path
- add the module import to the PowerShell profile if needed
- create a local config file if one does not exist yet

## Updating commands

Users can update in either way:

- Run the PowerShell command `Update-DevSecOpsToolkit`
- Or run `./update.ps1`

That keeps the installed module aligned with the latest repository version.

## Local config

Some commands use organization-specific endpoints or local automation paths. Those values are intentionally moved into a local config file so the public repo stays reusable.

Copy the example values from `config/config.example.json` into your local file:

`$HOME/.devsecops-shell-toolkit/config.json`

Example keys:

- `JenkinsUrl`
- `JenkinsCredentialPath`
- `BmcRobotPath`
- `BmcRobotCommand`

## Adding Bash later

Add Bash commands under `shells/bash` and document usage in that folder. Placeholder files `shells/bash/install.sh` and `shells/bash/update.sh` are included so the repo already has a clean cross-shell layout.

## Before publishing publicly

Review any company-specific URLs, IDs, paths, and credentials flow before pushing to GitHub.

See `docs/publishing.md` for a simple publishing flow.

Repository URL: `https://github.com/XaviFortes/devsecops-shell-toolkit`
