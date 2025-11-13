# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project provides diagnostic scripts for troubleshooting Claude Code connectivity issues. The scripts are designed to be cross-platform, supporting:
- **Windows**: PowerShell (`.ps1`)
- **macOS**: zsh (`.sh`)

## Target Environment

- **API Server**: `https://claude-code.club/api`
- **Authentication**: Uses `ANTHROPIC_AUTH_TOKEN` environment variable only
- **API Configuration**: `ANTHROPIC_BASE_URL=https://claude-code.club/api`

## Diagnostic Scope

The diagnostic scripts should identify and report:

### Authentication Issues
- Presence of official Console login cache that may conflict
- Incorrect `ANTHROPIC_API_KEY` configuration (should not be used)
- Wrong `ANTHROPIC_BASE_URL` value

### Network Issues
- DNS resolution failures for `claude-code.club`
- Network connectivity problems
- Firewall blocking TLS handshake
- TLS/SSL certificate issues

### Installation Issues
- Claude Code installation location
- Installation method (npm, brew, binary, etc.)
- Multiple version installations
- Currently active version

## Key Diagnostic Commands

### Network Connectivity Test
```bash
curl -v https://claude-code.club/api/v1/models \
  --header "x-api-key: $ANTHROPIC_AUTH_TOKEN" \
  --header "anthropic-version: 2023-06-01"
```

The `-v` flag provides verbose output showing:
- DNS resolution
- TCP connection establishment
- TLS handshake details
- HTTP request/response headers
- Any error messages

## Script Architecture

### Cross-Platform Considerations

**Shell Scripts (macOS/Linux)**
- Use `#!/usr/bin/env zsh` or `#!/usr/bin/env bash` shebang
- Test environment variables with `[ -z "$VAR" ]`
- Use `command -v` to check for command availability

**PowerShell Scripts (Windows)**
- Use `.ps1` extension
- Test environment variables with `[string]::IsNullOrEmpty($env:VAR)`
- Use `Get-Command` to check for command availability
- Consider execution policy requirements

### Diagnostic Flow

1. **Environment Check**: Verify required tools (`curl`, `jq`, etc.)
2. **Configuration Analysis**: Check environment variables
3. **Network Diagnostics**: Test DNS, connectivity, TLS
4. **Installation Discovery**: Locate Claude Code binary and version
5. **Report Generation**: Provide actionable troubleshooting steps

## Development Commands

### Testing Scripts

**macOS/Linux:**
```bash
chmod +x diagnose.sh
./diagnose.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File diagnose.ps1
```

### Running with Specific Token
```bash
ANTHROPIC_AUTH_TOKEN="your-token" ./diagnose.sh
```

```powershell
$env:ANTHROPIC_AUTH_TOKEN="your-token"; .\diagnose.ps1
```

## Implementation Guidelines

### Error Detection Patterns

- DNS failures: `Could not resolve host`, `getaddrinfo failed`
- Connection failures: `Connection refused`, `Connection timed out`
- TLS failures: `SSL certificate problem`, `SSL handshake failed`
- Auth failures: HTTP 401, 403 responses

### Configuration File Locations

**macOS/Linux:**
- `~/.config/claude-code/`
- `~/.claude-code/`
- Environment: `~/.zshrc`, `~/.bashrc`, `~/.profile`

**Windows:**
- `%APPDATA%\claude-code\`
- `%USERPROFILE%\.claude-code\`
- Environment: User/System environment variables via Registry

### Claude Code Binary Locations

**macOS:**
- Homebrew: `/opt/homebrew/bin/claude` or `/usr/local/bin/claude`
- npm global: `~/.npm-global/bin/claude` or `/usr/local/bin/claude`

**Windows:**
- npm global: `%APPDATA%\npm\claude.cmd`
- Manual install: Check `PATH` directories

**Version detection:**
```bash
claude --version
```

## Output Format

Diagnostic output should be:
1. **Structured**: Clear sections for each check
2. **Actionable**: Provide specific fix instructions
3. **Colored** (optional): Use terminal colors for warnings/errors
4. **Copy-paste friendly**: Include exact commands to fix issues
