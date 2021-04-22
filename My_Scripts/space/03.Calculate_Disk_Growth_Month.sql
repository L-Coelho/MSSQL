USE [dba_database]
GO

IF NOT EXISTS ( SELECT  * FROM    sys.schemas  WHERE   name = N'space' ) 
    EXEC('CREATE SCHEMA [space] AUTHORIZATION [dbo]');
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'Calculate_Disk_Growth_Month')
	EXEC ('CREATE PROC [space].[Calculate_Disk_Growth_Month] AS SELECT ''stub version, to be replaced''')
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Luis Coelho>
-- Create date: <09/04/2021>
-- Description:	<Gather The Growth from disk (Space Used) by Month in Pivot Table>
-- V.01 <14/04/2021>
-- Usage Examples:
-- Display the growth from the table DiskSpace By Months
-- exec ['+@schema+'].[Calculate_Disk_Growth_Month] @months=<Number of Months to analize>
-- Display the growth from the table DiskSpace By Months
-- exec ['+@schema+'].[Calculate_Disk_Growth_Month] @Aggregate_Type=<MIN,MAX,AVG>
-- =============================================
/*
 #####                                                                 ######                           #####                                            #     #                            
#     #   ##   #       ####  #    # #        ##   ##### ######         #     # #  ####  #    #         #     # #####   ####  #    # ##### #    #         ##   ##  ####  #    # ##### #    # 
#        #  #  #      #    # #    # #       #  #    #   #              #     # # #      #   #          #       #    # #    # #    #   #   #    #         # # # # #    # ##   #   #   #    # 
#       #    # #      #      #    # #      #    #   #   #####          #     # #  ####  ####           #  #### #    # #    # #    #   #   ######         #  #  # #    # # #  #   #   ###### 
#       ###### #      #      #    # #      ######   #   #              #     # #      # #  #           #     # #####  #    # # ## #   #   #    #         #     # #    # #  # #   #   #    # 
#     # #    # #      #    # #    # #      #    #   #   #              #     # # #    # #   #          #     # #   #  #    # ##  ##   #   #    #         #     # #    # #   ##   #   #    # 
 #####  #    # ######  ####   ####  ###### #    #   #   ######         ######  #  ####  #    #          #####  #    #  ####  #    #   #   #    #         #     #  ####  #    #   #   #    # 
                                                               #######                         #######                                           #######                                    
*/
ALTER PROCEDURE [space].[Calculate_Disk_Growth_Month]
	-- Parameters for the stored procedure --
	@Aggregate_Type VARCHAR(3)='MAX',@months VARCHAR(3)=3,@database VARCHAR(100)='dba_database',@schema VARCHAR(50)='space',@table VARCHAR(100)='DiskSpace'

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
/* Check If the Parameter @Aggregate_Type is correct ( MIN,MAX or AVG )*/
		IF (
SELECT
  CASE
     WHEN @Aggregate_Type='MIN' OR @Aggregate_Type='MAX' OR @Aggregate_Type='AVG'  THEN 1
     ELSE 0
  END
) = 0
BEGIN
	DECLARE @msg1 VARCHAR(8000);
	SELECT @msg1 = 'Sorry, but the valor @Aggregate_Type is incorrect only accepts ( MIN,MAX or AVG ) .' + REPLICATE(CHAR(13),7933);
	PRINT @msg1;
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
	DECLARE @msg2 VARCHAR(8000);
	SELECT @msg2 = 'Sorry but Database ' + @database+ ' does not exists or Database ' +@database+ ' is in the state <> Online'
	PRINT @msg2;
	RETURN;
END;

/* Check if the schema output database exists in the server and abort in the case that it doesn't exists*/
IF  (
SELECT
CASE WHEN
@database IS NOT NULL AND @schema IS NOT NULL and @table IS NOT NULL 
AND EXISTS (SELECT * FROM sys.schemas  WHERE name = @schema ) THEN 1
    ELSE 0
  END
) = 0
BEGIN
	DECLARE @msg3 VARCHAR(8000);
	SELECT @msg3 = 'Sorry but The Schema ' + @schema + ' does not exists '
	PRINT @msg3;
	RETURN;
END;

/* Check if the Table output database exists in the server and abort in the case that it doesn't exists*/
IF  (
SELECT
CASE WHEN
@database IS NOT NULL AND @schema IS NOT NULL and @table IS NOT NULL 
AND EXISTS (SELECT * FROM sys.objects WHERE name = @table  AND type ='U' ) THEN 1
    ELSE 0
  END
) = 0
BEGIN
	DECLARE @msg4 VARCHAR(8000);
	SELECT @msg4 = 'Sorry but The Table ' + @table + ' does not exists '
	PRINT @msg4;
	RETURN;
