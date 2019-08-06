USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_06_CC_APP]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_06_CC_APP]
AS 
BEGIN 

DECLARE @TODATE VARCHAR(8) = (SELECT RPTDATE FROM DBS_rEF.DBO.RPTDATE) 
DECLARE @RBDATE VARCHAR(8) = (SELECT MAX(RIGHT(TABLE_NAME,8)) FROM BIC_RB.DAILY_RETAIL.INFORMATION_SCHEMA.TABLES 
			WHERE TABLE_NAME LIKE 'CREDITCARD_%'
			AND RIGHT(TABLE_NAME,8) IN (SELECT DISTINCT CONVERT(VARCHAR,RptDate) FROM DBS_REF.DBO.CALENDAR))
DECLARE @FROMDATE VARCHAR(8) = LEFT(@TODATE, 6) + '01' 
----------------------------------------------------------

-- INSERT NEW DAY
-- SELECT MAX(CONVERT(DATETIME,SAVE_DATE,103)) from DRAFT.DBO.IMPORT_CCAPP
-- SELECT * INTO DATA.DBO.CCAPP_APPLICATION_ALL FROM DATA.DBO.DIGITAL_CARD_LEADS_RECHECK

EXEC
('
	PRINT ''LAY CAC BAN GHI DANG HIEU LUC TU TBL_DIGIT_DIGITAL_CC_APP_SCD''
	DROP TABLE IF EXISTS DATA.DBO.CCAPP_APPLICATION_ALL
	SELECT 
		[APPLICATION_ID],[LOS_ID],[NAME],[MOBILE_NO],[ID],[EMAIL],[KYC_TYPE],[AGES],[GENDER],[REGION],[SAVE_DATE],[SUBMITTED_LOS],[SUBMITTED_APP],
		[SUBMITTED_DOC],[USER_APP],[USER_DOC],[USERMODIFIED],[CARD_TYPE] REGIST_CARD_TYPE,[MONTHLYINCOME],[STATUS],[STATUSCSR],[STATUSLOS],[STATUSCSRDETAIL],
		[AGENCYID],[UTMCAMPAIGN],[UTMCONTENT],[UTMMEDIUM],[UTMSOURCE],[UTMTERM],[BROWSERNAME],[CITY],[COUNTRY],[OPERATINGSYSTEM],[TYPEOFDEVICE],
		[INFORMATIONSUBMITTED],[DOCUMENTUPLOADED],[REQUESTLIMIT],[USE_APPROVE],[CSR], [INTRODUCER_NAME] 
	INTO DATA.DBO.CCAPP_APPLICATION_ALL
	FROM M16.VPB_WHR2.DBO.TBL_DIGIT_DIGITAL_CC_APP_SCD A 
	WHERE CONVERT(DATE,SAVE_DATE) >= ''2017-04-27'' 
		AND CONVERT(DATE,SAVE_DATE) < dateadd(d,1,'''+@TODATE+''')
		AND EXP_DATE = ''2400-01-01''
')

---- LAY BANG CUSTOMER 
--EXEC
--('
--PRINT ''LAY CUSTOMER''
--IF NOT EXISTS (SELECT * FROM DBS_dAILY.DBO.SYSOBJECTS WHERE NAME LIKE ''CUSTOMER_'+@TODATE+''')
--SELECT * INTO DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' FROM DBS_dAILY.DBO.CUSTOMER_'+@TODATE+'
--')

EXEC
('
ALTER TABLE DATA.DBO.CCAPP_APPLICATION_ALL
	ADD CIF VARCHAR(20)
')

EXEC
(' 
	PRINT ''UPDATE CIF''

	UPDATE a 
		SET CIF = B.RECID
	FROM DATA.DBO.CCAPP_APPLICATION_ALL A
		INNER JOIN DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' B ON A.ID = B.LEGAL_ID ;

	SELECt CIF, DATA_PHONE
	into #ocb_mobile
	FROM 
		(select * , ROW_NUMBER() OVER (PARTITION BY CIF ORDER BY CREATE_DATE DESC, TERMS_ACCEPTED DESC , ACCOUNT_STATUS ASC ) AS ROWID
		from DATA.DBO.OCB_NEW
		) A 
	WHERE ROWID = 1 
	
	UPDATE DATA.DBO.CCAPP_APPLICATION_ALL
		SET CIF = B.CIF
	FROM DATA.DBO.CCAPP_APPLICATION_ALL A
		inner join #ocb_mobile B on A.MOBILE_NO = B.DATA_PHONE  
	where A.CIF IS NULL ;

	select T24_CIF, USER_MOBILE 
	into #i2b_mobile
	FROM 
	(
	SELECT ROW_NUMBER() OVER (PARTITION BY T24_CIF ORDER BY OPEN_DATE DESC,AMND_DATE DESC,LAST_LOGIN_TIME DESC) AS ROWID,*
		FROM DATA.dbo.DAILY_I2B_USERS_F0
			WHERE CONVERT(VARCHAR(8),OPEN_DATE,112) <= '''+@TODATE+'''
			AND AMND_USER <> ''OCB''
			AND LAST_LOGIN_TIME IS NOT NULL					
	) A
	where ROWID = 1 

	UPDATE a 
		SET CIF = B.t24_cif
	FROM DATA.DBO.CCAPP_APPLICATION_ALL A
		inner join #i2b_mobile B on A.MOBILE_NO = B.USER_MOBILE
	where A.CIF IS NULL ; 
	
	UPDATE A
		SET CIF = B.RECID
	FROM DATA.DBO.CCAPP_APPLICATION_ALL A
		inner join DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' B	ON A.MOBILE_NO = B.MOBILE
	WHERE A.CIF IS NULL ;
')

EXEC
('
	PRINT ''UPDATE CREDIT CARD''
	DROP TABLE IF EXISTS ##CARD
	SELECT * 
		INTO ##CARD 
	FROM (
			SELECT 
				T24_CIF, CARD_TYPE,CARD_DATE_OPEN,CARD_LIMIT,CARD_STATUS,COMPANY,BI_CARD_TYPE,
				CONTRACT_NUMBER,ACNT_CONTRACT_ID,PRODUCTION_STATUS -- THE ONLINE LAY FULL
			FROM DBS_dAILY.DBO.CARD_'+@TODATE+'
			WHERE BI_PRODUCT_GROUP = ''01.Credit Card''
				AND COMPANY = ''VN0010005''
		UNION ALL
			SELECT 
				CIF T24_CIF,B.CARD_TYPE,CARD_DATE_OPEN,CARD_LIMIT,CARD_STATUS,COMPANY,
				BI_CARD_TYPE,CONTRACT_NUMBER,ACNT_CONTRACT_ID,PRODUCTION_STATUS --THE OFFLINE LAY FULL
			FROM DATA.DBO.CCAPP_APPLICATION_ALL A 
			LEFT JOIN
				(SELECT * FROM DBS_dAILY.DBO.CARD_'+@TODATE+' 
				WHERE BI_CARD_TYPE = ''DIGITAL CARD''
					AND COMPANY <> ''VN0010005''
					AND CARD_DATE_OPEN <= ''2018-03-31''
					AND CARD_TYPE NOT LIKE ''%SME%''
					AND CARD_TYPE NOT LIKE ''%CORPORATE%''
				) B 
				ON A.CIF = B.T24_CIF
			WHERE DATEDIFF(D,CONVERT(DATE,CONVERT(DATETIME,SAVE_DATE,103)),CARD_DATE_OPEN) >= 5

		UNION ALL
			SELECT 
				CIF T24_CIF, B.CARD_TYPE,CARD_DATE_OPEN,CARD_LIMIT,CARD_STATUS,COMPANY,
				BI_CARD_TYPE,CONTRACT_NUMBER,ACNT_CONTRACT_ID,PRODUCTION_STATUS --THE OFFLINE LAY FULL
			FROM DATA.DBO.CCAPP_APPLICATION_ALL A 
			LEFT JOIN
				(SELECT * 
				FROM DBS_dAILY.DBO.CARD_'+@TODATE+' 
				WHERE BI_CARD_TYPE IN (''RETAIL CARD'',''DIGITAL CARD'') 
					AND COMPANY <> ''VN0010005''
					AND CARD_DATE_OPEN > ''2018-03-31''
				) B 
				ON A.CIF = B.T24_CIF
			WHERE DATEDIFF(D,CONVERT(DATE,CONVERT(DATETIME,SAVE_DATE,103)),CARD_DATE_OPEN) >= 5
		) A 

       DROP TABLE IF EXISTS DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
       SELECT 
              A.*, B.CARD_TYPE,B.CARD_DATE_OPEN,B.CARD_LIMIT,B.CARD_STATUS,B.COMPANY,
              B.BI_CARD_TYPE,B.CONTRACT_NUMBER,B.ACNT_CONTRACT_ID,B.PRODUCTION_STATUS, C.ISSUED_METHOD, C.CAMPAIGN_CODE PROMOTION_CODE 
		INTO DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
       FROM DATA.DBO.CCAPP_APPLICATION_ALL A 
		LEFT JOIN ##CARD B  ON A.CIF = B.T24_CIF
		LEFT JOIN BIC_RB.DAILY_RETAIL.DBO.CREDITCARD_'+@RBDATE+' C  ON B.ACNT_CONTRACT_ID = C.ACNT_CONTRACT_ID

')

EXEC
('
ALTER TABLE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
	ADD BRANCH_CITY VARCHAR(200),GAP FLOAT, DF VARCHAR(20)
')

EXEC
('
	PRINT ''UPDATE BRANCH''
	UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
		SET BRANCH_CITY = NULL

	UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
	SET BRANCH_CITY = B.CITY
	FROM DATA.DBO.DIGITAL_CARD_LEADS_RECHECK A, DATA.DBO.BRANCH_CODE B
	WHERE A.COMPANY = B.BRANCH_ID
')


EXEC
('
       PRINT ''UPDATE GAP & DF''
       UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
              SET GAP = DATEDIFF(D,CAST(SAVE_DATE AS DATE),CARD_DATE_OPEN)
                     WHERE COMPANY <> ''VN0010005''

       UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
              SET DF = (CASE WHEN COMPANY = ''VN0010005'' AND BI_CARD_TYPE NOT IN (''ONLINE CARD'',''TIMO CARD'') THEN ''DF-ONLINE''
                                     WHEN COMPANY <> ''VN0010005'' AND BI_CARD_TYPE NOT IN (''ONLINE CARD'',''TIMO CARD'') AND GAP >= 5 
                                                AND isnull(ISSUED_METHOD,0) NOT LIKE ''%PRE%EMBOSS%'' THEN ''DF-OFFLINE''
                                                  ELSE NULL END)

')


--======================================= TEST NEW RULE

print 'UPDATE CREDIT CARD' 
EXEC
('

DROP TABLE IF EXISTS ##CARD
SELECT * INTO ##CARD 
FROM 
(	SELECT 
		CIF T24_CIF,CARD_TYPE,CARD_DATE_OPEN,CARD_LIMIT,CARD_STATUS,COMPANY,BI_CARD_TYPE,
		CONTRACT_NUMBER,ACNT_CONTRACT_ID,PRODUCTION_STATUS,APP_ID_C,CREATION_DAY
	FROM DATA.DBO.CCAPP_APPLICATION_ALL A 
	 LEFT JOIN 
		(SELECT A.*, B.CREATION_DAY 
		FROM DBS_dAILY.DBO.CARD_'+@todate+' A 
			LEFT JOIN DATA.DBO.LOS_INFORMATION B  ON A.APP_ID_C = B.SZDISPLAYAPPLICATIONNO
        WHERE BI_PRODUCT_GROUP = ''01.Credit Card'' 
			AND BI_CARD_TYPE IN (''RETAIL CARD'',''DIGITAL CARD'') 
			AND A.COMPANY <> ''VN0010005''
			AND  NOT EXISTS (SELECT 1 FROM bic_rb.DAILY_RETAIL.DBO.CREDITCARD_'+@RBdate+' C 
                                        WHERE ISSUED_METHOD  LIKE ''%PRE%EMBOSS%''
										AND A.ACNT_CONTRACT_ID = C.ACNT_CONTRACT_ID
                                        AND ACNT_CONTRACT_ID IS NOT NULL)

        ) B  ON A.CIF = B.T24_CIF
	WHERE DATEDIFF(D,CONVERT(DATE,CONVERT(DATETIME,SAVE_DATE,103)),CARD_DATE_OPEN) BETWEEN 5 AND 90
	AND (
		(CONVERT(DATE,CONVERT(DATETIME,SAVE_DATE,103)) <= CREATION_DAY 
				AND B.CREATION_DAY <= CARD_DATE_OPEN)
		OR B.CREATION_DAY IS NULL
		)
	
	UNION ALL
	SELECT 
		T24_CIF,CARD_TYPE,CARD_DATE_OPEN,CARD_LIMIT,CARD_STATUS,COMPANY,BI_CARD_TYPE,
		CONTRACT_NUMBER,ACNT_CONTRACT_ID,PRODUCTION_STATUS,APP_ID_C,NULL -- THE ONLINE LAY FULL
	FROM DBS_dAILY.DBO.CARD_'+@todate+'
	WHERE BI_PRODUCT_GROUP = ''01.Credit Card''
		AND COMPANY = ''VN0010005''
       ) A
 ')
 exec('
 
DROP TABLE IF EXISTS DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
SELECT A.*, B.CARD_TYPE,B.CREATION_DAY,B.CARD_DATE_OPEN,B.CARD_LIMIT,B.CARD_STATUS,B.COMPANY,B.BI_CARD_TYPE,B.CONTRACT_NUMBER,B.ACNT_CONTRACT_ID,B.PRODUCTION_STATUS
       INTO DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
       FROM DATA.DBO.CCAPP_APPLICATION_ALL A LEFT JOIN ##CARD B
                     ON A.CIF = B.T24_CIF
')
 
EXEC
('
ALTER TABLE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
       ADD BRANCH_CITY VARCHAR(200),GAP FLOAT, DF VARCHAR(20)
')
 
EXEC
('
print ''UPDATE BRANCH''
UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
       SET BRANCH_CITY = NULL
 
UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
       SET BRANCH_CITY = B.CITY
              FROM DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST A, DATA.DBO.BRANCH_CODE B
                     WHERE A.COMPANY = B.BRANCH_ID
')
 
EXEC
('
print ''UPDATE GAP & DF''
UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
       SET GAP = DATEDIFF(D,cast(SAVE_DATE as date),CARD_DATE_OPEN)
              WHERE COMPANY <> ''VN0010005''
 
UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK_TEST
       SET DF = (CASE WHEN COMPANY = ''VN0010005'' AND BI_CARD_TYPE NOT IN (''ONLINE CARD'',''TIMO CARD'') THEN ''DF-ONLINE''
                              WHEN BI_CARD_TYPE NOT IN (''ONLINE CARD'',''TIMO CARD'') 
                                         AND DATEDIFF(D,CONVERT(DATE,CONVERT(DATETIME,SAVE_DATE,103)),CARD_DATE_OPEN) BETWEEN 5 AND 90
                                         AND (
                                                (CONVERT(DATE,CONVERT(DATETIME,SAVE_DATE,103)) <= CREATION_DAY 
                                                AND CREATION_DAY <= CARD_DATE_OPEN)
                                                OR CREATION_DAY IS NULL
                                                ) 
                                         THEN ''DF-OFFLINE''
                                  ELSE NULL END)
')
 
 EXEC
('
ALTER TABLE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
       ADD CUS_OPEN_DATE DATE, DIFF_APP_CUS FLOAT
')
 
EXEC
('
UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
       SET CUS_OPEN_DATE = B.CUS_OPEN_DATE
              FROM DATA.DBO.DIGITAL_CARD_LEADS_RECHECK A, DBS_dAILY.DBO.CUSTOMER_'+@TODATE+' B
                     WHERE A.CIF = B.RECID
 
UPDATE DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
       SET DIFF_APP_CUS = DATEDIFF(D,SAVE_DATE,CUS_OPEN_DATE)
')
 
 EXEC
('
DROP TABLE IF EXISTS ##TEMP
SELECT A.*, B.CREATION_DAY,(CASE WHEN CONVERT(DATE,SAVE_DATE) <= CREATION_DAY THEN 1 ELSE NULL END) DIFF_APP_LOS, 
                                            (CASE WHEN CREATION_DAY <= CARD_DATE_OPEN THEN 1 ELSE NULL END) DIFF_LOS_CARD,B.DAO_CODE
       INTO ##TEMP
       FROM DATA.DBO.DIGITAL_CARD_LEADS_RECHECK A LEFT JOIN 
       (SELECT A.ACNT_CONTRACT_ID, A.APP_ID_C,B.CREATION_DAY,B.DAO_CODE
              FROM DATA.DBO.CARD_LIVE A LEFT JOIN DATA.DBO.LOS_INFORMATION B ON A.APP_ID_C = B.SZDISPLAYAPPLICATIONNO) B
       ON A.ACNT_CONTRACT_ID = B.ACNT_CONTRACT_ID
              WHERE CONVERT(DATE,SAVE_DATE) <= '''+@TODATE+'''
')
 
EXEC
('
DROP TABLE IF EXISTS DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
SELECT * INTO DATA.DBO.DIGITAL_CARD_LEADS_RECHECK FROM ##TEMP
')


------------UPDATE LAI CARD DF 
EXEC('
	UPDATE a 
	SET BI_CARD_TYPE = ''DIGITAL CARD''
	FROM CARD_'+@TODATE+' A, 
		(SELECT DISTINCT ACNT_CONTRACT_ID
		FROM DATA.DBO.DIGITAL_CARD_LEADS_RECHECK
			WHERE CARD_TYPE NOT LIKE ''%SME%''
			AND CARD_TYPE NOT LIKE ''%CORPORATE%''
			AND DF = ''DF-OFFLINE'' 
			AND CARD_DATE_OPEN BETWEEN '''+@FROMDATE+''' AND '''+@TODATE+''') B -- TỪ NGÀY ĐẦU THÁNG ĐẾN NGÀY BÁO CÁO
	WHERE A.ACNT_CONTRACT_ID = B.ACNT_CONTRACT_ID
	AND BI_PRODUCT_GROUP = ''01.CREDIT CARD''
	AND BI_CARD_TYPE = ''RETAIL CARD''
')


DROP TABLE IF EXISTS ##TEMP

END
GO
