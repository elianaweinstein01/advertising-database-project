#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; cd "$ROOT_DIR"

[ -f .env ] && set -a && . ./.env && set +a
PGHOST=${PGHOST:-localhost}; PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres};  PGDATABASE=${PGDATABASE:-travel_ads}

OUTDUMP="$ROOT_DIR/backupPSQL.sql"
OUTLOG="$ROOT_DIR/backupPSQL.log"

echo "→ Creating custom-format dump: $OUTDUMP" | tee -a "$OUTLOG"
/usr/bin/time -p pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
  -Fc --no-owner --no-privileges -v -f "$OUTDUMP" 2>> "$OUTLOG"
echo " Done." | tee -a "$OUTLOG"
