SET NOCOUNT ON;
IF DB_NAME() NOT LIKE 'VaxStockAuthTest[_]%' THROW 51200, 'Use isolated test database.', 1;
IF (SELECT COUNT(*) FROM dbo.AppUserRecords WHERE Role='Admin') <> 1 THROW 51201, 'Last-admin invariant failed.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='CreateUser') THROW 51202, 'Missing create audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='GrantWarehouse') THROW 51203, 'Missing grant audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='RevokeWarehouse') THROW 51204, 'Missing revoke audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='ResetPassword' AND ISJSON(Details)=1 AND LEN(JSON_VALUE(Details,'$.reason'))=2000)
    THROW 51205, 'Password-reset audit reason missing or truncated.', 1;
IF EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Details LIKE '%passwordHash%' OR Details LIKE '%Changed-password-123!%')
    THROW 51206, 'Secret leaked into audit.', 1;
SELECT 'PASS: user management audit completeness, full reason, no credentials, last-admin invariant.' AS Result;
