SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: ULP Wave Replent Health Check - SKU With No Pallet Config

DATE				VER		CREATEDBY   PURPOSE
2023-05-18			1.0		JAM			MIGRATE FROM HYPERION 
************************************************************************/

CREATE   PROC [BI].[nsp_ULP_WaveReplenHC_SKUWithNoPalletConfig] --NAME OF SP */ DECLARE
	@PARAM_GENERIC_STORERKEY NVARCHAR(30)	= ''
	,@PARAM_GENERIC_FACILITY NVARCHAR(30) = ''
	,@PARAM_ORDERS_USERDEFINE09 NVARCHAR(30) = ''
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_STORERKEY, '') = ''
		SET @PARAM_GENERIC_STORERKEY = ''
	
	IF ISNULL(@PARAM_ORDERS_USERDEFINE09, '') = ''
		SET @PARAM_ORDERS_USERDEFINE09 = ''

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'", '
									+ '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'",  '
									+ '"PARAM_ORDERS_USERDEFINE09":"'    +@PARAM_ORDERS_USERDEFINE09+'" '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
DECLARE @Stmt NVARCHAR(2000) = ''
SET @Stmt = '
SELECT
O.Userdefine09 [Wavekey]
, OD.Sku [SKU]
, S.Descr [Description]
, P.Casecnt [Casecnt]
, P.Pallet [Pallet]
, P.Pallet / NULLIF(P.Casecnt,0) [Case Per Pallet]
FROM
BI.V_Orders O (NOLOCK)
INNER JOIN BI.V_Orderdetail OD (NOLOCK) ON O.ORDERKEY=OD.ORDERKEY
INNER JOIN BI.V_Sku S (NOLOCK) ON OD.STORERKEY=S.STORERKEY AND OD.SKU=S.SKU
INNER JOIN BI.V_Pack P (NOLOCK) ON P.PACKKEY=S.PACKKEY
WHERE
O.STORERKEY = '''+@PARAM_GENERIC_STORERKEY+'''
AND O.FACILITY = '''+@PARAM_GENERIC_FACILITY+'''
AND P.PALLET = 0 '
IF ISNULL(@PARAM_ORDERS_USERDEFINE09,'')<>''
	SET @Stmt = @Stmt + ' AND O.USERDEFINE09 = '''+@PARAM_ORDERS_USERDEFINE09+''' '

--PRINT (@STMT)
--EXEC (@STMT)

EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO