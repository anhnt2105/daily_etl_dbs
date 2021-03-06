USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_01_GET_DATA_M74]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_01_GET_DATA_M74]
AS 

BEGIN

DECLARE @TODATE VARCHAR(8) , @TOMONTH VARCHAR(8) 
DECLARE @LASTMONTH VARCHAR(8)
DECLARE @FROMDATE VARCHAR(8)

SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )
SET @TOMONTH = LEFT(@TODATE,6)
SET @FROMDATE  = (SELECT CONVERT(VARCHAR(8),DATEADD(MM,DATEDIFF(MM,0,@TODATE),0),112)) 
SET @LASTMONTH = (SELECT CONVERT(VARCHAR(8),DATEADD(MS,-3,DATEADD(MM,0,DATEADD(MM,DATEDIFF(MM,0,@TODATE),0))),112)) 

-------BALANCE & DPTB MASTER 

EXEC
('
	TRUNCATE TABLE DATA.DBO.DPTB_MASTER 	
	INSERT INTO DATA.DBO.DPTB_MASTER
	SELECT
		[ID],[APP],[PRODUCT_NAME],[BRANCH_CODE],[ACCTNO],[CIF],[CUSTOMER_NAME],[CATEGORY],[CCY],[PRODUCT_CODE],[CUS_OPEN_DATE],[ISSUE_DATE],[OPENNING_DATE],[MATDT],[RDMDT]
		,[RATE],[SECTOR],[INPUTTER],[SEGMENT],[CHANNEL],[DIVISION],[DAO],[CIF_CHANNEL],[INSERT_DATE],[UPDATE_DATE],[BI_CHANNEL],[ORIGINAL_BAL],[PAYROLL_DATE],[BAL_QD],[TERM]
		,[ROLLOVER_DATE],[BONUS_TYPE],[PAYROLL_TYPE],[AZ_NRL],[NR_PROGRAM],[SOURCE],[BI_TENOR],[WITHDRAW_DATE],[BI_SOURCE_CODE],[NR],[SALE_CODE],[SAN_PHAM],[JOINT_HOLDER],[I2B]
		,[PRODUCT_DETAIL],[INTRODUCER],[IS_CLOSE],[F],[BI_SEGMENT],[LAST_ACTIVE_FIN_TRANS],[CHUONG_TRINH_SP],[KEYID_JETL],[ONLINE_LIMIT_DATE],[LIMIT_EXPIRY_DATE],[LIMIT_AMT]
		,[LIMIT_REFERENCE],[IS_SECURED_LIMIT],[LIMIT_UPDATE_DATE],[VPB_LNK_PARTNER],[OVERDRAFT_TYPE],[OVERDRAFT_INT],[MAT_INSTRUCTION],[SERVICE_CHANNEL],[POSTING_RESTRICT]
		,[POSTING_RESTRICT_DES],[OD_PD_CODE],[VPB_AC_STATUS],[CUST_TYPE],[RRT_ID]
	FROM M74.BICDATA.DBO.DPTB_MASTER
	WHERE APP = ''DEPOSIT''
		AND CCY <> ''XAU''

	')

EXEC('	
	TRUNCATE TABLE DATA.DBO.CARD_LIVE
    INSERT INTO DATA.DBO.CARD_LIVE	
	SELECT 
		[BUSINESS_DATE],[ACNT_CONTRACT_ID],[ACNT_CONTRACT_OID],[CONTRACT_AMND_DATE],[CARD_AMND_DATE],[COMPANY],[PRODUCT_GROUP],[CONTRACT_DATE_OPEN],[CONTRACT_TYPE],[CONTRACT_STATUS]
		,[ACCOUNT_LIMIT],[CONTRACT_NUMBER],[CARD_NUMBER],[CARD_STATUS],[CARD_LIMIT],[CARD_DATE_OPEN],[ORG_DATE_EXPIRE],[ACTUAL_DATE_EXPIRE],[CARD_TYPE]
		,[ISSUED_TYPE],[PRODUCTION_STATUS],[SOURCE_ID],[SOURCE_INFO] ,[T24_ACCT_NO],[UNLOCK_DATE],[BAD_DEBT_DATE],[CERT_ID],[T24_MAIN_AC],[T24_AC_LIST]
		,[T24_DAO],[BALANCE],[T24_CIF],[CUSTOMER_NAME],[BALANCE_BK],[BI_PRODUCT_TYPE],[BI_PRODUCT_GROUP],[DIVISION],[BI_CHANNEL],[OVD],[OVD30],[OVD60],[OVD90]
		,[OVD_DAYS],[OVD_LEVEL],[BADDEBT_DATE],[OVD_DATE],[CONTRACT_CIF] ,[SALE_CODE],[BI_SOURCE_CODE],[APP_ID_C],[CAMPAIGN],[BI_SEGMENT],[PRINCIPAL],[INTEREST]
		,[FEE],[CREDIT_TYPE],[ACNT_CONTRACT_OID_MAIN],[CONTRACT_NUMBER_MAIN],[CONTRACT_STATUS_MAIN],[CONTRACT_DATE_OPEN_MAIN],[CONTRACT_BALANCE_MAIN],[IS_MULTI_LEVEL]
		,[F],[product_code]
	FROM M74.BICDATA.DBO.CARD_LIVE
	WHERE BUSINESS_DATE = '''+@TODATE+'''
')

EXEC('
	TRUNCATE TABLE DATA.DBO.LNTB_MASTER		
	INSERT INTO DATA.DBO.LNTB_MASTER
	SELECT 
		[ID],[BRANCH_CODE],[CIF],[CUSTOMER_NAME],[SECTOR],[INDUSTRY],[ACCTNO],[CCY],[CATEGORY],[SUB_CATEGORY],[ORIGINAL_AMT],[VALUE_DATE],[MATDT],[RATE],[STATUS]
		,[COLLATERAL_VALUE],[LD_SECURED_YN],[SEGMENT],[CHANNEL],[DIVISION],[DAO],[AC],[COMPANY_MBN],[WRITEOFF],[CUS_OPEN_DATE],[CIF_CHANNEL],[BI_CHANNEL],[PRODUCT_CODE]
		,[PRODUCT_NAME],[UPDATE_DATE],[VMB_LN_CLASS],[CUST_ASSET_CLASS],[EXTEND_SCH],[NO_OVD_DAYS],[COLLATER],[TERM],[BI_TENOR],[OVERDRAFT_TYPE],[OVERDRAFT_COLLATERAL]
		,[LIMIT_AMT],[INSERT_DATE],[SOURCE],[INT_RATE_TYPE],[INT_SPREAD],[INT_KEY],[RATE_ADDON],[RATE_CHANGED_FRE],[FREQUENCY],[MUC_DICH],[CT_UUDAI_VAY],[WITHDRAW_DATE]
		,[BAL_QD],[CHUONG_TRINH_SP],[DRAW_PART_REPAY_ACCT],[PRIN_REPAY_ACCT],[INT_REPAY_ACCT],[PRODUCT_DETAIL],[INTRODUCER],[IS_BIG_LOAN],[NOTE],[IS_CLOSE],[F],[SALE_CODE]
		,[BI_SOURCE_CODE],[RRT_ID],[BI_SEGMENT],[LIMIT_REFERENCE],[FUND_PROGRAM],[IN_AMT],[PE_AMT],[PS_AMT],[ONLINE_LIMIT_DATE],[LIMIT_EXPIRY_DATE],[IS_SECURED_LIMIT]
		,[LIMIT_UPDATE_DATE],[VPB_LNK_PARTNER],[LN_PURPOSE],[LN_PURPOSE_DESC],[I2B],[HH_COMPANY],[LIMIT_REFERENCE_OLD]	
	FROM M74.BICDATA.DBO.LNTB_MASTER
	WHERE ACCTNO IS NOT NULL 
')
------------LIMIT OD TYPE 
EXEC
('
	DELETE FROM DATA.DBO.LIMIT_ODTYPE WHERE BUSINESS_DATE = (SELECT CONVERT(DATE,MAX(ISSUE_DATE)) FROM DATA.DBO.DPTB_MASTER)

	INSERT INTO DATA.DBO.LIMIT_ODTYPE
	SELECT CIF,ACCTNO,OVERDRAFT_TYPE,LIMIT_REFERENCE,OVERDRAFT_INT,NULL,''DPTB_MASTER''
		   FROM DATA.DBO.DPTB_MASTER 
				  WHERE OVERDRAFT_TYPE IS NOT NULL

	INSERT INTO DATA.DBO.LIMIT_ODTYPE
	SELECT CIF,ACCTNO,OVERDRAFT_TYPE,LIMIT_REFERENCE,RATE,NULL,''LNTB_MASTER''
		   FROM DATA.DBO.LNTB_MASTER
				  WHERE OVERDRAFT_TYPE IS NOT NULL

	UPDATE DATA.DBO.LIMIT_ODTYPE
		   SET BUSINESS_DATE = (SELECT CONVERT(DATE,MAX(ISSUE_DATE)) FROM DATA.DBO.DPTB_MASTER)
						 WHERE BUSINESS_DATE IS NULL

')


-----MONTHLY LCY 
EXEC ('
	TRUNCATE TABLE DATA.DBO.MONTHLY_LCY	
	INSERT INTO DATA.DBO.MONTHLY_LCY
	SELECT 
		[ID],[YEARMONTH],[APP],[ACCTNO],
		[N01],[N02],[N03],[N04],[N05],[N06],[N07],[N08],[N09],[N10],[N11],[N12],[N13],[N14],[N15],[N16]
		,[N17],[N18],[N19],[N20],[N21],[N22],[N23],[N24],[N25],[N26],[N27],[N28],[N29],[N30],[N31]
		,[NUMBER_OF_DAY],[ACCRUAL_BAL],[AVERAGE_BAL],[CIF],[BI_SEGMENT], NULL 
	FROM m74.[BICDATA].[DBO].[MONTHLY_LCY_AMOUNT]
	WHERE YEARMONTH = (selecT convert(varchar(6), businesS_date, 112) from m74.staging.dbo.partb_etldaily_log) 

	')

EXEC('
	update a 
	set a.product_name = b.PRODUCT_NAME 
	from data.dbo.monthly_lcy  a 
		inner join data.dbo.dptb_master b on a.acctno = b.acctno 
	where a.app = ''deposit'' 
	
	')

---------------------------------------------
-- BRANCH_CODE

EXEC
('
	PRINT ''BRANCH_CODE FROM M74''
	DROP TABLE IF EXISTS DATA.DBO.BRANCH_CODE
	SELECT * INTO DATA.DBO.BRANCH_CODE
		   FROM M74.BICDATA.DBO.BRANCH_CODE

	DROP TABLE IF EXISTS DATA.DBO.BRANCH_CODE_NEW
	SELECT * INTO DATA.DBO.BRANCH_CODE_NEW
		   FROM M74.BICDATA.DBO.BRANCH_CODE_NEW
')

---------------------------------------------
-- LNTB_DISBURSEMENT

EXEC
('
	TRUNCATE TABLE DATA.DBO.LNTB_DISBURSEMENT

	INSERT INTO DATA.DBO.LNTB_DISBURSEMENT
	SELECT 
		[ID],[BRANCH_CODE],[ACCTNO],[VALUE_DATE],[MATDT],[DIST_DATE],[CIF],[SECTOR],[CATEGORY],[SUB_CATEGORY],[CCY],[BAL],[RATE],[BUSINESS_DATE],[SEGMENT]
		  ,[CHANNEL],[DAO],[PRODUCT_NAME],[PRODUCT_CODE],[BI_CHANNEL],[BAL_QD],[CUSTOMER_NAME],[CUS_OPEN_DATE],[F_FAKEONLY],[VMB_LN_CLASS],[CUST_ASSET_CLASS]
		  ,[EXTEND_SCH],[NO_OVD_DAYS],[COLLATER],[COLLATERAL_VALUE],[TERM],[BI_TENOR],[OVERDRAFT_TYPE],[OVERDRAFT_COLLATERAL],[LIMIT_AMT],[INSERT_DATE],[UPDATE_DATE]
		  ,[SOURCE],[DIVISION],[INT_RATE_TYPE],[INT_SPREAD],[INT_KEY],[RATE_ADDON],[RATE_CHANGED_FRE],[FREQUENCY],[MUC_DICH],[CT_UUDAI_VAY],[BI_SOURCE_CODE]
		  ,[SALE_CODE] ,[CHUONG_TRINH_SP],[PRODUCT_DETAIL],[INTRODUCER],[APP_ID_C],[IS_BIG_LOAN],[NOTE],[F],[HH_COMPANY]
	FROM M74.BICDATA.DBO.LNTB_DISBURSEMENT
	WHERE ACCTNO IS NOT NULL 
')
------ CUSTOMER_CONTACT 
EXEC
('
	PRINT ''LNTB_DISBURSEMENT FROM M74''
	DROP TABLE IF EXISTS DATA.DBO.CUSTOMER_CONTACT
	SELECT * 
		INTO DATA.DBO.CUSTOMER_CONTACT
	FROM M74.BICDATA.DBO.CUSTOMER_CONTACT 
')


---------BANG CUSTOMER

PRINT '1. BANG CUSTOMER'
EXEC('
IF EXISTS (SELECT * FROM DBS_dAILY.DBO.SYSOBJECTS WHERE NAME = ''CUSTOMER_'+@TODATE+''')
	DROP TABLE [CUSTOMER_'+@TODATE+']
	')

EXEC('
	CREATE TABLE [CUSTOMER_'+@TODATE+'](
		[RECID] [VARCHAR](20) NOT NULL,
		[CUS_NAME] [NVARCHAR](255) NULL,
		[SECTOR] [VARCHAR](10) NULL,
		[INDUSTRY] [VARCHAR](10) NULL,
		[LEGAL_ID] [VARCHAR](20) NULL,
		[ADDRESS] [VARCHAR](255) NULL,
		PER_ADDR_STREET [VARCHAR](360) NULL,
		PER_ADDR_TOWN [VARCHAR](360) NULL,
		[COMPANY_BOOK] [VARCHAR](20) NULL,
		[BIRTH_INCORP_DATE] [DATE] NULL,
		[PROVINCE_CITY] [VARCHAR](35) NULL,
		[NATIONALITY] [VARCHAR](35) NULL,
		[VPB_GENDER] [VARCHAR](10) NULL,
		[EMAIL_ADDR] [VARCHAR](50) NULL,
		[MARITAL_STAT] [VARCHAR](10) NULL,
		[EDUCATION] [VARCHAR](35) NULL,
		[VPB_JOB_TITLE] [VARCHAR](35) NULL,
		[SEGMENT] [VARCHAR](16) NULL,
		[DAO] [VARCHAR](10) NULL,
		[CUS_OPEN_DATE] [DATE] NULL,
		[VPB_INDUSTRY] [VARCHAR](20) NULL,
		[DOC_ISSUE_DATE] [VARCHAR](10) NULL,
		[DOC_ISSUE_PLACE] [VARCHAR](200) NULL,
		[VIP_CODE] [VARCHAR](25) NULL,
		[CUST_TYPE] [NUMERIC](15, 0) NULL,
		[VPB_SERVICE] [VARCHAR](50) NULL,
		[VPB_CHANNEL] [VARCHAR](50) NULL,
		[BI_CHANNEL] [VARCHAR](20) NULL,
		[DIVISION] [VARCHAR](10) NULL,
		[PB_DAO] [VARCHAR](20) NULL,
		[TCSIGN_DATE] [VARCHAR](10) NULL,
		[DAO_RM] [VARCHAR](8) NULL,
		[PRIORITY_BRANCH] [VARCHAR](50) NULL,
		GOLD_CUS INT , 
		PROMOTION_PRG VARCHAR(20), 
		CONSTRAINT [PK_CUSTOMER_RECID_'+@TODATE+'] PRIMARY KEY CLUSTERED 	([RECID] ASC)
		)
')

EXEC('
	INSERT INTO [CUSTOMER_'+@TODATE+']
	SELECT 
		RECID,CUS_NAME,SECTOR,INDUSTRY,LEGAL_ID,ADDRESS, PER_ADDR_STREET, PER_ADDR_TOWN, COMPANY_BOOK,
		CONVERT(DATE,BIRTH_INCORP_DATE) BIRTH_INCORP_DATE, PROVINCE_CITY,NATIONALITY , 
		VPB_GENDER,	EMAIL_ADDR,MARITAL_STAT,EDUCATION,VPB_JOB_TITLE,SEGMENT,
		DAO,CONVERT(DATE,CUS_OPEN_DATE) CUS_OPEN_DATE,VPB_INDUSTRY,DOC_ISSUE_DATE,
		DOC_ISSUE_PLACE,VIP_CODE,CUST_TYPE, VPB_SERVICE, VPB_CHANNEL, BI_CHANNEL, 
		DIVISION ,PB_DAO, TCSIGN_DATE, DAO_RM	,PRIORITY_BRANCH , null, PROMOTION_PRG
	FROM [M74].[BICDATA].[DBO].[CUSTOMER]
	WHERE CUS_OPEN_DATE <= '''+@TODATE+'''
	')

EXEC ('
	UPDATE A
	SET GOLD_CUS = 1 
	FROM CUSTOMER_'+@TODATE+' A 
	WHERE VIP_CODE IN (''Gold'',''Gold-Special'',''Gold-Fee'', ''diamond'', ''AF-Private'', ''AF-Preferred'', ''AF-Pre'',''AF-Special'') 
		AND TCSIGN_DATE IS NOT NULL
	')

exec('
	ALTER TABLE [CUSTOMER_'+@TODATE+']
	ADD AGE INT ,MOBILE VARCHAR(50), VPB_STAFF INT, PAYROLL_CUS INT
	')

exec('
	PRINT ''UPDATE AGE, MOBILE, I2B_MOVILE, I2B_EMAIL FOR CUSTOMER''
	UPDATE [CUSTOMER_'+@TODATE+']
		SET AGE = YEAR(GETDATE()) - YEAR(BIRTH_INCORP_DATE)

	UPDATE A 
		SET MOBILE = replace(replace(B.CONTACT_NUM , ''.'',''''),'' '','''')
	FROM [CUSTOMER_'+@TODATE+'] A 
	INNER JOIN DATA.DBO.CUSTOMER_CONTACT b ON A.RECID = B.RECID
		WHERE B.CONTACT_TYPE LIKE ''%Mobile%'' --(15791 row(s) affected)
') 

EXEC('
	DROP TABLE IF EXISTS #STAFF, #PAYROLL

	-------VPB STAFF
	SELECT DISTINCT CIF
	INTO #STAFF
	FROM DATA.DBO.DPTB_MASTER
	WHERE PRODUCT_NAME = ''1. CURRENT ACCOUNT''
		AND CATEGORY = ''1006''

	-------PAYROLL
	SELECT DISTINCT CIF
	INTO #PAYROLL
	FROM DATA.DBO.DPTB_MASTER
	WHERE PRODUCT_NAME = ''1. CURRENT ACCOUNT''
		AND (CATEGORY = ''1015''
			OR PAYROLL_TYPE IS NOT NULL
			OR PAYROLL_DATE IS NOT NULL )

	UPDATE A 
	SET A.VPB_STAFF = CASE WHEN B.CIF IS NOT NULL THEN 1 ELSE NULL END, 
		A.PAYROLL_CUS = CASE WHEN C.CIF IS NOT NULL THEN 1 ELSE NULL END
	FROM DBS_DAILY.DBO.CUSTOMER_'+@TODATE+' A 
	LEFT JOIN #STAFF B ON A.RECID = B.CIF 
	LEFT JOIN #PAYROLL C ON A.RECID = C.CIF 
	') 

EXEC('
	CREATE NONCLUSTERED INDEX [IDX_CUSTOMER_OPD_'+@TODATE+'] 
		ON [CUSTOMER_'+@TODATE+'] ([CUS_OPEN_DATE] ASC)
	
	CREATE NONCLUSTERED INDEX [IDX_CUSTOMER_ID_'+@TODATE+'] 
		ON [CUSTOMER_'+@TODATE+'] ([CUS_NAME] ASC)

	CREATE NONCLUSTERED INDEX [IDX_CUSTOMER_LGID_'+@TODATE+'] 
		ON [CUSTOMER_'+@TODATE+'] ([LEGAL_ID] ASC)
') 
END 
GO
