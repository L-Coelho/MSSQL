
-- Script Made by João Fragoso
	IF EXISTS (SELECT NAME FROM tempdb..sysobjects WHERE NAME like '##GERAL%')    
		BEGIN    
		   DROP TABLE ##GERAL    
		END   
		
	CREATE TABLE ##GERAL
		( 
			[ID_Tipo][int] IDENTITY(1,1) NOT NULL,
			[NomeTipo] varchar(90),
			[ValorTipo] varchar(450)
		) 



--=========================================
-->Determinar o Nó Activo onde se encontra
--=========================================

DECLARE @ActiveNode [nvarchar](128)
EXEC [master]..[xp_regread]  @rootkey = 'HKEY_LOCAL_MACHINE'
                            ,@RegistryKeyPath = 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'
                            ,@value_name = 'ComputerName'
                            ,@value = @ActiveNode OUTPUT

	INSERT INTO ##GERAL ([NomeTipo],[ValorTipo]) VALUES ( 'ActiveNode', @ActiveNode)

--=========================================
--Determinar o numero de CPUS
--=========================================
declare @CPU_COUNT as INT
SELECT  @CPU_COUNT = CPU_COUNT From sys.dm_os_sys_info    
--select @CPU_COUNT


declare @cpu_id as VARCHAR(450)
Select  @cpu_id= COALESCE(@cpu_id + ',' ,'') + cast(cpu_id as varchar)
from sys.dm_os_schedulers where status='VISIBLE ONLINE'
order by cpu_id

	INSERT INTO ##GERAL ([NomeTipo],[ValorTipo]) VALUES ( 'cpu_id', @cpu_id)


DECLARE @parent_node_id as VARCHAR(450)
SELECT @parent_node_id =  COALESCE(@parent_node_id + ',' ,'') + cast(parent_node_id as varchar)
from sys.dm_os_schedulers 
where status='VISIBLE ONLINE'

	INSERT INTO ##GERAL ([NomeTipo],[ValorTipo]) VALUES  ( 'parent_node_id', @parent_node_id)

DECLARE @SQLStrgBase as varchar (1000)
DECLARE @SQLStrgCPUS as varchar (6000)
DECLARE @SQLStrgFim  as varchar (8000)


SET		@SQLStrgBase =
		'
			declare @CPU_COUNT as INT
			SELECT  @CPU_COUNT = CPU_COUNT  From sys.dm_os_sys_info    
				

			SELECT	(SELECT [ValorTipo] FROM ##GERAL where [NomeTipo] = ''ActiveNode'') AS ActiveNode
					,@@servername AS InstanceName
					,(SELECT total_physical_memory_kb / 1024  FROM sys.dm_os_sys_memory) as ''total_physical_memory_MB''
					,(SELECT available_physical_memory_kb / 1024 FROM sys.dm_os_sys_memory) as ''available_physical_memory_kb'' 
					,(SELECT [value_in_use]   FROM [master].[sys].[configurations] WHERE NAME = (''min server memory (MB)'')) as [Min server memory (MB)]
					,(SELECT [value_in_use]  FROM [master].[sys].[configurations] WHERE NAME = (''max server memory (MB)'')) AS [Max server memory (MB)] 
					,@CPU_COUNT AS CPU_COUNT
					,(SELECT [ValorTipo] FROM ##GERAL where [NomeTipo] = ''parent_node_id'') AS Node_Id
					,(SELECT [ValorTipo] FROM ##GERAL where [NomeTipo] = ''cpu_id'') AS CPU_CONFIG
		'


SET		@SQLStrgCPUS = ''
DECLARE @Contador as INT
SET		@Contador = 0

	WHILE @Contador <  @CPU_COUNT
	BEGIN
		SET	@SQLStrgCPUS = @SQLStrgCPUS + ',ISNULL((SELECT ''X'' from sys.dm_os_schedulers where status=''VISIBLE ONLINE'' AND cpu_id = ' +  CONVERT(VARCHAR(2),@Contador) + ' ),'''') AS cpu' + RIGHT ('000000'+ CONVERT(VARCHAR(2),@Contador),2) + CHAR(13)
		SET @Contador = @Contador + 1
	END
	
	SET		@SQLStrgFim = @SQLStrgBase + CHAR(13) + @SQLStrgCPUS
	
	--PRINT 	@SQLStrgFim
	
	EXEC (@SQLStrgFim)	
	
	
	
