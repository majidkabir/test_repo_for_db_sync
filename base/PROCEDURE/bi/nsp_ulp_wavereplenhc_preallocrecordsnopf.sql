SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: ULP Wave Replent Health Check - Pre Alloc Records No PF

DATE				VER		CREATEDBY   PURPOSE
2023-05-18			1.0		JAM			MIGRATE FROM HYPERION
************************************************************************/

CREATE   PROC [BI].[nsp_ULP_WaveReplenHC_PreAllocRecordsNoPF] --NAME OF SP */ Declare
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)=''
			,@PARAM_GENERIC_FACILITY NVARCHAR(30)=''
			,@PARAM_ORDERS_Userdefine09 NVARCHAR(30)=''
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_STORERKEY, '') = ''
		SET @PARAM_GENERIC_STORERKEY = ''
	
	IF ISNULL(@PARAM_GENERIC_FACILITY, '') = ''
		SET @PARAM_GENERIC_FACILITY = ''

	IF ISNULL(@PARAM_ORDERS_Userdefine09, '') = ''
		SET @PARAM_ORDERS_Userdefine09 = ''

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'", '
									+ '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'",  '
									+ '"PARAM_ORDERS_Userdefine09":"'    +@PARAM_ORDERS_Userdefine09+'"  '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
DECLARE @Stmt NVARCHAR(2000) = ''
set @Stmt = '
SELECT
  O.UserDefine09 [Wavekey], 
  PPD.Sku [PreAllocSKU], 
  S.DESCR [Description], 
  SUM (OD.QtyPreAllocated) [QtyPreAlloc-PC], 
  SUM (OD.QtyPreAllocated / P.CaseCnt) [QtyPreAlloc-CS], 
  P.Pallet / nullif(P.CaseCnt,''0'') [Case Per Pallet]
FROM 
  BI.V_PreAllocatePickDetail PPD (NOLOCK)
  INNER JOIN BI.V_ORDERDetail OD (NOLOCK) ON OD.OrderKey = PPD.OrderKey and OD.OrderLineNumber = PPD.OrderLineNumber
  INNER JOIN BI.V_ORDERS O (NOLOCK) ON O.OrderKey = OD.OrderKey
  INNER JOIN BI.V_SKU S (NOLOCK) ON OD.StorerKey = S.StorerKey AND OD.Sku = S.Sku
  INNER JOIN BI.V_Pack P (NOLOCK) ON S.PACKKey = P.PackKey
  LEFT JOIN BI.V_Skuxloc SL (NOLOCK) ON PPD.STORERKEY=SL.STORERKEY AND PPD.SKU=SL.Sku and SL.LocationType = ''CASE''
WHERE 
      PPD.Storerkey = '''+@param_generic_storerkey+''' 
	  and o.Facility = '''+@param_generic_facility+'''
      AND PPD.Qty > 0
	  AND ISNULL(SL.SKU,'''')='''' '
	  if ISNULL(@param_orders_userdefine09,'')<>''
		  set @stmt = @stmt +' and o.userdefine09='''+@PARAM_ORDERS_Userdefine09+''' '
set @Stmt = @Stmt + '
GROUP BY 
  O.UserDefine09, 
  PPD.Sku, 
  S.DESCR, 
  P.Pallet / nullif(P.CaseCnt,''0'')
  '

EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO