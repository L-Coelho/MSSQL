USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'audit' ) 
    EXEC('CREATE SCHEMA [audit] AUTHORIZATION [dbo]');
GO

/****** Object:  StoredProcedure [audit].[usp_gather_default_trace]   ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <06/10/2020>
-- Description:	<Gather Information about Database Extends and objects and users from default trace>
-- V.01 <08/01/2021>
-- Usage Examples:
-- Display the records from the Audit Trace on the last 30 days
-- exec [audit].[usp_gather_default_trace] @hours=720 < Note: Need to convert previously hours in days, in this example is 30 days >
-- Create a table if not exists and dumps the output of the default trace on it
-- exec [audit].[usp_gather_default_trace] @permanent=1 < Note: will retain the value in Variable @hours >
-- Define the Retention off data in table
-- exec [audit].[usp_gather_default_trace] @defaultpurge VARCHAR(5)=30 < Note: will purge data below the value in Variable @defaultpurge >
-- =============================================
CREATE PROCEDURE [audit].[usp_gather_default_trace]
	-- Parameters for the stored procedure --
	@permanent BIT =0, @hours INT=24,@purge INT=1,@defaultpurge VARCHAR(5)=275,
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

/* Purging Data*/

IF @purge=1
BEGIN
--Print 'I will Purge Data'
Print 'Ckeck if Control Table Purge Exists'
IF EXISTS (SELECT name FROM sys.objects WHERE name ='PurgeData' AND schema_id=1 AND type='U')
	BEGIN
	PRINT 'Purge Table Exists'
	DECLARE @retain int
	SELECT @retain=[RetainDays] from [dbo].[PurgeData] (nolock) where [SchemaName] = 'audit' and [TableName] ='default_trace' and isActive=1
	--print @retain
	PRINT 'Purging Data'
	Delete from [audit].[default_trace] where [StartTime] <=getdate()-@retain
	END
ELSE 
	PRINT 'The control table does not exists , i will purge the values in the SP';
	--select * from @schema.@table where [StartTime] <=getdate()-10
	DECLARE @msg2 VARCHAR(8000);
	SET @msg2 = 'DELETE FROM ['+ @database+ '].['+@schema+'].['+@table+'] where [StartTime] <=getdate()-'+@defaultpurge+''
	--print @msg2
	EXEC (@msg2)
END
ELSE
BEGIN
Print 'I will do nothing'
END

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

SELECT ftg.spid                                                 AS SPID,
       ftg.starttime                                            AS StartTime,
       ftg.databasename                                         AS DatabaseName,
       Cast(NULL AS NVARCHAR(256)) COLLATE latin1_general_ci_as AS Filename,
       Cast(NULL AS DECIMAL(10, 2))                             AS TimeTakenSeconds,
       Cast(NULL AS DECIMAL(18, 6))                             AS ChangeSizeMB,
       te.[name]                                                AS EventClass,
       tcg.[name]                                               AS Category,
       sv.[name] COLLATE latin1_general_ci_as                   AS ObjectType,
       ftg.objectname                                           AS ObjectName,
       CONVERT(VARCHAR(10), tsv.subclass_value)
       + ' - ' + tsv.subclass_name COLLATE latin1_general_ci_as AS EventSubClass,
       ftg.textdata                                             AS TextData,
       ftg.hostname                                             AS HostName,
       ftg.applicationname                                      AS ApplicationName,
       ftg.loginname                                            AS LoginName,
       ftg.servername                                           AS ServerName,
       ftg.ownername                                            AS OwnerName,
       ftg.rolename                                             AS RoleName,
       ftg.targetusername                                       AS TargetUserName,
       ftg.targetloginname                                      AS TargetLoginName,
       ftg.linkedservername                                     AS LinkedServerName
INTO   #temptrace1
FROM   ::fn_trace_gettable(@value, DEFAULT) AS ftg
       INNER JOIN sys.trace_events AS te
               ON ftg.eventclass = te.trace_event_id
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
ORDER  BY ftg.starttime

