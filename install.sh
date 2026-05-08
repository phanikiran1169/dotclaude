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
mkdir -p "$CLAUDE_DIR"/{hooks/pre_tool_use,commands,profiles,scripts,skills}

# Merge settings (preserves existing keys like enabledPlugins while updating ours)
echo "Installing settings.json..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.backup"
    if command -v jq &>/dev/null; then
        if jq -s '.[0] * .[1]' "$CLAUDE_DIR/settings.json" "$SCRIPT_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp"; then
            mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
            echo "  Merged settings.json (old version backed up)"
            mark_ok "settings.json (merged)"
        else
            rm -f "$CLAUDE_DIR/settings.json.tmp"
            mark_failed "settings.json" "jq merge failed" "brew install jq && re-run install.sh"
        fi
    else
        cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
        echo "  Updated settings.json (old version backed up, install jq for merge support)"
        mark_ok "settings.json (overwritten, no jq)"
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
    cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "  Updated CLAUDE.md (old version backed up)"
    mark_ok "CLAUDE.md (updated)"
fi

# Copy hooks
echo "Installing safety hooks..."
HOOKS_COPIED=0
cp "$SCRIPT_DIR/hooks/pre_tool_use/"*.js "$CLAUDE_DIR/hooks/pre_tool_use/" 2>/dev/null && HOOKS_COPIED=1
cp "$SCRIPT_DIR/hooks/pre_tool_use/"*.py "$CLAUDE_DIR/hooks/pre_tool_use/" 2>/dev/null && HOOKS_COPIED=1
if [ "$HOOKS_COPIED" -eq 1 ]; then
    mark_ok "Safety hooks"
else
    mark_failed "Safety hooks" "no hook files found in repo" "check that hooks/pre_tool_use/ has .js or .py files"
fi

# Copy statusline script
echo "Installing statusline script..."
if [ -f "$SCRIPT_DIR/statusline-script.sh" ]; then
    cp "$SCRIPT_DIR/statusline-script.sh" "$CLAUDE_DIR/statusline-script.sh"
    chmod +x "$CLAUDE_DIR/statusline-script.sh"
    mark_ok "Statusline script"
else
    mark_failed "Statusline script" "source file not found" "ensure statusline-script.sh exists in the repo root"
fi

# Copy commands
echo "Installing commands..."
if ls "$SCRIPT_DIR/commands/"*.md &>/dev/null; then
    cp "$SCRIPT_DIR/commands/"*.md "$CLAUDE_DIR/commands/"
    mark_ok "Commands"
else
    mark_skipped "Commands" "no .md files in commands/"
fi

# Copy profiles
echo "Installing profiles..."
PROFILES_COPIED=0
cp "$SCRIPT_DIR/profiles/"*.json "$CLAUDE_DIR/profiles/" 2>/dev/null && PROFILES_COPIED=1
cp "$SCRIPT_DIR/profiles/"*.template "$CLAUDE_DIR/profiles/" 2>/dev/null && PROFILES_COPIED=1
if [ "$PROFILES_COPIED" -eq 1 ]; then
    mark_ok "Profiles"
else
    mark_skipped "Profiles" "no profile files found"
fi

# Copy scripts
echo "Installing scripts..."
if ls "$SCRIPT_DIR/scripts/"*.sh &>/dev/null; then
    cp "$SCRIPT_DIR/scripts/"*.sh "$CLAUDE_DIR/scripts/"
    chmod +x "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null || true
    mark_ok "Scripts"
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
if [ "$SKILLS_COUNT" -gt 0 ]; then
    mark_ok "Skills ($SKILLS_COUNT installed)"
else
    mark_skipped "Skills" "no skill directories found"
fi

# Ensure npm global bin is on PATH
NPM_GLOBAL_BIN="$(npm config get prefix 2>/dev/null)/bin"
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

    echo "  Installing codex plugin..."
    if claude plugin install "codex@openai-codex" 2>/dev/null; then
        mark_ok "Plugin: codex"
    else
        mark_skipped "Plugin: codex" "already installed or unavailable"
    fi

    for plugin in "${PLUGINS[@]}"; do
        echo "  Installing $plugin..."
        if claude plugin install "$plugin" 2>/dev/null; then
            mark_ok "Plugin: $plugin"
        else
            mark_skipped "Plugin: $plugin" "already installed or unavailable"
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
echo "  /plan          - Create implementation plans"
echo "  /prime         - Load project context"
echo ""
