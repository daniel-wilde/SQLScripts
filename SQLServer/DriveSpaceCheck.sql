--D:\ Drive
--0.234111785

SET NOCOUNT ON
DECLARE @hr INT
DECLARE @fso INT
DECLARE @drive CHAR(1)
DECLARE @odrive INT
DECLARE @TotalSize VARCHAR(20)
DECLARE @MB NUMERIC;
SET @MB = 1048576

CREATE TABLE #drives
(
	drive CHAR(1) PRIMARY KEY
	,FreeSpace INT NULL
	,TotalSize INT NULL
)

INSERT #drives(drive,FreeSpace)
EXEC master.dbo.xp_fixeddrives

EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @fso OUT

IF @hr <> 0
	EXEC sp_OAGetErrorInfo @fso

DECLARE dcur CURSOR LOCAL FAST_FORWARD FOR
	SELECT drive
	FROM #drives
	ORDER BY drive
OPEN dcur
FETCH NEXT FROM dcur INTO @drive
WHILE @@FETCH_STATUS = 0
BEGIN

	EXEC @hr = sp_OAMethod @fso
		,'GetDrive'
		,@odrive OUT
		,@drive

	IF @hr <> 0
		EXEC sp_OAGetErrorInfo @fso

	EXEC @hr = sp_OAGetProperty @odrive
		,'TotalSize'
		,@TotalSize OUT

	IF @hr <> 0
		EXEC sp_OAGetErrorInfo @odrive

	UPDATE #drives
	SET TotalSize = @TotalSize / @MB
	WHERE drive = @drive

	FETCH NEXT FROM dcur INTO @drive
END
CLOSE dcur
DEALLOCATE dcur

EXEC @hr = sp_OADestroy @fso

IF @hr <> 0
	EXEC sp_OAGetErrorInfo @fso

SELECT drive
	,TotalSize / 1048576.0 AS 'Total (TB)'
	,FreeSpace / 1048576.0 AS 'Free (TB)'
FROM #drives
ORDER BY drive

DROP TABLE #drives
GO

