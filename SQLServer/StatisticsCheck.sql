--------CHECK STATS UPDATED--------------------------
SELECT OBJECT_NAME(object_id) AS [ObjectName]
	,[name] AS [StatisticName]
	,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats
WHERE OBJECT_NAME(object_id) LIKE '%%'
ORDER BY STATS_DATE([object_id], [stats_id]) DESC -- Tablename 

---------------------------------UpdateStatisticsForAllTablesInDB------------------------------
SET NOCOUNT ON
DECLARE @cursor CURSOR, @table SYSNAME, @message VARCHAR(512)
SET @cursor = CURSOR FOR
	SELECT '[' + s.name + '].[' + o.name + ']'
	FROM sysobjects o, sys.schemas s 
	WHERE o.uid = s.schema_id 
		AND o.type = 'U' 
		AND '[' + s.name + '].[' + o.name + ']' NOT LIKE ('%exclude%')
		ORDER BY s.name, o.name
	OPEN @cursor
	FETCH @cursor INTO @table
WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @message = CONVERT(VARCHAR,GETDATE(),121) +': Updating statistics for table "'+ @table +'"'
	RAISERROR (@message, 0, 1) WITH NOWAIT
	SET @message = 'UPDATE STATISTICS '+ @table
		EXEC(@message)
	FETCH @cursor INTO @table
	END
	CLOSE @cursor
	DEALLOCATE @cursor
GO
