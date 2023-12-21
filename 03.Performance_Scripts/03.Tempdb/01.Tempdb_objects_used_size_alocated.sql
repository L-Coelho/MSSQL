USE [tempdb];

WITH [task_space_usage] AS (
    -- SUM alloc/delloc pages
    SELECT [session_id],
           [request_id],
           SUM([internal_objects_alloc_page_count]) AS [alloc_pages],
           SUM([internal_objects_dealloc_page_count]) AS [dealloc_pages]
    FROM sys.dm_db_task_space_usage WITH (NOLOCK)
    WHERE [session_id] != @@SPID
    GROUP BY [session_id], [request_id]
)
SELECT [tskspc].[session_id],
       CAST([tskspc].[alloc_pages] * 1.0 / 128 AS DECIMAL (20,2)) AS [Internal object MB space],
	   CAST([tskspc].[alloc_pages] * 1.0 / 128/1024 AS DECIMAL (20,2)) AS [Internal object GB space],
	   --CAST([tskspc].[dealloc_pages] * 1.0 / 128 AS DECIMAL (20,2)) AS [Internal object dealloc MB space],
	   --CAST([tskspc].[dealloc_pages] * 1.0 / 128/1024 AS DECIMAL (20,2)) AS [Internal object dealloc GB space],
       [exsql].[text],
       -- Extract statement from sql text
       ISNULL(
           NULLIF(
               SUBSTRING(
                 [exsql].[text],
                 [exrq].[statement_start_offset] / 2,
                 CASE WHEN [exrq].[statement_end_offset] < [exrq].[statement_start_offset]
                  THEN 0
                 ELSE([exrq].[statement_end_offset] - [exrq].[statement_start_offset]) / 2 END
               ), ''
           ), [exsql].[text]
       ) AS [statement text],
       [expl].[query_plan]
FROM [task_space_usage] AS [tskspc]
INNER JOIN sys.dm_exec_requests AS [exrq] WITH (NOLOCK) ON [tskspc].[session_id] = [exrq].[session_id] AND [tskspc].[request_id] = [exrq].[request_id]
OUTER APPLY sys.dm_exec_sql_text([exrq].[sql_handle]) AS [exsql]
OUTER APPLY sys.dm_exec_query_plan([exrq].[plan_handle]) AS [expl]
WHERE [exsql].[text] IS NOT NULL OR [expl].[query_plan] IS NOT NULL
ORDER BY 3 DESC;