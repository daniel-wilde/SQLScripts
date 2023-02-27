----------INDEX USAGE---------
SELECT
	OBJECT_NAME(S.[object_id]) AS [OBJECT NAME]
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
WHERE
	OBJECTPROPERTY(S.[object_id], 'IsUserTable') = 1 
	AND DB_NAME(S.database_id) = 'BizDev'
	AND OBJECT_NAME(S.[object_id]) = 'EmailStats' --LIKE '%Contact%'
	--AND I.Name IN ('')
ORDER BY S.user_seeks

sp_spaceused 'Job.JobApp' --38,830,221            

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


------------------------------------------------------------------------------------
-- Index Usage Data
------------------------------------------------------------------------------------
DECLARE @DBID INT
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
       , CAST(ISNULL([last_user_seek], '') AS VARCHAR(30)) [last_user_seek]
       , CAST(ISNULL([last_user_scan], '') AS VARCHAR(30)) [last_user_scan]
--     , CAST (f.avg_fragmentation_in_percent as decimal (4,1)) [Frag %]
       , DB_NAME (@DBID) [DB Name]
INTO #IndexStats
FROM sys.dm_db_index_usage_stats AS s 
LEFT JOIN sys.indexes f ON f.[object_id] = s.[object_id] AND f.index_id = s.index_id 
--     INNER JOIN (SELECT object_id, index_id, page_count, avg_fragmentation_in_percent FROM sys.dm_db_index_physical_stats (@DBID, NULL, NULL, NULL, NULL)) f ON f.[object_id] = s.[object_id] AND f.index_id = s.index_id 
       --LEFT JOIN (SELECT object_id, index_id, SUM(row_count) AS Rows, CONVERT(numeric(19,0), CONVERT(numeric(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(numeric(19,3), 128)) AS SizeMB
       --            FROM sys.dm_db_partition_stats GROUP BY object_id, index_id) f ON f.[object_id] = s.[object_id] AND f.index_id = s.index_id 
WHERE s.database_id = @DBID