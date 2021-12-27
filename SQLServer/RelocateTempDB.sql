----------------------------------RelocateTempDB------------------------------------------
--Determine the logical file names of the tempdb database and their current location on the disk. 
SELECT name, physical_name AS CurrentLocation
FROM sys.master_files
WHERE database_id = DB_ID(N'tempdb');
GO
--Change the location of each file by using ALTER DATABASE.
USE master;
GO
ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, FILENAME = 'E:\SQLData\tempdb.mdf');
GO
ALTER DATABASE tempdb 
MODIFY FILE (NAME = templog, FILENAME = 'F:\SQLLog\templog.ldf');
GO
--Stop and restart the instance of SQL Server. 
--Verify the file change.
SELECT name, physical_name AS CurrentLocation, state_desc
FROM sys.master_files
WHERE database_id = DB_ID(N'tempdb');

--DELETE the tempdb.mdf and templog.ldf files from the original location.