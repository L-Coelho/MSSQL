USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'space' ) 
    EXEC('CREATE SCHEMA [space] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'TableDetails')
	EXEC ('CREATE PROC [space].[TableDetails] AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <19/04/2022>
-- Description:	<Get Info space from tables>
-- Version 0.1 - Initial Version
-- =============================================

/*
 ____    __    ____  __    ____  ____   ____  ____    __    ____  __    ___
(_  _)  /__\  (  - \(  )  ( ___)(  _ \ ( ___)(_  _)  /__\  (_  _)(  )  / __)
  )(   /(  )\  ) _ < )(__  )__)  )(_) ) )__)   )(   /(  )\  _)(_  )(__ \__ \
 (__) (__)(__)(____/(____)(____)(____/ (____) (__) (__)(__)(____)(____)(___/

*/
alter PROCEDURE [space].[TableDetails]
-- Parameters for the stored procedure --
	@permanent BIT =0, @purge INT=1,@defaultpurge VARCHAR(5)=600,
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='space',@table
VARCHAR(100)='TableSpace', @dbname VARCHAR(200) = NULL, @diary BIT =0, @Weekday INT = 1

/*
Day of the week is:
1-Sunday,2-Monday,3-Tuesday,4-Wednesday,5-Thursday,6-Friday,7-Saturday, NULL to invalidate
Capture
*/
AS
BEGIN

   SET NOCOUNT ON;
   DECLARE @msg VARCHAR(8000);
   DECLARE @sqlversion int;
   DECLARE @SqlStatement varchar(8000)
   DECLARE @cmd varchar(8000)
   DECLARE @DB NVARCHAR(256)
   DECLARE @cmdalwayson NVARCHAR(1024)


   	IF(@Weekday NOT BETWEEN 1 AND 7 )
	BEGIN
			RAISERROR (N'The value for the parameter @Weekday is not supported, only valid days
from 1 to 7  ',16,1) WITH NOWAIT;
			RETURN;
	END

   ---- Checking SQL Server Version
   SELECT @sqlversion = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);

		/* Check SQL Server Version and abort in the case that the version is prior to SQL
Server 2005*/
	IF (
	SELECT
	  CASE
		 WHEN CONVERT(NVARCHAR(128), SERVERPROPERTY ('PRODUCTVERSION')) LIKE '8%' THEN 0
		 ELSE 1
	  END
	) = 0
	BEGIN

		SELECT @msg = 'Sorry, only works on versions of SQL prior to 2005.' +
REPLICATE(CHAR(13),7933);
		PRINT @msg;
		RETURN;
	END;

		/* Check if output database exists in the server and abort in the case that it doesn't
exists*/
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
		SELECT @msg = 'Sorry but Database ' + @database+ ' does not exists or Database '
+@database+ ' is in the state <> Online'
		PRINT @msg;
		RETURN;
	END;

	/* Check if output table is equals to the name of the stored procedure*/
	IF @table='TableDetails'
	BEGIN
		SELECT @msg = 'Sorry, but the name of the table destination cannot be equal to the name
of the Stored Procedure.' + REPLICATE(CHAR(13),7933);
		PRINT @msg;
		RETURN;
	END;


	DECLARE @DayWeek INT;
	SELECT @DayWeek= DATEPART(WEEKDAY, GETDATE())


	IF  @Weekday<>@DayWeek AND @diary=0 AND @permanent=1--and @Weekday is NULL
	BEGIN
	SELECT @msg = 'Sorry, but is not the day to capture the information.' +
REPLICATE(CHAR(13),7933);
	PRINT @msg;
	RETURN;
	END


CREATE TABLE #TmpDB(
	[RowId] [int] ,
	[Databasename] [varchar](250),
	[SchemaName] [varchar](250) ,
	[TableName] [varchar](250) ,
	[RowCount] [int] ,
	[TotalSpaceMB] [decimal](20, 3) ,
	[DataUsedMB] [decimal](20, 3) ,
	[IndexSizeMB] [decimal](20, 3) ,
	[UnusedSpaceMB] [decimal](20, 3) ,
	[SysDate] [datetime]  )

	CREATE TABLE #tmp_alwayson (dbname VARCHAR(800),IsPrimaryServer int,ReplicaServerName
VARCHAR(200),ReadableSecondary VARCHAR(100))