-- Gather information From Autoextends
SELECT ftg.spid                                      AS SPID,
       ftg.starttime                                 AS StartTime,
       ftg.databasename                              AS DatabaseName,
       filename COLLATE latin1_general_ci_as         AS Filename,
       CONVERT(DECIMAL(10, 2), duration / 1000000e0) AS TimeTakenSeconds,
       ( integerdata * 8.0 / 1024 )                  AS ChangeSizeMB,
       te.[name]                                     AS EventClass,
       tcg.[name]                                    AS Category,
       'EXTEND\SHRINK' COLLATE latin1_general_ci_as  AS ObjectType,
       ftg.objectname                                AS ObjectName,
       '1 - Commit' COLLATE latin1_general_ci_as     AS EventSubClass,
       ftg.textdata                                  AS TextData,
       ftg.hostname                                  AS HostName,
       ftg.applicationname                           AS ApplicationName,
       ftg.loginname                                 AS LoginName,
       ftg.servername                                AS ServerName,
       ftg.ownername                                 AS OwnerName,
       ftg.rolename                                  AS RoleName,
       ftg.targetusername                            AS TargetUserName,
       ftg.targetloginname                           AS TargetLoginName,
       ftg.linkedservername                          AS LinkedServerName
INTO   #temptrace2
FROM   ::fn_trace_gettable(@value, DEFAULT) ftg
       INNER JOIN sys.trace_events AS te
               ON ftg.eventclass = te.trace_event_id
       LEFT JOIN sys.trace_subclass_values AS tsv
              ON te.trace_event_id = tsv.trace_event_id
       INNER JOIN sys.trace_categories tcg
               ON te.category_id = tcg.category_id
WHERE  ftg.eventclass IN ( 116 )
       AND textdata LIKE 'DBCC%SHRINK%'
        OR ( te.trace_event_id >= 92
             AND te.trace_event_id <= 95 )
/* 92 – Data File Auto Grow \ 93 – Log File Auto Grow \ 94 – Data File Auto Shrink \95 – Log File Auto Shrink */
ORDER  BY ftg.starttime;

SELECT
spid,
starttime,
databasename,
filename,
timetakenseconds,
changesizemb,
eventclass,
category,
objecttype,
objectname,
eventsubclass,
textdata,
hostname,
applicationname,
loginname,
servername,
ownername,
rolename,
targetusername,
targetloginname,
linkedservername
INTO   #temptracefinal
FROM   #temptrace1
WHERE  COALESCE(objectname, '') NOT LIKE 'GSD331%'
UNION ALL
SELECT spid,
       starttime,
       databasename,
       filename COLLATE latin1_general_ci_as,
       timetakenseconds,
       changesizemb,
       eventclass,
       category,
       objecttype COLLATE latin1_general_ci_as,
       objectname,
       eventsubclass COLLATE latin1_general_ci_as,
       textdata,
       hostname,
       applicationname,
       loginname,
       servername,
       ownername,
       rolename,
       targetusername,
       targetloginname,
       linkedservername
FROM   #temptrace2
ORDER  BY starttime


IF @permanent=0
BEGIN
Print  'Display Only Rows'
SELECT * FROM   #temptracefinal
where #temptracefinal.starttime > DateAdd(hour, -@hours, GETDATE()) order by starttime asc
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
spid,starttime,databasename,filename,timetakenseconds,changesizemb,eventclass,category,objecttype,objectname,eventsubclass,textdata,hostname,applicationname,loginname,servername,ownername,rolename,targetusername,targetloginname,linkedservername
FROM #temptracefinal where #temptracefinal.starttime > DateAdd(hour, -' + CAST(@hours AS NVARCHAR) + ','
+'GETDATE()) order by starttime asc' + ';' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert
	--Print @sqlinsert
END

DROP TABLE #temptrace1

DROP TABLE #temptrace2

DROP TABLE #temptracefinal

END

GO


