#!/usr/bin/env bash
# vault-check.sh — Public safety check for a skill folder
# Usage: scripts/vault-check.sh <skill-folder-path>
#
# Scans for content that should not appear in a public repository.
# Exits 0 if clean, 1 if issues found.

set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: vault-check.sh <skill-folder-path>"
  exit 1
fi

ISSUES=0

# Patterns that indicate personal or sensitive content
SENSITIVE_PATTERNS=(
  # Hardcoded personal home dirs (catches /Users/specificname/ but not /Users/{user}/)
  '/Users/[A-Za-z][A-Za-z0-9_-]*/'
  # API key patterns
  'sk-[A-Za-z0-9]{20,}'
  'ghp_[A-Za-z0-9]{36}'
  'gho_[A-Za-z0-9]{36}'
  'Bearer [A-Za-z0-9._-]{20,}'
  # Generic secret patterns
  'api[_-]?key\s*[:=]\s*["\x27][A-Za-z0-9._-]{16,}'
  'secret\s*[:=]\s*["\x27][A-Za-z0-9._-]{16,}'
  'password\s*[:=]\s*["\x27][^"\x27]{8,}'
  # Private IPs / internal URLs
  '192\.168\.[0-9]+\.[0-9]+'
  '10\.[0-9]+\.[0-9]+\.[0-9]+'
  'localhost:[0-9]{4,5}'
)

# Allowlist patterns (these are OK even if they match the above)
# e.g., /Users/{user}/ is a generic placeholder
ALLOWLIST=(
  '/Users/\{user\}/'
  '/Users/\$USER/'
  'localhost:3000'
  'localhost:8080'
)

echo "Checking: $TARGET"

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
  # Search recursively, excluding .git and versions/ (versions are already reviewed)
  matches=$(grep -rl --include="*.md" --include="*.json" --include="*.sh" \
    -E "$pattern" "$TARGET" 2>/dev/null || true)

  if [[ -n "$matches" ]]; then
    # Check against allowlist
    for file in $matches; do
      content=$(grep -E "$pattern" "$file" 2>/dev/null || true)
      safe=false
      for allow in "${ALLOWLIST[@]}"; do
        if echo "$content" | grep -qE "$allow"; then
          safe=true
          break
        fi
      done
      if [[ "$safe" == "false" ]]; then
        echo "  WARN [$pattern] in $file"
        ISSUES=$((ISSUES + 1))
      fi
    done
  fi
done

if [[ $ISSUES -eq 0 ]]; then
  echo "  OK — no issues found"
  exit 0
else
  echo "  $ISSUES issue(s) found — review before committing"
  exit 1
fi
