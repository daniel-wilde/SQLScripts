------------STORED PROCEDURE PERFORMANCE / EXECUTION PLAN-------------
SELECT TOP (50) --s.*, d.*, p.*
	DB_NAME(d.database_id) AS db_nm
	,s2.name + '.' + s.name AS proc_name
	,s.create_date
	,d.cached_time
	,d.last_execution_time
	,d.execution_count
	,d.Execution_Count / NULLIF(((DATEDIFF(MINUTE,d.cached_time,GETDATE())) * 1.00),0) AS freq_per_min
	,(d.total_elapsed_time / NULLIF(d.execution_count,0)) / 1000000.00 AS avg_dur_seconds
	,((d.total_elapsed_time ) / 1000000.00) / NULLIF(((DATEDIFF(MINUTE,d.cached_time,GETDATE())) * 1.00),0) AS dur_s_per_min
	,(d.total_elapsed_time ) / 1000000.00 AS total_elapsed_time_seconds
	,(d.total_worker_time / NULLIF(d.execution_count,0)) / 1000000.00 AS avg_cpu_seconds
	,(d.min_worker_time ) / 1000000.00 AS min_worker_time_seconds
	,(d.max_worker_time ) / 1000000.00 AS max_worker_time_seconds
	,d.total_physical_reads / NULLIF(d.execution_count,0) AS avg_physical_reads
	,d.total_logical_reads / NULLIF(d.execution_count,0) AS avg_logical_reads
	,d.total_logical_writes / NULLIF(d.execution_count,0) AS avg_logical_writes
	,s.[type]
	,s.modify_date
	,d.database_id
	,d.plan_handle
	,p.query_plan
FROM sys.procedures s (NOLOCK) 
INNER JOIN sys.schemas s2 (NOLOCK) ON s.schema_id = s2.schema_id
INNER JOIN sys.dm_exec_procedure_stats d (NOLOCK) ON s.object_id = d.object_id
	--AND S.Name LIKE ('%Schema%')
CROSS APPLY sys.dm_exec_query_plan(d.plan_handle) p
WHERE d.database_id = DB_ID('DBNameHere')
	--AND s2.name + '.' + s.name LIKE '%ProcName%'
	--d.Execution_Count / DATEDIFF(MINUTE,d.cached_time,GETDATE()) >= 1
ORDER BY dur_s_per_min DESC


--Update statistics TableName IndexName

--SELECT
--	db.name AS DBName
--	,s.name AS ProcName
--	,s.modify_date
--	,d.cached_time
--	,d.last_execution_time
--	,d.Execution_Count
--FROM sys.procedures s (NOLOCK) 
--	INNER JOIN sys.dm_exec_procedure_stats d (NOLOCK) ON s.object_id = d.object_id
--	INNER JOIN sys.databases db (NOLOCK) ON d.database_id = db.database_id
--ORDER BY DBName, ProcName

--DECLARE @db_name VARCHAR(50) = 'DBName'
--SELECT TOP (50)
--    DB_NAME(s.database_id) AS DBName
--    ,OBJECT_SCHEMA_NAME(object_id, s.database_id) + '.' + OBJECT_NAME(object_id, s.database_id) AS [ObjName]
--	,s.[type] AS ObjType
--	,s.cached_time
--	,s.last_execution_time
--    ,s.execution_count AS ExecutionCount
--    ,(s.total_elapsed_time / s.execution_count) / 1000000.00 AS AvgElapsedTime_seconds
--    ,(s.total_physical_reads + s.total_logical_reads) / s.execution_count AS AvgReads
--    ,H.query_plan AS QueryPlan
--    --,t.[text] AS QueryText
--FROM sys.dm_exec_procedure_stats s
--    --CROSS APPLY sys.dm_exec_sql_text(s.sql_handle) T
--    CROSS APPLY sys.dm_exec_query_plan(s.plan_handle) H
--WHERE LOWER(DB_NAME(s.database_id)) LIKE LOWER(@db_name) 
--    AND LOWER(DB_NAME (s.database_id)) NOT IN ('master','tempdb','model','msdb','resource')
--    --AND total_elapsed_time / execution_count > @avg_time_threshhold 
--ORDER BY AvgElapsedTime_seconds DESC

--------RECOMPILE STORED PROC------------------------
--EXEC sp_recompile 'Candidate.CandidateSummaryPopulate'
--EXEC sp_recompile 'Job.GetJobInProcess'
--EXEC sp_recompile 'Job.GetJobPipeline'
--EXEC sp_recompile 'Job.PopulateJobMatchAndCW'
--EXEC sp_recompile 'dbo.ServiceActiveCampaignContacts_Get'

--------CHECK REPLICA STATES------------------------

SELECT * FROM sys.dm_hadr_database_replica_states

 --------------OPEN TRANSACTIONS--------------
IF OBJECT_ID('tempdb..#sp_who2') IS NOT NULL
DROP TABLE #sp_who2
GO

CREATE TABLE #sp_who2 
(
	SPID INT
	,STATUS VARCHAR(MAX)
	,LOGIN VARCHAR(MAX)
	,HostName VARCHAR(MAX)
	,BlkBy VARCHAR(MAX)
	,DBName VARCHAR(MAX)
	,Command VARCHAR(MAX)
	,CPUTime BIGINT
	,DiskIO BIGINT
	,LastBatch VARCHAR(MAX)
	,ProgramName VARCHAR(MAX)
	,SPID_1 INT
	,REQUESTID INT
)
GO

INSERT INTO #sp_who2
EXEC sp_who2
GO

SELECT s.SPID, s.STATUS, s.LOGIN, s.HostName, s.BlkBy, s.DBName, 
	q.[Percent Complete], q.[Elapsed Min], q.SQL_STMT
FROM #sp_who2 s 
LEFT OUTER JOIN 
(
	SELECT r.session_id,r.command,r.status,CONVERT(NUMERIC(6,2),r.percent_complete)
	AS [Percent Complete],CONVERT(VARCHAR(20),DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time],
	CONVERT(NUMERIC(10,2),r.total_elapsed_time/1000.0/60.0) AS [Elapsed Min],
	CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0) AS [ETA Min],
	CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours],
	CONVERT(VARCHAR(4000),(SELECT SUBSTRING(text,r.statement_start_offset/2,
	CASE WHEN r.statement_end_offset = -1 THEN 1000 ELSE (r.statement_end_offset-r.statement_start_offset)/2 END) AS SQL_STMT
	FROM sys.dm_exec_sql_text(sql_handle))) AS SQL_STMT
	FROM sys.dm_exec_requests r 
	INNER JOIN #sp_who2 S ON R.session_id = S.SPID
) q ON s.SPID = q.session_id
--WHERE S.DBName IN ('DBName')
--ORDER BY LOGIN
ORDER BY q.[Elapsed Min] DESC
GO


SELECT r.session_id,r.command,r.status,CONVERT(NUMERIC(6,2),r.percent_complete)
AS [Percent Complete],CONVERT(VARCHAR(20),DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time],
CONVERT(NUMERIC(10,2),r.total_elapsed_time/1000.0/60.0) AS [Elapsed Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0) AS [ETA Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours],
CONVERT(VARCHAR(4000),(SELECT SUBSTRING(text,r.statement_start_offset/2,
CASE WHEN r.statement_end_offset = -1 THEN 1000 ELSE (r.statement_end_offset-r.statement_start_offset)/2 END) AS SQL_STMT
FROM sys.dm_exec_sql_text(sql_handle)))
FROM sys.dm_exec_requests r 
INNER JOIN #sp_who2 S ON R.session_id = S.SPID
--WHERE S.DBName = 'DBName'
--AND S.HostName = 'HostName'


------------OPEN TRANSACTIONS------------------
SELECT DB_NAME(dbid) AS DBNAME
	,(SELECT TEXT FROM sys.dm_exec_sql_text(sql_handle)) AS SQLSTATEMENT
	,nt_username
	,*
FROM master..sysprocesses
WHERE open_tran > 0

------------BLOCKING AND LOCKS------------------
SELECT --sp.*
sp.spid
, sp.blocked AS BlockingProcess
, DB_NAME(sp.dbid) AS DatabaseName
, sp.loginame
, CAST(text AS VARCHAR(1000)) AS SqlStatement
FROM sys.sysprocesses sp
CROSS APPLY sys.dm_exec_sql_text (sp.sql_handle)
WHERE sp.blocked <> 0
	--and spid in (52,58)
ORDER BY sp.spid

------PARALLEL THREADS:------
SELECT ost.session_id,
    ost.scheduler_id,
    w.worker_address,
    ost.task_state,
    wt.wait_type,
    wt.wait_duration_ms
FROM sys.dm_os_tasks ost
LEFT JOIN sys.dm_os_workers w ON ost.worker_address=w.worker_address
LEFT JOIN sys.dm_os_waiting_tasks wt ON w.task_address=wt.waiting_task_address
--where ost.session_id=164
ORDER BY scheduler_id;

select 
    t1.request_session_id as spid, 
    t1.resource_type as type,  
    t1.resource_database_id as dbid, 
    t1.resource_description as description,  
    t1.request_mode as mode, 
    t1.request_status as status
from sys.dm_tran_locks as t1
where t1.request_session_id = @@SPID

select 
    t1.request_session_id as spid, 
    t1.resource_type as type,  
    t1.resource_database_id as dbid, 
    t1.request_mode as mode, 
    t1.request_status as status,
     t2.blocking_session_id
from sys.dm_tran_locks as t1 
left outer join sys.dm_os_waiting_tasks as t2 ON t1.lock_owner_address = t2.resource_address
WHERE t1.request_status = 'WAIT'

SELECT db.NAME DBName
	,tl.request_session_id
	,wt.blocking_session_id
	,OBJECT_NAME(p.OBJECT_ID) BlockedObjectName
	,tl.resource_type
	,h1.TEXT AS RequestingText
	,h2.TEXT AS BlockingTest
	,tl.request_mode
FROM sys.dm_tran_locks AS tl
	INNER JOIN sys.databases db ON db.database_id = tl.resource_database_id
	INNER JOIN sys.dm_os_waiting_tasks AS wt ON tl.lock_owner_address = wt.resource_address
	INNER JOIN sys.partitions AS p ON p.hobt_id = tl.resource_associated_entity_id
	INNER JOIN sys.dm_exec_connections ec1 ON ec1.session_id = tl.request_session_id
	INNER JOIN sys.dm_exec_connections ec2 ON ec2.session_id = wt.blocking_session_id
	CROSS APPLY sys.dm_exec_sql_text(ec1.most_recent_sql_handle) AS h1
	CROSS APPLY sys.dm_exec_sql_text(ec2.most_recent_sql_handle) AS h2

-----------QUERY TO FIND DEADLOCK----------------
SELECT xed.value('@timestamp', 'datetime') AS Creation_Date
	,xed.query('.') AS Extend_Event
