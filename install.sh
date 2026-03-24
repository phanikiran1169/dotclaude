#!/bin/bash

# install.sh: Claude Code Configuration Installer
# install.sh: Installs hooks, commands, settings, and statusline to ~/.claude

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing Claude Code Configuration..."
echo "========================================"
echo ""

# Detect shell config file
SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
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
        # Deep merge: repo settings override existing, but existing-only keys are preserved
        jq -s '.[0] * .[1]' "$CLAUDE_DIR/settings.json" "$SCRIPT_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp"
        mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
        echo "Merged settings.json (old version backed up)"
    else
        cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
        echo "Updated settings.json (old version backed up, install jq for merge support)"
    fi
else
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
fi

# Copy CLAUDE.md
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo "Installing CLAUDE.md..."
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
else
    echo "CLAUDE.md exists, creating backup..."
    cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "Updated CLAUDE.md (old version backed up)"
fi

# Copy hooks
echo "Installing safety hooks..."
cp "$SCRIPT_DIR/hooks/pre_tool_use/"*.py "$CLAUDE_DIR/hooks/pre_tool_use/" 2>/dev/null || true

# Make hooks executable
chmod +x "$CLAUDE_DIR/hooks/pre_tool_use/"*.py 2>/dev/null || true

# Copy statusline script
echo "Installing statusline script..."
cp "$SCRIPT_DIR/statusline-script.sh" "$CLAUDE_DIR/statusline-script.sh"
chmod +x "$CLAUDE_DIR/statusline-script.sh"

# Copy commands
echo "Installing commands..."
cp "$SCRIPT_DIR/commands/"*.md "$CLAUDE_DIR/commands/" 2>/dev/null || true

# Copy profiles
echo "Installing profiles..."
cp "$SCRIPT_DIR/profiles/"*.json "$CLAUDE_DIR/profiles/" 2>/dev/null || true
cp "$SCRIPT_DIR/profiles/"*.template "$CLAUDE_DIR/profiles/" 2>/dev/null || true

# Copy scripts
echo "Installing scripts..."
cp "$SCRIPT_DIR/scripts/"*.sh "$CLAUDE_DIR/scripts/" 2>/dev/null || true
chmod +x "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null || true

# Install skills
echo "Installing skills..."
if [ -d "$SCRIPT_DIR/skills" ]; then
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        echo "  Installing skill: $skill_name"
        mkdir -p "$CLAUDE_DIR/skills/$skill_name"
        cp -r "$skill_dir"* "$CLAUDE_DIR/skills/$skill_name/"
    done
fi

# Install marketplace plugins
echo ""
echo "Installing recommended plugins..."
PLUGINS=("context7" "code-simplifier" "superpowers" "claude-md-management" "skill-creator")

if command -v claude &> /dev/null; then
    for plugin in "${PLUGINS[@]}"; do
        echo "  Installing $plugin..."
        claude plugin install "$plugin" 2>/dev/null || echo "    (already installed or unavailable)"
    done
    echo "Plugins installation complete"
else
    echo "Claude CLI not found. Skipping plugin installation."
    echo "Install plugins manually after installing Claude CLI:"
    for plugin in "${PLUGINS[@]}"; do
        echo "  claude plugin install $plugin"
    done
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
        echo "Profile switcher added to $SHELL_CONFIG"
    else
        echo "Profile switcher already in $SHELL_CONFIG"
    fi
else
    echo ""
    echo "Could not detect shell config. Manually add to your shell config:"
    echo "  $PROFILE_SOURCE"
fi

echo ""
echo "========================================"
echo "Installation complete!"
echo "========================================"
echo ""
echo "Installed components:"
echo "  - CLAUDE.md: Development guidelines"
echo "  - settings.json: Core configuration"
echo "  - Safety hooks: Pre-tool-use validation"
echo "  - StatusLine: Enhanced status bar"
echo "  - Commands: /scan, /plan, /prime"
echo "  - Profiles: claude, openrouter, glm"
echo "  - Skills: decode-ai-paper, humanizer"
echo "  - Profile switcher: Shell functions"
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
echo "To setup a provider:"
echo "  1. Copy template: cp ~/.claude/profiles/openrouter.json.template ~/.claude/profiles/openrouter.json"
echo "  2. Edit and add your API key"
echo "  3. Switch: use-openrouter"
echo ""
echo "Available slash commands:"
echo "  /scan          - Generate project CLAUDE.md"
echo "  /plan          - Create implementation plans"
echo "  /prime         - Load project context"
echo ""
echo "Available skills (auto-trigger from context):"
echo "  decode-ai-paper   - Decode research papers for implementation"
echo "  humanizer      - Remove AI writing patterns from text"
echo ""
