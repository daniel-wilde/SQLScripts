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
--WHERE S.DBName IN ('---')
--ORDER BY LOGIN
ORDER BY q.[Elapsed Min] DESC
GO

----------------------------------------------

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
--WHERE S.DBName = '------'
--AND S.HostName = '------'

----------------------------------------------

SELECT DB_NAME(dbid) AS DBNAME
	,(SELECT TEXT FROM sys.dm_exec_sql_text(sql_handle)) AS SQLSTATEMENT
	,nt_username
	,*
FROM master..sysprocesses
WHERE open_tran > 0

------------BLOCKING AND LOCKS------------------

USE MASTER
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

select ost.session_id,
    ost.scheduler_id,
    w.worker_address,
    ost.task_state,
    wt.wait_type,
    wt.wait_duration_ms
from sys.dm_os_tasks ost
left join sys.dm_os_workers w on ost.worker_address=w.worker_address
left join sys.dm_os_waiting_tasks wt on w.task_address=wt.waiting_task_address
--where ost.session_id=164
order by scheduler_id;

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
