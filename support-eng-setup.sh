#!/bin/bash
#
# Support Engineer Setup.command
# Double-click this file in Finder to install and/or update to the latest
# versions of: Chrome, 1Password, 1Password CLI, Claude, Postman, Slack
#
# Safe to re-run any time — it installs whatever is missing, upgrades
# whatever is already there, and adopts apps that were installed some
# other way (e.g. downloaded directly) so it doubles as an "update my
# apps" tool.

set -e

APPS="google-chrome 1password 1password-cli claude postman slack"

echo "=== Installing Homebrew (if needed) ==="
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for this session (Apple Silicon default location)
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
echo "=== Installing any missing apps (adopting existing installs if found) ==="
# --adopt: if an app is already installed but NOT via Homebrew (e.g. downloaded
# manually from the vendor's site), brew will take over managing it instead of
# failing with "there is already an App at ...". This lets future runs of this
# script upgrade it like any other brew-managed app.
brew install --cask --adopt $APPS

echo ""
echo "=== Upgrading any apps that are already installed ==="
brew upgrade --cask --greedy $APPS

echo ""
echo "=== Cleaning up old versions ==="
brew cleanup

echo ""
echo "=== Done! ==="
echo "Chrome, 1Password, 1Password CLI, Claude, Postman, and Slack are all installed and up to date."
echo ""
read -p "Press Enter to close this window..."
