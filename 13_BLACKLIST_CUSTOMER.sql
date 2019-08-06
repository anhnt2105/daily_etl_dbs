USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_13_BLACKLIST_CUSTOMER]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_13_BLACKLIST_CUSTOMER] AS 
BEGIN 

DECLARE @TODATE VARCHAR(8) , @LASTMONTH VARCHAR(8) , @FROMDATE VARCHAR(8)
SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )

--CREATE TABLE DBS_REF.DBO.DBS_BLACKLIST_CUSTOMER (
--CUS_GROUP VARCHAR(50) , 
--T24_CIF VARCHAR(10) , 
--EMAIL_ADDR VARCHAR(200) ,  
--MOBILE VARCHAR(20)  
--)

--CREATE NONCLUSTERED INDEX PK_EXCL_CUS 
--ON DBS_REF.DBO.DBS_BLACKLIST_CUSTOMER (T24_CIF  ASC) 

EXEC('
	DELETE FROM DBS_REF.DBO.DBS_BLACKLIST_CUSTOMER 
	WHERE CUS_GROUP = ''TIMO''
	')
EXEC('
	SELECT A.* ,  ROW_NUMBER() OVER(PARTITION BY RECID , EMAIL_ADDR, MOBILE ORDER BY RECID ) AS ROW_NUMBER 
	INTO #LIST_TIMO
	FROM 
		(
		selecT recid  , email_addr,  Mobile 
		from customer_'+@TODATE+'  b 
		WHERE COMPANY_BOOK= ''VN0010348''		
			or CUST_TYPE IN (''59'',''60'')

		UNION ALL 

		selecT  recid  ,  I2B_EMAIL , I2B_MOBILE
		from customer_'+@TODATE+'  b 
		WHERE COMPANY_BOOK= ''VN0010348''		
			AND I2B_EMAIL IS NOT NULL 

		UNION ALL 

		selecT  recid  ,  I2B_EMAIL, I2B_MOBILE
		from customer_'+@TODATE+'  b 
		WHERE COMPANY_BOOK= ''VN0010348''		
			AND I2B_MOBILE IS NOT NULL 
		) A 

	INSERT INTO DBS_REF.DBO.DBS_BLACKLIST_CUSTOMER 
	SELECt ''TIMO'' , RECID , EMAIL_ADDR , MOBILE 
	FROM #LIST_TIMO 
	WHERE ROW_NUMBER = 1 
	')
-----SPECIAL CASE 

/*
EXEC('
	insert into DBS_REF.DBO.DBS_BLACKLIST_CUSTOMER 
	selecT  ''OTHER'' , RECID ,   EMAIL_ADDR , MOBILE 
	from customer_'+@TODATE+' 
	where EMAIL_ADDR = ''vinhpq@gmail.com'' 
	')
*/
END
GO
