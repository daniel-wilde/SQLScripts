SET NOCOUNT ON
DECLARE @cursor CURSOR, @table SYSNAME, @message VARCHAR(512)
SET @cursor = CURSOR FOR
	SELECT s.name + '.' + o.name 
	FROM sysobjects o, sys.schemas s 
	WHERE o.uid = s.schema_id 
		--AND o.type = 'U' 
		AND s.name + '.' + o.name IN
	(
		'dbo.Excluded'
	)
	ORDER BY s.name, o.name
	OPEN @cursor
	FETCH @cursor INTO @table
WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @message = CONVERT(VARCHAR,GETDATE(),121) +': Reindexing table "'+ @table +'"'
	RAISERROR (@message, 0, 1) WITH NOWAIT
	DBCC DBREINDEX (@table)
	FETCH @cursor INTO @table
	END
	CLOSE @cursor
	DEALLOCATE @cursor
GO