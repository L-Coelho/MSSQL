USE [dba_database]
GO


IF OBJECT_ID('perf.dbusage') IS NULL   
   BEGIN   
       EXEC ('CREATE PROCEDURE perf.dbusage AS RETURN 138;');   
   END;   
GO 


-- =====================================================================
-- Author:		<Luis Coelho> - Based on script Provided by Felipe Renz
-- Create date: <28/06/2024>
-- Description:	<Get Database Resource Usage>
-- =====================================================================



ALTER PROCEDURE [perf].[dbusage]
@permanent BIT=0, @purge INT=1, @defaultpurge VARCHAR (5)=600, @database VARCHAR (100)='dba_database', @schema VARCHAR (50)='perf', @table VARCHAR (100)='dbresourceusage'
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


	CREATE TABLE #tempresult ([Database Name] VARCHAR(500),[CPU Rank] INT,[CPU Time (ms)] BIGINT, [CPU Percent] DECIMAL(12, 2),[I/O Rank] INT,[Total I/O (MB)] DECIMAL(12, 2),[Total I/O %] DECIMAL(12, 2),
	[Read I/O (MB)] DECIMAL(12, 2), [Read I/O %] DECIMAL(12, 2), [Write I/O (MB)] DECIMAL(12, 2),[Write I/O %] DECIMAL(12, 2),[Buffer Pool Rank] INT,[Cached Size (MB)] DECIMAL(12, 2),[Buffer Pool Percent] DECIMAL(12, 2), [SysDate] DATETIME);
   

    -- CPU Utilization

WITH DB_CPU_Stats AS
(
    SELECT pa.DatabaseID,
           DB_Name(pa.DatabaseID) AS [Database Name],
           SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
    FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
    CROSS APPLY 
    (
        SELECT CONVERT(int, value) AS [DatabaseID] 
        FROM sys.dm_exec_plan_attributes(qs.plan_handle)
        WHERE attribute = N'dbid'
    ) AS pa
    GROUP BY pa.DatabaseID
),

-- I/O Utilization
Aggregate_IO_Statistics AS
(
    SELECT DB_NAME(database_id) AS [Database Name],
           CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) AS [ioTotalMB],
           CAST(SUM(num_of_bytes_read) / 1048576 AS DECIMAL(12, 2)) AS [ioReadMB],
           CAST(SUM(num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) AS [ioWriteMB]
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
    GROUP BY database_id
),

-- Buffer Pool Usage
AggregateBufferPoolUsage AS
(
    SELECT DB_NAME(database_id) AS [Database Name],
           CAST(COUNT(*) * 8/1024.0 AS DECIMAL(12,2)) AS [CachedSize]
    FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
    WHERE database_id <> 32767 -- ResourceDB
    GROUP BY database_id
),

-- CPU Utilization with Rank
CPU_Rank AS
(
    SELECT ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [CPU Rank],
           [Database Name],
           [CPU_Time_Ms] AS [CPU Time (ms)], 
           CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(12, 2)) AS [CPU Percent]
    FROM DB_CPU_Stats
    WHERE DatabaseID <> 32767 -- ResourceDB
),

-- I/O Utilization with Rank
IO_Rank AS
(
    SELECT ROW_NUMBER() OVER (ORDER BY ioTotalMB DESC) AS [I/O Rank],
           [Database Name],
           ioTotalMB AS [Total I/O (MB)],
           CAST(ioTotalMB / SUM(ioTotalMB) OVER () * 100.0 AS DECIMAL(12, 2)) AS [Total I/O %],
           ioReadMB AS [Read I/O (MB)], 
           CAST(ioReadMB / SUM(ioReadMB) OVER () * 100.0 AS DECIMAL(12, 2)) AS [Read I/O %],
           ioWriteMB AS [Write I/O (MB)], 
           CAST(ioWriteMB / SUM(ioWriteMB) OVER () * 100.0 AS DECIMAL(12, 2)) AS [Write I/O %]
    FROM Aggregate_IO_Statistics
),

