/*
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dba_ForeignKeyDefinitionAll_temp]') AND type in (N'U'))
	SELECT		s1.name AS FK_schema,
				o1.name AS FK_table,
				c1a.name AS FK_PK_column, 
				c1.name AS FK_column,
				fk.name AS FK_name,
				s2.name AS PK_schema,
				o2.name AS PK_table,
				c2.name AS PK_column,
				pk.name AS PK_name,
				fk.delete_referential_action_desc AS Delete_Action,
				fk.update_referential_action_desc AS Update_Action,
				fk.is_not_trusted
	INTO		dbo.dba_ForeignKeyDefinitionAll_temp
	FROM		sys.objects o1
				INNER JOIN sys.schemas s1 ON o1.schema_id = s1.schema_id
				INNER JOIN sys.foreign_keys fk ON o1.object_id = fk.parent_object_id
				INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
				INNER JOIN sys.columns c1 ON fkc.parent_object_id = c1.object_id AND fkc.parent_column_id = c1.column_id
				INNER JOIN sys.columns c1a ON fkc.parent_object_id = c1a.object_id AND fkc.constraint_column_id = c1a.column_id
				INNER JOIN sys.columns c2 ON fkc.referenced_object_id = c2.object_id AND fkc.referenced_column_id = c2.column_id
				INNER JOIN sys.objects o2 ON fk.referenced_object_id = o2.object_id
				INNER JOIN sys.schemas s2 ON o2.schema_id = s2.schema_id
				INNER JOIN sys.key_constraints pk ON fk.referenced_object_id = pk.parent_object_id AND fk.key_index_id = pk.unique_index_id;
GO

*/


DECLARE	@SQL VARCHAR(MAX) = '',
		@Row_no INT = 1,
		@PK_schema VARCHAR(250),
		@PK_table VARCHAR(250) = 'Product',
		@PK_column VARCHAR(250) = '';

DECLARE @PK_Tables TABLE (Row_no INT, PK_schema varchar(250), PK_table varchar(250), PK_column varchar(250));


IF @PK_table = ''
	INSERT INTO @PK_Tables
	SELECT	[Row_no] = ROW_NUMBER() OVER (ORDER BY PK_table),
			PK_schema,
			PK_table, 
			PK_column
	FROM	dbo.dba_ForeignKeyDefinitionAll_temp
	GROUP BY PK_schema, PK_table, PK_column;
ELSE
	WITH PK_table_CTE
	AS
	(
		SELECT	PK_schema, PK_table, FK_table, PK_column, 0 AS Level
		FROM	dbo.dba_ForeignKeyDefinitionAll_temp f
		WHERE	PK_table = @PK_table
		--AND	PK_table <> FK_table

		UNION ALL

		SELECT	f.PK_schema, f.PK_table, f.FK_table, f.PK_column, Level + 1
		FROM	dbo.dba_ForeignKeyDefinitionAll_temp f
				INNER JOIN PK_table_CTE c ON c.FK_table = f.PK_table 
				--AND c.PK_column = f.PK_column
				AND	NOT EXISTS(
				SELECT	1
				FROM	dbo.dba_ForeignKeyDefinitionAll_temp t
				WHERE	f.PK_table = t.FK_table
				AND		f.PK_table = t.PK_table
				)
	) 
	INSERT INTO @PK_Tables
	SELECT	[Row_no] = ROW_NUMBER() OVER (ORDER BY PK_table),
			PK_schema,
			PK_table,
			PK_column
	FROM	PK_table_CTE
	GROUP BY PK_schema, PK_table, PK_column;


/*******************************************************************
*	select all child tables from a given parent table
*******************************************************************/

SET	@SQL = 'DECLARE @ToBeDELETED INT = ;' + CHAR(10) + CHAR(13);

WHILE (1=1)
BEGIN
	SELECT	@PK_schema = PK_schema,
			@PK_table = PK_table,
			@PK_column = PK_column
	FROM	@PK_Tables
	WHERE	Row_no = @Row_no;

	SET	@SQL = @SQL + '-- The following are the child tables of: ' + @PK_table + CHAR(10);
	
	SELECT	@SQL = @SQL + 'SELECT ''' + f.FK_table + ''' AS [TABLE], * FROM ' + f.FK_schema + '.' + f.FK_table + ' WHERE ' + f.FK_column + ' IN (@ToBeDELETED); ' + CHAR(10)
	FROM	dbo.dba_ForeignKeyDefinitionAll_temp f
			INNER JOIN @PK_Tables p ON p.PK_table = f.PK_table
	WHERE	p.Row_no = @Row_no
	ORDER BY f.FK_table, f.FK_column;

	IF @@ROWCOUNT = 0
		BREAK;
	ELSE
	BEGIN
		SET	@SQL = @SQL + CHAR(10) + CHAR(13);
		SET	@Row_no = @Row_no + 1;

		PRINT(@SQL);

		SET @SQL = '';
	END
END