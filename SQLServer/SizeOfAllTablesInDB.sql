DECLARE @TableName VARCHAR(300)
DECLARE @AllTables TABLE(TableName VARCHAR(300))
DECLARE @TableSizes TABLE(
	TableName VARCHAR(300)
	,TotalRows BIGINT
	,Reserved VARCHAR(50)
	,Data VARCHAR(50)
	,Index_Size VARCHAR(50)
	,Unused VARCHAR(50))
INSERT INTO @AllTables
SELECT s.Name + '.' + t.Name
FROM sys.tables t, sys.schemas s 
WHERE t.schema_id = s.schema_id 
ORDER BY s.Name, t.Name
DECLARE cursor_SpaceUsed CURSOR FAST_FORWARD
	FOR
	SELECT * FROM @AllTables
OPEN cursor_SpaceUsed
FETCH NEXT FROM cursor_SpaceUsed INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN 
	INSERT INTO @TableSizes
	EXEC sp_spaceused @TableName
	UPDATE @TableSizes
	SET TableName = @TableName
	WHERE TableName = RIGHT(@TableName,LEN(@TableName)-CHARINDEX('.',@TableName))
FETCH NEXT FROM cursor_SpaceUsed INTO @TableName
END
CLOSE cursor_SpaceUsed
DEALLOCATE cursor_SpaceUsed

SELECT * FROM @TableSizes 
--WHERE TableName IN ('---')
ORDER BY LEN(Reserved) DESC, Reserved DESC, TotalRows DESC
--ORDER BY TableName ASC