FROM (
	SELECT CAST([target_data] AS XML) AS Target_Data
	FROM sys.dm_xe_session_targets AS xt
	INNER JOIN sys.dm_xe_sessions AS xs ON xs.address = xt.event_session_address
	WHERE xs.NAME = N'system_health'
		AND xt.target_name = N'ring_buffer'
	) AS XML_Data
CROSS APPLY Target_Data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(xed)
ORDER BY Creation_Date DESC

-------CHECK PROGRESS OF A PROCESS------------------
SELECT r.session_id,r.command,r.status,CONVERT(NUMERIC(6,2),r.percent_complete)
AS [Percent Complete],CONVERT(VARCHAR(20),DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time],
CONVERT(NUMERIC(10,2),r.total_elapsed_time/1000.0/60.0) AS [Elapsed Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0) AS [ETA Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours],
CONVERT(VARCHAR(1000),(SELECT SUBSTRING(text,r.statement_start_offset/2,
CASE WHEN r.statement_end_offset = -1 THEN 1000 ELSE (r.statement_end_offset-r.statement_start_offset)/2 END) AS SQL_STMT
FROM sys.dm_exec_sql_text(sql_handle)))
FROM sys.dm_exec_requests r 
--WHERE session_id = 145
WHERE Command LIKE ('%DbccFilesCompact%')
	--OR Command LIKE ('%update%')
	--OR Command LIKE ('%BACKUP%') --('CREATE INDEX','RESTORE DATABASE','BACKUP DATABASE','DBCC TABLE CHECK'); LIKE ('%DBCC%');
GO

SELECT cpu_time
	,last_wait_type
	,reads
	,writes
	,logical_reads
	,blocking_session_id
	,*
FROM sys.dm_exec_requests
WHERE session_id = 84

 -----------TOP 20 TRANSACTIONS------------------------
SELECT TOP 100 obj.name, max_logical_reads, max_elapsed_time
FROM sys.dm_exec_query_stats a
CROSS APPLY sys.dm_exec_sql_text(sql_handle) hnd
INNER JOIN sys.sysobjects obj on hnd.objectid = obj.id
ORDER BY max_logical_reads DESC

SELECT TOP 100 total_worker_time / execution_count AS Avg_CPU_Time
	,execution_count
	,total_elapsed_time / execution_count AS AVG_Run_Time
	,(
		SELECT SUBSTRING(TEXT, statement_start_offset / 2, (
					CASE 
						WHEN statement_end_offset = - 1
							THEN LEN(CONVERT(NVARCHAR(max), TEXT)) * 2
						ELSE statement_end_offset
						END - statement_start_offset
					) / 2)
		FROM sys.dm_exec_sql_text(sql_handle)
		) AS query_text
	,st.*
FROM sys.dm_exec_query_stats st
ORDER BY AVG_Run_Time DESC


SELECT * FROM sys.dm_exec_query_stats
 -----------MISSING INDEXES------------------------
SELECT 
	[statement] AS [database.scheme.table]
	,column_id
	,column_name
	,column_usage
	,migs.user_seeks
	,migs.user_scans
	,migs.last_user_seek
	,migs.avg_total_user_cost
	,migs.avg_user_impact
FROM sys.dm_db_missing_index_details AS mid
CROSS APPLY sys.dm_db_missing_index_columns(mid.index_handle)
INNER JOIN sys.dm_db_missing_index_groups AS mig ON mig.index_handle = mid.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats AS migs ON mig.index_group_handle = migs.group_handle
WHERE [statement] LIKE '%stmt%'
--or [statement] LIKE '%SensorCentral]%'
ORDER BY mig.index_group_handle
	,mig.index_handle
	,column_id

------CREATE INDEXES
SELECT
  migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,
  'CREATE INDEX [missing_index_' + CONVERT (varchar, mig.index_group_handle) + '_' + CONVERT (varchar, mid.index_handle)
  + '_' + LEFT (PARSENAME(mid.statement, 1), 32) + ']'
  + ' ON ' + mid.statement
  + ' (' + ISNULL (mid.equality_columns,'')
    + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END
    + ISNULL (mid.inequality_columns, '')
  + ')'
  + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,
  migs.*, mid.database_id, mid.[object_id]
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC

----------INDEX FRAGMENTATION---------
SELECT OBJECT_NAME(ind.OBJECT_ID) AS TableName, 
ind.name AS IndexName, indexstats.index_type_desc AS IndexType, 
indexstats.avg_fragmentation_in_percent 
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats 
INNER JOIN sys.indexes ind  
ON ind.object_id = indexstats.object_id 
AND ind.index_id = indexstats.index_id 
WHERE Object_name(ind.object_id) = 'dbo.proc_name'
	--AND indexstats.avg_fragmentation_in_percent > 30 
ORDER BY indexstats.avg_fragmentation_in_percent DESC 

sp_spaceused 'DimSensor'
DBCC DBREINDEX ('DimSensor')


----------INDEX USAGE---------
USE DBName
SELECT
	SCHEMA_NAME(o.schema_id) + '.' + OBJECT_NAME(S.[object_id]) AS [OBJECT NAME]
	,DB_NAME(S.database_id) AS [DATABASE]
	,I.[name] AS [INDEX NAME]
	,I.type_desc
	,I.is_unique
	,user_seeks
	,user_scans
	,user_lookups
	,user_updates
FROM
	sys.dm_db_index_usage_stats AS S
	INNER JOIN sys.indexes AS I ON I.[object_id] = S.[object_id]
									AND I.index_id = S.index_id
	INNER JOIN sys.objects o ON o.object_id = S.object_id
