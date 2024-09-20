USE [dba_database]
GO

Print 'Creating Stored Procedure CSD_Validation 8.0'

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'CSD_Validation')
	EXEC ('CREATE PROC [dbo].[CSD_Validation] AS SELECT ''stub version, to be replaced''')
GO


-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <02/04/2024>
-- Description:	<Validation of SQL Server CSD v7.2>
-- Alter date: <30/04/2024>
-- V01 -- Validation CSD 8.0
-- =============================================
ALTER PROCEDURE [dbo].[CSD_Validation]
@permanent BIT=0, @purge INT=1, @defaultpurge VARCHAR (5)=365, @Loginauditing CHAR (7)='failure', @NumLogs INT=99, @trace INT=1, @sqlaudit INT=1, @sqlpolicy INT=1, 
@bultinadmin INT=0, @guest INT=0, @cross INT=0, @sadisable INT=0, @databasemail INT=0, @remoteadmin INT=0, @remoteaccess INT=0, @scanprocs INT=0, @adhocqueries INT=0, 
@clr INT=0, @ole INT=0, @trustworthy INT=0, @clrassemblysafe INT=1, @xpcmdshell INT=0, @symmetrickeys NVARCHAR (60)='AES_256', @asymmetricsize INT=2048, @sarenamed INT=0, 
@sqlport INT=0,@hideinstance INT=0,@clrstrictsecurity INT=1,@orphanusers INT=0,@containedusers INT=0,@builtin INT=0,@winlocalgroups INT=0,@publicproxy INT=0,@sqlsaexpires INT=0,
@database VARCHAR (100)='dba_database', @schema VARCHAR (50)='dbo', @table VARCHAR (100)='CSD'
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
@sarenamed Values -> 0 - sa Disabled and renamed \ - sa Enabled and not renamed
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
@sqlport Values -> 0 - SQL Port is not 1433 \ 1 - SQL Port is 1433
@hideinstance Values -> 0 is not Hide \ 1 is Hide
@orphanusers Values -> 0 No orphan Users \ 1 Orphan Users
@containedusers Values -> 0 No sql Contained Users \ 1 Exists sql Contained Users
@builtin Values -> 0 No Bultin Users \ 1 Exists Bultin Users
@winlocalgroups Values -> 0 No Windows Local Users \ 1 Exists Windows Local Users
@publicproxy Values -> 0 No public Proxys in msdb \ 1 Exists public Proxys in msdb
@sqlsaexpires Values -> 0 No sql users with sa that not expires \ 1 Exists sql users with sa that not expires
*/

