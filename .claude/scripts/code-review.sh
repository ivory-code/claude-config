#!/bin/bash

# Code Review Script for Claude Code
# Checks for anti-patterns, hardcoded secrets, and security issues

FILE_PATH="$1"

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Skip .env files (they are expected to contain secrets)
if [[ "$FILE_PATH" =~ \.env(\.|$) ]]; then
    exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Only check code files
if [[ ! "$EXT" =~ ^(js|jsx|ts|tsx|vue|py|java|go|rb|php)$ ]]; then
    exit 0
fi

# Read file content
CONTENT=$(cat "$FILE_PATH")

# Check for hardcoded secrets (API keys, tokens, passwords)
SECRETS_PATTERNS=(
    "api[_-]?key['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "api[_-]?secret['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "access[_-]?token['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "auth[_-]?token['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "password['\"]?\s*[:=]\s*['\"][^'\"]{3,}"
    "secret['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "private[_-]?key['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "Bearer [A-Za-z0-9._~+/-]+"
)

ISSUES=()

# Check for hardcoded secrets
for pattern in "${SECRETS_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -iE "$pattern" > /dev/null; then
        ISSUES+=("⚠️  SECURITY: Potential hardcoded secret detected (pattern: $pattern)")
    fi
done

# Check for common anti-patterns in JS/TS/Vue
if [[ "$EXT" =~ ^(js|jsx|ts|tsx|vue)$ ]]; then
    # Console.log in production code (excluding test files)
    if [[ ! "$FILE_PATH" =~ test|spec ]] && echo "$CONTENT" | grep -E "console\.(log|debug|info)" > /dev/null; then
        ISSUES+=("💡 ANTI-PATTERN: console.log found in non-test file")
    fi

    # Dangerous eval usage
    if echo "$CONTENT" | grep -E "\beval\s*\(" > /dev/null; then
        ISSUES+=("⚠️  SECURITY: eval() usage detected - potential security risk")
    fi

    # TODO/FIXME comments
    if echo "$CONTENT" | grep -iE "\/\/.*TODO|\/\/.*FIXME|\/\*.*TODO|\/\*.*FIXME" > /dev/null; then
        ISSUES+=("📝 NOTE: TODO/FIXME comments found")
    fi
fi

# Output results
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo ""
    echo "🔍 Code Review Results for: $FILE_PATH"
    echo "================================================"
    for issue in "${ISSUES[@]}"; do
        echo "$issue"
    done
    echo "================================================"
    echo ""
fi

exit 0
