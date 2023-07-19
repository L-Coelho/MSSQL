
--select @@version

--======================================================================================
--> INI --> ZONA TABELAS TEMP
--======================================================================================

	IF EXISTS (SELECT NAME FROM tempdb..sysobjects WHERE NAME = '##IDX_MissingIndex')    
		BEGIN    
		   DROP TABLE ##IDX_MissingIndex    
		END   

		CREATE TABLE ##IDX_MissingIndex	
				(
					[DatabaseName]		NVARCHAR(128), 
					[schema_id]			INT ,
					[schema_name]		NVARCHAR(128),
					[object_id]			INT,
					[object_name]		NVARCHAR(128),
					[type]				NVARCHAR(2),
					[Rows]				BIGINT,
					[SizeMB]			NVARCHAR(4000),
					[equality_columns]	NVARCHAR(4000),
					[inequality_columns]NVARCHAR(4000),
					[included_columns]	NVARCHAR(4000),
					[sql_statement]		NVARCHAR(4000),
					[unique_compiles]	BIGINT,
					[user_seeks]		BIGINT,
					[user_scans]		BIGINT,
					[avg_total_user_cost]FLOAT,
					[avg_user_impact]	FLOAT,
					[last_user_seek]	DATETIME,
					[last_user_scan]	DATETIME,
					[system_seeks]		BIGINT,
					[system_scans]		BIGINT,
					[avg_total_system_cost] FLOAT,
					[avg_system_impact]	FLOAT,
					[last_system_seek]	DATETIME,
					[last_system_scan]	DATETIME,
					[Score]				FLOAT,
					[ScoreHighest]		FLOAT
				
				)   


