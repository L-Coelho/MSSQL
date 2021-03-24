<# 
Authors : Luis Coelho 
Based on Alexandru-Codrin Panaite in : https://stackoverflow.com/questions/7516337/powershell-list-all-sql-instances-on-my-system
V1.01 (18/03/2021) 
# Collects information about local instances on the server such as :
- $instance.SQLInstance ( Returns the Full Name of the SQL Server Instance )
- $instance.Instance ( Returns only the SQL Server Instance Name )
- $instance.Edition ( Returns The SQL Server Edition ( Enterprise,Standard,Developer ) )   
- $instance.ProductVersion  ( Returns the actual SQL Server Version installed )
- $instance.MajorVersion ( Returns the SQL Server Version ( 2008,2012,2014,etc.. )
- $instance.PatchLevel  ( Returns the actual SQL Server Version installed )
- $instance.VirtualName  ( Returns the actual SQL Server VirtualName ( Only in case of cluster Instances )
- $instance.IsCluster  ( Returns the info if the SQL Server Instance is in cluster or not )
- $instance.ServiceName ( Returns the Local SQL Service Name )
- $instance.ServiceStatus ( Returns the Status of SQL Service Status Running or Stopped )
- $instance.ServerName ( Returns the name of the local HostName )
- $instance.SQLCollation ( Returns the SQL Server Collation )
V1.02 (19/03/2021 )
- Add verification ## Test if SQL Server exists is in the Registry ##
- Alter Key $productversion from Version to PatchLevel
- Add $instance.PatchLevel and $instance.SQLCollation
## Only Works On SQL Server 2008 or above because key "cluster" and "InstalledInstances" only exists on SQL 2008 ##
## Procedure to be performed on the local host ##

#>
# Bypass the error The file xx.ps1 is not digitally signed.#

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


function ListSQLInstances {
$server_name = $env:computername
$listinstances = New-Object System.Collections.ArrayList

  ## Test if SQL Server exists in the Registry ##
  if(!(Test-Path ("HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server")))
  {
  Write-Output "SQL Server Does Not Exists on the Host : $server_name "
  exit # exit the session #
  }

$installedInstances = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
foreach ($i in $installedInstances) {
    $sqlnameservice = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$i
    $sqlcollation = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlnameservice\Setup").Collation
    $productversion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlnameservice\Setup").Version
    $patchlevel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlnameservice\Setup").PatchLevel
    # Make the Service Info to $servicestatus #
    if ($i -eq "MSSQLSERVER")
                        { $tmpservicestatus = "MSSQLSERVER" }
					else
                        {$tmpservicestatus = "MSSQL$"+ $i }
  $servicestatus = (get-service "$tmpservicestatus" )
  # Test if is a Cluster Or Standalone #
  if(!(Test-Path ("HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\" +$sqlnameservice + "\cluster")))
  {
	  # Is not a Cluster Instance #
  $IsCluster = $False
	if ($i -eq "MSSQLSERVER")
                        { $sqlinstance = $server_name }
					else
                        {$sqlinstance = $server_name + "\" + $i }
  }
  else
  {
  $IsCluster = $True
  $VirtualName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlnameservice\Cluster").ClusterName
    if ($i -eq "MSSQLSERVER")
                        { $sqlinstance = $VirtualName }
					else
                        {$sqlinstance = $VirtualName + "\" + $i }
  }
    $majorversion = switch -Regex ($productversion) {
        '8' { 'SQL2000' }
        '9' { 'SQL2005' }
        '10' { 'SQL2008' }
        '10.5' { 'SQL2008R2' }
        '11' { 'SQL2012' }
        '12' { 'SQL2014' }
        '13' { 'SQL2016' }
        '14' { 'SQL2017' }
        '15' { 'SQL2019' }
        default { "Unknown" }
    }
    $instance = [PSCustomObject]@{
        SQLInstance          = $sqlinstance;
        Instance             = $i
        Edition              = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlnameservice\Setup").Edition;
        MajorVersion         = $majorversion;
	    VirtualName          = $VirtualName;
	    IsCluster            = $IsCluster;
	    ServiceName          = $tmpservicestatus;
        ServiceStatus        = $servicestatus.status;
        ServerName           = $server_name;
        PatchLevel           = $patchlevel;
        SQLCollation         = $sqlcollation;
        
    }
    $listinstances.Add($instance)
}
Return $listinstances
}

## Use The information gathered in the function ListSQLInstances ##

<#
Usage Examples :

Example 1: For all instances that are running returns the SQL Server Instance Name,MajorVersion,Edition,Sql Version

$instances = ListSQLInstances
foreach ($instance in $instances) 
{
   if($instance.ServiceStatus -eq "Running")
    {
    Write-Host $instance.SQLInstance,$instance.MajorVersion,$instance.Edition,$instance.ProductVersion
    }        
}

Example 2: For all instances that are in state running executes a sql server query defined in $query_to_run

$instances = ListSQLInstances
foreach ($instance in $instances) 
{
   if($instance.ServiceStatus -eq "Running")
    {
    Invoke-SqlCmd -ServerInstance $instance.SQLInstance -Database 'master' -Query $query_to_run
    }        
}

#>

## Example Query to Run ##
$query_to_run = @'
SELECT
         @@servername as SQLInstance,DB_NAME(database_id) as [Database_Name] , Total_Size_MB = CAST(SUM(size) * 8. / 1024 AS DECIMAL(20,0))
    FROM master.sys.master_files
	where DB_NAME(database_id) in (SELECT name FROM master..sysdatabases WHERE DATABASEPROPERTYEX(name,'Status')='ONLINE' and name not in ('master','model','msdb','tempdb','dba_database')) GROUP BY database_id
	ORDER by DB_NAME(database_id) ASC
'@

$instances = ListSQLInstances
foreach ($instance in $instances) 
{
   if($instance.ServiceStatus -eq "Running")
    {
   # Write-Host $instance.SQLInstance,$instance.Edition,$instance.PatchLevel,$instance.SQLCollation,$instance.ServiceStatus
    Invoke-SqlCmd -ServerInstance $instance.SQLInstance -Database 'master' -Query $query_to_run 
    }        
}