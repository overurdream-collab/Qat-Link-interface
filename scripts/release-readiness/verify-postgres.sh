#!/usr/bin/env bash
set -euo pipefail

# Only supply disposable synthetic databases. Never drops databases or volumes.
: "${FIN08_TEST_DATABASE_URL:?Disposable synthetic PostgreSQL URL is required}"
: "${IDENTITY_CI_DATABASE_URL:?Separate disposable identity and OTP test database URL required}"
: "${FIN08_RUNTIME_DATABASE_URL:?Restricted runtime role connection required}"
: "${FIN08_RESTORE_DATABASE_URL:?Separate NEW restore database URL is required}"
# Parse identifiers without evaluating connection strings as shell/SQL text.
# Restrict names so test credentials never become executable SQL or log payloads.
config_file=$(mktemp)
trap 'rm -f "$config_file"' EXIT
node --input-type=module > "$config_file" <<'JS'
const source = new URL(process.env.FIN08_TEST_DATABASE_URL);
const identity = new URL(process.env.IDENTITY_CI_DATABASE_URL);
const restored = new URL(process.env.FIN08_RESTORE_DATABASE_URL);
const runtime = new URL(process.env.FIN08_RUNTIME_DATABASE_URL);
const db = u => decodeURIComponent(u.pathname.slice(1));
const identifiers = [db(source), db(identity), db(restored), decodeURIComponent(runtime.username)];
if (identifiers.some(x => !/^[a-z][a-z0-9_]{0,62}$/.test(x))) {
  throw new Error('Use simple lowercase test database and role identifiers');
}
if (new Set(identifiers.slice(0, 3)).size !== 3 || db(runtime) !== db(source)) {
  throw new Error('Require separate finance, identity, restore DBs and a runtime finance connection');
}
if ([identity, restored, runtime].some(u => u.hostname !== source.hostname || u.port !== source.port)) {
  throw new Error('Disposable test URLs must use the same isolated cluster');
}
const password = decodeURIComponent(runtime.password);
if (!/^[A-Za-z0-9_]{8,80}$/.test(password)) {
  throw new Error('Use an 8–80 character synthetic runtime test password');
}
console.log([...identifiers, password].join('\n'));
JS
mapfile -t parsed_config < "$config_file"
finance_db=${parsed_config[0]}
identity_db=${parsed_config[1]}
restore_db=${parsed_config[2]}
runtime_role=${parsed_config[3]}
runtime_password=${parsed_config[4]}
root=$(cd "$(dirname "$0")/../.." && pwd)
evidence="$root/build/release-readiness"
mkdir -p "$evidence"
exec > >(tee "$evidence/postgres.log") 2>&1
printf 'UTC: %s\nCommit: %s\n' "$(date -u +%FT%TZ)" "$(git -C "$root" rev-parse HEAD)"
node --version
psql --version
psql "$FIN08_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -Atc 'SHOW server_version;'
if [[ $(psql "$FIN08_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM pg_tables WHERE schemaname='public'") != 0 ]]; then
  echo 'Refusing migrations: finance test database must have an empty public schema' >&2
  exit 1
fi

cd "$root/server"
npm run check
while IFS= read -r -d '' source; do
  node --check "$source"
done < <(find src -name '*.mjs' -print0)
for migration in sql/00[1-9]_*.sql; do
  printf 'Applying %s\n' "$migration"
  psql "$FIN08_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration"
done
psql "$FIN08_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/tests/fin19_direct_sql_regression.sql
# Identity and SMS fixtures are separate from the financial database.
# createdb fails if the target already exists; no database is overwritten.
createdb --maintenance-db="$FIN08_TEST_DATABASE_URL" "$identity_db"
for migration in sql/identity/008_p0_identity_accounts.sql sql/fin25/009_fin25_gateway_isolated.sql sql/fin25/010_fin25_otp_isolated.sql; do
  psql "$IDENTITY_CI_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration"
done
psql "$FIN08_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v finance_db="$finance_db" -v runtime_role="$runtime_role" -v runtime_password="$runtime_password" <<'SQL'
CREATE ROLE :"runtime_role" LOGIN PASSWORD :'runtime_password' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS NOINHERIT;
GRANT CONNECT ON DATABASE :"finance_db" TO :"runtime_role";
GRANT USAGE ON SCHEMA public TO :"runtime_role";
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO :"runtime_role";
REVOKE UPDATE ON fin08_audit_events FROM :"runtime_role";
SQL
psql "$FIN08_RUNTIME_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/audit_fin18_runtime_role.sql
# Tests that intentionally probe schema/trigger privilege protections use migrator.
# This does not certify the privileges of a deployed production database user.
# FIN08_TEST_DATABASE_URL is inherited by every PostgreSQL test.
node --test --test-reporter=tap | tee "$evidence/backend.tap"
# A successful process with skipped integration tests is not acceptance.
node --input-type=module - "$evidence/backend.tap" <<'JS'
import fs from 'node:fs';
const tap = fs.readFileSync(process.argv[2], 'utf8');
if (!/^# skipped 0$/m.test(tap) || !/^# fail 0$/m.test(tap)) {
  throw new Error('Full backend acceptance requires zero failures and zero skips');
}
JS
psql "$FIN08_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/audit_fin18_existing_ledger.sql

# The target MUST be new; createdb fails rather than overwriting existing data.
createdb --maintenance-db="$FIN08_TEST_DATABASE_URL" "$restore_db"
pg_dump "$FIN08_TEST_DATABASE_URL" --format=custom --no-owner --no-acl --file="$evidence/synthetic.dump"
pg_restore --dbname="$FIN08_RESTORE_DATABASE_URL" --exit-on-error --no-owner --no-acl "$evidence/synthetic.dump"
psql "$FIN08_TEST_DATABASE_URL" -X -q -A -t -v ON_ERROR_STOP=1 -f "$root/scripts/release-readiness/financial-snapshot.sql" > "$evidence/source.snapshot"
psql "$FIN08_RESTORE_DATABASE_URL" -X -q -A -t -v ON_ERROR_STOP=1 -f "$root/scripts/release-readiness/financial-snapshot.sql" > "$evidence/restored.snapshot"
diff -u "$evidence/source.snapshot" "$evidence/restored.snapshot"
psql "$FIN08_RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/audit_fin18_existing_ledger.sql
echo 'PASS: fresh migrations, full backend suite (zero skips), FIN18 audit and exact restore snapshot.'
