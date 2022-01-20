USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'space' ) 
    EXEC('CREATE SCHEMA [space] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'DBdetails')
	EXEC ('CREATE PROC [space].[DBdetails] AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <05/02/2020>
-- Description:	<Get Info from databases>
-- Version 0.1 - Initial Version
-- Alter Date :  <12/03/2020>
-- Version 0.2 - Exclude databases with AlwaysON
-- Alter Date :  <18/01/2022>
-- Version 0.3 - Dynamic create table and add Parameters to SP 
-- =============================================

/*
 ______  ______  ______  _______ _______ _______ _____        _______
 |     \ |_____] |     \ |______    |    |_____|   |   |      |______
 |_____/ |_____] |_____/ |______    |    |     | __|__ |_____ ______|
                                                                    
*/
ALTER PROCEDURE [space].[DBdetails]
-- Parameters for the stored procedure --
	@permanent BIT =0, @purge INT=1,@defaultpurge VARCHAR(5)=600,
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='space',@table VARCHAR(100)='DatabaseDetails', @dbname VARCHAR(200) = NULL

AS
BEGIN

	SET NOCOUNT ON;

	
CREATE TABLE #TmpDB(
	[DBId] [int] ,
	[Databasename] [varchar](250) ,
	[FileId] [int] ,
	[Type] [varchar](15) ,
	[FileGroup] [varchar](200) ,
	[Logical_name] [varchar](100) ,
	[Physical_name] [varchar](800) ,
	[sizeMB] [decimal](20, 2) ,
	[SpaceUsedMB] [decimal](20, 2) ,
	[AvailableSpaceMB] [decimal](20, 2) ,
	[Pct_Free] [decimal](10, 2) ,
	[IsAutoGrowth] [bit] ,
	[AutoGrow] [varchar](20) ,
	[Maxsize] [varchar](50) ,
	[SysDate] [datetime]  )
	
	DECLARE @sqlversion int;
	---- Checking SQL Server Version
   SELECT @sqlversion = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);
   DECLARE @SqlStatement varchar(8000)
   DECLARE @SqlStatement1 varchar(8000)
   DECLARE @SqlStatement2 varchar(8000)
   DECLARE @SqlStatement3 varchar(8000)
   DECLARE @cmd varchar(8000)
   DECLARE @DB NVARCHAR(256)

-- Databases SQL 2000
IF @sqlversion <=8
BEGIN	
DECLARE Databases_sql2000 CURSOR FAST_FORWARD FOR SELECT name FROM master.dbo.sysdatabases WHERE DATABASEPROPERTYEX(name,'status') = 'ONLINE'
OPEN Databases_sql2000

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM Databases_sql2000 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement2 = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	  SELECT Db_id() DBid,
       Db_name() DBname,
       fileid AS [FileId],
       CASE
       WHEN (64 & status) = 64 THEN ''Log'' ELSE ''ROWS'' END AS [Type] ,
       Filegroup_name(groupid) AS FileGroup,
       name AS [Logical name],
       filename [Physical_name],
       Cast(size / 128.0 AS DECIMAL(20,2)) AS [sizeMB],
       Cast(Fileproperty(name, ''SpaceUsed'') / 128.0 AS DECIMAL(20,2)) AS [SpaceUsedMB],
       Cast(size / 128.0 - (Fileproperty(name, ''SpaceUsed'') / 128.0) AS DECIMAL(20,2)) AS [AvailableSpaceMB],
       CONVERT(DECIMAL(20,2), (CONVERT(DECIMAL(20,2), Round((size - Fileproperty(name, ''SpaceUsed'')) / 128.000, 2)) / CONVERT (DECIMAL(20,2), Round(size / 128.000, 2)) * 100)) AS [Pct_Free],
       CASE WHEN growth = 0  OR maxsize NOT IN (-1,268435456) THEN 0 ELSE 1 END AS [IsAutoGrowth],
       CASE status & 0x100000 WHEN 0x100000 THEN ''By '' + Cast(growth AS VARCHAR) + '' Percent '' ELSE Ltrim(Str(growth/128, 12, 1)) + '' MB '' END [Autogrow],
       CASE  WHEN maxsize = -1 THEN ''Unlimited'' ELSE ''Limited to '' + Ltrim(Str(maxsize/128, 10, 1)) + '' MB'' END AS [Maxsize],
       Getdate() AS SysDate
FROM dbo.sysfiles (NOLOCK) '
	
	EXECUTE(@SqlStatement2);
