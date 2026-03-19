#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# PostgreSQL Backup Script
# ---------------------------------------------------------------------------
# Loads credentials from a .env file (never hard-coded).
# Usage: ./backup.sh [/path/to/.env]   (defaults to same dir as script)
#
# Encryption: the .tar.gz is encrypted with GPG (AES-256) before upload.
# The passphrase is read from the file path set in BACKUP_PASSPHRASE_FILE
# inside your .env — never stored as a plain string.
#
# To generate a passphrase file (do this once, keep it safe):
#   openssl rand -base64 48 > /root/.backup_passphrase
#   chmod 600 /root/.backup_passphrase
#
# To decrypt a backup manually:
#   gpg --batch --passphrase-file /root/.backup_passphrase \
#       --decrypt Monday.tar.gz.gpg > Monday.tar.gz
# ---------------------------------------------------------------------------

# ── Config & credential loading ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[ERROR] Env file not found: $ENV_FILE" >&2
    exit 1
fi

# Restrict env file permissions on every run
chmod 600 "$ENV_FILE"

# Load only expected variables; ignore comments and blank lines
while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]]               && continue
    case "$key" in
        DB_HOST|DB_PORT|DB_NAME|DB_USER|DB_PASSWORD|DB_CONTAINER|\
        DB_SCHEMA|DROPBOX_DIR|BACKUP_DST|BACKUP_PASSPHRASE_FILE)
            printf -v "$key" '%s' "$value"
            ;;
    esac
done < "$ENV_FILE"

# ── Validate required variables ──────────────────────────────────────────────
required_vars=(DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_CONTAINER DB_SCHEMA DROPBOX_DIR BACKUP_DST BACKUP_PASSPHRASE_FILE)
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "[ERROR] Required variable '$var' is not set in $ENV_FILE" >&2
        exit 1
    fi
done

# ── Validate DB_PORT is numeric ──────────────────────────────────────────────
if ! [[ "$DB_PORT" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] DB_PORT must be numeric." >&2
    exit 1
fi

# ── Validate passphrase file ─────────────────────────────────────────────────
if [[ ! -f "$BACKUP_PASSPHRASE_FILE" ]]; then
    echo "[ERROR] Passphrase file not found: $BACKUP_PASSPHRASE_FILE" >&2
    echo "[INFO]  Generate one with:" >&2
    echo "          openssl rand -base64 48 > $BACKUP_PASSPHRASE_FILE" >&2
    echo "          chmod 600 $BACKUP_PASSPHRASE_FILE" >&2
    exit 1
fi

PASSPHRASE_PERMS="$(stat -c '%a' "$BACKUP_PASSPHRASE_FILE")"
if [[ "$PASSPHRASE_PERMS" != "600" ]]; then
    echo "[ERROR] Passphrase file must have permissions 600 (currently $PASSPHRASE_PERMS)." >&2
    echo "[INFO]  Fix with: chmod 600 $BACKUP_PASSPHRASE_FILE" >&2
    exit 1
fi

# ── Dependency checks ────────────────────────────────────────────────────────
for cmd in docker tar gpg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[ERROR] Required command not found: $cmd" >&2
        exit 1
    fi
done

UPLOADER="$SCRIPT_DIR/dropbox_uploader.sh"
if [[ ! -x "$UPLOADER" ]]; then
    echo "[ERROR] dropbox_uploader.sh not found or not executable: $UPLOADER" >&2
    exit 1
fi

# ── Prepare secure temp workspace ────────────────────────────────────────────
WORK_DIR="$(mktemp -d)"
# Always clean up the temp dir on exit (success or failure)
trap 'rm -rf "$WORK_DIR"' EXIT

chmod 700 "$WORK_DIR"

NOW="$(date +"%A")"
SQL_FILE="$WORK_DIR/${NOW}-Databases.sql"
ARCHIVE_FILE="$WORK_DIR/${NOW}.tar.gz"
ENCRYPTED_FILE="$WORK_DIR/${NOW}.tar.gz.gpg"

# ── Dump the database ────────────────────────────────────────────────────────
echo "[INFO] Starting pg_dump …"

# Pass the password via PGPASSWORD env var instead of embedding it in the URL
# so it does not appear in the process list.
if ! docker run --rm \
        -e PGPASSWORD="$DB_PASSWORD" \
        "$DB_CONTAINER" \
        pg_dump \
            --host="$DB_HOST" \
            --port="$DB_PORT" \
            --username="$DB_USER" \
            --dbname="$DB_NAME" \
            --schema="$DB_SCHEMA" \
        > "$SQL_FILE"; then
    echo "[ERROR] pg_dump failed." >&2
    exit 1
fi

# ── Compress ─────────────────────────────────────────────────────────────────
echo "[INFO] Compressing backup …"
if ! tar -czf "$ARCHIVE_FILE" -C "$WORK_DIR" "${NOW}-Databases.sql"; then
    echo "[ERROR] Compression failed." >&2
    exit 1
fi

# Uncompressed SQL no longer needed
rm -f "$SQL_FILE"

# ── Encrypt ──────────────────────────────────────────────────────────────────
echo "[INFO] Encrypting backup …"
if ! gpg --batch \
         --yes \
         --passphrase-file "$BACKUP_PASSPHRASE_FILE" \
         --cipher-algo AES256 \
         --symmetric \
         --output "$ENCRYPTED_FILE" \
         "$ARCHIVE_FILE"; then
    echo "[ERROR] Encryption failed." >&2
    exit 1
fi

# Remove the plaintext archive now that we have the encrypted copy
rm -f "$ARCHIVE_FILE"

# ── Upload ───────────────────────────────────────────────────────────────────
echo "[INFO] Uploading encrypted backup to Dropbox …"
if ! "$UPLOADER" upload "$ENCRYPTED_FILE" "$DROPBOX_DIR/$NOW.tar.gz.gpg"; then
    echo "[ERROR] Dropbox upload failed." >&2
    exit 1
fi

echo "[INFO] Backup complete: $DROPBOX_DIR/$NOW.tar.gz.gpg"
# Temp dir (and any remaining files) are removed automatically by the trap
