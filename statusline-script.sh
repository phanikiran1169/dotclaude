#!/bin/bash

# statusline-script.sh: Statusline showing model, project, branch, context usage, tokens, cost, and time
# statusline-script.sh: Parses Claude Code JSON input via jq for reliable field extraction

# Read Claude Code JSON input
input=$(cat)

# Check for jq availability
if ! command -v jq &>/dev/null; then
    # Fallback: minimal statusline without JSON parsing
    project_name=$(basename "$PWD")
    printf "%s | no jq" "$project_name"
    exit 0
fi

# Extract fields via jq
model_info=$(echo "$input" | jq -r '.model.display_name // .model.id // "Unknown"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Extract project name from current directory
project_name=$(basename "$PWD")

# Git branch
if git rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
    [ -z "$git_branch" ] && git_branch="detached"
else
    git_branch="no-git"
fi

# Current time
current_time=$(date '+%H:%M')

# Build context bar (10 chars wide) from used_percentage
if [ -n "$used_pct" ]; then
    # Round to nearest integer for bar calculation
    pct_int=$(printf '%.0f' "$used_pct")
    filled=$(( pct_int / 10 ))
    empty=$(( 10 - filled ))
    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    context_segment="${bar} ${pct_int}%"
else
    context_segment="░░░░░░░░░░ --%"
fi

# Format token counts (e.g., 125000 → 125K)
format_tokens() {
    local count="$1"
    if [ -z "$count" ]; then
        echo "—"
        return
    fi
    if [ "$count" -ge 1000000 ] 2>/dev/null; then
        printf "%.1fM" "$(echo "$count / 1000000" | bc -l)"
    elif [ "$count" -ge 1000 ] 2>/dev/null; then
        printf "%.0fK" "$(echo "$count / 1000" | bc -l)"
    else
        echo "$count"
    fi
}

in_fmt=$(format_tokens "$total_in")
out_fmt=$(format_tokens "$total_out")
token_segment="${in_fmt}/${out_fmt}"

# Format cost
if [ -n "$cost_usd" ]; then
    cost_segment=$(printf '$%.2f' "$cost_usd")
else
    cost_segment='$—'
fi

# Shorten model name for compactness
short_model="$model_info"
case "$model_info" in
    *Opus*)   short_model="Opus" ;;
    *Sonnet*) short_model="Sonnet" ;;
    *Haiku*)  short_model="Haiku" ;;
esac

# Single-line statusline
printf "[%s] %s | %s | %s | %s | %s | %s" \
    "$short_model" \
    "$project_name" \
    "$git_branch" \
    "$context_segment" \
    "$token_segment" \
    "$cost_segment" \
    "$current_time"
