DECLARE @DB VARCHAR(100) = DB_NAME()
DECLARE @SPID VARCHAR(4)
	,@cmdSQL VARCHAR(255)
	,@SQLLoginName VARCHAR(50) = '%User%'

-- Looks for all spids that are connected in the databases
DECLARE cCursor CURSOR
FOR
SELECT CAST(SPID AS VARCHAR(4))
FROM master.dbo.sysprocesses
WHERE loginame LIKE @SQLLoginName
	AND DBID = DB_ID(@DB) 
OPEN cCursor

FETCH NEXT FROM cCursor INTO @SPID

-- For each user connected in the database
WHILE @@FETCH_STATUS = 0
BEGIN

	SET @cmdSQL = 'sp_who2 ' +  @SPID
	EXEC (@cmdSQL)

	PRINT 'KILLING SPID: ' + @SPID
	SET @cmdSQL = 'KILL ' + @SPID
	EXEC (@cmdSQL)

	FETCH NEXT FROM cCursor	INTO @SPID
END

CLOSE cCURSOR
DEALLOCATE cCURSOR
