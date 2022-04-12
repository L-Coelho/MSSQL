USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'perf' ) 
    EXEC('CREATE SCHEMA [perf] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'CaptureCpuMetrics')
	EXEC ('CREATE PROC perf.CaptureCpuMetrics AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <23/02/2022>
-- Description:	<Get CPU Utilization>
-- =============================================


ALTER PROCEDURE [perf].[CaptureCpuMetrics]
-- Parameters for the stored procedure --
	@permanent BIT =0, @purge INT=1,@defaultpurge VARCHAR(5)=365,
	@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='perf',@table
VARCHAR(100)='CpuMetrics',
	@minutes INT=60,@help BIT = 0

AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @sqlversion int;
	---- Checking SQL Server Version
   SELECT @sqlversion = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);

	---------------------------------------------------------------------------------------------------------------------------------------
	-- Check input parameters
	---------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @msg VARCHAR(8000);
	IF(@minutes NOT BETWEEN 1 AND 256 OR @minutes IS NULL)
	BEGIN
			RAISERROR (N'The value for the parameter @minutes is not supported, only valid minutes
from 1 to 256 ',16,1) WITH NOWAIT;
			RETURN;
	END

		/* Check SQL Server Version and abort in the case that the version is prior to SQL
Server 2008*/
			IF (
		SELECT
		  CASE WHEN @sqlversion <=9 THEN 0
			 ELSE 1
		  END
		) = 0
		BEGIN

			SELECT @msg = 'Sorry, only works on versions of SQL prior to 2008.' +
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
		SELECT  name,DATABASEPROPERTYEX(s.name,'status') as status from master..sysdatabases as
s
		WHERE s.name = @database and DATABASEPROPERTYEX(name,'status') ='ONLINE') THEN 1
			ELSE 0
		  END
		) = 0
		BEGIN
			SELECT @msg = 'Sorry but Database ' + @database+ ' does not exists or Database '
+@database+ ' is in the state <> Online'
			PRINT @msg;
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
					[SQL_Server_CPU] [INT] NOT NULL,
					[System_Idle_Process] [INT] NOT NULL,
					[Other_Process_CPU_Utilization] [INT] NOT NULL,
					[SysDate] [datetime] NOT NULL
					CONSTRAINT [PK_' + REPLACE(REPLACE(@table,'[',''),']','') + '] PRIMARY KEY
CLUSTERED(ID ASC));';
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
				+ 'DELETE FROM ['+ @database+'].['+@schema+'].['+@table+'] WHERE [SysDate]
<=GETDATE()-'+@defaultpurge+ ''
				+ CHAR(13)
				EXEC(@StringToExecute1);


	END
	ELSE
	BEGIN
	Print 'I will do no purging in the table'
	END


DECLARE @dsqltotal NVARCHAR(MAX)
DECLARE @dsql1 NVARCHAR(MAX)=N'DECLARE @ts_now bigint = (SELECT
cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info WITH (NOLOCK));' + CHAR(13)
DECLARE @dsql2 NVARCHAR(MAX)= N'INSERT INTO ['+ @database+'].['+@schema+'].['+@table+'] '
+ CHAR(13)
DECLARE @dsql3 NVARCHAR(MAX)= N'SELECT TOP('+CAST(@minutes AS VARCHAR(3))+')
SQLProcessUtilization AS [SQL_Server_CPU],
               SystemIdle AS [System_Idle_Process],
               100 - SystemIdle - SQLProcessUtilization AS
[Other_Process_CPU_Utilization],
               DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [SysDate]
FROM (SELECT record.value(''(./Record/@id)[1]'', ''int'') AS record_id,
			record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'')
			AS [SystemIdle],
			record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'',
''int'')
			AS [SQLProcessUtilization], [timestamp]
	  FROM (SELECT [timestamp], CONVERT(xml, record) AS [record]
			FROM sys.dm_os_ring_buffers WITH (NOLOCK)
			WHERE ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR''
			AND record LIKE N''%<SystemHealth>%'') AS x) AS y
ORDER BY record_id DESC OPTION (RECOMPILE);'

IF @permanent =0
   BEGIN
   SET @dsqltotal=@dsql1+@dsql3
   EXECUTE (@dsqltotal)
   END
   ELSE
   BEGIN
   SET @dsqltotal=@dsql1+@dsql2+@dsql3
   EXECUTE (@dsqltotal)
   END


   END
GO