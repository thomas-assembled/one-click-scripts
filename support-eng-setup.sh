#!/bin/bash
#
# support-eng-setup.sh
# Installs and keeps up to date:
#   Apps:      Chrome, 1Password, 1Password CLI, Claude, Postman, Slack, Notion
#   Dev tools: Claude Code CLI, ripgrep, poppler, jq, gh, fzf, htop, wget, tree
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
echo "=== Removing unused dependencies ==="
brew autoremove

echo ""
echo "=== Cleaning up old versions and cached downloads ==="
brew cleanup

echo ""
echo "=== Checking Homebrew health (informational only) ==="
brew doctor || true

echo ""
echo "=== Done! ==="
echo "All apps and dev tools (Claude Code CLI, ripgrep, poppler, jq, gh, fzf, htop, wget, tree) are installed and up to date."
echo ""
read -p "Press Enter to close this window..."
