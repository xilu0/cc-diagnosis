# Claude Code Debugging Guide

English | [简体中文](DEBUG_CN.md)

A comprehensive guide for diagnosing and troubleshooting Claude Code performance issues, unresponsiveness, and stuck processes.

## Table of Contents

- [Quick Start](#quick-start)
- [Debug Flags Reference](#debug-flags-reference)
- [Log Files and Locations](#log-files-and-locations)
- [Real-time Monitoring](#real-time-monitoring)
- [Troubleshooting Decision Tree](#troubleshooting-decision-tree)
- [Common Issues and Solutions](#common-issues-and-solutions)
- [Performance Optimization](#performance-optimization)
- [Community Tools](#community-tools)

---

## Quick Start

When Claude Code appears stuck or slow, immediately run:

```bash
# Enable all debug output
claude --verbose --debug

# For MCP-related issues
claude --verbose --mcp-debug

# Save debug output to file
claude --verbose --debug > debug.log 2>&1
```

**Quick diagnostic commands:**

```bash
claude doctor          # System health check
claude /status         # Check current status
claude mcp list        # MCP server status
claude /cost           # View session costs
```

---

## Debug Flags Reference

### `--verbose`

**Purpose**: Shows detailed diagnostic output of internal operations

**What it shows:**
- Timestamps for each operation
- Tool executions and parameters
- File operations (read, write, edit)
- API communication details
- Operation status and results

**Usage:**
```bash
claude --verbose
claude --verbose [command]
claude --verbose -p "Your prompt here"
```

**Best for:**
- Understanding what Claude Code is doing
- Identifying bottlenecks
- Debugging slow responses
- Tracking tool calls

**Example output:**
```
[2025-01-14 10:30:45] API Request: /v1/messages
[2025-01-14 10:30:46] Tool call: read_file(/path/to/file.js)
[2025-01-14 10:30:47] File read: 1234 bytes
[2025-01-14 10:30:48] API Response: 200 OK (tokens: 1500)
```

### `--debug`

**Purpose**: Enables debug mode with detailed debugging output

**What it shows:**
- Internal state information
- Error stack traces
- Configuration values
- Environment variables

**Usage:**
```bash
claude --debug
claude --debug [command]
```

**Best for:**
- Troubleshooting errors
- Understanding configuration issues
- Developer-level debugging

### `--mcp-debug`

**Purpose**: Specialized debugging for Model Context Protocol connections

**What it shows:**
- MCP server initialization
- Connection attempts and status
- Tool availability from MCP servers
- MCP-related errors and warnings

**Usage:**
```bash
claude --mcp-debug
claude --verbose --mcp-debug  # Recommended combination
```

**Best for:**
- MCP server connection issues
- Missing or unavailable MCP tools
- MCP configuration problems

**Common issues detected:**
- MCP server failed to start
- Tool not found from expected MCP server
- Connection timeout to MCP server

### Combining Flags

For comprehensive diagnostics, combine multiple flags:

```bash
# Maximum verbosity
claude --verbose --debug --mcp-debug

# Recommended for most debugging scenarios
claude --verbose --mcp-debug
```

---

## Log Files and Locations

### Primary Log Location

Claude Code stores complete session logs in JSONL (newline-delimited JSON) format:

**Path:**
```bash
~/.claude/projects/<encoded-directory>/*.jsonl
```

**Configuration files:**
```bash
~/.claude/settings.json              # Global settings
.claude/settings.json                # Project-specific settings
```

### Finding Your Logs

```bash
# Method 1: Use doctor command
claude doctor
# Output will show: "Log directory: /Users/username/.claude/projects/..."

# Method 2: List recent logs
ls -lt ~/.claude/projects/*/
```

### Viewing Logs

**Raw JSONL format:**
```bash
# View latest log file
tail -f ~/.claude/projects/*/$(ls -t ~/.claude/projects/*/ | head -1)

# Pretty-print with jq
tail -f ~/.claude/projects/*/*.jsonl | jq '.'
```

**Filter specific events:**
```bash
# Show only API requests
cat ~/.claude/projects/*/*.jsonl | jq 'select(.type == "api_request")'

# Show only errors
cat ~/.claude/projects/*/*.jsonl | jq 'select(.level == "error")'

# Show tool calls
cat ~/.claude/projects/*/*.jsonl | jq 'select(.type == "tool_call")'
```

### Log Rotation and Cleanup

Logs can accumulate over time. To manage space:

```bash
# Check log directory size
du -sh ~/.claude/

# Remove logs older than 30 days
find ~/.claude/projects -name "*.jsonl" -mtime +30 -delete

# Keep only last 10 sessions per project
# (Manual cleanup - review before deleting)
ls -t ~/.claude/projects/*/session*.jsonl | tail -n +11 | xargs rm
```

---

## Real-time Monitoring

### Built-in Monitoring Commands

Use these commands during an active Claude Code session:

```bash
/status              # Current session status
/cost                # Token usage and costs
/permissions         # Current permission settings
/clear               # Clear context window
/compact             # Compress conversation history
```

### Terminal-based Monitoring

**Watch log file in real-time:**
```bash
# In a separate terminal window
tail -f ~/.claude/projects/*/*.jsonl | jq -r '.timestamp + " " + .type + " " + (.message // "")'
```

**Monitor API calls:**
```bash
# Filter for API communication
tail -f ~/.claude/projects/*/*.jsonl | jq 'select(.type | test("api"))'
```

**Track tool executions:**
```bash
# Monitor tool calls
tail -f ~/.claude/projects/*/*.jsonl | jq 'select(.type == "tool_call") | {time: .timestamp, tool: .tool_name, duration: .duration}'
```

### Community Monitoring Tools

#### 1. claude-code-logger (Proxy-based)

Intercepts and displays traffic between Claude Code and the API.

**Installation:**
```bash
git clone https://github.com/username/claude-code-logger
cd claude-code-logger
npm install
npm run dev -- start --chat-mode
```

**Usage:**
```bash
# Terminal 1: Start proxy
npm run dev -- start --chat-mode

# Terminal 2: Use Claude with proxy
ANTHROPIC_BASE_URL=http://localhost:8000/ claude
```

**Features:**
- Real-time request/response streaming
- Chat mode with colored output
- Request/response formatting
- Latency tracking

#### 2. claude-code-log (TUI Viewer)

Interactive terminal UI for browsing sessions.

**Installation:**
```bash
pipx install claude-conversation-extractor
# or
pip install claude-conversation-extractor
```

**Usage:**
```bash
# Interactive TUI
claude-code-log --tui

# Start session browser
claude-start
```

**Features:**
- Session list with ID, summary, timestamp
- Message count and token usage
- Search and filter capabilities
- Export conversations

#### 3. Real-time Dashboard (Custom Script)

Create a simple monitoring script:

```bash
#!/bin/bash
# save as monitor-claude.sh

LOG_DIR="$HOME/.claude/projects"
LATEST_LOG=$(find "$LOG_DIR" -name "*.jsonl" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

echo "Monitoring: $LATEST_LOG"
echo "Press Ctrl+C to stop"
echo ""

tail -f "$LATEST_LOG" | while read line; do
    TYPE=$(echo "$line" | jq -r '.type // "unknown"')
    TIMESTAMP=$(echo "$line" | jq -r '.timestamp // "no-time"')

    case "$TYPE" in
        "api_request")
            echo "[$TIMESTAMP] 🌐 API Request"
            ;;
        "api_response")
            TOKENS=$(echo "$line" | jq -r '.usage.total_tokens // "?"')
            echo "[$TIMESTAMP] ✅ API Response (tokens: $TOKENS)"
            ;;
        "tool_call")
            TOOL=$(echo "$line" | jq -r '.tool_name // "unknown"')
            echo "[$TIMESTAMP] 🔧 Tool: $TOOL"
            ;;
        "error")
            MSG=$(echo "$line" | jq -r '.message // "unknown error"')
            echo "[$TIMESTAMP] ❌ Error: $MSG"
            ;;
    esac
done
```

Make executable and run:
```bash
chmod +x monitor-claude.sh
./monitor-claude.sh
```

---

## Troubleshooting Decision Tree

### When Claude Code Appears Stuck

```
┌─────────────────────────────────────┐
│ Claude Code appears unresponsive   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Enable: claude --verbose --debug   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Observe output for 30-60 seconds   │
└──────────────┬──────────────────────┘
               │
               ▼
        ┌──────┴──────┐
        │             │
        ▼             ▼
  ┌─────────┐   ┌─────────┐
  │ Seeing  │   │   No    │
  │ output? │   │ output? │
  └────┬────┘   └────┬────┘
       │             │
       │             └─────────────┐
       │                           │
       ▼                           ▼
┌──────────────────┐    ┌──────────────────────┐
│ What type of     │    │ Check log file:      │
│ output?          │    │ tail -f ~/.claude/   │
└────┬─────────────┘    │      projects/*/*.jsonl│
     │                  └──────────┬─────────────┘
     │                             │
     ├─ API request/response       ├─ File growing?
     │  → Processing normally      │  YES → Background processing
     │  → Continue waiting         │  NO  → Process hung
     │                             │       → Ctrl+C and retry
     ├─ Tool calls
     │  → Check if looping
     │  → If stuck, Ctrl+C
     │  → If MCP tool, check with:
     │     claude mcp list
     │
     ├─ Error messages
     │  → Address specific error
     │  → See Common Issues below
     │
     └─ Timeout warnings
        → Network issue
        → Check connectivity
        → Run network diagnostic
```

### Quick Decision Points

| Symptom | Check This | Action |
|---------|------------|--------|
| No output for 2+ min | Log file still growing? | If yes: wait; If no: Ctrl+C retry |
| Repeated tool calls | Same tool called 10+ times? | Likely loop, press Ctrl+C |
| API timeout | Network connectivity | Run `./diagnose.sh` for network check |
| MCP error | `claude mcp list` | Restart affected MCP server |
| High memory usage | Context window size | Run `/clear` or `/compact` |
| Slow responses | Token count | Check `/cost`, consider `/clear` |

---

## Common Issues and Solutions

### Issue 1: Claude Code Appears Frozen

**Symptoms:**
- No visible progress
- No terminal output
- Cursor just blinking

**Diagnosis:**
```bash
# Terminal 1: Run with verbose
claude --verbose

# Terminal 2: Monitor logs
tail -f ~/.claude/projects/*/*.jsonl | jq -r '.timestamp + " " + .type'
```

**Solutions:**

**If logs show activity:**
- Claude is working, be patient
- Large file operations take time
- Complex reasoning requires processing

**If logs are static:**
```bash
# Press Ctrl+C to interrupt
# Then retry with context cleared
claude
/clear
# Retry your request
```

### Issue 2: Slow Response Times

**Symptoms:**
- Each response takes 30+ seconds
- Thinking appears slow
- Tool calls are delayed

**Diagnosis:**
```bash
# Check context size
/cost  # Shows tokens used

# Check for context bloat
/status
```

**Solutions:**

1. **Clear context regularly:**
```bash
/clear     # Full context reset
/compact   # Compress history while keeping context
```

2. **Optimize prompts:**
```bash
# Bad: vague and requires exploration
"Fix all the bugs"

# Good: specific and targeted
"Fix the TypeError in src/utils/parser.js line 45"
```

3. **Use CLAUDE.md for context:**

Create `.claude/CLAUDE.md` in project root:
```markdown
# Project: MyApp

## Structure
- src/ - Source code
- tests/ - Test files
- docs/ - Documentation

## Common Commands
- npm test - Run tests
- npm build - Build project

## Code Style
- Use TypeScript
- Prefer functional style
- Max line length: 100

## Known Issues
- API rate limit: 100 req/min
- Database: PostgreSQL 14+
```

### Issue 3: MCP Servers Not Working

**Symptoms:**
- Tools not available
- MCP connection errors
- "Server not responding"

**Diagnosis:**
```bash
# Check MCP server status
claude mcp list
claude --mcp-debug
```

**Expected output:**
```
✓ github - Connected (15 tools available)
✓ filesystem - Connected (8 tools available)
✗ custom-server - Failed to connect
```

**Solutions:**

1. **Restart individual MCP server:**
```bash
# Check MCP configuration
cat ~/.claude/mcp-servers.json

# Test server manually
node /path/to/mcp-server/index.js
```

2. **Check MCP server logs:**
```bash
# MCP servers usually log to stderr
# Check Claude Code logs for MCP errors
cat ~/.claude/projects/*/*.jsonl | jq 'select(.type == "mcp_error")'
```

3. **Verify MCP configuration:**
```json
// ~/.claude/mcp-servers.json
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["/path/to/filesystem-server/index.js"]
    }
  }
}
```

### Issue 4: Out of Memory Errors

**Symptoms:**
- Process crashes
- "JavaScript heap out of memory"
- System slowdown

**Diagnosis:**
```bash
# Check Node.js memory usage
ps aux | grep claude

# Monitor memory during execution
while true; do
  ps aux | grep claude | grep -v grep | awk '{print $6/1024 " MB"}'
  sleep 2
done
```

**Solutions:**

1. **Increase Node.js memory:**
```bash
# Set memory limit (8GB example)
export NODE_OPTIONS="--max-old-space-size=8192"
claude
```

2. **Clear context frequently:**
```bash
# Use /clear after every major task
/clear
```

3. **Avoid loading large files:**
```bash
# Bad: Loading entire 50MB log file
# Good: Ask Claude to read specific lines or use grep first
```

### Issue 5: Token Limit Exceeded

**Symptoms:**
- "Context window exceeded"
- "Maximum tokens reached"
- Responses get cut off

**Diagnosis:**
```bash
/cost   # Check current token usage
```

**Solutions:**

1. **Use /compact instead of /clear:**
```bash
/compact  # Preserves important context, removes redundant content
```

2. **Break down tasks:**
```bash
# Instead of: "Refactor entire codebase"
# Do: "Refactor src/auth.js", then "Refactor src/api.js", etc.
```

3. **Use selective file reading:**
```bash
# Guide Claude to read only relevant files
"Read only the authentication-related files in src/"
```

---

## Performance Optimization

### Best Practices

#### 1. Context Management

```bash
# Start of work session
claude

# After completing a major task
/clear

# Before switching to different task
/compact
```

#### 2. Effective Prompting

**Poor prompts (slow, resource-intensive):**
- "Fix all issues"
- "Make this better"
- "Review everything"

**Good prompts (fast, targeted):**
- "Fix the null pointer error in auth.js:42"
- "Add error handling to the login function"
- "Review the security of the password reset flow"

#### 3. CLAUDE.md Configuration

Create informative context for Claude:

```markdown
# Project Configuration

## Quick Facts
- Language: TypeScript
- Framework: React + Express
- Database: PostgreSQL
- Tests: Jest

## File Structure
```
src/
├── api/       # REST API endpoints
├── components/  # React components
├── utils/     # Helper functions
└── types/     # TypeScript types
```

## Common Commands
- `npm test` - Run all tests
- `npm run dev` - Start dev server
- `npm run build` - Production build

## Coding Standards
- Max function length: 50 lines
- Prefer composition over inheritance
- All exports must have JSDoc comments

## Debugging Notes
- API server runs on port 3000
- Database connection: localhost:5432
- Redis cache: localhost:6379
```

#### 4. Limit Tool Execution

```bash
# Use --max-turns to prevent runaway execution
claude --max-turns 5 -p "Your complex task"
```

#### 5. Monitor Resource Usage

```bash
# Create monitoring alias
alias claude-monitor='watch -n 1 "ps aux | grep claude | grep -v grep"'

# Run before starting intensive work
claude-monitor
```

### Configuration Optimizations

**Global settings (`~/.claude/settings.json`):**

```json
{
  "verbose": false,
  "auto_clear_context": true,
  "max_context_tokens": 100000,
  "tool_timeout": 30000
}
```

**Project settings (`.claude/settings.json`):**

```json
{
  "ignored_paths": [
    "node_modules/",
    "dist/",
    "build/",
    "*.log",
    ".git/"
  ],
  "max_file_size": 1048576
}
```

---

## Community Tools

### 1. claude-code-logger

**Purpose**: HTTP proxy to monitor API traffic

**Installation:**
```bash
git clone https://github.com/anthropics/claude-code-logger
cd claude-code-logger
npm install
```

**Usage:**
```bash
npm run dev -- start --chat-mode
ANTHROPIC_BASE_URL=http://localhost:8000/ claude
```

**Features:**
- Real-time request/response display
- Token counting
- Latency measurements
- Chat-style formatting

### 2. claude-conversation-extractor

**Purpose**: Extract and browse Claude Code sessions

**Installation:**
```bash
pipx install claude-conversation-extractor
```

**Usage:**
```bash
# Interactive TUI
claude-code-log --tui

# Export specific conversation
claude-code-log export --id <session-id> --format markdown
```

**Features:**
- Session search
- Token statistics
- Export to multiple formats
- Conversation replay

### 3. Custom Monitoring Scripts

**Live token counter:**
```bash
#!/bin/bash
# live-cost.sh

while true; do
  LOG=$(find ~/.claude/projects -name "*.jsonl" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
  TOKENS=$(tail -1000 "$LOG" | jq -s '[.[].usage.total_tokens // 0] | add')
  echo "Total tokens in last 1000 events: $TOKENS"
  sleep 5
done
```

**Error tracker:**
```bash
#!/bin/bash
# track-errors.sh

LOG_DIR="$HOME/.claude/projects"

echo "Monitoring for errors..."
tail -f "$LOG_DIR"/*/*.jsonl | jq -r 'select(.level == "error") | .timestamp + " ERROR: " + .message'
```

---

## Appendix: Debug Checklist

When troubleshooting, work through this checklist:

- [ ] Enabled `--verbose` flag
- [ ] Checked log files are being written
- [ ] Verified network connectivity (run `./diagnose.sh`)
- [ ] Confirmed MCP servers are running (`claude mcp list`)
- [ ] Checked context size (`/cost`)
- [ ] Cleared context if needed (`/clear`)
- [ ] Reviewed recent errors in logs
- [ ] Verified disk space available
- [ ] Checked system memory usage
- [ ] Tested with minimal prompt
- [ ] Reviewed CLAUDE.md configuration (if exists)
- [ ] Confirmed API key is valid

---

## Getting Help

If issues persist after following this guide:

1. **Collect debug information:**
```bash
# Generate comprehensive debug report
claude doctor > claude-debug-report.txt
claude --verbose --debug [your-command] >> claude-debug-report.txt 2>&1
```

2. **Check community resources:**
- GitHub Issues: https://github.com/anthropics/claude-code/issues
- Discord: Claude Code community channel
- Documentation: https://docs.anthropic.com

3. **File a bug report with:**
- Debug report output
- Relevant log excerpts
- Steps to reproduce
- System information (OS, Node version, Claude Code version)

---

**Last Updated**: 2025-01-14

For network connectivity issues, see [README.md](README.md) and use the diagnostic scripts (`diagnose.sh` or `diagnose.ps1`).