-- Engine Version minor than SQL 2012
IF @sqlversion <12
BEGIN
DECLARE Databasesminor2012 CURSOR FAST_FORWARD FOR SELECT name FROM
master.dbo.sysdatabases WHERE DATABASEPROPERTYEX(name,'status') = 'ONLINE' AND dbid > 4
OPEN Databasesminor2012

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM Databasesminor2012 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	  SELECT
	(row_number() over(order by a3.name, a2.name))%2 as l1,
	Db_name() AS Databasename,
	a3.name AS [SchemaName],
	a2.name AS [TableName],
	a1.rows as Row_Count,
	(a1.reserved + ISNULL(a4.reserved,0))* 8/1024.0 AS TotalSpaceMB,
	a1.data * 8/1024.0 AS DataUsedMB,
	(CASE WHEN (a1.used + ISNULL(a4.used,0)) > a1.data THEN (a1.used + ISNULL(a4.used,0)) -
a1.data ELSE 0 END) * 8/1024.0 AS Index_SizeMB,
	(CASE WHEN (a1.reserved + ISNULL(a4.reserved,0)) > a1.used THEN (a1.reserved +
ISNULL(a4.reserved,0)) - a1.used ELSE 0 END) * 8/1024.0 AS UnusedSpaceMB,
	CAST(FLOOR(CAST(GETDATE() AS float)) AS datetime) AS SysDate
FROM
	(SELECT
		ps.object_id,
		SUM (
			CASE
				WHEN (ps.index_id < 2) THEN row_count
				ELSE 0
			END
			) AS [rows],
		SUM (ps.reserved_page_count) AS reserved,
		SUM (
			CASE
				WHEN (ps.index_id < 2) THEN (ps.in_row_data_page_count + ps.lob_used_page_count +
ps.row_overflow_used_page_count)
				ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count)
			END
			) AS data,
		SUM (ps.used_page_count) AS used
	FROM sys.dm_db_partition_stats ps
      	GROUP BY ps.object_id) AS a1
LEFT OUTER JOIN
	(SELECT
		it.parent_id,
		SUM(ps.reserved_page_count) AS reserved,
		SUM(ps.used_page_count) AS used
	 FROM sys.dm_db_partition_stats ps
	 INNER JOIN sys.internal_tables it ON (it.object_id = ps.object_id)
	 WHERE it.internal_type IN (202,204)
	 GROUP BY it.parent_id) AS a4 ON (a4.parent_id = a1.object_id)
INNER JOIN sys.all_objects a2  ON ( a1.object_id = a2.object_id )
INNER JOIN sys.schemas a3 ON (a2.schema_id = a3.schema_id)
WHERE a2.type <> N''S'' and a2.type <> N''IT''
ORDER BY a2.name, a3.name '

	EXECUTE(@SqlStatement);
END
CLOSE Databasesminor2012
DEALLOCATE Databasesminor2012

END
ELSE
-- Engine Version equals to SQL 2012
IF @sqlversion =12
BEGIN
--- Databases in Always ON

