DECLARE @BackupFolder AS VARCHAR(500)
DECLARE @BackupFilename_root AS VARCHAR(500)
DECLARE @BackupDescription AS VARCHAR(500)
DECLARE @BackupFilename_01Of05 AS VARCHAR(500)
DECLARE @BackupFilename_02Of05 AS VARCHAR(500)
DECLARE @BackupFilename_03Of05 AS VARCHAR(500)
DECLARE @BackupFilename_04Of05 AS VARCHAR(500)
DECLARE @BackupFilename_05Of05 AS VARCHAR(500)
DECLARE @BackupFilename AS VARCHAR(500)
DECLARE @BackupSetName AS NVARCHAR(500)

SET @BackupDescription = 'Database'
SET @BackupFolder = 'E:\' --ENTER FILE PATH HERE
SET @BackupFilename_root = 'Everest'
SET @BackupFilename_01Of05 = @BackupFolder + @BackupFilename_root + '_01of05.BAK'
SET @BackupFilename_02Of05 = @BackupFolder + @BackupFilename_root + '_02of05.BAK'
SET @BackupFilename_03Of05 = @BackupFolder + @BackupFilename_root + '_03of05.BAK'
SET @BackupFilename_04Of05 = @BackupFolder + @BackupFilename_root + '_04of05.BAK'
SET @BackupFilename_05Of05 = @BackupFolder + @BackupFilename_root + '_05of05.BAK'
SET @BackupSetName = N'EverestDB'
------------------------------------------------------------------------------------
--  BACKUP THE DATABASE INTO 5 BACKUP FILES
------------------------------------------------------------------------------------
BACKUP DATABASE
	Everest
TO 
	DISK= @BackupFilename_01Of05,
	DISK= @BackupFilename_02Of05,
	DISK= @BackupFilename_03Of05,
	DISK= @BackupFilename_04Of05,
	DISK= @BackupFilename_05Of05
WITH 
	DESCRIPTION = @BackupDescription,
	INIT, NOUNLOAD, NOSKIP, NOFORMAT, 
	STATS = 5,
	NAME = @BackupSetName
GO