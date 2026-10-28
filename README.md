# one-click-scripts

A store of useful scripts for the Support Eng team. Each script has a Mac version in [`mac/`](mac) and a Windows version in [`windows/`](windows).

## Support Eng setup

Sets up a support engineer's computer, and keeps it up to date when re-run:

- **Apps:** Chrome, 1Password, 1Password CLI, Claude, Postman, Slack, Notion
- **Dev tools:** Claude Code CLI, ripgrep, poppler, jq, gh, fzf, htop, wget, tree
- **Skills:** the Support Eng Claude skills ([assembledhq/support-eng-skills](https://github.com/assembledhq/support-eng-skills))
- **Code:** a clone of the Assembled repo, on the first run only

The skills and the repo need a GitHub account with Assembled access. The script asks you to sign in, and you can skip that step if you don't have an account yet.

### Mac

Open Terminal and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/thomas-assembled/one-click-scripts/main/mac/support-eng-setup.sh)"
```

### Windows

Open **Windows PowerShell** from the Start menu. Use the normal one, not "Run as administrator". Then paste:

```powershell
irm https://raw.githubusercontent.com/thomas-assembled/one-click-scripts/main/windows/support-eng-setup.ps1 | iex
```

Windows will ask a few times whether to let an installer make changes. Click **Yes** each time.

The Windows version sets up the same things, with a few differences:

- It uses winget, which comes with Windows 10 and 11, instead of Homebrew.
- It also installs Git, which Macs already have.
- ntop stands in for htop. tree is skipped because Windows already has a `tree` command.
- If one app fails to install, the script lists it at the end and still sets up everything else.

## Changing a script

Make the same change in both versions so Mac and Windows users get the same setup.
