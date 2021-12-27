---------------------------VIEW LOG FILE------------------------------------

SET NOCOUNT ON
DECLARE @LSN NVARCHAR(46)
DECLARE @LSN_HEX NVARCHAR(25)
DECLARE @tbl TABLE (id INT identity(1,1), i VARCHAR(10))
DECLARE @stmt VARCHAR(256)

SET @LSN = (SELECT TOP 1 [Current LSN] FROM fn_dblog(NULL, NULL))
PRINT @LSN

SET @stmt = 'SELECT CAST(0x' + SUBSTRING(@LSN, 1, 8) + ' AS INT)'
INSERT @tbl EXEC(@stmt)
SET @stmt = 'SELECT CAST(0x' + SUBSTRING(@LSN, 10, 8) + ' AS INT)'
INSERT @tbl EXEC(@stmt)
SET @stmt = 'SELECT CAST(0x' + SUBSTRING(@LSN, 19, 4) + ' AS INT)'
INSERT @tbl EXEC(@stmt)

SET @LSN_HEX =
(SELECT i FROM @tbl WHERE id = 1) + ':' + (SELECT i FROM @tbl WHERE id = 2) + ':' + (SELECT i FROM @tbl WHERE id = 3)
PRINT @LSN_HEX

SELECT [Current LSN], [Operation], [Context], [Transaction ID], [AllocUnitName], [Begin Time], [Page ID], [Transaction Name], [Parent Transaction ID], [Description] 
FROM ::fn_dblog(@LSN_HEX, NULL)
WHERE [Begin Time] IS NOT NULL
	OR [AllocUnitName] IS NOT NULL
ORDER BY [Begin Time] DESC