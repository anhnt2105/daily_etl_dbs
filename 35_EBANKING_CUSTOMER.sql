USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_35_EBANKING_CUSTOMER]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[PR_DAILY_ETL_35_EBANKING_CUSTOMER] 

AS 
BEGIN

DECLARE @TO_DATE VARCHAR(8) 
SET @TO_DATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )

DECLARE @LAST_2M_DATE VARCHAR(8) = (SELECT CONVERT(VARCHAR(8),DATEADD(M,-2,CONVERT(DATE,@TO_DATE)),112))
DECLARE @LAST_3M_DATE VARCHAR(8) = (SELECT CONVERT(VARCHAR(8),DATEADD(M,-3,CONVERT(DATE,@TO_DATE)),112))
DECLARE @LASTMONTH  VARCHAR(8)   = ( SELECT CONVERT(VARCHAR(8),DATEADD(MS,-3,DATEADD(MM,0,DATEADD(MM,DATEDIFF(MM,0,''+@TO_DATE+''),0))),112) )

------------EBANKING_CUSTOMER 

EXEC('
	DROP TABLE IF EXISTS EBANKING_CUSTOMER_'+@TO_DATE+'
	')

exec('
	CREATE TABLE EBANKING_CUSTOMER_'+@TO_DATE+'(
		[CHANNEL] VARCHAR(20), 
		T24_CIF VARCHAR(20) , 
		FIRST_OPEN_DATE datetime, 
		FIRST_ACTIVATED_DATE datetime, 
		ACTIVE_STT INT,
		ACTIVE_STT_1M INT,
		NEARLY_INACTIVE_STT INT ,
		FIRST_LOGIN_MOBILE DATETIME,
		FIRST_LOGIN_WEB DATETIME, 
		FIRST_LOGIN_DATE DATETIME , 
		LAST_LOGIN_MOBILE DATETIME,
		LAST_LOGIN_WEB DATETIME, 
		LAST_LOGIN_DATE DATETIME , 
		FIRST_TRANS_DATE DATETIME, 
		FIRST_TRANS_TYPE VARCHAR(100), 
		FIRST_TRANS_CHANNEL VARCHAR(20), 
		LAST_TRANS_DATE DATETIME, 
		LAST_TRANS_TYPE VARCHAR(100), 
		LAST_TRANS_CHANNEL VARCHAR(20), 
	  CONSTRAINT PK_EBK_CUS_'+@TO_DATE+' PRIMARY KEY CLUSTERED (T24_CIF ASC) 
	  ) 
') 

EXEC('
	INSERT INTO EBANKING_CUSTOMER_'+@TO_DATE+'(CHANNEL , T24_CIF, First_open_Date, First_activated_Date)
	SELECT 
		''TOTAL EBANKING'' AS CHANNEL ,  T24_CIF, 
		min(Open_date) as First_open_Date,
		min(ACTIVATED_DATE) as First_activated_Date
	FROM EBANKING_USER_'+@TO_DATE+' 
	WHERE 
		AMND_STATE  = ''A'' 
	GROUP BY T24_CIF
	')

exec('
	UPDATE A 
	SET FIRST_LOGIN_MOBILE = b.FIRST_LOGIN_MOBILE,
		FIRST_LOGIN_WEB = b.FIRST_LOGIN_WEB, 
		FIRST_LOGIN_DATE = b.FIRST_LOGIN_DATE , 
		LAST_LOGIN_MOBILE = b.LAST_LOGIN_MOBILE,
		LAST_LOGIN_WEB = b.LAST_LOGIN_WEB , 
		LAST_LOGIN_DATE = b.LAST_LOGIN_DATE
	FROM EBANKING_CUSTOMER_'+@to_date+' A 
	INNER JOIN EBANK_CUSTOMER_FIRST_LOGIN_'+@to_date+' B ON A.T24_CIF = B.T24_CIF 
	
	DROP TABLE IF EXISTS #TXN 

	SELECT *, 
		ROW_NUMBER() OVER(PARTITION BY T24_CIF ORDER BY FIRST_TRANS_DATE ASC) AS FST_TXN ,
		ROW_NUMBER() OVER(PARTITION BY T24_CIF ORDER BY LAST_TRANS_DATE DESC) AS LST_TXN
	INTO #TXN 
	FROM EBANKING_USER_FIRST_LOGIN_'+@to_date+'
	WHERE FIRST_TRANS_DATE IS NOT NULL 
	AND LAST_TRANS_DATE IS NOT NULL 

	UPDATE A 
	SET 
		A.FIRST_TRANS_DATE = B.FIRST_TRANS_DATE, 
		A.FIRST_TRANS_TYPE = B.FIRST_TRANS_TYPE, 
		A.FIRST_TRANS_CHANNEL = B.CHANNEL 
	FROM EBANKING_CUSTOMER_'+@to_date+' A 
	INNER JOIN 
		(SELECT * FROM #TXN WHERE FST_TXN = 1 ) B ON A.T24_CIF = B.T24_CIF 

	UPDATE A 
	SET 
		A.LAST_TRANS_DATE = B.LAST_TRANS_DATE, 
		A.LAST_TRANS_TYPE = B.LAST_TRANS_TYPE, 
		A.LAST_TRANS_CHANNEL = B.CHANNEL 
	FROM EBANKING_CUSTOMER_'+@to_date+' A 
	INNER JOIN 
		(SELECT * FROM #TXN WHERE LST_TXN = 1 ) B ON A.T24_CIF = B.T24_CIF 
')

exec('
	UPDATE A 
	SET ACTIVE_STT = 1 
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE EXISTS (SELECT * FROM EBANKING_USER_'+@TO_DATE+'  B 
				WHERE AMND_STATE = ''A'' AND ACTIVE_STT = 1 AND A.T24_CIF = B.T24_CIF )

	UPDATE A 
	SET ACTIVE_STT = 0 
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE ACTIVE_STT IS NULL

	UPDATE A 
	SET ACTIVE_STT_1M = 1 
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE EXISTS (SELECT * FROM EBANKING_USER_'+@TO_DATE+'  B 
				WHERE AMND_STATE = ''A'' AND ACTIVE_STT_1M = 1 AND A.T24_CIF = B.T24_CIF )

	UPDATE A 
	SET ACTIVE_STT_1M = 0 
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE ACTIVE_STT_1M IS NULL
')

-------------LAST_ACTIVATED_DATE THEO CUSTOMER 
EXEC('
SELECT T24_CIF , MAX(COALESCE(ACTIVATED_DATE,OPEN_DATE)) AS LAST_ACTIVATED_DATE 
INTO #LAST_ACTIVATED_DATE 
FROM DBS_dAILY.DBO.EBANKING_USER_'+@TO_DATE+' 
WHERE 
	(CHANNEL LIKE ''VPO%'' OR CHANNEL LIKE ''MOBILE%'' OR CHANNEL = ''TIMO'' )
	AND AMND_STATE = ''A'' 
GROUP BY 
	T24_CIF 

/*
-------------BANG EBANKING CUSTOMER FIRST LOGIN KO COVER DUOC PHAN TIMO & B2B 
SELECT T24_CIF , MAX(LAST_TRANS_DATE) AS LAST_TRANS_DATE, MAX(LAST_LOGIN_DATe) AS LAST_LOGIN_DATE 
INTO #CUST_FIRST_LOGIN 
FROM DBS_dAILY.DBO.EBANKING_USER_FIRST_LOGIN_'+@TO_DATE+'
GROUP BY T24_CIF
*/

------------UPDATE CAC KH ACTIVE KHONG CO GD TRONG 2 THANG GAN NHAT 
UPDATE A 
SET NEARLY_INACTIVE_STT = 1  
FROM DBS_dAILY.DBO.EBANKING_CUSTOMER_'+@TO_DATE+' A 
WHERE ((ISNULL(LAST_TRANS_DATE,0) < ISNULL(LAST_LOGIN_DATE,0) AND DATEDIFF(D, LAST_LOGIN_DATE,'''+@TO_DATE+''') >=  DATEDIFF(D,'''+@LAST_2M_DATE+''' , '''+@TO_DATE+''') )
	OR (ISNULL(LAST_TRANS_DATE,0) >= ISNULL(LAST_LOGIN_DATE,0) AND DATEDIFF(D, LAST_TRANS_DATE,'''+@TO_DATE+''') >=  DATEDIFF(D,'''+@LAST_2M_DATE+''' , '''+@TO_DATE+''')  ))
AND ACTIVE_STT = 1 

------------UPDATE CAC KH ACTIVE CHUA CO GD NAO, ACTIVATED HON 2 THANG TRC 

UPDATE A 
SET NEARLY_INACTIVE_STT = 1 
FROM DBS_dAILY.DBO.EBANKING_CUSTOMER_'+@TO_DATE+' A 
	LEFT JOIN #LAST_ACTIVATED_DATE C ON A.T24_CIF = C.T24_CIF 
WHERE COALESCE(LAST_TRANS_DATE, LAST_LOGIN_DATE) IS NULL 
	AND ACTIVE_STT = 1 
	AND NEARLY_INACTIVE_STT IS NULL 
	AND DATEDIFF(D,LAST_ACTIVATED_DATE, '''+@TO_DATE+''') >= DATEDIFF(D,'''+@LAST_2M_DATE+''' , '''+@TO_DATE+''')
')
-----------UPDATE CAC TH CON LAI 

EXEC('
	UPDATE A 
	SET NEARLY_INACTIVE_STT = 0  
	FROM DBS_dAILY.DBO.EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE ACTIVE_STT = 1 
		AND NEARLY_INACTIVE_STT IS NULL 
') 

---------ACTIVE_TYPE_FIN 

EXEC('
ALTER TABLE EBANKING_CUSTOMER_'+@TO_DATE+' 
	ADD ACTIVE_TYPE_FIN VARCHAR(50)
')
----STEP 1 : SET ACTIVE NEW CHO CUSTOMER CO NGAY ACTIVATED DATE DAU TIEN TRONG VONG 3 THANG GAN NHAT 
EXEC('
	UPDATE A
	SET ACTIVE_TYPE_FIN = ''ACTIVE NEW''
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE  (FIRST_ACTIVATED_DATE > '''+@LAST_3M_DATE+''' AND FIRST_ACTIVATED_DATE  < DATEADD(D,1,'''+@TO_DATE+''') )
		AND ACTIVE_STT = 1 
	')

----STEP 2 : SET ACTIVE MAINTAIN CHO CUSTOMER VAN DUY TRI TRANG THAI ACTIVE SO VOI THANG TRUOC 
EXEC('
	UPDATE A 
	SET ACTIVE_TYPE_FIN = ''ACTIVE MAINTAIN''
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE FIRST_ACTIVATED_DATE < DATEADD(D,1,'''+@LAST_3M_DATE+''')
		AND ACTIVE_STT = 1 
		AND ACTIVE_TYPE_FIN IS NULL 
		AND EXISTS (SELECT * FROM DBS_MONTHLY.DBO.EBANKING_CUSTOMER_'+@LASTMONTH+'  B 
					WHERE A.T24_CIF = B.T24_CIF 
						AND ACTIVE_STT = 1 )
	')

----STEP 3: SET ACTIVE WAKEUP CHO NHUNG CUSTOMER CHUYEN TU INACTIVE/CHUA KICH HOAT THANG TRUOC SANG ACTIVE THANG NAY 
EXEC('
	UPDATE A
	SET ACTIVE_TYPE_FIN = ''ACTIVE WAKE UP''
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE FIRST_ACTIVATED_DATE < DATEADD(D,1,'''+@LAST_3M_DATE+''')
		AND ACTIVE_STT  = 1 
		AND EXISTS (SELECT * FROM DBS_MONTHLY.DBO.EBANKING_CUSTOMER_'+@LASTMONTH+' B 
					WHERE A.T24_CIF = B.T24_CIF 
						AND ISNULL(ACTIVE_STT,0) = 0 )
		AND ACTIVE_TYPE_FIN IS NULL 
	')
-----STEP 4: SET ATTRITION CHO NHUNG KH CHUYEN TU TRANG THAI ACTIVE THANG TRUOC --> INACTIVE THANG NAY 
EXEC('
	UPDATE  A 
	SET ACTIVE_TYPE_FIN = ''ATTRITION''
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE ACTIVE_STT = 0  
		AND EXISTS (SELECT * FROM DBS_MONTHLY.DBO.EBANKING_CUSTOMER_'+@LASTMONTH+'  B 
					WHERE A.T24_CIF = B.T24_CIF
						AND ACTIVE_STT = 1  )
		AND ACTIVE_TYPE_FIN IS NULL 
	')
-----STEP 5: SET INACTIVE CHO TAP KH STAY INACTIVE 
EXEC('
	UPDATE A
	SET ACTIVE_TYPE_FIN = ''INACTIVE'' 
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A 
	WHERE ACTIVE_STT = 0 		
		AND EXISTS (SELECT * FROM DBS_MONTHLY.DBO.EBANKING_CUSTOMER_'+@LASTMONTH+'  B 
						WHERE A.T24_CIF = B.T24_CIF
						AND ISNULL(ACTIVE_STT,0) = 0 )
		AND ACTIVE_TYPE_FIN IS NULL 
	')
-----STEP 6: SET ACTIVE_TYPE_FIN CHO CAC TAP KH KO XUAT HIEN TRONG THANG TRUOC 
EXEC('
	UPDATE A 
	SET A.ACTIVE_TYPE_FIN = CASE WHEN ACTIVE_STT = 1 THEN ''ACTIVE WAKE UP''
								WHEN  ACTIVE_STT = 0 THEN ''ATTRITION''
							END 
	FROM EBANKING_CUSTOMER_'+@TO_DATE+' A  
	WHERE A.ACTIVE_TYPE_FIN IS NULL 
		AND NOT EXISTS (SELECT 1 FROM DBS_MONTHLY.DBO.EBANKING_CUSTOMER_'+@LASTMONTH+' D 
						WHERE A.T24_CIF = D.T24_CIF )
	') 

END

GO
