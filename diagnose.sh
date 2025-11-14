#!/usr/bin/env zsh

# Claude Code Diagnostic Tool for macOS/Linux
# Diagnoses connectivity, authentication, and installation issues

set -o pipefail

# Configuration
API_SERVER="https://claude-code.club/api"
API_ENDPOINT="${API_SERVER}/v1/models"
EXPECTED_BASE_URL="https://claude-code.club/api"

# Global flags
VERBOSE=false
AUTO_FIX=false
OUTPUT_FILE=""
ISSUES_FOUND=()
RECOMMENDATIONS=()

# Colors disabled (plain text output)
RESET=""
RED=""
GREEN=""
YELLOW=""
BLUE=""

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

print_section() {
    echo ""
    echo "[$1] $2"
    echo "----------------------------------------"
}

print_check() {
    local check_status="$1"
    local message="$2"
    if [[ "$check_status" == "ok" ]]; then
        echo "✓ $message"
    elif [[ "$check_status" == "warn" ]]; then
        echo "⚠ $message"
        ISSUES_FOUND+=("WARNING: $message")
    elif [[ "$check_status" == "error" ]]; then
        echo "✗ $message"
        ISSUES_FOUND+=("ERROR: $message")
    else
        echo "  $message"
    fi
}

add_recommendation() {
    RECOMMENDATIONS+=("$1")
}

verbose_log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "  [VERBOSE] $1"
    fi
}

# ============================================================================
# Diagnostic Functions
# ============================================================================

check_environment() {
    print_section "1" "Environment Check"

    # Check for curl
    if command -v curl &> /dev/null; then
        local curl_version=$(curl --version | head -n1)
        print_check "ok" "curl: Found ($curl_version)"
        verbose_log "curl path: $(command -v curl)"
    else
        print_check "error" "curl: Not found (required for diagnostics)"
        add_recommendation "Install curl: brew install curl (macOS) or use your package manager"
        return 1
    fi

    # Check for jq (optional)
    if command -v jq &> /dev/null; then
        print_check "ok" "jq: Found (optional JSON parser)"
        verbose_log "jq path: $(command -v jq)"
    else
        print_check "info" "jq: Not found (optional, install for better output formatting)"
        verbose_log "Install jq: brew install jq"
    fi

    # Check shell
    print_check "info" "Shell: $SHELL"
    verbose_log "Shell version: $ZSH_VERSION"
}

check_authentication() {
    print_section "2" "Authentication Diagnostics"

    # Check ANTHROPIC_AUTH_TOKEN
    if [[ -n "$ANTHROPIC_AUTH_TOKEN" ]]; then
        local token_preview="${ANTHROPIC_AUTH_TOKEN:0:10}...${ANTHROPIC_AUTH_TOKEN: -4}"
        print_check "ok" "ANTHROPIC_AUTH_TOKEN: Set ($token_preview)"
        verbose_log "Token length: ${#ANTHROPIC_AUTH_TOKEN}"
    else
        print_check "error" "ANTHROPIC_AUTH_TOKEN: Not set (required)"
        add_recommendation "Set ANTHROPIC_AUTH_TOKEN: export ANTHROPIC_AUTH_TOKEN='your-token-here'"
        add_recommendation "Add to ~/.zshrc for persistence: echo 'export ANTHROPIC_AUTH_TOKEN=\"your-token\"' >> ~/.zshrc"
    fi

    # Check for incorrect ANTHROPIC_API_KEY
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        print_check "warn" "ANTHROPIC_API_KEY: Detected (should NOT be used with claude-code.club)"
        add_recommendation "Remove ANTHROPIC_API_KEY from your environment (check ~/.zshrc, ~/.bashrc, ~/.profile)"

        if [[ "$AUTO_FIX" == true ]]; then
            verbose_log "Auto-fix: Would unset ANTHROPIC_API_KEY (implementation pending)"
        fi
    else
        print_check "ok" "ANTHROPIC_API_KEY: Not set (correct)"
    fi

    # Check ANTHROPIC_BASE_URL
    if [[ -n "$ANTHROPIC_BASE_URL" ]]; then
        if [[ "$ANTHROPIC_BASE_URL" == "$EXPECTED_BASE_URL" ]]; then
            print_check "ok" "ANTHROPIC_BASE_URL: Correctly set to $ANTHROPIC_BASE_URL"
        else
            print_check "warn" "ANTHROPIC_BASE_URL: Set to '$ANTHROPIC_BASE_URL' (expected: $EXPECTED_BASE_URL)"
            add_recommendation "Update ANTHROPIC_BASE_URL: export ANTHROPIC_BASE_URL='$EXPECTED_BASE_URL'"
        fi
    else
        print_check "info" "ANTHROPIC_BASE_URL: Not set (optional, defaults to claude-code.club)"
    fi

    # Check for official Anthropic Console cache
    local console_cache_locations=(
        "$HOME/.config/claude"
        "$HOME/.anthropic"
        "$HOME/Library/Application Support/Claude"
    )

    for cache_dir in "${console_cache_locations[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            print_check "warn" "Official Console cache detected: $cache_dir (may cause conflicts)"
            verbose_log "Contents: $(ls -la "$cache_dir" 2>/dev/null || echo 'Permission denied')"
            add_recommendation "Consider backing up and removing: $cache_dir"
        fi
    done
}

