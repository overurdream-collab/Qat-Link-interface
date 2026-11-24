-- Read-only FIN18 release check. Execute AS THE RUNTIME DATABASE ROLE,
-- not as the privileged migration user. Does not read client data.
-- Example: PGPASSWORD=... psql "$RUNTIME_DATABASE_URL" -v ON_ERROR_STOP=1
--   -f server/sql/audit_fin18_runtime_role.sql
DO $audit$
DECLARE
  role_info record;
  owned_table record;
BEGIN
  SELECT rolsuper, rolcreatedb, rolcreaterole, rolreplication,
         rolbypassrls
    INTO role_info FROM pg_roles WHERE rolname = current_user;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot verify runtime DB role';
  END IF;
  IF role_info.rolsuper OR role_info.rolcreatedb OR
     role_info.rolcreaterole OR role_info.rolreplication OR
     role_info.rolbypassrls THEN
    RAISE EXCEPTION 'Runtime DB role has privileged flags';
  END IF;

  -- NOINHERIT membership still allows SET ROLE to an owner. Checking only
  -- current_user and effective privileges misses this escalation path.
  FOR owned_table IN
    SELECT c.relname, c.relowner FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p')
  LOOP
    IF pg_has_role(current_user, owned_table.relowner, 'MEMBER') THEN
      RAISE EXCEPTION 'Runtime DB role is owner or member of table owner: %', owned_table.relname;
    END IF;
    IF has_table_privilege(current_user, format('public.%I',owned_table.relname), 'TRUNCATE')
       OR has_table_privilege(current_user, format('public.%I',owned_table.relname), 'TRIGGER') THEN
      RAISE EXCEPTION 'Runtime DB role has TRUNCATE/TRIGGER privileges: %', owned_table.relname;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_roles r
     WHERE (r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls)
       AND pg_has_role(current_user, r.oid, 'MEMBER')) THEN
    RAISE EXCEPTION 'Runtime DB role is member of privileged role';
  END IF;
  IF has_schema_privilege(current_user, 'public', 'CREATE') OR
     has_database_privilege(current_user, current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'Runtime DB role has schema/database CREATE privileges';
  END IF;
  IF has_table_privilege(current_user, 'public.fin08_audit_events', 'UPDATE') OR
     has_table_privilege(current_user, 'public.fin08_audit_events', 'DELETE') THEN
    RAISE EXCEPTION 'Runtime DB role can rewrite/delete financial audit history';
  END IF;

  IF pg_has_role(current_user, 'pg_write_all_data', 'MEMBER') OR
     pg_has_role(current_user, 'pg_execute_server_program', 'MEMBER') OR
     pg_has_role(current_user, 'pg_read_server_files', 'MEMBER') OR
     pg_has_role(current_user, 'pg_write_server_files', 'MEMBER') THEN
    RAISE EXCEPTION 'Runtime DB role has broad predefined elevated privileges';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'financial_movements'::regclass
      AND tgname = 'fin18_movement_source_guard'
      AND tgenabled = 'O'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'FIN18 approved ledger provenance trigger is not enabled';
  END IF;
  RAISE NOTICE 'FIN18 runtime DB role, privileges, and trigger: PASS';
END;
$audit$;
