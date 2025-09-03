#!/bin/bash
set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Always run from repo root so outputs land there
cd "$ROOT_DIR"

# 1) Load .env if present (export all vars)
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

# 2) Defaults if any var missing
PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}
PGDATABASE=${PGDATABASE:-travel_ads}

# 3) Output files at repo root as requested
OUTSQL="$ROOT_DIR/backupSQL.sql"
OUTLOG="$ROOT_DIR/backupSQL.log"

echo "→ Running plain text backup into $OUTSQL ..."
pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
  --clean --if-exists --no-owner --no-privileges \
  --format=plain -v > "$OUTSQL" 2> "$OUTLOG"

echo "Backup completed: $OUTSQL (log: $OUTLOG)"