check_network() {
    print_section "3" "Network Diagnostics"

    local domain="claude-code.club"

    # DNS Resolution
    verbose_log "Testing DNS resolution for $domain..."
    if host "$domain" &> /dev/null 2>&1 || nslookup "$domain" &> /dev/null 2>&1; then
        local ip_address=$(host "$domain" 2>/dev/null | grep "has address" | head -n1 | awk '{print $NF}' || echo "unknown")
        print_check "ok" "DNS Resolution: $domain → $ip_address"
        verbose_log "DNS lookup successful"
    else
        print_check "error" "DNS Resolution: Failed to resolve $domain"
        add_recommendation "Check DNS settings. Try: sudo dscacheutil -flushcache (macOS) or check /etc/resolv.conf"
        add_recommendation "Test with: host $domain or nslookup $domain"
    fi

    # TLS/SSL Test
    verbose_log "Testing TLS handshake..."
    local tls_test=$(echo | openssl s_client -connect "${domain}:443" -servername "$domain" 2>&1)

    if echo "$tls_test" | grep -q "Verify return code: 0"; then
        print_check "ok" "TLS Handshake: Successful"
        verbose_log "Certificate verification passed"
    else
        if echo "$tls_test" | grep -qi "certificate"; then
            print_check "error" "TLS Handshake: Certificate verification failed"
            add_recommendation "Check system certificates. Try: security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain (macOS)"
        else
            print_check "warn" "TLS Handshake: Unable to verify (may be blocked)"
            add_recommendation "Check firewall settings and network connectivity"
        fi
        verbose_log "OpenSSL output: $tls_test"
    fi

    # API Connectivity Test
    verbose_log "Testing API endpoint: $API_ENDPOINT"

    if [[ -n "$ANTHROPIC_AUTH_TOKEN" ]]; then
        local curl_output
        local http_code

        if [[ "$VERBOSE" == true ]]; then
            print_check "info" "Running verbose curl test..."
            curl_output=$(curl -v "$API_ENDPOINT" \
                --header "x-api-key: $ANTHROPIC_AUTH_TOKEN" \
                --header "anthropic-version: 2023-06-01" \
                --max-time 10 \
                2>&1)

            http_code=$(echo "$curl_output" | grep "< HTTP" | tail -n1 | awk '{print $3}')
            echo "  --- Curl Output ---"
            echo "$curl_output"
            echo "  --- End Curl Output ---"
        else
            curl_output=$(curl -s -w "\n%{http_code}" "$API_ENDPOINT" \
                --header "x-api-key: $ANTHROPIC_AUTH_TOKEN" \
                --header "anthropic-version: 2023-06-01" \
                --max-time 10 \
                2>&1)
            http_code=$(echo "$curl_output" | tail -n1)
        fi

        verbose_log "HTTP Status Code: $http_code"

        case "$http_code" in
            200)
                print_check "ok" "API Connection: Successful (HTTP $http_code)"
                ;;
            401)
                print_check "error" "API Connection: Authentication failed (HTTP 401)"
                add_recommendation "Verify ANTHROPIC_AUTH_TOKEN is valid and not expired"
                ;;
            403)
                print_check "error" "API Connection: Access forbidden (HTTP 403)"
                add_recommendation "Check if your token has proper permissions"
                ;;
            404)
                print_check "error" "API Connection: Endpoint not found (HTTP 404)"
                add_recommendation "Verify API endpoint URL: $API_ENDPOINT"
                ;;
            000|"")
                print_check "error" "API Connection: Connection failed (timeout or network error)"
                add_recommendation "Check network connectivity and firewall settings"
                if [[ "$curl_output" =~ "Could not resolve host" ]]; then
                    add_recommendation "DNS resolution failed - check your DNS settings"
                elif [[ "$curl_output" =~ "Connection refused" ]]; then
                    add_recommendation "Connection refused - service may be down or blocked"
                elif [[ "$curl_output" =~ "SSL" ]] || [[ "$curl_output" =~ "certificate" ]]; then
                    add_recommendation "SSL/TLS error - check certificates and system time"
                fi
                ;;
            *)
                print_check "warn" "API Connection: Unexpected response (HTTP $http_code)"
                verbose_log "Response: $curl_output"
                ;;
        esac
    else
        print_check "info" "API Connection: Skipped (no ANTHROPIC_AUTH_TOKEN set)"
    fi
}

