# Claude Code Diagnostic Tool for Windows
# Diagnoses connectivity, authentication, and installation issues

param(
    [switch]$Verbose,
    [switch]$Fix,
    [string]$Output = "",
    [switch]$Help
)

# Configuration
$API_SERVER = "https://claude-code.club/api"
$API_ENDPOINT = "$API_SERVER/v1/models"
$EXPECTED_BASE_URL = "https://claude-code.club/api"

# Global state
$script:IssuesFound = @()
$script:Recommendations = @()
$script:VerboseMode = $Verbose
$script:AutoFix = $Fix

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================"
    Write-Host $Message
    Write-Host "========================================"
}

function Write-Section {
    param([string]$Number, [string]$Title)
    Write-Host ""
    Write-Host "[$Number] $Title"
    Write-Host "----------------------------------------"
}

function Write-Check {
    param(
        [string]$Status,
        [string]$Message
    )

    switch ($Status) {
        "ok" {
            Write-Host "✓ $Message"
        }
        "warn" {
            Write-Host "⚠ $Message"
            $script:IssuesFound += "WARNING: $Message"
        }
        "error" {
            Write-Host "✗ $Message"
            $script:IssuesFound += "ERROR: $Message"
        }
        default {
            Write-Host "  $Message"
        }
    }
}

function Add-Recommendation {
    param([string]$Message)
    $script:Recommendations += $Message
}

function Write-VerboseLog {
    param([string]$Message)
    if ($script:VerboseMode) {
        Write-Host "  [VERBOSE] $Message"
    }
}

# ============================================================================
# Diagnostic Functions
# ============================================================================

function Test-Environment {
    Write-Section "1" "Environment Check"

    # Check for curl
    $curlCmd = Get-Command curl -ErrorAction SilentlyContinue
    if ($curlCmd) {
        try {
            $curlVersion = & curl --version 2>&1 | Select-Object -First 1
            Write-Check "ok" "curl: Found ($curlVersion)"
            Write-VerboseLog "curl path: $($curlCmd.Source)"
        } catch {
            Write-Check "warn" "curl: Found but unable to get version"
        }
    } else {
        Write-Check "error" "curl: Not found (required for diagnostics)"
        Add-Recommendation "Install curl: Download from https://curl.se/windows/ or use 'winget install curl'"
        return $false
    }

    # Check for jq (optional)
    $jqCmd = Get-Command jq -ErrorAction SilentlyContinue
    if ($jqCmd) {
        Write-Check "ok" "jq: Found (optional JSON parser)"
        Write-VerboseLog "jq path: $($jqCmd.Source)"
    } else {
        Write-Check "info" "jq: Not found (optional, install for better output formatting)"
        Write-VerboseLog "Install jq: winget install jqlang.jq"
    }

    # Check PowerShell version
    Write-Check "info" "PowerShell: $($PSVersionTable.PSVersion)"
    Write-VerboseLog "PowerShell Edition: $($PSVersionTable.PSEdition)"

    return $true
}

