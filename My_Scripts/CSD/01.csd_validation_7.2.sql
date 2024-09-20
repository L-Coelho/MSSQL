Print 'Creating Stored Procedure CSD_Validation 7.2'


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'CSD_Validation')
	EXEC ('CREATE PROC [dbo].[CSD_Validation] AS SELECT ''stub version, to be replaced''')
GO


-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <02/04/2024>
-- Description:	<Validation of SQL Server CSD v7.2>
-- =============================================

ALTER PROCEDURE [dbo].[CSD_Validation]
@permanent BIT=0, @purge INT=1,@defaultpurge VARCHAR(5)=365,@Loginauditing CHAR (7)='ALL', @NumLogs INT=99, @trace INT=1, @sqlaudit INT=1, @sqlpolicy INT=1, @bultinadmin INT=0, @guest INT=0, @cross INT=0,  
@sadisable INT=0,@databasemail INT=0, @remoteadmin INT=0, @remoteaccess INT=0, @scanprocs INT=0, @adhocqueries INT=0, @clr INT=0, @ole INT=0, @trustworthy INT=0, @clrassemblysafe INT=1, 
@xpcmdshell INT=0,@symmetrickeys NVARCHAR (60)='AES_256',@asymmetricsize int=2048,@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='dbo',@table VARCHAR(100)='CSD'
AS
-- Parameters to check --
/*
@permanent Values-> 0 - Display only resultus \ 1 - Record the results in the database, schema and table defined in the parameters @database,@schema,@table
@purge Values-> 0 - Don't purge Table defined in permanent \ 1 - Purge data with days below @defaultpurge
@Loginauditing Values -> ALL = Both failed and successfull logins \ failure = Failed logins only \ success= Successfull logins only \ none=none    
@NumLogs Values -> Number of Retain sql error log defined in CSD
@trace Values -> 0 - The default trace is not active \ 1 The default trace is active (This is the default)
@sqlaudit Values -> O - Not all the SQL Audits are implemented \  1 - All the SQL Audits are implemented (CNAU-AUDIT_CHANGE_GROUP\SUCCESS AND FAILURE ->LGFL-FAILED_LOGIN_GROUP\SUCCESS AND FAILURE ->LGSD-SUCCESSFUL_LOGIN_GROUP\SUCCESS AND FAILURE)
@sqlpolicy Values -> 0-Not Enabled on all sql logins \ 1 - Enabled on all sql logins
@bultinadmin Values -> 0- BUILTIN\administrator does not exists in sql server \  1 - BUILTIN\administrator exists in sql server
@guest Values -> 0 - guest has no permissions on user databases \ 1 - guest has permissions on user databases
@cross Values -> 0 - Disabled cross database chaining  \ 1 - Enabled cross database chaining
@sadisable Values -> 0 - sa Disabled  \ 1 - sa Enabled 
@databasemail Values -> 0 - Database Mail Disabled \ 1 - Database Mail Enabled
@remoteadmin Values -> 0 - remoteadmin Disabled \ 1 - remoteadmin Enabled
@remoteaccess Values -> 0 - Disabled \ 1 - Enabled
@scanprocs Values -> 0 - Disabled \ 1 - Enabled
@adhocqueries Values -> 0 - Disabled \ 1 - Enabled
@clr Values -> 0 - Disabled \ 1 - Enabled
@ole Values -> 0 - Disabled \ 1 - Enabled
@trustworthy Values -> 0 - Disabled \ 1 - Enabled
@clrassemblysafe Values -> 1 - Safe Access\ 2 - External Access \ 3 - Unsafe Access -- IF no CLR then  @clrassemblysafe = 0 - OK
@xpcmdshell Values -> 0 - Disabled \ 1 - Enabled
@symmetrickeys Values -> AES_128\ AES_192 \ AES_256
@asymmetricsize Values -> 512\1024\2048 - Algorithm -> 1R = 512-bit RSA\2R = 1024-bit RSA\3R = 2048-bit RSA
*/