WHERE
	OBJECTPROPERTY(S.[object_id], 'IsUserTable') = 1 
	AND DB_NAME(S.database_id) = 'DBName'
	AND OBJECT_NAME(S.[object_id]) LIKE '%Employment%'
	--AND I.Name IN ('')
	--AND I.type_desc NOT IN ('CLUSTERED')
	--AND s.user_seeks = 0
	--AND s.user_scans = 0
ORDER BY [OBJECT NAME]

----------INDEX OPERATIONAL STATS---------
SELECT OBJECT_NAME(A.[OBJECT_ID]) AS [OBJECT NAME], 
       I.[NAME] AS [INDEX NAME], 
       A.LEAF_INSERT_COUNT, 
       A.LEAF_UPDATE_COUNT, 
       A.LEAF_DELETE_COUNT 
FROM   SYS.DM_DB_INDEX_OPERATIONAL_STATS (NULL,NULL,NULL,NULL ) A 
       INNER JOIN SYS.INDEXES AS I 
         ON I.[OBJECT_ID] = A.[OBJECT_ID] 
            AND I.INDEX_ID = A.INDEX_ID 
WHERE I.Name IN ('')
	AND OBJECTPROPERTY(A.[OBJECT_ID],'IsUserTable') = 1

------------IO WAIT STATS-------------
SELECT db.name, sf.name, vs.*--
FROM sys.dm_io_virtual_file_stats (DB_ID(), NULL) vs
	INNER JOIN sys.databases db ON vs.database_id = vs.database_id
	INNER JOIN sys.sysfiles sf ON vs.file_id = sf.fileid
WHERE db.Name = 'D'
ORDER BY vs.io_stall DESC
GO

SELECT TOP 100
    DB_NAME ([vfs].[database_id]) AS [DB],
    [mf].[physical_name],
    --LEFT ([mf].[physical_name], 2) AS [Drive],
	[ReadLatency] = CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
    [WriteLatency] = CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
    [Latency] = CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
    [AvgBPerRead] = CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
    [AvgBPerWrite] = CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
    [AvgBPerTransfer] = CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            THEN 0 ELSE
                (([num_of_bytes_read] + [num_of_bytes_written]) /
                ([num_of_reads] + [num_of_writes])) END
FROM sys.dm_io_virtual_file_stats (DB_ID(),NULL) AS [vfs]
	INNER JOIN sys.master_files AS [mf] ON [vfs].[database_id] = [mf].[database_id]
		AND [vfs].[file_id] = [mf].[file_id]
ORDER BY [ReadLatency] DESC
GO

----------BACKUP HISTORY------------------------------------
SELECT TOP 10
	s.database_name
	,m.physical_device_name
	,m.*
	,CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS bkSize
	,CAST(DATEDIFF(SECOND, s.backup_start_date, s.backup_finish_date) AS VARCHAR(4))
	+ ' ' + 'Seconds' TimeTaken
	,s.backup_start_date
	,CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn
	,CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn
	,CASE s.[type]
		WHEN 'D' THEN 'Full'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Transaction Log'
		END AS BackupType
	,s.server_name
	,s.recovery_model
FROM
	msdb.dbo.backupset s
	INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
WHERE
	s.database_name = DB_NAME() -- Remove this line for all the database
	AND s.[Type] = 'D'
ORDER BY
	backup_start_date DESC
	,backup_finish_date

----------SQL AGENT JOBS HISTORY----------------------------

--SELECT * FROM msdb..sysjobs
--SELECT * FROM msdb..sysjobsteps
--SELECT * FROM msdb..sysjobhistory

SELECT 
	job_name
	,step_name
	,job_id
	,step_id
	,run_datetime
	,run_duration
FROM 
(
	SELECT 
		job_id
		,step_id
		,job_name
		,step_name
		,run_datetime
		,SUBSTRING(run_duration, 1, 2) + ':' + SUBSTRING(run_duration, 3, 2) + ':' + SUBSTRING(run_duration, 5, 2) AS run_duration
	FROM 
	(
		SELECT DISTINCT 
			j.job_id
			,js.step_id
			,j.NAME AS job_name
			,js.step_name
			,run_datetime = CONVERT(DATETIME, RTRIM(run_date)) + (run_time * 9 + run_time % 10000 * 6 + run_time % 100 * 10) / 216e4
			,run_duration = RIGHT('000000' + CONVERT(VARCHAR(6), run_duration), 6)
		FROM msdb..sysjobhistory h
		INNER JOIN msdb..sysjobs j ON h.job_id = j.job_id
		INNER JOIN msdb..sysjobsteps js ON h.job_id = js.job_id
			AND h.step_id = js.step_id
	) t
) t
ORDER BY run_datetime DESC
	,step_id DESC
	,job_name

----------SSISDB EXECUTION HISTORY---------------

DECLARE @BeginTime DATETIME, @EndTime DATETIME

SELECT @EndTime = '7/23/16'
SELECT @BeginTime = DATEADD(DAY,-1,@EndTime)

--EXECUTION HISTORY AT THE SSIS Package Level:
SELECT execution_id AS Audit_Key
	,folder_name
	,project_name
	,package_name
	,environment_folder_name
	,environment_name
	,server_name
	,caller_name
	,stopped_by_name
	,start_time
	,end_time
	,CASE [status]
		WHEN 1 THEN 'Created'
		WHEN 2 THEN 'Running'
		WHEN 3 THEN 'Canceled'
		WHEN 4 THEN 'Failed'
		WHEN 5 THEN 'Pending'
		WHEN 6 THEN 'Ended unexpectedly'
		WHEN 7 THEN 'Succeeded'
		WHEN 8 THEN 'Stopping'
		WHEN 9 THEN 'Completed'
		ELSE 'Error'
	 END AS [Status]
