DECLARE @dbname VARCHAR(500)   
DECLARE @statement NVARCHAR(MAX)

CREATE TABLE #TmpAgrupa(
	[Hostname] [varchar](200) ,
	[SQL Instance Name] [varchar](200) ,
	[OS Platform] [varchar](50) ,
	[DBMS Name] [varchar](200) ,
	[DBMS Version] [varchar](50) ,
	[Database_name] [varchar](500) ,
	[Create_Date] [datetime],
	[Users] [varchar](8000)	  )

DECLARE db_cursor CURSOR 
LOCAL FAST_FORWARD
FOR  
SELECT name
FROM master.sys.databases
WHERE name NOT IN ('master','msdb','model','tempdb') AND state_desc='online' 
OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  
WHILE @@FETCH_STATUS = 0  
BEGIN  

SELECT @statement = 'use '+QUOTENAME(@dbname) +';'+ '

Declare @val datetime; 
Select @val= create_date from master.sys.databases where name=db_name(db_id())
Declare @val1 Varchar(8000); 
Select @val1 = COALESCE(@val1 +  (CASE WHEN  name =''dbo'' THEN COALESCE(''sa'' + '','', '''') ELSE COALESCE(name + '','', '''') END) , (CASE WHEN  name =''dbo'' THEN COALESCE(''sa'' + '','', '''') ELSE COALESCE(name +'','', '''') END))
FROM sys.database_principals 
WHERE type in (''S'',''G'',''U'') and name NOT IN (''sys'', ''INFORMATION_SCHEMA'' , ''guest'',''##MS_PolicyEventProcessingLogin##'')
select CONVERT(VARCHAR(200),SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'')) AS Hostname, CONVERT(VARCHAR(200),@@servername) as [SQL Instance Name],''WINDOWS'' AS [OS Platform], ''Microsoft SQL Server'' AS [DBMS Name],   CONVERT(VARCHAR(200),SERVERPROPERTY(''ProductVersion'')) AS [DBMS Version],dbname=db_name(db_id()) ,@val as [create_date], @val1 as [users]  into #tempfinal
INSERT INTO #TmpAgrupa
select * from #tempfinal
DROP TABLE #tempfinal'
EXEC sp_executesql @statement

FETCH NEXT FROM db_cursor INTO @dbname  
END  
CLOSE db_cursor  
DEALLOCATE db_cursor

select * from #TmpAgrupa
DROP TABLE #TmpAgrupa