END
CLOSE Databases_sql2000
DEALLOCATE Databases_sql2000

END
ELSE   
-- Databases SQL 2005 to 2008R2 
IF @sqlversion >=9 and @sqlversion <=10
BEGIN
--
-- Databases with recovery_model bigger than 80

DECLARE dbmodelsup80 CURSOR FAST_FORWARD FOR SELECT name from master.sys.databases where state_desc='ONLINE' and compatibility_level>80 
OPEN dbmodelsup80

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM dbmodelsup80 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	  SELECT db_id() AS DBId,
       db_name() AS Databasename,
       file_id AS [FileId],
       df.type_desc AS [Type],
       fg.name AS [FileGroup],
       df.name AS [Logical_name],
       df.physical_name AS [Physical_name],
       CAST(df.size/128.0 AS DECIMAL(20,2)) AS [sizeMB],
       CAST(FILEPROPERTY(df.name, ''SpaceUsed'')/128.0 AS DECIMAL(20,2)) AS [SpaceUsedMB],
       CAST(size/128.0-(FILEPROPERTY(df.name, ''SpaceUsed'')/128.0) AS DECIMAL(20,2)) AS [AvailableSpaceMB],
       convert(decimal(20,2),(convert(decimal(20,2), round((size-fileproperty(df.name, ''SpaceUsed''))/128.000, 2)) / convert(decimal(20,2), round(df.size/128.000, 2)) * 100)) AS [Pct_Free],
       CASE  WHEN growth=0 OR df.max_size NOT IN (-1,268435456) THEN 0 ELSE 1 END AS [IsAutoGrowth],
	   CASE WHEN is_percent_growth = 0 THEN LTRIM(STR(df.growth/128, 12, 1)) + '' MB '' ELSE ''By '' + CAST(df.growth AS VARCHAR) + '' percent '' END AS [AutoGrow],
	   CASE WHEN df.max_size = -1 THEN ''Unlimited''  ELSE ''Limited to '' + LTRIM(STR(df.max_size/128, 10, 1)) + '' MB'' END AS [Maxsize],
       getdate() AS SysDate
	   FROM sys.database_files AS df (NOLOCK)
	   LEFT JOIN sys.filegroups AS fg (NOLOCK) ON df.data_space_id = fg.data_space_id '
	
	EXECUTE(@SqlStatement);
END
CLOSE dbmodelsup80
DEALLOCATE dbmodelsup80

-- Databases with recovery_model minor than 80

DECLARE Databases_80 CURSOR FAST_FORWARD FOR SELECT name from master.sys.databases where state_desc='ONLINE' and compatibility_level<=80
OPEN Databases_80

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM Databases_80 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement1 = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	  SELECT Db_id() DBid,
       Db_name() DBname,
       fileid AS [FileId],
       CASE
       WHEN (64 & status) = 64 THEN ''Log'' ELSE ''ROWS'' END AS [Type] ,
       Filegroup_name(groupid) AS FileGroup,
       name AS [Logical name],
       filename [Physical_name],
       Cast(size / 128.0 AS DECIMAL(20,2)) AS [sizeMB],
       Cast(Fileproperty(name, ''SpaceUsed'') / 128.0 AS DECIMAL(20,2)) AS [SpaceUsedMB],
       Cast(size / 128.0 - (Fileproperty(name, ''SpaceUsed'') / 128.0) AS DECIMAL(20,2)) AS [AvailableSpaceMB],
       CONVERT(DECIMAL(20,2), (CONVERT(DECIMAL(20,2), Round((size - Fileproperty(name, ''SpaceUsed'')) / 128.000, 2)) / CONVERT (DECIMAL(20,2), Round(size / 128.000, 2)) * 100)) AS [Pct_Free],
       CASE WHEN growth = 0  OR maxsize NOT IN (-1,268435456) THEN 0 ELSE 1 END AS [IsAutoGrowth],
       CASE status & 0x100000 WHEN 0x100000 THEN ''By '' + Cast(growth AS VARCHAR) + '' Percent '' ELSE Ltrim(Str(growth/128, 12, 1)) + '' MB '' END [Autogrow],
       CASE  WHEN maxsize = -1 THEN ''Unlimited'' ELSE ''Limited to '' + Ltrim(Str(maxsize/128, 10, 1)) + '' MB'' END AS [Maxsize],
       Getdate() AS SysDate
FROM dbo.sysfiles (NOLOCK) '
	
	EXECUTE(@SqlStatement1);