-- Buffer Pool Usage with Rank
Buffer_Pool_Rank AS
(
    SELECT ROW_NUMBER() OVER(ORDER BY CachedSize DESC) AS [Buffer Pool Rank],
           [Database Name],
           CachedSize AS [Cached Size (MB)],
           CAST(CachedSize / SUM(CachedSize) OVER() * 100.0 AS DECIMAL(12,2)) AS [Buffer Pool Percent]
    FROM AggregateBufferPoolUsage
)


-- Result
INSERT INTO #tempresult
SELECT 
    c.[Database Name],
    c.[CPU Rank],
    c.[CPU Time (ms)],
    c.[CPU Percent],
    io.[I/O Rank],
    io.[Total I/O (MB)],
    io.[Total I/O %],
    io.[Read I/O (MB)],
    io.[Read I/O %],
    io.[Write I/O (MB)],
    io.[Write I/O %],
    bp.[Buffer Pool Rank],
    bp.[Cached Size (MB)],
    bp.[Buffer Pool Percent],
	GETDATE() as [SysDate]
FROM 
    CPU_Rank c
LEFT JOIN 
    IO_Rank io ON c.[Database Name] = io.[Database Name]
LEFT JOIN 
    Buffer_Pool_Rank bp ON c.[Database Name] = bp.[Database Name]
ORDER BY 
    c.[CPU Rank];

	
	IF @permanent=1
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
		/* Check if output table is equals to the name of the stored procedure*/
	IF @table='dbusage'
	BEGIN
		SELECT @msg = 'Sorry, but the name of the table destination cannot be equal to the name of the Stored Procedure.' + REPLICATE(CHAR(13),7933);
		PRINT @msg;
		RETURN;
	END;
	
	-- Create Table if not exists
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
					[Database Name] VARCHAR(500) NOT NULL,
					[CPU Rank] INT NOT NULL,
					[CPU Time (ms)] BIGINT NOT NULL,
					[CPU Percent] DECIMAL(12, 2) NOT NULL,
					[I/O Rank] INT NOT NULL,
					[Total I/O (MB)] DECIMAL(12, 2) NOT NULL,
					[Total I/O %] DECIMAL(12, 2) NOT NULL,
					[Read I/O (MB)] DECIMAL(12, 2) NOT NULL,
					[Read I/O %] DECIMAL(12, 2) NOT NULL,
					[Write I/O (MB)] DECIMAL(12, 2) NOT NULL,
					[Write I/O %] DECIMAL(12, 2) NOT NULL,
					[Buffer Pool Rank] INT NOT NULL,
					[Cached Size (MB)] DECIMAL(12, 2) NOT NULL,
					[Buffer Pool Percent] DECIMAL(12, 2) NOT NULL,
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

	IF @permanent=1
	BEGIN
	Print  'Insert Rows in table'
	DECLARE @sqlinsert nvarchar(max)
    SET @sqlinsert = 'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table + ' OFF' + ';' + CHAR(13) +
	'INSERT INTO ' + @database +  '.' + @schema +  '.'+ @table + CHAR(13) +
'SELECT [Database Name],[CPU Rank],[CPU Time (ms)],[CPU Percent],[I/O Rank],[Total I/O (MB)],[Total I/O %],[Read I/O (MB)],[Read I/O %],[Write I/O (MB)],[Write I/O %],[Buffer Pool Rank],[Cached Size (MB)],[Buffer Pool Percent], [SysDate] FROM #tempresult' + CHAR(13) +
	'SET IDENTITY_INSERT  ' + @database +  '.' + @schema +  '.'+ @table +  ' ON' + ';'
    EXEC sp_executesql @sqlinsert


END
ELSE
BEGIN
SELECT [Database Name],[CPU Rank],[CPU Time (ms)],[CPU Percent],[I/O Rank],[Total I/O (MB)],[Total I/O %],[Read I/O (MB)],[Read I/O %],[Write I/O (MB)],[Write I/O %],[Buffer Pool Rank],[Cached Size (MB)],[Buffer Pool Percent], [SysDate] FROM #tempresult
END


TRUNCATE TABLE	#tempresult

END

GO


