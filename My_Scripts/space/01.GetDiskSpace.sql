USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'space' ) 
    EXEC('CREATE SCHEMA [space] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'GetDiskSpace')
	EXEC ('CREATE PROC [space].[GetDiskSpace] AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <05/02/2020>
-- Description:	<Get Info from computer Disks>
-- Version 0.1 - Initial Version
-- Alter date: <17/03/2020>
-- Version 0.2 - Arithemetic OverFlow
-- Alter date: <06/11/2022>
-- Version 0.3 - Dynamic create table and add Parameters to SP 
-- Usage Examples :
-- Display Only disk Space for SQL Server
-- exec [space].[GetDiskSpace]
-- Display and Save disk Space to a table
-- exec [space].[GetDiskSpace] @permanent=1 @database='dba_database',@schema='space',@table='DiskSpace'
-- =============================================

/* _____      _   _____  _     _     _____                      
  / ____|    | | |  __ \(_)   | |   / ____|                     
 | |  __  ___| |_| |  | | |___| | _| (___  _ __   __ _  ___ ___ 
 | | |_ |/ _ \ __| |  | | / __| |/ /\___ \| '_ \ / _` |/ __/ _ \
 | |__| |  __/ |_| |__| | \__ \   < ____) | |_) | (_| | (_|  __/
  \_____|\___|\__|_____/|_|___/_|\_\_____/| .__/ \__,_|\___\___|
                                          | |                   
                                          |_|
*/
ALTER PROCEDURE [space].[GetDiskSpace]
-- Parameters for the stored procedure --
	@permanent BIT =0, @purge INT=1,@defaultpurge VARCHAR(5)=600,
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='space',@table VARCHAR(100)='DiskSpace'
AS
BEGIN

	SET NOCOUNT ON;

		/* Check SQL Server Version and abort in the case that the version is prior to SQL Server 2005*/
	IF (
	SELECT
	  CASE
		 WHEN CONVERT(NVARCHAR(128), SERVERPROPERTY ('PRODUCTVERSION')) LIKE '8%' THEN 0
		 ELSE 1
	  END
	) = 0
	BEGIN
		DECLARE @msg VARCHAR(8000);
		SELECT @msg = 'Sorry, only works on versions of SQL prior to 2005.' + REPLICATE(CHAR(13),7933);
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

	IF @permanent=1
	BEGIN
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
					[VolumeName] [varchar](200) NOT NULL,
					[Capacity_GB] [bigint] NOT NULL,
					[Free_Space_GB] [bigint] NOT NULL,
					[Free_Space_Pct] [decimal](10, 2) NOT NULL,
					[SysDate] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY CLUSTERED(ID ASC));';
					EXEC(@StringToExecute);
	END;

	IF @purge=1
	BEGIN
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

	DECLARE @sqlversion int;
	-- Checking SQL Server Version
    SELECT @sqlversion = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);
	DECLARE @svrName varchar(255)
	DECLARE @sql varchar(400)
	DECLARE @xpcmd int
	DECLARE @enabelcmd int

	IF @sqlversion <11
BEGIN

SELECT @xpcmd = CAST([value] AS smallint) FROM sys.configurations (NOLOCK) WHERE [name] ='xp_cmdshell'

		IF @xpcmd = 0
		BEGIN
		EXEC sp_configure 'show advanced options', 1
		RECONFIGURE WITH OVERRIDE
	    EXEC sp_configure 'xp_cmdshell', 1
		RECONFIGURE WITH OVERRIDE
		SET @enabelcmd =1
	    --PRINT 'Enable CMD 1'
		END

		IF @xpcmd = 1
		BEGIN
		--PRINT 'Set EnableCMD To 0'
		SET @enabelcmd =0
		END

--by default it will take the current server name, we can the set the server name as well
set @svrName = @@SERVERNAME
set @sql = 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"'

--creating a temporary table

CREATE TABLE #output (line varchar(255))

--inserting disk name, total space and free space value in to temporary table

insert #output
EXEC master..xp_cmdshell @sql

--script to retrieve the values in GB from PS Script output

create table #results  (VolumeName varchar(100),Capacity_GB int,Free_Space_GB int)
insert into #results
select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as VolumeName
,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
(CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float)/1024,0) as 'Capacity_GB'
,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
(CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float) /1024 ,0)as 'Free_Space_GB'
from #output
where line like '[A-Z][:]%'
order by VolumeName

-- final table ( Created because Arithmetic Overflow )
create table #final (VolumeName varchar(100),Capacity_GB int,Free_Space_GB int,Free_Space_Pct numeric(6,2),SysDate datetime)
insert into #final
select VolumeName,Capacity_GB,Free_Space_GB,((CONVERT(NUMERIC(6,2),Free_Space_GB) / CONVERT(NUMERIC(6,2),Capacity_GB)) * 100),getdate()
from #results
--select * from #results

IF @permanent=1
	BEGIN
	Print  'Insert Rows in table'
	DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = 'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table + ' OFF' + ';' + CHAR(13) +
	'INSERT INTO ' + @database +  '.' + @schema +  '.'+ @table + CHAR(13) +
'SELECT VolumeName,Capacity_GB,Free_Space_GB,Free_Space_Pct,SysDate FROM #final' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert


END
ELSE
BEGIN

SELECT VolumeName,Capacity_GB,Free_Space_GB,Free_Space_Pct,SysDate FROM #final
END

END
ELSE
IF @permanent=1
	BEGIN
	
	Print  'Insert Rows in table'
	DECLARE @sqlinsert1 nvarchar(max)
    SET @sqlinsert1 = '
	SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table + ' OFF' + ';' + +
CHAR(13) +
	'INSERT INTO ' + @database +  '.' + @schema +  '.'+ @table + + CHAR(13) +
'select distinct
			   volume_mount_point VolumeName,
			   total_bytes/1024/1024/1024 Capacity_GB,
			   available_bytes/1024/1024/1024 Free_Space_GB,
			   cast(cast(convert(decimal(20,2), available_bytes)/convert(decimal(20,2),
total_bytes) as decimal (4,4))*100 as decimal(4,2)) as Free_Space_Pct,
			   getdate() as SysDate
		from  sys.master_files as f cross apply sys.dm_os_volume_stats(f.database_id, f.file_id) vs' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert1
	
END
ELSE
BEGIN
SELECT DISTINCT
			   volume_mount_point VolumeName,
			   total_bytes/1024/1024/1024 Capacity_GB,
			   available_bytes/1024/1024/1024 Free_Space_GB,
			   cast(cast(convert(decimal(20,2), available_bytes)/convert(decimal(20,2),
total_bytes) as decimal (4,4))*100 as decimal(4,2)) as Free_Space_Pct,
			   getdate() as SysDate
		FROM  sys.master_files AS f cross apply sys.dm_os_volume_stats(f.database_id, f.file_id) vs
END
END


IF OBJECT_ID('tempdb..#output') IS NOT NULL
DROP TABLE #output

IF OBJECT_ID('tempdb..#results') IS NOT NULL
DROP TABLE #results

IF OBJECT_ID('tempdb..#final') IS NOT NULL
DROP TABLE #final

IF @sqlversion >=11
BEGIN
Print 'No need xp_cmdshell'
END
ELSE
BEGIN
IF @enabelcmd = 1
BEGIN

		EXEC sp_configure 'show advanced options', 1
		RECONFIGURE WITH OVERRIDE
	    EXEC sp_configure 'xp_cmdshell', 0
		RECONFIGURE WITH OVERRIDE
		Print ' Put xp_cmdshell disable'
END
END

GO