END
CLOSE Databases_80
DEALLOCATE Databases_80
	
END
ELSE
-- Databases Equals or Bigger than 2012
BEGIN

--- Databases in Always ON
DECLARE @cmdalwayson NVARCHAR(1024)
CREATE TABLE #tmp_alwayson (dbname VARCHAR(800),IsPrimaryServer int,ReplicaServerName VARCHAR(200),ReadableSecondary VARCHAR(100)) 

SET @cmdalwayson = 'INSERT INTO #tmp_alwayson (dbname,IsPrimaryServer,ReplicaServerName,ReadableSecondary)
SELECT
dbc.database_name
,CASE WHEN  (States.primary_replica  = Replicas.replica_server_name) THEN  1
ELSE  '''' END AS IsPrimaryServer
,Replicas.replica_server_name as ReplicaServerName
,secondary_role_allow_connections_desc AS ReadableSecondary
from master.sys.availability_databases_cluster dbc 
INNER JOIN master.sys.availability_groups Groups on dbc.group_id=Groups.group_id
inner  JOIN master.sys.availability_replicas Replicas ON Groups.group_id = Replicas.group_id
INNER JOIN master.sys.dm_hadr_availability_group_states States ON Groups.group_id = States.group_id'
EXEC sp_executesql @cmdalwayson

--select dbname from #tmp_alwayson where IsPrimaryServer=0 and ReadableSecondary='NO' and ReplicaServerName=@@SERVERNAME
-- Databases with recovery_model bigger than 80

DECLARE dbmodelsup80 CURSOR FAST_FORWARD FOR SELECT name from master.sys.databases where state_desc='ONLINE' and compatibility_level>80 and name not in (select dbname from #tmp_alwayson where IsPrimaryServer=0 and ReadableSecondary='NO' and ReplicaServerName=@@SERVERNAME)
OPEN dbmodelsup80

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM dbmodelsup80 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	  SELECT db_id() AS DBId,
       db_name() AS Databasename,
       file_id AS [FileId],
       df.type_desc AS [Type],
       fg.name AS [FileGroup],
       df.name AS [Logical_name],
       df.physical_name AS [Physical_name],
       CAST(df.size/128.0 AS DECIMAL(20,2)) AS [sizeMB],
	   CAST(FILEPROPERTY(df.name, ''SpaceUsed'')/128.0 AS DECIMAL(20,2)) AS [SpaceUsedMB],
	   CAST(size/128.0-(FILEPROPERTY(df.name, ''SpaceUsed'')/128.0) AS DECIMAL(20,2)) AS [AvailableSpaceMB],
	   convert(decimal(20,2),(convert(decimal(20,2), round((size-fileproperty(df.name, ''SpaceUsed''))/128.000, 2)) / convert(decimal(20,2), round(df.size/128.000, 2)) * 100)) AS [Pct_Free],
	   CASE  WHEN growth=0 OR df.max_size NOT IN (-1,268435456) THEN 0 ELSE 1 END AS [IsAutoGrowth],
	   CASE WHEN is_percent_growth = 0 THEN LTRIM(STR(df.growth/128, 12, 1)) + '' MB '' ELSE ''By '' + CAST(df.growth AS VARCHAR) + '' percent '' END AS [AutoGrow],
	   CASE WHEN df.max_size = -1 THEN ''Unlimited''  ELSE ''Limited to '' + LTRIM(STR(df.max_size/128, 10, 1)) + '' MB'' END AS [Maxsize],
       getdate() AS SysDate
	   FROM sys.database_files AS df (NOLOCK)
	   LEFT JOIN sys.filegroups AS fg (NOLOCK) ON df.data_space_id = fg.data_space_id '
	
	EXECUTE(@SqlStatement);
END
CLOSE dbmodelsup80
DEALLOCATE dbmodelsup80

-- Databases with recovery_model minor than 80

DECLARE Databases_80 CURSOR FAST_FORWARD FOR SELECT name from master.sys.databases where state_desc='ONLINE' and compatibility_level<=80
OPEN Databases_80

WHILE 1 = 1
BEGIN
	FETCH NEXT FROM Databases_80 INTO @DB
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement1 = N'USE '
	+ QUOTEname(@DB)
	+ CHAR(13)+ CHAR(10)
	+ N'INSERT INTO #TmpDB
	  SELECT Db_id() DBid,
       Db_name() DBname,
       fileid AS [FileId],
       CASE
       WHEN (64 & status) = 64 THEN ''Log'' ELSE ''ROWS'' END AS [Type] ,
       Filegroup_name(groupid) AS FileGroup,
       name AS [Logical name],
       filename [Physical_name],
       Cast(size / 128.0 AS DECIMAL(20,2)) AS [sizeMB],
       Cast(Fileproperty(name, ''SpaceUsed'') / 128.0 AS DECIMAL(20,2)) AS [SpaceUsedMB],
       Cast(size / 128.0 - (Fileproperty(name, ''SpaceUsed'') / 128.0) AS DECIMAL(20,2)) AS [AvailableSpaceMB],
       CONVERT(DECIMAL(20,2), (CONVERT(DECIMAL(20,2), Round((size - Fileproperty(name, ''SpaceUsed'')) / 128.000, 2)) / CONVERT (DECIMAL(20,2), Round(size / 128.000, 2)) * 100)) AS [Pct_Free],
	   CASE WHEN growth = 0  OR maxsize NOT IN (-1,268435456) THEN 0 ELSE 1 END AS [IsAutoGrowth],
       CASE status & 0x100000 WHEN 0x100000 THEN ''By '' + Cast(growth AS VARCHAR) + '' Percent '' ELSE Ltrim(Str(growth/128, 12, 1)) + '' MB '' END [Autogrow],
       CASE  WHEN maxsize = -1 THEN ''Unlimited'' ELSE ''Limited to '' + Ltrim(Str(maxsize/128, 10, 1)) + '' MB'' END AS [Maxsize],
       Getdate() AS SysDate
FROM dbo.sysfiles (NOLOCK) '
	
	EXECUTE(@SqlStatement1);
END
CLOSE Databases_80
DEALLOCATE Databases_80

END

END

IF  @permanent=1 and @dbname IS NULL
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
				+ N'(ID bigint NOT NULL IDENTITY(1,1),
					[DBId] [int] NOT NULL,
					[DatabaseName] [varchar](250) NOT NULL,
					[FileId] [int] NOT NULL,
					[Type] [varchar] (15) NOT NULL,
					[FileGroup] [varchar] (200) NULL,
					[Logical_Name] [varchar] (100) NOT NULL,
					[Physical_Name] [varchar] (800) NOT NULL,
					[SizeMB] [decimal] (20,2) NOT NULL,
					[SpaceUsedMB] [decimal] (20,2) NOT NULL,
					[AvailableSpaceMB] [decimal] (20,2) NOT NULL,
					[Pct_Free] [decimal] (10,2) NOT NULL,
					[IsAutoGrowth] [bit] NOT NULL,
					[AutoGrow] [varchar] (20) NOT NULL,
					[MaxSize] [varchar] (50) NOT NULL,
					[SysDate] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY CLUSTERED(ID ASC));';
					EXEC(@StringToExecute);
	Print  'Insert Rows in table'
	DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = 'SET IDENTITY_INSERT  ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) + ' OFF' + ';' + CHAR(13) +
	'INSERT INTO ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) + CHAR(13) +
	'SELECT [DBId],[Databasename],[FileId],[Type],[FileGroup],[Logical_name],[Physical_name],[sizeMB],[SpaceUsedMB],[AvailableSpaceMB],[Pct_Free],[IsAutoGrowth],[AutoGrow],[Maxsize],[SysDate] FROM #TmpDB order by DBId' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + QUOTENAME(@database) +  '.' + QUOTENAME(@schema) +  '.'+ QUOTENAME(@table) +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert
END
ELSE
BEGIN
 IF  @dbname is not NULL
 BEGIN
 SELECT [Databasename],[FileId],[Type],[FileGroup],[Logical_name],[Physical_name],[sizeMB],[SpaceUsedMB],[AvailableSpaceMB],[Pct_Free],[IsAutoGrowth],[AutoGrow],[Maxsize],[SysDate] FROM #TmpDB where Databasename= @dbname order by DBId;
 END
ELSE
 IF @permanent=0
 BEGIN
SELECT [Databasename],[FileId],[Type],[FileGroup],[Logical_name],[Physical_name],[sizeMB],[SpaceUsedMB],[AvailableSpaceMB],[Pct_Free],[IsAutoGrowth],[AutoGrow],[Maxsize],[SysDate] FROM #TmpDB order by DBId;
END
END

 	IF @purge=1 --and @permanent <>0
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
				+ 'DELETE FROM ['+ @database+'].['+@schema+'].['+@table+'] WHERE [SysDate] <=GETDATE()-'+@defaultpurge+ ''
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

