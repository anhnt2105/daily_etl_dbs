USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_10_AUTH_SESSION_INFO]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_10_AUTH_SESSION_INFO]
AS 

BEGIN 

DECLARE @TODATE VARCHAR(8), @STDATE VARCHAR(8)
DECLARE @TDLAST6MONTH varchar(20), @LASTMONTH VARCHAR(20) 

---SET @TODATE = '20171111' 
SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )
SET @STDATE =  CONVERT(VARCHAR(8),DATEADD(d,-7, @TODATE),112)
SET @LASTMONTH  = (SELECT MAX(RPTDATE) FROM DBS_REF..Calendar WHERE LEFT(RptDate,6) < LEFT(@TODATE,6) )

-------------------------------------------------------------------------------------------------
-- 11. BANG TBL_I2B_AUTH_INFO
PRINT '10. BANG TBL_I2B_AUTH_INFO'

/*****
if exists(select * from DBS_dAILY.INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'TBL_I2B_AUTH_INFO')
begin 
	exec(' drop table DBS_dAILY.DBO.TBL_I2B_AUTH_INFO')
end 
EXEC('
	CREATE TABLE [DBS_dAILY].[dbo].[TBL_I2B_AUTH_INFO](
		[SYSID] [bigint] NOT NULL,
		[CHANNEL_RQ] [varchar](10) NOT NULL,
		[CUS_CIF] [varchar](20) NOT NULL,
		[TIME_RQ] [date] NULL,
		[USER_NAME] [varchar](255) NULL,
		[DEVICE_CODE] [varchar](50) NULL,
		[AMND_STATUS] [varchar](3) NOT NULL)

') 
******/