function Test-Authentication {
    Write-Section "2" "Authentication Diagnostics"

    # Check ANTHROPIC_AUTH_TOKEN
    $authToken = $env:ANTHROPIC_AUTH_TOKEN
    if (-not [string]::IsNullOrEmpty($authToken)) {
        $tokenPreview = $authToken.Substring(0, [Math]::Min(10, $authToken.Length)) + "..." +
                       $authToken.Substring([Math]::Max(0, $authToken.Length - 4))
        Write-Check "ok" "ANTHROPIC_AUTH_TOKEN: Set ($tokenPreview)"
        Write-VerboseLog "Token length: $($authToken.Length)"
    } else {
        Write-Check "error" "ANTHROPIC_AUTH_TOKEN: Not set (required)"
        Add-Recommendation "Set ANTHROPIC_AUTH_TOKEN: `$env:ANTHROPIC_AUTH_TOKEN='your-token-here'"
        Add-Recommendation "For persistence, set in System Environment Variables via System Properties"
    }

    # Check for incorrect ANTHROPIC_API_KEY
    if (-not [string]::IsNullOrEmpty($env:ANTHROPIC_API_KEY)) {
        Write-Check "warn" "ANTHROPIC_API_KEY: Detected (should NOT be used with claude-code.club)"
        Add-Recommendation "Remove ANTHROPIC_API_KEY from environment variables"

        if ($script:AutoFix) {
            Write-VerboseLog "Auto-fix: Would remove ANTHROPIC_API_KEY (implementation pending)"
        }
    } else {
        Write-Check "ok" "ANTHROPIC_API_KEY: Not set (correct)"
    }

    # Check ANTHROPIC_BASE_URL
    $baseUrl = $env:ANTHROPIC_BASE_URL
    if (-not [string]::IsNullOrEmpty($baseUrl)) {
        if ($baseUrl -eq $EXPECTED_BASE_URL) {
            Write-Check "ok" "ANTHROPIC_BASE_URL: Correctly set to $baseUrl"
        } else {
            Write-Check "warn" "ANTHROPIC_BASE_URL: Set to '$baseUrl' (expected: $EXPECTED_BASE_URL)"
            Add-Recommendation "Update ANTHROPIC_BASE_URL: `$env:ANTHROPIC_BASE_URL='$EXPECTED_BASE_URL'"
        }
    } else {
        Write-Check "info" "ANTHROPIC_BASE_URL: Not set (optional, defaults to claude-code.club)"
    }

    # Check for official Anthropic Console cache
    $consoleCacheLocations = @(
        "$env:APPDATA\Claude",
        "$env:LOCALAPPDATA\Claude",
        "$env:USERPROFILE\.anthropic"
    )

    foreach ($cacheDir in $consoleCacheLocations) {
        if (Test-Path $cacheDir) {
            Write-Check "warn" "Official Console cache detected: $cacheDir (may cause conflicts)"
            Write-VerboseLog "Directory exists: $cacheDir"
            Add-Recommendation "Consider backing up and removing: $cacheDir"
        }
    }
}

function Test-Network {
    Write-Section "3" "Network Diagnostics"

    $domain = "claude-code.club"

    # DNS Resolution
    Write-VerboseLog "Testing DNS resolution for $domain..."
    try {
        $dnsResult = Resolve-DnsName -Name $domain -ErrorAction Stop
        $ipAddress = $dnsResult | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1 -ExpandProperty IPAddress
        Write-Check "ok" "DNS Resolution: $domain → $ipAddress"
        Write-VerboseLog "DNS lookup successful"
    } catch {
        Write-Check "error" "DNS Resolution: Failed to resolve $domain"
        Add-Recommendation "Check DNS settings. Try: ipconfig /flushdns or check network adapter DNS settings"
        Add-Recommendation "Test with: Resolve-DnsName $domain"
    }

    # TLS/SSL Test
    Write-VerboseLog "Testing TLS handshake..."
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($domain, 443)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
        $sslStream.AuthenticateAsClient($domain)

        Write-Check "ok" "TLS Handshake: Successful"
        Write-VerboseLog "Certificate verification passed"

        $sslStream.Close()
        $tcpClient.Close()
    } catch {
        Write-Check "error" "TLS Handshake: Failed - $($_.Exception.Message)"
        Add-Recommendation "Check firewall settings and ensure TLS 1.2+ is enabled"
        Add-Recommendation "Verify system date/time is correct (certificate validation depends on it)"
        Write-VerboseLog "Error details: $($_.Exception)"
    }

    # API Connectivity Test
    Write-VerboseLog "Testing API endpoint: $API_ENDPOINT"

    if (-not [string]::IsNullOrEmpty($env:ANTHROPIC_AUTH_TOKEN)) {
        try {
            $headers = @{
                "x-api-key" = $env:ANTHROPIC_AUTH_TOKEN
                "anthropic-version" = "2023-06-01"
            }

            if ($script:VerboseMode) {
                Write-Check "info" "Running verbose curl test..."
                $curlArgs = @(
                    "-v",
                    $API_ENDPOINT,
                    "--header", "x-api-key: $env:ANTHROPIC_AUTH_TOKEN",
                    "--header", "anthropic-version: 2023-06-01",
                    "--max-time", "10"
                )

                $curlOutput = & curl $curlArgs 2>&1 | Out-String
                Write-Host "  --- Curl Output ---"
                Write-Host $curlOutput
                Write-Host "  --- End Curl Output ---"

                # Extract HTTP code from verbose output
                $httpCode = if ($curlOutput -match "< HTTP/[\d.]+ (\d+)") { $matches[1] } else { "000" }
            } else {
                $curlArgs = @(
                    "-s",
                    "-w", "`n%{http_code}",
                    $API_ENDPOINT,
                    "--header", "x-api-key: $env:ANTHROPIC_AUTH_TOKEN",
                    "--header", "anthropic-version: 2023-06-01",
                    "--max-time", "10"
                )

                $curlOutput = & curl $curlArgs 2>&1 | Out-String
                $httpCode = ($curlOutput -split "`n")[-1].Trim()
            }

            Write-VerboseLog "HTTP Status Code: $httpCode"

            switch ($httpCode) {
                "200" {
                    Write-Check "ok" "API Connection: Successful (HTTP $httpCode)"
                }
                "401" {
                    Write-Check "error" "API Connection: Authentication failed (HTTP 401)"
                    Add-Recommendation "Verify ANTHROPIC_AUTH_TOKEN is valid and not expired"
                }
                "403" {
                    Write-Check "error" "API Connection: Access forbidden (HTTP 403)"
                    Add-Recommendation "Check if your token has proper permissions"
                }
                "404" {
                    Write-Check "error" "API Connection: Endpoint not found (HTTP 404)"
                    Add-Recommendation "Verify API endpoint URL: $API_ENDPOINT"
                }
                default {
                    if ([string]::IsNullOrEmpty($httpCode) -or $httpCode -eq "000") {
                        Write-Check "error" "API Connection: Connection failed (timeout or network error)"
                        Add-Recommendation "Check network connectivity and firewall settings"

                        if ($curlOutput -match "Could not resolve host") {
                            Add-Recommendation "DNS resolution failed - check your DNS settings"
                        }
                        if ($curlOutput -match "Connection refused") {
                            Add-Recommendation "Connection refused - service may be down or blocked"
                        }
                        if ($curlOutput -match "SSL|certificate") {
                            Add-Recommendation "SSL/TLS error - check certificates and system time"
                        }
                    } else {
                        Write-Check "warn" "API Connection: Unexpected response (HTTP $httpCode)"
                        Write-VerboseLog "Response: $curlOutput"
                    }
                }
            }
        } catch {
            Write-Check "error" "API Connection: Failed - $($_.Exception.Message)"
            Add-Recommendation "Check network connectivity and firewall settings"
            Write-VerboseLog "Error details: $($_.Exception)"
        }
    } else {
        Write-Check "info" "API Connection: Skipped (no ANTHROPIC_AUTH_TOKEN set)"
    }
}

function Test-Installation {
    Write-Section "4" "Installation Discovery"

    # Find Claude Code binary
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue

    if ($claudeCmd) {
        Write-Check "ok" "Claude Code: Found at $($claudeCmd.Source)"

        # Get version
        try {
            $version = & claude --version 2>&1
            Write-Check "info" "Version: $version"
            Write-VerboseLog "Binary path: $($claudeCmd.Source)"
        } catch {
            Write-Check "warn" "Unable to determine version"
        }

        # Detect installation method
        if ($claudeCmd.Source -match "npm") {
            Write-Check "info" "Installation method: npm"
        } else {
            Write-Check "info" "Installation method: Unknown (manual or other)"
        }
    } else {
        Write-Check "error" "Claude Code: Not found in PATH"
        Add-Recommendation "Install Claude Code: npm install -g @anthropic-ai/claude-code"
    }

    # Check common npm locations
    $npmGlobalPath = "$env:APPDATA\npm"
    if (Test-Path "$npmGlobalPath\claude.cmd") {
        if (-not $claudeCmd) {
            Write-Check "warn" "Claude Code found in npm global but not in PATH: $npmGlobalPath\claude.cmd"
            Add-Recommendation "Add npm global directory to PATH: $npmGlobalPath"
        }
    }
}

