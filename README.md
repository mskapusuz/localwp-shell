# localwp-shell

Enter LocalWP site shells from your terminal. No more clicking "Open Site Shell" in the GUI.

## The Problem

LocalWP is great, but switching to its shell environment means:
1. Open LocalWP GUI
2. Find your site
3. Click "Open Site Shell"
4. Wait for the terminal window to open
5. Navigate back to where you were working

**localwp-shell** lets you type `localwp` from any directory inside a LocalWP site and drops you straight into that site's shell environment — with the right PHP, MySQL, and WP-CLI versions.

## Demo

<!-- TODO: Add terminal recording / gif -->

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/user/localwp-shell/main/install.sh | bash
```

Then restart your terminal or run:

```bash
source ~/.zshrc
```

## Usage

```bash
# From anywhere inside a LocalWP site directory
cd ~/Local\ Sites/my-site/app/public/wp-content/themes/my-theme
localwp
# → Entering LocalWP shell for: my-site
# → Drops you into the LocalWP shell with correct PHP, MySQL, WP-CLI

# From outside a LocalWP site directory
localwp
# → Not inside a LocalWP site directory.
# → Lists all available LocalWP sites
```

## How It Works

1. Walks up from your current directory looking for the LocalWP site root (a directory containing `app/`, `conf/`, and `logs/`)
2. Reads the `.sh` files in `~/Library/Application Support/Local/ssh-entry/` to find the one whose `cd` path matches your site root
3. If no ssh-entry file exists (site never started), automatically generates the shell environment from LocalWP's `sites.json` config
4. Executes the shell script to enter the LocalWP environment with the correct PHP, MySQL, and WP-CLI versions

## Requirements

- macOS (zsh) or Linux (zsh/bash)
- [LocalWP](https://localwp.com/) installed
- **macOS**: Zero external dependencies — uses `osascript` (ships with macOS)
- **Linux**: Requires `node` or `python3` for JSON parsing

## Uninstall

```bash
# Remove the plugin file
rm ~/.localwp-shell.zsh

# Remove the source line from .zshrc
sed -i '' '/localwp-shell/d' ~/.zshrc
```

## Suggested GitHub Topics

`localwp`, `local-by-flywheel`, `wordpress`, `zsh-plugin`, `shell`, `macos`, `linux`, `developer-tools`, `wp-cli`

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by WP Engine, Inc. or its subsidiaries. "Local" and "LocalWP" are trademarks of WP Engine, Inc. "WordPress" is a registered trademark of the WordPress Foundation. All other trademarks are the property of their respective owners.

This is an independent, community-built tool that interacts with locally installed Local software through its existing configuration files. It does not modify, redistribute, or reverse-engineer any part of Local.

## License

MIT
