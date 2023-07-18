--Restore latest backups on destination servers
SET NOCOUNT ON;
 
-- Declare cusrsor toinclude multiple DBs
DECLARE Restorecursor CURSOR FOR
SELECT  name FROM sys.databases
WHERE name ='dba_database'
-- Declare variable to hold DB names from cursor
DECLARE @db_name sysname
 
-- Open cursor
OPEN Restorecursor
FETCH NEXT FROM Restorecursor INTO @Db_name
 
WHILE (@@FETCH_STATUS <> -1)
BEGIN
  DECLARE @tmp TABLE ( RestorePart varchar(2000), FilePart varchar(max)   )
 
-- Insert restore statement in temp table for current DB in curosr  
     INSERT @tmp
      SELECT
        'Restore database ' + s.[database_name] + ' 
       From Disk = ''' + B.[physical_device_name] + '''
       with REPLACE, KEEP_CDC, RECOVERY, STATS =3 ' AS RestorePart,
        '      , Move ''' + f.[logical_name] + ''''
        + ' TO ''' + f.[physical_name] + '''' AS FilePart
      FROM [msdb].[dbo].[backupset] S
      INNER JOIN [msdb].[dbo].[backupfile] F ON S.backup_set_id = f.backup_set_id
      INNER JOIN [msdb].[dbo].[backupmediafamily] B ON s.media_set_id = b.media_set_id
      WHERE s.type = 'd'
      AND s.database_name = @Db_name
      AND s.backup_start_date = (
							SELECT MAX(s.backup_start_date) FROM [msdb].[dbo].[backupset] s
							WHERE s.type = 'd'
							AND s.database_name = @Db_name
							)
      ORDER BY s.backup_set_id DESC
 
 -- Select combined stement from parts
	 SELECT DISTINCT RestorePart FROM @tmp
    UNION ALL
    SELECT FilePart FROM @tmp
    UNION ALL
    SELECT 'GO'
 
    DELETE FROM @tmp
 
  
  FETCH NEXT FROM Restorecursor INTO @Db_name
END
-- Close and deallocate the cursor  
CLOSE Restorecursor
DEALLOCATE Restorecursor
SET NOCOUNT OFF