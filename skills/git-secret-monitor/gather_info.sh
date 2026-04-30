#!/bin/bash

# Git Secret Monitor - Helper Script
# This script is designed to be called by the PicoClaw agent via the exec tool
# It gathers information about git repos and changed files, then outputs it
# for the agent to process with secret scanning tools

# Configuration
MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw/.picoclaw}"

# Output format: JSON-like for easy parsing
# We'll output repo info and file lists that the agent can process

echo "GIT_SECRET_MONITOR_START"

# Find all Git repositories in the monitor directory
while IFS= read -r -d '' git_dir; do
    repo_dir="$(dirname "$git_dir")"
    
    # Change to repository directory
    if cd "$repo_dir"; then
        # Get the current branch
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            continue
        fi
        
        # Get the latest commit hash
        latest_commit=$(git rev-parse HEAD 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            continue
        fi
        
        # Get files changed in the latest commit
        changed_files=$(git diff-tree --no-commit-id --name-only -r "$latest_commit" 2>/dev/null)
        
        if [[ -z "$changed_files" ]]; then
            cd - > /dev/null
            continue
        fi
        
        # Output repository information
        echo "REPO_START"
        echo "REPO_DIR:$repo_dir"
        echo "BRANCH:$current_branch"
        echo "COMMIT:$latest_commit"
        
        # Output each changed file
        echo "FILES_START"
        while IFS= read -r file; do
            if [[ -n "$file" && -f "$file" ]]; then
                echo "FILE:$file"
            fi
        done <<< "$changed_files"
        echo "FILES_END"
        
        echo "REPO_END"
        
        # Return to original directory
        cd - > /dev/null
    fi
done < <(find "$MONITOR_DIR" -type d -name ".git" -print0 2>/dev/null)

echo "GIT_SECRET_MONITOR_END"