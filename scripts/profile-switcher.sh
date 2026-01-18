#!/bin/bash

# profile-switcher.sh: Claude Code Profile Switcher Functions
# profile-switcher.sh: Add these functions to your .zshrc or .bashrc to switch between providers

# Switch to Anthropic Claude (default)
use-claude() {
    cp ~/.claude/profiles/claude.json ~/.claude/settings.json 2>/dev/null
    echo "Switched to Anthropic Claude"
    echo "Launch with: claude"
}

# Switch to OpenRouter (400+ models)
use-openrouter() {
    if [ -f ~/.claude/profiles/openrouter.json ]; then
        cp ~/.claude/profiles/openrouter.json ~/.claude/settings.json
        echo "Switched to OpenRouter"
        echo ""
        echo "Popular Models:"
        echo "  Premium:  anthropic/claude-sonnet-4.5"
        echo "  Premium:  anthropic/claude-opus-4.5"
        echo "  Free:     xiaomi/mimo-v2-flash:free"
        echo ""
        echo "Launch with: claude"
    else
        if [ -f ~/.claude/profiles/openrouter.json.template ]; then
            echo "Auto-creating openrouter.json from template..."
            cp ~/.claude/profiles/openrouter.json.template ~/.claude/profiles/openrouter.json
            echo ""
            echo "IMPORTANT: Add your OpenRouter API key to:"
            echo "  ~/.claude/profiles/openrouter.json"
            echo ""
            echo "Find 'YOUR_API_KEY_HERE' and replace with your actual key."
            echo "Then run 'use-openrouter' again."
        else
            echo "ERROR: OpenRouter template not found."
            echo "Expected: ~/.claude/profiles/openrouter.json.template"
        fi
    fi
}

# Switch to GLM (Zhipu AI)
use-glm() {
    if [ -f ~/.claude/profiles/glm.json ]; then
        cp ~/.claude/profiles/glm.json ~/.claude/settings.json
        echo "Switched to GLM (Zhipu AI)"
        echo "Models: Haiku=GLM-4.5-Air, Sonnet/Opus=GLM-4.7"
        echo "Launch with: claude"
    else
        if [ -f ~/.claude/profiles/glm.json.template ]; then
            echo "Auto-creating glm.json from template..."
            cp ~/.claude/profiles/glm.json.template ~/.claude/profiles/glm.json
            echo ""
            echo "IMPORTANT: Add your GLM API key to:"
            echo "  ~/.claude/profiles/glm.json"
            echo ""
            echo "Find 'YOUR_API_KEY_HERE' and replace with your actual key."
            echo "Then run 'use-glm' again."
        else
            echo "ERROR: GLM template not found."
            echo "Expected: ~/.claude/profiles/glm.json.template"
        fi
    fi
}

# Check current profile
claude-profile() {
    if grep -q "openrouter.ai/api" ~/.claude/settings.json 2>/dev/null; then
        echo "Current: OpenRouter"
    elif grep -q "api.z.ai" ~/.claude/settings.json 2>/dev/null; then
        echo "Current: GLM (Zhipu AI)"
    else
        echo "Current: Anthropic Claude (default)"
    fi
}

# List available profiles
claude-profiles() {
    echo "Available Profiles:"
    echo "  use-claude      - Anthropic Claude (default)"
    echo "  use-openrouter  - OpenRouter (400+ models)"
    echo "  use-glm         - GLM (Zhipu AI)"
    echo ""
    echo "Commands:"
    echo "  claude-profile  - Show current profile"
    echo "  claude-reset    - Reset to Anthropic Claude"
}

# Reset to default Anthropic Claude
claude-reset() {
    use-claude
    echo "Environment reset to Anthropic defaults"
}
