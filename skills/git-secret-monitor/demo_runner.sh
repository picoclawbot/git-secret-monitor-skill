#!/bin/bash

# Git Secret Monitor - Demo Runner
# This script demonstrates the complete workflow:
# 1. Run monitor_test.sh to get file info
# 2. For each file, extract content and scan it using the secret scanner
# 3. Report results

DEMO_LOG="/home/picoclaw/.picoclaw/git-secret-monitor-demo.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEMO_LOG"
}

log_message "=== Starting Git Secret Monitor Demo ==="

# Clean up previous log
> "$DEMO_LOG"

# Run the test monitor to get file information
log_message "Step 1: Gathering repository information..."
MONITOR_OUTPUT=$(bash /home/picoclaw/.picoclaw/skills/git-secret-monitor/monitor_test.sh 2>&1)
log_message "Monitor output captured"

# Parse the output to find files to scan
log_message "Step 2: Parsing file information for scanning..."

# Extract SCAN_FILE blocks
echo "$MONITOR_OUTPUT" | awk '
/SCAN_FILE_START/ { in_block=1; path=""; repo=""; content=""; next }
/SCAN_FILE_END/   { 
    if (in_block && path != "" && content != "") {
        print "FILE_BLOCK_START"
        print "PATH:" path
        print "REPO:" repo
        print "CONTENT_START"
        print content
        print "CONTENT_END"
        print "FILE_BLOCK_END"
    }
    in_block=0; 
    next
}
in_block {
    if ($0 ~ /^PATH:/) { path = substr($0, 7) }
    else if ($0 ~ /^REPO:/) { repo = substr($0, 7) }
    else if ($0 ~ /^CONTENT:$/) { content_start=1; next }
    else if (content_start) { 
        if (content == "") { content = $0 }
        else { content = content "\n" $0 }
    }
    next
}
' > /tmp/scan_blocks.txt

# Process each file block
log_message "Step 3: Scanning each file for secrets..."
file_count=0
secret_count=0

while IFS= read -r line; do
    if [[ "$line" == "FILE_BLOCK_START" ]]; then
        current_path=""
        current_repo=""
        current_content=""
        in_content=false
    elif [[ "$line" == "FILE_BLOCK_END" ]]; then
        if [[ -n "$current_path" && -n "$current_content" ]]; then
            file_count=$((file_count + 1))
            log_message "Scanning file $file_count: $current_path (in $current_repo)"
            
            # Scan the content using the secret scanner (via agent)
            scan_result=$(mcp_hdn-server_secret_scanner --text "$current_content" 2>&1)
            
            # Check results
            if [[ "$scan_result" != *"No keys exposed"* && "$scan_result" != *"No secrets found"* && -n "$scan_result" && "$scan_result" != *"Error"* ]]; then
                secret_count=$((secret_count + 1))
                log_message "🚨 SECRET DETECTED in $current_path:"
                # Log each line of the result
                echo "$scan_result" | while read -r result_line; do
                    log_message "  $result_line"
                done
            else
                log_message "✅ No secrets found in $current_path"
            fi
        fi
    elif [[ "$line" == PATH:* ]]; then
        current_path="${line#PATH:}"
    elif [[ "$line" == REPO:* ]]; then
        current_repo="${line#REPO:}"
    elif [[ "$line" == CONTENT_START ]]; then
        in_content=true
        current_content=""
    elif [[ "$line" == CONTENT_END ]]; then
        in_content=false
    elif [[ "$in_content" == true ]]; then
        if [[ -z "$current_content" ]]; then
            current_content="$line"
        else
            current_content="$current_content
$line"
        fi
    fi
done < /tmp/scan_blocks.txt

log_message "=== Demo Complete ==="
log_message "Summary: Scanned $file_count file(s), found $secret_count file(s) with secrets"

if [[ $secret_count -gt 0 ]]; then
    log_message "⚠️  ACTION REQUIRED: Secrets detected in repository!"
else
    log_message "✅ All clear: No secrets detected in scanned files."
fi

# Cleanup
rm -f /tmp/scan_blocks.txt