FROM [SSISDB].[catalog].[executions]
WHERE start_time BETWEEN @BeginTime AND @EndTime
--	AND package_name LIKE '%coder%'
ORDER BY start_time DESC

-----------------------------------------------------------------------------

--EXECUTION DETAILS:
SELECT ce.execution_id AS Audit_Key
	,ce.server_name AS server_nm
	,ce.folder_name AS folder
	,ce.project_name AS project
	,ce.environment_folder_name AS env_folder
	,ce.environment_name AS environment
	,ce.package_name AS main_pkg
	,EM.Package_Name AS event_pkg
	,EM.Package_Path AS pkg_path
	,EM.Execution_Path AS execution_path
	,ce.caller_name AS caller_nm
	,ce.stopped_by_name AS stopped_by
	,ce.start_time AS pkg_start_time
	,ce.end_time AS pkg_end_time
	,CONVERT(DATETIME, O.start_time) AS oper_start_time
	,CONVERT(DATETIME, O.end_time) AS oper_end_time
	,OM.message_time
	,O.Operation_Id
	,OM.operation_message_id
	,EM.Event_Name
	,EM.Message_Source_Name AS Component_Name
	,EM.Subcomponent_Name AS Sub_Component_Name
	,OM.message AS [Error_Message]
FROM [SSISDB].[catalog].[executions] ce
	INNER JOIN [SSISDB].[internal].[operations] AS O ON ce.execution_id = O.operation_id
	INNER JOIN [SSISDB].[internal].[operation_messages] AS OM ON OM.Operation_id = ce.EXECUTION_ID
	INNER JOIN [SSISDB].[internal].[event_messages] AS EM ON EM.operation_id = OM.operation_id
		AND OM.operation_message_id = EM.event_message_id
WHERE ce.start_time BETWEEN @BeginTime AND @EndTime
	--AND OM.Message_Type = 120 -- 120 means Error 
	--AND EM.event_name = 'OnError'
ORDER BY OM.operation_message_id DESC

-----------------------------------------------------------------------------

----------SERVER INFO----------------------------
SELECT * FROM sys.dm_os_sys_info

------------QUERY PERFORMANCE / EXECUTION PLAN-------------
USE CAC_DW
SELECT t.text, t20.*, p.query_plan
FROM 
(
	SELECT TOP 20
		((q.total_elapsed_time / NULLIF(q.execution_count,0)) / 1000000.00) 
		* (q.Execution_Count / NULLIF(DATEDIFF(MINUTE,q.creation_time,GETDATE()),0)) AS DurationPerMinute
		, *
	FROM sys.dm_exec_query_stats q
	WHERE Execution_Count > 0
	ORDER BY DurationPerMinute DESC
) t20
CROSS APPLY sys.dm_exec_query_plan(t20.plan_handle) p
CROSS APPLY sys.dm_exec_sql_text(t20.sql_handle) t
ORDER BY t20.DurationPerMinute DESC

--------CHECK STATS UPDATED--------------------------
SELECT OBJECT_NAME(object_id) AS [ObjectName]
	,[name] AS [StatisticName]
	,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats
WHERE OBJECT_NAME(object_id) LIKE '%%'
ORDER BY STATS_DATE([object_id], [stats_id]) DESC -- Tablename 

--------UPDATE STATISTICS----------------------------
--UPDATE STATISTICS 
--UPDATE STATISTICS 

-----------FIND THE SIZE OF AN IDEX--------------------
SELECT i.[name] AS IndexName
    ,SUM(s.[used_page_count]) * 8 AS IndexSizeKB
FROM sys.dm_db_partition_stats AS s
INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
    AND s.[index_id] = i.[index_id]
WHERE i.[name] = ''
GROUP BY i.[name]
ORDER BY i.[name]

-----------DB FILE STATS-------------------
SELECT RTRIM(name) AS [Segment Name], groupid AS [Group ID], filename AS [File Name],
	CAST(size/128.0 AS DECIMAL(14,2)) AS [Allocated Size in MB],
	CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(14,2)) AS [Space Used in MB]
FROM sysfiles
ORDER BY groupid DESC

----------WAIT STATISTICS----------
SELECT 
	r.session_id
	,r.start_time
	,r.command
	,r.blocking_session_id
	,r.status
	,r.wait_type
	,r.wait_time
	,r.last_wait_type
	,r.wait_resource
	,r.cpu_time
	,r.total_elapsed_time
	,r.reads
	,r.writes
	,r.logical_reads
	,t.text
FROM sys.dm_exec_requests r
	CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id > 0
--WHERE command LIKE N'INSERT';


