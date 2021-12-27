-----------DB FILE STATS-------------------
SELECT RTRIM(name) AS [Segment Name], groupid AS [Group ID], filename AS [File Name],
	CAST(size/128.0 AS DECIMAL(14,2)) AS [Allocated Size in MB],
	CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(14,2)) AS [Space Used in MB]
FROM sysfiles
ORDER BY groupid DESC