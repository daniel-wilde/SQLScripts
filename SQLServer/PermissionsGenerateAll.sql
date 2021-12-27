IF OBJECT_ID('tempdb..#DBROLES') IS NOT NULL
	DROP TABLE #DBROLES

CREATE TABLE #DBROLES
(
	DatabaseName VARCHAR(100)
	,UserName VARCHAR(100)
	,LoginType VARCHAR(100)
	,RoleName VARCHAR(100)
)

IF OBJECT_ID('tempdb..#SERVERROLES') IS NOT NULL
	DROP TABLE #SERVERROLES

CREATE TABLE #SERVERROLES
(
	ServerName VARCHAR(100)
	,LoginName VARCHAR(100)
	,LoginType VARCHAR(100)
	,RoleName VARCHAR(100)
)

IF OBJECT_ID('tempdb..#ALLROLES') IS NOT NULL
	DROP TABLE #ALLROLES

CREATE TABLE #ALLROLES
(
	RoleName VARCHAR(100)
	,RoleType VARCHAR(10)
	,ColumnOrder INT
)

DECLARE @DBName VARCHAR(100)
DECLARE @SQL NVARCHAR(MAX)

--GET ALL DATABASE LEVEL PERMS
DECLARE DBName_Cursor CURSOR
FOR
	SELECT Name
	FROM master.sys.databases
	WHERE NAME NOT IN ('mssecurity','tempdb')
		AND State = 0
	ORDER BY NAME
OPEN DBName_Cursor
FETCH NEXT FROM DBName_Cursor INTO @DBName
WHILE @@FETCH_STATUS = 0
BEGIN

	SET @SQL = '
	INSERT INTO #DBROLES(DatabaseName, UserName, LoginType, RoleName)
	SELECT ''[' + @DBName + ']'' AS DatabaseName
		,b.NAME AS UserName
		,p.type_desc AS LoginType
		,c.NAME AS RoleName
	FROM [' + @DBName + '].dbo.sysmembers a
	JOIN [' + @DBName + '].dbo.sysusers b ON a.memberuid = b.uid
	JOIN [' + @DBName + '].dbo.sysusers c ON a.groupuid = c.uid
	JOIN [' + @DBName + '].sys.database_principals dbp ON b.sid = dbp.sid
	JOIN sys.server_principals p ON dbp.sid = p.sid
	WHERE p.is_disabled = 0
		AND b.name NOT IN (''dbo'')'

	--PRINT @SQL
	EXECUTE (@SQL)

	FETCH NEXT FROM DBName_Cursor INTO @DBName
END
CLOSE DBName_Cursor
DEALLOCATE DBName_Cursor

--GET DISTINCT LIST OF DATABASE ROLES
INSERT INTO #ALLROLES(RoleName, RoleType)
SELECT DISTINCT RoleName, 'Database' FROM #DBROLES

--GET ALL SERVER LEVEL PERMS
INSERT INTO #SERVERROLES(ServerName, LoginName, LoginType, RoleName)
SELECT CONVERT(sysname, SERVERPROPERTY('servername')) AS ServerName
	,PRN.NAME AS LoginName
	,Prn.Type_Desc AS LoginType
	,srvrole.NAME AS RoleName
FROM sys.server_role_members membership
INNER JOIN 
(
	SELECT *
	FROM sys.server_principals
	WHERE type_desc = 'SERVER_ROLE'
) srvrole ON srvrole.Principal_id = membership.Role_principal_id
RIGHT JOIN sys.server_principals PRN ON PRN.Principal_id = membership.member_principal_id
WHERE Prn.Type_Desc NOT IN ('SERVER_ROLE')
	AND PRN.is_disabled = 0
	AND srvrole.NAME IS NOT NULL
		
UNION ALL
		
SELECT 
	CONVERT(sysname, SERVERPROPERTY('servername')) AS ServerName
	,p.[name] AS LoginName
	,p.type_desc AS LoginType
	,'ControlServer' AS RoleName
FROM sys.server_principals p
JOIN sys.server_permissions Sp ON p.principal_id = sp.grantee_principal_id
WHERE sp.class = 100
	AND sp.[type] = 'CL'
	AND STATE = 'G'

--GET DISTINCT LIST OF DATABASE ROLES
INSERT INTO #ALLROLES(RoleName, RoleType)
SELECT DISTINCT RoleName, 'Server' FROM #SERVERROLES

UPDATE #ALLROLES
SET ColumnOrder = 
	CASE 
		WHEN RoleType = 'Server' AND RoleName = 'sysadmin' THEN 1
		WHEN RoleType = 'Server' AND RoleName <> 'sysadmin' THEN 2
		WHEN RoleType = 'Database' AND LEFT(RoleName,3) = 'db_' THEN 3
		ELSE 4
	END

IF OBJECT_ID('tempdb..#AllPerms') IS NOT NULL
	DROP TABLE #AllPerms

CREATE TABLE #AllPerms
(
	ServerName VARCHAR(100)
	,UserOrLoginType VARCHAR(100)
	,UserOrLoginName VARCHAR(100)
	,DatabaseName VARCHAR(100)
)

DECLARE @RoleName VARCHAR(100) 
DECLARE @RoleType VARCHAR(100) 
DECLARE @ServerRolesList NVARCHAR(MAX) = ''
DECLARE @ServerRolesListISNULL NVARCHAR(MAX) = ''
DECLARE @DatabaseRolesList NVARCHAR(MAX) = ''
DECLARE @DatabaseRolesListISNULL NVARCHAR(MAX) = ''
DECLARE @UpdateNULLs NVARCHAR(MAX) = ''

DECLARE cursor_Roles CURSOR FAST_FORWARD 
FOR 
	SELECT RoleName, RoleType 
	FROM #ALLROLES 
	ORDER BY ColumnOrder, RoleName
OPEN cursor_Roles  

FETCH NEXT FROM cursor_Roles INTO @RoleName, @RoleType
WHILE @@FETCH_STATUS = 0 
BEGIN   

	SET @SQL = 'ALTER TABLE #AllPerms ADD [' + @RoleName + '] INT'
	--PRINT @SQL
	EXEC sp_executesql @SQL

	SET @UpdateNULLs = @UpdateNULLs + '
	UPDATE #AllPerms SET [' + @RoleName + '] = 0 WHERE [' + @RoleName + '] IS NULL'

	IF @RoleType = 'Server' 
	BEGIN 
		SET @ServerRolesList = @ServerRolesList + '[' + @RoleName + '], '
		SET @ServerRolesListISNULL = @ServerRolesListISNULL + 'ISNULL([' + @RoleName + '],0), '
	END
	
	IF @RoleType = 'Database' 
	BEGIN 
		SET @DatabaseRolesList = @DatabaseRolesList + '[' + @RoleName + '], '
		SET @DatabaseRolesListISNULL = @DatabaseRolesListISNULL + 'ISNULL([' + @RoleName + '],0), '
	END

FETCH NEXT FROM cursor_Roles INTO @RoleName, @RoleType 

END 
CLOSE cursor_Roles 
DEALLOCATE cursor_Roles 

--TRIM FINAL COMMA
SELECT @ServerRolesList = LEFT(@ServerRolesList, LEN(@ServerRolesList) - 1)
SELECT @ServerRolesListISNULL = LEFT(@ServerRolesListISNULL, LEN(@ServerRolesListISNULL) - 1)
SELECT @DatabaseRolesList = LEFT(@DatabaseRolesList, LEN(@DatabaseRolesList) - 1)
SELECT @DatabaseRolesListISNULL = LEFT(@DatabaseRolesListISNULL, LEN(@DatabaseRolesListISNULL) - 1)

--SELECT Username, DatabaseName, RoleName FROM #DBROLES ORDER BY UserName, DatabaseName, RoleName
--SELECT LoginName, LoginType, ServerName, RoleName FROM #SERVERROLES ORDER BY LoginName, LoginType, ServerName, RoleName
--SELECT RoleType, RoleName FROM #ALLROLES ORDER BY RoleType, RoleName

SET @SQL = '
INSERT INTO #AllPerms(ServerName, DatabaseName, UserOrLoginType, UserOrLoginName, ' + @ServerRolesList + ')
SELECT ServerName, DatabaseName, UserOrLoginType, UserOrLoginName, ' + @ServerRolesListISNULL + '
FROM
(
	SELECT ServerName AS ServerName
		,''(server)'' AS DatabaseName
		,LoginType AS UserOrLoginType
		,LoginName AS UserOrLoginName
		,RoleName
	FROM #SERVERROLES 
) srv 
PIVOT
(
	COUNT(RoleName)
	FOR RoleName IN (' + @ServerRolesList + ')
) as pvt
ORDER BY ServerName, DatabaseName, UserOrLoginType, UserOrLoginName'

--PRINT @SQL
EXEC sp_executesql @SQL

SET @SQL = '
INSERT INTO #AllPerms(ServerName, DatabaseName, UserOrLoginType, UserOrLoginName, ' + @DatabaseRolesList + ')
SELECT ServerName, DatabaseName, UserOrLoginType, UserOrLoginName, ' + @DatabaseRolesListISNULL + '
FROM
(
	SELECT CONVERT(sysname, SERVERPROPERTY(''servername'')) AS ServerName
		,DatabaseName AS DatabaseName
		,LoginType AS UserOrLoginType
		,UserName AS UserOrLoginName
		,RoleName
	FROM #DBROLES 
) srv 
PIVOT
(
	COUNT(RoleName)
	FOR RoleName IN (' + @DatabaseRolesList + ')
) as pvt
ORDER BY ServerName, DatabaseName, UserOrLoginType, UserOrLoginName'

