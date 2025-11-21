SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************
TITLE: STOCKTAKE VARIANCE REPORT (PHWMS) https://jiralfl.atlassian.net/browse/WMS-21993

DATE				VER		CREATEDBY   PURPOSE
14-MAR-2023			1.0		JAM			MIGRATE FROM HYPERION (PHWMS)
22-Aug_2023			1.1		Crisnah		Change from Join to left join https://jiralfl.atlassian.net/browse/WMS-23267
************************************************************************/
-- Test:   EXEC BI.nsp_STD_PHWMS_StockTakeVarianceReport 'ZEROW2W' ,'2022-09-01','2022-10-01'

CREATE     PROC [BI].[nsp_STD_PHWMS_StockTakeVarianceReport] --NAME OF SP
		  @PARAM_GENERIC_STORERKEY NVARCHAR(30)
		  ,@PARAM_GENERIC_FACILITY NVARCHAR(30)
		  ,@PARAM_GENERIC_CCKEY NVARCHAR(30)
		  , @PARAM_GENERIC_ADDDATEFROM DATETIME
		  , @PARAM_GENERIC_ADDDATETO DATETIME
			
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
	IF ISNULL(@PARAM_GENERIC_CCKEY, '') = ''
		SET @PARAM_GENERIC_CCKEY = ''
	IF ISNULL(@PARAM_GENERIC_ADDDATEFROM, '') = ''
		  SET @PARAM_GENERIC_ADDDATEFROM = CONVERT(VARCHAR(25), GETDATE()-7, 121)
	IF ISNULL(@PARAM_GENERIC_ADDDATETO, '') = ''
	      SET @PARAM_GENERIC_ADDDATETO= GETDATE()

	DECLARE @nRowCnt INT = 0
	   , @Debug	BIT = 0
	   , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ '
									+ '"PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'",'
									+ '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'",'
									+ '"PARAM_GENERIC_CCKEY":"'    +@PARAM_GENERIC_CCKEY+'",'
									+ '"PARAM_GENERIC_ADDDATEFROM":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATEFROM,121)+'",'
                                    + '"PARAM_GENERIC_ADDDATETO":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATETO,121)+'"'
									+ ' }'
		, @storer nvarchar(20) = (SELECT TOP 1 STORERKEY FROM BI.V_CCDETAIL (NOLOCK) WHERE CCKEY=@PARAM_GENERIC_CCKEY)

	EXEC BI.dspExecInit @ClientId = @storer
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = ' SELECT '+
			'  CCD.CCKey  AS ''01CCKey''  ,  ' +
			'  CCD.CCSheetNo  AS ''02CCSheetNo''  ,  ' +
			'  CCD.Storerkey  AS ''03Storerkey''  ,  ' +
			'  SSP.Facility  AS ''04Facility''  ,  ' +
			'  CCD.Sku  AS ''05Sku''  ,  ' +
			'  S.DESCR  AS ''06DESCR''  ,  ' +
			'  CCD.Lot  AS ''07Lot''  ,  ' +
			'  CCD.Loc  AS ''08Loc''  ,  ' +
			'  CCD.Id  AS ''09Id''  ,  ' +
			'  CCD.SystemQty  AS ''10SystemQty''  ,  ' +
			'  case when P.CaseCnt = 0 then 0 else CCD.SystemQty / P.CaseCnt end AS ''11SystemQty_CS''  ,  ' +
			'  CCD.Qty AS ''12Qty''  ,  ' +
			'  case when P.InnerPack = 0 then 0 else CCD.Qty / P.InnerPack end AS ''13Qty_IP''  ,  ' +
			'  case when P.CaseCnt = 0 then 0 else CCD.Qty / P.CaseCnt end AS ''14Qty_CS''  ,  ' +
			'  CCD.Lottable01  AS ''15Lottable01''  ,  ' +
			'  CCD.Lottable02  AS ''16Lottable02''  ,  ' +
			'  CCD.Lottable03  AS ''17Lottable03''  ,  ' +
			'  CONVERT (CHAR(10), CCD.Lottable04, 101) AS ''18Lottable04''  ,  ' +
			'  CONVERT (CHAR(10), CCD.Lottable05, 101) AS ''19Lottable05''  ,  ' +
			'  CCD.EditWho AS ''20EditWho''  ,  ' +
			'  ROUND (S.Cost, 2) AS ''21Cost''  ,  ' +
			'  CCD.TagNo  AS ''22TagNo''  ,  ' +
			'  CCD.Lottable06  AS ''23Lottable06''  ,  ' +
			'  CCD.Lottable07  AS ''24Lottable07''  ,  ' +
			'  CCD.Lottable08  AS ''25Lottable08''  ,  ' +
			'  CCD.Lottable09  AS ''26Lottable09''  ,  ' +
			'  CCD.Lottable10  AS ''27Lottable10''  ,  ' +
			'  CCD.Lottable11  AS ''28Lottable11''  ,  ' +
			'  CCD.Lottable12  AS ''29Lottable12''  ,  ' +
			'  CCD.Lottable13  AS ''30Lottable13''  ,  ' +
			'  CCD.Lottable14  AS ''31Lottable14''  ,  ' +
			'  CCD.Lottable15 AS ''32Lottable15''  ,  ' +
			'  CCD.Qty_Cnt2  AS ''33Qty_Cnt2''  ,  ' +
			'  case when P.InnerPack = 0 then 0 else CCD.Qty_Cnt2 / P.InnerPack end AS ''34Qty_Cnt2_IP''  ,  ' +
			'  case when P.CaseCnt = 0 then 0 else CCD.Qty_Cnt2 / P.CaseCnt end AS ''35Qty_Cnt2_CS''  ,  ' +
			'  CCD.Lottable01_Cnt2  AS ''36Lottable01_Cnt2''  ,  ' +
			'  CCD.Lottable02_Cnt2  AS ''37Lottable02_Cnt2''  ,  ' +
			'  CCD.Lottable03_Cnt2  AS ''38Lottable03_Cnt2''  ,  ' +
			'  CONVERT (CHAR(10), CCD.Lottable04_Cnt2, 101) AS ''39Lottable04_Cnt2''  ,  ' +
			'  CONVERT (CHAR(10), CCD.Lottable05_Cnt2, 101) AS ''40Lottable05_Cnt2''  ,  ' +
			'  CCD.Lottable06_Cnt2  AS ''41Lottable06_Cnt2''  ,  ' +
			'  CCD.Lottable07_Cnt2  AS ''42Lottable07_Cnt2''  ,  ' +
			'  CCD.Lottable08_Cnt2  AS ''43Lottable08_Cnt2''  ,  ' +
			'  CCD.Lottable09_Cnt2  AS ''44Lottable09_Cnt2''  ,  ' +
			'  CCD.Lottable10_Cnt2  AS ''45Lottable10_Cnt2''  ,  ' +
			'  CCD.Lottable11_Cnt2  AS ''46Lottable11_Cnt2''  ,  ' +
			'  CCD.Lottable12_Cnt2  AS ''47Lottable12_Cnt2''  ,  ' +
			'  CCD.Lottable13_Cnt2  AS ''48Lottable13_Cnt2''  ,  ' +
			'  CCD.Lottable14_Cnt2  AS ''49Lottable14_Cnt2''  ,  ' +
			'  CCD.Lottable15_Cnt2 AS ''50Lottable15_Cnt2''  ,  ' +
			'  CCD.Qty_Cnt3  AS ''51Qty_Cnt3''  ,  ' +
			'  case when P.InnerPack = 0 then 0 else CCD.Qty_Cnt3 / P.InnerPack end  AS ''52Qty_Cnt3_IP''  ,  ' +
			'  case when P.CaseCnt = 0 then 0 else CCD.Qty_Cnt3 / P.CaseCnt end  AS ''53Qty_Cnt3_CS''  ,  ' +
			'  CCD.Lottable01_Cnt3  AS ''54Lottable01_Cnt3''  ,  ' +
			'  CCD.Lottable02_Cnt3  AS ''55Lottable02_Cnt3''  ,  ' +
			'  CCD.Lottable03_Cnt3  AS ''56Lottable03_Cnt3''  ,  ' +
			'  CONVERT (CHAR(10), CCD.Lottable04_Cnt3, 101) AS ''57Lottable04_Cnt3''  ,  ' +
			'  CONVERT (CHAR(10), CCD.Lottable05_Cnt3, 101)  AS ''58Lottable05_Cnt3''  ,  ' +
			'  CCD.Lottable06_Cnt3 AS ''59Lottable06_Cnt3''  ,  ' +
			'  CCD.Lottable07_Cnt3  AS ''60Lottable07_Cnt3''  ,  ' +
			'  CCD.Lottable08_Cnt3  AS ''61Lottable08_Cnt3''  ,  ' +
			'  CCD.Lottable09_Cnt3  AS ''62Lottable09_Cnt3''  ,  ' +
			'  CCD.Lottable10_Cnt3  AS ''63Lottable10_Cnt3''  ,  ' +
			'  CCD.Lottable11_Cnt3  AS ''64Lottable11_Cnt3''  ,  ' +
			'  CCD.Lottable12_Cnt3  AS ''65Lottable12_Cnt3''  ,  ' +
			'  CCD.Lottable13_Cnt3  AS ''66Lottable13_Cnt3''  ,  ' +
			'  CCD.Lottable14_Cnt3  AS ''67Lottable14_Cnt3''  ,  ' +
			'  CCD.Lottable15_Cnt3 AS ''68Lottable15_Cnt3''    ' +
			' , SSP.StockTakeKey ' +
' , SSP.Facility ' +
' , SSP.StorerKey ' +
' , SSP.ZoneParm ' +
' , SSP.AisleParm ' +
' , SSP.LevelParm ' +
' , SSP.HostWHCodeParm ' +
' , SSP.SKUParm ' +
' , SSP.AgencyParm ' +
' , SSP.ABCParm ' +
' , SSP.Protect ' +
' , SSP.Password ' +
' , SSP.WithQuantity ' +
' , SSP.ClearHistory ' +
' , SSP.EmptyLocation ' +
' , SSP.LinesPerPage ' +
' , SSP.FinalizeStage ' +
' , SSP.PopulateStage ' +
' , SSP.GroupLottable05 ' +
' , SSP.AddDate ' +
' , SSP.AddWho ' +
' , SSP.EditDate ' +
' , SSP.EditWho ' +
' , SSP.AdjReasonCode ' +
' , SSP.AdjType ' +
' , SSP.ArchiveCop ' +
' , SSP.BlankCSheetHideLoc ' +
' , SSP.BlankCSheetNoOfPage ' +
' , SSP.SkugroupParm ' +
' , SSP.ExcludeQtyPicked ' +
' , SSP.CountType ' +
' , SSP.ExtendedParm1Field ' +
' , SSP.ExtendedParm1 ' +
' , SSP.ExtendedParm2Field ' +
' , SSP.ExtendedParm2 ' +
' , SSP.ExtendedParm3Field ' +
' , SSP.ExtendedParm3 ' +
' , SSP.ExcludeQtyAllocated ' +
' , SSP.StrategyKey ' +
' , SSP.Parameter01 ' +
' , SSP.Parameter02 ' +
' , SSP.Parameter03 ' +
' , SSP.Parameter04 ' +
' , SSP.Parameter05 ' +
' , SSP.CountSheetGroupBy01 ' +
' , SSP.CountSheetGroupBy02 ' +
' , SSP.CountSheetGroupBy03 ' +
' , SSP.CountSheetGroupBy04 ' +
' , SSP.CountSheetGroupBy05 ' +
' , SSP.CountSheetSortBy01 ' +
' , SSP.CountSheetSortBy02 ' +
' , SSP.CountSheetSortBy03 ' +
' , SSP.CountSheetSortBy04 ' +
' , SSP.CountSheetSortBy05 ' +
' , SSP.CountSheetSortBy06 ' +
' , SSP.CountSheetSortBy07 ' +
' , SSP.CountSheetSortBy08 ' +
' , SSP.BlankCSheetLineByMaxPLT ' +
' , SSP.BlankCSheetDPTRNOnly ' +
' , SSP.QueryinJSON ' +
' , SSP.Status ' +
' , SSP.LocPerPage ' +
' , CCD.EDITWHO_CNT1 ' +
' , CCD.EDITWHO_CNT2 ' +
' , CCD.EDITWHO_CNT3 ' +
' , CCD.EDITDATE_CNT1 ' +
' , CCD.EDITDATE_CNT2 ' +
' , CCD.EDITDATE_CNT3 ' +
' , CCD.COUNTED_CNT1 ' +
' , CCD.COUNTED_CNT2 ' +
' , CCD.COUNTED_CNT3 ' +
' , CCD.FINALIZEFLAG ' +
' , CCD.FINALIZEFLAG_CNT2 ' +
' , CCD.FINALIZEFLAG_CNT3 ' +
' , CCD.CCDETAILKEY ' +
' , L.LOCAISLE ' +
			'FROM    ' +
			'  BI.V_CCDetail CCD (nolock)  ' +
			'  JOIN BI.V_StockTakeSheetParameters SSP (nolock) ON (CCD.CCKey = SSP.StockTakeKey) ' +
			'  LEFT JOIN BI.V_SKU S (nolock) ON (CCD.Storerkey = S.StorerKey  AND CCD.Sku = S.Sku) ' +
			'  LEFT JOIN BI.V_PACK P (nolock) ON (S.PACKKey = P.PackKey) ' +
			'  LEFT JOIN BI.V_LOC L (nolock) ON (L.LOC = CCD.LOC) ' +
			'WHERE    ' 
			IF @PARAM_GENERIC_CCKEY='ALL'
				BEGIN 
					SET @Stmt = @Stmt + 'CCD.CCKey IN (SELECT DISTINCT STOCKTAKEKEY FROM BI.V_StockTakeSheetParameters
					where Storerkey='''+@Param_Generic_Storerkey+'''
					and  facility='''+@param_Generic_facility +'''
					and AddDate between '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATEFROM,121)+''' 
					and '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATETO,121)+''')'
				END
			ELSE
				BEGIN
					SET @Stmt = @Stmt + ' CCD.CCKey = '''+@PARAM_GENERIC_CCKEY+''' '
				END
			SET @Stmt = @Stmt + ' AND CCD.adddate BETWEEN '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATEFROM,121)+''' ' +
			' AND '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATETO,121)+''' ' 


/*************************** FOOTER *******************************/
--print @Stmt
EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO