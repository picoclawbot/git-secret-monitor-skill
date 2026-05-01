#!/bin/bash

# Git Secret Monitor - Runner Script
# This script runs monitor.sh and processes its output to scan files for secrets
# using the MCP secret scanner tool.

MONITOR_SCRIPT="/home/picoclaw/.picoclaw/skills/git-secret-monitor/monitor.sh"
LOG_FILE="/home/picoclaw/.picoclaw/git-secret-monitor.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "Starting Git secret monitor runner"

# Run the monitor script and capture output
output=$("$MONITOR_SCRIPT" 2>&1)

# Parse the output to extract files to scan
in_scan_file=false
current_path=""
current_content=""
content_started=false

while IFS= read -r line; do
    if [[ "$line" == "SCAN_FILE_START" ]]; then
        in_scan_file=true
        current_path=""
        current_content=""
        content_started=false
    elif [[ "$line" == "SCAN_FILE_END" ]]; then
        if [[ -n "$current_path" && -n "$current_content" ]]; then
            log_message "Scanning: $current_path"
            
            # Call the secret scanner on the content
            scan_result=$(mcp_hdn-server_secret_scanner --text "$current_content" 2>&1)
            
            # Check if any secrets were found
            if [[ "$scan_result" != *"No keys exposed"* && "$scan_result" != *"No secrets found"* && -n "$scan_result" ]]; then
                log_message "🚨 SECRET DETECTED in $current_path:"
                log_message "$scan_result"
            else
                log_message "✅ No secrets found in $current_path"
            fi
        fi
        in_scan_file=false
    elif [[ "$line" == PATH:* ]]; then
        current_path="${line#PATH:}"
    elif [[ "$line" == CONTENT: ]]; then
        content_started=true
    elif [[ $content_started == true && "$in_scan_file" == true ]]; then
        # Accumulate content lines (skip empty line after CONTENT:)
        if [[ -n "$line" ]]; then
            if [[ -z "$current_content" ]]; then
                current_content="$line"
            else
                current_content="$current_content
$line"
            fi
        fi
    fi
done <<< "$output"

log_message "Git secret monitor runner completed"
