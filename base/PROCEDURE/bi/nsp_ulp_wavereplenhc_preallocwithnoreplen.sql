SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: ULP Wave Replent Health Check - Pre Alloc with no Replen

DATE				VER		CREATEDBY   PURPOSE
2023-05-18			1.0		JAM			MIGRATE FROM HYPERION 
************************************************************************/
-- SP_HELPTEXT 'BI.nsp_ULP_WaveReplenHC_PreAllocWithNoReplen'
CREATE   PROC [BI].[nsp_ULP_WaveReplenHC_PreAllocWithNoReplen] --NAME OF SP */ Declare
	@PARAM_GENERIC_STORERKEY NVARCHAR(30) = ''
	, @PARAM_GENERIC_FACILITY NVARCHAR(30) = ''
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

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'", '
									+ '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'" '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
DECLARE @stmt nvarchar(2000) = ''

set @stmt = '
;WITH a (aWave,aPreallocSKU,aQtyPreallocatedCS,aQtyReplenCS) as (
SELECT
O.Userdefine09 [Wave]
, OD.Sku [PreallocSKU]
, SUM(isnull(OD.Qtypreallocated / NULLIF(P.Casecnt,0),''0'')) [QtyPreallocated-CS]
, SUM(isnull(R.Qty / NULLIF(P.Casecnt,0),''0'')) [QtyReplen-CS]
FROM
BI.V_Orders O (NOLOCK)
INNER JOIN BI.V_Orderdetail OD (NOLOCK) ON O.ORDERKEY=OD.ORDERKEY
INNER JOIN BI.V_Sku S (NOLOCK) ON OD.STORERKEY=S.STORERKEY AND OD.SKU=S.SKU
INNER JOIN BI.V_Pack P (NOLOCK) ON P.PACKKEY=S.PACKKEY
LEFT JOIN BI.V_Replenishment R (NOLOCK) ON R.Storerkey=OD.StorerKey AND R.Sku=OD.Sku AND O.UserDefine09=R.Wavekey
WHERE
O.StorerKey='''+@param_generic_storerkey+'''
AND O.Facility='''+@param_generic_facility+'''
AND OD.Qtypreallocated>0
GROUP BY
O.Userdefine09
, OD.Sku
)

select 
	a.aWave [Wave] 
	,a.aPreallocSKU [PreAllocSKU]
	,a.aQtyPreallocatedCS [PreAllocatedCS]
	,a.aQtyReplenCS [QtyReplenCS]
from a
where isnull(aQtyReplenCS,'''')=''''
order by 1, 2
'

EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO