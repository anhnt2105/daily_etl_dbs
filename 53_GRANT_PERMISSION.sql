USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_53_GRANT_PERMISSION]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create proc [dbo].[PR_DAILY_ETL_53_GRANT_PERMISSION] AS 
BEGIN

declare @string_1 varchar(max),
	@string_2 varchar(max),
	@string_3 varchar(max)

set @string_1 = ''
set @string_2 = ''

SELECT 
	@string_1 += 'use ' + TABLE_CATALOG + char(10) + 'grant select on ' + table_schema + '.' + a.table_name + ' to bidata_user' + char(10) 
FROM DBS_DAILY.INFORMATION_SCHEMA.TABLES  a 
cross apply(
	SELECT table_name  as table_name
	FROM DBS_REF.DBO.GRANTED_TABLE_LIST  b 
	WHERE PARTNER_NAME = 'BI_DATA'
	and a.TABLE_NAME like b.table_name + '%'
	) x 

SELECT
	@string_2 += 'use ' + database_name + char(10) + 'grant select on dbo.'+ table_name + ' to bidata_user' + char(10)
FROM DBS_REF.DBO.GRANTED_TABLE_LIST  b 
WHERE PARTNER_NAME = 'BI_DATA'
and DATABASE_NAME in ('DBS_SUMMARY', 'DATA', 'DBS_MONTHLY') 

exec(@string_1) 
exec(@string_2) 


END 
GO
