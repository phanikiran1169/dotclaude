#!/bin/bash
# start-excalidraw.sh: Start the Excalidraw canvas server
# start-excalidraw.sh: Run before Claude Code to enable diagram tools

PORT=${1:-3000}
DIR="$HOME/.claude/mcp/mcp_excalidraw"

if [ ! -d "$DIR" ]; then
    echo "Excalidraw MCP not installed. Run setup-mcp.sh first."
    exit 1
fi

echo "Starting Excalidraw canvas on http://localhost:$PORT"
echo "Open this URL in your browser, then start Claude Code."
echo "Press Ctrl+C to stop."
cd "$DIR" && PORT=$PORT npm run canvas
