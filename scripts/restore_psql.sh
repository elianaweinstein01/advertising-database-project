#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; cd "$ROOT_DIR"

[ -f .env ] && set -a && . ./.env && set +a
PGHOST=${PGHOST:-localhost}; PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres};  PGDATABASE=${PGDATABASE:-travel_ads}

DUMP="$ROOT_DIR/backupPSQL.sql"
OUTLOG="$ROOT_DIR/backupPSQL.log"

echo "→ Dropping and recreating schema 'public'..." | tee -a "$OUTLOG"
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
  -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >> 
"$OUTLOG" 2>&1

echo "→ Restoring from $DUMP ..." | tee -a "$OUTLOG"
/usr/bin/time -p pg_restore --no-owner --no-privileges -v \
  -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
  "$DUMP" 2>> "$OUTLOG"
echo " Restore complete." | tee -a "$OUTLOG"

