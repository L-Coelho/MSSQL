

WITH DB_CPU_Stats
AS
(
    SELECT DatabaseID, DB_Name(DatabaseID) AS [DatabaseName], 
      SUM(total_worker_time) AS [CPU_Time_Ms]
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY (
                    SELECT CONVERT(int, value) AS [DatabaseID] 
                  FROM sys.dm_exec_plan_attributes(qs.plan_handle)
                  WHERE attribute = N'dbid') AS F_DB
    GROUP BY DatabaseID
)
SELECT ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [row_num],
       DatabaseName,
        [CPU_Time_Ms], 
       CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPUPercent]
FROM DB_CPU_Stats
--WHERE DatabaseID > 4 -- system databases
--AND DatabaseID <> 32767 -- ResourceDB
ORDER BY row_num OPTION (RECOMPILE);

DECLARE @total INT
SELECT @total=sum(cpu) FROM sys.sysprocesses sp (NOLOCK)
    join sys.sysdatabases sb (NOLOCK) ON sp.dbid = sb.dbid

SELECT sb.name 'database', @total 'system cpu', SUM(cpu) 'database cpu', CONVERT(DECIMAL(4,1), CONVERT(DECIMAL(17,2),SUM(cpu)) / CONVERT(DECIMAL(17,2),@total)*100) '%'
FROM sys.sysprocesses sp (NOLOCK)
JOIN sys.sysdatabases sb (NOLOCK) ON sp.dbid = sb.dbid
--WHERE sp.status = 'runnable'
GROUP BY sb.name
ORDER BY CONVERT(DECIMAL(4,1), CONVERT(DECIMAL(17,2),SUM(cpu)) / CONVERT(DECIMAL(17,2),@total)*100) desc