--======================================================================================
--> FIM --> ZONA TABELAS TEMP
--======================================================================================				



	-->Declarar o Cursor
	DECLARE sysObjAnalise CURSOR STATIC FOR

		SELECT	distinct(NAME)
		FROM	sys.databases
		WHERE	[state] <> 6	--6 = Offline

		AND NAME NOT IN ('model' )

		


	--Variáveis temporárias
	DECLARE @Contador as integer
	SET		@Contador = 0
	DECLARE @DBName as varchar(128)
	SET		@DBName = ''
	DECLARE @SQLString AS VARCHAR(8000)
	SET		@SQLString = ''
	DECLARE @ParmDefinition NVARCHAR(500);
	SET		@ParmDefinition = N'@DBName as varchar(128)';
	DECLARE @StrVariable varchar(128);
	SET		@StrVariable = ''
	
	
	--Abre o Cursor	
	OPEN sysObjAnalise

		--Vai buscar o primeiro registo
		FETCH sysObjAnalise INTO @DBName

		--Enquanto existirem registos ...
		WHILE (@@FETCH_STATUS=0)
			BEGIN

						-->Tabela ##Results	
						SELECT @SQLString =    
						
						' USE [' + @DBName + '] ' +
						'
							INSERT INTO ##IDX_MissingIndex	
									(
										[DatabaseName],
										[schema_id],
										[schema_name],
										[object_id]	,
										[object_name],
										[type]		,
										[Rows]		,
										[SizeMB]	,
										[equality_columns],
										[inequality_columns],
										[included_columns]	,
										[sql_statement]	,
										[unique_compiles],
										[user_seeks]	,
										[user_scans]	,
										[avg_total_user_cost],
										[avg_user_impact]	,
										[last_user_seek],
										[last_user_scan],
										[system_seeks]	,
										[system_scans]	,
										[avg_total_system_cost],
										[avg_system_impact]	,
										[last_system_seek]	,
										[last_system_scan]	,
										[Score],
										[ScoreHighest]		
									)   


								SELECT
									 DB_NAME() AS DataBaseName,
									 sys.schemas.schema_id, sys.schemas.name AS schema_name,
										sys.objects.object_id, sys.objects.name AS object_name, sys.objects.type,
										partitions.Rows, partitions.SizeMB,
										sys.dm_db_missing_index_details.equality_columns AS equality_columns,
										sys.dm_db_missing_index_details.inequality_columns AS inequality_columns,
										sys.dm_db_missing_index_details.included_columns AS included_columns,
									  ''Create NonClustered Index IX_'' + sys.objects.name + ''_missing_'' 
											+ CAST(sys.dm_db_missing_index_details.index_handle AS VARCHAR(10)) COLLATE DATABASE_DEFAULT
											+ '' On '' + sys.dm_db_missing_index_details.STATEMENT 
											+ '' ('' + IsNull(sys.dm_db_missing_index_details.equality_columns,'''') 
											+ CASE WHEN sys.dm_db_missing_index_details.equality_columns IS Not Null 
												And sys.dm_db_missing_index_details.inequality_columns IS Not Null THEN '','' 
													ELSE '''' END 
											+ IsNull(sys.dm_db_missing_index_details.inequality_columns, '''')
											+ '')'' 
											+ IsNull('' Include ('' + sys.dm_db_missing_index_details.included_columns + '');'', '';''
											) AS sql_statement	,	
										sys.dm_db_missing_index_group_stats.unique_compiles,
										sys.dm_db_missing_index_group_stats.user_seeks, sys.dm_db_missing_index_group_stats.user_scans,
										sys.dm_db_missing_index_group_stats.avg_total_user_cost, sys.dm_db_missing_index_group_stats.avg_user_impact,
										sys.dm_db_missing_index_group_stats.last_user_seek, sys.dm_db_missing_index_group_stats.last_user_scan,
										sys.dm_db_missing_index_group_stats.system_seeks, sys.dm_db_missing_index_group_stats.system_scans,
										sys.dm_db_missing_index_group_stats.avg_total_system_cost, sys.dm_db_missing_index_group_stats.avg_system_impact,
										sys.dm_db_missing_index_group_stats.last_system_seek, sys.dm_db_missing_index_group_stats.last_system_scan,
										(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks) + 
												 CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles)) * 
												 CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost) * 
												  CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)
												   AS Score,
										(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks) + 
												 CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_scans)) * 
												 CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost) * 
												  CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)
												   AS ScoreHighest
											   
									FROM
										sys.objects
										JOIN (
											SELECT
												object_id, SUM(CASE WHEN index_id BETWEEN 0 AND 1 THEN row_count ELSE 0 END) AS Rows,
												replace(CONVERT(numeric(19,3), CONVERT(numeric(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(numeric(19,3), 128)),''.'','','') AS SizeMB
											FROM sys.dm_db_partition_stats
											WHERE sys.dm_db_partition_stats.index_id BETWEEN 0 AND 1 --0=Heap; 1=Clustered; only 1 per table
											GROUP BY object_id
										) AS partitions ON sys.objects.object_id=partitions.object_id
										JOIN sys.schemas ON sys.objects.schema_id=sys.schemas.schema_id
										JOIN sys.dm_db_missing_index_details ON sys.objects.object_id=sys.dm_db_missing_index_details.object_id
										JOIN sys.dm_db_missing_index_groups ON sys.dm_db_missing_index_details.index_handle=sys.dm_db_missing_index_groups.index_handle
										JOIN sys.dm_db_missing_index_group_stats ON sys.dm_db_missing_index_groups.index_group_handle=sys.dm_db_missing_index_group_stats.group_handle
									WHERE
										sys.dm_db_missing_index_details.database_id=DB_ID()
									ORDER BY
											CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks) + 
											CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles) * 
											CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost) * 
											CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)*-1
							'
							
							EXECUTE (@SQLString)
							PRINT @SQLString
				
				--Incrementa Contador
				SET @Contador = @Contador + 1
				--Vai buscar o próximo registo
				FETCH NEXT FROM sysObjAnalise INTO @DBName

			END


	--Close o Cursor
	CLOSE sysObjAnalise
	--Disvincula o Objecto
	DEALLOCATE sysObjAnalise


--DROP TABLE ##IDX_MissingIndexTOT
	SELECT	TB1.DatabaseName 
			,COUNT(*) AS 'IDX Missing TOT' 
--			,TB2.[IDX Missing > 80 %]
	INTO ##IDX_MissingIndexTOT
	FROM ##IDX_MissingIndex	AS TB1 
	WHERE TB1.DatabaseName NOT IN ('master','msdb','tempdb')
	GROUP BY TB1.DatabaseName
	ORDER BY TB1.DatabaseName


	SELECT	 @@servername as servername
			,TB1.DatabaseName
			,TB1.[IDX Missing TOT]
			,ISNULL(TB2.[IDX Missing > 80 %],0) AS 'IDX Missing > 80 %'
			,ISNULL(TB3.[IDX Missing > 90 %],0) AS 'IDX Missing > 90 %'
			,ISNULL(TB4.[IDX Missing > 95 %],0) AS 'IDX Missing > 95 %'
	FROM	##IDX_MissingIndexTOT AS TB1
	LEFT OUTER JOIN
			(
				SELECT	DatabaseName 
						,COUNT(*) AS 'IDX Missing > 80 %' 
				FROM ##IDX_MissingIndex	WHERE DatabaseName NOT IN ('master','msdb','tempdb') AND avg_user_impact >= '80.00'
				GROUP BY DatabaseName			
			) AS TB2 ON TB1.DatabaseName = TB2.DatabaseName
	LEFT OUTER JOIN
			(
				SELECT	DatabaseName 
						,COUNT(*) AS 'IDX Missing > 90 %' 
				FROM ##IDX_MissingIndex	WHERE DatabaseName NOT IN ('master','msdb','tempdb') AND avg_user_impact >= '90.00'
				GROUP BY DatabaseName			
			) AS TB3 ON TB1.DatabaseName = TB3.DatabaseName
	LEFT OUTER JOIN
			(
				SELECT	DatabaseName 
						,COUNT(*) AS 'IDX Missing > 95 %' 
				FROM ##IDX_MissingIndex	WHERE DatabaseName NOT IN ('master','msdb','tempdb') AND avg_user_impact >= '95.00'
				GROUP BY DatabaseName			
			) AS TB4 ON TB1.DatabaseName = TB4.DatabaseName




SELECT		@@servername as servername,
					[DatabaseName],
					[schema_id],
					[schema_name],
					[object_id],
					[object_name],
					[type]	,
					[Rows]	,
					[SizeMB],
					[Score]	,			
					[ScoreHighest]	,			
					
					[avg_total_user_cost],					
					[avg_user_impact],					
					[unique_compiles]	,
					[user_seeks]		,					
					[user_scans]		,
					
					[last_user_seek]	,
					[last_user_scan]	,
					
					[system_seeks]		,
					[system_scans]		,
					
					[avg_total_system_cost],
					[avg_system_impact]	,
					
					[last_system_seek]	,
					[last_system_scan]	,
					
					[equality_columns],
					[inequality_columns],
					[included_columns]	,
					[sql_statement]		
FROM ##IDX_MissingIndex	WHERE DatabaseName NOT IN ('master','msdb','tempdb')


/*
SELECT DatabaseName , COUNT(*) AS 'Missing' 
FROM ##IDX_MissingIndex	WHERE DatabaseName NOT IN ('master','msdb','tempdb')
GROUP BY DatabaseName ,[avg_user_impact] 
HAVING [avg_user_impact] >= '90.00'
*/

