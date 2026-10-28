#
# support-eng-setup.ps1
# Installs and keeps up to date:
#   Apps:      Chrome, 1Password, 1Password CLI, Claude, Postman, Slack, Notion
#   Dev tools: Claude Code CLI, Git, ripgrep, poppler, jq, gh, fzf, ntop, wget
#   Skills:    the Support Eng Claude skills (assembledhq/support-eng-skills)
#   Code:      a clone of the Assembled repo (first run only, never updated)
#
# Safe to re-run any time - installs whatever is missing, upgrades whatever
# is already there, and picks up apps that were installed some other way
# (e.g. downloaded directly) so it doubles as an "update everything" tool.
#
# Windows version of mac/support-eng-setup.sh. Keep the two in step. Where
# they differ:
#   - winget, which comes with Windows 10 and 11, stands in for Homebrew.
#   - Git is installed too. Macs already have it.
#   - ntop stands in for htop, and tree is skipped because Windows has one.
#   - An app that fails to install is listed at the end instead of stopping
#     the whole run.
#
# Usage, from a normal PowerShell window (not "Run as administrator"):
#   irm <raw-github-url> | iex

# GUI apps + the 1Password CLI, by winget ID
$Apps = @(
    "Google.Chrome"
    "AgileBits.1Password"
    "AgileBits.1Password.CLI"
    "Anthropic.Claude"
    "Postman.Postman"
    "SlackTechnologies.Slack"
    "Notion.Notion"
)

# Command-line tools, by winget ID
$DevTools = @(
    "Anthropic.ClaudeCode"
    "Git.Git"                  # clones the skills and the repo, and gives Claude Code its Bash tool
    "BurntSushi.ripgrep.MSVC"
    "oschwartz10612.Poppler"
    "jqlang.jq"
    "GitHub.cli"
    "junegunn.fzf"
    "gsass1.NTop"              # htop doesn't run on Windows; ntop is the closest match
    "JernejSimoncic.Wget"      # in Windows PowerShell, type wget.exe: plain wget runs Invoke-WebRequest
)

# winget exit codes this script handles, from
# https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h
$WingetNoNewerVersion = 0x8A15002B      # already up to date
$WingetInstalledOtherWay = 0x8A15008E   # installed with an installer winget can't upgrade
$WingetRebootToFinish = 0x8A150109      # installed, finishes on the next restart
$WingetAppInUse = @(0x8A150101, 0x8A150111)

# Support Eng Claude skills, published as a Claude Code plugin marketplace
$SkillsRepo = "assembledhq/support-eng-skills"
$SkillsMarketplace = "assembled-support-eng"
$SkillsPlugin = "support-eng@assembled-support-eng"

# The Assembled repo, cloned to the path Go tooling expects
$AssembledRepo = "assembledhq/assembled"
$AssembledDir = Join-Path $HOME "go\src\github.com\assembledhq\assembled"

# Both the skills repo and the Assembled repo are private, so git needs a
# GitHub login to clone them.
# Set once sign-in is skipped or fails, so later steps don't ask again.
$GitHubLoginSkipped = $false

# winget IDs that didn't install or update, listed at the end
$FailedPackages = @()

# PowerShell carries on after a program fails, so check its exit code.
function Assert-Success($step) {
    if ($LASTEXITCODE -ne 0) {
        throw "$step failed."
    }
}

function Install-WingetPackages($ids) {
    foreach ($id in $ids) {
        Write-Host ""
        Write-Host "--- $id"
        # On something already installed, winget install upgrades it instead,
        # so one command covers both.
        winget install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements
        $code = $LASTEXITCODE
        if ($code -eq 0 -or $code -eq $WingetNoNewerVersion -or $code -eq $WingetRebootToFinish) {
            continue
        }
        if ($code -eq $WingetInstalledOtherWay) {
            Write-Host "$id was installed in a way winget can't update, so leaving it as it is."
            continue
        }
        if ($WingetAppInUse -contains $code) {
            Write-Host "$id is open, so it couldn't be updated. Close it and re-run this script."
        }
        $script:FailedPackages += $id
    }
}

# Installers add themselves to PATH for windows opened later. Load the new
# PATH into this one so the steps below can find git, gh and claude.
function Update-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Connect-GitHub {
    if ($script:GitHubLoginSkipped) {
        throw "GitHub sign-in was skipped earlier in this run."
    }
    gh auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "The Claude skills and the Assembled repo are private, so they need a GitHub account with Assembled access."
        $answer = Read-Host "Press Enter to sign in to GitHub now, or type s and Enter to skip"
        if ($answer -notlike "s*") {
            gh auth login --hostname github.com --git-protocol https --web
        }
        if ($answer -like "s*" -or $LASTEXITCODE -ne 0) {
            $script:GitHubLoginSkipped = $true
            throw "Not signed in to GitHub. Re-run this script once you have an account with access."
        }
    }
    gh auth setup-git --hostname github.com
    Assert-Success "Setting up git to use your GitHub login"
}

