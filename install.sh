#!/bin/bash

# install.sh: Claude Code Configuration Installer
# install.sh: Installs hooks, commands, settings, and statusline to ~/.claude

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# install.sh: Optional features (off by default — high failure risk on new machines)
INSTALL_ACADEMIC="${INSTALL_ACADEMIC:-0}"
for arg in "$@"; do
    case "$arg" in
        --academic) INSTALL_ACADEMIC=1 ;;
        --help|-h)
            echo "Usage: $0 [--academic]"
            echo "  --academic   Install claude-scholar + ARS plugins and their system deps"
            echo "               (pandoc, pipx, arxiv-latex-cleaner). Skipped by default."
            exit 0
            ;;
    esac
done

# install.sh: Track installation results for final summary
INSTALLED=()
SKIPPED=()
FAILED=()

# Colors (disabled when output is not a terminal)
if [ -t 1 ]; then
    C_GREEN='\033[0;32m'  C_YELLOW='\033[0;33m'  C_RED='\033[0;31m'  C_RESET='\033[0m'
else
    C_GREEN=''  C_YELLOW=''  C_RED=''  C_RESET=''
fi

FIXES=()

mark_ok()      { INSTALLED+=("$1"); }
mark_skipped() { SKIPPED+=("$1: $2"); }
mark_failed()  { FAILED+=("$1: $2"); FIXES+=("${3:-}"); }

echo "Installing Claude Code Configuration..."
echo "========================================"
echo ""

# Detect platform (macos | ubuntu | unknown)
detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian) echo "ubuntu" ;;
                    *) echo "unknown" ;;
                esac
            else
                echo "unknown"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}
PLATFORM="$(detect_platform)"

# install.sh: dpkg strict installed-status check (rejects half-configured packages)
dpkg_is_installed() {
    [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
}

# install.sh: track whether `apt-get update` has run this session
APT_UPDATED=0
ensure_apt_updated() {
    if [ "$APT_UPDATED" = "0" ]; then
        # only mark updated on actual success — failures should allow retry on next call
        sudo -n apt-get update >/dev/null 2>&1 && APT_UPDATED=1 || true
    fi
}

# install.sh: cross-platform package install (macos via brew, ubuntu via apt)
pkg_install() {
    local pkg="$1"
    case "$PLATFORM" in
        macos)
            if brew list "$pkg" &>/dev/null; then
                mark_ok "pkg: $pkg (already installed)"
                return 0
            fi
            local err
            if err="$(brew install "$pkg" 2>&1 >/dev/null)"; then
                mark_ok "pkg: $pkg"
            else
                mark_failed "pkg: $pkg" "brew install failed: $(echo "$err" | tail -1)" "brew install $pkg"
            fi
            ;;
        ubuntu)
            if dpkg_is_installed "$pkg"; then
                mark_ok "pkg: $pkg (already installed)"
                return 0
            fi
            # require non-interactive sudo so headless installs don't hang
            if ! sudo -n true 2>/dev/null; then
                mark_failed "pkg: $pkg" "passwordless sudo unavailable" "run: sudo apt-get install -y $pkg"
                return 0
            fi
            ensure_apt_updated
            local err
            if err="$(sudo -n apt-get install -y "$pkg" 2>&1 >/dev/null)"; then
                mark_ok "pkg: $pkg"
            else
                mark_failed "pkg: $pkg" "apt install failed: $(echo "$err" | tail -1)" "sudo apt-get install -y $pkg"
            fi
            ;;
        *)
            mark_skipped "pkg: $pkg" "unsupported platform: $PLATFORM"
            ;;
    esac
}

