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
-- Alter date: <11/06/2022>
-- Version 0.3 - Dynamic create table and add Parameters to SP 
-- Usage Examples :
-- Display Only disk Space for SQL Server
-- exec [space].[GetDiskSpace]
-- Display and Save disk Space to a table
-- exec [space].[GetDiskSpace] @permanent=1 @database='dba_database',@schema='space',@table='DiskSpace'
-- Alter date: <08/11/2022>
-- Version 0.4 - Generate Mail Alerts based on a threshold and excluded disks
-- exec [space].[GetDiskSpace] @alert=1,@mailprofile='<profile_name>',@recipients ='mail1@mail.xxx;mail2@mail.xxx',@excludeddisks='<disks_to_excluded>'

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
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='space',@table VARCHAR(100)='DiskSpace',
	@Alert BIT=0,@Mailprofile VARCHAR(100)=NULL,@Recipients VARCHAR(200)=NULL,@ExcludedDisks VARCHAR(500)=NULL,@PctDiskFree INT=10


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

	/* Check if the mail profile exists */
	DECLARE @validprofile BIT
		
	SET @validprofile =
    CASE
        WHEN NOT EXISTS(SELECT name FROM msdb.dbo.sysmail_profile WHERE name=@Mailprofile) OR @Mailprofile IS NULL THEN 0
        ELSE 1
       END;

	/* Transforming excluded disks to be used on the in clause */

	IF @ExcludedDisks IS NOT NULL
		BEGIN

		SET @ExcludedDisks=''''+REPLACE(@ExcludedDisks,',',''',''')+''''
		END

		-- final table ( Created because Arithmetic Overflow )
		CREATE TABLE #final (VolumeName varchar(100),Capacity_GB int,Free_Space_GB int,Free_Space_Pct numeric(6,2),SysDate datetime)

		-- alert table ( Created because Arithmetic Overflow )
	   CREATE TABLE #alert (VolumeName varchar(100),Capacity_GB int,Free_Space_GB int,Free_Space_Pct numeric(6,2),SysDate datetime)
		

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


insert into #final
select VolumeName,Capacity_GB,Free_Space_GB,((CONVERT(NUMERIC(6,2),Free_Space_GB) / CONVERT(NUMERIC(6,2),Capacity_GB)) * 100),getdate()
from #results


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

	insert into #final
	SELECT DISTINCT
			   volume_mount_point VolumeName,
			   total_bytes/1024/1024/1024 Capacity_GB,
			   available_bytes/1024/1024/1024 Free_Space_GB,
			   cast(cast(convert(decimal(20,2), available_bytes)/convert(decimal(20,2),
total_bytes) as decimal (4,4))*100 as decimal(4,2)) as Free_Space_Pct,
			   getdate() as SysDate
		FROM  sys.master_files AS f cross apply sys.dm_os_volume_stats(f.database_id, f.file_id) vs
	
END

ELSE
-- Sql version 2012 or later
BEGIN
insert into #final
SELECT DISTINCT
			   volume_mount_point VolumeName,
			   total_bytes/1024/1024/1024 Capacity_GB,
			   available_bytes/1024/1024/1024 Free_Space_GB,
			   cast(cast(convert(decimal(20,2), available_bytes)/convert(decimal(20,2),
total_bytes) as decimal (4,4))*100 as decimal(4,2)) as Free_Space_Pct,
			   getdate() as SysDate
		FROM  sys.master_files AS f cross apply sys.dm_os_volume_stats(f.database_id, f.file_id) vs
select * from #final
END

/* Alerts*/


