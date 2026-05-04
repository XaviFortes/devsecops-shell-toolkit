# Publishing to GitHub

## Suggested first push

1. Create a new empty repository in your personal GitHub account.
2. Open this folder in PowerShell.
3. Check your git identity before the first public commit:
	- `git config --get user.name`
	- `git config --get user.email`
4. Initialize git.
5. Add the files.
6. Commit.
7. Add your GitHub remote.
8. Push the default branch.

## Example commands

```powershell
git init -b main
git add .
git commit -m "Initial DevSecOps toolkit release"
git remote add origin https://github.com/<your-user>/devsecops-shell-toolkit.git
git push -u origin main
```

## Suggested repository name

`devsecops-shell-toolkit`

## Recommended notes before pushing

- replace any internal URLs you do not want public
- review config defaults
- check whether screenshots or examples contain internal data
- add a license when you decide how you want others to reuse the code

## After publishing

Test the installer with your public repository URL so you know the update path works for other users.
