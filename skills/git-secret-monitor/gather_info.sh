#!/bin/bash

# Git Secret Monitor - Helper Script
# This script is designed to be called by the PicoClaw agent via the exec tool
# It gathers information about git repos and changed files, then outputs it
# for the agent to process with secret scanning tools

# Configuration
MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw/.picoclaw}"
MAX_COMMIT_AGE_DAYS="${MAX_COMMIT_AGE_DAYS:-7}"

# Repositories to monitor
# Add or remove repos from this list as needed.
# Each path must contain a .git directory.
REPOS_TO_MONITOR=(
    "/home/picoclaw/.picoclaw/repos/stevef1uk/freeride"
    "/home/picoclaw/.picoclaw/repos/picoclaw"
    "/home/picoclaw/.picoclaw/repos/stevef1uk/picoclaw"
    "/home/picoclaw/.picoclaw/repos/stevef1uk/artificial_mind"
    "/home/picoclaw/.picoclaw/repos/stevef1uk/agentdojo-picoclaw-security"
    "/home/picoclaw/.picoclaw/repos/stevef1uk/agents"
    "/home/picoclaw/.picoclaw/repos/stevef1uk/argo"
    "/home/picoclaw/.picoclaw/repos/stevef1uk/app-test-1"
    "/home/picoclaw/.picoclaw/repos/agents"
)

echo "GIT_SECRET_MONITOR_START"
echo "MAX_COMMIT_AGE_DAYS:${MAX_COMMIT_AGE_DAYS}"

max_age_seconds=$((MAX_COMMIT_AGE_DAYS * 86400))
now=$(date +%s)

for repo_dir in "${REPOS_TO_MONITOR[@]}"; do
    if [[ ! -d "$repo_dir" || ! -d "$repo_dir/.git" ]]; then
        echo "SKIP:$repo_dir (not found or not a git repo)"
        continue
    fi

    if ! cd "$repo_dir"; then
        echo "SKIP:$repo_dir (cannot cd)"
        continue
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        cd - > /dev/null
        continue
    fi

    latest_commit=$(git rev-parse HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        cd - > /dev/null
        continue
    fi

    # --- Option 1: skip repos whose latest commit is older than threshold ---
    commit_epoch=$(git log -1 --format="%ct" HEAD 2>/dev/null)
    if [[ -n "$commit_epoch" ]]; then
        age_seconds=$((now - commit_epoch))
        if [[ $age_seconds -gt $max_age_seconds ]]; then
            age_days=$((age_seconds / 86400))
            echo "SKIP:$repo_dir (last commit ${age_days}d ago, older than ${MAX_COMMIT_AGE_DAYS}d)"
            cd - > /dev/null
            continue
        fi
    fi

    changed_files=$(git diff-tree --no-commit-id --name-only -r "$latest_commit" 2>/dev/null)

    if [[ -z "$changed_files" ]]; then
        cd - > /dev/null
        continue
    fi

    echo "REPO_START"
    echo "REPO_DIR:$repo_dir"
    echo "BRANCH:$current_branch"
    echo "COMMIT:$latest_commit"

    echo "FILES_START"
    while IFS= read -r file; do
        if [[ -n "$file" && -f "$file" ]]; then
            echo "FILE:$file"
        fi
    done <<< "$changed_files"
    echo "FILES_END"

    echo "REPO_END"

    cd - > /dev/null
done

echo "GIT_SECRET_MONITOR_END"