DECLARE @tableHTML  NVARCHAR(MAX) ;  
DECLARE @subject  varchar(max)
DECLARE @select nvarchar(max)


	/* Check if there is any alert to proced */
	DECLARE @validpct BIT
		
	SET @validpct =
    CASE
        WHEN NOT EXISTS(SELECT VolumeName,Capacity_GB,Free_Space_GB,Free_Space_Pct,SysDate FROM #final where Free_Space_Pct<=@PctDiskFree) THEN 0
        ELSE 1
       END;

IF (@Alert=1 and @validprofile=1 and @validpct=1)
BEGIN
IF @ExcludedDisks is null
	BEGIN
	SET @select = '
	insert into #alert
	SELECT VolumeName,Capacity_GB,Free_Space_GB,Free_Space_Pct,SysDate FROM #final where Free_Space_Pct<='+cast(@PctDiskFree as varchar(5)) +'' 
	END
	ELSE
	BEGIN
	SET @select = '
	insert into #alert
	SELECT VolumeName,Capacity_GB,Free_Space_GB,Free_Space_Pct,SysDate FROM #final where Free_Space_Pct<='+cast(@PctDiskFree as varchar(5)) +' AND VolumeName NOT IN ('+@ExcludedDisks+') '
	
	END
  EXEC sp_executesql @select


IF @sqlversion>=11
IF (@Alert=1 and @validprofile=1 and @recipients IS NOT NULL )
BEGIN
Print 'I will handle the alerts SQL >= 2012, because i have a valid profile'

		SET @tableHTML =  

   	N'<H1> Alert ' + @@servername + ' - Disks Below  '+ CAST (@PctDiskFree as VARCHAR) +' PCT </H1>' +  
    N'<table border="1">' +  
    N'<tr><th>VolumeName</th><th>Capacity_GB</th>' +  
    N'<th>Free_Space_GB</th><th>Free_Space_Pct</th>' +
    CAST ( ( SELECT td = VolumeName,       '',  
                    td = Capacity_GB, '',  
 					td = Free_Space_GB, '',  
					[td/@bgcolor]='"#cce6ff"',td = Free_Space_Pct, '' 
                    
              FROM #alert
			   
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +  
    N'<table border="12">' +  
    N'<th> Excluded Disks </th></tr>' +  
    CAST ( ( SELECT [td/@bgcolor]='"#ADFF2F"',td = @ExcludedDisks, ''       
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +             
    N'</table>' ;  
--END


SET @subject =  ' Alert ' + @@servername + ' - Disks Below  '+ CAST (@PctDiskFree as VARCHAR) +' PCT ' 
EXEC msdb.dbo.sp_send_dbmail @recipients=@Recipients,  
 @profile_name = @Mailprofile,  
    @subject = @subject ,  
    @body = @tableHTML ,  
    @body_format = 'HTML' 
END
ELSE
Print 'I will Not handle the alerts SQL >= 2012, because i dont have a valid profile or there is null recipients'


IF @sqlversion<=10
IF (@Alert=1 and @validprofile=1 and @recipients IS NOT NULL )
BEGIN
Print 'I will handle the alerts SQL <= 2008, because i have a valid profile'

SET @tableHTML =  

   	N'<H1> Alert ' + @@servername + ' - Disks Below  '+ CAST (@PctDiskFree as VARCHAR) +' PCT </H1>' +  
    N'<table border="1">' +  
    N'<tr><th>VolumeName</th><th>Capacity_GB</th>' +  
    N'<th>Free_Space_GB</th><th>Free_Space_Pct</th>' +
    CAST ( ( SELECT td = VolumeName,       '',  
                    td = Capacity_GB, '',  
 					td = Free_Space_GB, '',  
					[td/@bgcolor]='"#cce6ff"',td = Free_Space_Pct, '' 
              FROM #alert	   
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +  
    N'<table border="12">' +  
    N'<th> Excluded Disks </th></tr>' +  
    CAST ( ( SELECT [td/@bgcolor]='"#ADFF2F"',td = @ExcludedDisks, ''       
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +             
    N'</table>' ;  
--END

SET @subject =  ' Alert ' + @@servername + ' - Disks Below  '+ CAST (@PctDiskFree as VARCHAR) +' PCT ' 
EXEC msdb.dbo.sp_send_dbmail @recipients=@Recipients,  
 @profile_name = @Mailprofile,  
    @subject = @subject ,  
    @body = @tableHTML ,  
    @body_format = 'HTML';
END
ELSE
Print 'I will not handle the alerts SQL <= 2008, because i dont have a valid profile or there is null recipients '
END
ELSE
BEGIN
Print 'I dont have the alert option enable or a valid profile or valid recipients or the pct free space is not <=@PctDiskFree '
END


IF OBJECT_ID('tempdb..#output') IS NOT NULL
DROP TABLE #output

IF OBJECT_ID('tempdb..#results') IS NOT NULL
DROP TABLE #results

IF OBJECT_ID('tempdb..#final') IS NOT NULL
DROP TABLE #final

IF OBJECT_ID('tempdb..#alert') IS NOT NULL
DROP TABLE #alert

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

END
GO


