USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_24_SAVING_OCB]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_24_SAVING_OCB]
AS 
BEGIN 

DECLARE @TODATE VARCHAR(8)
DECLARE	@FROMDATE		VARCHAR(8)
DECLARE	@LASTDATE		VARCHAR(8)
--------------
---SET @TODATE = '20170921' 
SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )
SET @FROMDATE  = (SELECT CONVERT(VARCHAR(8),DATEADD(mm,DATEDIFF(mm,0,@TODATE),0),112)) 
SET @LASTDATE = CONVERT(VARCHAR(8),DATEADD(D,-1,@FROMDATE),112)

------------------------------------ EBANKING OCB TRANSACTION -----------------------------------
---- 0. KIEM TRA XEM DA CO BANG EBANKING_TRANSACTION

EXEC('
IF EXISTS (SELECT * FROM SYSOBJECTS WHERE NAME = ''SAVING_ONLINE_'+@TODATE+''')
	DROP TABLE [SAVING_ONLINE_'+@TODATE+']
')
EXEC('
CREATE TABLE [SAVING_ONLINE_'+@TODATE+'] 
	(
	[SOURCE] [VARCHAR](30) NOT NULL,			 
	[TRANS_TYPE] [VARCHAR](25) NOT NULL,
	[CHANNEL] [NVARCHAR](20) NULL,
	[MERCHANT_USED] [NVARCHAR](50) NULL,
	[TXN_STATUS] [NVARCHAR](50) NULL,
	[BANK_STATUS] [NVARCHAR](50) NULL,
	[CUSTOMERID] [VARCHAR](50) NULL,
	[CIF] [NVARCHAR](50) NULL,
	[FROM_AC] [NVARCHAR](50) NULL,
	[TO_AC] [NVARCHAR](50) NULL,
	[SYS_ID] VARCHAR(100),
	[TRANS_CODE] VARCHAR(50),
	[TXN_AMT] [FLOAT] NULL,
	[TXN_FEE] [FLOAT] NULL,
	[RES_CODE] [NVARCHAR](50) NULL,
	[PROCESS_CODE] [NVARCHAR](6) NULL,
	[BANK_XID] [NVARCHAR](150) NULL,
	[VALUE_DATE] [DATE] NULL,
	[FINAL_STATUS] [VARCHAR](20) NULL,
	[RANK_TIME] [VARCHAR](20) NULL,
	[TRANS_TYPE_GROUP] [VARCHAR](25) NULL,
	[INPUT_DATE] [DATETIME] NULL,
	BI_CHANNEL VARCHAR(50) NULL,
	SEGMENT VARCHAR(50) NULL,
	COMPANY_BOOK VARCHAR(50) NULL,
	TXN_MEMO NVARCHAR(MAX) NULL 
	)  
')

--1. SAVING OCB --

PRINT 'SAVING OCB'

EXEC('
	INSERT INTO [SAVING_ONLINE_'+@TODATE+'] 
		(SOURCE,TRANS_TYPE,TRANS_TYPE_GROUP,CHANNEL,MERCHANT_USED,TXN_STATUS,BANK_STATUS,CUSTOMERID,CIF,FROM_AC,TO_AC,SYS_ID,TRANS_CODE,TXN_AMT,TXN_FEE,RES_CODE,PROCESS_CODE,BANK_XID,VALUE_DATE,INPUT_DATE)
	SELECT ''TBL_EB_AUDIT_LOG'' SOURCE,''SAVING ONLINE'' TRANS_TYPE, ''SAVING ONLINE'' TRANS_TYPE_GROUP,CHANNEL,''UNKNOWN'' [MERCHANT_USED],STATE,NULL,
		USER_ID,NULL CIF,FROM_ACCT_ID,NULL,TRAN_ID,NULL,NULL,0 TXN_FEE, NULL RES_CODE, NULL PROCESS_CODE,NULL FTNUMBER,CONVERT(DATE,LOG_DATE),CONVERT(DATETIME,LEFT(LOG_DATE,19)) INPUT_DATE		
	FROM data.dbo.DAILY_EB_AUDIT_LOG T1
	WHERE T1.LOG_DATE < dateadd(d, 1, '''+@TODATE+''')
		AND T1.LOG_DATE >= '''+@FROMDATE+'''
		AND TRAN_TYPE IN (15000) 
')

--2. SAVING I2B --

PRINT 'SAVING I2B'
EXEC('
	INSERT INTO [SAVING_ONLINE_'+@TODATE+'] 
		(SOURCE,TRANS_TYPE,TRANS_TYPE_GROUP,CHANNEL,MERCHANT_USED,TXN_STATUS,BANK_STATUS,CIF,FROM_AC,TO_AC,SYS_ID,TRANS_CODE,TXN_AMT,TXN_FEE,RES_CODE,PROCESS_CODE,BANK_XID,VALUE_DATE,INPUT_DATE)
	SELECT 
		''TBL_I2B_TRANSFER_TXN'' SOURCE,''SAVING ONLINE'' TRANS_TYPE ,''SAVING ONLINE'' TRANS_TYPE_GROUP,CHANEL,''UNKNOWN'' [MERCHANT_USED],TXN_STATUS,BANK_STATUS,
		CUS_ORDER CIF,DEBIT_AC,BANK_XID,BANK_XID,TRANS_CODE,TXN_AMT,TXN_FEE, NULL RES_CODE, NULL PROCESS_CODE,BANK_XID,CONVERT(DATE,VALUE_DATE),INPUT_DATE		
	FROM  DATA.DBO.TBL_i2b_transfer_Txn  T1
	WHERE (T1.TRANSFER_TYPE = ''AZ''  
			OR T1.TRANSFER_TYPE = ''ONLINE'' 
			OR T1.TRANSFER_TYPE LIKE ''%EASYSAV%''
			OR T1.TRANSFER_TYPE LIKE ''TD%'')
		and T1.VALUE_DATE < dateadd(d, 1, '''+@TODATE+''')
		AND T1.VALUE_DATE >= '''+@FROMDATE+'''						
	')

--3. CLOSE SAVING OCB --
PRINT 'CLOSE SAVING OCB'
EXEC('
	INSERT INTO [SAVING_ONLINE_'+@TODATE+'] 
		(SOURCE,TRANS_TYPE,TRANS_TYPE_GROUP,CHANNEL,MERCHANT_USED,TXN_STATUS,BANK_STATUS,CUSTOMERID,CIF,FROM_AC,TO_AC,SYS_ID,TRANS_CODE,TXN_AMT,TXN_FEE,RES_CODE,PROCESS_CODE,BANK_XID,VALUE_DATE,INPUT_DATE)
	SELECT 
		''TBL_EB_AUDIT_LOG'' SOURCE,''CLOSING SAVING ONLINE'' TRANS_TYPE, ''CLOSING SAVING ONLINE'' TRANS_TYPE_GROUP,CHANNEL,''UNKNOWN'' [MERCHANT_USED],STATE,NULL,
		USER_ID,NULL CIF,TO_ACCT_ID,FROM_ACCT_ID,TRAN_ID,NULL,NULL,0 TXN_FEE, NULL RES_CODE, NULL PROCESS_CODE,NULL FTNUMBER,CONVERT(DATE,LOG_DATE),CONVERT(DATETIME,LEFT(LOG_DATE,19)) INPUT_DATE		
	FROM data.dbo.DAILY_EB_AUDIT_LOG T1
	WHERE T1.LOG_DATE < dateadd(d, 1, '''+@TODATE+''')
		AND T1.LOG_DATE >= '''+@FROMDATE+'''
		AND TRAN_TYPE IN (15001) 
')

--4. CLOSE SAVING I2B --

PRINT 'CLOSE SAVING I2B'
EXEC('
	INSERT INTO [SAVING_ONLINE_'+@TODATE+'] 
		(SOURCE,TRANS_TYPE,TRANS_TYPE_GROUP,CHANNEL,MERCHANT_USED,TXN_STATUS,BANK_STATUS,CIF,FROM_AC,TO_AC,SYS_ID,TRANS_CODE,TXN_AMT,TXN_FEE,RES_CODE,PROCESS_CODE,BANK_XID,VALUE_DATE,INPUT_DATE)
	SELECT ''TBL_I2B_TRANSFER_TXN'' SOURCE,''CLOSING SAVING ONLINE'' TRANS_TYPE ,''CLOSING SAVING ONLINE'' TRANS_TYPE_GROUP,CHANEL,''UNKNOWN'' [MERCHANT_USED],TXN_STATUS,BANK_STATUS,
		CUS_ORDER CIF,DEBIT_AC,CREDIT_AC,BANK_XID,TRANS_CODE,TXN_AMT,TXN_FEE, NULL RES_CODE, NULL PROCESS_CODE,BANK_XID,CONVERT(DATE,VALUE_DATE),INPUT_DATE		
	FROM  DATA.DBO.TBL_i2b_transfer_Txn  T1
	WHERE (T1.TRANSFER_TYPE = ''AZCLOSE'')		
		and T1.VALUE_DATE < dateadd(d, 1, '''+@TODATE+''')
		AND T1.VALUE_DATE >= '''+@FROMDATE+'''		
	')

------------------------------------------------------------------------------------------------
---------------- CẬP NHẬT FINAL STATUS----------------------------------------------------------

EXEC('
UPDATE [SAVING_ONLINE_'+@TODATE+'] 
	SET CIF = CUST_ID
	FROM DATA.DBO.DAILY_EB_CUSTOMER_DIRECTORY
	WHERE CUSTOMERID = DIRECTORY_ID
')

EXEC('
IF EXISTS (SELECT * FROM TEMPDB.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''##SO'')
DROP TABLE ##SO
')

EXEC('
SELECT TRAN_ID, DESCRIPTION INTO ##SO
FROM DATA.dbo.DAILY_EB_AUDIT_LOG T1
WHERE T1.LOG_DATE < dateadd(d, 1, '''+@TODATE+''')
	AND T1.LOG_DATE >= '''+@FROMDATE+'''
	AND TRAN_TYPE IN (15000)  
')


EXEC('
UPDATE [SAVING_ONLINE_'+@TODATE+'] 
	SET TXN_AMT = SUBSTRING(DESCRIPTION,PATINDEX(''%AMOUNT: %'',DESCRIPTION)+8,PATINDEX(''%. TERM: %'',DESCRIPTION) - PATINDEX(''%AMOUNT: %'',DESCRIPTION)-8)
	FROM ##SO 
	WHERE SYS_ID = TRAN_ID
	AND DESCRIPTION LIKE ''%AMOUNT%TERM%'' 
')

EXEC('
UPDATE [SAVING_ONLINE_'+@TODATE+'] 
	SET TO_AC = SUBSTRING(DESCRIPTION,PATINDEX(''%NUMBER: %'',DESCRIPTION)+8,PATINDEX(''%. CIF: %'',DESCRIPTION) - PATINDEX(''%NUMBER: %'',DESCRIPTION)-8)
	FROM ##SO 
	WHERE SYS_ID = TRAN_ID
	AND DESCRIPTION LIKE ''%NUMBER%CIF%''
')

EXEC('
UPDATE [SAVING_ONLINE_'+@TODATE+'] 
	SET TRANS_CODE = TO_AC
')



EXEC('
UPDATE [SAVING_ONLINE_'+@TODATE+'] 
	SET RANK_TIME = CASE 
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''0'' THEN ''00H-01H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''1'' THEN ''01H-02H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''2'' THEN ''02H-03H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''3'' THEN ''03H-04H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''4'' THEN ''04H-05H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''5'' THEN ''05H-06H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''6'' THEN ''06H-07H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''7'' THEN ''07H-08H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''8'' THEN ''08H-09H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''9'' THEN ''09H-10H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''10'' THEN ''10H-11H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''11'' THEN ''11H-12H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''12'' THEN ''12H-13H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''13'' THEN ''13H-14H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''14'' THEN ''14H-15H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''15'' THEN ''15H-16H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''16'' THEN ''16H-17H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''17'' THEN ''17H-18H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''18'' THEN ''18H-19H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''19'' THEN ''19H-20H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''20'' THEN ''20H-21H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''21'' THEN ''21H-22H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''22'' THEN ''22H-23H''
		WHEN CONVERT(FLOAT,DATEPART(HH,INPUT_DATE)) = ''23'' THEN ''23H-24H''
	ELSE ''999''
	END

UPDATE [SAVING_ONLINE_'+@TODATE+'] 
	SET FINAL_STATUS = CASE
						WHEN SOURCE = ''TBL_EB_AUDIT_LOG''	AND TXN_STATUS = ''SUCCESS'' THEN ''SUCCESSFUL''
						WHEN SOURCE = ''TBL_I2B_TRANSFER_TXN''	AND TXN_STATUS = ''FIN'' THEN ''SUCCESSFUL''
						WHEN TXN_STATUS IN (''FAL'',''FAILED'')	THEN ''UNSUCCESSFUL''
					ELSE ''OTHER''
					END
')


EXEC('
UPDATE a
	SET BI_CHANNEL = B.BI_CHANNEL,
		SEGMENT = B.SEGMENT,
		COMPANY_BOOK = B.COMPANY_BOOK
FROM [SAVING_ONLINE_'+@TODATE+']  A, [CUSTOMER_'+@TODATE+']  B
	WHERE A.CIF = B.RECID
')

exec('
	CREATE NONCLUSTERED INDEX [IDX_SVOL_CIF_'+@TODATE+'] 
		ON [DBS_dAILY].[dbo].SAVING_ONLINE_'+@TODATE+' ([CIF] ASC)

	CREATE NONCLUSTERED INDEX [IDX_SVOL_ACC_'+@TODATE+'] 
		ON [DBS_dAILY].[dbo].SAVING_ONLINE_'+@TODATE+' ([TO_AC] ASC ) INCLUDE ([FROM_AC])
		') 
--------------SAVING NEW ON OCB 
exec('
	DROP TABLE IF EXISTS DBS_REF.DBO.OCB_SAVING_ACCT_TYPE, DBS_DAILY.DBO.SAVING_ONLINE_OCB_'+@todate+'

	SELECT * 
	INTO DBS_REF.DBO.OCB_SAVING_ACCT_TYPE
	FROM m108.BICDATA_HIS.DBO.DAILY_OCB_SAV_ACCT_TYPES

	SELECT 
		BUSINESS_DATE, 
		SRVRTID, 
		SAVINGCODE AS SAVING_CODE, 
		DIRECTORYID AS DIRECTORY_ID, 
		SAVINGACCOUNTTYPE AS SAVING_TYPE_ID, 
		NAME_EN AS SAVING_NAME, 
		TRANTYPE AS TRAN_TYPE, 
		CASE WHEN TRANTYPE = ''OPEN'' THEN FROMACCOUNTID 
			WHEN TRANTYPE = ''SETTLE'' THEN SAVINGCODE 
		END AS FROM_AC,
		CASE WHEN TRANTYPE = ''OPEN'' THEN SAVINGCODE 
			WHEN TRANTYPE = ''SETTLE'' THEN DESTINATIONACCOUNTID
		END AS TO_AC,
		CREATEDATE AS VALUE_DATE, 
		MATURITYDATE AS MATURITY_DATE, 
		PRINCIPLEAMOUNT AS PRIN_AMT, 
		INTERESTRATE AS INTEREST_RATE, 
		TERM,
		PRODUCTCODE AS PRODUCT_CODE,
		CATEGORY, 
		EMPLOYEEDAO AS EMPLOYEE_DAO, 
		INTRODUCER, 
		MATURITY_METHOD,
		CURRENCY,
		A.STATUS,
		CASE WHEN A.STATUS IN (''3'',''SUCCESS'') THEN ''SUCCESS''
			WHEN A.STATUS IN (''4'', ''5'', ''FAILED'') THEN ''FAILED''
		END AS FINAL_STATUS 
	INTO DBS_DAILY.DBO.SAVING_ONLINE_OCB_'+@todate+'
	FROM M108.BICDATA_HIS.DBO.DAILY_OCB_ONLINESAVING A 
		LEFT JOIN DBS_REF.DBO.OCB_SAVING_ACCT_TYPE B ON A.SAVINGACCOUNTTYPE = CAST(B.ACCOUNT_TYPE_ID AS VARCHAR)
		LEFT JOIN DBS_REF.DBO.Saving_maturity_method C ON A.MATURITY_METHOD = METHOD_ID
	WHERE CREATEDATE >= '''+@FROMDATE+''' 

	alter table DBS_DAILY.DBO.SAVING_ONLINE_OCB_'+@todate+'
	add T24_CIF VARCHAR(8) 
')

exec('
	UPDATE A 
	SET A.T24_CIF = B.CUST_ID 
	FROM DBS_DAILY.DBO.SAVING_ONLINE_OCB_'+@todate+' A 
	INNER JOIN DATA.DBO.DAILY_EB_CUSTOMER_DIRECTORY B ON A.DIRECTORY_ID = B.DIRECTORY_ID 
	') 


PRINT 'UPDATE PLATFORM - DPTB MASTER '
EXEC
('
	UPDATE A
		SET PLATFORM = case when B.SOURCE = ''TBL_EB_AUDIT_LOG'' and B.CHANNEL IN (''i2b'',''Web'') then ''OCB WEB''
							when B.SOURCE = ''TBL_EB_AUDIT_LOG'' and B.CHANNEL IN (''Mobile'') THEN ''OCB MOBILE''
							when B.SOURCE = ''TBL_I2B_TRANSFER_TXN'' and B.CHANNEL IN (''i2b'',''Web'') then ''I2B WEB''
							when B.SOURCE = ''TBL_I2B_TRANSFER_TXN'' and B.CHANNEL IN (''Mobile'') THEN ''I2B MOBILE''
						END 
	FROM DBS_DAILY.DBO.DPTB_MASTER A 
		inner join DBS_MONTHLY.DBO.SAVING_ONLINE_CUMMULATIVE B on A.ACCTNO = B.TO_AC
	where B.VALUE_dATE <= '''+@LASTDATE+''' 

	UPDATE A
		SET PLATFORM = case when B.SOURCE = ''TBL_EB_AUDIT_LOG'' and B.CHANNEL IN (''i2b'',''Web'') then ''OCB WEB''
							when B.SOURCE = ''TBL_EB_AUDIT_LOG'' and B.CHANNEL IN (''Mobile'') THEN ''OCB MOBILE''
							when B.SOURCE = ''TBL_I2B_TRANSFER_TXN'' and B.CHANNEL IN (''i2b'',''Web'') then ''I2B WEB''
							when B.SOURCE = ''TBL_I2B_TRANSFER_TXN'' and B.CHANNEL IN (''Mobile'') THEN ''I2B MOBILE''
						END 
	FROM DBS_DAILY.DBO.DPTB_MASTER A 
		inner join DBS_DAILY.DBO.SAVING_ONLINE_'+@TODATE+' B ON A.ACCTNO = B.TO_AC
	WHERE B.TRANS_TYPE = ''SAVING ONLINE''
		and a.PRODUCT_NAME = ''2. Term Deposit''
		and a.platform is null 
')

END 
GO
