-- Troubleshoot always on
-- https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/troubleshoot-always-on-availability-groups-configuration-sql-server?view=sql-server-ver16


-- Check the WSFC cluster node configuration

use master  
go  
select * from sys.dm_hadr_cluster_members  
go

-- Check the instance account permissions

SELECT 
  @@servername as sql_instance,perm.class_desc,
  prin.name,
  perm.permission_name,
  perm.state_desc,
  prin.type_desc as PrincipalType,
  prin.is_disabled
FROM sys.server_permissions perm
  LEFT JOIN sys.server_principals prin ON perm.grantee_principal_id = prin.principal_id
  LEFT JOIN sys.tcp_endpoints tep ON perm.major_id = tep.endpoint_id
WHERE 
  perm.class_desc = 'ENDPOINT'
  AND perm.permission_name = 'CONNECT'
  AND tep.type = 4


-- detail ao (run on primary_replica)

select
    ag.name as aag_name,
    ar.replica_server_name,
	ar.endpoint_url,
	d.name as [database_name],
	agl.dns_name as ListernerName,
	agl.port,
	agl.ip_configuration_string_from_cluster,
    hars.is_local,
	ar.availability_mode_desc,
	ar.secondary_role_allow_connections_desc
from sys.dm_hadr_database_replica_states as hars
join sys.availability_replicas as ar
    on hars.replica_id = ar.replica_id
join sys.availability_groups as ag
    on ag.group_id = hars.group_id
join sys.databases as d
    on d.group_database_id = hars.group_database_id
		left join sys.availability_group_listeners agl
   on ar.group_id=agl.group_id
order by replica_server_name,aag_name

-- permission Endpoint
SELECT ep.endpoint_id, p.class_desc, p.permission_name, ep.name, sp.name 
FROM sys.server_permissions p
    INNER JOIN sys.endpoints ep ON p.major_id = ep.endpoint_id
    INNER JOIN sys.server_principals sp ON p.grantee_principal_id = sp.principal_id
WHERE class = '105'

-- Check the endpoint status

SELECT name, state_desc FROM sys.database_mirroring_endpoints