function Test-Configuration {
    Write-Section "5" "Configuration Files"

    $configLocations = @(
        "$env:APPDATA\claude-code",
        "$env:LOCALAPPDATA\claude-code",
        "$env:USERPROFILE\.claude-code"
    )

    # Check config directories
    $configFound = $false
    foreach ($configDir in $configLocations) {
        if (Test-Path $configDir) {
            Write-Check "ok" "Config directory: $configDir"
            Write-VerboseLog "Contents: $(Get-ChildItem $configDir -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)"
            $configFound = $true
        }
    }

    if (-not $configFound) {
        Write-Check "info" "No Claude Code config directories found"
    }

    # Check environment variables via registry
    Write-Check "info" "Checking environment variables for Claude Code settings..."

    $envPaths = @(
        "HKCU:\Environment",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    )

    foreach ($path in $envPaths) {
        try {
            $envVars = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            $anthropicVars = $envVars.PSObject.Properties | Where-Object { $_.Name -like "ANTHROPIC*" }

            if ($anthropicVars) {
                Write-Check "ok" "Found ANTHROPIC variables in registry: $path"
                if ($script:VerboseMode) {
                    Write-Host "  Relevant variables:"
                    foreach ($var in $anthropicVars) {
                        Write-Host "    $($var.Name) = $($var.Value)"
                    }
                }
            }
        } catch {
            Write-VerboseLog "Unable to read registry path: $path"
        }
    }
}

# ============================================================================
# Report Generation
# ============================================================================

function Write-Report {
    Write-Header "Diagnostic Summary"

    Write-Host ""
    if ($script:IssuesFound.Count -eq 0) {
        Write-Host "✓ No critical issues detected!"
    } else {
        Write-Host "Issues Found: $($script:IssuesFound.Count)"
        Write-Host ""
        foreach ($issue in $script:IssuesFound) {
            Write-Host "  • $issue"
        }
    }

    if ($script:Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Header "Recommendations"
        Write-Host ""
        $counter = 1
        foreach ($rec in $script:Recommendations) {
            Write-Host "$counter. $rec"
            $counter++
        }
    }

    Write-Host ""
    Write-Header "Diagnostic Complete"
}

# ============================================================================
# Main Execution
# ============================================================================

function Show-Help {
    @"
Claude Code Diagnostic Tool

Usage: .\diagnose.ps1 [OPTIONS]

Diagnoses connectivity, authentication, and installation issues with Claude Code.

OPTIONS:
    -Verbose           Enable detailed logging output
    -Fix              Attempt to automatically fix common issues
    -Output FILE      Save diagnostic report to FILE
    -Help             Display this help message

EXAMPLES:
    .\diagnose.ps1                          # Run basic diagnostics
    .\diagnose.ps1 -Verbose                 # Run with detailed logging
    .\diagnose.ps1 -Output report.txt       # Save results to file
    .\diagnose.ps1 -Verbose -Fix            # Run with auto-fix and detailed logging

For more information, visit: https://github.com/anthropics/claude-code

"@
}

function Main {
    if ($Help) {
        Show-Help
        exit 0
    }

    # Setup output redirection if requested
    if (-not [string]::IsNullOrEmpty($Output)) {
        Start-Transcript -Path $Output -Force | Out-Null
    }

    try {
        # Run diagnostics
        Write-Header "Claude Code Diagnostic Tool"
        Write-Host "Target API: $API_SERVER"
        Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

        $envOk = Test-Environment
        if ($envOk) {
            Test-Authentication
            Test-Network
            Test-Installation
            Test-Configuration
            Write-Report
        } else {
            Write-Host ""
            Write-Host "Cannot proceed with diagnostics due to missing required tools."
            exit 1
        }

        # Exit code based on issues found
        if ($script:IssuesFound.Count -gt 0) {
            exit 1
        } else {
            exit 0
        }
    } finally {
        if (-not [string]::IsNullOrEmpty($Output)) {
            Stop-Transcript | Out-Null
            Write-Host ""
            Write-Host "Diagnostic report saved to: $Output"
        }
    }
}

# Entry point
Main
