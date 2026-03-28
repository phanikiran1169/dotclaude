#!/usr/bin/env python3
# context_validator.py: Validates tool usage context to block access to secrets and system files
# context_validator.py: PreToolUse hook for Read, Write, Edit, and Bash tools

import json
import sys
import os


def make_block(reason):
    """Return a properly formatted PreToolUse block response."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason
        }
    }


def make_allow():
    """Return empty dict to allow (exit code 0 = allow)."""
    return {}


def validate_context(tool_data):
    tool_name = tool_data.get('tool_name', '')
    parameters = tool_data.get('tool_input', {})

    # File operation context validation
    if tool_name in ['Read', 'Write', 'Edit', 'MultiEdit']:
        file_path = parameters.get('file_path', '')

        # Validate file path is absolute
        if file_path and not os.path.isabs(file_path):
            return make_block(f"File path must be absolute, got: {file_path}")

        # Block access to files that contain secrets
        secret_patterns = [
            '.env', '.env.local', '.env.production', '.env.staging',
            'credentials.json', 'credentials.yaml',
            'secrets.json', 'secrets.yaml',
            '.netrc', '.npmrc',
            'service-account.json',
        ]
        filename = os.path.basename(file_path)
        if filename in secret_patterns:
            return make_block(f"Blocked access to secrets file: {file_path}")

        # Block files in common secret directories
        secret_dirs = ['/.ssh/', '/.gnupg/', '/.aws/']
        if any(d in file_path for d in secret_dirs):
            return make_block(f"Blocked access to sensitive directory: {file_path}")

        # Block editing system files
        sensitive_paths = ['/etc/', '/usr/bin/', '/usr/sbin/', '/bin/', '/sbin/']
        if any(file_path.startswith(path) for path in sensitive_paths):
            return make_block(f"Blocked access to system file: {file_path}")

    # Bash command context validation
    if tool_name == 'Bash':
        command = parameters.get('command', '')
        problematic_patterns = [
            'sudo su', 'chmod 777', 'chown root',
            'dd if=/dev/zero', 'mkfs.', 'fdisk', 'parted'
        ]
        for pattern in problematic_patterns:
            if pattern in command:
                return make_block(f"Blocked dangerous command pattern: {pattern}")

    # Validate Write operations don't overwrite important files
    if tool_name == 'Write':
        file_path = parameters.get('file_path', '')
        important_files = [
            '/etc/passwd', '/etc/shadow', '/etc/hosts', '/etc/fstab',
            '~/.ssh/authorized_keys', '~/.bashrc', '~/.zshrc'
        ]
        expanded_path = os.path.expanduser(file_path)
        if expanded_path in important_files:
            return make_block(f"Blocked overwriting important file: {file_path}")

    return make_allow()


def main():
    try:
        input_data = sys.stdin.read()
        if not input_data.strip():
            sys.exit(0)

        tool_data = json.loads(input_data)
        response = validate_context(tool_data)

        if response:
            print(json.dumps(response))
            # Exit code 2 = block
            if "hookSpecificOutput" in response:
                sys.exit(2)

    except json.JSONDecodeError:
        sys.exit(0)
    except Exception:
        sys.exit(0)


if __name__ == "__main__":
    main()
