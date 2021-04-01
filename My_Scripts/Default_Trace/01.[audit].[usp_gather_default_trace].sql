USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'audit' ) 
    EXEC('CREATE SCHEMA [audit] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'usp_gather_default_trace')
	EXEC ('CREATE PROC audit.usp_gather_default_trace AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <06/10/2020>
-- Description:	<Gather Information about Database Extends and objects and users from default trace>
-- V.01 <08/01/2021>
-- V.02 <01/04/2021> 
-- Repair error in collation SQL_Latin1_General_CP1_CS_AS -- Invalid column name 'xxx' --
-- Usage Examples:
-- Display the records from the Audit Trace on the last 30 days
-- exec [audit].[usp_gather_default_trace] @hours=720 < Note: Need to convert previously hours in days, in this example is 30 days >
-- Create a table if not exists and dumps the output of the default trace on it
-- exec [audit].[usp_gather_default_trace] @permanent=1 < Note: will retain the value in Variable @hours >
-- =============================================
ALTER PROCEDURE [audit].[usp_gather_default_trace]
	-- Parameters for the stored procedure --
	@permanent BIT =0, @hours INT=24,@purge INT=1,@defaultpurge VARCHAR(5)=180,
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='audit',@table VARCHAR(100)='default_trace'
AS
BEGIN

	SET NOCOUNT ON;
	/* Check SQL Server Version and abort in the case that the version is prior to SQL Server 2008*/
	IF (
SELECT
  CASE
     WHEN CONVERT(NVARCHAR(128), SERVERPROPERTY ('PRODUCTVERSION')) LIKE '8%' THEN 0
     WHEN CONVERT(NVARCHAR(128), SERVERPROPERTY ('PRODUCTVERSION')) LIKE '9%' THEN 0
	 ELSE 1
  END
) = 0
BEGIN
	DECLARE @msg VARCHAR(8000);
	SELECT @msg = 'Sorry, only works on versions of SQL prior to 2008.' + REPLICATE(CHAR(13),7933);
	PRINT @msg;
	RETURN;
END;
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

DECLARE @value VARCHAR(max)

SELECT @value = Substring(path, 0, Len(path)-Charindex('\', Reverse(path))+1) + '\Log.trc'
FROM   sys.traces
WHERE  is_default = 1;

IF Object_id('tempdb..#Temptrace1') IS NOT NULL
  DROP TABLE #temptrace1

IF Object_id('tempdb..#Temptrace2') IS NOT NULL
  DROP TABLE #temptrace2

IF Object_id('tempdb..#Temptracefinal') IS NOT NULL
  DROP TABLE #temptracefinal

SELECT ftg.SPID                                                 AS Spid,
       ftg.StartTime                                            AS StartTime,
       ftg.DatabaseName                                         AS DatabaseName,
       Cast(NULL AS NVARCHAR(256)) COLLATE latin1_general_ci_as AS Filename,
       Cast(NULL AS DECIMAL(10, 2))                             AS TimeTakenSeconds,
       Cast(NULL AS DECIMAL(18, 6))                             AS ChangeSizeMB,
       te.[name]                                                AS EventClass,
       tcg.[name]                                               AS Category,
       sv.[name] COLLATE latin1_general_ci_as                   AS ObjectType,
       ftg.ObjectName                                           AS ObjectName,
       CONVERT(VARCHAR(10), tsv.subclass_value)
       + ' - ' + tsv.subclass_name COLLATE latin1_general_ci_as AS EventSubClass,
       ftg.TextData                                             AS TextData,
       ftg.HostName                                             AS HostName,
       ftg.ApplicationName                                      AS ApplicationName,
       ftg.LoginName                                            AS LoginName,
       ftg.ServerName                                           AS ServerName,
       ftg.OwnerName                                            AS OwnerName,
       ftg.rolename                                             AS RoleName,
       ftg.TargetUserName                                       AS TargetUserName,
       ftg.TargetLoginName                                      AS TargetLoginName,
       ftg.LinkedServerName                                     AS LinkedServerName
INTO   #temptrace1
FROM   ::fn_trace_gettable(@value, DEFAULT) AS ftg
       INNER JOIN sys.trace_events AS te
               ON ftg.EventClass = te.trace_event_id
       LEFT JOIN sys.trace_subclass_values AS tsv
              ON te.trace_event_id = tsv.trace_event_id
       INNER JOIN sys.trace_columns AS tc
               ON tsv.trace_column_id = tc.trace_column_id
       INNER JOIN sys.trace_categories tcg
               ON te.category_id = tcg.category_id
       INNER JOIN master.dbo.spt_values sv
               ON ftg.objecttype = sv.number
WHERE  tc.[name] = 'EventSubClass'
       AND ftg.eventclass IN ( 46, 47, 164, 102,103, 104, 105, 106,108, 109, 110, 111 )
       /* EventClass Types : 46-Object:Created \ 47-Object:Deleted \ 164-Object:Altered \ 102 - Audit Database Scope GDR Event \103- Audit Schema Object GDR Event 
	   \104- Audit Addlogin Event \105-Audit Login GDR Event \ 106 - Audit Login Change Property Event \108 - Audit Add Login to Server Role Event \ 109 - Audit Add DB User Event 
	   \ 110 - Audit Add Member to DB Role Event \111 - Audit Add Role Event */
       AND tsv.subclass_name <> 'Rollback' -- Exclued roolback Transactions
       AND tsv.subclass_value <> 0 -- exclude Begin transaction
       AND ftg.eventsubclass <> 0 -- exclude Begin transaction
       AND applicationname <> 'SQLServerCEIP' -- Exclude Telemetry Service
       AND Isnull(objecttype, 1) <> '21587' --Exclude Statistics
       AND sv.type = N'EOD'
       -- more filter types see
--https://sqlquantumleap.com/reference/server-audit-filter-values-for-class_type/
       AND ftg.databasename <> 'tempdb'
ORDER  BY ftg.StartTime

-- Gather information From Autoextends
SELECT ftg.SPID                                      AS Spid,
       ftg.StartTime                                 AS StartTime,
       ftg.DatabaseName                              AS DatabaseName,
       Filename COLLATE latin1_general_ci_as         AS Filename,
       CONVERT(DECIMAL(10, 2), duration / 1000000e0) AS TimeTakenSeconds,
       ( integerdata * 8.0 / 1024 )                  AS ChangeSizeMB,
       te.[name]                                     AS EventClass,
       tcg.[name]                                    AS Category,
       'EXTEND\SHRINK' COLLATE latin1_general_ci_as  AS ObjectType,
       ftg.ObjectName                                AS ObjectName,
       '1 - Commit' COLLATE latin1_general_ci_as     AS EventSubClass,
       ftg.TextData                                  AS TextData,
       ftg.HostName                                  AS HostName,
       ftg.ApplicationName                           AS ApplicationName,
       ftg.LoginName                                 AS LoginName,
       ftg.ServerName                                AS ServerName,
       ftg.OwnerName                                 AS OwnerName,
       ftg.RoleName                                  AS RoleName,
       ftg.TargetUserName                            AS TargetUserName,
       ftg.TargetLoginName                           AS TargetLoginName,
       ftg.LinkedServerName                          AS LinkedServerName
INTO   #temptrace2
FROM   ::fn_trace_gettable(@value, DEFAULT) ftg
       INNER JOIN sys.trace_events AS te
               ON ftg.EventClass = te.trace_event_id
       LEFT JOIN sys.trace_subclass_values AS tsv
              ON te.trace_event_id = tsv.trace_event_id
       INNER JOIN sys.trace_categories tcg
               ON te.category_id = tcg.category_id
WHERE  ftg.eventclass IN ( 116 )
       AND textdata LIKE 'DBCC%SHRINK%'
        OR ( te.trace_event_id >= 92
             AND te.trace_event_id <= 95 )
/* 92 – Data File Auto Grow \ 93 – Log File Auto Grow \ 94 – Data File Auto Shrink \95 – Log File Auto Shrink */
ORDER  BY ftg.StartTime;

SELECT
Spid,
StartTime,
DatabaseName,
Filename,
TimeTakenSeconds,
ChangeSizeMB,
EventClass,
Category,
ObjectType,
ObjectName,
EventSubClass,
TextData,
HostName,
ApplicationName,
LoginName,
ServerName,
OwnerName,
RoleName,
TargetUserName,
TargetLoginName,
LinkedServerName
INTO   #temptracefinal
FROM   #temptrace1
WHERE  COALESCE(ObjectName, '') NOT LIKE 'GSD331%'
UNION ALL
SELECT Spid,
       StartTime,
       DatabaseName,
       Filename COLLATE latin1_general_ci_as,
       TimeTakenSeconds,
	   ChangeSizeMB,
       EventClass,
       Category,
       ObjectType COLLATE latin1_general_ci_as,
       ObjectName,
       EventSubClass COLLATE latin1_general_ci_as,
       TextData,
       HostName,
       ApplicationName,
       LoginName,
       ServerName,
       OwnerName,
       RoleName,
       TargetUserName,
       TargetLoginName,
       LinkedServerName
FROM   #temptrace2
ORDER  BY StartTime


IF @permanent=0
BEGIN
Print  'Display Only Rows'
SELECT * FROM   #temptracefinal
where #temptracefinal.StartTime > DateAdd(hour, -@hours, GETDATE()) order by StartTime asc
END;
ELSE
BEGIN
--Print  'Creating Table'
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
				+ N'(ID bigint NOT NULL IDENTITY(1,1),
					[Spid] [int] NOT NULL,
					[StartTime] [datetime] NOT NULL,
					[DatabaseName] [nvarchar](256) NOT NULL,
					[Filename] [nvarchar](256) NULL,
					[TimetakenSeconds] [decimal](10, 2) NULL,
					[ChangeSizeMB] [decimal](18, 6) NULL,
					[EventClass] [nvarchar](128) NOT NULL,
					[Category] [nvarchar](128) NOT NULL,
					[ObjectType] [nvarchar](35) NOT NULL,
					[ObjectName] [nvarchar](256) NULL,
					[EventSubClass] [nvarchar](141) NOT NULL,
					[Textdata] [nvarchar](max) NULL,
					[HostName] [nvarchar](256) NULL,
					[ApplicationName] [nvarchar](256) NULL,
					[LoginName] [nvarchar](256) NULL,
					[ServerName] [nvarchar](256) NULL,
					[OwnerName] [nvarchar](256) NULL,
					[RoleName] [nvarchar](256) NULL,
					[TargetUsername] [nvarchar](256) NULL,
					[TargetLoginName] [nvarchar](256) NULL,
					[LinkedServerName] [nvarchar](256) NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY CLUSTERED(ID ASC));';

					EXEC(@StringToExecute);
Print  'Insert Rows in table'

DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = '
	SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table + ' OFF' + ';' + +
CHAR(13) +
	'INSERT INTO ' + @database +  '.' + @schema +  '.'+ @table +
'([Spid],[StartTime],[DatabaseName],[Filename],[TimetakenSeconds],[ChangeSizeMB],[EventClass],[Category],[ObjectType],[ObjectName],[EventSubClass],[Textdata],[HostName],[ApplicationName],[LoginName],[ServerName],[OwnerName],[RoleName],[TargetUsername],[TargetLoginName],[LinkedServerName]
) ' +
	'SELECT
Spid,StartTime,DatabaseName,Filename,TimeTakenSeconds,ChangeSizeMB,EventClass,Category,ObjectType,ObjectName,EventSubClass,TextData,HostName,ApplicationName,LoginName,ServerName,OwnerName,RoleName,TargetUserName,TargetLoginName,LinkedServerName
FROM #temptracefinal where #temptracefinal.StartTime > DateAdd(hour, -' + CAST(@hours AS NVARCHAR) + ','
+'GETDATE()) order by StartTime asc' + ';' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert
	--Print @sqlinsert
	/* Purging Data*/
IF @purge=1
BEGIN
	PRINT 'Purge Data from the values in the SP';
	--select * from @schema.@table where [StartTime] <=getdate()-10
	DECLARE @msg2 VARCHAR(8000);
	SET @msg2 = 'DELETE FROM ['+ @database+ '].['+@schema+'].['+@table+'] where [StartTime] <=getdate()-'+@defaultpurge+''
	EXEC (@msg2)
END
ELSE
BEGIN
Print 'I will do no purging in the table'
END

END

DROP TABLE #temptrace1

DROP TABLE #temptrace2

DROP TABLE #temptracefinal

END

GO