SET @cmdalwayson = 'INSERT INTO #tmp_alwayson
(dbname,IsPrimaryServer,ReplicaServerName,ReadableSecondary)
SELECT
dbc.database_name
,CASE WHEN  (States.primary_replica  = Replicas.replica_server_name) THEN  1
ELSE  '''' END AS IsPrimaryServer
,Replicas.replica_server_name as ReplicaServerName
,secondary_role_allow_connections_desc AS ReadableSecondary
from master.sys.availability_databases_cluster dbc
INNER JOIN master.sys.availability_groups Groups on dbc.group_id=Groups.group_id
inner  JOIN master.sys.availability_replicas Replicas ON Groups.group_id =
Replicas.group_id
INNER JOIN master.sys.dm_hadr_availability_group_states States ON Groups.group_id =
States.group_id'
EXEC sp_executesql @cmdalwayson

DECLARE Databases2012 CURSOR FAST_FORWARD FOR SELECT name from master.sys.databases where
state_desc='ONLINE' AND database_id > 4 AND name not in (select dbname from #tmp_alwayson
where IsPrimaryServer=0 and ReadableSecondary='NO' and ReplicaServerName=@@SERVERNAME)
OPEN Databases2012

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM Databases2012 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	 SELECT
	(row_number() over(order by a3.name, a2.name))%2 as l1,
	Db_name() AS Databasename,
	a3.name AS [SchemaName],
	a2.name AS [TableName],
	a1.rows as Row_Count,
	(a1.reserved + ISNULL(a4.reserved,0))* 8/1024.0 AS TotalSpaceMB,
	a1.data * 8/1024.0 AS DataUsedMB,
	(CASE WHEN (a1.used + ISNULL(a4.used,0)) > a1.data THEN (a1.used + ISNULL(a4.used,0)) -
a1.data ELSE 0 END) * 8/1024.0 AS Index_SizeMB,
	(CASE WHEN (a1.reserved + ISNULL(a4.reserved,0)) > a1.used THEN (a1.reserved +
ISNULL(a4.reserved,0)) - a1.used ELSE 0 END) * 8/1024.0 AS UnusedSpaceMB,
	CAST(FLOOR(CAST(GETDATE() AS float)) AS datetime) AS SysDate
FROM
	(SELECT
		ps.object_id,
		SUM (
			CASE
				WHEN (ps.index_id < 2) THEN row_count
				ELSE 0
			END
			) AS [rows],
		SUM (ps.reserved_page_count) AS reserved,
		SUM (
			CASE
				WHEN (ps.index_id < 2) THEN (ps.in_row_data_page_count + ps.lob_used_page_count +
ps.row_overflow_used_page_count)
				ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count)
			END
			) AS data,
		SUM (ps.used_page_count) AS used
	FROM sys.dm_db_partition_stats ps
       	GROUP BY ps.object_id) AS a1
LEFT OUTER JOIN
	(SELECT
		it.parent_id,
		SUM(ps.reserved_page_count) AS reserved,
		SUM(ps.used_page_count) AS used
	 FROM sys.dm_db_partition_stats ps
	 INNER JOIN sys.internal_tables it ON (it.object_id = ps.object_id)
	 WHERE it.internal_type IN (202,204)
	 GROUP BY it.parent_id) AS a4 ON (a4.parent_id = a1.object_id)
INNER JOIN sys.all_objects a2  ON ( a1.object_id = a2.object_id )
INNER JOIN sys.schemas a3 ON (a2.schema_id = a3.schema_id)
WHERE a2.type <> N''S'' and a2.type <> N''IT''
ORDER BY a2.name, a3.name'

	EXECUTE(@SqlStatement);
END
CLOSE Databases2012
DEALLOCATE Databases2012
END

IF @sqlversion >12
-- Databases Equals or Bigger than 2012
BEGIN
--- Databases in Always ON

SET @cmdalwayson = 'INSERT INTO #tmp_alwayson
(dbname,IsPrimaryServer,ReplicaServerName,ReadableSecondary)
SELECT
dbc.database_name
,CASE WHEN  (States.primary_replica  = Replicas.replica_server_name) THEN  1
ELSE  '''' END AS IsPrimaryServer
,Replicas.replica_server_name as ReplicaServerName
,secondary_role_allow_connections_desc AS ReadableSecondary
from master.sys.availability_databases_cluster dbc
INNER JOIN master.sys.availability_groups Groups on dbc.group_id=Groups.group_id
inner  JOIN master.sys.availability_replicas Replicas ON Groups.group_id =
Replicas.group_id
INNER JOIN master.sys.dm_hadr_availability_group_states States ON Groups.group_id =
States.group_id'
EXEC sp_executesql @cmdalwayson

