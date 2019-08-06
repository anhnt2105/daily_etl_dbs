USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_08_GET_DATA_M108]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_08_GET_DATA_M108]
AS 

BEGIN

DECLARE @TODATE VARCHAR(8)
DECLARE  @FROMDATE VARCHAR(8) , @START_YEAR VARCHAR(20), @FROMDATE2 VARCHAR(20) 

SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )
SET @FROMDATE   = CONVERT(VARCHAR(8),DATEADD(d,-7, @TODATE),112)-----(SELECT CONVERT(VARCHAR(8),DATEADD(MM,DATEDIFF(MM,0,@TODATE),0),112)) 
SET @FROMDATE2   = LEFT(@TODATE, 6) + '01'
SET @START_YEAR = LEFT(@TODATE,4) + '0101'


EXEC('
	IF EXISTS(SELECT * FROM DATA.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''DAILY_EB_CUSTOMER_DIRECTORY'')
	BEGIN 
		DROP TABLE DATA.DBO.DAILY_EB_CUSTOMER_DIRECTORY
	END
	')
EXEC('
	SELECT * INTO DATA.DBO.DAILY_EB_CUSTOMER_DIRECTORY
	FROM M108.BICDATA_HIS.DBO.DAILY_EB_CUSTOMER_DIRECTORY
') 
-- LẤY BẢNG OCB_NEW

PRINT 'LAY BANG DATA.DBO.OCB_NEW'
EXEC('
	IF EXISTS(SELECT * FROM DATA.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''OCB_NEW'')
	BEGIN 
		DROP TABLE DATA.DBO.OCB_NEW
	END
	')


EXEC (' DROP TABLE IF EXISTS #1 , ##2 

SELECT A. * , B.PARENT_ID
INTO #1
FROM  [M108].[BICDATA_HIS].[DBO].DAILY_EB_CUSTOMER A 
LEFT JOIN  
	(SELECT NAME , PARENT_ID FROM [M108].[BICDATA_HIS].[DBO].[DAILY_EB_ENTITLEMENT_GROUP]
	WHERE ENT_GROUP_TYPE = ''USER'' ) B
		ON  A.USER_NAME = B.NAME
 
SELECT A.* , B.PARENT_ID AS SERVICE_PACK , 
		CASE WHEN B.PARENT_ID = ''200000010'' THEN ''INQUIRY''
            WHEN B.PARENT_ID = ''200000011'' THEN ''STANDARD''
            WHEN B.PARENT_ID = ''200000012'' THEN ''PLATINUM''
            WHEN B.PARENT_ID = ''200000013'' THEN ''VIP''
            WHEN B.PARENT_ID = ''200000015'' THEN ''SUPERVIP'' 
            WHEN B.PARENT_ID = ''200000016'' THEN ''FOREIGNER'' 
			WHEN B.PARENT_ID = ''200000019'' THEN ''FLEXI'' 
		ELSE NULL END	 AS SERVICE_PACK_NAME
INTO ##2 
FROM #1  A 
LEFT JOIN  
	(SELECT PARENT_ID , ENT_GROUP_ID FROM [M108].[BICDATA_HIS].[DBO].[DAILY_EB_ENTITLEMENT_GROUP]
	WHERE ENT_GROUP_TYPE = ''CONSUMERADMIN'' ) B 
		ON A.PARENT_ID = B.ENT_GROUP_ID
 
 ') 
 EXEC
('

SELECT A.DIRECTORY_ID,A.CUST_ID CIF,A.ACCOUNT_STATUS,CONVERT(DATE,A.CREATE_DATE) CREATE_DATE, USER_NAME,BRANCH_CREATED AS BRANCH_NAME,
	   REFERRAL AS CIF_GIOITHIEU,EMAIL_ADDRESS, DATA_PHONE,ADDRESS1, B.TERMS_ACCEPTED, B.DAO, B.TERMS_ACCEPTED_DATE , B.ID_PASSPORT , 
	   B.SERVICE_PACK , B.SERVICE_PACK_NAME, B.PASSWORD_STATUS, B.INPUTTER
	INTO DATA.DBO.OCB_NEW
		FROM DATA.DBO.DAILY_EB_CUSTOMER_DIRECTORY  A, ##2 B 
			WHERE A.DIRECTORY_ID = B.DIRECTORY_ID
			---AND A.ACCOUNT_STATUS  = 1 	
			AND A.CREATE_DATE < DATEADD(D,1,'''+@TODATE+''') 
')
-- BANG TBL_I2B_USERS

PRINT 'LAY BANG DATA.DBO.TBL_I2B_USERS'
EXEC('
	IF EXISTS(SELECT * FROM DATA.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''DAILY_I2B_USERS_F0'')
	BEGIN 
		DROP TABLE DATA.DBO.DAILY_I2B_USERS_F0
	END
	')
EXEC
('
	SELECT * INTO DATA.DBO.DAILY_I2B_USERS_F0
	FROM M108.BICDATA_HIS.DBO.DAILY_I2B_USERS_F0
')


-- BANG USERS_ACTIVATED_DATE 

EXEC('
	DROP TABLE IF EXISTS DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' 
	-----LAY CAC KH DA DKY I2B 

	SELECT  ''I2B'' AS SOURCE , T24_CIF , AMND_STATE , 
			OPEN_DATE AS OPEN_DATE_I2B 
	INTO DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' 
	FROM DATA.DBO.DAILY_I2B_USERS_F0
	-----WHERE AMND_STATE IN (''A'' ,''B'')
	WHERE AMND_STATE  = ''A''
	AND ISNULL(AMND_USER,0) <>  ''OCB'' 
	AND OPEN_DATE < DATEADD(D,1,'''+@TODATE+''') 

	ALTER TABLE  DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' 
	ADD OPEN_DATE_OCB DATETIME , AMND_DATE_OCB DATETIME , USER_TYPE INT  , ACTIVATED_DATE DATETIME 
')
	/*
	CREATE TABLE DBS_REF.DBO.USER_TYPE (USER_TYPE INT, USER_TYPE_NAME VARCHAR(50) , ACTIVATED_DATE_FIELD VARCHAR(50) ) 

	INSERT INTO DBS_REF.DBO.USER_TYPE VALUES(1  ,''HAVE NOT BEEN MIGRATED TO OCB'' , ''OPEN_DATE''  ) ;
	INSERT INTO DBS_REF.DBO.USER_TYPE VALUES( 2  ,''MIGRATED TO OCB - ACCEPTED OCB'' , ''OPEN_DATE'')  ;
	INSERT INTO DBS_REF.DBO.USER_TYPE VALUES(3 ,''MIGRATED TO OCB - HAVE NOT ACCEPTED OCB YET'' , ''OPEN_DATE'')
	INSERT INTO DBS_REF.DBO.USER_TYPE VALUES(4 ,''OCB ONLY'' , ''TERMS_ACCEPTED_DATE'')
	*/

	------UPDATE TREN BẢNG OCB USER ĐỂ XÁC ĐỊNH NGÀY TERM ACCEPTED DATE  (NGÀY DDWWOCJ MIGRATE LÊN OCB)
EXEC('
	UPDATE A
	SET A.OPEN_DATE_OCB = B.CREATE_DATE ,
		A.AMND_DATE_OCB = B.TERMS_ACCEPTED_DATE
	FROM DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' A
	INNER JOIN DATA.DBO.OCB_NEW B ON A.T24_CIF = B.CIF 
	WHERE CREATE_DATE < DATEADD(D,1,'''+@TODATE+''') 

	UPDATE A
	SET	A.USER_TYPE = CASE WHEN OPEN_DATE_OCB IS NULL THEN 1 
						WHEN OPEN_DATE_OCB IS NOT NULL AND AMND_DATE_OCB IS NOT NULL THEN 2  ---------------MIGRATED TO OCB - ACCEPTED OCB
						WHEN OPEN_DATE_OCB IS NOT NULL AND AMND_DATE_OCB IS NULL THEN 3 ----------------------- MIGRATED TO OCB - HAVE NOT ACCEPTED OCB YET
					 END
	FROM DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' A
')

	-----INSERT NHỮNG USER CHỈ MỞ TRÊN OCB 
EXEC('
	INSERT INTO DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' 
	SELECT DISTINCT ''OCB'' , CIF ,  
		CASE WHEN TERMS_ACCEPTED = 1 THEN ''A'' WHEN TERMS_ACCEPTED = 0 THEN ''B'' END, NULL , 
		CREATE_DATE , 
		TERMS_ACCEPTED_DATE, 4 , NULL 
	FROM DATA.DBO.OCB_NEW A 
	WHERE  NOT EXISTS (SELECT * FROM DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+'  B WHERE A.CIF = B.T24_CIF) 
	and ACCOUNT_STATUS = 1 
	AND CREATE_DATE < DATEADD(D,1,'''+@TODATE+''') 

	UPDATE A
	SET ACTIVATED_DATE = CASE WHEN USER_TYPE = 1 THEN OPEN_DATE_I2B 
							WHEN USER_TYPE IN (2,3) THEN OPEN_DATE_I2B 
							WHEN USER_TYPE = 4 THEN AMND_DATE_OCB 
						END 
	FROM DBS_dAILY.DBO.EBANKING_USERS_ACTIVATED_DATE_'+@TODATE+' A  

')

-- UPDATE KHÁCH HÀNG CÁ NHÂN VÀO OCB_NEW

IF NOT EXISTS( SELECT * FROM DATA.INFORMATION_SCHEMA.COLUMNS 
			WHERE TABLE_NAME = 'OCB_NEW' 
				AND COLUMN_NAME IN ('BI_CHANNEL', 'SEGMENT'))
EXEC
('
ALTER TABLE DATA.DBO.OCB_NEW
	ADD BI_CHANNEL VARCHAR(20),SEGMENT VARCHAR(20)
')

EXEC
('
PRINT N''UPDATE KHÁCH HÀNG CÁ NHÂN VÀO OCB_NEW''
UPDATE  DATA.DBO.OCB_NEW
	SET BI_CHANNEL = B.BI_CHANNEL,
		SEGMENT = CASE WHEN B.COMPANY_BOOK  = ''VN0010344'' THEN ''HH'' 
					WHEN B.COMPANY_BOOK  = ''VN0010260'' OR DIVISION = ''CF'' THEN ''FE'' 
					WHEN B.COMPANY_BOOK  = ''VN0010348'' AND B.CUST_TYPE IN (''59'',''60'') THEN ''TIMO'' 
					ELSE B.SEGMENT END 
			FROM  DATA.DBO.OCB_NEW A, CUSTOMER_'+@TODATE+'  B
				WHERE A.CIF = B.RECID 
')


PRINT 'LAY BANG MBBANKING_ACC'
exec('
	drop table if exists DATA.DBO.TBL_I2B_MBANKING_ACC

	select * 
	into  DATA.DBO.TBL_I2B_MBANKING_ACC
	from m108.bicdata_his.dbo.Daily_I2B_MBANKING_ACC

	DROP TABLE IF EXISTS DATA.DBO.TBL_EB_MBBANKING_ACC
	SELECT * 
	INTO DATA.DBO.TBL_EB_MBBANKING_ACC
	FROM m108.bicdata_his.dbo.Daily_EB_MBBANKING_ACC
')
-- i2b_transfer_Txn

/*
exec('
	 DROP TABLE IF EXISTS DATA.DBO.TBL_i2b_transfer_Txn 
	
	select *
	into DATA.DBO.TBL_i2b_transfer_Txn 
	FROM M108.BICDATA_HIS.DBO.DAILY_I2B_TRANSFER_TXN T1
	where t1.value_Date >= '''+@FROMDATE2+''' 
		AND T1.VALUE_DATE <= '''+@TODATE+'''
	') 

-- LẤY BẢNG DAILY_EB_AUDIT_LOG

EXEC('
	if exists (select  * from data.sys.indexes where name = ''IDX_LG_DT'' )
	DROP INDEX [IDX_LG_DT] ON [DATA].[dbo].[DAILY_EB_AUDIT_LOG]
	')
EXEC('
	CREATE NONCLUSTERED INDEX [IDX_LG_DT] 
		ON DATA.[dbo].[DAILY_EB_AUDIT_LOG] ([LOG_DATE] DESC)
	')

EXEC('
	DELETE FROM DATA.DBO.DAILY_EB_AUDIT_LOG
	WHERE LOG_DATE >= '''+@FROMDATE+'''
	')

EXEC('
	INSERT INTO DATA.DBO.DAILY_EB_AUDIT_LOG
	SELECT 
		[TRAN_ID]
      ,[USER_ID]
      ,[IP_ADDRESS]
      ,[CHANNEL]
      ,[AGENT_ID]
      ,[AGENT_TYPE]
      ,[DESCRIPTION]
      , case when  CHARINDEX(''.'',LOG_DATE,1)  = 0 then cast(LOG_DATE as datetime) 
			else cast(left(LOG_DATE, CHARINDEX(''.'',LOG_DATE,1)-1) as datetime) end
      ,[TRAN_TYPE]
      ,[AMOUNT]
      ,[CURRENCY_CODE]
      ,[SRVR_TID]
      ,[STATE]
      ,[FROM_ACCT_ID] ,TO_ACCT_ID	
	FROM M108.BICDATA_HIS.DBO.DAILY_EB_AUDIT_LOG
	WHERE business_Date >= cast('''+@FROMDATE+''' as date) 

	') 
*/
END 



GO
