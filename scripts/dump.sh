#!/bin/bash
set -e  # stop if any command fails

# 1) Load connection settings from .env (if present)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# 2) Provide safe defaults if .env is missing any values
PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}
PGDATABASE=${PGDATABASE:-travel_ads}

# 3) Ensure dumps/ exists and make a timestamped filename
mkdir -p dumps
TS=$(date +"%Y%m%d-%H%M%S")
OUTFILE="dumps/${PGDATABASE}_${TS}.sql"

# 4) Dump schema + data into a plain SQL file
echo "→ Dumping $PGDATABASE as $PGUSER@$PGHOST:$PGPORT ..."
pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" > "$OUTFILE"

# 5) Success message
echo "Dump created: $OUTFILE"


