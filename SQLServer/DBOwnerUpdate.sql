/* declare variables */
DECLARE @dbname VARCHAR(100)
DECLARE @SQL NVARCHAR(MAX)

DECLARE cursor_name CURSOR FAST_FORWARD READ_ONLY FOR 
SELECT d.name --, suser_sname( owner_sid )
FROM sys.databases d
WHERE is_read_only = 0
	AND SUSER_SNAME( owner_sid )  <> 'sa'
	--AND (d.recovery_model_desc <> 'FULL' AND d.name <> 'tempdb')

OPEN cursor_name

FETCH NEXT FROM cursor_name INTO @dbname

WHILE @@FETCH_STATUS = 0
BEGIN
    
	--CHANGE DB OWNER TO SA:
	SET @SQL = 'USE [' + @dbname + '];
	SELECT DB_NAME(); 
	EXEC sp_changedbowner ''sa'';'

	--PRINT @SQL
	EXEC (@SQL)

	----UPDATE RECOVERY MODEL TO FULL
	--SET @SQL = '
	--ALTER DATABASE [' + @dbname + '] SET RECOVERY FULL;'

	----PRINT @SQL
	--EXEC (@SQL)

    FETCH NEXT FROM cursor_name INTO @dbname
END

CLOSE cursor_name
DEALLOCATE cursor_name
