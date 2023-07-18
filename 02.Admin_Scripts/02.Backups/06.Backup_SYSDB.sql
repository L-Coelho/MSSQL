DECLARE @BackupDirectory NVARCHAR(200)
DECLARE @name VARCHAR(50) -- database name
DECLARE @path VARCHAR(256) -- path for backup files
DECLARE @fileName VARCHAR(256) -- filename for backup
DECLARE @fileDate VARCHAR(20) -- used for file name
Declare @options VARCHAR(256)
Declare @exec VARCHAR(256)
EXEC master..xp_instance_regread @rootkey = 'HKEY_LOCAL_MACHINE',
    @key = 'Software\Microsoft\MSSQLServer\MSSQLServer',
    @value_name = 'BackupDirectory', @BackupDirectory = @BackupDirectory OUTPUT ;
-- Backup To another Location
-- SET @BackupDirectory ='C:\teste' 
DECLARE @ver int
SET @ver = @@MICROSOFTVERSION / 0x01000000
SELECT @fileDate = CONVERT(VARCHAR(20),GETDATE(),112) + REPLACE(CONVERT(varchar(5),GETDATE(), 108), ':', '')

-- Options for Backup
IF ( @ver <= 8 )
      SET @options = ' '
ELSE IF ( @ver = 9 )
	  SET @options = ' WITH COPY_ONLY;'
ELSE IF ( @ver >= 10 )
      SET @options = ' WITH COPY_ONLY,COMPRESSION;'

SET @path = @BackupDirectory+'\'

DECLARE db_cursor CURSOR READ_ONLY FOR
SELECT name
FROM master.dbo.sysdatabases
WHERE name IN ('master','model','msdb')

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @name

WHILE @@FETCH_STATUS = 0
BEGIN
   SET @fileName = @path + @name + '_' + @fileDate + '.BAK'
   set @exec ='BACKUP DATABASE ' +'[' + @name + ']'+ ' ' + 'TO DISK = ' + '''' + @fileName + ''''+  @options
   print @exec
   Exec (@exec)
      FETCH NEXT FROM db_cursor INTO @name
END
DEALLOCATE db_cursor
