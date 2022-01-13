--INFORMATION SCHEMA / SP_SPACEUSED / QUERY FOR ALL TABLES / ALT-F1
	SELECT * 
	FROM INFORMATION_SCHEMA.TABLES T
		INNER JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
			AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
	--WHERE c.COLUMN_NAME LIKE '%MANAGER%'
	ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION
	GO

--ALL SCHEMA OBJECTS CREATION
	--TABLES, PROCS, ETC
	IF OBJECT_ID('TempDB..##Test') IS NOT NULL
	BEGIN
		DROP TABLE ##Test
	END

	CREATE TABLE ##Test (ID INT IDENTITY(1,1), FirstName VARCHAR(100))
	INSERT INTO ##Test(FirstName)
	SELECT FirstName FROM Person.Person
	GO

	--STORED PROCEDURE
	-- uspLogError logs error information in the ErrorLog table about the 
	-- error that caused execution to jump to the CATCH block of a 
	-- TRY...CATCH construct. This should be executed from within the scope 
	-- of a CATCH block otherwise it will return without inserting error 
	-- information. 
	CREATE PROCEDURE [dbo].[uspLogError] 
		@ErrorLogID [int] = 0 OUTPUT -- contains the ErrorLogID of the row inserted
	AS                               -- by uspLogError in the ErrorLog table
	BEGIN
		SET NOCOUNT ON;

		-- Output parameter value of 0 indicates that error 
		-- information was not logged
		SET @ErrorLogID = 0;

		BEGIN TRY
			-- Return if there is no error information to log
			IF ERROR_NUMBER() IS NULL
				RETURN;

			-- Return if inside an uncommittable transaction.
			-- Data insertion/modification is not allowed when 
			-- a transaction is in an uncommittable state.
			IF XACT_STATE() = -1
			BEGIN
				PRINT 'Cannot log error since the current transaction is in an uncommittable state. ' 
					+ 'Rollback the transaction before executing uspLogError in order to successfully log error information.';
				RETURN;
			END

			INSERT [dbo].[ErrorLog] 
				(
				[UserName], 
				[ErrorNumber], 
				[ErrorSeverity], 
				[ErrorState], 
				[ErrorProcedure], 
				[ErrorLine], 
				[ErrorMessage]
				) 
			VALUES 
				(
				CONVERT(sysname, CURRENT_USER), 
				ERROR_NUMBER(),
				ERROR_SEVERITY(),
				ERROR_STATE(),
				ERROR_PROCEDURE(),
				ERROR_LINE(),
				ERROR_MESSAGE()
				);

			-- Pass back the ErrorLogID of the row inserted
			SET @ErrorLogID = @@IDENTITY;
		END TRY
		BEGIN CATCH
			PRINT 'An error occurred in stored procedure uspLogError: ';
			EXECUTE [dbo].[uspPrintError];
			RETURN -1;
		END CATCH
	END;
	GO

	--TRY / CATCH
	CREATE PROCEDURE [HumanResources].[uspUpdateEmployeeHireInfo]
		@BusinessEntityID [int], 
		@JobTitle [nvarchar](50), 
		@HireDate [datetime], 
		@RateChangeDate [datetime], 
		@Rate [money], 
		@PayFrequency [tinyint], 
		@CurrentFlag [dbo].[Flag] 
	WITH EXECUTE AS CALLER
	AS
	BEGIN
		SET NOCOUNT ON;

		BEGIN TRY
			BEGIN TRANSACTION;

			UPDATE [HumanResources].[Employee] 
			SET [JobTitle] = @JobTitle 
				,[HireDate] = @HireDate 
				,[CurrentFlag] = @CurrentFlag 
			WHERE [BusinessEntityID] = @BusinessEntityID;

			INSERT INTO [HumanResources].[EmployeePayHistory] 
				([BusinessEntityID]
				,[RateChangeDate]
				,[Rate]
				,[PayFrequency]) 
			VALUES (@BusinessEntityID, @RateChangeDate, @Rate, @PayFrequency);

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			-- Rollback any active or uncommittable transactions before
			-- inserting information in the ErrorLog
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END

			EXECUTE [dbo].[uspLogError];
		END CATCH;
	END;
	GO


	--VIEWS (INDEXED / PERSISTED / MATERIALIZED VIEW)
	CREATE VIEW [Person].[vAdditionalContactInfo] 
	AS 
	SELECT 
		[BusinessEntityID] 
		,[FirstName]
		,[MiddleName]
		,[LastName]
		,[rowguid] 
		,[ModifiedDate]
	FROM [Person].[Person]
	WHERE [LastName] IS NOT NULL;
	GO

	--FUNCTIONS (SCALAR, IN-LINE, MULTI-STATEMENT)
	--SCALAR
	CREATE FUNCTION [dbo].[ufnGetAccountingEndDate]()
	RETURNS [datetime] 
	AS 
	BEGIN
		RETURN DATEADD(millisecond, -2, CONVERT(datetime, '20040701', 112));
	END;
	GO

	--TABLE FUNCTION
	CREATE FUNCTION [dbo].[ufnGetContactInformation](@PersonID int)
	RETURNS @retContactInformation TABLE 
	(
		-- Columns returned by the function
		[PersonID] int NOT NULL, 
		[FirstName] [nvarchar](50) NULL, 
		[LastName] [nvarchar](50) NULL, 
		[JobTitle] [nvarchar](50) NULL,
		[BusinessEntityType] [nvarchar](50) NULL
	)
	AS 
	-- Returns the first name, last name, job title and business entity type for the specified contact.
	-- Since a contact can serve multiple roles, more than one row may be returned.
	BEGIN
		IF @PersonID IS NOT NULL 
			BEGIN
				IF EXISTS(SELECT * FROM [HumanResources].[Employee] e 
						WHERE e.[BusinessEntityID] = @PersonID) 
				INSERT INTO @retContactInformation
					SELECT @PersonID, p.FirstName, p.LastName, e.[JobTitle], 'Employee'
					FROM [HumanResources].[Employee] AS e
						INNER JOIN [Person].[Person] p
						ON p.[BusinessEntityID] = e.[BusinessEntityID]
					WHERE e.[BusinessEntityID] = @PersonID;
			END
		RETURN;
	END;
	GO

	--INLINE TABLE VALUED FUNCTION
	CREATE FUNCTION [dbo].[udfGetProductList]
	(@SafetyStockLevel SMALLINT
	)
	RETURNS TABLE
	AS
	RETURN
	(SELECT Product.ProductID, 
			Product.Name, 
			Product.ProductNumber
	 FROM Production.Product
	 WHERE SafetyStockLevel >= @SafetyStockLevel)
	 GO

	--TABLE-TYPE PARAMETERS
	--INDEX CREATION / SEQUENCES
	ALTER TABLE [Person].[Person] ADD  CONSTRAINT [PK_Person_BusinessEntityID] PRIMARY KEY CLUSTERED 
	(
		[BusinessEntityID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	GO

	--SYNONYMS
	--TRIGGERS
	CREATE TRIGGER [Person].[iuPerson] ON [Person].[Person] 
	AFTER INSERT, UPDATE NOT FOR REPLICATION AS 
	BEGIN
		DECLARE @Count int;

		SET @Count = @@ROWCOUNT;
		IF @Count = 0 
			RETURN;

		SET NOCOUNT ON;

		IF UPDATE([BusinessEntityID]) OR UPDATE([Demographics]) 
		BEGIN
			UPDATE [Person].[Person] 
			SET [Person].[Person].[Demographics] = N'<IndividualSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"> 
				<TotalPurchaseYTD>0.00</TotalPurchaseYTD> 
				</IndividualSurvey>' 
			FROM inserted 
			WHERE [Person].[Person].[BusinessEntityID] = inserted.[BusinessEntityID] 
				AND inserted.[Demographics] IS NULL;
        
			UPDATE [Person].[Person] 
			SET [Demographics].modify(N'declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"; 
				insert <TotalPurchaseYTD>0.00</TotalPurchaseYTD> 
				as first 
				into (/IndividualSurvey)[1]') 
			FROM inserted 
			WHERE [Person].[Person].[BusinessEntityID] = inserted.[BusinessEntityID] 
				AND inserted.[Demographics] IS NOT NULL 
				AND inserted.[Demographics].exist(N'declare default element namespace 
					"http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"; 
					/IndividualSurvey/TotalPurchaseYTD') <> 1;
		END;
	END;
	GO

	ALTER TABLE [Person].[Person] ENABLE TRIGGER [iuPerson]
	GO

--DATA TYPES / TIMESTAMP / ROWVERSION

--ALL JOINS / CROSS JOIN
--INNER / OUTER APPLY

	--UPDATE Person.EmailAddress 
	--SET BusinessEntityID = BusinessEntityID - 19000
	--WHERE BusinessEntityID BETWEEN 19001 AND 19020

	SET STATISTICS IO ON 
	SET STATISTICS TIME ON 

	SELECT t.*
	FROM
	(
		SELECT p.BusinessEntityID
			,a.EmailAddress
			,a.EmailAddressID
			,ROW_NUMBER() OVER (PARTITION BY p.BusinessEntityID ORDER BY a.EmailAddressID DESC) AS RowNum
		FROM Person.Person p
			LEFT OUTER JOIN Person.EmailAddress a ON p.BusinessEntityID = a.BusinessEntityID
	) t
	WHERE RowNum = 1
	ORDER BY t.BusinessEntityID ASC

	SELECT p.BusinessEntityID
		,a.EmailAddress
		,a.EmailAddressID
	FROM Person.Person p
		--CROSS APPLY 
		OUTER APPLY 
		(
			SELECT TOP 1 EmailAddressID, EmailAddress
			FROM Person.EmailAddress
			WHERE BusinessEntityID = p.BusinessEntityID
			ORDER BY EmailAddressID DESC
		) a
	ORDER BY p.BusinessEntityID ASC

	--NOT EXISTS
	SELECT p.BusinessEntityID
	FROM Person.Person p
	WHERE NOT EXISTS
		(
			SELECT TOP 1 BusinessEntityID
			FROM Person.EmailAddress
			WHERE BusinessEntityID = p.BusinessEntityID
		)
	ORDER BY p.BusinessEntityID ASC

--RECURSIVE CTE
	WITH Emp_CTE AS 
	(
		SELECT EmployeeID, ContactID, LoginID, ManagerID, Title, BirthDate
		FROM HumanResources.Employee
		WHERE ManagerID IS NULL
		UNION ALL
		SELECT e.EmployeeID, e.ContactID, e.LoginID, e.ManagerID, e.Title, e.BirthDate
		FROM HumanResources.Employee e
		INNER JOIN Emp_CTE ecte ON ecte.EmployeeID = e.ManagerID
	)
	SELECT *
	FROM Emp_CTE
	GO

--AGGREGATE FUNCTIONS / WINDOWING FUNCTIONS / NEW 2017/2019 FUNCTIONS / LEAD-LAG
	ROW_NUMBER, RANK, DENSE_RANK, NTILE
	LAG		--ROW AFTER / BELOW
	LEAD	--ROW BEFORE / ABOVE

--PIVOT / UNPIVOT
--NULL HANDLING / DIV BY 0
--MERGE STATEMENT

--DYNAMIC SQL
	DECLARE @table NVARCHAR(128),
		@sql NVARCHAR(MAX);

	SET @table = N'Person.Person';
	SET @sql = N'SELECT * FROM ' + @table;
	EXEC sp_executesql @sql;


--TRY / CATCH / THROW / RAISERROR
--GLOBAL TEMP TABLE / TEMP TABLES / TEMPDB
--XML / JSON PARSING

--STRING CONCATENATION
	SELECT DISTINCT CategoryId, ProductNames
	FROM Northwind.dbo.Products p1
	CROSS APPLY 
	( 
		SELECT ProductName + ',' 
		FROM Northwind.dbo.Products p2
		WHERE p2.CategoryId = p1.CategoryId 
		ORDER BY ProductName 
		FOR XML PATH('') 
	) D ( ProductNames )

--EXECUTION PLAN DETAILS
--DMVS
--USER / LOGIN CREATION / USER PERMS QUERIES
--ISOLATION LEVELS

	SET TRANSACTION ISOLATION LEVEL
		--READ UNCOMMITTED
		READ COMMITTED
		--REPEATABLE READ
		--SNAPSHOTcam
		--SERIALIZABLE
    
--PARTITIONING
--REPLICATION
--SYSTEM DATABASES
	use master	--Records all the system-level information for an instance of SQL Server
	use model	--The model database is used as the template for all databases created on an instance of SQL Server
	use msdb	--Is used by SQL Server Agent for scheduling alerts and jobs and by other features such as SQL Server Management Studio, Service Broker and Database Mail
	use tempdb	--Is a workspace for holding temporary objects or intermediate result sets

--SSISDB QUERIES

--SSIS SOLUTION / SSIS PACKAGES / ETL QUESTIONS FROM ONLINE
--READ JOB DESCRIPTION / ASK ABOUT TEST / LIST OF QUESTIONS FROM ONLINE TO GET IDEAS:
	
	--MATERIALIZED VIEWS
	--COLUMNSTORE INDEX DESIGN / LOADING / ANALYSIS
	--REPLICATION

	--AWS or Azure Database Services 
	--Embedded Python and R scripting in SQL Server stored procedures 
	--Experience with Apache Spark 
	--Experience with data science workflow and tools (SciKit, Numpy, Tensorflow) 