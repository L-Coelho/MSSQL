SELECT @@servername as 'Instance Name'
,SUBSTRING(s.name,1,50) AS 'DATABASE Name',
DATABASEPROPERTYEX(s.name,'Status') AS [Statedb],
DATABASEPROPERTYEX(s.name,'RECOVERY') AS [Recovery Model],
b.backup_start_date AS 'Last Full Backup',
DATEDIFF(day, b.backup_start_date, getdate()) AS DaysLastFullBK,
c.backup_start_date AS 'Last Diff Backup',
DATEDIFF(day, c.backup_start_date, getdate()) AS DaysLastDiffBK,
d.backup_start_date AS 'Last Tlog Backup',
DATEDIFF(HH, d.backup_start_date, getdate()) AS HoursLastTlogBK
FROM master..sysdatabases s
LEFT OUTER JOIN msdb..backupset b
ON s.name = b.database_name
AND b.backup_start_date =
(SELECT MAX(backup_start_date)AS 'Full DB Backup Status'
FROM msdb..backupset
WHERE database_name = b.database_name
AND TYPE = 'D') -- full database backups only, not log backups
LEFT OUTER JOIN msdb..backupset c
ON s.name = c.database_name
AND c.backup_start_date =
(SELECT MAX(backup_start_date)'Differential DB Backup Status'
FROM msdb..backupset
WHERE database_name = c.database_name
AND TYPE = 'I')
LEFT OUTER JOIN msdb..backupset d
ON s.name = d.database_name
AND d.backup_start_date =
(SELECT MAX(backup_start_date)'Transaction Log Backup Status'
FROM msdb..backupset
WHERE database_name = d.database_name
AND TYPE = 'L')
WHERE s.name <>'tempdb'
--AND DATABASEPROPERTYEX(s.name,'Status') <>'OFFLINE'
ORDER BY s.name