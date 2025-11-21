SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: INVENTORY REPORT https://jiralfl.atlassian.net/browse/WMS-21886

DATE				VER		CREATEDBY   PURPOSE
21-OCT-2021			1.0		BCN			MIGRATE FROM HYPERION 
04-JAN-2021			1.1		JAM			RE-MODIFY. ADDED MISSING FIELDS
22-Feb-2023			1.2		JEFF		ADDED FIELDS FROM CUSTOM REPORT
07-MAR-2023			1.3		JAM			FINE TUNE. CHANGE SOME TABLES TO INNER JOIN
09-MAR-2023			1.4		JEFFClidoro		Amend and add table 
15-MAR-2023			1.5		JEFFClidoro		Remove the RECEIPTDETAIL table and column
31-MAR-2023			1.7		JEFFClidoro		Changes condition in the 63 column
************************************************************************/

CREATE   PROC [BI].[nsp_STD_InventoryReport] --NAME OF SP
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

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_STORERKEY
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

set @Stmt = ' SELECT
LLI.StorerKey as ''01Storerkey'',
LC.Facility as ''02Facility'',
S.SkuStatus as ''03SKU Status'',
LLI.Sku as ''04SKU'',
S.DESCR AS ''05DESCRIPTION'',
S.PutawayZone AS ''06SKU ZONE'',
S.SUSR3 AS ''07PRINCIPAL'', 
CUP2.Description AS ''08PRINCIPAL DESCRIPTION'',
S.SKUGROUP AS ''09SKU CATEGORY CODE'',
LLI.Lot AS ''10LOT'', 
LLI.Loc AS ''11LOC'',
LC.Zcoord AS ''12ODD EVEN'',
LC.LocationFlag AS ''13LOCATION FLAG'', 
LC.PutawayZone AS ''14LOCATION ZONE'',
LC.Status AS ''15LOCATION STATUS'',
LC.CCLogicalLoc AS ''16CCLOGICALLOC'',
LC.LocAisle AS ''17LOCAISLE'',
LC.LocLevel AS ''18LOCLEVEL'',
LC.LocationType AS ''19LOCATIONTYPE'', 
LC.LogicalLocation AS ''20LOGICALLOCATION'',
LA.Lottable01 AS ''21LOTTABLE01'',
LA.Lottable02 AS ''22LOTTABLE02'', 
LA.Lottable03 AS ''23LOTTABLE03'', 
LA.Lottable04 AS ''24LOTTABLE04'',
LA.Lottable05 AS ''25LOTTABLE05'', 
LLI.Id AS ''26ID'',
LC.MaxPallet AS ''27MAXPALLET'',
S.StackFactor AS ''28STACKFACTOR'', 
LLI.Qty AS ''29QTY ON HAND PC'',
LLI.QtyAllocated AS ''30QTY ALLOCATED PC'',
LLI.QtyPicked AS ''31QTY PICKED PC'',
LLI.QTY-LLI.QtyAllocated-LLI.QTYPICKED AS ''32QTY AVAILABLE PC'',
case when PK.CaseCnt is null then 0                     
     when PK.CaseCnt = 0 then 0  
	 else LLI.Qty/PK.CaseCnt end AS ''33QTY ON HAND CS'',
case when PK.CaseCnt is null then 0                     
     when PK.CaseCnt = 0 then 0  
	 else LLI.QtyAllocated/PK.CaseCnt end AS ''34QTY ALLOCATED CS'',
case when PK.CaseCnt is null then 0                     
     when PK.CaseCnt = 0 then 0  
	 else LLI.QtyPicked/PK.CaseCnt end AS ''35 QTY PICKED CS'',
case when PK.CaseCnt is null then 0                     
     when PK.CaseCnt = 0 then 0  
	 else (LLI.QTY-LLI.QtyAllocated-LLI.QTYPICKED)/PK.CaseCnt  end AS ''36 QTY AVAILABLE CS'',
case when PK.InnerPack is null then 0                     
     when PK.InnerPack = 0 then 0  
	 else LLI.Qty / PK.InnerPack end AS ''37 QTY ON HAND IP'',
case when PK.InnerPack is null then 0                     
     when PK.InnerPack = 0 then 0  
	 else LLI.QtyAllocated / PK.InnerPack end AS ''38 QTY ALLOCATED IP'',
case when PK.InnerPack is null then 0                     
     when PK.InnerPack = 0 then 0  
	 else LLI.QtyPicked / PK.InnerPack end AS ''39 QTY PICKED IP'',
