USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'space' ) 
    EXEC('CREATE SCHEMA [space] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'usp_DBAConsol_Get_DbStats')
	EXEC ('CREATE PROC [space].[usp_DBAConsol_Get_DbStats] AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [space].[usp_DBAConsol_Get_DbStats] 
@permanent BIT =0, @purge INT=1,@defaultpurge VARCHAR(5)=600,
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='space',@table VARCHAR(100)='tbl_DBAConsol_DbStats'
AS
--
--  usp_DBAConsol_Get_DbStats.sql - Stats de DB
--
--  Luis Coelho (13/06/2019) -- removed databases in alwayson
--  Luis Coelho (23/09/2022) Dynamic create table and add Parameters to SP
--
SET NOCOUNT ON
DECLARE @msg VARCHAR(8000);


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
		SELECT @msg = 'Sorry but Database ' + @database+ ' does not exists or Database ' +@database+ ' is in the state <> Online'
		PRINT @msg;
		RETURN;
	END;

	/* Check if output table is equals to the name of the stored procedure*/
	IF @table='usp_DBAConsol_Get_DbStats'
	BEGIN
		SELECT @msg = 'Sorry, but the name of the table destination cannot be equal to the name of the Stored Procedure.' + REPLICATE(CHAR(13),7933);
		PRINT @msg;
		RETURN;
	END;

DECLARE @cmd NVARCHAR(1024)
-- IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE name LIKE '#tmplg%')
-- DROP TABLE #tmplg
CREATE TABLE #tmplg
(DBName VARCHAR(100),
LogSize REAL,
LogSpaceUsed REAL,
Status int)
SELECT @cmd = 'DBCC SQLPERF (logspace)'
INSERT INTO #tmplg EXECUTE (@cmd)

-- IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE name LIKE '#tmp_stats%')
-- DROP TABLE #tmp_stats
CREATE TABLE #tmp_stats (TotalExtents BIGINT, 
UsedExtents BIGINT,
DBName VARCHAR(100),
LogSize REAL,
LogSpaceUsed REAL)



--- Find databases in Always ON
DECLARE @cmdalwayson NVARCHAR(1024)
CREATE TABLE #tmp_alwayson (DBName VARCHAR(100),dbrole int) 

DECLARE @sqlversion int;
	-- Checking SQL Server Version
    SELECT @sqlversion = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);

IF @sqlversion >=12
BEGIN
SET @cmdalwayson = 'INSERT INTO #tmp_alwayson (DBName,dbrole)
SELECT d.name, isnull(ARS.role,1) hadr_role 
	FROM sys.databases d LEFT JOIN (
		 sys.dm_hadr_database_replica_states DRS INNER JOIN sys.dm_hadr_availability_replica_states ARS 
		 ON DRS.group_id = ARS.group_id AND DRS.replica_id = ARS.replica_id and ARS.is_local=1)
	ON d.database_id = DRS.database_id where ARS.role =2'
EXEC sp_executesql @cmdalwayson
END


DECLARE AllDatabases CURSOR FAST_FORWARD FOR SELECT name FROM master.dbo.sysdatabases WHERE DATABASEPROPERTYEX(name,'status') = 'ONLINE'
and name not in (select DBName from #tmp_alwayson )
OPEN AllDatabases
DECLARE @DB NVARCHAR(128)
FETCH NEXT FROM AllDatabases INTO @DB
WHILE (@@FETCH_STATUS = 0)
BEGIN
	--    IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE name LIKE '#tmp_sfs%')
	--    DROP TABLE #tmp_sfs
	

	CREATE TABLE #tmp_sfs (
	Fileid int,
	[FileGroup] int, 
	TotalExtents bigint,
	UsedExtents bigint,
	[Name] VARCHAR(1024),
	[Filename] VARCHAR(1024))
	SET @cmd = 'USE [' + @DB + '] DBCC SHOWFILESTATS'
	INSERT INTO #tmp_sfs EXECUTE (@cmd)
	DECLARE @logsize NVARCHAR(12)
	DECLARE @logspaceused NVARCHAR(12) 
	SELECT @logsize = LogSize FROM #tmplg WHERE DBName = @DB
	SELECT @logspaceused = (LogSize * LogSpaceUsed)/100.0 FROM #tmplg WHERE DBName = @DB
	SET @cmd = 'INSERT INTO #tmp_stats (TotalExtents,UsedExtents,DBName,LogSize,LogSpaceUsed)
SELECT SUM(TotalExtents), SUM(UsedExtents), ' + CHAR(39) + @DB + CHAR(39) + ', CAST(' + @logsize + ' AS VARCHAR), CAST(' + @logspaceused + ' AS VARCHAR) FROM #tmp_sfs'
	EXEC sp_executesql @cmd
	DROP TABLE #tmp_sfs
	FETCH NEXT FROM AllDatabases INTO @DB
END
CLOSE AllDatabases
DEALLOCATE AllDatabases

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
				+ N'(ID INT NOT NULL IDENTITY(1,1),
					[RECORD_TYPE] [int] NOT NULL,
					[DBNAME] [CHAR](150) NOT NULL,
					[DATA_SIZE] [decimal] (20,2) NULL,
					[DATA_USED] [decimal] (20,2) NULL,
					[LOG_SIZE] [decimal] (20,2) NULL,
					[LOG_USED] [decimal] (20,2) NULL,
					[STAT_DATE] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY CLUSTERED(ID ASC));';
					EXEC(@StringToExecute);
	Print  'Insert Rows in table'
	DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = 'SET IDENTITY_INSERT  ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) + ' OFF' + ';' + CHAR(13) +
	'INSERT INTO ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) + CHAR(13) +
	'SELECT 1,DBName, TotalExtents * 64/1024 , UsedExtents * 64/1024 , LogSize, LogSpaceUsed, getdate() FROM #tmp_stats' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert
END
ELSE
BEGIN
SELECT DBName, TotalExtents * 64/1024 as Data_Size , UsedExtents * 64/1024 as Data_Used, LogSize, LogSpaceUsed FROM #tmp_stats
END

IF @purge=1 
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
		DECLARE @msg2 VARCHAR(8000);
		SELECT @msg2 = 'Sorry but Database ' + @database+ ' does not exists or Database ' +@database+ ' is in the state <> Online, so i will Not Purge Data'
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
				+ 'DELETE FROM ['+ @database+'].['+@schema+'].['+@table+'] WHERE [STAT_DATE] <=GETDATE()-'+@defaultpurge+ ''
				+ CHAR(13)
				EXEC(@StringToExecute1);
		        --PRINT(@StringToExecute1);
	END
	ELSE
	BEGIN
	Print 'I will do no purging in the table'
	END

DROP TABLE #tmplg
DROP TABLE #tmp_stats
DROP TABLE #tmp_alwayson



GO