# Detect shell config file (prefer the active shell, not just what exists)
SHELL_CONFIG=""
CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"
if [ "$CURRENT_SHELL" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ "$CURRENT_SHELL" = "bash" ] && [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

# Create directories
echo "Creating directory structure..."
mkdir -p "$CLAUDE_DIR"/{commands,profiles,scripts,skills}

# Merge settings (preserves existing keys like enabledPlugins while updating ours)
echo "Installing settings.json..."
# Keeps a timestamped copy under backups/ alongside the single .backup slot, so running the
# installer twice does not leave the original unrecoverable.
BACKUP_DIR="$CLAUDE_DIR/backups"
archive_backup() {
    local src="$1"
    [ -f "$src" ] || return 0
    mkdir -p "$BACKUP_DIR"
    cp "$src" "$BACKUP_DIR/$(basename "$src").$(date +%Y%m%d-%H%M%S)"
}

if [ -f "$CLAUDE_DIR/settings.json" ]; then
    archive_backup "$CLAUDE_DIR/settings.json"
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.backup"
    if command -v jq &>/dev/null; then
        # `*` recurses into objects but replaces arrays, so permissions.allow and every
        # hooks.<event> array would be overwritten. Those are unioned instead: approvals granted
        # over time and hooks the user added themselves both survive an install. Every other key
        # takes the repo's value.
        if jq -s '
              .[0] as $live | .[1] as $repo
            | ($live * $repo)
            | .permissions.allow = (($live.permissions.allow // []) + ($repo.permissions.allow // []) | unique)
            | .permissions.deny  = (($live.permissions.deny  // []) + ($repo.permissions.deny  // []) | unique)
            | .hooks = (
                (($live.hooks // {}) | keys) + (($repo.hooks // {}) | keys) | unique
                | map({ key: ., value: (
                    (($live.hooks[.] // []) + ($repo.hooks[.] // [])) | unique_by(tojson)
                  )})
                | from_entries)
          ' "$CLAUDE_DIR/settings.json" "$SCRIPT_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp"; then
            mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
            echo "  Merged settings.json (old version backed up)"
            mark_ok "settings.json (merged)"
        else
            rm -f "$CLAUDE_DIR/settings.json.tmp"
            mark_failed "settings.json" "jq merge failed" "brew install jq && re-run install.sh"
        fi
    else
        # Overwriting would drop the permission allowlist, model and plugin settings that live only
        # in the installed file. Losing those is worse than not installing, so the existing file is
        # left alone.
        mark_failed "settings.json" "jq not found, existing file left unchanged" \
                    "install jq (apt-get install -y jq / brew install jq) and re-run install.sh"
    fi
else
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    mark_ok "settings.json"
fi

# Copy CLAUDE.md
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo "Installing CLAUDE.md..."
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    mark_ok "CLAUDE.md"
else
    echo "CLAUDE.md exists, creating backup..."
    archive_backup "$CLAUDE_DIR/CLAUDE.md"
    cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "  Updated CLAUDE.md (old version backed up)"
    mark_ok "CLAUDE.md (updated)"
fi

# Copy hooks. Every hooks/<event>/ directory in the repo is installed, so adding a new event
# directory does not require editing this script.
echo "Installing safety hooks..."
HOOKS_COPIED=0
for hook_dir in "$SCRIPT_DIR/hooks"/*/; do
    [ -d "$hook_dir" ] || continue
    event_name=$(basename "$hook_dir")
    mkdir -p "$CLAUDE_DIR/hooks/$event_name"
    # test-*.js and cases.js are the repo's own checks and corpus, not hooks.
    for hook_file in "$hook_dir"*.js "$hook_dir"*.py; do
        [ -f "$hook_file" ] || continue
        case "$(basename "$hook_file")" in test-*|cases.js) continue ;; esac
        cp "$hook_file" "$CLAUDE_DIR/hooks/$event_name/" && HOOKS_COPIED=1
    done
done
if [ "$HOOKS_COPIED" -eq 1 ]; then
    mark_ok "Safety hooks"
else
    mark_failed "Safety hooks" "no hook files found in repo" "check that hooks/*/ has .js or .py files"
fi

# Claude Code finds hooks only through settings.json, so a copied file at a path settings.json does
# not name is inert, and a path settings.json names that does not exist fails silently at runtime.
# Both are checked here rather than assumed from a successful copy.
if command -v jq &>/dev/null; then
    MISSING_HOOKS=""
    while read -r hook_path; do
        [ -n "$hook_path" ] || continue
        resolved="${hook_path/#\~\/.claude\//$CLAUDE_DIR/}"
        resolved="${resolved/#\$HOME\/.claude\//$CLAUDE_DIR/}"
        [ -f "$resolved" ] || MISSING_HOOKS="$MISSING_HOOKS $hook_path"
    done < <(jq -r '(.hooks // {}) | to_entries[].value[]?.hooks[]?.command // empty' "$CLAUDE_DIR/settings.json" 2>/dev/null \
             | grep -oE '(~|\$HOME)/\.claude/[^ "]+' || true)
    if [ -n "$MISSING_HOOKS" ]; then
        mark_failed "Hook paths" "settings.json points at missing files:$MISSING_HOOKS" \
                    "check that hooks/<event>/ in the repo matches the paths in settings.json"
    else
        mark_ok "Hook paths resolve"
    fi
fi

# Copy statusline script
echo "Installing statusline script..."
if [ -f "$SCRIPT_DIR/statusline-script.sh" ]; then
    archive_backup "$CLAUDE_DIR/statusline-script.sh"
    cp "$SCRIPT_DIR/statusline-script.sh" "$CLAUDE_DIR/statusline-script.sh"
    chmod +x "$CLAUDE_DIR/statusline-script.sh"
    mark_ok "Statusline script"
else
    mark_failed "Statusline script" "source file not found" "ensure statusline-script.sh exists in the repo root"
fi

# Copy commands
echo "Installing commands..."
if compgen -G "$SCRIPT_DIR/commands/*.md" >/dev/null; then
    if cp "$SCRIPT_DIR/commands/"*.md "$CLAUDE_DIR/commands/" 2>/dev/null; then
        mark_ok "Commands"
    else
        mark_failed "Commands" "copy failed" "check permissions on $CLAUDE_DIR/commands/"
    fi
else
    mark_skipped "Commands" "no .md files in commands/"
fi

# Copy profiles
echo "Installing profiles..."
PROFILES_COPIED=0
for profile in "$SCRIPT_DIR/profiles"/*.json "$SCRIPT_DIR/profiles"/*.template; do
    [ -f "$profile" ] || continue
    # A profile may hold an API key, so keep a copy before replacing it.
    archive_backup "$CLAUDE_DIR/profiles/$(basename "$profile")"
    cp "$profile" "$CLAUDE_DIR/profiles/" 2>/dev/null && PROFILES_COPIED=1
done
if [ "$PROFILES_COPIED" -eq 1 ]; then
    mark_ok "Profiles"
else
    mark_skipped "Profiles" "no profile files found"
fi

# Copy scripts
echo "Installing scripts..."
if compgen -G "$SCRIPT_DIR/scripts/*.sh" >/dev/null; then
    if cp "$SCRIPT_DIR/scripts/"*.sh "$CLAUDE_DIR/scripts/" 2>/dev/null; then
        chmod +x "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null || true
        mark_ok "Scripts"
    else
        mark_failed "Scripts" "copy failed" "check permissions on $CLAUDE_DIR/scripts/"
    fi
else
    mark_skipped "Scripts" "no .sh files in scripts/"
fi

# Install skills
echo "Installing skills..."
SKILLS_COUNT=0
if [ -d "$SCRIPT_DIR/skills" ]; then
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        echo "  Installing skill: $skill_name"
        mkdir -p "$CLAUDE_DIR/skills/$skill_name"
        if cp -r "$skill_dir"* "$CLAUDE_DIR/skills/$skill_name/"; then
            SKILLS_COUNT=$((SKILLS_COUNT + 1))
        else
            mark_failed "Skill: $skill_name" "copy failed" "check permissions on ~/.claude/skills/"
        fi
    done
fi
# Report installed skills and commands that no longer exist in the repo. These are not removed
# automatically: they may have been added directly or by another tool, and deleting a user's
# config without asking is not this script's decision. A skill removed from the repo to resolve a
# conflict stays live until it is deleted here, so the warning names the command to run.
STALE_FOUND=0
for installed in "$CLAUDE_DIR/skills"/*/; do
    [ -d "$installed" ] || continue
    name=$(basename "$installed")
    if [ ! -d "$SCRIPT_DIR/skills/$name" ]; then
        [ "$STALE_FOUND" -eq 0 ] && echo "" && echo "  Installed but not in this repo:"
        STALE_FOUND=1
        echo "    skill '$name'  ->  rm -rf $CLAUDE_DIR/skills/$name"
    fi
done
for installed in "$CLAUDE_DIR/commands"/*.md; do
    [ -f "$installed" ] || continue
    name=$(basename "$installed")
    if [ ! -f "$SCRIPT_DIR/commands/$name" ]; then
        [ "$STALE_FOUND" -eq 0 ] && echo "" && echo "  Installed but not in this repo:"
        STALE_FOUND=1
        echo "    command '$name'  ->  rm $CLAUDE_DIR/commands/$name"
    fi
done
# A hook file absent from the repo is only stale if nothing invokes it. One the user added and
# registered themselves is live config, and recommending its deletion would break their setup.
REGISTERED_HOOKS=""
if command -v jq &>/dev/null && [ -f "$CLAUDE_DIR/settings.json" ]; then
    REGISTERED_HOOKS="$(jq -r '(.hooks // {}) | to_entries[].value[]?.hooks[]?.command // empty' \
                        "$CLAUDE_DIR/settings.json" 2>/dev/null || true)"
fi
for installed_dir in "$CLAUDE_DIR/hooks"/*/; do
    [ -d "$installed_dir" ] || continue
    event_name=$(basename "$installed_dir")
    for installed in "$installed_dir"*; do
        [ -f "$installed" ] || continue
        name=$(basename "$installed")
        [ -f "$SCRIPT_DIR/hooks/$event_name/$name" ] && continue
        case "$REGISTERED_HOOKS" in *"$name"*) continue ;; esac
        [ "$STALE_FOUND" -eq 0 ] && echo "" && echo "  Installed but not in this repo:"
        STALE_FOUND=1
        echo "    hook '$event_name/$name'  ->  rm $installed"
    done
done
if [ "$STALE_FOUND" -eq 1 ]; then
    echo "  Review these; a skill kept alongside its replacement can give conflicting instructions."
    echo ""
fi

if [ "$SKILLS_COUNT" -gt 0 ]; then
    mark_ok "Skills ($SKILLS_COUNT installed)"
else
    mark_skipped "Skills" "no skill directories found"
fi

# Ensure npm global bin is on PATH
NPM_GLOBAL_BIN="$(npm config get prefix 2>/dev/null || true)/bin"
if [ -n "$NPM_GLOBAL_BIN" ] && [[ ":$PATH:" != *":$NPM_GLOBAL_BIN:"* ]]; then
    export PATH="$NPM_GLOBAL_BIN:$PATH"
fi

# Install Codex CLI
echo ""
if command -v codex &> /dev/null; then
    echo "Codex CLI already installed ($(codex --version 2>/dev/null || echo 'unknown'))"
    mark_ok "Codex CLI (already installed)"
else
    echo "Installing Codex CLI..."
    if command -v npm &> /dev/null; then
        if npm install -g @openai/codex 2>/dev/null; then
            # Verify it's now findable
            if command -v codex &> /dev/null; then
                mark_ok "Codex CLI"
            else
                mark_failed "Codex CLI" "installed but not on PATH" "export PATH=\"$NPM_GLOBAL_BIN:\$PATH\" and restart terminal"
            fi
        else
            echo "  Global install failed (permissions)."
            echo "  Run manually: sudo npm install -g @openai/codex"
            mark_failed "Codex CLI" "npm install failed (permissions)" "sudo npm install -g @openai/codex"
        fi
    else
        echo "  npm not found. Install Node.js first, then: npm install -g @openai/codex"
        mark_failed "Codex CLI" "npm/node not installed" "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && nvm install --lts"
    fi
fi

# Persist npm global bin in shell config if missing
if [ -n "$NPM_GLOBAL_BIN" ] && [ -d "$NPM_GLOBAL_BIN" ]; then
    PATH_EXPORT="export PATH=\"$NPM_GLOBAL_BIN:\$PATH\""
    if [ -n "$SHELL_CONFIG" ] && ! grep -qF "$NPM_GLOBAL_BIN" "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >> "$SHELL_CONFIG"
        echo "# npm global bin (added by Claude Code installer)" >> "$SHELL_CONFIG"
        echo "$PATH_EXPORT" >> "$SHELL_CONFIG"
        echo "  Added $NPM_GLOBAL_BIN to $SHELL_CONFIG"
    fi
fi

# Install academic writing system deps (claude-scholar + ARS plugins)
# install.sh: opt-in only — these installs (brew/apt/pipx + plugin marketplaces)
# have high failure rates on fresh machines (network, sudo, PATH).
if [ "$INSTALL_ACADEMIC" = "1" ]; then
    echo ""
    echo "Installing academic writing system deps..."
    pkg_install pandoc
    pkg_install pipx

    if command -v pipx &>/dev/null; then
        pipx ensurepath >/dev/null 2>&1 || true
        # exact-name check (machine-readable: lists installed venv names, one per line)
        if pipx list --short 2>/dev/null | awk '{print $1}' | grep -qx "arxiv-latex-cleaner"; then
            mark_ok "pipx: arxiv-latex-cleaner (already installed)"
        else
            PIPX_ERR="$(pipx install arxiv-latex-cleaner 2>&1 >/dev/null)" \
                && mark_ok "pipx: arxiv-latex-cleaner" \
                || mark_failed "pipx: arxiv-latex-cleaner" "install failed: $(echo "$PIPX_ERR" | tail -1)" "pipx install arxiv-latex-cleaner"
            unset PIPX_ERR
        fi
    else
        mark_skipped "pipx: arxiv-latex-cleaner" "pipx not available"
    fi

    # LaTeX stack — print-only (large install, often already present via tlmgr/MacTeX)
    LATEX_MISSING=()
    for cmd in lualatex pdflatex bibtex biber latexmk; do
        command -v "$cmd" >/dev/null || LATEX_MISSING+=("$cmd")
    done
    if [ ${#LATEX_MISSING[@]} -gt 0 ]; then
        case "$PLATFORM" in
            ubuntu)
                mark_skipped "LaTeX stack" "missing: ${LATEX_MISSING[*]} — run: sudo apt-get install -y texlive-luatex texlive-bibtex-extra biber latexmk"
                ;;
            macos)
                mark_skipped "LaTeX stack" "missing: ${LATEX_MISSING[*]} — install MacTeX from https://www.tug.org/mactex/ or: brew install --cask mactex-no-gui"
                ;;
            *)
                mark_skipped "LaTeX stack" "missing: ${LATEX_MISSING[*]}"
                ;;
        esac
    else
        mark_ok "LaTeX stack (lualatex, biber, latexmk)"
    fi
else
    mark_skipped "Academic writing setup" "opt-in: re-run with ./install.sh --academic"
fi

# Install marketplace plugins
echo ""
echo "Installing recommended plugins..."
PLUGINS=("context7" "code-simplifier" "superpowers" "claude-md-management" "skill-creator")

# Marketplace plugins (academic writing): "marketplace_repo:plugin@marketplace_name"
ACADEMIC_MARKETPLACES=(
    "yy/claude-scholar:claude-scholar@claude-scholar"
    "Imbad0202/academic-research-skills:academic-research-skills@academic-research-skills"
)

if command -v claude &> /dev/null; then
    # Add Codex marketplace and plugin
    echo "  Adding Codex marketplace..."
    if claude plugin marketplace add openai/codex-plugin-cc 2>/dev/null; then
        mark_ok "Plugin: codex-marketplace"
    else
        mark_skipped "Plugin: codex-marketplace" "already added or unavailable"
    fi

    INSTALLED_PLUGINS="$(claude plugin list 2>/dev/null || true)"

    echo "  Installing codex plugin..."
    if printf '%s' "$INSTALLED_PLUGINS" | grep -q "codex"; then
        mark_ok "Plugin: codex (already installed)"
    elif claude plugin install "codex@openai-codex" 2>/dev/null; then
        mark_ok "Plugin: codex"
    else
        mark_failed "Plugin: codex" "install failed (offline or unavailable)" \
                    "check network, then: claude plugin install codex@openai-codex"
    fi

    for plugin in "${PLUGINS[@]}"; do
        echo "  Installing $plugin..."
        if printf '%s' "$INSTALLED_PLUGINS" | grep -q "^\s*${plugin%%@*}\b"; then
            mark_ok "Plugin: $plugin (already installed)"
        elif claude plugin install "$plugin" 2>/dev/null; then
            mark_ok "Plugin: $plugin"
        else
            mark_failed "Plugin: $plugin" "install failed (offline or unavailable)" \
                        "check network, then: claude plugin install $plugin"
        fi
    done

    # Academic writing marketplaces (claude-scholar + ARS) — opt-in
    if [ "$INSTALL_ACADEMIC" = "1" ]; then
        # Cache existing marketplace + plugin lists so we can distinguish
        # "already there" (skip) from "operation failed" (real failure).
        EXISTING_MARKETS="$(claude plugin marketplace list 2>/dev/null || true)"
        EXISTING_PLUGINS="$(claude plugin list 2>/dev/null || true)"

        for entry in "${ACADEMIC_MARKETPLACES[@]}"; do
            market="${entry%%:*}"
            pkg="${entry##*:}"
            market_short="${market##*/}"
            plugin_name="${pkg%@*}"

            echo "  Adding marketplace $market..."
            # exact whole-word match, anchored to non-name boundaries — avoids
            # false-matching extensions like `claude-scholar-extra`
            if echo "$EXISTING_MARKETS" | awk -v m="$market_short" '$0 ~ ("(^|[[:space:]/])"m"([[:space:]]|$)") {f=1} END {exit !f}'; then
                mark_ok "Marketplace: $market (already added)"
            else
                MARKET_ERR="$(claude plugin marketplace add "$market" 2>&1 >/dev/null)" \
                    && mark_ok "Marketplace: $market" \
                    || mark_failed "Marketplace: $market" "add failed: $(echo "$MARKET_ERR" | tail -1)" "claude plugin marketplace add $market"
                unset MARKET_ERR
            fi

            echo "  Installing $pkg..."
            if echo "$EXISTING_PLUGINS" | awk -v p="$plugin_name" '$0 ~ ("(^|[[:space:]/@])"p"([[:space:]@]|$)") {f=1} END {exit !f}'; then
                mark_ok "Plugin: $pkg (already installed)"
            else
                PLUGIN_ERR="$(claude plugin install "$pkg" 2>&1 >/dev/null)" \
                    && mark_ok "Plugin: $pkg" \
                    || mark_failed "Plugin: $pkg" "install failed: $(echo "$PLUGIN_ERR" | tail -1)" "claude plugin install $pkg"
                unset PLUGIN_ERR
            fi
        done
        unset EXISTING_MARKETS EXISTING_PLUGINS
    fi
else
    echo "  Claude CLI not found. Skipping plugin installation."
    mark_failed "Plugins (all)" "claude CLI not installed" "npm install -g @anthropic-ai/claude-code && re-run install.sh"
    echo "  Install plugins manually after installing Claude CLI:"
    echo "    claude plugin marketplace add openai/codex-plugin-cc"
    echo "    claude plugin install codex@openai-codex"
    for plugin in "${PLUGINS[@]}"; do
        echo "    claude plugin install $plugin"
    done
    if [ "$INSTALL_ACADEMIC" = "1" ]; then
        for entry in "${ACADEMIC_MARKETPLACES[@]}"; do
            market="${entry%%:*}"; pkg="${entry##*:}"
            echo "    claude plugin marketplace add $market"
            echo "    claude plugin install $pkg"
        done
    fi
fi

# Add profile switcher to shell config
PROFILE_SOURCE='source ~/.claude/scripts/profile-switcher.sh'

if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "profile-switcher.sh" "$SHELL_CONFIG" 2>/dev/null; then
        echo ""
        echo "Adding profile switcher to $SHELL_CONFIG..."
        echo "" >> "$SHELL_CONFIG"
        echo "# Claude Code Profile Switcher" >> "$SHELL_CONFIG"
        echo "$PROFILE_SOURCE" >> "$SHELL_CONFIG"
        mark_ok "Profile switcher (added to $SHELL_CONFIG)"
    else
        mark_ok "Profile switcher (already configured)"
    fi
else
    echo ""
    echo "Could not detect shell config. Manually add to your shell config:"
    echo "  $PROFILE_SOURCE"
    mark_skipped "Profile switcher" "shell config not detected"
fi

echo ""
echo "========================================"
echo "Installation Summary"
echo "========================================"

# Print installed components
if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${C_GREEN}INSTALLED (${#INSTALLED[@]}):${C_RESET}"
    for item in "${INSTALLED[@]}"; do
        echo -e "    ${C_GREEN}[ok]${C_RESET} $item"
    done
fi

# Print skipped components
if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${C_YELLOW}SKIPPED (${#SKIPPED[@]}):${C_RESET}"
    for item in "${SKIPPED[@]}"; do
        echo -e "    ${C_YELLOW}[--]${C_RESET} $item"
    done
fi

# Print failed components
if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${C_RED}FAILED (${#FAILED[@]}):${C_RESET}"
    for i in "${!FAILED[@]}"; do
        echo -e "    ${C_RED}[!!]${C_RESET} ${FAILED[$i]}"
        if [ -n "${FIXES[$i]:-}" ]; then
            echo -e "         Fix: ${FIXES[$i]}"
        fi
    done
fi

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "========================================"
    echo -e "${C_RED}Completed with ${#FAILED[@]} failure(s). Review above.${C_RESET}"
    echo "========================================"
else
    echo "========================================"
    echo -e "${C_GREEN}All components installed successfully!${C_RESET}"
    echo "========================================"
fi

echo ""
echo "Restart your terminal or run:"
echo "  source $SHELL_CONFIG"
echo ""
echo "Available profiles:"
echo "  use-claude      - Anthropic Claude (default)"
echo "  use-openrouter  - OpenRouter (multi-model access)"
echo "  use-glm         - GLM (Zhipu AI)"
echo "  claude-profile  - Show current profile"
echo "  claude-profiles - List all profiles"
echo ""
echo "Available slash commands:"
echo "  /scan          - Generate project CLAUDE.md"
echo "  /prime         - Load project context"
echo "  /create-spec   - Interview, then write a technical specification"
echo ""
