
/*Open Ports
netsh advfirewall firewall add rule name="Open Port 1434 for SQL Browser" dir=in action=allow protocol=UDP localport=1434
netsh advfirewall firewall add rule name="Open Port 5022 for Availability Groups" dir=in action=allow protocol=TCP localport=5022
netsh advfirewall firewall add rule name="Open Port 1433 for SQL Server" dir=in action=allow
protocol=TCP localport=1433
*/

--https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/create-an-availability-group-transact-sql?view=sql-server-2017


--  Create endpoints on all replicas using windows authentication

CREATE ENDPOINT [Hadr_endpoint]
    STATE = STARTED
    AS TCP (LISTENER_PORT = 5022)
    FOR DATABASE_MIRRORING (
        ROLE = ALL
        );

--  Grant connect to the service account running partner instances

USE master
GO
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [<domain>\<account_name>];

IF (SELECT state FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END
GO

---------------------------------------------------------------------------------------------------------------
--Na instância primária, criar o AG

CREATE AVAILABILITY GROUP [AG_NAME] 
   FOR   
      --DATABASE <db_name> --(usar só no caso de adição de BD, na criação do AG)
   REPLICA ON   
      '<host_name>' WITH   
         (  
         ENDPOINT_URL = 'TCP://<host_name>.<domain>:5022',   
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,  
         FAILOVER_MODE = MANUAL  
         ),  
      'QSRAZSQLNOH2' WITH   
         (  
         ENDPOINT_URL = 'TCP://<host_name>.<domain>:5022',  
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,  
         FAILOVER_MODE = MANUAL  
         );   
GO 

---------------------------------------------------------------------------------------------------------------
--Na instância secundária, Fazer o Join do AG
-- run on secondary instances to join AG

ALTER AVAILABILITY GROUP [AG_NAME] JOIN;  
GO  

--Depois de restaurar a bd com Norecovery executar o comando. 
ALTER DATABASE [<db_name>] SET HADR AVAILABILITY GROUP = [AG_NAME];


--Adicionar uma nova base de dados ao um AG.
--Na instância primária
USE [master]
GO
ALTER AVAILABILITY GROUP [AG_NAME] ADD DATABASE [<db_name>];
GO

-- Fazer FULL backup e LOG backup no primário e restaurar no secundário com NoRecovery

--Na instância secundária depois de fazer restore da BD
ALTER DATABASE [<db_name>] SET HADR AVAILABILITY GROUP = [AG_NAME];

---------------------------------------------------------------------------------------------------------------

--Adicionar um Listener

USE [master]
GO
ALTER AVAILABILITY GROUP [AG_NAME]
ADD LISTENER N'AG_NAME' (
WITH IP
((N'10.81.54.7', N'255.255.255.128'))
, PORT=54421);
GO


--Adicionar um novo ip ao listener
--Primeiro tem que ser removido o IP actual no cluster. Depois executar a query

USE [master]
GO
ALTER AVAILABILITY GROUP [AG1]
MODIFY LISTENER N'LTeste'
(ADD IP (N'192.168.220.14', N'255.255.255.0')
);
GO


-- Azure --

(Get-ClusterNode "<name>").NodeWeight=0


Probe:

<probe_name>.<ip_probe>

Get-ClusterResource -Name "<probe_name>.<ip_probe>" | Get-ClusterParameter

59997

-- Configurar probe do load balancer
$SqlIpAddress = Get-ClusterResource |
  Where-Object {$_.ResourceType -eq "IP Address"} |
  Where-Object {$_.Name.StartsWith("<name>")}
  
   
$SqlIpAddress | Set-ClusterParameter -Multiple @{
 'Address'= xx.xx.xx.xxx;
 'ProbePort'= 5xxxx;
 'SubnetMask'='255.255.255.xxx';
 'Network'= (Get-ClusterNetwork).Name;
 'EnableDhcp'=0; }
 
Get-ClusterResource -Name <probe_name>.<ip_probe> | Set-ClusterParameter -Name ProbeFailureThreshold -Value 5