----SSRS_REPORTS------------
SELECT
	c.[Path] AS ReportPath
	,c.[Name] AS ReportName
	,c.CreationDate
	,c.ModifiedDate
	,d.Name AS DataSourceName
	,cd.path AS DataSourcePath
	--,CONVERT(NVARCHAR(MAX),CONVERT(XML,CONVERT(VARBINARY(MAX),c.Content))) AS REPORTXML
	,CONVERT(XML,CONVERT(VARBINARY(MAX),c.Content)) AS REPORTXML
FROM [dbo].[Catalog] (NOLOCK) c
	LEFT JOIN dbo.DataSource (NOLOCK) d ON c.ItemID = d.ItemID
	LEFT JOIN [dbo].[Catalog] (NOLOCK) cd ON d.link = cd.ItemID
WHERE 
	(c.[Type]  = 2 OR c.[Type]  = 6)
	AND LEN(c.Name) <> 0
	AND CONVERT(NVARCHAR(MAX),CONVERT(XML,CONVERT(VARBINARY(MAX),c.Content))) LIKE '%= 614%'
ORDER BY 
	ReportPath
	,ReportName
    
----REPORT_SUBSCRIPTIONS-----
SELECT 
	SUB.EventType 
	,SCH.Name AS ScheduleName 
	,CAT.[Name] AS ReportName
	,CAT.[Path] AS ReportPath 
	,CAT.[Description] AS ReportDescription 		
	,USR.UserName AS SubscriptionOwner 
	,SUB.ModifiedDate 
	,SUB.[Description] 
	,SUB.DeliveryExtension 
	,SUB.LastStatus 
	,SUB.LastRunTime 
	,SCH.NextRunTime 
FROM dbo.Subscriptions AS SUB 
INNER JOIN dbo.Users AS USR ON SUB.OwnerID = USR.UserID 
INNER JOIN dbo.[Catalog] AS CAT ON SUB.Report_OID = CAT.ItemID 
INNER JOIN dbo.ReportSchedule AS RS ON SUB.Report_OID = RS.ReportID 
	AND SUB.SubscriptionID = RS.SubscriptionID 
INNER JOIN dbo.Schedule AS SCH ON RS.ScheduleID = SCH.ScheduleID 
ORDER BY 
	ScheduleName
    ,ReportName

-----------------------Report Usage Stats---------------------
USE ReportServer
DECLARE @MinDate DATETIME = DATEADD(DAY,-60,GETDATE()) --SELECT @MinDate
SELECT 
	c.[Path] AS ReportPath
	,c.[Name] AS ReportName
	,c.[ItemID] AS ReportID
	,ISNULL(e.TotalExecutions,0) AS TotalExecutions
	,ISNULL(dt.TotalDrillThroughs,0) AS TotalDrillThroughs
	,ISNULL(f.ReportFailures,0) AS TotalReportFailures
	,ISNULL(e.AvgExecutionTime,0) / 1000.0 AS AvgExecutionSeconds
	,ISNULL(e.AvgDataRetrievalTime,0) / 1000.0 AS AvgDataRetrievalSeconds
	,ISNULL(e.AvgProcessingTime,0) / 1000.0 AS AvgProcessingSeconds
	,ISNULL(e.AvgRenderingTime,0) / 1000.0 AS AvgRenderingSeconds
	,ISNULL(e.AvgRowsReturned,0) AS AvgRowsReturned
FROM [dbo].[Catalog] (nolock) c
LEFT OUTER JOIN 
(
	SELECT ReportID
		,COUNT(*) AS TotalExecutions
		,AVG(DATEDIFF(ms,els.TimeStart,els.TimeEnd)) AS AvgExecutionTime
		,AVG(els.TimeDataRetrieval) AS AvgDataRetrievalTime
		,AVG(els.TimeProcessing) AS AvgProcessingTime
		,AVG(els.TimeRendering) AS AvgRenderingTime
		,AVG(els.[RowCount]) AS AvgRowsReturned
	FROM [dbo].[ExecutionLog2] el (NOLOCK)
		INNER JOIN [ExecutionLogStorage] els (NOLOCK) ON el.ExecutionID = els.ExecutionID
			AND el.TimeStart = els.TimeStart
	WHERE el.ReportAction = 'Render'
		AND el.[Source] = 'Live'
		AND els.TimeStart >= @MinDate
	GROUP BY els.ReportID
) e ON c.ItemID = e.ReportID
LEFT OUTER JOIN
(
	SELECT ReportID
		,COUNT(*) AS TotalDrillThroughs
	FROM [dbo].[ExecutionLog2] el (NOLOCK)
		INNER JOIN [ExecutionLogStorage] els (NOLOCK) ON el.ExecutionID = els.ExecutionID
			AND el.TimeStart = els.TimeStart
	WHERE el.ReportAction IN ('DrillThrough','Toggle')
		AND el.[Source] = 'Session'
		AND els.TimeStart >= @MinDate
	GROUP BY els.ReportID
) dt ON c.ItemID = dt.ReportID
LEFT OUTER JOIN
(
	SELECT ReportID
		,COUNT(*) AS ReportFailures
	FROM [ExecutionLogStorage] els (NOLOCK)
	WHERE els.Status <> 'rsSuccess'
		AND els.TimeStart >= @MinDate
	GROUP BY els.ReportID
) f ON c.ItemID = f.ReportID
WHERE c.[Hidden] = 0
	AND C.[Type] = 2
	--OR c.[Path] LIKE '/Production/%'
ORDER BY 
	TotalExecutions DESC