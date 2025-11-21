SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: BROADCAST REPORT - COLPAL SUMMARY OF INBOUND & OUTBOUND

DATE				VER		CREATEDBY   PURPOSE
08-MAR-2022			1.0		JAM			MIGRATE FROM HYPERION 
09-June-2022		1.1		JAM			Tuning and deploy in PHWMS PROD https://jiralfl.atlassian.net/browse/WMS-22770 
************************************************************************/
-- Test:   EXEC BI.nsp_SCH_GENERIC_SummaryOfInbOut 'PH01'

CREATE     PROC [BI].[nsp_SCH_GENERIC_SummaryOfInbOut] --NAME OF SP
	@param_generic_storerkey nvarchar(20)
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		   SET @PARAM_GENERIC_StorerKey = ''

DECLARE @nRowCnt INT = 0
       , @Proc      NVARCHAR(128) = 'nsp_SCH_GENERIC_SummaryOfInbOut' --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'+@param_generic_storerkey+'"'
                                    + ' }'

DECLARE  @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_GENERIC_StorerKey, @Proc, @cParamIn);
   --*/
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '
SELECT 
   TRIM(R.Facility) as ''01 ReceivingFacility'' 
  ,CONVERT(char(10), R.EditDate, 101) as ''02 ReceivedDate''
  ,SUM(case when P.CaseCnt = 0 then 0 else (RD.QtyReceived) / P.CaseCnt end ) as ''03 ReceivedQty'' 
  ,''ReceivedQty'' as ''04Type''
FROM 
  BI.V_RECEIPT R (nolock) 
  JOIN BI.V_RECEIPTDETAIL RD (nolock) ON R.StorerKey=RD.StorerKey AND R.ReceiptKey = RD.ReceiptKey
  JOIN BI.V_SKU S (nolock) ON RD.StorerKey=S.StorerKey AND RD.Sku = S.Sku
  JOIN BI.V_PACK P (nolock) ON S.PACKKey = P.PackKey
WHERE 
   R.StorerKey = '''+@param_generic_storerkey+''' 
   AND R.Status = ''9''
   AND R.Editdate >= DATEADD(day, DATEDIFF(day, 0, getdate()-7), 0)
GROUP BY 
  R.Facility
  ,CONVERT(char(10), R.EditDate, 101) 

UNION

SELECT 
  TRIM(O.Facility) as ''01 ShippingFacility''
  ,CONVERT(char(10),M.EditDate,101) as ''02 ShippedDate'' 
  ,SUM (case when P.CaseCnt = 0 then 0 else (OD.ShippedQty) / P.CaseCnt end ) as ''03ShippedQty''
  ,''ShippedQty'' as ''04Type''
FROM 
  BI.V_ORDERS O (nolock) 
  JOIN BI.V_ORDERDETAIL OD (nolock) ON (O.STORERKEY=OD.STORERKEY AND O.ORDERKEY=OD.ORDERKEY)
  JOIN BI.V_SKU S (nolock) ON (O.STORERKEY=S.STORERKEY AND OD.SKU=S.SKU)
  JOIN BI.V_PACK P (nolock) ON (S.PACKKEY=P.PACKKEY)
  LEFT JOIN BI.V_MBOL M (nolock) ON (O.FACILITY = M.FACILITY AND O.MBOLKey = M.MbolKey) 
WHERE  
  O.Status = ''9'' AND O.StorerKey = '''+@param_generic_storerkey+'''
  AND M.Editdate >= DATEADD(day, DATEDIFF(day, 0, getdate()-7), 0)
group by 
  O.Facility
  ,CONVERT(char(10),M.EditDate,101) 

order by 2
'
-- USE VIEW TABLES WITH BI SCHEMA : BI.V_DM_ORDERS for PH_DATAMART, BI.V_ORDERS for PHWMS

/*************************** FOOTER *******************************/
 -- print @Stmt
EXEC sp_ExecuteSql @Stmt; -- for dynamic SQL only
SET @nRowCnt = @@ROWCOUNT;

   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL only
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
   WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END

GO