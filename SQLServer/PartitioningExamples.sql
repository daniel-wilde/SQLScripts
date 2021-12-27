-- CHECK LARGEST RANGE RIGHT LIMIT
DECLARE @MaxID BIGINT
SELECT @MaxID = MAX(ID) FROM  (NOLOCK) dbo.Table
DECLARE @MaxRangeRightLimit BIGINT
SELECT @MaxRangeRightLimit = MAX(CAST(rv.value AS BIGINT))
FROM sys.partitions p
INNER JOIN sys.indexes i ON p.object_id = i.object_id
	AND p.index_id = i.index_id
INNER JOIN sys.objects o ON p.object_id = o.object_id
INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
INNER JOIN sys.partition_functions f ON f.function_id = ps.function_id
INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
	AND dds.destination_id = p.partition_number
INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
LEFT OUTER JOIN sys.partition_range_values rv ON f.function_id = rv.function_id
	AND p.partition_number = rv.boundary_id
WHERE i.index_id < 2
	AND o.object_id IN (SELECT object_id FROM sys.objects WHERE name = '')

SELECT @MaxID, @MaxRangeRightLimit

IF @MaxRangeRightLimit - @MaxID < 8000000
BEGIN
	
	--ADD FILEGROUP
	ALTER DATABASE PartDB ADD FILEGROUP FG_PartDB_NewFG;

	--ADD FILE TO FILEGROUP
	ALTER DATABASE PartDB
		ADD FILE
			( NAME = N'PartDB_NewFile', FILENAME = N'M:\MSSQL2012\Data\PROD\NewFile.NDF' , SIZE = 1GB , MAXSIZE = UNLIMITED, FILEGROWTH = 1GB )
		TO FILEGROUP FG_PartDB_NewFG;

	--UPDATE PARTITION SCHEME
	ALTER PARTITION SCHEME psPartitionScheme
		NEXT USED FG_PartDB_NewFG;

	--UPDATE PARTITION FUNCTION
	ALTER PARTITION FUNCTION pfPartitionFunction()
		SPLIT RANGE (1000000)

END


------------CHECK PARTITIONS--------------------------------------

DECLARE @MaxID BIGINT
DECLARE @PartitionSize BIGINT = 2000000 --PARTITION SIZE
SELECT @MaxID = MAX(ID) FROM dbo.LargeTable (NOLOCK) 
DECLARE @FilePath VARCHAR(1000)

-- CHECK LARGEST RANGE RIGHT LIMIT
DECLARE @MaxRangeRightLimit BIGINT
SELECT @MaxRangeRightLimit = MAX(CAST(rv.value AS BIGINT))
--SELECT rv.Value, fg.name, p.partition_number, fil.*
FROM sys.partitions p
INNER JOIN sys.indexes i ON p.object_id = i.object_id
	AND p.index_id = i.index_id
INNER JOIN sys.objects o ON p.object_id = o.object_id
INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
INNER JOIN sys.partition_functions f ON f.function_id = ps.function_id
INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
	AND dds.destination_id = p.partition_number
INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
INNER JOIN sysfiles fil ON fg.data_space_id = fil.groupid
LEFT OUTER JOIN sys.partition_range_values rv ON f.function_id = rv.function_id
	AND p.partition_number = rv.boundary_id
WHERE i.index_id < 2
	AND o.object_id IN (SELECT object_id FROM sys.objects WHERE name = '')
--ORDER BY p.partition_number

-- GET THE FILE PATH OF THE LAST PARTITION
SELECT @FilePath = LEFT(fil.FileName, LEN(fil.FileName) - CHARINDEX('\',REVERSE(fil.FileName)))
FROM sys.partitions p
INNER JOIN sys.indexes i ON p.object_id = i.object_id
	AND p.index_id = i.index_id
INNER JOIN sys.objects o ON p.object_id = o.object_id
INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
INNER JOIN sys.partition_functions f ON f.function_id = ps.function_id
INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
	AND dds.destination_id = p.partition_number
INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
INNER JOIN sysfiles fil ON fg.data_space_id = fil.groupid
LEFT OUTER JOIN sys.partition_range_values rv ON f.function_id = rv.function_id
	AND p.partition_number = rv.boundary_id
WHERE i.index_id < 2
	AND o.object_id IN (SELECT object_id FROM sys.objects WHERE name = '')
	AND rv.Value IS NULL --LAST RANGE RIGHT PARTITION

SELECT @MaxID AS Current_ID, @MaxRangeRightLimit AS Max_ID_Bound, @FilePath AS FilePath

SELECT rv.Value AS UpperBound, fg.name AS FileGroup, fil.*
FROM sys.partitions p
INNER JOIN sys.indexes i ON p.object_id = i.object_id
	AND p.index_id = i.index_id
INNER JOIN sys.objects o ON p.object_id = o.object_id
INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
INNER JOIN sys.partition_functions f ON f.function_id = ps.function_id
INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
	AND dds.destination_id = p.partition_number
INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
INNER JOIN sysfiles fil ON fg.data_space_id = fil.groupid
LEFT OUTER JOIN sys.partition_range_values rv ON f.function_id = rv.function_id
	AND p.partition_number = rv.boundary_id
WHERE i.index_id < 2
	AND o.object_id IN (SELECT object_id FROM sys.objects WHERE name = '')
ORDER BY fileid DESC