check_installation() {
    print_section "4" "Installation Discovery"

    # Find Claude Code binary
    local claude_locations=(
        "/opt/homebrew/bin/claude"
        "/usr/local/bin/claude"
        "$HOME/.npm-global/bin/claude"
        "$HOME/.npm/bin/claude"
        "/usr/bin/claude"
    )

    local found_locations=()

    # Check PATH first
    if command -v claude &> /dev/null; then
        local claude_path=$(command -v claude)
        print_check "ok" "Claude Code: Found at $claude_path"
        found_locations+=("$claude_path")

        # Get version
        local version=$(claude --version 2>/dev/null || echo "unknown")
        print_check "info" "Version: $version"
        verbose_log "Binary path: $claude_path"

        # Detect installation method
        if [[ "$claude_path" =~ "homebrew" ]]; then
            print_check "info" "Installation method: Homebrew"
        elif [[ "$claude_path" =~ "npm" ]]; then
            print_check "info" "Installation method: npm"
        else
            print_check "info" "Installation method: Unknown (manual or other)"
        fi
    else
        print_check "warn" "Claude Code: Not found in PATH"
    fi

    # Check other known locations
    for location in "${claude_locations[@]}"; do
        if [[ -f "$location" ]] && [[ ! " ${found_locations[@]} " =~ " ${location} " ]]; then
            print_check "warn" "Additional installation found: $location"
            verbose_log "Multiple installations detected - may cause version conflicts"
        fi
    done

    if [[ ${#found_locations[@]} -eq 0 ]]; then
        print_check "error" "No Claude Code installation found"
        add_recommendation "Install Claude Code: npm install -g @anthropic-ai/claude-code or brew install claude-code"
    elif [[ ${#found_locations[@]} -gt 1 ]]; then
        add_recommendation "Multiple Claude Code installations found - consider removing duplicates"
    fi
}

check_configuration() {
    print_section "5" "Configuration Files"

    local config_locations=(
        "$HOME/.config/claude-code"
        "$HOME/.claude-code"
    )

    local env_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.profile"
        "$HOME/.zshenv"
    )

    # Check config directories
    local config_found=false
    for config_dir in "${config_locations[@]}"; do
        if [[ -d "$config_dir" ]]; then
            print_check "ok" "Config directory: $config_dir"
            verbose_log "Contents: $(ls -la "$config_dir" 2>/dev/null | tail -n +4)"
            config_found=true
        fi
    done

    if [[ "$config_found" == false ]]; then
        print_check "info" "No Claude Code config directories found"
    fi

    # Check environment files for Claude Code settings
    print_check "info" "Checking environment files for Claude Code variables..."
    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            if grep -q "ANTHROPIC" "$env_file" 2>/dev/null; then
                print_check "ok" "Found ANTHROPIC variables in: $env_file"
                if [[ "$VERBOSE" == true ]]; then
                    echo "  Relevant lines:"
                    grep "ANTHROPIC" "$env_file" | sed 's/^/    /'
                fi
            fi
        fi
    done
}

# ============================================================================
# Report Generation
# ============================================================================

generate_report() {
    print_header "Diagnostic Summary"

    echo ""
    if [[ ${#ISSUES_FOUND[@]} -eq 0 ]]; then
        echo "✓ No critical issues detected!"
    else
        echo "Issues Found: ${#ISSUES_FOUND[@]}"
        echo ""
        for issue in "${ISSUES_FOUND[@]}"; do
            echo "  • $issue"
        done
    fi

    if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
        echo ""
        print_header "Recommendations"
        echo ""
        local counter=1
        for rec in "${RECOMMENDATIONS[@]}"; do
            echo "$counter. $rec"
            ((counter++))
        done
    fi

    echo ""
    print_header "Diagnostic Complete"

    # Save to file if requested
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo ""
        echo "Saving diagnostic report to: $OUTPUT_FILE"
        # The report will be saved by redirecting stdout
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

show_help() {
    cat << EOF
Claude Code Diagnostic Tool

Usage: $0 [OPTIONS]

Diagnoses connectivity, authentication, and installation issues with Claude Code.

OPTIONS:
    --verbose           Enable detailed logging output
    --fix              Attempt to automatically fix common issues
    --output FILE      Save diagnostic report to FILE
    --help             Display this help message

EXAMPLES:
    $0                          # Run basic diagnostics
    $0 --verbose                # Run with detailed logging
    $0 --output report.txt      # Save results to file
    $0 --verbose --fix          # Run with auto-fix and detailed logging

For more information, visit: https://github.com/anthropics/claude-code

EOF
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --fix|-f)
                AUTO_FIX=true
                shift
                ;;
            --output|-o)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Redirect output to file if requested
    if [[ -n "$OUTPUT_FILE" ]]; then
        exec > >(tee "$OUTPUT_FILE")
    fi

    # Run diagnostics
    print_header "Claude Code Diagnostic Tool"
    echo "Target API: $API_SERVER"
    echo "Date: $(date)"

    check_environment
    check_authentication
    check_network
    check_installation
    check_configuration
    generate_report

    # Exit code based on issues found
    if [[ ${#ISSUES_FOUND[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
