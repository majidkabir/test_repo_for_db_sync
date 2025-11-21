SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: PH_LogiReport - Alter Stored Procedure Inventory Reports https://jiralfl.atlassian.net/browse/WMS-22079

DATE				VER		CREATEDBY			PURPOSE
15-MAR-2023			1.0		Jeff Clidoro		MIGRATE FROM HYPERION 
23-MAR-2023			1.1		Jeff Clidoro		Create IN PHWMS UAT 
************************************************************************/
CREATE   PROC [BI].[nsp_VAS_InventoryReport_CHG_MFG] --NAME OF SP
			 @PARAM_GENERIC_STORERKEY NVARCHAR(30)=''
			,@PARAM_GENERIC_FACILITY NVARCHAR(30)=''
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
									+ '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'"  '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only

/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt ='SELECT TOP 100 
  LLI.StorerKey AS ''01 StorerKey'', 
  LC.Facility AS ''02 Facility'', 
  LLI.Sku AS ''03 SKU'', 
  S.PutawayZone AS ''04 PutawayZone'', 
  S.DESCR AS ''05 Description'', 
  LA.Lottable01 AS ''06 Lottable01'', 
  LA.Lottable02 AS ''07 Lottable02'', 
  LA.Lottable03 AS ''06 Lottable03'', 
  LA.Lottable04 AS ''08 Lottable04'', 
  LA.Lottable05 AS ''09 Lottavle05'', 
  LLI.Loc AS ''10 Location'', 
  LC.PutawayZone AS ''11 Location Zone'', 
  LC.Zcoord AS ''12 Odd Even'', 
  LLI.Id AS ''13 Id'', 
  LLI.Qty AS ''14 Qty On Hand PC'', 
  LLI.QtyPicked AS ''15 Qty Picked PC'', 
  LLI.QtyAllocated AS ''16 Qty Allocated PC'', 
  P.CaseCnt AS ''17 CaseCnt'', 
  P.InnerPack AS ''18 InnerPack'', 
  LC.LocationFlag AS ''19 Locationflag'', 
  LC.Status AS ''20 Location Status'', 
  LC.CCLogicalLoc AS ''21 Cclogicalloc'', 
  LC.LogicalLocation AS ''22 Logicallocation'', 
  LC.LocAisle AS ''23 Locaisle'', 
  LC.LocationType AS ''24 Locationtype'', 
  S.SUSR3 AS ''25 Principal'', 
  S.SKUGROUP AS ''26 SKU Category Code'', 
  CUP2.Description AS ''27 Principal Description'', 
  CUP1.Description AS ''28 SKU Category Description'', 
  LT.QtyOnHold AS ''29 Qty On Hold on PC'', 
  LLI.Lot AS ''30 Lot'', 
  S.SkuStatus AS ''31 SKU Status'', 
  LC.LocLevel AS ''32 Loclevel'', 
  LC.MaxPallet AS ''33 Maxpallet'', 
  S.StackFactor AS ''34 Stackfactor'', 
  P.Pallet AS ''35 Pallet Count'', 
  case when P.CaseCnt is null then 0 when P.CaseCnt = 0 then 0 else P.Pallet / P.CaseCnt end AS ''36 CS per Pallet'', 
  S.StrategyKey AS ''37 StrategyKey'', 
  LC.HOSTWHCODE AS ''38 HOSTWHCODE'', 
  RD.SubReasonCode AS ''39 Subreasoncode'', 
  RD.UserDefine01 AS ''40 UserDefine01'', 
  RD.UserDefine02 AS ''41 UserDefine02'', 
  RD.UserDefine04 AS ''42 UserDefine04'', 
  RD.ReceiptKey AS ''43 ReceiptKey''
  ,R.Status [RecStatus]'
  SET @Stmt =@Stmt+'
FROM 
  BI.V_LOTxLOCxID LLI (nolock)
   JOIN BI.V_LOTATTRIBUTE LA (nolock) ON (LLI.Lot = LA.Lot) 
   JOIN BI.V_LOC LC (nolock) ON (LLI.LOC=LC.LOC)
   JOIN BI.V_SKU S (nolock) ON (LLI.STORERKEY=S.STORERKEY AND LLI.SKU=S.SKU)
   JOIN BI.V_PACK P (nolock) ON (S.PACKKEY=P.PACKKEY)
   JOIN BI.V_LOT LT (nolock) ON (LLI.LOT=LT.LOT)
   LEFT JOIN BI.V_RECEIPTDETAIL RD (nolock) ON (LLI.Id = RD.ToId AND LLI.Sku = RD.Sku AND LLI.StorerKey = RD.StorerKey)
   LEFT JOIN BI.V_RECEIPT R (nolock) ON (R.StorerKey = RD.StorerKey and R.Receiptkey=RD.Receiptkey)
   LEFT JOIN BI.V_CODELKUP CUP1 (nolock) ON (S.SKUGROUP = CUP1.Code and (CUP1.LISTNAME=''SKUGROUP'' OR CUP1.LISTNAME='''')) 
   LEFT JOIN BI.V_CODELKUP CUP2 (nolock) ON (S.SUSR3 = CUP2.Code AND (CUP2.LISTNAME=''PRINCIPAL'' OR CUP2.LISTNAME=''''))
WHERE (LLI.StorerKey = '''+@Param_Generic_Storerkey+''') 
			AND (LC.Facility = '''+@Param_Generic_facility+''')
			AND (LLI.Qty>0)
			AND (LA.Lottable01 IN (''CHG'', ''MFG''))'



/*************************** FOOTER *******************************/

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;
END

GO