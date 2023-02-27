Select A.[object_id]
 , OBJECT_NAME(A.[object_id]) AS Table_Name
 , A.Index_ID
 , A.[Name] As Index_Name
 , CAST(
 Case When A.type = 1 AND is_unique = 1 Then 'Create Unique Clustered Index '
 When A.type = 1 AND is_unique = 0 Then 'Create Clustered Index '
 When A.type = 2 AND is_unique = 1 Then 'Create Unique NonClustered Index '
 When A.type = 2 AND is_unique = 0 Then 'Create NonClustered Index '
 End
 + quotename(A.[Name]) + ' On ' + quotename(S.name) + '.' + quotename(OBJECT_NAME(A.[object_id])) + ' ('
 + Stuff(
 (
 Select
 ',[' + COL_NAME(A.[object_id],C.column_id)
 + Case When C.is_descending_key = 1 Then '] Desc' Else '] Asc' End
 From sys.index_columns C WITH (NOLOCK)
 Where A.[Object_ID] = C.object_id
 And A.Index_ID = C.Index_ID
 And C.is_included_column = 0
 Order by C.key_Ordinal Asc
 For XML Path('')
 )
 ,1,1,'') + ') '
 
 + CASE WHEN A.type = 1 THEN ''
 ELSE Coalesce('Include ('
 + Stuff(
 (
 Select
 ',' + QuoteName(COL_NAME(A.[object_id],C.column_id))
 From sys.index_columns C WITH (NOLOCK)
 Where A.[Object_ID] = C.object_id
 And A.Index_ID = C.Index_ID
 And C.is_included_column = 1
 Order by C.index_column_id Asc
 For XML Path('')
 )
 ,1,1,'') + ') '
 ,'') End
 + Case When A.has_filter = 1 Then 'Where ' + A.filter_definition Else '' End
 + ' With (Drop_Existing = ON, SORT_IN_TEMPDB = ON'
 --when the same index exists you'd better to set the Drop_Existing = ON
 --SORT_IN_TEMPDB = ON is recommended but based on your own environment.
 + ', Fillfactor = ' + Cast(Case When fill_factor = 0 Then 100 Else fill_factor End As varchar(3)) 
 + Case When A.[is_padded] = 1 Then ', PAD_INDEX = ON' Else ', PAD_INDEX = OFF' END
 + Case When D.[no_recompute] = 1 Then ', STATISTICS_NORECOMPUTE = ON' Else ', STATISTICS_NORECOMPUTE = OFF' End 
 + Case When A.[ignore_dup_key] = 1 Then ', IGNORE_DUP_KEY = ON' Else ', IGNORE_DUP_KEY = OFF' End
 + Case When A.[ALLOW_ROW_LOCKS] = 1 Then ', ALLOW_ROW_LOCKS = ON' Else ', ALLOW_ROW_LOCKS = OFF' END
 + Case When A.[ALLOW_PAGE_LOCKS] = 1 Then ', ALLOW_PAGE_LOCKS = ON' Else ', ALLOW_PAGE_LOCKS = OFF' End 
 + Case When P.[data_compression] = 0 Then ', DATA_COMPRESSION = NONE' 
 When P.[data_compression] = 1 Then ', DATA_COMPRESSION = ROW' 
 Else ', DATA_COMPRESSION = PAGE' End 
 + ') On ' 
 + Case when C.type = 'FG' THEN quotename(C.name) 
 ELSE quotename(C.name) + '(' + F.Partition_Column + ')' END + ';' --if it uses partition scheme then need partition column
 As nvarchar(Max)) As Index_Create_Statement
 , C.name AS FileGroupName
 , 'DROP INDEX ' + quotename(A.[Name]) + ' On ' + quotename(S.name) + '.' + quotename(OBJECT_NAME(A.[object_id])) + ';' AS Index_Drop_Statement
From SYS.Indexes A WITH (NOLOCK)
 INNER JOIN
 sys.objects B WITH (NOLOCK)
 ON A.object_id = B.object_id
 INNER JOIN 
 SYS.schemas S
 ON B.schema_id = S.schema_id 
 INNER JOIN
 SYS.data_spaces C WITH (NOLOCK)
 ON A.data_space_id = C.data_space_id 
 INNER JOIN
 SYS.stats D WITH (NOLOCK)
 ON A.object_id = D.object_id
 AND A.index_id = D.stats_id 
 Inner Join
 --The below code is to find out what data compression type was used by the index. If an index is not partitioned, it is easy as only one data compression
 --type can be used. If the index is partitioned, then each partition can be configued to use the different data compression. This is hard to generalize,
 --for simplicity, I just use the data compression type used most for the index partitions for all partitions. You can later rebuild the index partition to
 --the appropriate data compression type you want to use
 (
 select object_id, index_id, Data_Compression, ROW_NUMBER() Over(Partition By object_id, index_id Order by COUNT(*) Desc) As Main_Compression
 From sys.partitions WITH (NOLOCK)
 Group BY object_id, index_id, Data_Compression
 ) P
 ON A.object_id = P.object_id
 AND A.index_id = P.index_id
 AND P.Main_Compression = 1
 Outer APPLY
 (
 SELECT COL_NAME(A.object_id, E.column_id) AS Partition_Column
 From sys.index_columns E WITH (NOLOCK)
 WHERE E.object_id = A.object_id
 AND E.index_id = A.index_id
 AND E.partition_ordinal = 1
 ) F 
Where 
	--A.type IN (1,2) --clustered and nonclustered
	A.type IN (2) --nonclustered
 AND B.Type != 'S'
 AND OBJECT_NAME(A.[object_id]) not like 'queue_messages_%'
 AND OBJECT_NAME(A.[object_id]) not like 'filestream_tombstone_%'
 AND OBJECT_NAME(A.[object_id]) not like 'sqlagent_%'
 AND OBJECT_NAME(A.[object_id]) not like 'plan_%'
 AND OBJECT_NAME(A.[object_id]) not like 'sys%' --if you have index start with sys then remove it