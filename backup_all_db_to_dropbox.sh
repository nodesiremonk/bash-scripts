#!/bin/bash
set -uo pipefail
# Note: -e is intentionally omitted so a single DB failure does not abort the rest.

# ---------------------------------------------------------------------------
# Multi-DB Backup Orchestrator
# ---------------------------------------------------------------------------
# Calls backup.sh once per .env file found in ENV_DIR.
# Each database gets its own .env file, e.g.:
#   /root/backup/envs/production.env
#   /root/backup/envs/analytics.env
#   /root/backup/envs/staging.env
#
# Usage: ./backup_all.sh [/path/to/envs/dir]
#        Defaults to ./envs/ relative to this script.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
ENV_DIR="${1:-$SCRIPT_DIR/envs}"

# ── Sanity checks ────────────────────────────────────────────────────────────
if [[ ! -x "$BACKUP_SCRIPT" ]]; then
    echo "[ERROR] backup.sh not found or not executable: $BACKUP_SCRIPT" >&2
    exit 1
fi

if [[ ! -d "$ENV_DIR" ]]; then
    echo "[ERROR] Env directory not found: $ENV_DIR" >&2
    exit 1
fi

# ── Collect .env files ───────────────────────────────────────────────────────
mapfile -t ENV_FILES < <(find "$ENV_DIR" -maxdepth 1 -name "*.env" | sort)

if [[ ${#ENV_FILES[@]} -eq 0 ]]; then
    echo "[ERROR] No .env files found in $ENV_DIR" >&2
    exit 1
fi

echo "[INFO] Found ${#ENV_FILES[@]} database config(s) in $ENV_DIR"
echo ""

# ── Run backups ──────────────────────────────────────────────────────────────
declare -a FAILED=()
declare -a SUCCEEDED=()

for env_file in "${ENV_FILES[@]}"; do
    name="$(basename "$env_file" .env)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[INFO] Backing up: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if "$BACKUP_SCRIPT" "$env_file"; then
        SUCCEEDED+=("$name")
    else
        echo "[ERROR] Backup failed for: $name" >&2
        FAILED+=("$name")
    fi

    echo ""
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[SUMMARY] ${#SUCCEEDED[@]} succeeded, ${#FAILED[@]} failed"

if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
    echo "[OK]"
    for name in "${SUCCEEDED[@]}"; do
        echo "    ✓ $name"
    done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "[FAILED]"
    for name in "${FAILED[@]}"; do
        echo "    ✗ $name"
    done
    exit 1
fi

exit 0