BEGIN
    SET NOCOUNT ON;
    DECLARE @sqlversion AS INT;
    SELECT @sqlversion = CONVERT (INT, (@@microsoftversion / 0x1000000) & 0xff);
    DECLARE @CSDVersion AS DECIMAL (10, 1);
    SET @CSDVersion = 8.0;
    IF (SELECT CASE WHEN @sqlversion = 8 THEN 0 ELSE 1 END) = 0
        BEGIN
            DECLARE @msg AS VARCHAR (8000);
            SELECT @msg = 'Sorry, not works on versions of SQL Server prior to 2005.' + REPLICATE(CHAR(13), 7933);
            PRINT @msg;
            RETURN;
        END
    IF OBJECT_ID('tempdb..#CSDResults') IS NOT NULL
        DROP TABLE #CSDResults;
    CREATE TABLE #CSDResults (
        [ID]                     INT            IDENTITY (1, 1) PRIMARY KEY CLUSTERED,
        [Section]                NVARCHAR (50)  NOT NULL,
        [Section Heading]        NVARCHAR (200) NOT NULL,
        [System Value/Parameter] NVARCHAR (200) NOT NULL,
        [Description]            NVARCHAR (MAX) NOT NULL,
        [Agreed to Value]        NVARCHAR (80)  NOT NULL,
        [Result]                 VARCHAR (3)    NOT NULL
    );
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
    SELECT 'AO.1.1.0' AS [Section],
           'Password Requirements' AS [Section Heading],
           'These requirements are covered at a Operating System level for all platforms.' AS [System Value/Parameter],
           'No configurable controls in this Section' AS [Description],
           'No value to be set' AS [Agreed to Value],
           'N\A' AS [Result];
	--AO.1.2.0.1
    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.2.0.1' AS [Section],
           'Logging' AS [Section Heading],
           'Local Logging' AS [System Value/Parameter],
           'Security event logs are retained locally and managed by OS. The exact path to these logs can vary based on the operating system and SQL Server configuration.' AS [Description],
           'No value to be set' AS [Agreed to Value],
           'N\A' AS [Result];
    --AO.1.2.0.2
    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.1.2.0.2' AS [Section],
           'Logging' AS [Section Heading],
           'Remote Logging' AS [System Value/Parameter],
           'Security event logs are not remotely logged.' AS [Description],
           'No value to be set' AS [Agreed to Value],
           'N\A' AS [Result];
	--AO.1.2.2
    CREATE TABLE #tabAuditLoginAttempts (
        [name]       sysname   ,
        config_value NCHAR (50)
    );
    INSERT INTO #tabAuditLoginAttempts
    EXECUTE master.dbo.xp_loginconfig 'audit level';
    DECLARE @result AS CHAR (7);
    SET @result = (SELECT config_value
                   FROM   #tabAuditLoginAttempts);
    IF (SELECT @result) = @Loginauditing
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.2' AS [Section],
               'Logging' AS [Section Heading],
               'Login auditing' AS [System Value/Parameter],
               'Record attempts to login to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @Loginauditing) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.2' AS [Section],
               'Logging' AS [Section Heading],
               'Login auditing' AS [System Value/Parameter],
               'Record attempts to login to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @Loginauditing) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.2.3
	DECLARE @NLogs AS INT;
    EXECUTE xp_instance_regread 'HKEY_LOCAL_MACHINE', 'Software\Microsoft\MSSQLServer\MSSQLServer', 'NumErrorLogs', @NLogs OUTPUT;
    IF @NLogs = @NumLogs
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.3' AS [Section],
               'Logging' AS [Section Heading],
               'Retain error log files' AS [System Value/Parameter],
               'Retain sql error log for a given number of iterations.' AS [Description],
               '' + CONVERT (VARCHAR, @NumLogs) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.3' AS [Section],
               'Logging' AS [Section Heading],
               'Retain error log files' AS [System Value/Parameter],
               'Retain sql error log for a given number of iterations.' AS [Description],
               '' + CONVERT (VARCHAR, @NumLogs) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.1.2.4
    DECLARE @resulttrace AS INT;
    SET @resulttrace = (SELECT CAST (value AS INT)
                        FROM   sys.configurations
                        WHERE  name = 'default trace enabled');
    IF @resulttrace = @trace
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.4' AS [Section],
               'Logging' AS [Section Heading],
               'Default trace enabled' AS [System Value/Parameter],
               'The default trace provides audit logging of database activity including account creations, privilege elevation and execution of DBCC commands.' AS [Description],
               '' + CONVERT (VARCHAR, @resulttrace) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.2.4' AS [Section],
               'Logging' AS [Section Heading],
               'Default trace enabled' AS [System Value/Parameter],
               'The default trace provides audit logging of database activity including account creations, privilege elevation and execution of DBCC commands.' AS [Description],
               '' + CONVERT (VARCHAR, @resulttrace) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.1.2.5
    DECLARE @resultsqlaudit AS INT;
    SET @resultsqlaudit = (SELECT COUNT(*)
                           FROM   (SELECT S.name AS 'Audit Name',
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
                                          AND S.is_state_enabled = 1) AS CountQuery);
    IF @resultsqlaudit = 3
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
            SELECT 'AO.1.2.5' AS [Section],
                   'Logging' AS [Section Heading],
                   'SQL Server Audit' AS [System Value/Parameter],
                   'SQL Server Audit is capable of capturing both failed and successful logins and writing them to one of three places: the application event log, the security event log, or the file system. We will use it to capture any login attempt to SQL Server, as well as any attempts to change audit policy. This will also serve to be a second source to record failed login attempts.' AS [Description],
                   'Failed and Successful' AS [Agreed to Value],
                   'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.2.5' AS [Section],
                   'Logging' AS [Section Heading],
                   'SQL Server Audit' AS [System Value/Parameter],
                   'SQL Server Audit is capable of capturing both failed and successful logins and writing them to one of three places: the application event log, the security event log, or the file system. We will use it to capture any login attempt to SQL Server, as well as any attempts to change audit policy. This will also serve to be a second source to record failed login attempts.' AS [Description],
                   'Failed and Successful' AS [Agreed to Value],
                   'NOK' AS [Result];
        END
	--AO.1.7.1
    DECLARE @resultpolicy AS INT;
    IF NOT EXISTS (SELECT name,
                          is_policy_checked
                   FROM   sys.sql_logins
                   WHERE  is_policy_checked <> 1)
        BEGIN
            SET @resultpolicy = 1;
        END
    ELSE
        BEGIN
            SET @resultpolicy = 0;
        END
    IF @resultpolicy = @sqlpolicy
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.1' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Account password policy enforcement' AS [System Value/Parameter],
               'Ensure active directory password policy is applied to sql logins. Applies to SQL 2005 onwards only.' AS [Description],
               'Enabled on all sql logins - ' + CONVERT (VARCHAR, @sqlpolicy) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.1' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Account password policy enforcement' AS [System Value/Parameter],
               'Ensure active directory password policy is applied to sql logins. Applies to SQL 2005 onwards only.' AS [Description],
               'Enabled on all sql logins - ' + CONVERT (VARCHAR, @sqlpolicy) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.7.4.2
	DECLARE @First AS SMALLINT, @Last AS SMALLINT, @DBName AS VARCHAR (200), @SQLCommand AS VARCHAR (500), @DBWithGuestAccess AS NVARCHAR (4000);
    IF OBJECT_ID('tempdb..#GuestUsersReport') IS NOT NULL
        DROP TABLE #GuestUsersReport;
    CREATE TABLE #GuestUsersReport (
        [Database]    VARCHAR (256),
        [UserName]    VARCHAR (256),
        [HasDbAccess] VARCHAR (10) 
    );
    DECLARE @DatabaseList TABLE (
        [RowNo]  SMALLINT      IDENTITY (1, 1),
        [DBName] VARCHAR (200));
    INSERT INTO @DatabaseList
    SELECT   d1.[name]
    FROM     [master]..[sysdatabases] AS d1 WITH (NOLOCK)
             INNER JOIN
             [sys].databases AS d2
             ON d1.dbid = d2.database_id
    WHERE    d1.[name] NOT IN ('master', 'tempdb', 'msdb')
             AND d2.state_desc = 'ONLINE'
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
    IF NOT EXISTS (SELECT *
                   FROM   #GuestUsersReport WITH (NOLOCK))
        BEGIN
            SET @resultguest = 0;
        END
    ELSE
        BEGIN
            SET @resultguest = 1;
        END
    IF @resultguest = @guest
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.4.2' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Guest Permissions' AS [System Value/Parameter],
               'Ensure guest has no permissions on user databases.' AS [Description],
               'Disable in all user databases - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.4.2' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Guest Permissions' AS [System Value/Parameter],
               'Ensure guest has no permissions on user databases.' AS [Description],
               'Disable in all user databases - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.7.5
	DECLARE @resultcross AS INT;
    SET @resultcross = (SELECT CONVERT (INT, (SELECT value_in_use
                                              FROM   sys.configurations
                                              WHERE  description = 'Allow cross db ownership chaining')));
    IF @resultcross = @cross
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.5' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Cross Database Permissions' AS [System Value/Parameter],
               'Ensure only explicitly assigned permissions are valid.' AS [Description],
               'Disabled for user databases only - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.5' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Cross Database Permissions' AS [System Value/Parameter],
               'Ensure only explicitly assigned permissions are valid.' AS [Description],
               'Disabled for user databases only - ' + CONVERT (VARCHAR, @bultinadmin) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.7.7
	DECLARE @resultsadisable AS INT;
    SET @resultsadisable = (SELECT COUNT(*)
                            FROM   sys.sql_logins
                            WHERE  principal_id = 1
                                   AND is_disabled = 0);
    IF @resultsadisable = @sadisable
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.7' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'sa Password recent versions' AS [System Value/Parameter],
               'Ensure sa account cannot be used' AS [Description],
               'Account should be disabled - ' + CONVERT (VARCHAR, @sadisable) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.7' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'sa Password recent versions' AS [System Value/Parameter],
               'Ensure sa account cannot be used' AS [Description],
               'Account should be disabled - ' + CONVERT (VARCHAR, @sadisable) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.1.7.10
    IF NOT EXISTS (SELECT *
                   FROM   master.sys.server_permissions
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
        SELECT 'AO.1.7.10' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Public access levels' AS [System Value/Parameter],
               'Public is a special fixed server role containing all logins. Unlike other fixed server roles, permissions can be changed for the public role. In keeping with the principle of least privileges, the public server role should not be used to grant permissions at the server scope as these would be inherited by all users.' AS [Description],
               'Nothing above base.' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.10' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Public access levels' AS [System Value/Parameter],
               'Public is a special fixed server role containing all logins. Unlike other fixed server roles, permissions can be changed for the public role. In keeping with the principle of least privileges, the public server role should not be used to grant permissions at the server scope as these would be inherited by all users.' AS [Description],
               'Nothing above base.' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.7.11
	IF NOT EXISTS (SELECT pr.[name] AS LocalGroupName,
                          pe.[permission_name],
                          pe.[state_desc]
                   FROM   sys.server_principals AS pr
                          INNER JOIN
                          sys.server_permissions AS pe
                          ON pr.[principal_id] = pe.[grantee_principal_id]
                   WHERE  pr.[type_desc] = 'WINDOWS_GROUP'
                          AND pr.[name] LIKE CAST (SERVERPROPERTY('MachineName') AS NVARCHAR) + '%')
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.11' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Windows local groups' AS [System Value/Parameter],
               'Local Windows groups should not be used as logins for SQL Server instances.' AS [Description],
               'Not present' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.11' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Windows local groups' AS [System Value/Parameter],
               'Local Windows groups should not be used as logins for SQL Server instances.' AS [Description],
               'Not present' AS [Agreed to Value],
               'NOK' AS [Result];
	-- AO.1.7.13
 		DECLARE @resultsarenamed AS INT;
		DECLARE @issarenamed AS INT;
		IF NOT EXISTS (SELECT name FROM   sys.sql_logins  WHERE  principal_id = 1  AND name='sa' ) 
			BEGIN
				SET @issarenamed = 0;
			END
		ELSE
			BEGIN
				SET @issarenamed = 1;
			END		
		DECLARE @isdisable as INT;
		IF NOT EXISTS (SELECT name FROM   sys.sql_logins  WHERE  principal_id = 1  AND is_disabled = 0 ) 
			BEGIN
				 SET @isdisable = 0;
			END
			ELSE
			BEGIN
				SET @isdisable = 1;
			END
			IF @issarenamed=0 and @isdisable=0
			BEGIN
				SET @resultsarenamed=0
			END
			ELSE
			BEGIN
				SET @resultsarenamed=1
			END
    IF @resultsarenamed = @sarenamed
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.13' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Ensure the sa Login Account has been renamed.' AS [System Value/Parameter],
               'Ensure sa account cannot be used by renaming it.' AS [Description],
               'Account should be renamed - ' + CONVERT (VARCHAR, @sarenamed) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.7.13' AS [Section],
               'Identify and Authenticate Users' AS [Section Heading],
               'Ensure the sa Login Account has been renamed.' AS [System Value/Parameter],
               'Ensure sa account cannot be used by renaming it.' AS [Description],
               'Account should be renamed - ' + CONVERT (VARCHAR, @sarenamed) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.8.1
	DECLARE @resultdatabasemail AS INT;
    SET @resultdatabasemail = (SELECT CAST (value_in_use AS INT) AS value_in_use
                               FROM   sys.configurations
                               WHERE  name = 'Database Mail XPs');
    IF @resultdatabasemail = @databasemail
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.1' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Database Mail XPs' AS [System Value/Parameter],
               'The Database Mail XPs option controls the ability to generate and transmit email messages from SQL Server.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @databasemail) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.1' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Database Mail XPs' AS [System Value/Parameter],
               'The Database Mail XPs option controls the ability to generate and transmit email messages from SQL Server.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @databasemail) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.8.2
	DECLARE @resultremoteadmin AS INT;
    SET @resultremoteadmin = (SELECT CAST (value_in_use AS INT) AS value_in_use
                              FROM   sys.configurations
                              WHERE  name = 'remote admin connections'
                                     AND SERVERPROPERTY('IsClustered') = 0);
    IF @resultremoteadmin = @remoteadmin
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.2' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Remote Admin Connections' AS [System Value/Parameter],
               'The remote admin connections option controls whether a client application on a remote computer can use the Dedicated Administrator Connection (DAC). Should not be applied to clusters.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteadmin) + '' AS [Agreed to Value],
               'OK' AS [Result];
    IF @resultremoteadmin <> @remoteadmin
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.2' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Remote Admin Connections' AS [System Value/Parameter],
               'The remote admin connections option controls whether a client application on a remote computer can use the Dedicated Administrator Connection (DAC). Should not be applied to clusters.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteadmin) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    ELSE
        IF @resultremoteadmin IS NULL
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.2' AS [Section],
                   'Protecting Resources - OSRs' AS [Section Heading],
                   'Remote Admin Connections' AS [System Value/Parameter],
                   'The remote admin connections option controls whether a client application on a remote computer can use the Dedicated Administrator Connection (DAC). Should not be applied to clusters.' AS [Description],
                   '' + CONVERT (VARCHAR, @remoteadmin) + '' AS [Agreed to Value],
                   'OK' AS [Result];
    --AO.1.8.3
	DECLARE @SqlStatement AS VARCHAR (8000);
    DECLARE @DB AS NVARCHAR (256);
    CREATE TABLE #Tmpsymmetric (
        [Databasename]   VARCHAR (250),
        [Key_Name]       VARCHAR (50) ,
        [key_algorithm]  CHAR (2)     ,
        [algorithm_desc] NVARCHAR (60)
    );
    DECLARE cursor_symmetric CURSOR FAST_FORWARD
        FOR SELECT name
            FROM   master.sys.databases
            WHERE  state_desc = 'ONLINE'
                   AND database_id > 4;
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
    IF NOT EXISTS (SELECT *
                   FROM   #Tmpsymmetric
                   WHERE  [algorithm_desc] <> @symmetrickeys
                          AND [algorithm_desc] <> 'AES_256')
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.3' AS [Section],
                   'Protecting Resources - OSRs' AS [Section Heading],
                   'Symmetric Key Encryption Levels' AS [System Value/Parameter],
                   'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
                   '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],
                   'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.3' AS [Section],
                   'Protecting Resources - OSRs' AS [Section Heading],
                   'Symmetric Key Encryption Levels' AS [System Value/Parameter],
                   'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
                   '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],
                   'NOK' AS [Result];
        END
    --AO.1.8.4
	DECLARE @resultremoteaccess AS INT;
    SET @resultremoteaccess = (SELECT CAST (value AS INT) AS value_configured
                               FROM   sys.configurations
                               WHERE  name = 'remote access');
    IF @resultremoteaccess = @remoteaccess
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.4' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Remote Access' AS [System Value/Parameter],
               'The remote access option controls the execution of local stored procedures on remote servers or remote stored procedures on local server.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteaccess) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.4' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Remote Access' AS [System Value/Parameter],
               'The remote access option controls the execution of local stored procedures on remote servers or remote stored procedures on local server.' AS [Description],
               '' + CONVERT (VARCHAR, @remoteaccess) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.8.5
	DECLARE @SqlStatement1 AS VARCHAR (8000);
    DECLARE @DB1 AS NVARCHAR (256);
    CREATE TABLE #Tmpasymmetric (
        [Databasename]   VARCHAR (250) ,
        [Key_Name]       NVARCHAR (150),
        [key_length]     INT           ,
        [algorithm]      CHAR (2)      ,
        [algorithm_desc] NVARCHAR (60) 
    );
    DECLARE cursor_Asymmetric CURSOR FAST_FORWARD
        FOR SELECT name
            FROM   master.sys.databases
            WHERE  state_desc = 'ONLINE'
                   AND database_id > 4;
    OPEN cursor_Asymmetric;
    WHILE 1 = 1
        BEGIN
            FETCH NEXT FROM cursor_Asymmetric INTO @DB1;
            IF @@FETCH_STATUS = -1
                BREAK;
            SET @SqlStatement1 = N'USE ' + QUOTEname(@DB1) + CHAR(13) + CHAR(10) + N'INSERT INTO #Tmpasymmetric
								 SELECT db_name() AS Database_Name, name AS [Key_Name],[key_length],[algorithm],[algorithm_desc] FROM sys.asymmetric_keys';
            EXECUTE (@SqlStatement1);
        END
    CLOSE cursor_Asymmetric;
    DEALLOCATE cursor_Asymmetric;
    IF NOT EXISTS (SELECT *
                   FROM   #Tmpasymmetric
                   WHERE  [key_length] < @asymmetricsize)
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.5' AS [Section],
                   'Protecting Resources - OSRs' AS [Section Heading],
                   'Asymmetric Key Size' AS [System Value/Parameter],
                   'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
                   '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],
                   'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.8.5' AS [Section],
                   'Protecting Resources - OSRs' AS [Section Heading],
                   'Asymmetric Key Size' AS [System Value/Parameter],
                   'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
                   '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],
                   'NOK' AS [Result];
        END
    --AO.1.8.6
	DECLARE @resultscanprocs AS INT;
    SET @resultscanprocs = (SELECT CAST (value AS INT) AS value_configured
                            FROM   sys.configurations
                            WHERE  name = 'scan for startup procs');
    IF @resultscanprocs = @scanprocs
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.6' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Scan for Startup Procs' AS [System Value/Parameter],
               'The scan for startup procs option, if enabled, causes SQL Server to scan for and automatically run all stored procedures that are set to execute upon service startup.' AS [Description],
               '' + CONVERT (VARCHAR, @scanprocs) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.8.6' AS [Section],
               'Protecting Resources - OSRs' AS [Section Heading],
               'Scan for Startup Procs' AS [System Value/Parameter],
               'The scan for startup procs option, if enabled, causes SQL Server to scan for and automatically run all stored procedures that are set to execute upon service startup.' AS [Description],
               '' + CONVERT (VARCHAR, @scanprocs) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.9.1
	DECLARE @resultadhocqueries AS INT;
    SET @resultadhocqueries = (SELECT CAST (value AS INT) AS value_configured
                               FROM   sys.configurations
                               WHERE  name = 'Ad Hoc Distributed Queries');
    IF @resultadhocqueries = @adhocqueries
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.1' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'Adhoc Distributed Queries' AS [System Value/Parameter],
               'Ensure adhoc distributed queries is disabled.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @adhocqueries) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.1' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'Adhoc Distributed Queries' AS [System Value/Parameter],
               'Ensure adhoc distributed queries is disabled.' AS [Description],
               'Disable - ' + CONVERT (VARCHAR, @adhocqueries) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.9.2
	DECLARE @resultclr AS INT;
    SET @resultclr = (SELECT CAST (value AS INT) AS value_configured
                      FROM   sys.configurations
                      WHERE  name = 'clr enabled');
    IF @resultclr = @clr
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.2' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'CLR Enabled' AS [System Value/Parameter],
               'The clr enabled option specifies whether user assemblies can be run by SQL Server.' AS [Description],
               'DISABLE - ' + CONVERT (VARCHAR, @clr) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.2' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'CLR Enabled' AS [System Value/Parameter],
               'The clr enabled option specifies whether user assemblies can be run by SQL Server.' AS [Description],
               'DISABLE - ' + CONVERT (VARCHAR, @clr) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.9.3
	DECLARE @resultole AS INT;
    SET @resultole = (SELECT CAST (value AS INT) AS value_configured
                      FROM   sys.configurations
                      WHERE  name = 'Ole Automation Procedures');
    IF @resultole = @ole
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.3' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'OLE Automation Procedures' AS [System Value/Parameter],
               'The Ole Automation Procedures option controls whether OLE Automation objects can be instantiated within Transact-SQL batches. These are extended stored procedures that allow SQL Server users to execute functions external to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @ole) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.3' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'OLE Automation Procedures' AS [System Value/Parameter],
               'The Ole Automation Procedures option controls whether OLE Automation objects can be instantiated within Transact-SQL batches. These are extended stored procedures that allow SQL Server users to execute functions external to SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @ole) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.9.4
	DECLARE @resulttrustworthy AS INT;
    IF NOT EXISTS (SELECT name
                   FROM   sys.databases
                   WHERE  is_trustworthy_on = 1
                          AND name != 'msdb')
        BEGIN
            SET @resulttrustworthy = 0;
        END
    ELSE
        BEGIN
            SET @resulttrustworthy = 1;
        END
    IF @resulttrustworthy = @trustworthy
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.4' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'Trustworthy' AS [System Value/Parameter],
               'The TRUSTWORTHY database option allows database objects to access objects in other databases under certain circumstances.' AS [Description],
               'Off - ' + CONVERT (VARCHAR, @trustworthy) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.4' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'Trustworthy' AS [System Value/Parameter],
               'The TRUSTWORTHY database option allows database objects to access objects in other databases under certain circumstances.' AS [Description],
               'Off - ' + CONVERT (VARCHAR, @trustworthy) + '' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.9.5
	IF NOT EXISTS (SELECT name,
                          containment,
                          containment_desc,
                          is_auto_close_on
                   FROM   sys.databases
                   WHERE  is_auto_close_on = 1)
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.5' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'Auto Close' AS [System Value/Parameter],
               'AUTO_CLOSE determines if a given database is closed or not after a connection terminates. If enabled, subsequent connections to the given database will require the database to be reopened and relevant procedure caches to be rebuilt.' AS [Description],
               'Off' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.5' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'Auto Close' AS [System Value/Parameter],
               'AUTO_CLOSE determines if a given database is closed or not after a connection terminates. If enabled, subsequent connections to the given database will require the database to be reopened and relevant procedure caches to be rebuilt.' AS [Description],
               'Off' AS [Agreed to Value],
               'NOK' AS [Result];
    --AO.1.9.6
	DECLARE @SqlStatement2 AS VARCHAR (8000);
    DECLARE @DB2 AS NVARCHAR (256);
    CREATE TABLE #Tmpclrassemblysafe (
        [Databasename]        VARCHAR (250),
        [name]                VARCHAR (150),
        [permision_set]       INT          ,
        [permission_set_desc] VARCHAR (30) 
    );
    DECLARE cursor_clrassemblysafe CURSOR FAST_FORWARD
        FOR SELECT name
            FROM   master.sys.databases
            WHERE  state_desc = 'ONLINE';
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
    IF NOT EXISTS (SELECT name
                   FROM   #Tmpclrassemblysafe)
        BEGIN
            SET @resultclrassemblysafe = 0;
            SET @clrassemblysafe = 0;
        END
    ELSE
        IF EXISTS (SELECT name
                   FROM   #Tmpclrassemblysafe
                   WHERE  [permision_set] = @clrassemblysafe)
            BEGIN
                SET @resultclrassemblysafe = 0;
            END
        ELSE
            BEGIN
                SET @resultclrassemblysafe = 1;
            END
    IF @resultclrassemblysafe = 0
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.1.9.6' AS [Section],
               'Protecting Resources - User Resources' AS [Section Heading],
               'CLR Assembly Safe' AS [System Value/Parameter],
               'Setting CLR Assembly Permission Sets to SAFE_ACCESS will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.' AS [Description],
               '' + CONVERT (VARCHAR, @clrassemblysafe) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        IF @resultclrassemblysafe = @clrassemblysafe
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.1.9.6' AS [Section],
                   'Protecting Resources - User Resources' AS [Section Heading],
                   'CLR Assembly Safe' AS [System Value/Parameter],
                   'Setting CLR Assembly Permission Sets to SAFE_ACCESS will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.' AS [Description],
                   '' + CONVERT (VARCHAR, @clrassemblysafe) + '' AS [Agreed to Value],
                   'OK' AS [Result];
        ELSE
            IF @resultclrassemblysafe <> @clrassemblysafe
                INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
                SELECT 'AO.1.9.6' AS [Section],
                       'Protecting Resources - User Resources' AS [Section Heading],
                       'CLR Assembly Safe' AS [System Value/Parameter],
                       'Setting CLR Assembly Permission Sets to SAFE_ACCESS will prevent assemblies from accessing external system resources such as files, the network, environment variables, or the registry.' AS [Description],
                       '' + CONVERT (VARCHAR, @clrassemblysafe) + '' AS [Agreed to Value],
                       'NOK' AS [Result];
    
	--AO.1.9.7
	--DECLARE @resultxpcmdshell AS INT;
 --   SET @resultxpcmdshell = (SELECT CAST (value AS INT) AS value_configured
 --                            FROM   sys.configurations
 --                            WHERE  name = 'xp_cmdshell');
 --   IF @resultxpcmdshell = @xpcmdshell
 --       INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --       SELECT 'AO.1.9.7' AS [Section],
 --              'Protecting Resources - OSRs' AS [Section Heading],
 --              'XP_CmdShell' AS [System Value/Parameter],
 --              'While XP_CmdShell is not a security risk, malicious users can attempt to elevate their privileges and / or deploy harmful codes on the system. The configuration parameter should left as Disabled as default.' AS [Description],
 --              '' + CONVERT (VARCHAR, @xpcmdshell) + '' AS [Agreed to Value],
 --              'OK' AS [Result];
 --   ELSE
 --       INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --       SELECT 'AO.1.9.7' AS [Section],
 --              'Protecting Resources - OSRs' AS [Section Heading],
 --              'XP_CmdShell' AS [System Value/Parameter],
 --              'While XP_CmdShell is not a security risk, malicious users can attempt to elevate their privileges and / or deploy harmful codes on the system. The configuration parameter should left as Disabled as default.' AS [Description],
 --              '' + CONVERT (VARCHAR, @xpcmdshell) + '' AS [Agreed to Value],
 --              'NOK' AS [Result];
 --   INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --   --AO.2.0.0
 --   SELECT 'AO.2.0.0' AS [Section],
 --          'Business use Notice' AS [Section Heading],
 --          'No configurable controls in this Section' AS [System Value/Parameter],
 --          'No configurable controls in this Section' AS [Description],
 --          'No value to be set',
 --          'N\A' AS [Result];
    --AO.2.1.1
	--IF NOT EXISTS (SELECT *
 --                  FROM   #Tmpsymmetric
 --                  WHERE  [algorithm_desc] <> @symmetrickeys
 --                         AND [algorithm_desc] <> 'AES_256')
 --       BEGIN
 --           INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --           SELECT 'AO.2.1.1' AS [Section],
 --                  'Encryption' AS [Section Heading],
 --                  'Ensure Symmetric Key encryption algorithm is set to AES_128 or higher in non-system databases' AS [System Value/Parameter],
 --                  'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
 --                  '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],
 --                  'OK' AS [Result];
 --       END
 --   ELSE
 --       BEGIN
 --           INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --           SELECT 'AO.2.1.1' AS [Section],
 --                  'Encryption' AS [Section Heading],
 --                  'Ensure Symmetric Key encryption algorithm is set to AES_128 or higher in non-system databases' AS [System Value/Parameter],
 --                  'Per the Microsoft Best Practices, only the SQL Server AES algorithm options, AES_128, AES_192, and AES_256, should be used for a symmetric key encryption algorithm.' AS [Description],
 --                  '' + CONVERT (VARCHAR, @symmetrickeys) + '' AS [Agreed to Value],
 --                  'NOK' AS [Result];
 --       END
    --AO.2.1.2
	--IF NOT EXISTS (SELECT *
 --                  FROM   #Tmpasymmetric
 --                  WHERE  [key_length] < @asymmetricsize)
 --       BEGIN
 --           INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --           SELECT 'AO.2.1.2' AS [Section],
 --                  'Encryption' AS [Section Heading],
 --                  'Ensure Asymmetric Key Size is set to greater than or equal to 2048 in non-system databases' AS [System Value/Parameter],
 --                  'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
 --                  '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],
 --                  'OK' AS [Result];
 --       END
 --   ELSE
 --       BEGIN
 --           INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --           SELECT 'AO.2.1.2' AS [Section],
 --                  'Encryption' AS [Section Heading],
 --                  'Ensure Asymmetric Key Size is set to greater than or equal to 2048 in non-system databases' AS [System Value/Parameter],
 --                  'Microsoft Best Practices recommend to use at least a 2048-bit encryption algorithm for asymmetric keys.' AS [Description],
 --                  '' + CONVERT (VARCHAR, @asymmetricsize) + '' AS [Agreed to Value],
 --                  'NOK' AS [Result];
 --       END
    --AO.3.0.0
	--INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
 --   SELECT 'AO.3.0.0' AS [Section],
 --          'Process Exceptions' AS [Section Heading],
 --          'No configurable controls in this Section' AS [System Value/Parameter],
 --          'No configurable controls in this Section' AS [Description],
 --          'No value to be set',
 --          'N\A' AS [Result];
    --AO.5.0.0
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.5.0.0' AS [Section],
           'Privileged Authorizations / Userids' AS [Section Heading],
           'Note' AS [System Value/Parameter],
           'Description of privileged IDs: The rows in Section 5 below describe the list of UserIDs or groups that have Privileged authority.' AS [Description],
           'No value to be set',
           'N\A' AS [Result];
    --AO.5.0.1
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.5.0.1' AS [Section],
           'Privileged Authorizations / Userids' AS [Section Heading],
           'Users assigned the roles of: Sysadmin' AS [System Value/Parameter],
           'List all members of the sysadmin role.' AS [Description],
           'No value to be set',
           'N\A' AS [Result];
    --AO.5.0.2
	INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
    SELECT 'AO.5.0.2' AS [Section],
           'Privileged Authorizations / Userids' AS [Section Heading],
           'Users assigned the roles of: Securityadmin' AS [System Value/Parameter],
           'List all members of the Securityadmin role.' AS [Description],
           'No value to be set',
           'N\A' AS [Result];
	--AO.C.6.1.1
	DECLARE @querysqlport AS INT;
	SET  @querysqlport  = (SELECT count(*) FROM sys.dm_server_registry WHERE value_name like '%Tcp%' and value_data='1433');
	DECLARE @resultsqlport AS INT;
	IF @querysqlport =0
		BEGIN 
			SET @resultsqlport=0
		END
		ELSE
		BEGIN
			SET @resultsqlport=1
		END
	
    IF @resultsqlport = @sqlport
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.1' AS [Section],
               'Surface Area Reduction' AS [Section Heading],'Ensure SQL Server is configured to use non-standard ports.' AS [System Value/Parameter],
               'If installed, a default SQL Server instance will be assigned a default port of `TCP:1433` for TCP/IP communication. Administrators can also manually configure named instances to use `TCP:1433` for communication. `TCP:1433` is a widely known SQL Server port and this port assignment should be changed. In a multi-instance scenario, each instance must be assigned its own dedicated TCP/IP port.' AS [Description],
               '' + CONVERT (VARCHAR, @sqlport) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.1' AS [Section],
               'Surface Area Reduction' AS [Section Heading],
               'Ensure SQL Server is configured to use non-standard ports.' AS [System Value/Parameter],
               'If installed, a default SQL Server instance will be assigned a default port of `TCP:1433` for TCP/IP communication. Administrators can also manually configure named instances to use `TCP:1433` for communication. `TCP:1433` is a widely known SQL Server port and this port assignment should be changed. In a multi-instance scenario, each instance must be assigned its own dedicated TCP/IP port.' AS [Description],
               '' + CONVERT (VARCHAR, @sqlport) + '' AS [Agreed to Value],'NOK' AS [Result];

	--AO.C.6.1.2
	DECLARE @resulthideinstance AS INT;
   	EXECUTE xp_instance_regread 'HKEY_LOCAL_MACHINE', 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib', 'HideInstance', @resulthideinstance OUTPUT;
    IF @resulthideinstance = @hideinstance
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.2' AS [Section],'Surface Area Reduction' AS [Section Heading],'Ensure Hide Instance option is set to Yes for Production SQL Server instances.' AS [System Value/Parameter],
               'Non-clustered SQL Server instances within production environments should be designated as hidden to prevent advertisement by the SQL Server Browser service.' AS [Description],
               '' + CONVERT (VARCHAR, @hideinstance) + '' AS [Agreed to Value],'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.2' AS [Section],'Surface Area Reduction' AS [Section Heading],'Ensure Hide Instance option is set to Yes for Production SQL Server instances.' AS [System Value/Parameter],
               'Non-clustered SQL Server instances within production environments should be designated as hidden to prevent advertisement by the SQL Server Browser service.' AS [Description],
               '' + CONVERT (VARCHAR, @hideinstance) + '' AS [Agreed to Value],'NOK' AS [Result];
    --AO.C.6.1.3
	IF @resultsarenamed = @sarenamed
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.3' AS [Section],'Surface Area Reduction' AS [Section Heading],
               'Ensure no login exists with the name sa.' AS [System Value/Parameter],
               'The `sa` login (e.g. principal) is a widely known and often widely used SQL Server account. Therefore, there should not be a login called `sa` even when the original `sa` login (`principal_id = 1`) has been renamed.' AS [Description],
               'Ensure SA account disabled, renamed. - ' + CONVERT (VARCHAR, @sarenamed) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.3' AS [Section],'Surface Area Reduction' AS [Section Heading],
               'Ensure no login exists with the name sa.' AS [System Value/Parameter],
               'The `sa` login (e.g. principal) is a widely known and often widely used SQL Server account. Therefore, there should not be a login called `sa` even when the original `sa` login (`principal_id = 1`) has been renamed.' AS [Description],
               'Ensure SA account disabled, renamed. - ' + CONVERT (VARCHAR, @sarenamed) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.C.6.1.4
	DECLARE @resultclrstrictsecurity AS INT;
    SET @resultclrstrictsecurity = (SELECT CAST (value AS INT) AS value_configured
                               FROM   sys.configurations
                               WHERE  name = 'clr strict security');
    IF @resultclrstrictsecurity = @clrstrictsecurity

        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.4' AS [Section],
               'Surface Area Reduction' AS [Section Heading],
               'Ensure clr strict security Server Configuration Option is set to 1.' AS [System Value/Parameter],
               'The `clr strict security` option specifies whether the engine applies the `PERMISSION_SET` on the assemblies.' AS [Description],
               '' + CONVERT (VARCHAR, @clrstrictsecurity) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.6.1.4' AS [Section],
               'Surface Area Reduction' AS [Section Heading],
               'Ensure clr strict security Server Configuration Option is set to 1.' AS [System Value/Parameter],
               'The `clr strict security` option specifies whether the engine applies the `PERMISSION_SET` on the assemblies.' AS [Description],
               '' + CONVERT (VARCHAR, @clrstrictsecurity) + '' AS [Agreed to Value],
               'NOK' AS [Result];

	--AO.C.7.1.1
	DECLARE @SqlStatement3 AS VARCHAR (8000);
    DECLARE @DB3 AS NVARCHAR (256);
    CREATE TABLE #TmpOrphan ([databasename] VARCHAR (150),[username] VARCHAR (150));
    DECLARE cursor_clrassemblysafe CURSOR FAST_FORWARD
        FOR SELECT name
            FROM   master.sys.databases
            WHERE  state_desc = 'ONLINE';
    OPEN cursor_clrassemblysafe;
    WHILE 1 = 1
        BEGIN
            FETCH NEXT FROM cursor_clrassemblysafe INTO @DB3;
            IF @@FETCH_STATUS = -1
                BREAK;
            SET @SqlStatement3 = N'USE ' + QUOTEname(@DB3) + CHAR(13) + CHAR(10) + N'INSERT INTO #TmpOrphan
			                     SELECT DB_NAME() as [databasename] ,p.name from sys.database_principals p
								 where p.type in (''G'',''S'',''U'') -- S = SQL user, U = Windows user, G = Windows group
								 and p.sid not in (select sid from sys.server_principals)
								 and p.name not in (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'',''MS_DataCollectorInternalUser'');';
            EXECUTE (@SqlStatement3);
        END
    CLOSE cursor_clrassemblysafe;
    DEALLOCATE cursor_clrassemblysafe;
    
	DECLARE @resultorphanusers INT;
	IF NOT EXISTS (select * from #TmpOrphan)
	 BEGIN
		SET @resultorphanusers =0
	 END
	 ELSE
	 BEGIN
		SET @resultorphanusers =1
	 END
	
	IF @resultorphanusers = @orphanusers
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.C.7.1.1' AS [Section],
                   'Authentication and Authorization' AS [Section Heading],
                   'Ensure Orphaned Users are Dropped From SQL Server Databases.' AS [System Value/Parameter],
                   'A database user for which the corresponding SQL Server login is undefined or is incorrectly defined on a server instance cannot log in to the instance and is referred to as orphaned and should be removed.' AS [Description],
                   '' + CONVERT (VARCHAR, @orphanusers) + '' +' orphan users' AS [Agreed to Value],
                   'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.C.7.1.1' AS [Section],
                   'Authentication and Authorization' AS [Section Heading],
                   'Ensure Orphaned Users are Dropped From SQL Server Databases.' AS [System Value/Parameter],
                   'A database user for which the corresponding SQL Server login is undefined or is incorrectly defined on a server instance cannot log in to the instance and is referred to as orphaned and should be removed.' AS [Description],
                   '' + CONVERT (VARCHAR, @orphanusers) + '' +' orphan users' AS [Agreed to Value],
                   'NOK' AS [Result];
        END
	--AO.C.7.1.2
	DECLARE @SqlStatement4 AS VARCHAR (8000);
    DECLARE @DB4 AS NVARCHAR (256);
    CREATE TABLE #TmpContained ([databasename] VARCHAR (150),[username] VARCHAR (150));
    DECLARE cursor_clrassemblysafe CURSOR FAST_FORWARD
        FOR SELECT name
            FROM   master.sys.databases
            WHERE  state_desc = 'ONLINE';
    OPEN cursor_clrassemblysafe;
    WHILE 1 = 1
        BEGIN
            FETCH NEXT FROM cursor_clrassemblysafe INTO @DB4;
            IF @@FETCH_STATUS = -1
                BREAK;
            SET @SqlStatement4 = N'USE ' + QUOTEname(@DB4) + CHAR(13) + CHAR(10) + N'INSERT INTO #TmpContained
				SELECT DB_NAME() as [databasename],name AS DBUser
			FROM sys.database_principals
				WHERE name NOT IN (''dbo'',''Information_Schema'',''sys'',''guest'') AND type IN (''U'',''S'',''G'') AND authentication_type = 2;';
            EXECUTE (@SqlStatement4);
        END
    CLOSE cursor_clrassemblysafe;
    DEALLOCATE cursor_clrassemblysafe;

	DECLARE @resultcontainedusers INT;
	IF NOT EXISTS (select * from #TmpContained)
	 BEGIN
		SET @resultcontainedusers =0
	 END
	 ELSE
	 BEGIN
		SET @resultcontainedusers =1
	 END
	
	IF @resultcontainedusers = @containedusers
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.C.7.1.2' AS [Section],
                   'Authentication and Authorization' AS [Section Heading],
                   'Ensure SQL Authentication is not used in contained databases.' AS [System Value/Parameter],
                   'Contained databases do not enforce password complexity rules for SQL Authenticated users.' AS [Description],
                   '' + CONVERT (VARCHAR, @containedusers) + '' AS [Agreed to Value],
                   'OK' AS [Result];
        END
    ELSE
        BEGIN
            INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
            SELECT 'AO.C.7.1.2' AS [Section],
                   'Authentication and Authorization' AS [Section Heading],
                   'Ensure SQL Authentication is not used in contained databases.' AS [System Value/Parameter],
                   'Contained databases do not enforce password complexity rules for SQL Authenticated users.' AS [Description],
                   '' + CONVERT (VARCHAR, @containedusers) + '' AS [Agreed to Value],
                   'NOK' AS [Result];
        END
	--AO.C.7.1.3
	DECLARE @resultbuiltin AS INT;
	IF NOT EXISTS ( SELECT pr.[name], pe.[permission_name], pe.[state_desc] FROM sys.server_principals pr JOIN sys.server_permissions pe
					ON pr.principal_id = pe.grantee_principal_id WHERE pr.name like 'BUILTIN%')
	BEGIN
	    SET @resultbuiltin=0
	END
	ELSE
	BEGIN
		SET @resultbuiltin=1
	END
    IF @resultbuiltin = @builtin
	    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.7.1.3' AS [Section],
               'Authentication and Authorization' AS [Section Heading],
               'Ensure Windows BUILTIN groups are not SQL Logins.' AS [System Value/Parameter],
               'Prior to SQL Server 2008, the `BUILTIN\Administrators` group was added as a SQL Server login with sysadmin privileges during installation by default. Best practices promote creating an Active Directory level group containing approved DBA staff accounts and using this controlled AD group as the login with sysadmin privileges. The AD group should be specified during SQL Server installation and the `BUILTIN\Administrators` group would therefore have no need to be a login.' AS [Description],
               '' + CONVERT (VARCHAR, @builtin) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.7.1.3' AS [Section],
               'Authentication and Authorization' AS [Section Heading],
               'Ensure Windows BUILTIN groups are not SQL Logins.' AS [System Value/Parameter],
               'Prior to SQL Server 2008, the `BUILTIN\Administrators` group was added as a SQL Server login with sysadmin privileges during installation by default. Best practices promote creating an Active Directory level group containing approved DBA staff accounts and using this controlled AD group as the login with sysadmin privileges. The AD group should be specified during SQL Server installation and the `BUILTIN\Administrators` group would therefore have no need to be a login.' AS [Description],
               '' + CONVERT (VARCHAR, @builtin) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.C.7.1.4
	DECLARE @resultwinlocalgroups AS INT;
	IF NOT EXISTS ( SELECT pr.[name] AS LocalGroupName, pe.[permission_name], pe.[state_desc]
					FROM sys.server_principals pr JOIN sys.server_permissions pe ON pr.[principal_id] = pe.[grantee_principal_id]
					WHERE pr.[type_desc] = 'WINDOWS_GROUP' AND pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%')
	BEGIN
	    SET @resultwinlocalgroups=0
	END
	ELSE
	BEGIN
		SET @resultwinlocalgroups=1
	END
    IF @resultwinlocalgroups = @winlocalgroups
	    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.7.1.4' AS [Section],
               'Authentication and Authorization' AS [Section Heading],
               'Ensure Windows local groups are not SQL Logins.' AS [System Value/Parameter],
               'Local Windows groups should not be used as logins for SQL Server instances.' AS [Description],
               '' + CONVERT (VARCHAR, @winlocalgroups) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.7.1.4' AS [Section],
               'Authentication and Authorization' AS [Section Heading],
               'Ensure Windows local groups are not SQL Logins.' AS [System Value/Parameter],
               'Local Windows groups should not be used as logins for SQL Server instances.' AS [Description],
               '' + CONVERT (VARCHAR, @winlocalgroups) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.C.7.1.5
	DECLARE @resultpublicproxy AS INT;
	IF NOT EXISTS ( SELECT sp.name AS proxyname FROM msdb.dbo.sysproxylogin spl JOIN sys.database_principals dp
					ON dp.sid = spl.sid JOIN msdb.dbo.sysproxies sp ON sp.proxy_id = spl.proxy_id WHERE principal_id = USER_ID('public'))
	BEGIN
	    SET @resultpublicproxy=0
	END
	ELSE
	BEGIN
		SET @resultpublicproxy=1
	END
    IF @resultpublicproxy = @publicproxy
	    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.7.1.5' AS [Section],
               'Authentication and Authorization' AS [Section Heading],
               'Ensure the public role in the msdb database is not granted access to SQL Agent proxies.' AS [System Value/Parameter],
               'The `public` database role contains every user in the `msdb` database. SQL Agent proxies define a security context in which a job step can run.' AS [Description],
               '' + CONVERT (VARCHAR, @publicproxy) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.7.1.5' AS [Section],
               'Authentication and Authorization' AS [Section Heading],
               'Ensure the public role in the msdb database is not granted access to SQL Agent proxies.' AS [System Value/Parameter],
               'The `public` database role contains every user in the `msdb` database. SQL Agent proxies define a security context in which a job step can run.' AS [Description],
               '' + CONVERT (VARCHAR, @publicproxy) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	--AO.C.8.1.1
	DECLARE @resultsqlsaexpires AS INT;
	IF NOT EXISTS (	SELECT l.[name], 'sysadmin membership' AS 'Access_Method' FROM sys.sql_logins AS l WHERE IS_SRVROLEMEMBER('sysadmin',name) = 1
					AND l.principal_id <>1 AND l.is_expiration_checked <> 1	AND l.is_disabled<>1
					UNION ALL
					SELECT l.[name], 'CONTROL SERVER' AS 'Access_Method' FROM sys.sql_logins AS l JOIN sys.server_permissions AS p
					ON l.principal_id = p.grantee_principal_id WHERE l.principal_id <>1 AND p.type = 'CL' AND p.state IN ('G', 'W')
					AND l.is_disabled<>0 AND l.is_expiration_checked <> 1)
	BEGIN
	    SET @resultsqlsaexpires=0
	END
	ELSE
	BEGIN
		SET @resultsqlsaexpires=1
	END
    IF @resultsqlsaexpires = @sqlsaexpires
	    INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.8.1.1' AS [Section],
               'Password Policies' AS [Section Heading],
               'Ensure CHECK_EXPIRATION Option is set to ON for All SQL Authenticated Logins Within the Sysadmin Role.' AS [System Value/Parameter],
               'Applies the same password expiration policy used in Windows to passwords used inside SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @sqlsaexpires) + '' AS [Agreed to Value],
               'OK' AS [Result];
    ELSE
        INSERT INTO #CSDResults ([Section], [Section Heading], [System Value/Parameter], [Description], [Agreed to Value], [Result])
        SELECT 'AO.C.8.1.1' AS [Section],
               'Password Policies' AS [Section Heading],
               'Ensure CHECK_EXPIRATION Option is set to ON for All SQL Authenticated Logins Within the Sysadmin Role.' AS [System Value/Parameter],
               'Applies the same password expiration policy used in Windows to passwords used inside SQL Server.' AS [Description],
               '' + CONVERT (VARCHAR, @sqlsaexpires) + '' AS [Agreed to Value],
               'NOK' AS [Result];
	





	
	IF @permanent = 1
        BEGIN
            IF (SELECT CASE WHEN @database IS NOT NULL
                                 AND @schema IS NOT NULL
                                 AND @table IS NOT NULL
                                 AND EXISTS (SELECT name,
                                                    DATABASEPROPERTYEX(s.name, 'status') AS status
                                             FROM   master..sysdatabases AS s
                                             WHERE  s.name = @database
                                                    AND DATABASEPROPERTYEX(name, 'status') = 'ONLINE') THEN 1 ELSE 0 END) = 0
                BEGIN
                    DECLARE @msg1 AS VARCHAR (8000);
                    SELECT @msg1 = 'Sorry but Database ' + @database + ' does not exists or Database ' + @database + ' is in the state <> Online';
                    PRINT @msg1;
                    RETURN;
                END
            DECLARE @StringToExecute AS VARCHAR (8000);
            SET @StringToExecute = 'USE ' + @database + ';' + CHAR(13) + 'IF  NOT EXISTS(SELECT * FROM ' + @database + '.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ''' + @schema + ''') ' + CHAR(13) + 'EXEC sp_executesql N''CREATE SCHEMA ' + @schema + '''' + CHAR(13) + 'IF  EXISTS(SELECT * FROM ' + @database + '.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ''' + @schema + ''') ' + CHAR(13) + 'AND NOT EXISTS (SELECT * FROM ' + @database + '.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ''' + @schema + ''' AND TABLE_NAME = ''' + @table + ''') ' + CHAR(13) + 'CREATE TABLE ' + @schema + '.' + @table + N'(ID int NOT NULL IDENTITY(1,1),
					[Section] NVARCHAR(50) NOT NULL,
					[Section Heading] NVARCHAR(200) NOT NULL,
					[System Value/Parameter] NVARCHAR(200) NOT NULL,
					[Description] NVARCHAR(MAX) NOT NULL,
					[Agreed to Value] NVARCHAR(80) NOT NULL,
					[Result] VARCHAR(3) NOT NULL,  
					[SysDate] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table, '[', ''), ']', '') + '] PRIMARY KEY CLUSTERED(ID ASC));';
            EXECUTE (@StringToExecute);
            DECLARE @sqlinsert AS NVARCHAR (MAX);
            SET @sqlinsert = '
	SET IDENTITY_INSERT  ' + @database + '.' + @schema + '.' + @table + ' OFF' + ';' + +CHAR(13) + 'INSERT INTO ' + @database + '.' + @schema + '.' + @table + +CHAR(13) + 'SELECT [Section],[Section Heading],[System Value/Parameter],[Description],[Agreed to Value],[Result],GETDATE() FROM #CSDResults ORDER BY ID ASC' + CHAR(13) + 'SET IDENTITY_INSERT  ' + @database + '.' + @schema + '.' + @table + ' ON' + ';';
            EXECUTE sp_executesql @sqlinsert;
            IF @purge = 1
                BEGIN
                    DECLARE @StringToExecute1 AS VARCHAR (8000);
                    SET @StringToExecute1 = 'USE ' + @database + ';' + CHAR(13) + 'IF  EXISTS(SELECT OBJECT_ID FROM ' + 'sys.tables WHERE NAME =''' + @table + '''' + ' AND SCHEMA_NAME(schema_id) =''' + @schema + '' + ''')' + CHAR(13) + 'DELETE FROM [' + @database + '].[' + @schema + '].[' + @table + '] WHERE [SysDate] <=GETDATE()-' + @defaultpurge + '' + CHAR(13);
                    EXECUTE (@StringToExecute1);
                END
        END
    ELSE
        SELECT   [Section],
                 [Section Heading],
                 [System Value/Parameter],
                 [Description],
                 [Agreed to Value],
                 [Result]
        FROM     #CSDResults
        ORDER BY ID ASC;
    DROP TABLE #CSDResults;
    DROP TABLE #tabAuditLoginAttempts;
    DROP TABLE #GuestUsersReport;
    DROP TABLE #Tmpsymmetric;
    DROP TABLE #Tmpasymmetric;
    DROP TABLE #Tmpclrassemblysafe;
	DROP table #TmpOrphan;
	DROP TABLE #TmpContained;
END

GO


