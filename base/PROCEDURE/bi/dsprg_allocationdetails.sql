SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************************************/
-- Purpose  : MYS-LogiReport-Create Views/SP in BI Schema
--            https://jiralfl.atlassian.net/browse/WMS-19701
/* Updates:                                                                                              */
/* Date         Author      Ver.  Purposes                                                               */
/* 19-Mar-2022  JarekLim    1.0   Created                                                                */
/*********************************************************************************************************/
--EXEC  BI.dspRG_AllocationDetails 'SKECHERS','%','%','149181-BKCC-10%','%','%'
--EXEC  BI.dspRG_AllocationDetails '','','','','','',''
--EXEC  BI.dspRG_AllocationDetails NULL,NULL,NULL,NULL,NULL,NULL,NULL
CREATE PROC [BI].[dspRG_AllocationDetails]
     @PARAM_GENERIC_StorerKey NVARCHAR(15) = ''
	 ,@PARAM_GENERIC_OrderKey_S NVARCHAR(20) = ''
	 ,@PARAM_GENERIC_LoadKey_S  NVARCHAR(20) = ''
	 ,@PARAM_GENERIC_SKU_S NVARCHAR(40) = ''
	 ,@PARAM_GENERIC_Location_S NVARCHAR(20) = ''
	 ,@PARAM_GENERIC_ID_S NVARCHAR(36)  = ''

AS
BEGIN
SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		   SET @PARAM_GENERIC_StorerKey = ''
	IF ISNULL(@PARAM_GENERIC_OrderKey_S, '') = ''
	       SET @PARAM_GENERIC_OrderKey_S = ''
	IF ISNULL(@PARAM_GENERIC_LoadKey_S, '') = ''
		   SET @PARAM_GENERIC_LoadKey_S = ''
	IF ISNULL(@PARAM_GENERIC_SKU_S, '') = ''
		   SET @PARAM_GENERIC_SKU_S = ''
	IF ISNULL(@PARAM_GENERIC_Location_S, '') = ''
		   SET @PARAM_GENERIC_Location_S = ''
	IF ISNULL(@PARAM_GENERIC_ID_S, '') = ''
		   SET @PARAM_GENERIC_ID_S = ''
		

		DECLARE    @nRowCnt INT = 0
		       , @Debug     BIT   = 0
               , @Proc      NVARCHAR(128) = 'dspRG_AllocationDetails'
               , @cParamOut NVARCHAR(4000)= ''
               , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'"'
									 + '"PARAM_GENERIC_OrderKey_S":"'  +@PARAM_GENERIC_OrderKey_S+'"'
									 + '"PARAM_GENERIC_LoadKey_S":"'   +@PARAM_GENERIC_LoadKey_S+'"'
									 + '"PARAM_GENERIC_SKU_S":"'       +@PARAM_GENERIC_SKU_S+'"'
									 + '"PARAM_GENERIC_Location_S":"'  +@PARAM_GENERIC_Location_S+'"'
									 + '"PARAM_GENERIC_ID_S":"'        +@PARAM_GENERIC_ID_S+'"'
                                     + ' }'

      DECLARE @tVarLogId TABLE (LogId INT);
      INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_GENERIC_StorerKey, @Proc, @cParamIn);

	  IF OBJECT_ID('dbo.ExecDebug','u') IS NOT NULL
   BEGIN
      SELECT @Debug = Debug
      FROM dbo.ExecDebug WITH (NOLOCK)
      WHERE UserName = SUSER_SNAME()
   END

	   DECLARE @Stmt NVARCHAR(MAX) = ''

SET @Stmt = '
SELECT
  o.orderkey
  , o.externorderkey
  , o.loadkey
  , o.mbolkey
  , orderstatus = orderstatus.description
  , sostatus = sostatus.description
  , o.type
  , o.deliverydate
  , o.consigneekey
  , o.ordergroup
  , o.doctype
  , pd.storerkey
  , l.facility
  , pd.pickdetailkey
  , pd.orderkey
  , pd.orderlinenumber
  , pd.lot
  , pd.loc
  , l.locationcategory
  , l.locationtype
  , pd.id
  , pd.sku
  , s.descr
  , s.skugroup
  , pickstatus = pickstatus.description
  , pd.qty
  , pd.sourcetype
  , pd.channel_id
  , la.lottable01
  , la.lottable02
  , la.lottable03
  , la.lottable04
  , la.lottable05

FROM BI.V_PICKDETAIL pd (NOLOCK)
JOIN BI.V_ORDERS o (NOLOCK) ON o.orderkey = pd.orderkey
JOIN BI.V_ORDERDETAIL od (NOLOCK) ON pd.orderkey = od.orderkey AND od.OrderLineNumber=pd.OrderLineNumber
JOIN BI.V_SKU s(NOLOCK) on pd.sku = s.sku and pd.storerkey = s.storerkey
JOIN BI.V_LOC l (NOLOCK) on pd.loc = l.loc
LEFT JOIN BI.V_codelkup sostatus (nolock) on sostatus.listname = ''SOSTATUS'' and sostatus.code = o.sostatus AND sostatus.storerkey = o.storerkey
LEFT JOIN BI.V_codelkup orderstatus (nolock) on orderstatus.listname = ''ORDRSTATUS'' and orderstatus.code = o.status AND orderstatus.storerkey = o.storerkey
LEFT JOIN BI.V_codelkup pickstatus (nolock) on pickstatus.listname = ''PICKSTATUS'' and pickstatus.code = pd.status AND pickstatus.storerkey = o.storerkey
JOIN BI.V_lotattribute la (nolock) on pd.lot = la.lot

WHERE pd.Storerkey = "'+@PARAM_GENERIC_StorerKey+'"
AND o.orderkey like "'  +@PARAM_GENERIC_OrderKey_S+'"
AND o.loadkey like  "'+@PARAM_GENERIC_LoadKey_S+'"
AND pd.Sku like  "'+@PARAM_GENERIC_SKU_S+'"
AND pd.Loc like "'+@PARAM_GENERIC_Location_S+'"
AND pd.id like "'+@PARAM_GENERIC_ID_S+'"
AND o.Status <> ''9''
'


      IF @Debug = 1 
	  BEGIN
	  PRINT @Stmt
      PRINT SUBSTRING(@Stmt, 4001, 8000)
      PRINT SUBSTRING(@Stmt, 8001,12000)  
	  PRINT SUBSTRING (@Stmt, 12001 ,16000)
      
	  END
EXEC sp_ExecuteSql @Stmt;


SET @nRowCnt = @@ROWCOUNT;


   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL only
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
   WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END --procedure

GO