DECLARE Databasessup2012 CURSOR FAST_FORWARD FOR SELECT name from master.sys.databases
where state_desc='ONLINE' AND database_id > 4 AND name NOT IN (select dbname from
#tmp_alwayson where IsPrimaryServer=0 and ReadableSecondary='NO' and
ReplicaServerName=@@SERVERNAME)
OPEN Databasessup2012

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM Databasessup2012 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	   SELECT
	(row_number() over(order by a3.name, a2.name))%2 as l1,
	Db_name() AS Databasename,
	a3.name AS [SchemaName],
	a2.name AS [TableName],
	a1.rows as Row_Count,
	(a1.reserved + ISNULL(a4.reserved,0))* 8/1024.0 AS TotalSpaceMB,
	a1.data * 8/1024.0 AS DataUsedMB,
	(CASE WHEN (a1.used + ISNULL(a4.used,0)) > a1.data THEN (a1.used + ISNULL(a4.used,0)) -
a1.data ELSE 0 END) * 8/1024.0 AS Index_SizeMB,
	(CASE WHEN (a1.reserved + ISNULL(a4.reserved,0)) > a1.used THEN (a1.reserved +
ISNULL(a4.reserved,0)) - a1.used ELSE 0 END) * 8/1024.0 AS UnusedSpaceMB,
	CAST(FLOOR(CAST(GETDATE() AS float)) AS datetime) AS SysDate
FROM
	(SELECT
		ps.object_id,
		SUM (
			CASE
				WHEN (ps.index_id < 2) THEN row_count
				ELSE 0
			END
			) AS [rows],
		SUM (ps.reserved_page_count) AS reserved,
		SUM (
			CASE
				WHEN (ps.index_id < 2) THEN (ps.in_row_data_page_count + ps.lob_used_page_count +
ps.row_overflow_used_page_count)
				ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count)
			END
			) AS data,
		SUM (ps.used_page_count) AS used
	FROM sys.dm_db_partition_stats ps
        WHERE ps.object_id NOT IN (SELECT object_id FROM sys.tables WHERE
is_memory_optimized = 1)
	GROUP BY ps.object_id) AS a1
LEFT OUTER JOIN
	(SELECT
		it.parent_id,
		SUM(ps.reserved_page_count) AS reserved,
		SUM(ps.used_page_count) AS used
	 FROM sys.dm_db_partition_stats ps
	 INNER JOIN sys.internal_tables it ON (it.object_id = ps.object_id)
	 WHERE it.internal_type IN (202,204)
	 GROUP BY it.parent_id) AS a4 ON (a4.parent_id = a1.object_id)
INNER JOIN sys.all_objects a2  ON ( a1.object_id = a2.object_id )
INNER JOIN sys.schemas a3 ON (a2.schema_id = a3.schema_id)
WHERE a2.type <> N''S'' and a2.type <> N''IT''
ORDER BY a2.name, a3.name'

	EXECUTE(@SqlStatement);

END
CLOSE Databasessup2012
DEALLOCATE Databasessup2012


END

END

IF  @dbname is not NULL
 BEGIN
 SELECT
[Databasename],[SchemaName],[TableName],[RowCount],[TotalSpaceMB],[DataUsedMB],[IndexSizeMB],[UnusedSpaceMB],[SysDate]
FROM #TmpDB where Databasename= @dbname order by [SchemaName],[TableName];
 END
ELSE
 IF @permanent=0
 BEGIN
