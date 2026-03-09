#!/usr/bin/env zsh
# localwp-shell - Enter LocalWP site shells from your terminal
# https://github.com/user/localwp-shell
# Zero external dependencies on macOS (uses osascript)
# Falls back to python3 or node on Linux

# Platform-aware paths
if [[ "$(uname)" == "Darwin" ]]; then
  LOCALWP_SSH_ENTRY_DIR="$HOME/Library/Application Support/Local/ssh-entry"
  LOCALWP_SITES_JSON="$HOME/Library/Application Support/Local/sites.json"
  LOCALWP_SERVICES_DIR="$HOME/Library/Application Support/Local/lightning-services"
  LOCALWP_RUN_DIR="$HOME/Library/Application Support/Local/run"
else
  LOCALWP_SSH_ENTRY_DIR="$HOME/.config/Local/ssh-entry"
  LOCALWP_SITES_JSON="$HOME/.config/Local/sites.json"
  LOCALWP_SERVICES_DIR="$HOME/.config/Local/lightning-services"
  LOCALWP_RUN_DIR="$HOME/.config/Local/run"
fi

localwp() {
  local site_root=""

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
    dir="${dir:h}"
  done

  return 1
}

_localwp_enter_shell() {
  local site_root="$1"
  local ssh_entry_dir="$LOCALWP_SSH_ENTRY_DIR"
  local match_file=""
  local match_count=0

  if [[ -d "$ssh_entry_dir" ]]; then
    local sh_file
    for sh_file in "$ssh_entry_dir"/*.sh(N); do
      local cd_path=""
      cd_path=$(grep -m1 '^cd ' "$sh_file" 2>/dev/null | sed 's/^cd //' | tr -d '"' | tr -d "'")

      if [[ -z "$cd_path" ]]; then
        continue
      fi

      local normalized_cd="${cd_path%/}"
      local normalized_root="${site_root%/}"

      if [[ "$normalized_cd" == "$normalized_root"/* || "$normalized_cd" == "$normalized_root" ]]; then
        match_file="$sh_file"
        ((match_count++))
      fi
    done
  fi

  if [[ $match_count -gt 1 ]]; then
    echo "Warning: Multiple ssh-entry files match this site ($match_count found)."
    echo "Using the last match: $(basename "$match_file")"
    echo ""
  fi

  if [[ $match_count -eq 0 ]]; then
    match_file=$(_localwp_generate_entry "$site_root")
    if [[ -z "$match_file" ]]; then
      return 1
    fi
  fi

  local site_name="$(basename "$site_root")"
  echo "Entering LocalWP shell for: $site_name"
  echo "---"

  bash "$match_file"
}

# Find the installed lightning-service directory for a given service and version
_localwp_find_service() {
  local service="$1"
  local version="$2"
  local services_dir="$LOCALWP_SERVICES_DIR"

  local match
  for match in "$services_dir"/${service}-${version}+*(N); do
    if [[ -d "$match" ]]; then
      echo "$match"
      return 0
    fi
  done

  return 1
}

# Run a JSON query script with the best available runtime
# Usage: _localwp_run_json <js_code>
# The JS code receives: SITES_JSON, SITE_ROOT, HOME_DIR as env vars
# and should write output to stdout
_localwp_run_json() {
  local js_code="$1"

  if command -v osascript &>/dev/null; then
    # macOS: use JXA (JavaScript for Automation) — always available
    osascript -l JavaScript -e '
var env = ObjC.unwrap($.NSProcessInfo.processInfo.environment);
var _readFile = function(p) {
  return ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null));
};
var SITES_JSON = ObjC.unwrap(env.SITES_JSON);
var SITE_ROOT = ObjC.unwrap(env.SITE_ROOT) || "";
var HOME_DIR = ObjC.unwrap(env.HOME_DIR);
'"$js_code" 2>/dev/null

  elif command -v node &>/dev/null; then
    node -e '
var fs = require("fs");
var _readFile = function(p) { return fs.readFileSync(p, "utf8"); };
var SITES_JSON = process.env.SITES_JSON;
var SITE_ROOT = process.env.SITE_ROOT || "";
var HOME_DIR = process.env.HOME_DIR;
function print(s) { process.stdout.write(s + "\n"); }
'"$js_code" 2>/dev/null

  elif command -v python3 &>/dev/null; then
    python3 -c '
import json, os, sys
def _read_file(p):
    with open(p) as f: return f.read()
SITES_JSON = os.environ["SITES_JSON"]
SITE_ROOT = os.environ.get("SITE_ROOT", "")
HOME_DIR = os.environ["HOME_DIR"]
_js_sites = json.loads(_read_file(SITES_JSON))
'"

# Python adapter: translate the JS logic
_sites = _js_sites
_home = HOME_DIR
_target = SITE_ROOT
$2" 2>/dev/null

  else
    echo "Error: No JSON parser found. Install node or python3." >&2
    return 1
  fi
}

# Parse sites.json to find config for a specific site
# Returns: site_id|name|php_version|mysql_name|mysql_version
_localwp_find_site_config() {
  local site_root="$1"

  if [[ ! -f "$LOCALWP_SITES_JSON" ]]; then
    return 1
  fi

  SITES_JSON="$LOCALWP_SITES_JSON" \
  SITE_ROOT="$site_root" \
  HOME_DIR="$HOME" \
  _localwp_run_json '
var sites = JSON.parse(_readFile(SITES_JSON));
var result = "";
for (var id in sites) {
  var s = sites[id];
  var p = (s.path || "").replace("~", HOME_DIR);
  if (p.replace(/\/$/, "") === SITE_ROOT.replace(/\/$/, "")) {
    var php = (s.services && s.services.php) ? s.services.php.version : "";
    var mv = "", mn = "";
    var names = ["mysql", "mariadb"];
    for (var i = 0; i < names.length; i++) {
      if (!mv && s.services && s.services[names[i]]) {
        mv = s.services[names[i]].version || "";
        mn = s.services[names[i]].name || names[i];
      }
    }
    result = id + "|" + (s.name || "") + "|" + php + "|" + mn + "|" + mv;
    break;
  }
}
result;
'
}

# Generate a temporary ssh-entry script from sites.json
_localwp_generate_entry() {
  local site_root="$1"

  local site_info
  site_info=$(_localwp_find_site_config "$site_root")

  if [[ -z "$site_info" ]]; then
    echo "Error: Site not found in LocalWP's sites.json." >&2
    echo "Site root: $site_root" >&2
    return 1
  fi

  local site_id="${site_info%%|*}"
  local rest="${site_info#*|}"
  local display_name="${rest%%|*}"
  rest="${rest#*|}"
  local php_version="${rest%%|*}"
  rest="${rest#*|}"
  local mysql_name="${rest%%|*}"
  local mysql_version="${rest#*|}"

  local php_dir=""
  local mysql_dir=""

  if [[ -n "$php_version" ]]; then
    php_dir=$(_localwp_find_service "php" "$php_version")
  fi

  if [[ -n "$mysql_version" && -n "$mysql_name" ]]; then
    mysql_dir=$(_localwp_find_service "$mysql_name" "$mysql_version")
  fi

  # Determine architecture
  local arch=""
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) arch="darwin-arm64" ;;
    Darwin-*)     arch="darwin" ;;
    Linux-x86_64) arch="linux" ;;
    Linux-*)      arch="linux-$(uname -m)" ;;
  esac

  # Generate temp script in user-private temp directory
  local tmp_dir="${TMPDIR:-/tmp}"
  local tmp_script
  tmp_script=$(mktemp "${tmp_dir}localwp-shell-XXXXXX")
  mv "$tmp_script" "${tmp_script}.sh"
  tmp_script="${tmp_script}.sh"
  chmod 700 "$tmp_script"

  cat > "$tmp_script" <<SCRIPT
export DISABLE_AUTO_TITLE="true"
echo -n -e "\033]0;${display_name} Shell\007"

SCRIPT

  if [[ -n "$mysql_dir" ]]; then
    cat >> "$tmp_script" <<SCRIPT
export MYSQL_HOME="${LOCALWP_RUN_DIR}/${site_id}/conf/mysql"
SCRIPT
  fi

  if [[ -n "$php_dir" ]]; then
    cat >> "$tmp_script" <<SCRIPT
export PHPRC="${LOCALWP_RUN_DIR}/${site_id}/conf/php"
SCRIPT
  fi

  cat >> "$tmp_script" <<SCRIPT
export WP_CLI_CONFIG_PATH="/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/config.yaml"
export WP_CLI_DISABLE_AUTO_CHECK_UPDATE=1

echo "Setting Local environment variables..."

SCRIPT

  if [[ -n "$mysql_dir" ]]; then
    echo "export PATH=\"${mysql_dir}/bin/${arch}/bin:\$PATH\"" >> "$tmp_script"
  fi

  if [[ -n "$php_dir" ]]; then
    echo "export PATH=\"${php_dir}/bin/${arch}/bin:\$PATH\"" >> "$tmp_script"
  fi

  cat >> "$tmp_script" <<'SCRIPT'
export PATH="/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/posix:$PATH"
export PATH="/Applications/Local.app/Contents/Resources/extraResources/bin/composer/posix:$PATH"
SCRIPT

  if [[ -n "$php_dir" && -d "${php_dir}/bin/${arch}/ImageMagick" ]]; then
    echo "export MAGICK_CODER_MODULE_PATH=\"${php_dir}/bin/${arch}/ImageMagick/modules-Q16/coders\"" >> "$tmp_script"
  fi

  cat >> "$tmp_script" <<SCRIPT

echo "----"
echo "WP-CLI:   \$(wp --version 2>/dev/null || echo 'not found')"
echo "Composer: \$(composer --version 2>/dev/null | cut -f3-4 -d' ' || echo 'not found')"
echo "PHP:      \$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo 'not found')"
echo "MySQL:    \$(mysql --version 2>/dev/null || echo 'not found')"
echo "----"
echo "(generated by localwp-shell)"

cd "${site_root}/app/public"

echo "Launching shell: \$SHELL ..."
exec \$SHELL
SCRIPT

  echo "$tmp_script"
}

_localwp_list_sites() {
  local sites_json="$LOCALWP_SITES_JSON"
  local ssh_entry_dir="$LOCALWP_SSH_ENTRY_DIR"

  if [[ -f "$sites_json" ]]; then
    SITES_JSON="$sites_json" \
    HOME_DIR="$HOME" \
    _localwp_run_json '
var sites = JSON.parse(_readFile(SITES_JSON));
var entries = [];
for (var id in sites) {
  var s = sites[id];
  entries.push({name: s.name || "(unnamed)", path: (s.path || "").replace("~", HOME_DIR)});
}
entries.sort(function(a,b) { return a.name.localeCompare(b.name); });
var lines = ["Available LocalWP sites:", ""];
for (var i = 0; i < entries.length; i++) {
  lines.push("  " + entries[i].name);
  lines.push("    Path: " + entries[i].path);
}
lines.push("");
lines.push("cd into a site directory and run localwp to enter its shell.");
lines.join("\n");
'
    return $?
  fi

  # Fall back to ssh-entry files
  if [[ ! -d "$ssh_entry_dir" ]]; then
    echo "LocalWP not found. Make sure it is installed."
    return 1
  fi

  local sh_files=("$ssh_entry_dir"/*.sh(N))

  if [[ ${#sh_files[@]} -eq 0 ]]; then
    echo "No LocalWP sites found."
    return 1
  fi

  echo "Available LocalWP sites:"
  echo ""

  local sh_file
  for sh_file in "${sh_files[@]}"; do
    local cd_path=""
    cd_path=$(grep -m1 '^cd ' "$sh_file" 2>/dev/null | sed 's/^cd //' | tr -d '"' | tr -d "'")

    if [[ -n "$cd_path" ]]; then
      local site_dir="$(dirname "$(dirname "$cd_path")")"
      local site_name="$(basename "$site_dir")"

      echo "  $site_name"
      echo "    Path: $site_dir"
    fi
  done

  echo ""
  echo "cd into a site directory and run 'localwp' to enter its shell."
}
