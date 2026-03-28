#!/bin/bash
# setup-mcp.sh: MCP server setup for Claude Code
# setup-mcp.sh: Installs PAL/Zen MCP server to ~/.claude/mcp/

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
MCP_DIR="$CLAUDE_DIR/mcp"
PAL_DIR="$MCP_DIR/pal-mcp-server"
PAL_VENV="$PAL_DIR/.pal_venv"
MCP_JSON="$CLAUDE_DIR/.mcp.json"

echo -e "${BLUE}PAL MCP Server Setup (formerly Zen)${NC}"
echo "===================================="
echo ""

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian) echo "ubuntu" ;;
                    *) echo "linux" ;;
                esac
            else
                echo "linux"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM=$(detect_platform)

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Find a working python >= 3.10
find_python() {
    for py in python3.12 python3.11 python3.10 python3; do
        if command_exists "$py"; then
            local ver
            ver=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            local major minor
            major=$(echo "$ver" | cut -d. -f1)
            minor=$(echo "$ver" | cut -d. -f2)
            if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
                echo "$py"
                return 0
            fi
        fi
    done
    return 1
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    local missing=0

    if ! command_exists git; then
        echo -e "${RED}git not found${NC}"
        missing=1
    else
        echo -e "${GREEN}git $(git --version | cut -d' ' -f3)${NC}"
    fi

    local py
    py=$(find_python) || true
    if [ -z "$py" ]; then
        echo -e "${RED}Python >= 3.10 not found${NC}"
        missing=1
    else
        echo -e "${GREEN}$py ($($py --version))${NC}"
    fi

    if [ "$missing" -eq 1 ]; then
        echo -e "${RED}Missing prerequisites. Install them first.${NC}"
        exit 1
    fi
    echo ""
}

# Clone or update PAL repo
clone_or_update_pal() {
    if [ -d "$PAL_DIR" ]; then
        echo -e "${GRAY}PAL repo exists, pulling latest...${NC}"
        git -C "$PAL_DIR" pull --quiet 2>/dev/null || \
            echo -e "${YELLOW}Pull failed, continuing with existing version${NC}"
    else
        echo -e "${GRAY}Cloning PAL MCP server...${NC}"
        mkdir -p "$MCP_DIR"
        git clone https://github.com/BeehiveInnovations/pal-mcp-server.git "$PAL_DIR"
    fi
}

# Create or repair the venv
# PAL's run-server.sh often fails (broken symlinks, platform issues).
# This function tries run-server.sh first, then falls back to manual
# venv creation with pip install from requirements.txt.
setup_venv() {
    local py
    py=$(find_python)

    # Check if existing venv works
    if [ -f "$PAL_VENV/bin/python" ] && "$PAL_VENV/bin/python" -c "import mcp" 2>/dev/null; then
        echo -e "${GREEN}Existing venv is functional${NC}"
        return 0
    fi

    # Try PAL's own setup first
    echo -e "${GRAY}Trying PAL run-server.sh...${NC}"
    if (cd "$PAL_DIR" && /bin/bash run-server.sh 2>&1 | tail -5) && \
       [ -f "$PAL_VENV/bin/python" ] && \
       "$PAL_VENV/bin/python" -c "import mcp" 2>/dev/null; then
        echo -e "${GREEN}PAL setup succeeded${NC}"
        return 0
    fi

    # Fallback: manual venv creation
    echo -e "${YELLOW}PAL setup failed or venv broken. Rebuilding manually...${NC}"
    rm -rf "$PAL_VENV"
    "$py" -m venv "$PAL_VENV"
    "$PAL_VENV/bin/pip" install --quiet --upgrade pip
    "$PAL_VENV/bin/pip" install --quiet -r "$PAL_DIR/requirements.txt"

    # Verify
    if "$PAL_VENV/bin/python" -c "import mcp" 2>/dev/null; then
        echo -e "${GREEN}Manual venv setup succeeded${NC}"
    else
        echo -e "${RED}Venv setup failed. Check $PAL_DIR/requirements.txt${NC}"
        exit 1
    fi
}