SELECT
[Databasename],[SchemaName],[TableName],[RowCount],[TotalSpaceMB],[DataUsedMB],[IndexSizeMB],[UnusedSpaceMB],[SysDate]
FROM #TmpDB order by [Databasename],[SchemaName],[TableName];
END
ELSE
BEGIN
IF  @permanent=1 and @dbname IS NULL and @diary =1 OR @Weekday=@DayWeek
BEGIN
/* Check if output database exists in the server and abort in the case that it doesn't
exists*/
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
		SELECT @msg = 'Sorry but Database ' + @database+ ' does not exists or Database '
+@database+ ' is in the state <> Online'
		PRINT @msg;
		RETURN;
	END;
	/* Check if the schema an table exists and create it if doesn't exists*/
	DECLARE @StringToExecute VARCHAR(8000)
	SET @StringToExecute = 'USE '
				+ QUOTENAME(@database) + ';' + CHAR(13)
				+'IF  NOT EXISTS(SELECT * FROM '
				+ @database
				+ '.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '''
				+ @schema
				+ ''') ' + CHAR(13)
				+ 'EXEC sp_executesql N''CREATE SCHEMA ' + QUOTENAME(@schema) + ''''
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
				+ QUOTENAME(@schema) + '.'
				+ QUOTENAME(@table)
				+ N'(ID bigint NOT NULL IDENTITY(1,1),
					[Databasename] [varchar](250),
					[SchemaName] [varchar] (250) NOT NULL,
					[TableName] [varchar](250) NOT NULL,
					[RowCount] [int] NOT NULL,
					[TotalSpaceMB] [decimal](20, 3) NOT NULL,
					[DataUsedMB] [decimal](20, 3) NOT NULL,
					[IndexSizeMB] [decimal](20, 3) NOT NULL,
					[UnusedSpaceMB] [decimal](20, 3) NOT NULL,
					[SysDate] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY
CLUSTERED(ID ASC));';
					EXEC(@StringToExecute);

	Print  'Insert Rows in table'
	DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = 'SET IDENTITY_INSERT  ' + QUOTENAME(@database) +  '.' +
QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) + ' OFF' + ';' + CHAR(13) +
	'INSERT INTO ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+
QUOTENAME(@table) + CHAR(13) +
	'SELECT
[Databasename],[SchemaName],[TableName],[RowCount],[TotalSpaceMB],[DataUsedMB],[IndexSizeMB],[UnusedSpaceMB],[SysDate]
FROM #TmpDB' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+
QUOTENAME(@table) +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert
END

END

 	IF @purge=1
	BEGIN
	/* Check if output database exists in the server and abort in the case that it doesn't
exists*/
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
		DECLARE @msg2 VARCHAR(8000);
		SELECT @msg2 = 'Sorry but Database ' + @database+ ' does not exists or Database '
+@database+ ' is in the state <> Online, so i will Not Purge Data'
		PRINT @msg2;
		RETURN;
	END;
		PRINT 'Purge Data from the values in the SP';
	    DECLARE @StringToExecute1 VARCHAR(8000)
		SET @StringToExecute1 = 'USE '
				+ @database + ';' + CHAR(13)
				+'IF  EXISTS(SELECT OBJECT_ID FROM '
				+ 'sys.tables WHERE NAME =''' +@table + ''''
				+ ' AND SCHEMA_NAME(schema_id) ='''+@schema +''
				+''')'
				+ CHAR(13)
				+ 'DELETE FROM ['+ @database+'].['+@schema+'].['+@table+'] WHERE [SysDate]
<=GETDATE()-'+@defaultpurge+ ''
				+ CHAR(13)
				EXEC(@StringToExecute1);
		        --PRINT(@StringToExecute1);
	END
	ELSE
	BEGIN
	Print 'I will do no purging in the table'
	END


IF OBJECT_ID('tempdb..#TmpDB') IS NOT NULL DROP TABLE #TmpDB
IF OBJECT_ID('tempdb..#tmp_alwayson') IS NOT NULL DROP TABLE #tmp_alwayson


GO