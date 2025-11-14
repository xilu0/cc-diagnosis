# Claude Code Diagnostic Tool

A cross-platform diagnostic utility for troubleshooting Claude Code connectivity, authentication, and installation issues.

## Overview

This tool helps diagnose common problems when connecting to the Claude Code API server at `claude-code.club`. It performs comprehensive checks across multiple areas:

- **Authentication**: Validates API tokens and configuration
- **Network**: Tests DNS resolution, TLS handshakes, and API connectivity
- **Installation**: Locates Claude Code binaries and verifies versions
- **Configuration**: Examines environment variables and config files

## Supported Platforms

- **macOS/Linux**: `diagnose.sh` (zsh/bash)
- **Windows**: `diagnose.ps1` (PowerShell)

## Quick Start

### Direct Execution (No Download Required)

Run the diagnostic tool directly from GitHub without cloning the repository:

#### macOS/Linux

```bash
# Basic diagnostics
curl -fsSL https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.sh | zsh

# With verbose output
curl -fsSL https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.sh | zsh -s -- --verbose

# Save output to file
curl -fsSL https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.sh | zsh -s -- --output diagnostic-report.txt

# With verbose and output
curl -fsSL https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.sh | zsh -s -- --verbose --output report.txt
```

#### Windows

```powershell
# Basic diagnostics
irm https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.ps1 | iex

# With verbose output
irm https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.ps1 | iex; .\diagnose.ps1 -Verbose

# Alternative: Download and execute with parameters
$script = irm https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.ps1
Invoke-Expression $script -Verbose -Output report.txt
```

> **Security Note**: Always review scripts before executing them directly from the internet. You can inspect the script first:
> ```bash
> # macOS/Linux: View script content
> curl -fsSL https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.sh | less
>
> # Windows: View script content
> irm https://raw.githubusercontent.com/xilu0/cc-diagnosis/main/diagnose.ps1
> ```

---

### Local Execution (Downloaded Repository)

If you prefer to clone the repository first:

#### macOS/Linux

```bash
# Make the script executable (first time only)
chmod +x diagnose.sh

# Run basic diagnostics
./diagnose.sh

# Run with detailed logging
./diagnose.sh --verbose

# Save diagnostic report to file
./diagnose.sh --output diagnostic-report.txt

# Run with auto-fix enabled
./diagnose.sh --fix
```

#### Windows

```powershell
# Run basic diagnostics
.\diagnose.ps1

# Run with detailed logging
.\diagnose.ps1 -Verbose

# Save diagnostic report to file
.\diagnose.ps1 -Output diagnostic-report.txt

# Run with auto-fix enabled
.\diagnose.ps1 -Fix
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--verbose` / `-Verbose` | Enable detailed logging output including curl responses and intermediate steps |
| `--fix` / `-Fix` | Attempt to automatically fix common configuration issues |
| `--output <file>` / `-Output <file>` | Save the diagnostic report to a specified file |
| `--help` / `-Help` | Display usage information |

## What It Checks

### 1. Environment Check

- Verifies presence of required tools (`curl`, optional `jq`)
- Reports shell/PowerShell version information

### 2. Authentication Diagnostics

- **ANTHROPIC_AUTH_TOKEN**: Confirms the token is set (required)
- **ANTHROPIC_API_KEY**: Warns if detected (should NOT be used)
- **ANTHROPIC_BASE_URL**: Validates correct configuration
- **Console Cache**: Detects potential conflicts from official Anthropic Console

### 3. Network Diagnostics

- **DNS Resolution**: Tests domain name lookup for `claude-code.club`
- **TLS Handshake**: Verifies SSL/TLS certificate validation
- **API Connectivity**: Performs actual API call with authentication headers
- **Error Detection**: Identifies specific failure patterns (timeouts, certificate errors, etc.)

### 4. Installation Discovery

- Locates Claude Code binary in system PATH
- Detects installation method (npm, Homebrew, manual)
- Reports current version
- Warns about multiple installations

### 5. Configuration Files

- Checks for config directories (`~/.config/claude-code`, etc.)
- Scans environment files for ANTHROPIC variables
- Inspects registry settings (Windows only)

## Example Output