----exec('
----	INSERT INTO DATA.DBO.TBL_I2B_AUTH_INFO_HIS
----	SELECT A.*
----	FROM M108.BICDATA_HIS.DBO.DAILY_I2B_AUTH_INFO A 
----		LEFT JOIN DATA.DBO.TBL_I2B_AUTH_INFO_HIS B ON A.SYSID = B.SYSID
----	WHERE B.SYSID IS NULL 
----		AND A.TIME_RQ >= ''20170101''
----')
--EXEC('
--	DROP INDEX [IDX_TMRQ] ON [dbo].[TBL_I2B_AUTH_INFO]
--	DROP INDEX IDX_USERID ON [dbo].[TBL_I2B_AUTH_INFO]
--	DROP INDEX IDX_USERNAME ON [dbo].[TBL_I2B_AUTH_INFO]
--	')

exec('
	DELETE FROM DBS_dAILY.DBO.TBL_I2B_AUTH_INFO
	WHERE TIME_RQ >= CAST(  '''+@STDATE+''' AS DATETIME )
	')
EXEC
('
	INSERT INTO DBS_dAILY.DBO.TBL_I2B_AUTH_INFO
	SELECT SYSID, CHANNEL_RQ, CUS_CIF,CONVERT(DATE,TIME_RQ) TIME_RQ, USER_NAME, DEVICE_CODE, AMND_STATUS		
	from m108.bicdata_his.dbo.daily_i2b_auth_info
	where TIME_RQ < cast('''+@TODATE+''' as datetime)  + 1
	AND TIME_RQ >=  CAST(  '''+@STDATE+''' AS DATETIME )


	INSERT INTO DBS_dAILY.DBO.TBL_I2B_AUTH_INFO
		(SYSID, CHANNEL_RQ, CUS_CIF,TIME_RQ, USER_NAME, DEVICE_CODE, AMND_STATUS)
	SELECT 
		TRAN_ID SYSID, 
		(CASE WHEN CHANNEL = ''Web'' THEN ''i2b'' ELSE CHANNEL END) CHANNEL_RQ, 
		A.CUST_ID CUS_CIF, CONVERT(DATE,LOG_DATE) TIME_RQ,
		SUBSTRING(B.DESCRIPTION,6,(LEN(B.DESCRIPTION)-16)) USER_NAME, ''OCB'' DEVICE_CODE, ''A'' AMND_STATUS
	FROM data.dbo.DAILY_EB_CUSTOMER_DIRECTORY A
			inner join DATA.dbo.DAILY_EB_AUDIT_LOG B on CONVERT(VARCHAR,A.DIRECTORY_ID) = CONVERT(VARCHAR,B.[USER_ID])
	--where convert(varchar(8), cast(log_date as date), 112) >= '''+@STDATE+'''
	--and convert(varchar(8), cast(log_date as date), 112) <= '''+@TODATE+'''

	where log_Date < dateadd(d,1,'''+@TODATE+''')
			and log_Date >=  CAST(  '''+@STDATE+''' AS DATETIME )
			AND B.TRAN_TYPE = ''3201''
			AND CHANNEL IN (''Web'',''MOBILE'',''VPBANKPLUS'')

')

--exec('
--	CREATE NONCLUSTERED INDEX [IDX_USERID] 
--	ON DBS_dAILY.DBO.TBL_I2B_AUTH_INFO ([CUS_CIF] ASC)

--	CREATE NONCLUSTERED INDEX [IDX_TMRQ] 
--	ON DBS_dAILY.DBO.TBL_I2B_AUTH_INFO ([TIME_RQ] ASC)
--	') 
/*
SELECT * 
INTO DATA..DAILY_EB_AUDIT_LOG
 from M16.VPB_whr2.dbo.tbl_EB_AUDIT_LOG B 
 where convert(varchar(8),cast(LOG_DATE as date),112) between '20170101' and '20170920' 
 */
-------------------------------------------------------------------------------------------------
-- 12. BANG TBL_B2B_SESSION_INFO  
          
PRINT '11. BANG TBL_B2B_SESSION_INFO'
if exists(select * from DBS_dAILY.INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'TBL_B2B_SESSION_INFO')
begin 
	exec(' drop table DBS_dAILY.DBO.TBL_B2B_SESSION_INFO')
end 
EXEC('
	CREATE TABLE [DBS_dAILY].[dbo].[TBL_B2B_SESSION_INFO](
	[SESSION_ID] [varchar](120) NOT NULL,
	[CLIENT_RQ] [varchar](30) NOT NULL,
	[CHANNEL_RQ] [varchar](10) NOT NULL,
	[USER_NAME] [varchar](50) NOT NULL,
	[CUST_CIF] [varchar](50) NOT NULL,
	[LOGIN_TIME] [datetime] NOT NULL,
	[LAST_ACTIVE_TIME] [datetime] NOT NULL,
	[LOGIN_STATUS] [varchar](10) NULL) 
')

EXEC
('
	INSERT INTO DBS_dAILY.DBO.TBL_B2B_SESSION_INFO
	SELECT * 
		 FROM m108.bicdata_his.dbo.DAILY_B2B_SESSION_INFO
			  WHERE CONVERT(VARCHAR(8),LOGIN_TIME,112) BETWEEN '''+@STDATE+''' AND '''+@TODATE+'''
	UNION ALL 
	SELECT * 
	FROM DBS_MONTHLY.DBO.TBL_B2B_SESSION_INFO_'+@LASTMONTH+'
	WHERE CONVERT(VARCHAR(8),LOGIN_TIME,112) <= '''+@LASTMONTH+'''

')
EXEC('
	CREATE NONCLUSTERED INDEX [IDX_USERID] 
	ON DBS_dAILY.DBO.TBL_B2B_SESSION_INFO ([CUST_CIF] ASC)

	CREATE NONCLUSTERED INDEX [IDX_USERNAME] 
	ON DBS_dAILY.DBO.TBL_B2B_SESSION_INFO ([USER_NAME] ASC)

	CREATE NONCLUSTERED INDEX [IDX_TMRQ] 
	ON DBS_dAILY.DBO.TBL_B2B_SESSION_INFO ([LOGIN_TIME] ASC)
') 

end 



GO
