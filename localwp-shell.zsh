#!/usr/bin/env zsh
# localwp-shell - Enter LocalWP site shells from your terminal
# https://github.com/user/localwp-shell

LOCALWP_SSH_ENTRY_DIR="$HOME/Library/Application Support/Local/ssh-entry"

localwp() {
  local site_root=""

  # Walk up from current directory looking for a LocalWP site root
  # A LocalWP site has app/, conf/, and logs/ as siblings
  site_root=$(_localwp_find_site_root)

  if [[ -n "$site_root" ]]; then
    _localwp_enter_shell "$site_root"
  else
    echo "Not inside a LocalWP site directory."
    echo ""
    _localwp_list_sites
  fi
}

_localwp_find_site_root() {
  local dir="$PWD"

  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/app" && -d "$dir/conf" && -d "$dir/logs" ]]; then
      echo "$dir"
      return 0
    fi
    dir="${dir:h}"  # zsh parent directory
  done

  return 1
}

_localwp_enter_shell() {
  local site_root="$1"
  local ssh_entry_dir="$LOCALWP_SSH_ENTRY_DIR"
  local match_file=""
  local match_count=0

  if [[ ! -d "$ssh_entry_dir" ]]; then
    echo "Error: LocalWP ssh-entry directory not found."
    echo "Expected: $ssh_entry_dir"
    echo ""
    echo "Make sure LocalWP is installed and has been started at least once."
    return 1
  fi

  # Read each .sh file and match the cd path to our site root
  # The cd path in ssh-entry files points to site-root/app/public
  local sh_file
  for sh_file in "$ssh_entry_dir"/*.sh(N); do
    local cd_path=""
    cd_path=$(grep -m1 '^cd ' "$sh_file" 2>/dev/null | sed 's/^cd //' | tr -d '"' | tr -d "'")

    if [[ -z "$cd_path" ]]; then
      continue
    fi

    # The cd path is site-root/app/public — check if it's under our site root
    local normalized_cd="${cd_path%/}"
    local normalized_root="${site_root%/}"

    if [[ "$normalized_cd" == "$normalized_root"/* || "$normalized_cd" == "$normalized_root" ]]; then
      match_file="$sh_file"
      ((match_count++))
    fi
  done

  if [[ $match_count -eq 0 ]]; then
    echo "Error: No matching LocalWP shell entry found for this site."
    echo "Site root: $site_root"
    echo ""
    echo "Possible reasons:"
    echo "  - The site is not running in LocalWP"
    echo "  - The ssh-entry file was not generated (try restarting the site)"
    return 1
  fi

  if [[ $match_count -gt 1 ]]; then
    echo "Warning: Multiple ssh-entry files match this site ($match_count found)."
    echo "Using the last match: $(basename "$match_file")"
    echo ""
  fi

  local site_name="$(basename "$site_root")"
  echo "Entering LocalWP shell for: $site_name"
  echo "---"

  # Source the ssh-entry script in current process instead of exec
  # so it sets up the environment and launches the shell
  bash "$match_file"
}

_localwp_list_sites() {
  local ssh_entry_dir="$LOCALWP_SSH_ENTRY_DIR"

  if [[ ! -d "$ssh_entry_dir" ]]; then
    echo "LocalWP ssh-entry directory not found."
    echo "Make sure LocalWP is installed and has been started at least once."
    return 1
  fi

  local sh_files=("$ssh_entry_dir"/*.sh(N))

  if [[ ${#sh_files[@]} -eq 0 ]]; then
    echo "No LocalWP sites found in ssh-entry directory."
    echo "Start a site in LocalWP first."
    return 1
  fi

  echo "Available LocalWP sites:"
  echo ""

  local sh_file
  for sh_file in "${sh_files[@]}"; do
    local cd_path=""
    cd_path=$(grep -m1 '^cd ' "$sh_file" 2>/dev/null | sed 's/^cd //' | tr -d '"' | tr -d "'")

    if [[ -n "$cd_path" ]]; then
      # cd path is like /Users/.../Local Sites/my-site/app/public
      # Site root is two levels up
      local site_dir="$(dirname "$(dirname "$cd_path")")"
      local site_name="$(basename "$site_dir")"

      echo "  $site_name"
      echo "    Path: $site_dir"
    fi
  done

  echo ""
  echo "cd into a site directory and run 'localwp' to enter its shell."
}
