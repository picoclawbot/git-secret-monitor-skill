#!/bin/bash

# Debug version of gather_info.sh

# Configuration
MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw/.picoclaw/test_monitor_repo}"

echo "GIT_SECRET_MONITOR_START"
echo "MONITOR_DIR is: $MONITOR_DIR"

# Find all Git repositories in the monitor directory
echo "Finding .git directories..."
git_dirs=$(find "$MONITOR_DIR" -type d -name ".git")
echo "Found git dirs: $git_dirs"

count=0
while IFS= read -r git_dir; do
    count=$((count + 1))
    echo "Processing git dir $count: $git_dir"
    repo_dir="$(dirname "$git_dir")"
    echo "Repo dir: $repo_dir"
    
    # Change to repository directory
    if cd "$repo_dir"; then
        echo "Changed to: $(pwd)"
        # Get the current branch
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "Branch: $current_branch"
        if [[ $? -ne 0 ]]; then
            echo "Skipping: Not a valid Git repository or HEAD unavailable"
            cd - > /dev/null
            continue
        fi
        
        # Get the latest commit hash
        latest_commit=$(git rev-parse HEAD 2>/dev/null)
        echo "Latest commit: $latest_commit"
        if [[ $? -ne 0 ]]; then
            echo "Skipping: Unable to get latest commit"
            cd - > /dev/null
            continue
        fi
        
        # Get files changed in the latest commit
        changed_files=$(git diff-tree --no-commit-id --name-only -r "$latest_commit" 2>/dev/null)
        echo "Changed files: $changed_files"
        
        if [[ -z "$changed_files" ]]; then
            echo "No files changed in latest commit"
            cd - > /dev/null
            continue
        fi
        
        echo "Found $(echo "$changed_files" | wc -l) changed files in latest commit"
        
        # Scan each changed file for secrets
        while IFS= read -r file; do
            if [[ -n "$file" && -f "$file" ]]; then
                echo "Scanning: $file"
            fi
        done <<< "$changed_files"
        
        # Return to original directory
        cd - > /dev/null
    else
        echo "Skipping: Cannot access directory $repo_dir"
    fi
done <<< "$git_dirs"

echo "GIT_SECRET_MONITOR_END"