BEGIN
    SET NOCOUNT ON;
    DECLARE @sqlversion AS INT;
    SELECT @sqlversion = CONVERT (INT, (@@microsoftversion / 0x1000000) & 0xff);
    DECLARE @CSDVersion AS DECIMAL (10, 1);
    SET @CSDVersion = 7.2;

	
		/* Check SQL Server Version and abort in the case that the version is prior to SQL Server 2005*/
	IF (
	SELECT
	  CASE
		 WHEN @sqlversion=8 THEN 0
		 ELSE 1
	  END
	) = 0
	BEGIN
		DECLARE @msg VARCHAR(8000);
		SELECT @msg = 'Sorry, not works on versions of SQL Server prior to 2005.' + REPLICATE(CHAR(13),7933);
		PRINT @msg;
		RETURN;
	END;
    
	IF OBJECT_ID('tempdb..#CSDResults') IS NOT NULL
    DROP TABLE #CSDResults;
    
	CREATE TABLE #CSDResults (
        [ID]                     INT            IDENTITY (1, 1) PRIMARY KEY CLUSTERED,
        [Section]                NVARCHAR (50)  NOT NULL,
        [Section Heading]        NVARCHAR (200) NOT NULL,
        [System Value/Parameter] NVARCHAR (200) NOT NULL,
        [Description]            NVARCHAR (MAX) NOT NULL,
        [Agreed to Value]        NVARCHAR (80)  NOT NULL,
        [Result]                 VARCHAR (3)    NOT NULL  );
	
	--000
    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT '000' AS [Section],
           'CSD Validation' AS [Section Heading],
           'SQL Server Instance - ' + @@servername + '' AS [System Value/Parameter],
           'CSD Version - ' + CONVERT (VARCHAR, @CSDVersion) + '' AS [Description],
           'No value to be set' AS [Agreed to Value],
           'N\A' AS [Result];
	--AO.1.1.0 
    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.1.0' AS [Section],'Password Requirements' AS [Section Heading],'These requirements are covered at a Operating System level for all platforms.' AS [System Value/Parameter],
           'No configurable controls in this Section' AS [Description],'No value to be set' AS [Agreed to Value],'N\A' AS [Result];
	--AO.1.2.2
    CREATE TABLE #tabAuditLoginAttempts ([name] sysname ,config_value NCHAR (50));
    INSERT INTO #tabAuditLoginAttempts
    EXECUTE master.dbo.xp_loginconfig 'audit level';
    DECLARE @result AS CHAR (7);
    SET @result = (SELECT config_value FROM #tabAuditLoginAttempts);
    IF (SELECT @result) = @Loginauditing
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.2' AS [Section], 'Logging' AS [Section Heading],'Login auditing' AS [System Value/Parameter],'Record attempts to login to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @Loginauditing) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.2' AS [Section],'Logging' AS [Section Heading], 'Login auditing' AS [System Value/Parameter], 'Record attempts to login to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @Loginauditing) + '' AS [Agreed to Value],'NOK' AS [Result];
	--AO.1.2.3 
    DECLARE @NLogs AS INT;
    EXECUTE xp_instance_regread 'HKEY_LOCAL_MACHINE', 'Software\Microsoft\MSSQLServer\MSSQLServer', 'NumErrorLogs', @NLogs OUTPUT;
    IF @NLogs = @NumLogs
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.3' AS [Section],'Logging' AS [Section Heading],'Retain error log files' AS [System Value/Parameter], 'Retain sql error log for a given number of iterations.' AS [Description],
               '' + CONVERT (VARCHAR, @NumLogs) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.3' AS [Section], 'Logging' AS [Section Heading], 'Retain error log files' AS [System Value/Parameter],'Retain sql error log for a given number of iterations.' AS [Description],
               '' + CONVERT (VARCHAR, @NumLogs) + '' AS [Agreed to Value], 'NOK' AS [Result];
    --AO.1.2.4
	DECLARE @resulttrace AS INT;
    SET @resulttrace = (SELECT CAST (value AS INT) FROM sys.configurations  WHERE  name = 'default trace enabled');
    IF @resulttrace = @trace
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.4' AS [Section],'Logging' AS [Section Heading],'Default trace enabled' AS [System Value/Parameter],'The default trace provides audit logging of database activity including account creations, privilege elevation and execution of DBCC commands.' AS [Description],
               '' + CONVERT (VARCHAR, @resulttrace) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.4' AS [Section],'Logging' AS [Section Heading],'Default trace enabled' AS [System Value/Parameter],'The default trace provides audit logging of database activity including account creations, privilege elevation and execution of DBCC commands.' AS [Description],
               '' + CONVERT (VARCHAR, @resulttrace) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.2.5
	DECLARE @resultsqlaudit AS INT;
	SET @resultsqlaudit=(SELECT COUNT(*) FROM (
				SELECT S.name AS 'Audit Name',
                      CASE S.is_state_enabled WHEN 1 THEN 'Y' WHEN 0 THEN 'N' END AS 'Audit Enabled',
                      S.type_desc AS 'Write Location',
                      SA.name AS 'Audit Specification Name',
                      CASE SA.is_state_enabled WHEN 1 THEN 'Y' WHEN 0 THEN 'N' END AS 'Audit Specification Enabled',
                      SAD.audit_action_name,
                      SAD.audited_result
               FROM   sys.server_audit_specification_details AS SAD
                      INNER JOIN
                      sys.server_audit_specifications AS SA
                      ON SAD.server_specification_id = SA.server_specification_id
                      INNER JOIN
                      sys.server_audits AS S
                      ON SA.audit_guid = S.audit_guid
               WHERE  SAD.audit_action_id IN ('CNAU', 'LGFL', 'LGSD')
                      AND S.is_state_enabled = 1
					) CountQuery)


				IF @resultsqlaudit=3
					BEGIN
						SET @resultsqlaudit = 1;
				END
				ELSE
					BEGIN
						SET @resultsqlaudit = 0;
				END
		IF @resultsqlaudit = @sqlaudit
	    BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.2.5' AS [Section],'Logging' AS [Section Heading],'SQL Server Audit' AS [System Value/Parameter],'SQL Server Audit is capable of capturing both failed and successful logins and writing them to one of three places: the application event log, the security event log, or the file system. We will use it to capture any login attempt to SQL Server, as well as any attempts to change audit policy. This will also serve to be a second source to record failed login attempts.' AS [Description],
                   'Failed and Successful' AS [Agreed to Value],'OK' AS [Result];
        END
		ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.2.5' AS [Section],'Logging' AS [Section Heading],'SQL Server Audit' AS [System Value/Parameter],'SQL Server Audit is capable of capturing both failed and successful logins and writing them to one of three places: the application event log, the security event log, or the file system. We will use it to capture any login attempt to SQL Server, as well as any attempts to change audit policy. This will also serve to be a second source to record failed login attempts.' AS [Description],
                   'Failed and Successful' AS [Agreed to Value],'NOK' AS [Result];
        END
    --AO.1.4.0
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.4.0' AS [Section],'System Settings' AS [Section Heading],'No configurable controls in this Sectiont' AS [System Value/Parameter],'No configurable controls in this Section' AS [Description],'No value to be set' AS [Agreed to Value],'N\A' AS [Result];
    --AO.1.5.0
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.5.0' AS [Section],'Network Settings' AS [Section Heading],'No configurable controls in this Sectiont' AS [System Value/Parameter],'No configurable controls in this Section' AS [Description],'No value to be set' AS [Agreed to Value],'N\A' AS [Result];
    -- AO.1.7.1
	DECLARE @resultpolicy AS INT;
    IF NOT EXISTS (SELECT name,is_policy_checked FROM sys.sql_logins WHERE is_policy_checked <> 1)
        BEGIN
            SET @resultpolicy = 1;
        END
    ELSE
        BEGIN
            SET @resultpolicy = 0;
        END
    IF @resultpolicy = @sqlpolicy
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.1' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Account password policy enforcement' AS [System Value/Parameter],'Ensure active directory password policy is applied to sql logins. Applies to SQL 2005 onwards only.' AS [Description],
               'Enabled on all sql logins - ' + CONVERT (VARCHAR, @sqlpolicy) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.1' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Account password policy enforcement' AS [System Value/Parameter],'Ensure active directory password policy is applied to sql logins. Applies to SQL 2005 onwards only.' AS [Description],
               'Enabled on all sql logins - ' + CONVERT (VARCHAR, @sqlpolicy) + '' AS [Agreed to Value],'NOK' AS [Result];
	--AO.1.7.2
    DECLARE @resultadmin AS INT;
    SET @resultadmin = (SELECT count(*) FROM master.dbo.syslogins WHERE name ='BUILTIN\Administrators');
    IF @resultadmin = @bultinadmin
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.2' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'BUILTIN\administrator access level' AS [System Value/Parameter],'Ensure the BUILTIN\administrator has no access to sql server.' AS [Description],
               'Delete - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.2' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'BUILTIN\administrator access level' AS [System Value/Parameter],'Ensure the BUILTIN\administrator has no access to sql server.' AS [Description],
               'Delete - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.7.3
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.7.3' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'SSAS Admins Check' AS [System Value/Parameter],'Ensure the BUILTINADMINSARESERVERADMINS is not set.' AS [Description],
           'SSAS Only - FALSE ' AS [Agreed to Value],'N\A' AS [Result];
    --AO.1.7.4.2
	DECLARE @First AS SMALLINT, @Last AS SMALLINT, @DBName AS VARCHAR (200), @SQLCommand AS VARCHAR (500), @DBWithGuestAccess AS NVARCHAR (4000);
    IF OBJECT_ID('tempdb..#GuestUsersReport') IS NOT NULL
        DROP TABLE #GuestUsersReport;
		CREATE TABLE #GuestUsersReport ([Database] VARCHAR (256),[UserName] VARCHAR (256),[HasDbAccess] VARCHAR (10));
    DECLARE @DatabaseList TABLE ([RowNo] SMALLINT IDENTITY (1, 1),[DBName] VARCHAR (200));
    INSERT INTO @DatabaseList
    SELECT   d1.[name]
    FROM     [master]..[sysdatabases] AS d1 WITH (NOLOCK) INNER JOIN [sys].databases AS d2 ON d1.dbid = d2.database_id
    WHERE    d1.[name] NOT IN ('master', 'tempdb', 'msdb') AND d2.state_desc = 'ONLINE'
    ORDER BY d1.[name];
    SELECT @First = MIN([RowNo])
    FROM   @DatabaseList;
    SELECT @Last = MAX([RowNo])
    FROM   @DatabaseList;
    WHILE @First <= @Last
        BEGIN
            SELECT @DBName = [DBName]
            FROM   @DatabaseList
            WHERE  [RowNo] = @First;
            SET @SQLCommand = 'INSERT INTO #GuestUsersReport ([Database], [UserName], [HasDbAccess])' + CHAR(13) + 'SELECT ' + CHAR(39) + @DBName + CHAR(39) + ' ,[name], CASE [hasdbaccess] WHEN 0 THEN ''N'' WHEN 1 THEN ''Y'' END ' + CHAR(13) + 'FROM [' + @DBName + ']..[sysusers] WHERE [name] LIKE ''guest'' AND [hasdbaccess] = 1';
            EXECUTE (@SQLCommand);
            SET @First = @First + 1;
        END
    DECLARE @resultguest AS INT;
    IF NOT EXISTS (SELECT * FROM #GuestUsersReport WITH (NOLOCK))
        BEGIN
            SET @resultguest = 0;
        END
    ELSE
        BEGIN
            SET @resultguest = 1;
        END
    IF @resultguest = @guest
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.4.2' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Guest Permissions' AS [System Value/Parameter],'Ensure guest has no permissions on user databases.' AS [Description],
               'Disable in all user databases - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.4.2' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Guest Permissions' AS [System Value/Parameter],'Ensure guest has no permissions on user databases.' AS [Description],
               'Disable in all user databases - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.7.5
	DECLARE @resultcross AS INT;
    SET @resultcross = (SELECT CONVERT(INT,(SELECT value_in_use FROM sys.configurations WHERE description = 'Allow cross db ownership chaining')));
    IF @resultcross = @cross
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.5' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Cross Database Permissions' AS [System Value/Parameter],'Ensure only explicitly assigned permissions are valid.' AS [Description],
               'Disabled for user databases only - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.5' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Cross Database Permissions' AS [System Value/Parameter],'Ensure only explicitly assigned permissions are valid.' AS [Description],
               'Disabled for user databases only - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.7.6
	IF NOT EXISTS (SELECT name FROM sys.sql_logins WHERE name='sa' AND PWDCOMPARE('', password_hash) = 1 OR PWDCOMPARE('sa', password_hash) = 1)
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.7.6' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'sa Password legacy versions' AS [System Value/Parameter],
                   'Ensure strong password. ' AS [Description],'Password must be non-blank and not identical to the login id' AS [Agreed to Value],'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.7.6' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'sa Password legacy versions' AS [System Value/Parameter],
                   'Ensure strong password. ' AS [Description],'Password must be non-blank and not identical to the login id' AS [Agreed to Value],'NOK' AS [Result];
        END
    --AO.1.7.7
	DECLARE @resultsadisable AS INT;
    SET @resultsadisable = (SELECT COUNT(*) FROM sys.sql_logins WHERE name='sa' AND is_disabled = 0);
    IF @resultsadisable = @sadisable
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.7' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'sa Password recent versions' AS [System Value/Parameter],'Ensure sa account cannot be used' AS [Description],
               'Account should be disabled - ' + CONVERT (VARCHAR, @sadisable) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.7' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'sa Password recent versions' AS [System Value/Parameter],'Ensure sa account cannot be used' AS [Description],
               'Account should be disabled - ' + CONVERT (VARCHAR, @sadisable) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.7.8
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.7.8' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'SQLDebugger' AS [System Value/Parameter],'Ensure SQLDebugger account is removed. Applies to SQL 2000 Service Pack 3 only.' AS [Description],
           'Delete' AS [Agreed to Value],'OK' AS [Result];
    
	--AO.1.7.10
	IF NOT EXISTS (SELECT * FROM   master.sys.server_permissions
                   WHERE  (grantee_principal_id = SUSER_SID(N'public')
                           AND state_desc LIKE 'GRANT%')
                          AND NOT (state_desc = 'GRANT'
                                   AND [permission_name] = 'VIEW ANY DATABASE'
                                   AND class_desc = 'SERVER')
                          AND NOT (state_desc = 'GRANT'
                                   AND [permission_name] = 'CONNECT'
                                   AND class_desc = 'ENDPOINT'
                                   AND major_id = 2)
                          AND NOT (state_desc = 'GRANT'
                                   AND [permission_name] = 'CONNECT'
                                   AND class_desc = 'ENDPOINT'
                                   AND major_id = 3)
                          AND NOT (state_desc = 'GRANT'
                                   AND [permission_name] = 'CONNECT'
                                   AND class_desc = 'ENDPOINT'
                                   AND major_id = 4)
                          AND NOT (state_desc = 'GRANT'
                                   AND [permission_name] = 'CONNECT'
                                   AND class_desc = 'ENDPOINT'
                                   AND major_id = 5))
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.10' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Public access levels' AS [System Value/Parameter],'Public is a special fixed server role containing all logins. Unlike other fixed server roles, permissions can be changed for the public role. In keeping with the principle of least privileges, the public server role should not be used to grant permissions at the server scope as these would be inherited by all users.' AS [Description],
               'Nothing above base.' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.10' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Public access levels' AS [System Value/Parameter],'Public is a special fixed server role containing all logins. Unlike other fixed server roles, permissions can be changed for the public role. In keeping with the principle of least privileges, the public server role should not be used to grant permissions at the server scope as these would be inherited by all users.' AS [Description],
               'Nothing above base.' AS [Agreed to Value],'NOK' AS [Result];
	--AO.1.7.11
    IF NOT EXISTS (SELECT pr.[name] AS LocalGroupName,pe.[permission_name],pe.[state_desc]
                   FROM   sys.server_principals AS pr INNER JOIN sys.server_permissions AS pe ON pr.[principal_id] = pe.[grantee_principal_id]
                   WHERE  pr.[type_desc] = 'WINDOWS_GROUP' AND pr.[name] LIKE CAST (SERVERPROPERTY('MachineName') AS NVARCHAR) + '%')
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.11' AS [Section], 'Identify and Authenticate Users' AS [Section Heading], 'Windows local groups' AS [System Value/Parameter],'Local Windows groups should not be used as logins for SQL Server instances.' AS [Description],
               'Not present' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.11' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Windows local groups' AS [System Value/Parameter],'Local Windows groups should not be used as logins for SQL Server instances.' AS [Description],
               'Not present' AS [Agreed to Value],'NOK' AS [Result];
	--AO.1.7.12
    IF NOT EXISTS (SELECT sp.name AS proxyname FROM [msdb].[dbo].[sysproxylogin] AS spl INNER JOIN sys.database_principals AS dp ON dp.sid = spl.sid
                          INNER JOIN [msdb].[dbo].[sysproxies] AS sp ON sp.proxy_id = spl.proxy_id WHERE  principal_id = USER_ID('public'))
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.12' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Public agent proxies' AS [System Value/Parameter],'The public database role contains every user in the msdb database. SQL Agent proxies define a security context in which a job step can run.' AS [Description],
               'No access' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.12' AS [Section],'Identify and Authenticate Users' AS [Section Heading],'Public agent proxies' AS [System Value/Parameter],'The public database role contains every user in the msdb database. SQL Agent proxies define a security context in which a job step can run.' AS [Description],
               'No access' AS [Agreed to Value],'NOK' AS [Result];
	--AO.1.8.1
    DECLARE @resultdatabasemail AS INT;
    SET @resultdatabasemail = (SELECT CAST(value_in_use AS INT) AS value_in_use FROM sys.configurations WHERE name='Database Mail XPs');
    IF @resultdatabasemail = @databasemail
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.1' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Database Mail XPs' AS [System Value/Parameter],'The Database Mail XPs option controls the ability to generate and transmit email messages from SQL Server.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @databasemail) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.1' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Database Mail XPs' AS [System Value/Parameter],'The Database Mail XPs option controls the ability to generate and transmit email messages from SQL Server.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @databasemail) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.8.2
	DECLARE @resultremoteadmin AS INT;
    SET @resultremoteadmin = (SELECT CAST(value_in_use AS INT) AS value_in_use FROM sys.configurations WHERE name='remote admin connections' AND SERVERPROPERTY('IsClustered') = 0);
    IF @resultremoteadmin = @remoteadmin
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.2' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Remote Admin Connections' AS [System Value/Parameter],'The remote admin connections option controls whether a client application on a remote computer can use the Dedicated Administrator Connection (DAC). Should not be applied to clusters.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteadmin) + '' AS [Agreed to Value],'OK' AS [Result];
    IF @resultremoteadmin <> @remoteadmin
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.2' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Remote Admin Connections' AS [System Value/Parameter],'The remote admin connections option controls whether a client application on a remote computer can use the Dedicated Administrator Connection (DAC). Should not be applied to clusters.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteadmin) + '' AS [Agreed to Value],'NOK' AS [Result];
    ELSE
	-- Cluster Service Not to disable ( the result will be ok as the query will return no data )
        IF @resultremoteadmin IS NULL
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.2' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Remote Admin Connections' AS [System Value/Parameter],'The remote admin connections option controls whether a client application on a remote computer can use the Dedicated Administrator Connection (DAC). Should not be applied to clusters.' AS [Description],
                   '' + CONVERT (VARCHAR, @remoteadmin) + '' AS [Agreed to Value],'OK' AS [Result];
    --AO.1.8.3
	DECLARE @SqlStatement AS VARCHAR (8000);
    DECLARE @DB AS NVARCHAR (256);
  	CREATE TABLE #Tmpsymmetric ([Databasename] VARCHAR(250),[Key_Name] VARCHAR(50),[key_algorithm] CHAR (2),[algorithm_desc] NVARCHAR(60));
    DECLARE cursor_symmetric CURSOR FAST_FORWARD
        FOR SELECT name FROM master.sys.databases WHERE  state_desc = 'ONLINE' AND database_id > 4;
    OPEN cursor_symmetric;
    WHILE 1 = 1
        BEGIN
            FETCH NEXT FROM cursor_symmetric INTO @DB;
            IF @@FETCH_STATUS = -1
                BREAK;
            SET @SqlStatement = N'USE ' + QUOTEname(@DB) + CHAR(13) + CHAR(10) + N'INSERT INTO #Tmpsymmetric
			SELECT db_name() AS Database_Name, name AS Key_Name,key_algorithm,algorithm_desc FROM sys.symmetric_keys';
            EXECUTE (@SqlStatement);
        END
    CLOSE cursor_symmetric;
    DEALLOCATE cursor_symmetric;
    IF NOT EXISTS (SELECT * FROM #Tmpsymmetric where [algorithm_desc] <>@symmetrickeys and [algorithm_desc] <>'AES_256')
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.3' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Symmetric Key Encryption Levels' AS [System Value/Parameter],'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
                   '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.3' AS [Section],
                   'Protecting Resources - OSRs' AS [Section Heading],'Symmetric Key Encryption Levels' AS [System Value/Parameter],'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
                   '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],'NOK' AS [Result];
        END
    --AO.1.8.4
	DECLARE @resultremoteaccess AS INT;
    SET @resultremoteaccess = (SELECT CAST(value AS INT) AS value_configured FROM sys.configurations WHERE name='remote access');
    IF @resultremoteaccess = @remoteaccess
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.4' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Remote Access' AS [System Value/Parameter],'The remote access option controls the execution of local stored procedures on remote servers or remote stored procedures on local server.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteaccess) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.4' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Remote Access' AS [System Value/Parameter],'The remote access option controls the execution of local stored procedures on remote servers or remote stored procedures on local server.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteaccess) + '' AS [Agreed to Value],'NOK' AS [Result];
   	--AO.1.8.5
	DECLARE @SqlStatement1 AS VARCHAR (8000);
    DECLARE @DB1 AS NVARCHAR (256);
    CREATE TABLE #Tmpasymmetric ([Databasename] VARCHAR (250),[Key_Name] NVARCHAR (150), [key_length] int,[algorithm] char(2),[algorithm_desc] NVARCHAR (60));
    DECLARE cursor_Asymmetric CURSOR FAST_FORWARD
        FOR SELECT name FROM master.sys.databases WHERE state_desc='ONLINE' AND database_id > 4;
    OPEN cursor_Asymmetric;
    WHILE 1 = 1
        BEGIN
            FETCH NEXT FROM cursor_Asymmetric INTO @DB1;
            IF @@FETCH_STATUS = -1
                BREAK;
            SET @SqlStatement1 = N'USE ' + QUOTEname(@DB1) + CHAR(13) + CHAR(10) + N'INSERT INTO #Tmpasymmetric
								 SELECT db_name() AS Database_Name, name AS [Key_Name],[key_length],[algorithm],[algorithm_desc] FROM sys.asymmetric_keys'
            EXECUTE (@SqlStatement1);
        END
    CLOSE cursor_Asymmetric;
    DEALLOCATE cursor_Asymmetric;
    IF NOT EXISTS (SELECT * FROM   #Tmpasymmetric where [key_length] <@asymmetricsize )
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.5' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Asymmetric Key Size' AS [System Value/Parameter],'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
                   '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.5' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Asymmetric Key Size' AS [System Value/Parameter],'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
                   '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],'NOK' AS [Result];
        END
    --AO.1.8.6
	DECLARE @resultscanprocs AS INT;
    SET @resultscanprocs = (SELECT CAST (value AS INT) AS value_configured FROM sys.configurations WHERE  name = 'scan for startup procs');
    IF @resultscanprocs = @scanprocs
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.6' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Scan for Startup Procs' AS [System Value/Parameter],'The scan for startup procs option, if enabled, causes SQL Server to scan for and automatically run all stored procedures that are set to execute upon service startup.' AS [Description],
               '' + CONVERT (VARCHAR, @scanprocs) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.6' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'Scan for Startup Procs' AS [System Value/Parameter],'The scan for startup procs option, if enabled, causes SQL Server to scan for and automatically run all stored procedures that are set to execute upon service startup.' AS [Description],
               '' + CONVERT (VARCHAR, @scanprocs) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.1
	DECLARE @resultadhocqueries AS INT;
    SET @resultadhocqueries = (SELECT CAST(value AS INT) AS value_configured FROM sys.configurations WHERE name ='Ad Hoc Distributed Queries');
    IF @resultadhocqueries = @adhocqueries
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.1' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'Adhoc Distributed Queries' AS [System Value/Parameter],'Ensure adhoc distributed queries is disabled.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @adhocqueries) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.1' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'Adhoc Distributed Queries' AS [System Value/Parameter],'Ensure adhoc distributed queries is disabled.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @adhocqueries) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.2
	DECLARE @resultclr AS INT;
    SET @resultclr = (SELECT CAST(value AS INT) AS value_configured FROM sys.configurations WHERE name='clr enabled');
    IF @resultclr = @clr
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.2' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'CLR Enabled' AS [System Value/Parameter],'The clr enabled option specifies whether user assemblies can be run by SQL Server.' AS [Description],
               'DISABLE - ' + CONVERT (VARCHAR, @clr) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.2' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'CLR Enabled' AS [System Value/Parameter],'The clr enabled option specifies whether user assemblies can be run by SQL Server.' AS [Description],
               'DISABLE - ' + CONVERT (VARCHAR, @clr) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.3
	DECLARE @resultole AS INT;
    SET @resultole = (SELECT CAST(value AS INT) AS value_configured FROM sys.configurations WHERE name='Ole Automation Procedures');
    IF @resultole = @ole
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.3' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'OLE Automation Procedures' AS [System Value/Parameter],'The Ole Automation Procedures option controls whether OLE Automation objects can be instantiated within Transact-SQL batches. These are extended stored procedures that allow SQL Server users to execute functions external to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @ole) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.3' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'OLE Automation Procedures' AS [System Value/Parameter],'The Ole Automation Procedures option controls whether OLE Automation objects can be instantiated within Transact-SQL batches. These are extended stored procedures that allow SQL Server users to execute functions external to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @ole) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.4
	DECLARE @resulttrustworthy AS INT;
    IF NOT EXISTS (SELECT name FROM sys.databases WHERE is_trustworthy_on=1 AND name !='msdb')
        BEGIN
            SET @resulttrustworthy = 0;
        END
    ELSE
        BEGIN
            SET @resulttrustworthy = 1;
        END
    IF @resulttrustworthy = @trustworthy
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.4' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'Trustworthy' AS [System Value/Parameter],'The TRUSTWORTHY database option allows database objects to access objects in other databases under certain circumstances.' AS [Description],
               'Off - ' + CONVERT (VARCHAR, @trustworthy) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.4' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'Trustworthy' AS [System Value/Parameter],'The TRUSTWORTHY database option allows database objects to access objects in other databases under certain circumstances.' AS [Description],
               'Off - ' + CONVERT (VARCHAR, @trustworthy) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.5
	IF NOT EXISTS (SELECT name,containment,containment_desc,is_auto_close_on FROM sys.databases WHERE  is_auto_close_on = 1)
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.5' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'Auto Close' AS [System Value/Parameter],'AUTO_CLOSE determines if a given database is closed or not after a connection terminates. If enabled, subsequent connections to the given database will require the database to be reopened and relevant procedure caches to be rebuilt.' AS [Description],
               'Off' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.5' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'Auto Close' AS [System Value/Parameter],'AUTO_CLOSE determines if a given database is closed or not after a connection terminates. If enabled, subsequent connections to the given database will require the database to be reopened and relevant procedure caches to be rebuilt.' AS [Description],
               'Off' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.6
	DECLARE @SqlStatement2 AS VARCHAR (8000);
    DECLARE @DB2 AS NVARCHAR (256);
    CREATE TABLE #Tmpclrassemblysafe ([Databasename] VARCHAR(250),[name] VARCHAR(150),[permision_set] INT,[permission_set_desc] VARCHAR(30));
    DECLARE cursor_clrassemblysafe CURSOR FAST_FORWARD
        FOR SELECT name FROM master.sys.databases WHERE  state_desc = 'ONLINE';
    OPEN cursor_clrassemblysafe;
    WHILE 1 = 1
        BEGIN
            FETCH NEXT FROM cursor_clrassemblysafe INTO @DB2;
            IF @@FETCH_STATUS = -1
                BREAK;
            SET @SqlStatement2 = N'USE ' + QUOTEname(@DB2) + CHAR(13) + CHAR(10) + N'INSERT INTO #Tmpclrassemblysafe
			                     SELECT db_name() AS Database_Name,name,permission_set,permission_set_desc FROM sys.assemblies WHERE is_user_defined = 1;';
            EXECUTE (@SqlStatement2);
        END
    CLOSE cursor_clrassemblysafe;
    DEALLOCATE cursor_clrassemblysafe;
    DECLARE @resultclrassemblysafe AS INT;
    IF NOT EXISTS (SELECT name FROM #Tmpclrassemblysafe)
	--There aren't any clr on the instance, mapping @clrassemblysafe to 0
        BEGIN
            SET @resultclrassemblysafe = 0;
            SET @clrassemblysafe = 0;
        END
    ELSE
        IF EXISTS (SELECT name FROM #Tmpclrassemblysafe WHERE [permision_set]=@clrassemblysafe)
            BEGIN
                SET @resultclrassemblysafe = 0;
            END
        ELSE
            BEGIN
                SET @resultclrassemblysafe = 1;
            END
    IF @resultclrassemblysafe = 0
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.6' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'CLR Assembly Safe' AS [System Value/Parameter],'Setting CLR Assembly Permission Sets to SAFE_ACCESS will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.' AS [Description],
               '' + CONVERT (VARCHAR, @clrassemblysafe) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        IF @resultclrassemblysafe = @clrassemblysafe
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.9.6' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'CLR Assembly Safe' AS [System Value/Parameter],'Setting CLR Assembly Permission Sets to SAFE_ACCESS will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.' AS [Description],
                   '' + CONVERT (VARCHAR, @clrassemblysafe) + '' AS [Agreed to Value],'OK' AS [Result];
        ELSE
            IF @resultclrassemblysafe <> @clrassemblysafe
                INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
                SELECT 'AO.1.9.6' AS [Section],'Protecting Resources - User Resources' AS [Section Heading],'CLR Assembly Safe' AS [System Value/Parameter],'Setting CLR Assembly Permission Sets to SAFE_ACCESS will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.' AS [Description],
                       '' + CONVERT (VARCHAR, @clrassemblysafe) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.1.9.7
	DECLARE @resultxpcmdshell AS INT;
    SET @resultxpcmdshell = (SELECT CAST(value AS INT) AS value_configured FROM sys.configurations WHERE name='xp_cmdshell');
    IF @resultxpcmdshell = @xpcmdshell
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.7' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'XP_CmdShell' AS [System Value/Parameter],'While XP_CmdShell is not a security risk, malicious users can attempt to elevate their privileges and / or deploy harmful codes on the system. The configuration parameter should left as Disabled as default.' AS [Description],
               '' + CONVERT (VARCHAR, @xpcmdshell) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.7' AS [Section],'Protecting Resources - OSRs' AS [Section Heading],'XP_CmdShell' AS [System Value/Parameter],'While XP_CmdShell is not a security risk, malicious users can attempt to elevate their privileges and / or deploy harmful codes on the system. The configuration parameter should left as Disabled as default.' AS [Description],
               '' + CONVERT (VARCHAR, @xpcmdshell) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.2.0.0
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.2.0.0' AS [Section],'Business use Notice' AS [Section Heading],'No configurable controls in this Section' AS [System Value/Parameter],'No configurable controls in this Section' AS [Description],
           'No value to be set','N\A' AS [Result];
	--AO.2.1.1
	    IF NOT EXISTS (SELECT * FROM #Tmpsymmetric where [algorithm_desc] <>@symmetrickeys and [algorithm_desc] <>'AES_256')
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.2.1.1' AS [Section],'Encryption' AS [Section Heading],'Ensure Symmetric Key encryption algorithm is set to AES_128 or higher in non-system databases' AS [System Value/Parameter],'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
                   '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.2.1.1' AS [Section],'Encryption' AS [Section Heading],'Ensure Symmetric Key encryption algorithm is set to AES_128 or higher in non-system databases' AS [System Value/Parameter],'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
                   '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],'NOK' AS [Result];
        END
	--AO.2.1.2
	IF NOT EXISTS (SELECT * FROM   #Tmpasymmetric where [key_length] <@asymmetricsize )
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.2.1.2' AS [Section],'Encryption' AS [Section Heading],'Ensure Asymmetric Key Size is set to greater than or equal to 2048 in non-system databases' AS [System Value/Parameter],'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
                   '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.2.1.2' AS [Section],'Encryption' AS [Section Heading],'Ensure Asymmetric Key Size is set to greater than or equal to 2048 in non-system databases' AS [System Value/Parameter],'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
                   '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],'NOK' AS [Result];
        END
    --AO.3.0.0
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.3.0.0' AS [Section],'Process Exceptions' AS [Section Heading],'No configurable controls in this Section' AS [System Value/Parameter],'No configurable controls in this Section' AS [Description],
           'No value to be set','N\A' AS [Result];
    --AO.5.0.0
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.5.0.0' AS [Section],'Privileged Authorizations / Userids' AS [Section Heading],'Note' AS [System Value/Parameter],'Description of privileged IDs: The rows in Section 5 below describe the list of UserIDs or groups that have Privileged authority.' AS [Description],
           'No value to be set','N\A' AS [Result];
    --AO.5.0.1
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.5.0.1' AS [Section],'Privileged Authorizations / Userids' AS [Section Heading],'Users assigned the roles of: Sysadmin' AS [System Value/Parameter],'List all members of the sysadmin role.' AS [Description],
           'No value to be set','N\A' AS [Result];
    --AO.5.0.2
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.5.0.2' AS [Section],'Privileged Authorizations / Userids' AS [Section Heading],'Users assigned the roles of: Securityadmin' AS [System Value/Parameter],'List all members of the Securityadmin role.' AS [Description],
           'No value to be set','N\A' AS [Result];
    
	IF @permanent=1
	BEGIN
	/* Check if output database exists in the server and abort in the case that it doesn't exists*/
	IF  (
	SELECT
	CASE WHEN
	@database IS NOT NULL AND @schema IS NOT NULL and @table IS NOT NULL AND EXISTS(
	SELECT  name,DATABASEPROPERTYEX(s.name,'status') as status from master..sysdatabases as s
	where s.name = @database and DATABASEPROPERTYEX(name,'status') ='ONLINE') THEN 1
		ELSE 0
	  END
	) = 0
	BEGIN
		DECLARE @msg1 VARCHAR(8000);
		SELECT @msg1 = 'Sorry but Database ' + @database+ ' does not exists or Database ' +@database+ ' is in the state <> Online'
		PRINT @msg1;
		RETURN;
	END;

	DECLARE @StringToExecute VARCHAR(8000)
	SET @StringToExecute = 'USE '
				+ @database + ';' + CHAR(13)
				+'IF  NOT EXISTS(SELECT * FROM '
				+ @database
				+ '.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '''
				+ @schema
				+ ''') ' + CHAR(13)
				+ 'EXEC sp_executesql N''CREATE SCHEMA ' + @schema + ''''
				+ CHAR(13)
				+'IF  EXISTS(SELECT * FROM '
				+ @database
				+ '.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '''
				+ @schema
				+ ''') ' + CHAR(13)
				+ 'AND NOT EXISTS (SELECT * FROM '
				+ @database
				+ '.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '''
				+ @schema + ''' AND TABLE_NAME = '''
				+ @table + ''') ' + CHAR(13) + 'CREATE TABLE '
				+ @schema + '.'
				+ @table
				+ N'(ID int NOT NULL IDENTITY(1,1),
					[Section] NVARCHAR(50) NOT NULL,
					[Section Heading] NVARCHAR(200) NOT NULL,
					[System Value/Parameter] NVARCHAR(200) NOT NULL,
					[Description] NVARCHAR(MAX) NOT NULL,
					[Agreed to Value] NVARCHAR(80) NOT NULL,
					[Result] VARCHAR(3) NOT NULL,  
					[SysDate] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY CLUSTERED(ID ASC));';
					EXEC(@StringToExecute);
	
	DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = '
	SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table + ' OFF' + ';' + +CHAR(13) +
	'INSERT INTO ' + @database +  '.' + @schema +  '.'+ @table + + CHAR(13) +
	'SELECT [Section],[Section Heading],[System Value/Parameter],[Description],[Agreed to Value],[Result],GETDATE() FROM #CSDResults ORDER BY ID ASC' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert

	IF @purge=1
	BEGIN
		--PRINT 'Purge Data from the values in the SP';
	    DECLARE @StringToExecute1 VARCHAR(8000)
		SET @StringToExecute1 = 'USE '
				+ @database + ';' + CHAR(13)
				+'IF  EXISTS(SELECT OBJECT_ID FROM '
				+ 'sys.tables WHERE NAME =''' +@table + ''''
				+ ' AND SCHEMA_NAME(schema_id) ='''+@schema +''
				+''')'
				+ CHAR(13)
				+ 'DELETE FROM ['+ @database+'].['+@schema+'].['+@table+'] WHERE [SysDate] <=GETDATE()-'+@defaultpurge+ ''
				+ CHAR(13)
				EXEC(@StringToExecute1);
		      
	END
	END;
	ELSE
	--return the Results
	SELECT [Section],[Section Heading],[System Value/Parameter],[Description],[Agreed to Value],[Result] FROM #CSDResults ORDER BY ID ASC;
	


    DROP TABLE #CSDResults;
    DROP TABLE #tabAuditLoginAttempts;
    DROP TABLE #GuestUsersReport;
    DROP TABLE #Tmpsymmetric;
    DROP TABLE #Tmpasymmetric;
    DROP TABLE #Tmpclrassemblysafe;
END

GO