function Install-ClaudeSkills {
    Connect-GitHub

    gh repo view $SkillsRepo *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Your GitHub account can't see $SkillsRepo. Ask for access, then re-run this script."
    }

    # Each command is safe to repeat: add and install do nothing if already
    # done, and the two updates pull the latest skills.
    claude plugin marketplace add "https://github.com/$SkillsRepo.git"
    Assert-Success "Adding the skills marketplace"
    claude plugin marketplace update $SkillsMarketplace
    Assert-Success "Updating the skills marketplace"
    claude plugin install $SkillsPlugin
    Assert-Success "Installing the skills plugin"
    claude plugin update $SkillsPlugin
    Assert-Success "Updating the skills plugin"
}

function Copy-AssembledRepo {
    # An existing folder is left exactly as it is: pulling into someone's
    # working copy could collide with work in progress.
    if (Test-Path $AssembledDir) {
        Write-Host "Found $AssembledDir, leaving it untouched."
        return
    }

    Connect-GitHub

    gh repo view $AssembledRepo *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Your GitHub account can't see $AssembledRepo. Ask for access, then re-run this script."
    }

    Write-Host "Downloading the full repo (about 2.5 GB). This can take several minutes."
    New-Item -ItemType Directory -Force -Path (Split-Path $AssembledDir) -ErrorAction Stop | Out-Null
    # Clone into a temporary name so an interrupted download never leaves a
    # half-finished folder that the next run would mistake for a real clone.
    $partial = "$AssembledDir.partial"
    if (Test-Path $partial) {
        Remove-Item $partial -Recurse -Force -ErrorAction Stop
    }
    # Windows caps paths at 260 characters unless long paths are on, and a
    # repo this size can go past that. This turns them on for this clone only.
    git clone -c core.longpaths=true "https://github.com/$AssembledRepo.git" $partial
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $partial -Recurse -Force -ErrorAction SilentlyContinue
        throw "Downloading the Assembled repo failed."
    }
    # Antivirus scanning the new files can briefly block the rename, so retry.
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Move-Item $partial $AssembledDir -ErrorAction Stop
            return
        } catch {
            Start-Sleep -Seconds 3
        }
    }
    throw "The repo downloaded to $partial but couldn't be renamed. Rename that folder to $(Split-Path $AssembledDir -Leaf) yourself before re-running, or the next run will download it again."
}

# Run as administrator, the GitHub login, the skills and the repo can end up
# in the administrator's account instead of yours.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This window is running as administrator, which can set things up for the wrong account."
    Write-Host "Close it, open PowerShell normally (not 'Run as administrator'), and run this again."
    $answer = Read-Host "Press Enter to stop here, or type c and Enter to carry on anyway"
    if ($answer -notlike "c*") {
        return
    }
}

Write-Host "=== Checking for winget ==="
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    # On a new PC winget is often installed but not yet registered for this
    # account. This is Microsoft's documented fix; the check below covers the
    # case where it doesn't help.
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    } catch {}
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget isn't installed. Opening the Microsoft Store: install or update App Installer there, then run this again."
    Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
    Read-Host "Press Enter to finish"
    return
}
Write-Host "winget is ready."

Write-Host ""
Write-Host "=== Updating winget (refreshing available versions) ==="
winget source update --name winget

Write-Host ""
Write-Host "=== Installing and updating apps ==="
Write-Host "Windows may ask whether to let an installer make changes. Click Yes each time."
Install-WingetPackages $Apps

Write-Host ""
Write-Host "=== Installing and updating dev tools ==="
Install-WingetPackages $DevTools
Update-SessionPath

Write-Host ""
Write-Host "=== Installing and updating Support Eng Claude skills ==="
$SkillsStatus = "installed and up to date"
try {
    Install-ClaudeSkills
} catch {
    Write-Host $_.Exception.Message
    $SkillsStatus = "NOT installed (see the message above)"
    Write-Host "Skipping the Claude skills. Everything else will still be set up."
}

Write-Host ""
Write-Host "=== Downloading the Assembled repo (first run only) ==="
$RepoStatus = "at $AssembledDir"
try {
    Copy-AssembledRepo
} catch {
    Write-Host $_.Exception.Message
    $RepoStatus = "NOT downloaded (see the message above)"
    Write-Host "Skipping the Assembled repo. Everything else is set up."
}

Write-Host ""
Write-Host "=== Done! ==="
if ($FailedPackages.Count -eq 0) {
    Write-Host "All apps and dev tools (Claude Code CLI, Git, ripgrep, poppler, jq, gh, fzf, ntop, wget) are installed and up to date."
} else {
    Write-Host "These didn't install or update (see the messages above): $($FailedPackages -join ', '). Re-run this script to try them again."
    Write-Host "All other apps and dev tools are installed and up to date."
}
Write-Host "Support Eng Claude skills: $SkillsStatus. Restart Claude Code to pick up new or changed skills."
Write-Host "Assembled repo: $RepoStatus."
Write-Host "PowerShell windows that were already open need reopening to use the new command-line tools."
Write-Host ""
Read-Host "Press Enter to finish"
