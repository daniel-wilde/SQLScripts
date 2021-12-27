USE SSISDB

DECLARE @ExecutionIDS TABLE (ExecutionID INT) --123456

INSERT INTO @ExecutionIDS (ExecutionID)
SELECT TOP 10 ce.execution_id --, * 
FROM [SSISDB].[catalog].[executions] ce (NOLOCK)  
WHERE ce.project_name = '<ProjectName>'
	--AND ce.status NOT IN (4,7)
	--AND ce.execution_id = 123456
ORDER BY ce.execution_id DESC

-----------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#SSISExecutions') IS NOT NULL
BEGIN
	DROP TABLE #SSISExecutions
END

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
INTO #SSISExecutions
FROM [SSISDB].[catalog].[executions] ce (NOLOCK) 
	LEFT OUTER JOIN [SSISDB].[internal].[operations] AS O (NOLOCK) ON ce.execution_id = O.operation_id
	LEFT OUTER JOIN [SSISDB].[internal].[operation_messages] AS OM (NOLOCK) ON OM.Operation_id = ce.EXECUTION_ID
	LEFT OUTER JOIN [SSISDB].[internal].[event_messages] AS EM (NOLOCK) ON EM.operation_id = OM.operation_id
		AND OM.operation_message_id = EM.event_message_id
WHERE 
	ce.execution_id IN (SELECT ExecutionID from @ExecutionIDs)
	--ce.start_time BETWEEN @BeginTime AND @EndTime
	--AND ce.package_name LIKE '%%'
	--AND ce.status = 4 --Failed
	--AND OM.Message_Type = 120 -- 120 means Error 
	--AND EM.event_name = 'OnError'
ORDER BY OM.operation_message_id DESC


SELECT TOP 10000 se.message_time AS MsgTime
	,se.Error_Message
	,*
FROM #SSISExecutions se
WHERE 
	se.Error_Message LIKE '%Error%'
	AND NOT se.event_pkg LIKE '%Error%'
	AND NOT se.execution_path LIKE '%Error%'
	--se.Audit_Key = 123456 --
	--AND se.Event_Name = 'OnPostExecute'
ORDER BY se.message_time asc
--ORDER BY se.execution_path asc
--ORDER BY se.Audit_Key DESC, se.operation_message_id DESC

--SELECT COUNT(*) FROM #SSISExecutions
--SELECT * FROM #SSISExecutions

-----------------------------------------------------------------------------
