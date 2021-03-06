USE [DBS_DAILY]
GO
/****** Object:  StoredProcedure [dbo].[PR_DAILY_ETL_11_OCB_TRANS]    Script Date: 8/6/2019 10:56:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PR_DAILY_ETL_11_OCB_TRANS]
AS 
BEGIN 

DECLARE @TODATE VARCHAR(8)
DECLARE	@FROMDATE		VARCHAR(8)

---SET @TODATE = '20170923'
SET @TODATE    = (SELECT RPTDATE FROM DBS_REF.DBO.RPTDATE )
---SET @FROMDATE  = CONVERT(VARCHAR(8), DATEADD(D, -30, @TODATE), 112)
set @FROMDATE = left(@todate, 6) + '01' 

------------------------------------ EBANKING OCB TRANSACTION -----------------------------------
exec('
	drop table if exists DATA.DBO.EBANKING_OCB_TRANSACTION 	
	select 
		[SOURCE]
      ,[TRANS_TYPE]
      ,case when [CHANNEL] = ''WEB'' THEN ''I2B'' ELSE CHANNEL END CHANNEL
      ,[MERCHANT_USED]
      ,[TXN_STATUS]
      ,[BANK_STATUS]
      ,[CUSTOMERID]
      ,CASE WHEN SOURCE = ''TBL_EBA_AUTO_BILLING_TXN'' THEN A.CIF
			ELSE b.CUST_ID END as CIF
      ,[FROM_AC]
      ,[TO_AC]
      ,[SYS_ID]
      ,[TRANS_CODE]
      ,[TXN_AMT]
      ,[TXN_FEE]
      ,[RES_CODE]
      ,[PROCESS_CODE]
      ,[BANK_XID]
      ,[VALUE_DATE]
      ,[FINAL_STATUS]
      ,[RANK_TIME]
      ,[TRANS_TYPE_GROUP]
      ,[INPUT_DATE]
      ,[TXN_MEMO]
      ,[ICASHCHECK]
      ,[Evoucher_Code]
      ,[Evoucher_Amt]
      ,[ExternalAcctID]
      ,[PROVIDER_CODE]
      ,[SERVICE_CODE]
      ,[PROVIDER_NAME]
      ,[SERVICE_NAME]
      ,[TO_AC_BANKNAME]		
	INTO DATA.DBO.EBANKING_OCB_TRANSACTION
from M108.BICDATA_HIS.DBO.DAILY_EBANKING_OCB_TRANSACTION a 
	LEFT JOIN DATA.dbo.DAILY_EB_CUSTOMER_DIRECTORY B 	ON CUSTOMERID = DIRECTORY_ID
where value_Date >= '''+@fromdate+''' 
		and value_date <= '''+@todate+'''
	')


end 
GO