# Create .env if missing
setup_env() {
    if [ ! -f "$PAL_DIR/.env" ]; then
        if [ -f "$PAL_DIR/.env.example" ]; then
            cp "$PAL_DIR/.env.example" "$PAL_DIR/.env"
            echo -e "${YELLOW}Created .env from example${NC}"
        else
            touch "$PAL_DIR/.env"
            echo -e "${YELLOW}Created empty .env${NC}"
        fi
    else
        echo -e "${GRAY}.env already exists${NC}"
    fi
}

# Register PAL in ~/.claude/.mcp.json (user-level, all projects)
# Using .mcp.json directly is more reliable than `claude mcp add`.
register_mcp() {
    local venv_python="$PAL_VENV/bin/python"
    local server_py="$PAL_DIR/server.py"

    if [ ! -f "$venv_python" ]; then
        echo -e "${RED}Venv python not found at $venv_python${NC}"
        exit 1
    fi

    # Build the config
    local config
    config=$(cat <<EOF
{
  "mcpServers": {
    "pal": {
      "command": "$venv_python",
      "args": ["$server_py"],
      "cwd": "$PAL_DIR"
    }
  }
}
EOF
)

    if [ -f "$MCP_JSON" ]; then
        # Check if pal is already registered
        if python3 -c "
import json, sys
with open('$MCP_JSON') as f:
    d = json.load(f)
if 'pal' in d.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            echo -e "${GRAY}PAL already registered in $MCP_JSON${NC}"
            # Update paths in case they changed
            python3 -c "
import json
with open('$MCP_JSON') as f:
    d = json.load(f)
d['mcpServers']['pal'] = {
    'command': '$venv_python',
    'args': ['$server_py'],
    'cwd': '$PAL_DIR'
}
with open('$MCP_JSON', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
" 2>/dev/null
            echo -e "${GREEN}PAL paths updated${NC}"
        else
            # Merge into existing config
            python3 -c "
import json
with open('$MCP_JSON') as f:
    d = json.load(f)
d.setdefault('mcpServers', {})['pal'] = {
    'command': '$venv_python',
    'args': ['$server_py'],
    'cwd': '$PAL_DIR'
}
with open('$MCP_JSON', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
" 2>/dev/null
            echo -e "${GREEN}PAL added to existing $MCP_JSON${NC}"
        fi
    else
        echo "$config" > "$MCP_JSON"
        echo -e "${GREEN}Created $MCP_JSON with PAL config${NC}"
    fi
}

# Verify server can start
verify_server() {
    echo -e "${GRAY}Verifying PAL server...${NC}"
    local output
    output=$("$PAL_VENV/bin/python" -c "
import sys
sys.path.insert(0, '$PAL_DIR')
import server
print('OK')
" 2>&1)

    if echo "$output" | grep -q "OK"; then
        echo -e "${GREEN}PAL server verified${NC}"
    else
        echo -e "${RED}PAL server failed to import:${NC}"
        echo "$output" | tail -5
        exit 1
    fi
}

# Main
main() {
    check_prerequisites
    clone_or_update_pal
    setup_env
    setup_venv
    register_mcp
    verify_server

    echo ""
    echo -e "${GREEN}PAL MCP setup complete${NC}"
    echo ""

    # Check for API keys
    local has_keys=0
    if grep -q "GEMINI_API_KEY=.\+" "$PAL_DIR/.env" 2>/dev/null; then
        echo -e "${GREEN}  GEMINI_API_KEY configured${NC}"
        has_keys=1
    fi
    if grep -q "OPENROUTER_API_KEY=.\+" "$PAL_DIR/.env" 2>/dev/null; then
        echo -e "${GREEN}  OPENROUTER_API_KEY configured${NC}"
        has_keys=1
    fi
    if grep -q "OPENAI_API_KEY=.\+" "$PAL_DIR/.env" 2>/dev/null; then
        echo -e "${GREEN}  OPENAI_API_KEY configured${NC}"
        has_keys=1
    fi

    if [ "$has_keys" -eq 0 ]; then
        echo -e "${YELLOW}No API keys found. Add at least one to $PAL_DIR/.env:${NC}"
        echo -e "${GRAY}  GEMINI_API_KEY=your-key${NC}"
        echo -e "${GRAY}  OPENROUTER_API_KEY=your-key  (for GPT, Grok, etc.)${NC}"
        echo -e "${GRAY}  OPENAI_API_KEY=your-key${NC}"
    fi

    echo ""
    echo -e "${GRAY}Restart Claude Code to activate PAL MCP.${NC}"
}

main "$@"
