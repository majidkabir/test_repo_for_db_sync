SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: ULP Wave Replent Health Check - Pre Alloc Records

DATE				VER		CREATEDBY   PURPOSE
2023-05-18			1.0		JAM			MIGRATE FROM HYPERION
************************************************************************/

CREATE   PROC [BI].[nsp_ULP_WaveReplenHC_PreAllocRecords] --NAME OF SP */ Declare
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)=''
			,@PARAM_GENERIC_FACILITY NVARCHAR(30)=''
			,@PARAM_ORDERKEY_USERDEFINE09 NVARCHAR(30)=''
			,@PARAM_ORDERKEY_ORDERGROUP NVARCHAR(30)=''
			,@PARAM_ORDERKEY_EXTERNORDERKEY NVARCHAR(30)=''
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

	IF ISNULL(@PARAM_ORDERKEY_USERDEFINE09, '') = ''
		SET @PARAM_ORDERKEY_USERDEFINE09 = ''

	IF ISNULL(@PARAM_ORDERKEY_ORDERGROUP, '') = ''
		SET @PARAM_ORDERKEY_ORDERGROUP = ''

	IF ISNULL(@PARAM_ORDERKEY_EXTERNORDERKEY, '') = ''
		SET @PARAM_ORDERKEY_EXTERNORDERKEY = ''

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'", '
									+ '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'",  '
									+ '"PARAM_ORDERKEY_USERDEFINE09":"'    +@PARAM_ORDERKEY_USERDEFINE09+'",  '
									+ '"PARAM_ORDERKEY_ORDERGROUP":"'    +@PARAM_ORDERKEY_ORDERGROUP+'",  '
									+ '"PARAM_ORDERKEY_EXTERNORDERKEY":"'    +@PARAM_ORDERKEY_EXTERNORDERKEY+'"  '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
DECLARE @Stmt NVARCHAR(MAX) = ''
SET @Stmt = '
SELECT
O.Userdefine09 [WaveKey]
, O.Ordergroup [Shipment]
, O.Externorderkey [OBD]
, S.Descr [Description]
, PPD.Sku [PreallocSku]
, SUM ( OD.Qtypreallocated ) [QtyPrealloc-PC]
, SUM ( OD.Qtypreallocated / P.Casecnt ) [QtyPrealloc-CS]
, ISNULL(P.Pallet / NULLIF(P.Casecnt,0),0) [Case per Pallet]
, SL.Sku

FROM
	BI.V_PreAllocatePickDetail PPD (NOLOCK)
	INNER JOIN BI.V_ORDERDETAIL OD (NOLOCK) ON OD.STORERKEY=PPD.STORERKEY
			AND OD.ORDERKEY=PPD.ORDERKEY AND OD.Orderlinenumber=PPD.Orderlinenumber
	INNER JOIN BI.V_ORDERS O (NOLOCK) ON O.ORDERKEY=OD.ORDERKEY
	INNER JOIN BI.V_Sku S (NOLOCK) ON ppd.StorerKey=S.StorerKey AND ppd.Sku=S.Sku
	INNER JOIN BI.V_Pack P (NOLOCK) ON P.PackKey=S.PACKKey
	LEFT JOIN BI.V_Skuxloc SL (NOLOCK) ON PPD.STORERKEY=SL.STORERKEY AND PPD.SKU=SL.Sku AND SL.LocationType = ''CASE''
WHERE
	PPD.StorerKey = '''+@PARAM_GENERIC_STORERKEY+'''
	and o.Facility = '''+@PARAM_GENERIC_FACILITY+'''
	AND PPD.Qty>0 '
	IF ISNULL(@PARAM_ORDERKEY_USERDEFINE09,'')<>''
		SET @STMT = @STMT +' AND O.UserDefine09 = '''+@PARAM_ORDERKEY_USERDEFINE09+''' '
	IF ISNULL(@PARAM_ORDERKEY_USERDEFINE09,'')<>''
		SET @STMT = @STMT +' AND O.Ordergroup = '''+@PARAM_ORDERKEY_ORDERGROUP+''' '
	IF ISNULL(@PARAM_ORDERKEY_USERDEFINE09,'')<>''
		SET @STMT = @STMT +' AND O.ExternOrderKey = '''+@PARAM_ORDERKEY_EXTERNORDERKEY+''' '
SET @Stmt = @STMT + '
GROUP BY
O.Userdefine09
, O.Ordergroup
, O.Externorderkey
, S.Descr
, PPD.Sku
, P.Pallet
, P.Casecnt
, SL.Sku
, SL.Loc
'
EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO