# Git Secret Monitor Skill

This skill monitors your Git repositories for leaked secrets in commits by integrating with PicoClaw's secret scanning capabilities.

## Description

The skill provides two scripts:
1. `gather_info.sh` - Collects information about Git repositories and recent commit changes
2. `monitor.sh` - Orchestrates the monitoring process (to be called by the PicoClaw agent)

## How It Works

1. The PicoClaw agent runs `gather_info.sh` to get a list of repositories and changed files
2. The agent parses this output and for each changed file, calls the `mcp_hdn-server_secret_scanner` tool
3. If any secrets are found, the agent sends an alert

## Installation

The skill is installed as a directory under `~/.picoclaw/skills/git-secret-monitor/`.

### Setup

1. Make the scripts executable:
   ```bash
   chmod +x ~/.picoclaw/skills/git-secret-monitor/*.sh
   ```

2. Configure the directory to monitor (optional):
   Edit the `MONITOR_DIR` variable in the scripts to point to the directory containing your Git repositories.
   By default, it monitors the current workspace (`/home/picoclaw/.picoclaw`).

3. To run a check, you can either:
   - Ask the PicoClaw agent to run the monitor skill, or
   - Set up a cron job via the agent's cron tool

### Example Usage via Agent

You could ask the PicoClaw agent to:
"Run the git secret monitor skill to check my repositories for leaked secrets"

The agent would then:
1. Execute the gather_info.sh script
2. Parse the output to identify repositories and changed files
3. For each changed file, invoke the secret scanner tool
4. Report any findings

## Customization

You can modify the scripts to:
- Scan different ranges of commits (e.g., all unpushed commits, last N commits)
- Change the frequency of monitoring
- Exclude certain files or directories based on patterns
- Adjust the alert thresholds