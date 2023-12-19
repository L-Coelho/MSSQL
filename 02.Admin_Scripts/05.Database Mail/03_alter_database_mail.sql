-- Select database mail

SELECT [sysmail_server].[account_id]
		,[sysmail_account].[name] AS [Account Name]
      ,[servertype]
      ,[servername] AS [SMTP Server Address]
      ,[Port]
     
  FROM [msdb].[dbo].[sysmail_server]
  INNER JOIN [msdb].[dbo].[sysmail_account]
  ON [sysmail_server].[account_id]=[sysmail_account].[account_id]


-- Alter database mail

-- Run below SP to change any info of mail account. Replace XXXX & XX with your correct SMTP IP address and port no.
EXECUTE msdb.dbo.sysmail_update_account_sp
    @account_name = 'MSSQL_Name_mail_account'
    ,@description = 'Mail account for administrative e-mail.'
    ,@mailserver_name = 'smtp.XXXX.com'
    ,@mailserver_type = 'SMTP'
    ,@port = XX5