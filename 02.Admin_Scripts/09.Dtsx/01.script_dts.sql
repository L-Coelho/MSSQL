use msdb

set nocount on
declare @objPackage int
declare @PackageName varchar(128)
declare @rc int
declare @ServerName varchar(128)
declare @out varchar(1000)
declare @Path varchar(100)
--declare @id int

select @Path = 'C:\lc\'
select @ServerName = @@ServerName

DECLARE cursor_objects CURSOR FAST_FORWARD FOR
    select distinct(name) from sysdtspackages

-- Abrindo Cursor para leitura
OPEN cursor_objects

-- Lendo a próxima linha
FETCH NEXT FROM cursor_objects INTO @PackageName
-- Percorrendo linhas do cursor (enquanto houverem)
WHILE @@FETCH_STATUS = 0
BEGIN

exec @rc = sp_OACreate 'DTS.Package', @objPackage output

exec @rc = sp_OAMethod @objPackage, 'LoadFromSQLServer' , null, @ServerName =
@ServerName,@PackageName = @PackageName, @Flags = 256

EXEC sp_OAGetErrorInfo @objPackage

select @out = @Path + @PackageName + '.dts'
exec @rc = sp_OAMethod @objPackage, 'SaveToStorageFile' , null, @out
exec sp_OADestroy @objPackage

    -- Lendo a próxima linha
    FETCH NEXT FROM cursor_objects INTO @PackageName
END
-- Fechando Cursor para leitura
CLOSE cursor_objects
-- Desalocando o cursor
DEALLOCATE cursor_objects