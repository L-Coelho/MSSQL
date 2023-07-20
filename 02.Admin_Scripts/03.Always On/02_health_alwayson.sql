select
    ag.name as aag_name,
    ar.replica_server_name,
    d.name as [database_name],
    hars.is_local,
    hars.synchronization_state_desc as synchronization_state,
    hars.synchronization_health_desc as synchronization_health,
    hars.database_state_desc as db_state,
    --hars.is_suspended,
    --hars.suspend_reason_desc as suspend_reason,
    hars.last_commit_time
from sys.dm_hadr_database_replica_states as hars
join sys.availability_replicas as ar
    on hars.replica_id = ar.replica_id
join sys.availability_groups as ag
    on ag.group_id = hars.group_id
join sys.databases as d
    on d.group_database_id = hars.group_database_id
order by replica_server_name,aag_name
