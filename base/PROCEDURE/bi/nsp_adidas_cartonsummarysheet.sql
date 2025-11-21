SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: ADIDAS PH CARTON SUMMARY SHEET
DATE				VER		CREATEDBY   PURPOSE
07-SEPT-2023		1.0		JAM			PRINTED DOCUMENT 
************************************************************************/
CREATE   PROC [BI].[nsp_Adidas_CartonSummarySheet] 
	@PARAM_WMS_c_Storerkey nvarchar(20)		
	, @PARAM_WMS_c_Receiptkey nvarchar(20)	
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
	IF ISNULL(@PARAM_WMS_c_Storerkey, '') = ''
		SET @PARAM_WMS_c_Storerkey = ''
	IF ISNULL(@PARAM_WMS_c_Receiptkey, '') = ''
		SET @PARAM_WMS_c_Receiptkey = ''
   DECLARE @Debug	BIT = 1
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_WMS_c_Storerkey":"'    +@PARAM_WMS_c_Storerkey+'", '
									+ '"PARAM_WMS_c_Receiptkey":"'    +@PARAM_WMS_c_Receiptkey+'"  '
                                    + ' }'
   EXEC BI.dspExecInit @ClientId = @PARAM_WMS_c_Storerkey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
	DECLARE @Stmt NVARCHAR(2000) = ''
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '
select R.ReceiptKey [ASN]
, R.ExternReceiptKey [DR]
, CONVERT(VARCHAR,R.ReceiptDate,101) [DATE_RECEIVE]
, S.Style [ARTICLE]
, S.Price [NEW_RPP]
, COUNT(DISTINCT(RD.Lottable10)) [SUM_OF_CTNS]
, SUM(RD.QtyExpected) [SUM_OF_QTY]
from bi.v_RECEIPT R (nolock)
join bi.V_ReceiptDetail RD (nolock) on (rd.ReceiptKey=r.ReceiptKey)
join bi.V_SKU S (nolock) on (S.StorerKey=r.StorerKey AND RD.Sku=S.SKU)
where R.storerkey='''+@PARAM_WMS_c_Storerkey+'''
and R.ReceiptKey='''+@PARAM_WMS_c_Receiptkey+'''
GROUP BY R.ReceiptKey, R.ExternReceiptKey, CONVERT(VARCHAR,R.ReceiptDate,101),S.Price, S.Style
ORDER BY 4'
/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;
END

GO