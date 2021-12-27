--CHECK % OF INT FIELD USED:
DECLARE @Percent DECIMAL(3, 2) = .80

SELECT TableName
	,ColumnName
	,DataType
	,CurrentValue
	,MaxValue
	,CASE 
		WHEN CurrentValue < 0
			THEN (MaxValue + cast(CurrentValue AS FLOAT(4))) / MaxValue
		ELSE cast(CurrentValue AS FLOAT(4)) / MaxValue
		END * 100 AS PercentUsed
FROM 
(
	SELECT c.NAME AS TableName
		,a.NAME AS ColumnName
		,b.NAME AS DataType
		,a.last_value AS CurrentValue
		,power(cast(2 AS VARCHAR), (b.max_length * 8) - 1) AS MaxValue
	FROM sys.identity_columns a
	INNER JOIN sys.types b ON a.system_type_id = b.system_type_id
	INNER JOIN sys.tables c ON a.object_id = c.object_id
	WHERE a.last_value IS NOT NULL
		AND b.NAME IN ('bigint','int','smallint','tinyint')
) CurrentValues
WHERE CASE 
		WHEN CurrentValue < 0
			THEN (MaxValue + cast(CurrentValue AS FLOAT(4))) / MaxValue
		ELSE cast(CurrentValue AS FLOAT(4)) / MaxValue
		END >= @Percent

---------------------------

SELECT ID_COLS.* FROM
(
	SELECT 
		GETDATE() AS [Date]
		,c.TABLE_CATALOG AS DBName
		,c.TABLE_SCHEMA + '.' + t.TABLE_NAME AS TableName
		,c.COLUMN_NAME AS ColName
		,c.DATA_TYPE AS [DataType]
		,idcol.last_value AS CurrentValue
		,CAST((CASE LOWER(c.DATA_TYPE)
					WHEN 'tinyint' THEN 
						(CASE WHEN ISNULL(idcol.last_value,0) >= 0 THEN IDENT_CURRENT(t.TABLE_NAME) ELSE 255 + IDENT_CURRENT(t.TABLE_NAME) END / 255)
					WHEN 'smallint' THEN 
						(CASE WHEN ISNULL(idcol.last_value,0) >= 0 THEN IDENT_CURRENT(t.TABLE_NAME) ELSE 32767 + IDENT_CURRENT(t.TABLE_NAME) END / 32767)
					WHEN 'int' THEN 
						(CASE WHEN ISNULL(idcol.last_value,0) >= 0 THEN IDENT_CURRENT(t.TABLE_NAME) ELSE 2147483647 + IDENT_CURRENT(t.TABLE_NAME) END / 2147483647)
					WHEN 'bigint' THEN 
						(CASE WHEN ISNULL(idcol.last_value,0) >= 0 THEN IDENT_CURRENT(t.TABLE_NAME) ELSE 9223372036854775807 + IDENT_CURRENT(t.TABLE_NAME) END / 9223372036854775807)
					WHEN 'decimal' THEN 
						(CASE WHEN ISNULL(idcol.last_value,0) >= 0 THEN IDENT_CURRENT(t.TABLE_NAME) ELSE ((c.NUMERIC_PRECISION * 10) - 1) + IDENT_CURRENT(t.TABLE_NAME) END / ((c.NUMERIC_PRECISION * 10) - 1))
				END) AS DECIMAL(8,5)) AS PercFull
	FROM INFORMATION_SCHEMA.COLUMNS c
		INNER JOIN INFORMATION_SCHEMA.TABLES t ON t.TABLE_NAME = c.TABLE_NAME
			AND c.TABLE_SCHEMA = t.TABLE_SCHEMA
		INNER JOIN SYS.SCHEMAS sc ON t.TABLE_SCHEMA = sc.name
		INNER JOIN SYS.OBJECTS o ON t.TABLE_NAME = o.name 
			AND sc.schema_id = o.schema_id
			AND o.type = 'U'
		INNER JOIN SYS.COLUMNS scol ON o.object_id = scol.object_id
			AND c.COLUMN_NAME = scol.name
		INNER JOIN SYS.IDENTITY_COLUMNS idcol ON o.object_id = idcol.object_id 
	WHERE COLUMNPROPERTY(OBJECT_ID(c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') = 1 --true
		AND t.TABLE_TYPE = 'Base Table'
		AND t.TABLE_NAME NOT LIKE 'dt%'
		AND t.TABLE_NAME NOT LIKE 'MS%'
		AND t.TABLE_NAME NOT LIKE 'syncobj_%'
) ID_COLS
WHERE PercFull > 0.01
ORDER BY PercFull DESC