#!/usr/bin/env bash
# Geçişleri ve RLS doğrulamalarını geçici bir yalın PostgreSQL üzerinde çalıştırır.
# Gereken: PostgreSQL 15+ sunucu ikilileri (initdb, pg_ctl) ve psql. Docker gerekmez.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
DATA="$(mktemp -d)"
PORT="${PGPORT_VERIFY:-54329}"
if [ "$(id -u)" = "0" ]; then RUNAS="runuser -u postgres --"; chown postgres "$DATA"; else RUNAS=""; fi
cleanup() { $RUNAS "$PGBIN/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$DATA"; }
trap cleanup EXIT
$RUNAS "$PGBIN/initdb" -D "$DATA" -U postgres --auth=trust -E UTF8 >/dev/null
$RUNAS "$PGBIN/pg_ctl" -D "$DATA" -o "-p $PORT -k /tmp -c listen_addresses=''" -w start >/dev/null
PSQL=(psql -h /tmp -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -f "$ROOT/supabase/verify/stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "geçiş: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
"${PSQL[@]}" -tA -f "$ROOT/supabase/verify/tests.sql" 2>&1 | sed 's/^psql:.*NOTICE:  //'
