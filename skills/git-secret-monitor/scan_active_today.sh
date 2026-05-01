#!/bin/bash

# Git Secret Monitor - Scan today's commits in active repos for secrets
# Active repos: those with at least one commit in the last 30 days
# Then scan files changed in today's commits in those active repos.

# Configuration
MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw}"
ACTIVE_DAYS=30

# Output format: We'll output findings directly, and also a summary
echo "GIT_SECRET_MONITOR_ACTIVE_TODAY_START"

# Find all Git repositories in the monitor directory
while IFS= read -r -d '' git_dir; do
    repo_dir="$(dirname "$git_dir")"
    
    # Change to repository directory
    if cd "$repo_dir"; then
        # Check if there is any commit in the last $ACTIVE_DAYS days
        recent_commit=$(git log --since="${ACTIVE_DAYS} days ago" --until="now" --pretty=format:"%H" -1 2>/dev/null)
        if [[ -z "$recent_commit" ]]; then
            # Not active in the last $ACTIVE_DAYS days, skip
            cd - > /dev/null
            continue
        fi
        
        # Repo is active, now check for today's commits
        todays_commits=$(git log --since="today 00:00" --until="now" --pretty=format:"%H" 2>/dev/null)
        if [[ -z "$todays_commits" ]]; then
            # No commits today, skip
            cd - > /dev/null
            continue
        fi
        
        # Get the list of files changed in today's commits (unique)
        changed_files=$(git log --since="today 00:00" --until="now" --name-only --pretty=format: 2>/dev/null | sort -u)
        
        if [[ -z "$changed_files" ]]; then
            cd - > /dev/null
            continue
        fi
        
        # Output repository header
        echo "REPO_START:$repo_dir"
        
        # Process each changed file
        while IFS= read -r file; do
            if [[ -n "$file" && -f "$file" ]]; then
                # Scan the file for secrets
                # We'll use the secret scanner tool via the agent, but since we are in a script,
                # we cannot directly call the MCP tool. Instead, we'll output the file path
                # and let the agent process it. However, we are in a script that is called by the agent via exec.
                # The agent can then parse this output and call the secret scanner for each file.
                # So we'll output the file path in a way that the agent can parse.
                echo "FILE_TO_SCAN:$file"
            fi
        done <<< "$changed_files"
        
        echo "REPO_END:$repo_dir"
        
        # Return to original directory
        cd - > /dev/null
    fi
done < <(find "$MONITOR_DIR" -type d -name ".git" -print0 2>/dev/null)

echo "GIT_SECRET_MONITOR_ACTIVE_TODAY_END"