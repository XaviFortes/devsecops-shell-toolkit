# DevSecOps Shell Toolkit

Shareable shell commands for day-to-day DevSecOps work.

This repository starts with PowerShell support and is already structured to add Bash commands later without changing the layout.

By default, the repo is set up for your public GitHub repository:

`https://github.com/XaviFortes/devsecops-shell-toolkit`

## Repository layout

- `src/powershell/DevSecOpsToolkit`: PowerShell module
- `shells/bash`: future Bash commands and placeholder install/update scripts
- `config/config.example.json`: optional local settings for org-specific integrations
- `bootstrap.ps1`: one-command GitHub bootstrap installer
- `install.ps1`: installs the module locally
- `update.ps1`: updates a local installation from the cloned repository

## What is included now

### PowerShell commands

- `Get-DevSecOpsToolkitStatus`
- `Test-DevSecOpsToolkitDependencies`
- `Install-DevSecOpsToolkitDependencies`
- `aks-sync`
- `asx`
- `Find-KubeResource`
- `k-clean`
- `get-sp-expiry`
- `Get-AksSpExpiry`
- `Find-JenkinsUserUsage`
- `New-BmcAzureTicket`
- `Update-DevSecOpsToolkit`
- aliases: `k`, `kx`, `kn`

See [docs/commands.md](docs/commands.md) for the command guide.

## Quick start

### One-command install from GitHub

Users can install directly from GitHub with:

`irm https://raw.githubusercontent.com/XaviFortes/devsecops-shell-toolkit/main/bootstrap.ps1 | iex`

That bootstrap flow downloads the installer, clones the repository, installs the PowerShell module, and can guide users through dependency setup.

### Install from a local clone

1. Clone this repository.
2. Run `./install.ps1 -ConfigureDependencies` from the repo root.
3. Open a new PowerShell session.

### Install from GitHub directly

After you publish the repo, people can install it with:

`./install.ps1 -RepositoryUrl https://github.com/XaviFortes/devsecops-shell-toolkit.git -ConfigureDependencies`

The installer will:

- clone or refresh the repo under `$HOME/.devsecops-shell-toolkit/repo`
- copy the PowerShell module to the user module path
- add the module import to the PowerShell profile if needed
- create a local config file if one does not exist yet
- check optional dependencies and offer guided installation support

## Dependency checks and guided setup

Several commands depend on external tools such as `git`, `az`, `kubectl`, `fzf`, `kubectx`, and `kubens`.

The toolkit now includes:

- `Test-DevSecOpsToolkitDependencies`: check what is installed or missing
- `Install-DevSecOpsToolkitDependencies`: guided install when `winget` is available, or manual guidance links otherwise
- automatic dependency checks before commands like `asx`, `aks-sync`, `Get-AksSpExpiry`, and `k-clean`

Recommended first run:

1. `Get-DevSecOpsToolkitStatus`
2. `Install-DevSecOpsToolkitDependencies`
3. `Update-DevSecOpsToolkit`

## Updating commands

Users can update in either way:

- Run the PowerShell command `Update-DevSecOpsToolkit`
- Or run `./update.ps1`

That keeps the installed module aligned with the latest repository version.

If you add new commands locally while developing this repo:

1. update [src/powershell/DevSecOpsToolkit/DevSecOpsToolkit.psm1](src/powershell/DevSecOpsToolkit/DevSecOpsToolkit.psm1)
2. export the new function in [src/powershell/DevSecOpsToolkit/DevSecOpsToolkit.psd1](src/powershell/DevSecOpsToolkit/DevSecOpsToolkit.psd1)
3. run `./update.ps1`

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
