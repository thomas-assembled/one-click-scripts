#!/bin/bash
#
# support-eng-setup.sh
# Installs and keeps up to date:
#   Apps:      Chrome, 1Password, 1Password CLI, Claude, Postman, Slack, Notion
#   Dev tools: Claude Code CLI, ripgrep, poppler, jq, gh, fzf, htop, wget, tree
#   Skills:    the Support Eng Claude skills (assembledhq/support-eng-skills)
#   Code:      a clone of the Assembled repo (first run only, never updated)
#
# Safe to re-run any time — installs whatever is missing, upgrades whatever
# is already there, and adopts apps that were installed some other way
# (e.g. downloaded directly) so it doubles as an "update everything" tool.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL <raw-github-url>)"

set -e

# GUI apps + CLI tools that ship as Homebrew casks
CASKS="google-chrome 1password 1password-cli claude postman slack notion claude-code"

# Command-line tools that ship as Homebrew formulae
FORMULAE="ripgrep poppler jq gh fzf htop wget tree"

# Support Eng Claude skills, published as a Claude Code plugin marketplace
SKILLS_REPO="assembledhq/support-eng-skills"
SKILLS_MARKETPLACE="assembled-support-eng"
SKILLS_PLUGIN="support-eng@assembled-support-eng"

# The Assembled repo, cloned to the path Go tooling expects
ASSEMBLED_REPO="assembledhq/assembled"
ASSEMBLED_DIR="$HOME/go/src/github.com/assembledhq/assembled"

# Both the skills repo and the Assembled repo are private, so git needs a
# GitHub login to clone them.
# Set once sign-in is skipped or fails, so later steps don't ask again.
GITHUB_LOGIN_SKIPPED=""

ensure_github_login() {
    if [[ -n "$GITHUB_LOGIN_SKIPPED" ]]; then
        echo "GitHub sign-in was skipped earlier in this run."
        return 1
    fi
    if ! gh auth status --hostname github.com &> /dev/null; then
        echo "The Claude skills and the Assembled repo are private, so they need a GitHub account with Assembled access."
        read -r -p "Press Enter to sign in to GitHub now, or type s and Enter to skip: " answer
        if [[ "$answer" == [sS]* ]] || ! gh auth login --hostname github.com --git-protocol https --web; then
            GITHUB_LOGIN_SKIPPED="yes"
            echo "Not signed in to GitHub. Re-run this script once you have an account with access."
            return 1
        fi
    fi
    gh auth setup-git --hostname github.com || return 1
}

install_claude_skills() {
    ensure_github_login || return 1

    if ! gh repo view "$SKILLS_REPO" &> /dev/null; then
        echo "Your GitHub account can't see $SKILLS_REPO. Ask for access, then re-run this script."
        return 1
    fi

    # Each command is safe to repeat: add and install do nothing if already
    # done, and the two updates pull the latest skills.
    claude plugin marketplace add "https://github.com/$SKILLS_REPO.git" || return 1
    claude plugin marketplace update "$SKILLS_MARKETPLACE" || return 1
    claude plugin install "$SKILLS_PLUGIN" || return 1
    claude plugin update "$SKILLS_PLUGIN" || return 1
}

clone_assembled_repo() {
    # An existing folder is left exactly as it is: pulling into someone's
    # working copy could collide with work in progress.
    if [[ -e "$ASSEMBLED_DIR" ]]; then
        echo "Found $ASSEMBLED_DIR, leaving it untouched."
        return 0
    fi

    ensure_github_login || return 1

    if ! gh repo view "$ASSEMBLED_REPO" &> /dev/null; then
        echo "Your GitHub account can't see $ASSEMBLED_REPO. Ask for access, then re-run this script."
        return 1
    fi

    echo "Downloading the full repo (about 2.5 GB). This can take several minutes."
    mkdir -p "$(dirname "$ASSEMBLED_DIR")" || return 1
    # Clone into a temporary name so an interrupted download never leaves a
    # half-finished folder that the next run would mistake for a real clone.
    rm -rf "$ASSEMBLED_DIR.partial"
    if ! git clone "https://github.com/$ASSEMBLED_REPO.git" "$ASSEMBLED_DIR.partial"; then
        rm -rf "$ASSEMBLED_DIR.partial"
        return 1
    fi
    mv "$ASSEMBLED_DIR.partial" "$ASSEMBLED_DIR" || return 1
}

echo "=== Installing Homebrew (if needed) ==="
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed."
fi

echo ""
echo "=== Updating Homebrew (refreshing available versions) ==="
brew update

echo ""
echo "=== Installing apps (adopting existing installs if found) ==="
# --adopt: if an app is already installed but NOT via Homebrew (e.g. downloaded
# manually from the vendor's site), brew takes over managing it instead of
# failing with "there is already an App at ...".
brew install --cask --adopt $CASKS

echo ""
echo "=== Upgrading apps that are already installed ==="
# --greedy: some casks (Chrome, 1Password, Slack, etc.) are marked as
# self-updating and get skipped by a normal upgrade — --greedy forces the check.
brew upgrade --cask --greedy $CASKS

echo ""
echo "=== Installing dev tools ==="
brew install $FORMULAE

echo ""
echo "=== Upgrading dev tools ==="
brew upgrade $FORMULAE

echo ""
echo "=== Installing and updating Support Eng Claude skills ==="
SKILLS_STATUS="installed and up to date"
if ! install_claude_skills; then
    SKILLS_STATUS="NOT installed (see the message above)"
    echo "Skipping the Claude skills. Everything else will still be set up."
fi

echo ""
echo "=== Removing unused dependencies ==="
brew autoremove

echo ""
echo "=== Cleaning up old versions and cached downloads ==="
brew cleanup

echo ""
echo "=== Checking Homebrew health (informational only) ==="
brew doctor || true

echo ""
echo "=== Downloading the Assembled repo (first run only) ==="
REPO_STATUS="at $ASSEMBLED_DIR"
if ! clone_assembled_repo; then
    REPO_STATUS="NOT downloaded (see the message above)"
    echo "Skipping the Assembled repo. Everything else is set up."
fi

echo ""
echo "=== Done! ==="
echo "All apps and dev tools (Claude Code CLI, ripgrep, poppler, jq, gh, fzf, htop, wget, tree) are installed and up to date."
echo "Support Eng Claude skills: $SKILLS_STATUS. Restart Claude Code to pick up new or changed skills."
echo "Assembled repo: $REPO_STATUS."
echo ""
read -p "Press Enter to close this window..."
