#!/usr/bin/env bash
# localwp-shell installer
# Usage: curl -fsSL https://raw.githubusercontent.com/user/localwp-shell/main/install.sh | bash

set -euo pipefail

PLUGIN_URL="https://raw.githubusercontent.com/user/localwp-shell/main/localwp-shell.zsh"
INSTALL_PATH="$HOME/.localwp-shell.zsh"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE='source "$HOME/.localwp-shell.zsh"'

echo "Installing localwp-shell..."

# Download the plugin
if command -v curl &>/dev/null; then
  curl -fsSL "$PLUGIN_URL" -o "$INSTALL_PATH"
elif command -v wget &>/dev/null; then
  wget -qO "$INSTALL_PATH" "$PLUGIN_URL"
else
  echo "Error: curl or wget is required."
  exit 1
fi

# Add source line to .zshrc if not already present
if ! grep -qF '.localwp-shell.zsh' "$ZSHRC" 2>/dev/null; then
  echo "" >> "$ZSHRC"
  echo "# localwp-shell: enter LocalWP site shells from your terminal" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "Added source line to $ZSHRC"
else
  echo "Source line already exists in $ZSHRC"
fi

echo ""
echo "Installed! Run 'source ~/.zshrc' or open a new terminal, then:"
echo "  cd into a LocalWP site directory and type 'localwp'"
