----SQL_JOBS_AND_STEPS-------
SELECT 
	job.name AS JobName
	,job.Description AS JobDescription
	,stp.step_id AS StepID
	,stp.step_name AS StepName
	,ss.name AS ScheduleName
	,sjc.next_run_date
	,sjc.next_run_time
	,stp.on_success_action AS OnSuccessAction
	,stp.on_fail_action AS OnFailAction
	,stp.output_file_name AS OutputFileName
	,stp.database_name AS DatabaseName
	,CASE ss.freq_type 
		WHEN 1 THEN 'One Time'
		WHEN 4 THEN 'Daily'
		WHEN 8 THEN 'Weekly'
		WHEN 16 THEN 'Monthly'
		WHEN 32 THEN 'Monthly - relative'
		WHEN 64 THEN 'When Agent Starts'
		WHEN 128 THEN 'When Computer is idle' 
		ELSE 'Invalid' 
	 END FreqType	
	,CASE job.enabled 
		WHEN 1 THEN 'Enabled' 
		ELSE 'Disabled' 
	 END [Enabled]
	,stp.subsystem AS SubSystem
	,stp.command AS Command
	,stp.last_run_date AS LastRunDate
	,stp.last_run_time AS LastRunTime
	,stp.last_run_duration AS LastRunDuration
	,CASE stp.last_run_outcome 
		WHEN 1 THEN 'Success'
		ELSE 'Fail'
	 END AS LastRunOutcome
FROM msdb..sysjobs job 
	LEFT OUTER JOIN msdb..sysjobsteps stp ON job.job_id = stp.job_id
	LEFT OUTER JOIN msdb..sysjobschedules sjc ON job.job_id = sjc.job_id
	LEFT OUTER JOIN msdb..sysschedules ss ON sjc.schedule_id = ss.schedule_id
WHERE  job.enabled = 1
	AND sjc.next_run_date BETWEEN CAST(CONVERT(varchar(8), GETDATE(), 112) AS INT) AND CAST(CONVERT(varchar(8), DATEADD(DAY,1,GETDATE()), 112) AS INT)
ORDER BY 
	sjc.next_run_date
	,sjc.next_run_time
	,JobName
	,StepID


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