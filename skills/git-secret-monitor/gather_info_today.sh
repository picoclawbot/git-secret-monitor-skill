#!/bin/bash

# Git Secret Monitor - Helper Script for today's commits
# This script is designed to be called by the PicoClaw agent via the exec tool
# It gathers information about git repos and files changed in today's commits

# Configuration
MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw}"

# Output format: JSON-like for easy parsing
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
        
        # Check if there are any commits today
        todays_commits=$(git log --since="today 00:00" --until="now" --pretty=format:"%H" 2>/dev/null)
        if [[ -z "$todays_commits" ]]; then
            cd - > /dev/null
            continue
        fi
        
        # Get the list of files changed in today's commits (unique)
        changed_files=$(git log --since="today 00:00" --until="now" --name-only --pretty=format: 2>/dev/null | sort -u)
        
        if [[ -z "$changed_files" ]]; then
            cd - > /dev/null
            continue
        fi
        
        # Output repository information
        echo "REPO_START"
        echo "REPO_DIR:$repo_dir"
        echo "BRANCH:$current_branch"
        # We don't have a single commit, but we can list the first one or just note it's today's
        echo "COMMIT:TODAYS_COMMITS"
        
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