case when PK.InnerPack is null then 0                     
     when PK.InnerPack = 0 then 0  
	 else (LLI.QTY-LLI.QtyAllocated-LLI.QTYPICKED) / PK.InnerPack end AS ''40 QTY AVAILABLE IP'',
LT.QtyOnHold AS ''41 QTY ON HOLD'',
PK.Pallet AS ''42 PALLET COUNT'', 
case when PK.CaseCnt is null then 0                     
     when PK.CaseCnt = 0 then 0  
	 else PK.Pallet / PK.CaseCnt end AS ''43 CS PER PALLET'', 
case when PK.Pallet is null then 0                     
     when PK.Pallet = 0 then 0  
	 else LLI.Qty / PK.Pallet end AS ''44 NO OF PALLET'',
S.StrategyKey AS ''45 STRATEGYKEY'',
LC.HOSTWHCODE AS ''46 HOSTWAREHOUSECODE'',
LA.Lottable07 AS ''47 LOTTABLE07'',
LA.Lottable06 AS ''48 LOTTABLE06'',
LA.Lottable08 AS ''49 LOTTABLE08'',
LA.Lottable09 AS ''50 LOTTABLE09'', 
LA.Lottable10 AS ''51 LOTTABLE10'',
LA.Lottable11 AS ''52 LOTTABLE11'',
LA.Lottable12 AS ''53 LOTTABLE12'',
LA.Lottable13 AS ''54 LOTTABLE13'',
LA.Lottable14 AS ''55 LOTTABLE14'',
LA.Lottable15 AS ''56 LOTTABLE15'',     
LC.LocationCategory AS ''57 LOCATION CATEGORY'', 
S.Price AS ''58 UNIT PRICE'',
S.Price*(LLI.QTY-LLI.QtyAllocated-LLI.QTYPICKED) AS ''59 TOTAL PRICE (AVAIL)'',
S.Price*LLI.QTY AS ''60 TOTAL PRICE (ONHAND)'',
S.ShelfLife AS ''61 Shelflife'',
S.SUSR2 AS ''62 MRSL'',
case when ISNULL(S.SUSR2,'''')='''' then 0
     when ISNUMERIC(S.SUSR2)= 0 then 0
     else (LA.Lottable04 - abs (S.SUSR2)) end as ''63 Final Dispatch Date'',
case when PK.CaseCnt is null then 0
	when PK.CaseCnt = 0 then 0
	else LLI.PendingMoveIN / PK.CaseCnt end as ''64 PendindMoveIn CS'', 
case when PK.CaseCnt is null then 0
	when PK.CaseCnt = 0 then 0
	else LLI.QtyReplen / PK.CaseCnt end as ''65 QtyReplen CS'',
PK.CaseCnt AS ''66 CaseCnt'',
PK.Innerpack AS ''67 Inner Pack'',
CUP2.Description AS ''68 Principal Description'',
CUP1.Description AS ''69 SKU Category Description'',
S.BUSR7 AS ''75 BUSR7'',
S.ALTSKU AS ''76 ALTERNATESKU'' '

	SET @Stmt =@Stmt+'
FROM            
BI.V_LOTxLOCxID LLI (nolock)   
	JOIN BI.V_LOC LC (nolock) ON (LLI.Loc = LC.Loc) 
    JOIN BI.V_LOT LT (nolock) ON (LT.Lot = LLI.Lot) 
	JOIN BI.V_LOTATTRIBUTE LA (nolock) ON (LLI.Lot = LA.Lot)   
	JOIN BI.V_SKU S (nolock) ON (LLI.STORERKEY=S.STORERKEY AND LLI.Sku = S.Sku) 
	JOIN BI.V_PACK PK (nolock) ON (S.PACKKey = PK.PackKey) 
	LEFT JOIN BI.V_CODELKUP CUP1 (nolock) ON (CUP1.LISTNAME = ''SKUGROUP'' AND S.SKUGROUP = CUP1.Code AND S.StorerKey =CUP1.Storerkey )   
    LEFT JOIN BI.V_CODELKUP CUP2 (nolock) ON (CUP2.LISTNAME = ''PRINCIPAL'' AND S.SUSR3 = CUP2.Code AND S.StorerKey =CUP2.Storerkey )   
WHERE        (LLI.StorerKey = '''+@Param_Generic_Storerkey+''') 
			AND (LC.Facility = '''+@Param_Generic_facility+''')
			AND (LLI.Qty>0) ' 


/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO