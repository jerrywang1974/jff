## Create user and its default schema

```
CREATE USER some_user PASSWORD 'xxxx';
CREATE SCHEMA AUTHORIZATION some_user;
```

## Grant extra privileges

```
GRANT USAGE ON SCHEMA xx, xxx TO some_user;
GRANT SELECT ON ALL TABLES IN SCHEMA xx, xxx TO some_user;
```

## Show grants

```
SELECT distinct * FROM (
    SELECT distinct grantor, grantee, table_catalog AS catalog, table_schema AS schema, privilege_type FROM information_schema.role_column_grants union
    SELECT distinct grantor, grantee, routine_catalog AS catalog, routine_schema AS schema, privilege_type FROM information_schema.role_routine_grants union
    SELECT distinct grantor, grantee, table_catalog AS catalog, table_schema AS schema, privilege_type FROM information_schema.role_table_grants union
    SELECT distinct grantor, grantee, udt_catalog AS catalog, udt_schema AS schema, privilege_type FROM information_schema.role_udt_grants union
    SELECT distinct grantor, grantee, object_catalog AS catalog, object_schema AS schema, privilege_type FROM information_schema.role_usage_grants union

    SELECT distinct grantor, grantee, table_catalog AS catalog, table_schema AS schema, privilege_type FROM information_schema.column_privileges union
    SELECT distinct grantor, grantee, routine_catalog AS catalog, routine_schema AS schema, privilege_type FROM information_schema.routine_privileges union
    SELECT distinct grantor, grantee, table_catalog AS catalog, table_schema AS schema, privilege_type FROM information_schema.table_privileges union
    SELECT distinct grantor, grantee, udt_catalog AS catalog, udt_schema AS schema, privilege_type FROM information_schema.udt_privileges union
    SELECT distinct grantor, grantee, object_catalog AS catalog, object_schema AS schema, privilege_type FROM information_schema.usage_privileges
) AS privileges WHERE grantee = 'some_user' ORDER BY catalog, schema, privilege_type;
```

```
SELECT relname, relkind, relacl, nspname, nspacl FROM pg_class LEFT JOIN pg_namespace ON relnamespace = pg_namespace.oid
WHERE relacl IS NOT NULL AND nspacl IS NOT NULL AND (relacl::text ~ 'some_user=' OR nspacl::text ~ 'some_user=');
```
