#!/bin/bash

# Git Secret Monitor - Test Script
# This script gathers git repository info and changed file contents from test_monitor_repo,
# then outputs them for the PicoClaw agent to scan using the MCP secret scanner.
#
# Usage: bash monitor_test.sh
# Output: Structured data on stdout for the agent to process

MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw/.picoclaw}"
LOG_FILE="${MONITOR_DIR}/git-secret-monitor.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Run gather_info.sh to find repos and changed files (test version)
GATHER_SCRIPT="/home/picoclaw/.picoclaw/skills/git-secret-monitor/gather_info_test.sh"

if [[ ! -x "$GATHER_SCRIPT" ]]; then
    log_message "ERROR: gather_info_test.sh not found or not executable"
    exit 1
fi

log_message "Starting Git secret monitor (TEST)"

temp_file=$(mktemp)
"$GATHER_SCRIPT" > "$temp_file" 2>/dev/null

in_repo=false
in_files=false
repo_dir=""
repo_count=0
file_count=0

while IFS= read -r line; do
    case "$line" in
        "REPO_START")
            in_repo=true
            in_files=false
            repo_dir=""
            ;;
        "REPO_END")
            in_repo=false
            ;;
        "FILES_START")
            in_files=true
            ;;
        "FILES_END")
            in_files=false
            ;;
        REPO_DIR:*)
            if [[ $in_repo == true ]]; then
                repo_dir="${line#REPO_DIR:}"
            fi
            ;;
        FILE:*)
            if [[ $in_files == true ]]; then
                file_path="${line#FILE:}"
                # Resolve to absolute path
                if [[ "$file_path" != /* ]]; then
                    file_path="${repo_dir}/${file_path}"
                fi
                if [[ -f "$file_path" ]]; then
                    file_count=$((file_count + 1))
                    echo "SCAN_FILE_START"
                    echo "PATH:${file_path}"
                    echo "REPO:${repo_dir}"
                    echo "CONTENT:"
                    cat "$file_path"
                    echo ""
                    echo "SCAN_FILE_END"
                fi
            fi
            ;;
    esac
done < "$temp_file"

rm -f "$temp_file"

log_message "Git secret monitor completed (TEST) — ${file_count} file(s) to scan"
echo "TOTAL_FILES:${file_count}"
