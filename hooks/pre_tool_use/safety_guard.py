#!/usr/bin/env python3
"""
Smart safety filter that blocks truly dangerous operations
while allowing everything else in dangerous mode
"""

import json
import sys
import re

DANGER_PATTERNS = [
    # Destructive file operations
    (r"rm\s+-rf\s+/(?:\s|$)", "Attempting to delete root filesystem"),
    (r"rm\s+-rf\s+~(?:/|$|\s)", "Attempting to delete home directory"),
    (r"rm\s+-rf\s+\.\.", "Attempting to delete parent directories"),
    (r"rm\s+-rf\s+\*", "Attempting to delete everything"),
    (r">\s*/dev/sd[a-z]", "Attempting to overwrite disk devices"),

    # Fork bombs and system killers
    (r":\(\)\s*{\s*:\|:&\s*}", "Fork bomb detected"),
    (r">\s*/dev/null\s*2>&1\s*&\s*while.*true", "Resource exhaustion attack"),

    # Credential exposure
    (r"cat\s+.*\.env(?:\s|$)", "Attempting to read .env file"),
    (r"echo.*(?:AWS_SECRET|API_KEY|PASSWORD)", "Attempting to echo secrets"),
    (r"curl.*(?:api_key|password|secret)=", "Attempting to send credentials"),
    (r"git\s+push.*--force.*(?:main|master)", "Force pushing to main branch"),

    # System modifications
    (r"chmod\s+777\s+/", "Making root world-writable"),
    (r"chown.*-R.*root\s+/", "Changing ownership to root recursively"),
    (r"mkfs\.", "Attempting to format filesystem"),

    # Network attacks
    (r"curl.*\|\s*(?:bash|sh)(?:\s|$)", "Curl pipe to shell detected"),
    (r"wget.*\|\s*(?:bash|sh)(?:\s|$)", "Wget pipe to shell detected"),
    (r"nc\s+-l.*-e\s*/bin/(?:bash|sh)", "Reverse shell detected"),
]

def check_safety(tool_use):
    """Check if the tool use is safe to execute"""
    try:
        if tool_use.get("tool") == "Bash":
            command = tool_use.get("input", {}).get("command", "")

            # Check against danger patterns
            for pattern, message in DANGER_PATTERNS:
                if re.search(pattern, command, re.IGNORECASE):
                    return {
                        "action": "block",
                        "message": f"🛡️ BLOCKED: {message}\nCommand: {command}"
                    }

        # Allow all other commands
        return {"action": "allow"}

    except Exception as e:
        # On error, block for safety
        return {
            "action": "block",
            "message": f"Safety check error: {str(e)}"
        }

def main():
    """Main entry point for the hook"""
    try:
        # Read tool use from stdin
        tool_use = json.load(sys.stdin)

        # Check safety
        result = check_safety(tool_use)

        # Output result
        print(json.dumps(result))

    except Exception as e:
        # On any error, block for safety
        print(json.dumps({
            "action": "block",
            "message": f"Hook error: {str(e)}"
        }))

if __name__ == "__main__":
    main()
