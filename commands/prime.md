---
allowed-tools: Bash, Read
description: Load context for a new agent session by analyzing codebase structure, README, and recent git history. Optional argument: path to specifications and documentation directory.
---

# Prime

This command loads essential context for a new agent session by examining the codebase structure, reading the project README, and understanding recent changes through git history. You must only Read and Understand the code base and nothing else.

If an argument is provided ($1), it should be a path to specifications and documentation directory for the project/feature being developed.

IMPORTANT: NO WRITING CODE

## Instructions
- Run `git ls-files` to understand the codebase structure and file organization
- Analyze recent git history to understand what's been changing
- Read the README.md to understand the project purpose, setup instructions, and key information
- Provide a concise overview of the project based on the gathered context

## Context
- Codebase structure git accessible: !`if git rev-parse --git-dir > /dev/null 2>&1; then git ls-files; else echo "Not a git repository - skipping git ls-files"; fi`
- Recent commits (last 10): !`if git rev-parse --git-dir > /dev/null 2>&1; then git log --oneline -n 10; else echo "Not a git repository - no commit history available"; fi`
- Files changed recently: !`if git rev-parse --git-dir > /dev/null 2>&1; then git diff --name-status HEAD~5..HEAD 2>/dev/null || git diff --name-status $(git rev-list --max-parents=0 HEAD)..HEAD; else echo "Not a git repository - no change history available"; fi`
- Summary of recent changes: !`if git rev-parse --git-dir > /dev/null 2>&1; then git diff --stat HEAD~5..HEAD 2>/dev/null || git diff --stat $(git rev-list --max-parents=0 HEAD)..HEAD; else echo "Not a git repository - no change summary available"; fi`
- Project README: @README.md
- Current Status: @CLAUDE.md
- Specification files: !`if [ -n "$1" ] && [ -d "$1" ]; then find "$1" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.rst" \) | head -5; else echo "No spec path provided"; fi`