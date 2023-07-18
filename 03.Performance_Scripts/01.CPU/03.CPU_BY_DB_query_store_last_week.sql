DECLARE @DatabaseName NVARCHAR(256);
DECLARE @SQL    NVARCHAR(MAX);

CREATE TABLE #Stats (
    DatabaseName    NVARCHAR(256),
    CPUUsage        FLOAT
);

DECLARE myCursor CURSOR READ_ONLY
FOR
SELECT name
FROM sys.databases
WHERE is_query_store_on = 1;

OPEN myCursor;

WHILE 1=1 BEGIN

    FETCH NEXT FROM myCursor
    INTO @DatabaseName;

    IF @@FETCH_STATUS != 0 BREAK;

    SET  @SQL = N'
        USE ' + QUOTENAME(@DatabaseName) +';
        
        INSERT #Stats (DatabaseName, CPUUsage)
        SELECT @DatabaseName,
            SUM(qsrs.count_executions*qsrs.avg_cpu_time)
        FROM [sys].[query_store_runtime_stats] qsrs
            JOIN [sys].[query_store_runtime_stats_interval] qsrsi ON qsrsi.runtime_stats_interval_id = qsrs.runtime_stats_interval_id
        WHERE qsrsi.start_time > DATEADD(DAY, -7, GETDATE());
    '
    EXEC sp_executesql @SQL, N'@DatabaseName NVARCHAR(256)', @DatabaseName;

END

CLOSE myCursor;
DEALLOCATE myCursor;

SELECT ROW_NUMBER() OVER(ORDER BY CPUUsage DESC) AS [CPU Rank],
       DatabaseName, 
       ISNULL(CPUUsage , 0)/1000 AS [CPU Time (ms)], 
       CAST(ISNULL(CPUUsage / SUM(CPUUsage) OVER() * 100.0, 0) AS DECIMAL(5, 2)) AS [CPU Percent]
FROM #Stats
ORDER BY [CPU Rank];

DROP TABLE #Stats;