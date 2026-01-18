#!/usr/bin/env python3
"""
Context Validator Hook for Claude Code
Validates tool usage context to ensure appropriate tool selection and usage patterns.
"""

import json
import sys
import os
from pathlib import Path

def validate_context(tool_data):
    """
    Validate the context of tool usage to ensure appropriate patterns.

    Args:
        tool_data: Dictionary containing tool invocation information

    Returns:
        dict: Response with action and optional message
    """
    tool_name = tool_data.get('tool_name', '')
    parameters = tool_data.get('parameters', {})

    # File operation context validation
    if tool_name in ['Read', 'Write', 'Edit', 'MultiEdit']:
        file_path = parameters.get('file_path', '')

        # Validate file path is absolute
        if file_path and not os.path.isabs(file_path):
            return {
                "action": "block",
                "message": f"File path must be absolute, got: {file_path}"
            }

        # Warn about editing system files
        sensitive_paths = ['/etc/', '/usr/bin/', '/usr/sbin/', '/bin/', '/sbin/']
        if any(file_path.startswith(path) for path in sensitive_paths):
            return {
                "action": "block",
                "message": f"Blocked editing system file: {file_path}"
            }

    # Bash command context validation
    if tool_name == 'Bash':
        command = parameters.get('command', '')

        # Check for potentially problematic command patterns
        problematic_patterns = [
            'sudo su',
            'chmod 777',
            'chown root',
            'dd if=/dev/zero',
            'mkfs.',
            'fdisk',
            'parted'
        ]

        for pattern in problematic_patterns:
            if pattern in command:
                return {
                    "action": "block",
                    "message": f"Blocked potentially dangerous command pattern: {pattern}"
                }

    # Validate Write operations don't overwrite important files
    if tool_name == 'Write':
        file_path = parameters.get('file_path', '')
        important_files = [
            '/etc/passwd',
            '/etc/shadow',
            '/etc/hosts',
            '/etc/fstab',
            '~/.ssh/authorized_keys',
            '~/.bashrc',
            '~/.zshrc'
        ]

        expanded_path = os.path.expanduser(file_path)
        if expanded_path in important_files:
            return {
                "action": "block",
                "message": f"Blocked overwriting important system file: {file_path}"
            }

    # All validations passed
    return {"action": "allow"}

def main():
    """Main entry point for the context validator hook."""
    try:
        # Read input from stdin
        input_data = sys.stdin.read()
        if not input_data.strip():
            print(json.dumps({"action": "allow"}))
            return

        # Parse JSON input
        tool_data = json.loads(input_data)

        # Validate context
        response = validate_context(tool_data)

        # Output response
        print(json.dumps(response))

    except json.JSONDecodeError:
        # Invalid JSON input - allow by default
        print(json.dumps({"action": "allow"}))
    except Exception as e:
        # Any other error - allow by default but log
        print(json.dumps({
            "action": "allow",
            "message": f"Context validator error: {str(e)}"
        }))

if __name__ == "__main__":
    main()