END;

IF OBJECT_ID(N'tempdb..#tempagrupa') IS NOT NULL
BEGIN
DROP TABLE #tempagrupa
END

/*Calculate all the months in the table DiskSpace */

IF OBJECT_ID(N'tempdb..#tempconta') IS NOT NULL
BEGIN
DROP TABLE #tempconta
END
CREATE TABLE #tempconta([mesano] varchar(8))
DECLARE @calculate as varchar (8000)
SET @calculate= ('SELECT QUOTENAME(YEAR(SysDate)*100 + MONTH(SysDate)) as mesano from ['+ @database+ '].['+@schema+'].['+@table+'] WHERE [SysDate] >= DATEADD(MONTH, -'+@months+'+1, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)) GROUP BY YEAR(SysDate)*100 + MONTH(SysDate) order by YEAR(SysDate)*100 + MONTH(SysDate) ASC')


INSERT INTO #tempconta
EXEC (@calculate)
--select * from #tempconta

IF OBJECT_ID(N'tempdb..#tempconta1') IS NOT NULL
BEGIN
DROP TABLE #tempconta1
END
CREATE TABLE #tempconta1([mesano] varchar(8))
DECLARE @calculate1 as varchar (8000)
SET @calculate1= ('SELECT YEAR(SysDate)*100 + MONTH(SysDate) as mesano from ['+ @database+ '].['+@schema+'].['+@table+'] WHERE [SysDate] >= DATEADD(MONTH, -'+@months+'+1, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)) GROUP BY YEAR(SysDate)*100 + MONTH(SysDate) order by YEAR(SysDate)*100 + MONTH(SysDate) ASC')

INSERT INTO #tempconta1
EXEC (@calculate1)

CREATE TABLE #tempagrupa([VolumeName] [varchar](200),[mesano] [int],[Totalused] [int])

/* Create Data Info for Pivot Table */
Declare @val Varchar(MAX); 
Select @val = COALESCE(@val + ',' + mesano , mesano) From #tempconta;


DECLARE @final AS VARCHAR (8000)
SET @final='	

INSERT INTO #tempagrupa
SELECT [VolumeName]
      ,YEAR(SysDate)*100 + MONTH(SysDate) as mesano
	  --,([Capacity_GB]-[Free_Space_GB]) as Totalused
	   ,CAST('+@Aggregate_Type+'([Capacity_GB]-[Free_Space_GB]) AS INT) AS Totalused   
  FROM ['+ @database+ '].['+@schema+'].['+@table+']
  WHERE [SysDate] >= DATEADD(MONTH, -'+@months+'+1, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0))
  GROUP BY  [VolumeName],([Capacity_GB]-[Free_Space_GB]),YEAR(SysDate)*100 + MONTH(SysDate)

SELECT [VolumeName] as Space_Used_LUN,' +@val+ ' FROM #tempagrupa
PIVOT
('+@Aggregate_Type+'(Totalused) FOR  [mesano] IN (' +@val+ ')) AS pvt
ORDER BY [VolumeName] ASC'
--print(@final)

DECLARE @final1 AS VARCHAR (8000)

SET @final1='
DECLARE @mincalculate VARCHAR(6)
DECLARE @maxcalculate VARCHAR(6)

SET @mincalculate= (SELECT MIN(mesano) from #tempconta1)
SET @maxcalculate= (SELECT MAX(mesano) from #tempconta1)

;WITH mincalc as(
SELECT VolumeName,mesano
,'+@Aggregate_Type+'(Totalused) AS total
FROM #tempagrupa WHERE mesano=@mincalculate
GROUP BY VolumeName,mesano),
maxcalc as (
SELECT VolumeName,mesano
,'+@Aggregate_Type+'(Totalused) AS total
FROM #tempagrupa WHERE mesano=@maxcalculate
GROUP BY VolumeName,mesano)
SELECT a.VolumeName ,a.total as MinSpace_Used,b.total as MaxSpace_Used,b.total-a.total AS Growth_Last_'+@months+'_Months
FROM mincalc a JOIN maxcalc b ON a.VolumeName=b.VolumeName
ORDER BY a.VolumeName ASC
'
--print @final1

EXEC (@final)
EXEC (@final1)

DROP TABLE #tempagrupa
DROP TABLE #tempconta
DROP TABLE #tempconta1

END



GO


