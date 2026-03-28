#!/usr/bin/env python3
# safety_guard.py: Blocks truly dangerous shell operations
# safety_guard.py: PreToolUse hook for the Bash tool

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
    try:
        if tool_use.get("tool_name") == "Bash":
            command = tool_use.get("tool_input", {}).get("command", "")

            for pattern, message in DANGER_PATTERNS:
                if re.search(pattern, command, re.IGNORECASE):
                    return {
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "deny",
                            "permissionDecisionReason": f"BLOCKED: {message}"
                        }
                    }

        return {}

    except Exception:
        return {}


def main():
    try:
        tool_use = json.load(sys.stdin)
        result = check_safety(tool_use)

        if result:
            print(json.dumps(result))
            if "hookSpecificOutput" in result:
                sys.exit(2)

    except Exception:
        sys.exit(0)


if __name__ == "__main__":
    main()