----IO_WAITS and FRAGMENTATION----
WITH io_waits 
(
	[DATABASE]
	,ObjectID
	,ObjectName
	,IndexName
	,Partition_Name
	,partition_number
	--,IndexType
	,[PageLatchWaitCount]
	,[PageIOLatchWaitCount]
	,[PageIOLatchWaitInMilliseconds]
)
AS
(
	--PHYSICAL I/O
	SELECT TOP 20
		DB_NAME([database_id]) AS [Database]
		,iops.[object_id] AS [ObjectID]
		,QUOTENAME(OBJECT_SCHEMA_NAME(iops.[object_id], [database_id])) + N'.' + QUOTENAME(OBJECT_NAME(iops.[object_id], [database_id])) AS [ObjectName]
		,i.[name] AS [IndexName]
		,fg.Name AS Partition_Name
		,iops.partition_number
		--,CASE
		--	WHEN i.[is_unique] = 1
		--		THEN 'UNIQUE '
		--	ELSE ''
		--	END + i.[type_desc] AS [IndexType]
		,iops.[page_latch_wait_count] AS [PageLatchWaitCount]
		,iops.[page_io_latch_wait_count] AS [PageIOLatchWaitCount]
		,iops.[page_io_latch_wait_in_ms] AS [PageIOLatchWaitInMilliseconds]
	FROM [sys].[dm_db_index_operational_stats](DB_ID(), NULL, NULL, NULL) iops
		INNER JOIN [sys].[indexes] i ON i.[object_id] = iops.[object_id]
			AND i.[index_id] = iops.[index_id]
		INNER JOIN sys.partitions p ON p.object_id = i.object_id
			AND p.index_id = i.index_id
			AND p.partition_number = iops.partition_number
		INNER JOIN sys.objects o ON p.object_id = o.object_id
		INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
		INNER JOIN sys.partition_functions f ON f.function_id = ps.function_id
		INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
			AND dds.destination_id = p.partition_number
		INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
	ORDER BY (iops.[page_latch_wait_count] + iops.[page_io_latch_wait_count]) DESC
) 
SELECT 
	io_waits.*
	--,p.partition_number
	,index_stats.alloc_unit_type_desc
	--,index_stats.index_depth
	,index_stats.avg_fragmentation_in_percent
	,index_stats.fragment_count
	,index_stats.avg_fragment_size_in_pages
	,index_stats.page_count
FROM [sys].[indexes] i 
	INNER JOIN sys.partitions p ON p.object_id = i.object_id
		AND p.index_id = i.index_id
	INNER JOIN io_waits ON p.partition_number = io_waits.partition_number
	INNER JOIN sys.objects o ON p.object_id = o.object_id
	INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
	INNER JOIN sys.partition_functions f ON f.function_id = ps.function_id
	INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
		AND dds.destination_id = p.partition_number
	INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
	CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(),o.object_id,i.index_id,p.partition_number,NULL) index_stats
WHERE index_stats.alloc_unit_type_desc = 'IN_ROW_DATA'
	AND io_waits.objectID = o.object_id
ORDER BY (io_waits.[PageLatchWaitCount] + io_waits.[PageIOLatchWaitCount]) DESC

DECLARE @DBID INT = DB_ID()
------------------------------------------------------------------------------------
-- Index Usage Data
------------------------------------------------------------------------------------
SELECT 
       ISNULL(OBJECT_NAME(s.[object_id], @DBID), 'N/A') AS [Table] 
       , s.[object_id]
       , f.name
       , CASE 
              WHEN s.index_id=0 THEN 'HEAP'
              WHEN s.index_id=1 THEN 'CLUSTERED INDEX'
              ELSE 'UNCLUSTERED INDEX'
         END [Type]
       --, ISNULL(f.SizeMB, -1) [SizeMB]
       --, ISNULL(f.Rows, -1) [Rows]
       , s.index_id 
       , user_seeks
       , user_scans
       , user_lookups 
       , user_updates AS [Writes] 
       , CAST(ISNULL([last_user_seek], '') as varchar(30)) [last_user_seek]
       , CAST(ISNULL([last_user_scan], '') as varchar(30)) [last_user_scan]
--     , CAST (f.avg_fragmentation_in_percent as decimal (4,1)) [Frag %]
       , DB_Name (@DBID) [DB Name]