```
========================================
Claude Code Diagnostic Tool
========================================
Target API: https://claude-code.club/api
Date: 2025-01-14 10:30:45

[1] Environment Check
----------------------------------------
✓ curl: Found (curl 8.1.0)
  jq: Not found (optional, install for better output formatting)
  Shell: /bin/zsh

[2] Authentication Diagnostics
----------------------------------------
✓ ANTHROPIC_AUTH_TOKEN: Set (sk-ant-api...abc123)
✓ ANTHROPIC_API_KEY: Not set (correct)
  ANTHROPIC_BASE_URL: Not set (optional, defaults to claude-code.club)

[3] Network Diagnostics
----------------------------------------
✓ DNS Resolution: claude-code.club → 1.2.3.4
✓ TLS Handshake: Successful
✓ API Connection: Successful (HTTP 200)

[4] Installation Discovery
----------------------------------------
✓ Claude Code: Found at /opt/homebrew/bin/claude
  Version: 1.2.3
  Installation method: Homebrew

[5] Configuration Files
----------------------------------------
✓ Config directory: /Users/username/.config/claude-code
  Checking environment files for Claude Code variables...
✓ Found ANTHROPIC variables in: /Users/username/.zshrc

========================================
Diagnostic Summary
========================================

✓ No critical issues detected!

========================================
Diagnostic Complete
========================================
```

## Common Issues and Solutions

### Issue: "ANTHROPIC_AUTH_TOKEN: Not set"

**Solution:**
```bash
# macOS/Linux
export ANTHROPIC_AUTH_TOKEN='your-token-here'
echo 'export ANTHROPIC_AUTH_TOKEN="your-token"' >> ~/.zshrc

# Windows (PowerShell)
$env:ANTHROPIC_AUTH_TOKEN='your-token-here'
# For persistence, set via System Properties → Environment Variables
```

### Issue: "API Connection: Authentication failed (HTTP 401)"

**Causes:**
- Token is invalid or expired
- Token format is incorrect

**Solution:**
- Verify your token is correct
- Request a new token if necessary
- Ensure no extra spaces or quotes in the token value

### Issue: "DNS Resolution: Failed to resolve claude-code.club"

**Solution:**
```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### Issue: "TLS Handshake: Certificate verification failed"

**Causes:**
- System time is incorrect
- Missing or outdated root certificates
- Corporate proxy or firewall interference

**Solution:**
1. Verify system date/time is correct
2. Update system certificates
3. Check for corporate proxy settings
4. Temporarily test without VPN (if applicable)

### Issue: "ANTHROPIC_API_KEY detected"

**Solution:**
```bash
# macOS/Linux: Remove from environment files
# Edit ~/.zshrc, ~/.bashrc, or ~/.profile and remove the line:
# export ANTHROPIC_API_KEY='...'

# Windows: Remove from Environment Variables
# System Properties → Advanced → Environment Variables
```

### Issue: "Multiple Claude Code installations found"

**Solution:**
Remove duplicate installations to avoid version conflicts:
```bash
# Check all locations
which -a claude

# Remove unwanted versions
# Example: npm install -g @anthropic-ai/claude-code (to reinstall)
```

## Requirements

### macOS/Linux
- **curl** (required) - Usually pre-installed
- **zsh** or **bash** shell
- **jq** (optional) - For JSON formatting

### Windows
- **PowerShell** 5.1 or later
- **curl** (comes with Windows 10+, or install via [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/))
- **jq** (optional) - Install via `winget install jqlang.jq`

## Troubleshooting

### Script Execution Issues

**macOS/Linux:**
```bash
# Permission denied
chmod +x diagnose.sh

# /bin/zsh: bad interpreter
# If zsh is not available, edit the shebang line to:
#!/usr/bin/env bash
```

**Windows:**
```powershell
# Execution policy error
PowerShell -ExecutionPolicy Bypass -File diagnose.ps1

# Or permanently set execution policy (requires admin):
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Network Testing

If the diagnostic shows network issues, you can test manually:

```bash
# Test DNS
nslookup claude-code.club

# Test TLS
openssl s_client -connect claude-code.club:443 -servername claude-code.club

# Test API (replace YOUR_TOKEN)
curl -v https://claude-code.club/api/v1/models \
  --header "x-api-key: YOUR_TOKEN" \
  --header "anthropic-version: 2023-06-01"
```

## Contributing

Contributions are welcome! If you encounter issues or have suggestions:

1. Check existing issues or create a new one
2. Fork the repository
3. Create a feature branch
4. Submit a pull request

## Support

For Claude Code related issues:
- Official Documentation: [https://docs.anthropic.com](https://docs.anthropic.com)
- GitHub Issues: [Report an issue](https://github.com/anthropics/claude-code/issues)

## License

This diagnostic tool is provided as-is for troubleshooting purposes.

---

**Target Environment:**
- API Server: `https://claude-code.club/api`
- Authentication: Uses `ANTHROPIC_AUTH_TOKEN` environment variable
- API Configuration: `ANTHROPIC_BASE_URL=https://claude-code.club/api`
