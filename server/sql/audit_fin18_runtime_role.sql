-- Read-only FIN18 release check. Execute AS THE RUNTIME DATABASE ROLE,
-- not as the privileged migration user. Does not read client data.
-- Example: PGPASSWORD=... psql "$RUNTIME_DATABASE_URL" -v ON_ERROR_STOP=1
--   -f server/sql/audit_fin18_runtime_role.sql
DO $audit$
DECLARE
  role_info record;
  owner_name text;
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

  SELECT pg_get_userbyid(relowner) INTO owner_name
    FROM pg_class WHERE oid = 'financial_movements'::regclass;
  IF owner_name = current_user THEN
    RAISE EXCEPTION 'Runtime DB role owns approved ledger and can disable protections';
  END IF;

  IF has_table_privilege(current_user, 'financial_movements',
    'TRUNCATE') OR has_table_privilege(current_user,
    'financial_movements', 'TRIGGER') THEN
    RAISE EXCEPTION 'Runtime DB role can truncate the ledger or alter its triggers';
  END IF;
  IF has_schema_privilege(current_user, current_schema(), 'CREATE') OR
     has_database_privilege(current_user, current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'Runtime DB role has schema/database CREATE privileges';
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
