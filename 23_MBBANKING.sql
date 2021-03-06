USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_23_MBBANKING]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_23_MBBANKING]
AS 
BEGIN 

DECLARE @TODATE VARCHAR(8)
SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )
---Set @todate = '20170921' 

---------------------------------------------------------------------------------------------------

PRINT '6. BANG I2B_MBANKING_ACC'
exec('
IF EXISTS (SELECT * FROM SYSOBJECTS WHERE NAME = ''TBL_I2B_MBANKING_ACC_'+@TODATE+''')
	DROP TABLE [TBL_I2B_MBANKING_ACC_'+@TODATE+']
	')
EXEC('
	CREATE TABLE [TBL_I2B_MBANKING_ACC_'+@TODATE+'](
		[ROWID] [bigint] NULL,
		[SOURCE] [varchar](3) NOT NULL,
		[SYS_ID] [bigint] NOT NULL,
		[CHANNEL] [varchar](10) NULL,
		[T24_CIF] [nvarchar](50) not NULL,
		[ACTIVE_CODE] [varchar](500) NULL,
		[REGISTER_DATE] [datetime] NULL,
		[ACTIVE_DATE] [datetime] NULL,
		[AMND_STATE] [varchar](1) NULL,
		[PROCESS_STATUS] [varchar](3) NULL,
		[CIF_INTRODUCER] [varchar](50) NULL,
		[BUSINESS_DATE] [date] NULL,
		[ETL_TIME] [datetime] NULL
		CONSTRAINT [PK_MBB_CIF_'+@TODATE+'] PRIMARY KEY CLUSTERED 	([T24_CIF] ASC)	
	)
')

EXEC('
	DROP TABLE IF EXISTS ##OCB_NEW
	SELECt * 
	INTO ##OCB_NEW
	FROM 
	(
	SELECT ROW_NUMBER() OVER (PARTITION BY CIF ORDER BY CREATE_DATE, TERMS_ACCEPTED DESC) AS ROWID,*
			FROM DATA.DBO.OCB_NEW	
		) A  
	WHERE ROWID = 1 
	AND (TERMS_ACCEPTED = 0 or ACCOUNT_STATUS IN (2,8)) 
') 

exec
('
	INSERT TBL_I2B_MBANKING_ACC_'+@TODATE+' (ROWID, SOURCE,SYS_ID, CHANNEL, T24_CIF, ACTIVE_CODE, REGISTER_DATE, ACTIVE_DATE, AMND_STATE, PROCESS_STATUS, CIF_INTRODUCER)
	SELECT 
		''1'' ROWID,''OCB'', a.SYS_ID, a.CHANNEL, a.T24_CIF, a.ACTIVE_CODE, 
		a.REGISTER_DATE, a.ACTIVE_DATE, ''A'' AMND_STATE,''FIN'' PROCESS_STATUS, a.CIF_INTRODUCER
	FROM DATA.DBO.TBL_EB_MBBANKING_ACC A 
	--FROM m108.bicdata_his.dbo.Daily_EB_MBBANKING_ACC A 
	--FROM M16.VPB_WHR2.dbo.TBL_EB_MBBANKING_ACC
	WHERE a.AMND_STATE = ''1''
		AND CONVERT(VARCHAR(8),a.REGISTER_DATE,112) <= '''+@TODATE+'''	 
		AND EXISTS (SELECT RECID FROM CUSTOMER_'+@TODATE+'  c 
					WHERE (BI_CHANNEL <> ''OTHER'' 
						OR SEGMENT IN (''SMEs'',''CIB'',''CMB'') 
						OR COMPANY_BOOK = ''VN0010344'' ----HOUSEHOLD 
						OR (COMPANY_BOOK  = ''VN0010348'' AND CUST_TYPE IN (''59'',''60'')) ---TIMO 
						OR COMPANY_BOOK = ''VN0010260'' ----FE CREDIT
						) 
					AND CONVERT(VARCHAR(8),CUS_OPEN_DATE,112) <= '''+@TODATE+'''
					and a.T24_CIF = c.recid)
		AND NOT EXISTS (SELECT * FROM ##OCB_NEW C WHERE A.T24_CIF = C.CIF)
') 

exec
('
	-- TBL_I2B_MBANKING_ACC
	insert INTO TBL_I2B_MBANKING_ACC_'+@TODATE+'
	SELECT * 	
	FROM 
		(
		SELECT ROW_NUMBER() OVER (PARTITION BY T24_CIF ORDER BY REGISTER_DATE DESC,ETL_TIME DESC) AS ROWID,''I2B'' SOURCE,*
		FROM DATA.DBO.TBL_I2B_MBANKING_ACC
			--FROM m108.bicdata_his.dbo.Daily_I2B_MBANKING_ACC
		WHERE CONVERT(VARCHAR(8),REGISTER_DATE,112) <= '''+@TODATE+'''	
			AND AMND_STATE IN (''A'')
			AND PROCESS_STATUS = ''FIN''
		) B
	WHERE ROWID = 1
		AND EXISTS (SELECT RECID FROM CUSTOMER_'+@TODATE+'  c 
					WHERE (BI_CHANNEL <> ''OTHER'' 
						OR SEGMENT IN (''SMEs'',''CIB'',''CMB'') 
						oR COMPANY_BOOK = ''VN0010344''
						OR (COMPANY_BOOK  = ''VN0010348'' AND CUST_TYPE IN (''59'',''60''))
						OR COMPANY_BOOK = ''VN0010260''
						) 
					AND CONVERT(VARCHAR(8),CUS_OPEN_DATE,112) <= '''+@TODATE+'''
					and b.T24_CIF = c.recid)
		AND NOT EXISTS (SELECt t24_cif FROM TBL_I2B_MBANKING_ACC_'+@TODATE+' D  WHERE B.t24_cif = D.t24_cif)
		AND EXISTS (SELECt t24_cif FROM DBS_dAILY.DBO.TBL_I2B_USERS_F0_'+@TODATE+' E  
					WHERE B.t24_cif = E.t24_cif AND E.AMND_STATE = ''A'')
')

exec('
	SELECT T24_CIF , MIN(ACTIVE_DATE) AS ACTIVE_DATE 
	INTO #ACTIVE_DATE 
	FROM 	
		(SELECT  T24_CIF ,ACTIVE_DATE 
		FROM DATA.DBO.TBL_I2B_MBANKING_ACC
		WHERE AMND_STATE  = ''A''
			and process_status = ''fin''
		
		UNION ALL 
		SELECT  T24_CIF ,ACTIVE_DATE 
		FROM DATA.DBO.TBL_EB_MBBANKING_ACC
		WHERE AMND_STATE = ''1''
		) A 
	GROUP BY T24_CIF

	update a 
	set a.active_date = b.active_date 
	FROM TBL_I2B_MBANKING_ACC_'+@TODATE+'  a 
	inner join #ACTIVE_DATE b on a.t24_cif = b.t24_cif 
	where b.active_date < dateadd(d, 1, '''+@todate+''') 
')

exec
	('
ALTER TABLE TBL_I2B_MBANKING_ACC_'+@TODATE+'
	ADD BI_CHANNEL VARCHAR (30), SEGMENT VARCHAR(30)
	')

exec
	('
UPDATE TBL_I2B_MBANKING_ACC_'+@TODATE+' 
	SET BI_CHANNEL = B.BI_CHANNEL,
		SEGMENT = CASE 
					WHEN B.COMPANY_BOOK  = ''VN0010344'' THEN ''HH'' 
					WHEN B.COMPANY_BOOK  = ''VN0010348'' THEN ''TIMO'' 
				ELSE B.SEGMENT END
			FROM TBL_I2B_MBANKING_ACC_'+@TODATE+' A, CUSTOMER_'+@TODATE+' B
				WHERE A.T24_CIF = B.RECID
	')

EXEC('
	CREATE NONCLUSTERED INDEX [IDX_MBB_RGD_'+@TODATE+'] 
		ON [TBL_I2B_MBANKING_ACC_'+@TODATE+'] ([REGISTER_DATE] ASC)
		')
EXEC('
	ALTER INDEX PK_MBB_CIF_'+@TODATE+' ON TBL_I2B_MBANKING_ACC_'+@TODATE+' REBUILD
	')

END
GO