PRINT @SQL
EXEC sp_executesql @SQL
EXEC sp_executesql @UpdateNULLs


---------DATABASE ROLE PERMISSIONS---------
IF OBJECT_ID('tempdb..#DBROLEPERMS') IS NOT NULL
	DROP TABLE #DBROLEPERMS

CREATE TABLE #DBROLEPERMS
(
	DatabaseName VARCHAR(100)
	,RoleName VARCHAR(100)
	,PermissionType VARCHAR(100)
	,PermissionName VARCHAR(100)
	,StateDesc VARCHAR(100)
	,ObjectType VARCHAR(100)
	,SchemaName VARCHAR(100)
	,ObjectName VARCHAR(100)
)

DECLARE cursor_RolePerms CURSOR FAST_FORWARD 
FOR 
	SELECT Name 
	FROM sys.databases 
	ORDER BY Name
OPEN cursor_RolePerms  

FETCH NEXT FROM cursor_RolePerms INTO @DBName
WHILE @@FETCH_STATUS = 0 
BEGIN   

	SET @SQL = 'USE [' + @DBName + ']

	INSERT INTO #DBROLEPERMS
	(
		DatabaseName
		,RoleName
		,PermissionType
		,PermissionName
		,StateDesc
		,ObjectType
		,SchemaName
		,ObjectName
	)
	SELECT DISTINCT
		DB_NAME() AS DatabaseName
		,rp.name AS RoleName
		--,ObjectType = rp.type_desc
		,PermissionType = pm.class_desc
		,pm.permission_name AS PermissionName
		,pm.state_desc AS StateDesc
		,ObjectType = CASE	WHEN obj.type_desc IS NULL OR obj.type_desc = ''SYSTEM_TABLE'' THEN pm.class_desc ELSE obj.type_desc END
		,s.name AS SchemaName
		,[ObjectName] = ISNULL(ss.name, OBJECT_NAME(pm.major_id))
	FROM
		sys.database_principals rp
		INNER JOIN sys.database_permissions pm ON pm.grantee_principal_id = rp.principal_id
		LEFT JOIN sys.schemas ss ON pm.major_id = ss.schema_id
		LEFT JOIN sys.objects obj ON pm.[major_id] = obj.[object_id]
		LEFT JOIN sys.schemas s ON s.schema_id = obj.schema_id
	WHERE
		rp.type_desc = ''DATABASE_ROLE''
		AND pm.class_desc <> ''DATABASE''
	ORDER BY
		rp.name
		--,rp.type_desc
		,pm.class_desc'

	--PRINT @SQL
	EXEC sp_executesql @SQL

FETCH NEXT FROM cursor_RolePerms INTO @DBName

END 
CLOSE cursor_RolePerms 
DEALLOCATE cursor_RolePerms 


-----------------VIEW PERMISSIONS----------------------------------


SELECT *
FROM #AllPerms
WHERE (DatabaseName LIKE '%DBName]')
	OR (DatabaseName LIKE '%DBName]')
	--OR (sysadmin = 1 )
ORDER BY ServerName
	,UserOrLoginType
	,UserOrLoginName
	,DatabaseName

--VIEW INDIVIDUAL OBJECT PERMISSIONS:
SELECT pr.principal_id, pr.name, pr.type_desc,   
    pr.authentication_type_desc, pe.state_desc,   
    pe.permission_name, s.name + '.' + o.name AS ObjectName  
FROM sys.database_principals AS pr  
JOIN sys.database_permissions AS pe  
    ON pe.grantee_principal_id = pr.principal_id  
JOIN sys.objects AS o  
    ON pe.major_id = o.object_id  
JOIN sys.schemas AS s  
    ON o.schema_id = s.schema_id
WHERE pr.Name = 'DOMAIN\USER'
--pe.permission_name = 'CONTROL'

SELECT --'USE ' + DatabaseName + ' REVOKE ' + PermissionName + ' ON ' + PermissionType + ' :: ' + ObjectName + ' FROM ' + RoleName, 
	* 
FROM #DBROLEPERMS
WHERE --PermissionName IN ('CONTROL')--,'EXECUTE')
--	--AND ObjectName IS NOT NULL
	--AND 
	DatabaseName LIKE '%DBName%'
	--AND RoleName LIKE '%public%'
	--AND ObjectName = 'dbo'
ORDER BY DatabaseName, RoleName, ObjectType, PermissionName

--REVOKE PERMISSIONS:
USE DBName REVOKE CONTROL ON SCHEMA :: dbo FROM Approle

