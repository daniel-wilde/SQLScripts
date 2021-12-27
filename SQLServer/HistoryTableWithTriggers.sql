IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.pCreateHistoryTriggers') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.pCreateHistoryTriggers
GO

CREATE PROCEDURE dbo.pCreateHistoryTriggers (
	@TableNameWithSchema nvarchar(max)
	)
As

If OBJECT_ID(@TableNameWithSchema)>0 
Begin
	Declare @TableName nvarchar(max) Set @TableName=RIGHT(@TableNameWithSchema,charindex('.',reverse(@TableNameWithSchema),0)-1)

	Declare @HistoryTableNameWithSchema nvarchar(max) set @HistoryTableNameWithSchema=@TableNameWithSchema+'History'
	Declare @HistoryTableName nvarchar(max) Select @HistoryTableName=RIGHT(@HistoryTableNameWithSchema,charindex('.',reverse(@HistoryTableNameWithSchema),0)-1)

	Declare @HistoryColumns nvarchar(max)
	Declare @HistoryColumnsWithDataType nvarchar(max)
	Declare @HistoryColumnsSQL nvarchar(max)
	Declare @HistoryTable nvarchar(max)

	Select @HistoryColumnsWithDataType=Stuff((select ', '+c.name+' '+t.name+case 
		when t.name in ('binary', 'varbinary','bigint', 'tinyint', 'bit','int','datetime','money','float') then ''
		when c.max_length='-1' then ' (max)'
		else ' ('+cast(c.max_length as varchar)+')'
		end
		+case when c.is_nullable=1 then ' NULL' else ' NOT NULL' end
	from sys.columns c
	Left join sys.types t on c.system_type_id=t.system_type_id
	where object_id=object_id(@TableNameWithSchema)
	for XML Path('')
	),1,2,'')

	Select @HistoryColumns=Stuff((select ', '+c.name
	from sys.columns c
	Left join sys.types t on c.system_type_id=t.system_type_id
	where object_id=object_id(@TableNameWithSchema)
	for XML Path('')
	),1,1,'')


	select @HistoryColumnsSQL='HistoryID int NOT NULL Identity(1,1)'
		+', HistoryTranType int NOT NULL'
		+', '+@HistoryColumnsWithDataType
		+' CONSTRAINT PK_'+@HistoryTableName+' PRIMARY KEY (HistoryID)'
		
	Select @HistoryTable='Create Table '+@HistoryTableNameWithSchema+' ('+@HistoryColumnsSQL+')'

	--- Create History Table
	Exec SP_ExecuteSQL @HistoryTable,N''

	Declare @TriggerSQL nvarchar(max)
	Declare @TriggerName nvarchar(max),@TriggerFromTable nvarchar(max),@TriggerForType nvarchar(max)
	Declare @i int Select @i=1
	While @i<4 Begin
		
		Select @TriggerName='[dbo].[trg'+@TableName+'_'+case @i when 1 then 'i' when 2 then 'u' when 3 then 'd' end+']'
		Select @TriggerForType=case @i when 1 then 'Insert' when 2 then 'Update' when 3 then 'Delete' end
		Select @TriggerFromTable=case @i 
					when 1 then 'Inserted'
					when 2 then 'Inserted'
					when 3 then 'Deleted'
					End
		
		Select @TriggerSQL=
		'CREATE TRIGGER '+@TriggerName+' ON '+@TableNameWithSchema+'
		FOR '+@TriggerForType+' AS'
		+case when @i=2 then ' IF UPDATE(Version) OR UPDATE(UpdateDate)' else '' end+' BEGIN
			SET NOCOUNT ON
			INSERT INTO '+@HistoryTableNameWithSchema+' (
			HistoryTranType,'
			+@HistoryColumns+'
			)
			SELECT
				'+cast(@i as nvarchar)+','
				+Replace(@HistoryColumns,'UpdateDate','GetDate()')+'
			FROM '+@TriggerFromTable+' SET NOCOUNT OFF
		END
		'
		
		---- Create Trigger
		Exec(@TriggerSQL)
		
		Set @i=@i+1
	End
End
	
GO

BEGIN TRAN

/**** Example Call ****/
	Exec dbo.pCreateHistoryTriggers 'dbo.Config'
	Exec dbo.pCreateHistoryTriggers 'dbo.ConfigStation'
	Exec dbo.pCreateHistoryTriggers 'dbo.ConfigRecipeParameter'
/***********************/

--COMMIT
ROLLBACK

--- Remove this proc from the environment ---
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.pCreateHistoryTriggers') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.pCreateHistoryTriggers
GO