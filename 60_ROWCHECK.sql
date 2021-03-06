USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_60_ROWCHECK]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_60_ROWCHECK]
AS 

BEGIN 
Declare @rptdate varchar(20) 

set @rptdate = (SELECt rptdate FROM DBS_REF.DBO.RPTDATE)

EXEC('
	DELETE FROM [DATA].[dbo].[DAILY_ROW_CHECKING]
	WHERE RPTDATE = '''+@rptdate+'''
	')
EXEC ('
	SELECT 
		'''+@rptdate+''' as Rptdate , 
		o.name as TABLE_NAME_DAILY,
		ddps.row_count as count, 
		Case when right(o.name,8) like ''[0-9]%'' then left(o.name , len(o.name) - 9) ELSE o.name END as TABLE_NAME
	INTO #row_checking 
	FROM sys.indexes AS i
	  INNER JOIN sys.objects AS o ON i.OBJECT_ID = o.OBJECT_ID
	  INNER JOIN sys.dm_db_partition_stats AS ddps ON i.OBJECT_ID = ddps.OBJECT_ID
	  AND i.index_id = ddps.index_id 
	WHERE i.index_id < 2  AND o.is_ms_shipped = 0 
	ORDER BY o.NAME 

	insert into [DATA].[dbo].[DAILY_ROW_CHECKING]	
	select  a.* , b.TABLE_TYPE
	from #row_checking 	a 
		INNER JOIN DBS_REF.DBO.ARCHIVE_LIST B ON A.TABLE_NAME = B.TABLE_NAME 
	WHERE 
		(RIGHT(TABLE_NAME_DAILY, 8)  = RPTDATE AND TABLE_TYPE = ''DAILY'')
		OR TABLE_TYPE = ''ACCUMULATED''

') 
END 
GO
