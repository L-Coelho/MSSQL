#Requires Modules
#Install-Module -Name SqlServer
#Install-Module -Name ImportExcel

$query_to_run = @'
select * from master.sys.databases
'@

# Database Vars
$sqlinstance = 'LAPTOP-GLRR4E3T'
$sqluser ='xxx'
$sqlpass='xxxx'
$database='master'

#Report Location Vars
$dirpath ='C:\lc\export_excel\'
$reportname ='report_'
$datetime = (Get-Date).ToString("yyyyMMddHHmmss")
$reportoutput = $dirpath + $reportname + $datetime +'_'+'.xlsx'

Invoke-SqlCmd -ServerInstance $sqlinstance -Database $database -Query $query_to_run | Export-Excel -Path $reportoutput -ExcludeProperty ItemArray, RowError, RowState, Table, HasErrors




