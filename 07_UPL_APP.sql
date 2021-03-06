USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_07_UPL_APP]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_07_UPL_APP]
AS 
BEGIN 

DECLARE @TODATE VARCHAR(8) = (select Rptdate from DBS_REF.dbo.RPTDATE )
DECLARE @LOAN_OLD VARCHAR(8) = (SELECT MAX(RIGHT(TABLE_NAME,8)) FROM BIC_RB.DAILY_RETAIL.INFORMATION_SCHEMA.TABLES 
			WHERE TABLE_NAME like 'LOAN_OLD_%' and RIGHT(TABLE_NAME,8) like '[0-9]%')
DECLARE @LOAN VARCHAR(8) = (SELECT MAX(RIGHT(TABLE_NAME,8)) FROM BIC_RB.DAILY_RETAIL.INFORMATION_SCHEMA.TABLES 
			WHERE TABLE_NAME not like 'LOAN_OLD_%' and TABLE_NAME like 'LOAN_20%' and RIGHT(TABLE_NAME,8) like '[0-9]%')

----------------------------------------------------------
-- LAY CAC BAN GHI DANG HIEU LUC TU DATA.DBO.TBL_UPL_DIGITAL_UPL_APP_SCD

EXEC
('
	PRINT ''LAY CAC BAN GHI DANG HIEU LUC TU DATA.DBO.TBL_UPL_DIGITAL_UPL_APP_SCD''
	DROP TABLE IF EXISTS DATA.DBO.UPLAPP_APPLICATION_ALL
	SELECT * 
		INTO DATA.DBO.UPLAPP_APPLICATION_ALL
	FROM M16.VPB_WHR2.DBO.TBL_UPL_DIGITAL_UPL_APP_SCD A 
	WHERE EXP_DATE = ''2400-01-01''
		AND CREATED_TIME < dateadd(d,1,'''+@TODATE+''')
')


-----------UPDATE CIF

EXEC
('
ALTER TABLE DATA.DBO.UPLAPP_APPLICATION_ALL
	ADD CIF VARCHAR(50)
')

EXEC
('
	PRINT ''UPDATE CIF''
	UPDATE DATA.DBO.UPLAPP_APPLICATION_ALL
		SET CIF = NULL

	UPDATE A
		SET CIF = B.RECID
	FROM DATA.DBO.UPLAPP_APPLICATION_ALL A, DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' B
	WHERE A.PASSPORT_NUMBER = B.LEGAL_ID ; 

	SELECt CIF, DATA_PHONE
	INTO #ocb_mobile
	FROM 
		(select * , ROW_NUMBER() OVER (PARTITION BY CIF ORDER BY CREATE_DATE DESC, TERMS_ACCEPTED DESC , ACCOUNT_STATUS ASC ) AS ROWID
		from DATA.DBO.OCB_NEW
		) A 
	WHERE ROWID = 1 

	UPDATE A
		SET CIF = B.CIF
	FROM DATA.DBO.UPLAPP_APPLICATION_ALL A
		inner join #ocb_mobile B on A.PHONE_NUMBER = B.DATA_PHONE  
	where A.CIF IS NULL ;
	
	select T24_CIF, USER_MOBILE 
	INTO #i2b_mobile
	FROM 
		(
		SELECT ROW_NUMBER() OVER (PARTITION BY T24_CIF ORDER BY OPEN_DATE DESC,AMND_DATE DESC,LAST_LOGIN_TIME DESC) AS ROWID,*
			FROM DATA.dbo.DAILY_I2B_USERS_F0
				WHERE CONVERT(VARCHAR(8),OPEN_DATE,112) <= '''+@TODATE+'''
				AND AMND_USER <> ''OCB''
				AND LAST_LOGIN_TIME IS NOT NULL					
		) A
	where ROWID = 1 


	UPDATE A
		SET CIF = B.t24_cif
	FROM DATA.DBO.UPLAPP_APPLICATION_ALL A
		inner join #i2b_mobile B on A.PHONE_NUMBER = B.USER_MOBILE
	where A.CIF IS NULL ; 
	
	UPDATE A
		SET CIF = B.RECID
	FROM DATA.DBO.UPLAPP_APPLICATION_ALL A, DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' B
	WHERE A.PHONE_NUMBER = B.MOBILE
		AND A.CIF IS NULL
')


---------LAY BANG LOS VA LOAN

--UPDATE DAILY_CHECK_UPL_LEADS_DF

EXEC
('
	DROP TABLE IF EXISTS DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
	SELECT * INTO DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
		FROM DATA.DBO.UPLAPP_APPLICATION_ALL
')

EXEC
('
ALTER TABLE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
	ADD NO_UPL FLOAT
')

EXEC
('
PRINT ''UPDATE NO_UPL''
	UPDATE A 
		SET NO_UPL = B.NO_UPL
	FROM DATA.DBO.DAILY_CHECK_UPL_LEADS_DF A
	INNER JOIN
		(SELECT CIF, COUNT(1) NO_UPL
		FROM DATA.DBO.LNTB_DISBURSEMENT
		WHERE CONVERT(DATE,VALUE_DATE) >= ''2017-12-10''
			AND CONVERT(DATE,VALUE_DATE) <= CONVERT(DATE,'''+@TODATE+''')
			AND PRODUCT_NAME LIKE ''%UPL%''
		GROUP BY CIF
		) B ON A.CIF = B.CIF
')

EXEC
('
	PRINT ''UPDATE FROM LNTB_DISBURSEMENT''
	DROP TABLE IF EXISTS ##TEMP
	SELECT A.*, B.ACCTNO,CONVERT(DATE,B.VALUE_DATE) VALUE_DATE,B.APP_ID_C,B.RATE,B.TERM,B.DAO,B.SALE_CODE,B.BRANCH_CODE
		INTO ##TEMP
	FROM DATA.DBO.DAILY_CHECK_UPL_LEADS_DF A 
	LEFT JOIN 
		(SELECT * 
		FROM DATA.DBO.LNTB_DISBURSEMENT
		WHERE CONVERT(DATE,VALUE_DATE) >= ''2017-12-10''
			AND CONVERT(DATE,VALUE_DATE) <= CONVERT(DATE,'''+@TODATE+''')
			AND PRODUCT_NAME LIKE ''%UPL%''
		) B	ON A.CIF = B.CIF
			
	ALTER TABLE ##TEMP
		ADD AMOUNT FLOAT,SUB_PRODUCT_SCHEMEDESC_NAME NVARCHAR(100),LOANPURPOSE NVARCHAR(2000),CREATION_DAY DATE,APP_REJ_CAN_DAY DATE,BRANCH_NAME VARCHAR(100),
		PRIORITY1 NVARCHAR(320)
') 

EXEC('
	UPDATE ##TEMP
		SET AMOUNT = B.AMOUNT
	FROM ##TEMP A	
	INNER JOIN 
		(SELECT 
			ACCTNO, SUM(BAL_QD) AMOUNT 
		FROM DATA.DBO.LNTB_DISBURSEMENT
		WHERE CONVERT(DATE,VALUE_DATE) >= ''2017-12-10''
			AND CONVERT(DATE,VALUE_DATE) <= CONVERT(DATE,'''+@TODATE+''')
			AND PRODUCT_NAME LIKE ''%UPL%''
		GROUP BY ACCTNO
		) B ON A.ACCTNO = B.ACCTNO

	PRINT ''UPDATE FROM LOS_INFORMATION''
	UPDATE ##TEMP
		SET SUB_PRODUCT_SCHEMEDESC_NAME = B.SUB_PRODUCT,
			LOANPURPOSE = B.LOANPURPOSE,
			CREATION_DAY = B.CREATION_DAY,
			APP_REJ_CAN_DAY = B.APP_REJ_CAN_DAY,
			PRIORITY1 = B.PRIORITY1
	FROM ##TEMP A, DATA.DBO.LOS_INFORMATION B
		WHERE A.APP_ID_C = B.SZDISPLAYAPPLICATIONNO
')

EXEC
('
	PRINT ''UPDATE BRANCH''
	UPDATE ##TEMP
		SET BRANCH_NAME = B.BRANCH_NAME
			FROM ##TEMP A, DATA.DBO.BRANCH_CODE B
				WHERE A.BRANCH_CODE = B.BRANCH_ID

	DROP TABLE IF EXISTS DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
	SELECT * INTO DATA.DBO.DAILY_CHECK_UPL_LEADS_DF FROM ##TEMP
')



EXEC
('
PRINT ''UPDATE GAP & DF''
ALTER TABLE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
	ADD GAP FLOAT, DF VARCHAR(20)
')

EXEC
('
	UPDATE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
		SET GAP = DATEDIFF(D,CREATED_TIME,VALUE_DATE)

	UPDATE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
		SET DF = (CASE WHEN BRANCH_CODE = ''VN0010005'' THEN ''DF-ONLINE''
							  WHEN BRANCH_CODE <> ''VN0010005'' AND GAP >= 4 THEN ''DF-OFFLINE''
							  ELSE NULL END)

PRINT ''UPDATE CAMPAIGN INFO FROM BIC_RB''
	DROP TABLE IF EXISTS ##TEMP
	SELECT A.*, B.CHUONG_TRINH_SP,B.CAMPAIGN_GROUP,B.CAMPAIGN_CODE,B.CAMPAIGN_NAME
	INTO ##TEMP
	FROM DATA.DBO.DAILY_CHECK_UPL_LEADS_DF A 
	LEFT JOIN
		(SELECT ACCTNO,CHUONG_TRINH_SP,CAMPAIGN_GROUP,CAMPAIGN_CODE,CAMPAIGN_NAME 
		FROM BIC_RB.DAILY_RETAIL.DBO.LOAN_'+@LOAN+'
		UNION ALL 
		SELECT ACCTNO,CHUONG_TRINH_SP,CAMPAIGN_GROUP,CAMPAIGN_CODE,CAMPAIGN_NAME 
		FROM BIC_RB.DAILY_RETAIL.DBO.LOAN_OLD_'+@LOAN_OLD+'
		) B	ON A.ACCTNO = B.ACCTNO

	DROP TABLE IF EXISTS DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
	SELECT * INTO DATA.DBO.DAILY_CHECK_UPL_LEADS_DF FROM ##TEMP
')

/*
EXEC
('
PRINT ''LOAI UPL24''
UPDATE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
	SET DF = NULL
		WHERE CAMPAIGN_GROUP LIKE ''%UPL%24%''
')
*/

EXEC
('
ALTER TABLE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
       ADD CUS_OPEN_DATE DATE, DIFF_APP_CUS FLOAT
')
 
EXEC
('
UPDATE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
       SET CUS_OPEN_DATE = B.CUS_OPEN_DATE
              FROM DATA.DBO.DAILY_CHECK_UPL_LEADS_DF A, DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' B
                     WHERE A.CIF = B.RECID
 
UPDATE DATA.DBO.DAILY_CHECK_UPL_LEADS_DF
       SET DIFF_APP_CUS = DATEDIFF(D,CREATED_TIME,CUS_OPEN_DATE)
')
 


END
GO
