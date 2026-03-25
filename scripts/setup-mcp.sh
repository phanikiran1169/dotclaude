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

    if ! command_exists claude; then
        echo -e "${RED}Claude Code not found${NC}"
        missing=1
    else
        echo -e "${GREEN}Claude Code found${NC}"
    fi

    if [ "$missing" -eq 1 ]; then
        echo -e "${RED}Missing prerequisites. Install them first.${NC}"
        exit 1
    fi
    echo ""
}

# Install uv if missing
ensure_uv() {
    if command_exists uv; then
        echo -e "${GREEN}uv $(uv --version | cut -d' ' -f2) found${NC}"
        return 0
    fi

    echo -e "${YELLOW}uv not found. Installing...${NC}"
    case "$PLATFORM" in
        macos)
            if command_exists brew; then
                brew install uv
            else
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
            ;;
        ubuntu)
            curl -LsSf https://astral.sh/uv/install.sh | sh
            ;;
        *)
            echo -e "${RED}Unsupported platform. Install uv manually:${NC}"
            echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
            return 1
            ;;
    esac

    export PATH="$HOME/.local/bin:$PATH"

    if command_exists uv; then
        echo -e "${GREEN}uv installed${NC}"
    else
        echo -e "${RED}uv installation failed. Install manually and re-run.${NC}"
        return 1
    fi
}

# Setup PAL MCP
setup_pal() {
    ensure_uv || exit 1

    # Clone or update
    if [ -d "$PAL_DIR" ]; then
        echo -e "${GRAY}PAL repo exists, pulling latest...${NC}"
        git -C "$PAL_DIR" pull --quiet 2>/dev/null || \
            echo -e "${YELLOW}Pull failed, continuing with existing version${NC}"
    else
        echo -e "${GRAY}Cloning PAL MCP server...${NC}"
        mkdir -p "$MCP_DIR"
        git clone https://github.com/BeehiveInnovations/pal-mcp-server.git "$PAL_DIR"
    fi

    # Create .env if missing
    if [ ! -f "$PAL_DIR/.env" ]; then
        cp "$PAL_DIR/.env.example" "$PAL_DIR/.env"
        echo -e "${YELLOW}Created .env from example${NC}"
    fi

    # Run PAL setup
    echo -e "${GRAY}Running PAL setup...${NC}"
    cd "$PAL_DIR"
    /bin/bash run-server.sh 2>&1 | tail -20
    cd - >/dev/null

    # Register with Claude Code
    local venv_python="$PAL_DIR/.pal_venv/bin/python"
    if [ -f "$venv_python" ]; then
        claude mcp add -s user pal -- "$venv_python" "$PAL_DIR/server.py" 2>/dev/null && \
            echo -e "${GREEN}PAL MCP registered with Claude Code${NC}" || \
            echo -e "${YELLOW}PAL MCP already registered${NC}"
    else
        echo -e "${RED}PAL venv not found at $venv_python${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}PAL MCP setup complete${NC}"
    echo ""
    echo -e "${YELLOW}Next: add your API keys to $PAL_DIR/.env${NC}"
    echo -e "${GRAY}  GEMINI_API_KEY=your-key${NC}"
    echo -e "${GRAY}  OPENAI_API_KEY=your-key${NC}"
    echo ""
    echo -e "${GRAY}Then restart Claude Code to activate.${NC}"
}

# Main
main() {
    check_prerequisites
    setup_pal
}

main "$@"
