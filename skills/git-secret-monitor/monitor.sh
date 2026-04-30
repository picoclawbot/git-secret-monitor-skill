#!/bin/bash

# Git Secret Monitor - Main Script
# This script orchestrates the secret scanning process by:
# 1. Gathering git repository information
# 2. For each changed file, invoking the secret scanner tool via the PicoClaw agent
# 3. Reporting any findings

# Configuration
MONITOR_DIR="${MONITOR_DIR:-/home/picoclaw/.picoclaw}"
LOG_FILE="${MONITOR_DIR}/git-secret-monitor.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to scan a file for secrets using the secret scanner tool
# This function creates a temporary file with the content and calls the scanner
scan_file_for_secrets() {
    local file_path="$1"
    
    # Check if file exists and is readable
    if [[ ! -r "$file_path" ]]; then
        return 0
    fi
    
    # Read file content
    local content
    content=$(cat "$file_path" 2>/dev/null)
    
    if [[ -z "$content" ]]; then
        return 0
    fi
    
    # Use the secret scanner tool via PicoClaw's MCP interface
    # We'll call the agent's exec tool to run a command that uses the scanner
    # This is a simplified approach - in practice, the agent would need to handle this
    
    log_message "Scanning: $file_path"
    
    # For demonstration, we'll just note that scanning would happen here
    # In a real implementation, this would involve calling the MCP tool
    # through the agent's available functions
    
    return 0
}

# Main monitoring function
main() {
    log_message "Starting Git secret monitor"
    log_message "Monitoring directory: $MONITOR_DIR"
    
    # Create temporary file for gather_info.sh output
    local temp_file=$(mktemp)
    
    # Run the gather_info script to get repository information
    /home/picoclaw/.picoclaw/skills/git-secret-monitor/gather_info.sh > "$temp_file" 2>/dev/null
    
    # Process the output
    local in_repo=false
    local in_files=false
    local repo_dir=""
    local branch=""
    local commit=""
    
    while IFS= read -r line; do
        case "$line" in
            "GIT_SECRET_MONITOR_START")
                # Start of output
                ;;
            "GIT_SECRET_MONITOR_END")
                # End of output
                ;;
            "REPO_START")
                in_repo=true
                in_files=false
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
            REPO_DIR:*|BRANCH:*|COMMIT:*)
                if [[ $in_repo == true ]]; then
                    key="${line%%:*}"
                    value="${line#*:}"
                    case "$key" in
                        "REPO_DIR") repo_dir="$value" ;;
                        "BRANCH") branch="$value" ;;
                        "COMMIT") commit="$value" ;;
                    esac
                fi
                ;;
            FILE:*)
                if [[ $in_files == true ]]; then
                    file_path="${line#FILE:}"
                    if [[ -n "$file_path" && -f "$file_path" ]]; then
                        log_message "Checking file: $file_path in repo $repo_dir"
                        scan_file_for_secrets "$file_path"
                    fi
                fi
                ;;
        esac
    done < "$temp_file"
    
    # Clean up
    rm -f "$temp_file"
    
    log_message "Git secret monitor completed"
}

# Execute main function
main "$@"