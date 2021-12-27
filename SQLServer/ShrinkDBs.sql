---------------------------------ShrinkAllDBsOnASQLInstance---------------------------------
EXEC sp_MSForEachDB 
@Command1 = N'
	USE [?]; 
	IF EXISTS ( select * from sys.objects where name = ''CompactB2BLogs'' ) 
	BEGIN 
		EXEC B2B.CompactB2BLogs 0; 
		TRUNCATE TABLE Portfolio.LotHistory; 
		TRUNCATE TABLE Portfolio.ContractHistory; 
		TRUNCATE TABLE UI.DataPanelHistory; 
	END', 
@Command2 = N'DBCC SHRINKDATABASE (?, 10)', 
@Command3 = N'USE [?]; DBCC SHRINKFILE (<<NAME OF FILE>>, 10)',	
@replacechar = '?'
---------------------------------ShrinkAllLogsOnASQLInstance--------------------------------
EXEC sp_MSForEachDB @Command1 = N'USE [?]; DBCC SHRINKFILE (<<NAME OF LOG>>, 10)'
---------------------------------ShrinkDatabase---------------------------------------------
SET NOCOUNT ON
DECLARE @cursor CURSOR, @file SYSNAME, @filename SYSNAME, @message VARCHAR(512)
SET @cursor = CURSOR FOR
	SELECT name, filename FROM sysfiles WHERE groupid > 0 ORDER BY name
	OPEN @cursor
	FETCH @cursor INTO @file, @filename
WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @message = CONVERT(VARCHAR,GETDATE(),121) +': Shrinking data file "'+ @file +'" at "'+ @filename +'"'
	RAISERROR (@message, 0, 1) WITH NOWAIT
	DBCC SHRINKFILE (@file)
	FETCH @cursor INTO @file, @filename
	END
	CLOSE @cursor
	DEALLOCATE @cursor
GO
---------------------------------ShrinkLogs--------------------------------------------------
SET NOCOUNT ON
DECLARE @database SYSNAME, @message VARCHAR(512)
SET @database = db_name()
SET @message = CONVERT(VARCHAR,GETDATE(),121) +': Backing up log truncate only for database "'+ @database +'"'
RAISERROR (@message, 0, 1) WITH NOWAIT
--BACKUP LOG @database WITH TRUNCATE_ONLY
GO
-- Truncate log files:
SET NOCOUNT ON
DECLARE @cursor CURSOR, @file SYSNAME, @filename SYSNAME, @message VARCHAR(512)
SET @cursor = CURSOR FOR
	SELECT name, filename FROM sysfiles WHERE groupid = 0
	OPEN @cursor
	FETCH @cursor INTO @file, @filename
WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @message = CONVERT(VARCHAR,GETDATE(),121) +': Shrinking log file "'+ @file +'" at "'+ @filename +'"'
	RAISERROR (@message, 0, 1) WITH NOWAIT
	DBCC SHRINKFILE (@file)
	FETCH @cursor INTO @file, @filename
	END
	CLOSE @cursor
	DEALLOCATE @cursor
GO