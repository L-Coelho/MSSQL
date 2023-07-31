exec sp_configure 'show advanced options', 1;
go
reconfigure;
go
exec sp_configure 'xp_cmdshell', 1
go
reconfigure
go
exec xp_cmdshell 'net use Z: \\<server>\F$\<location> /user:<domain>\<username> ##########'
exec xp_cmdshell 'dir Z:' 


exec xp_cmdshell 'net use Z: /delete'