INTO #IndexStats
FROM sys.dm_db_index_usage_stats AS s 
LEFT JOIN sys.indexes f ON f.[object_id] = s.[object_id] AND f.index_id = s.index_id 
--     INNER JOIN (SELECT object_id, index_id, page_count, avg_fragmentation_in_percent FROM sys.dm_db_index_physical_stats (@DBID, NULL, NULL, NULL, NULL)) f ON f.[object_id] = s.[object_id] AND f.index_id = s.index_id 
       --LEFT JOIN (SELECT object_id, index_id, SUM(row_count) AS Rows, CONVERT(numeric(19,0), CONVERT(numeric(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(numeric(19,3), 128)) AS SizeMB
       --            FROM sys.dm_db_partition_stats GROUP BY object_id, index_id) f ON f.[object_id] = s.[object_id] AND f.index_id = s.index_id 
WHERE s.database_id = @DBID

------------------------------------------------------------------------------------
-- Missing Index Data
------------------------------------------------------------------------------------
SELECT  
    CAST((user_seeks+user_scans) * avg_total_user_cost * (avg_user_impact * 0.01) as bigint) [Benefit], 
    object_name(d.object_id, @DBID) [Table], 
    '=: ' + isnull(d.equality_columns, 'n/a') + '  -- <>: ' + isnull(d.inequality_columns, 'n/a') [Columns],
    isnull(d.included_columns, 'n/a') [Incl Columns],
    gs.unique_compiles [Compiles],
    gs.user_seeks [Seeks],
    gs.user_scans [Scans],
    CAST(gs.avg_user_impact as int) [Usr Impact],
    gs.last_user_seek [Last Seek]
INTO #tmpMissingIndex
FROM  sys.dm_db_missing_index_groups g
    join sys.dm_db_missing_index_group_stats gs    on gs.group_handle = g.index_group_handle
    join sys.dm_db_missing_index_details d         on g.index_handle = d.index_handle
WHERE  d.database_id             = @DBID

------------------------------------------------------------------------------------
-- Missing Indexes (within 1 hour)
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #tmpMissingIndex WHERE [Last Seek] >= DATEADD (HOUR, -1, getdate()))
    SELECT 'Index Stats - Top 10 Missing Indexes (within 1 hour)' AS '$$', 'N/A' [Data] --FOR XML RAW
ELSE
    SELECT TOP 10 'Index Stats - Top 10 Missing Indexes (within 1 hour)' AS '$$', *
    FROM #tmpMissingIndex 
    WHERE [Last Seek] >= DATEADD (HOUR, -1, getdate())
    ORDER BY [Benefit] DESC
    --FOR XML RAW
     
------------------------------------------------------------------------------------
-- Missing Indexes (within 1 day)
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #tmpMissingIndex WHERE  [Last Seek] < DATEADD (HOUR, -1, getdate()) AND [Last Seek] >= DATEADD (DAY, -1, getdate()))
    SELECT 'Index Stats - Top 10 Missing Indexes (within 1 day)' AS '$$', 'N/A' [Data] --FOR XML RAW
ELSE
    SELECT TOP 10 'Index Stats - Top 10 Missing Indexes (within 1 day)' AS '$$', *
    FROM #tmpMissingIndex 
    WHERE  [Last Seek] < DATEADD (HOUR, -1, getdate()) AND [Last Seek] >= DATEADD (DAY, -1, getdate())
    ORDER BY [Benefit] DESC
    --FOR XML RAW
     
------------------------------------------------------------------------------------
-- Missing Indexes (older than 1 day)
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #tmpMissingIndex WHERE [Last Seek] < DATEADD (DAY, -1, getdate()))
    SELECT 'Index Stats - Top 10 Missing Indexes (older than 1 day)' AS '$$', 'N/A' [Data]  --FOR XML RAW
ELSE
    SELECT TOP 10 'Index Stats - Top 10 Missing Indexes (older than 1 day)' AS '$$', *
    FROM #tmpMissingIndex 
    WHERE [Last Seek] < DATEADD (DAY, -1, getdate())
    ORDER BY [Benefit] DESC
    --FOR XML RAW
    

   SELECT --qt.text [SP Name]
              s.name [SP Name]
              , LTRIM(LEFT(SUBSTRING(qt.text,qs.statement_start_offset/2, (case    when qs.statement_end_offset = -1 then len(convert(nvarchar(max), qt.text)) * 2 else qs.statement_end_offset end - qs.statement_start_offset)/2),200)) AS Query_Text
        , qs.creation_time [Creation Time]
        , qs.execution_count [Execution Count]
              , qs.execution_count/CASE WHEN DATEDIFF(Second, qs.creation_time, GetDate())=0 THEN 1 ELSE DATEDIFF(Second, qs.creation_time, GetDate()) END [Calls/Second]
        , qs.total_worker_time/1000 [total_worker_time]
        , qs.total_worker_time/1000/CASE WHEN qs.execution_count=0 THEN 1 ELSE qs.execution_count END [AvgWorkerTime]
        , qs.total_elapsed_time/1000 [total_elapsed_time]
        , qs.total_elapsed_time/1000/CASE WHEN qs.execution_count=0 THEN 1 ELSE qs.execution_count END AS 'AvgElapsedTime'
        , qs.total_physical_reads
        , qs.total_physical_reads/CASE WHEN qs.execution_count=0 THEN 1 ELSE qs.execution_count END AS 'AvgPhysicalReads'
        , qs.total_logical_writes
        , qs.total_logical_writes/CASE WHEN qs.execution_count=0 THEN 1 ELSE qs.execution_count END AS 'AvgLogicalWrites'
        , qs.total_logical_reads
        , qs.total_logical_reads/CASE WHEN qs.execution_count=0 THEN 1 ELSE qs.execution_count END AS 'AvgLogicalReads'
        , qs.max_logical_reads
        , qs.max_logical_writes 
        , qs.total_logical_writes/CASE WHEN DATEDIFF(Minute, qs.creation_time, GetDate())=0 THEN 1 ELSE DATEDIFF(Minute, qs.creation_time, GetDate()) END AS 'Logical Writes/Min'
        , DATEDIFF(Minute, qs.creation_time, GetDate()) AS 'Age in Cache'
              INTO #tmp1
       FROM sys.dm_exec_query_stats AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
              JOIN sys.objects s ON qt.objectid=s.object_id
    WHERE qt.dbid = @DBID

    UPDATE #tmp1 SET [SP Name] = REPLACE ([SP Name], '[', '')
    UPDATE #tmp1 SET [SP Name] = REPLACE ([SP Name], ']', '')
    UPDATE #tmp1 SET [SP Name] = REPLACE ([SP Name], 'dbo.', '')
    UPDATE #tmp1 SET Query_Text = REPLACE (LTRIM(Query_Text), CHAR(10), '')
    UPDATE #tmp1 SET Query_Text = REPLACE (RTRIM(Query_Text), CHAR(13), '')
    UPDATE #tmp1 SET Query_Text = REPLACE (Query_Text, ' ', '_')
       DELETE FROM #tmp1 WHERE [SP Name] IS  NULL


       DECLARE @SumLR float, @TWT float, @TPR float
       SELECT @SumLR = SUM([total_logical_reads]) FROM #tmp1
       SELECT @TWT = SUM([total_worker_time]) FROM #tmp1
       SELECT @TPR = SUM([total_physical_reads]) FROM #tmp1

------------------------------------------------------------------------------------
-- Top SPs by locical reads
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #tmp1)
    SELECT 'Query Stats - Top 10 Logical Reads' AS '$$', 'N/A' [Data]  --FOR XML RAW
ELSE
       SELECT TOP 10 
              'Query Stats - Top 10 Logical Reads' AS '$$', 
              [SP Name], 
        [Execution Count],
        [total_logical_reads],
        CAST(CAST([total_logical_reads] as float) / @SumLR *100 as decimal(5,1)) [% of Total],
              [Query_Text]
    FROM #tmp1 
    ORDER BY 5 DESC
    --FOR XML RAW

------------------------------------------------------------------------------------
-- Top SPs by CPU worker time
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #tmp1)
    SELECT 'Query Stats - Top 10 Worker Time' AS '$$', 'N/A' [Data]  --FOR XML RAW
ELSE
       SELECT TOP 10 
              'Query Stats - Top 10 Worker Time' AS '$$', 
              [SP Name], 
        [Execution Count],
        [total_worker_time],
        CAST(CAST([total_worker_time] as float) / CASE WHEN @TWT=0 THEN 1 ELSE @TWT END *100 as decimal(5,1))[% of Total],
              [Query_Text]
    FROM #tmp1 
    ORDER BY 5 DESC
    --FOR XML RAW
     
------------------------------------------------------------------------------------
-- Top SPs by physical reads
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #tmp1)
    SELECT 'Query Stats - Top 10 Physical Reads' AS '$$', 'N/A' [Data]  --FOR XML RAW
ELSE
       SELECT TOP 10 
              'Query Stats - Top 10 Physical Reads' AS '$$', 
              [SP Name], 
        [Execution Count],
        [total_physical_reads],
        CAST(CAST([total_physical_reads] as float) / CASE WHEN @TPR=0 THEN 1 ELSE @TPR END *100 as decimal(5,1))[% of Total],
              [Query_Text]
    FROM #tmp1 
    ORDER BY 5 DESC
    --FOR XML RAW
     
------------------------------------------------------------------------------------
-- Unused Indexes - consider deleting them if not the cluster
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #IndexStats WHERE (user_seeks + user_scans + user_lookups)=0)
    SELECT 'Index Stats - Unused Indexes' AS '$$', 'N/A' [Data]  --FOR XML RAW
ELSE
    SELECT 'Index Stats - Unused Indexes' AS '$$', *
    FROM #IndexStats 
    WHERE (user_seeks + user_scans + user_lookups)=0
    ORDER BY [Table]
    --FOR XML RAW

------------------------------------------------------------------------------------
-- No Index Seek in last 7 days - consider deleting them if not the cluster
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #IndexStats WHERE (last_user_seek IS NULL) OR (DATEADD(DAY, 7, last_user_seek) < getdate()))
    SELECT 'Index Stats - No Index Seek in last 7 days' AS '$$', 'N/A' [Data]  --FOR XML RAW
ELSE
    SELECT 'Index Stats - No Index Seek in last 7 days' AS '$$', *
    FROM #IndexStats 
    WHERE (last_user_seek IS NULL) OR (DATEADD(DAY, 7, last_user_seek) < getdate())
    ORDER BY [Table]
    --FOR XML RAW

------------------------------------------------------------------------------------
-- Index Stats
------------------------------------------------------------------------------------
--IF NOT EXISTS (SELECT 1 FROM #IndexStats)
--    SELECT 'Index Stats - All Stats' AS '$$', 'N/A' [Data] -- FOR XML RAW
--ELSE
--    SELECT 'Index Stats - All Stats' AS '$$', *
--    FROM #IndexStats 
--    ORDER BY [Table]
    -- FOR XML RAW
   
	DROP TABLE #IndexStats
	DROP TABLE #tmpMissingIndex
	DROP TABLE #tmp1 

---------------------------VIEW LOG FILE------------------------------------

SET NOCOUNT ON
DECLARE @LSN NVARCHAR(46)
DECLARE @LSN_HEX NVARCHAR(25)
DECLARE @tbl TABLE (id INT identity(1,1), i VARCHAR(10))
DECLARE @stmt VARCHAR(256)

SET @LSN = (SELECT TOP 1 [Current LSN] FROM fn_dblog(NULL, NULL))
PRINT @LSN

SET @stmt = 'SELECT CAST(0x' + SUBSTRING(@LSN, 1, 8) + ' AS INT)'
INSERT @tbl EXEC(@stmt)
SET @stmt = 'SELECT CAST(0x' + SUBSTRING(@LSN, 10, 8) + ' AS INT)'
INSERT @tbl EXEC(@stmt)
SET @stmt = 'SELECT CAST(0x' + SUBSTRING(@LSN, 19, 4) + ' AS INT)'
INSERT @tbl EXEC(@stmt)

SET @LSN_HEX =
(SELECT i FROM @tbl WHERE id = 1) + ':' + (SELECT i FROM @tbl WHERE id = 2) + ':' + (SELECT i FROM @tbl WHERE id = 3)
PRINT @LSN_HEX

SELECT [Current LSN], [Operation], [Context], [Transaction ID], [AllocUnitName], [Begin Time], [Page ID], [Transaction Name], [Parent Transaction ID], [Description] 
FROM ::fn_dblog(@LSN_HEX, NULL)
WHERE [Begin Time] IS NOT NULL
	OR [AllocUnitName] IS NOT NULL
ORDER BY [Begin Time] DESC