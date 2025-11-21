SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: BROADCAST REPORT - BEVA AGEING REPORT https://jiralfl.atlassian.net/browse/WMS-19169

DATE				VER		CREATEDBY   PURPOSE
08-MAR-2022			1.0		JAM			MIGRATE FROM HYPERION
27-April-2022       1.1     JarekLim    Change the column
10-Oct-2023			1.2		JAM			Enhancement Request-add Lot01,Lot02,Lot03
************************************************************************/
-- Test:   EXEC BI.nsp_SCH_GENERIC_AgeingReport 'BEVI'

CREATE     PROC [BI].[nsp_SCH_GENERIC_AgeingReport] --NAME OF SP
	@Param_Generic_Storerkey NVARCHAR(20)

AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;

   IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_StorerKey = ''

DECLARE  @Debug	BIT = 0
		 , @LogId   INT
         , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
         , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
         , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'+@Param_Generic_Storerkey+'"'
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '
SELECT 
  F.Facility								as ''01 Facility'' 
  ,LLI.StorerKey								as ''02 StorerKey'' 
  ,LLI.Sku									as ''03 Sku'' 
  ,S.DESCR									as ''04 Description'' 
  ,LOA.Lottable04							as ''05 ExpiryDate'' 
  ,GETDATE()									as ''06 CurrentDate'' 
  ,DATEDIFF (dy,(GETDATE()),LOA.Lottable04)	as ''07 Days to Expire From the CurrentDate''
  ,S.ShelfLife								as ''08 Shelflife(in days)''
  ,((LLI.Qty) -(LLI.QtyAllocated + LLI.QtyPicked)) as ''09 Qty Available (EA)'' 
  ,dateadd(day,(-1 * S.ShelfLife),LOA.Lottable04) as ''10 ProductionDate'' 
  ,CASE WHEN DATEDIFF (dy,(GETDATE()),LOA.Lottable04) > 365 THEN ''OK TO SERVE''
	WHEN DATEDIFF (dy,(GETDATE()),LOA.Lottable04) < 0 THEN ''EXPIRED'' 
	WHEN DATEDIFF (dy,(GETDATE()),LOA.Lottable04) <= 365 THEN ''NEAR EXPIRY''
	END										AS ''11 Age Status''
  ,(((LLI.Qty) -(LLI.QtyAllocated + LLI.QtyPicked))) / P.CaseCnt AS ''12 Qty Available (CS)''
  ,LOA.Lottable05							AS ''13 Receipt Date'' 
  ,DATEDIFF (mm,(GETDATE()),LOA.Lottable04)	AS ''14 Months to Expire From the Current Date'' 
  ,DATEDIFF (dy,(LOA.Lottable05),(GETDATE())) AS ''15 Age in Days From the Receipt Date''
  ,DATEDIFF (mm,(LOA.Lottable05),(GETDATE()))  AS ''16 Age in Months From the Receipt Date''
  ,LOC.HOSTWHCODE,LOA.Lottable01,LOA.Lottable02,LOA.Lottable03
FROM 
  BI.V_LOTxLOCxID LLI (NOLOCK)
  LEFT OUTER JOIN BI.V_LOTATTRIBUTE LOA (NOLOCK) ON (LLI.Lot = LOA.Lot)
  LEFT OUTER JOIN BI.V_LOC LOC (NOLOCK) ON (LLI.Loc = LOC.Loc)
  LEFT OUTER JOIN BI.V_SKU S (NOLOCK) ON (LLI.StorerKey = S.StorerKey AND S.Sku = LLI.Sku)
  LEFT OUTER JOIN BI.V_PACK P (NOLOCK)  ON (P.PackKey = S.PACKKey)
  LEFT OUTER JOIN BI.V_FACILITY F (NOLOCK) ON (F.Facility = LOC.Facility)
WHERE 
  LLI.Qty > 0 AND LLI.StorerKey = '''+@Param_Generic_Storerkey+''' 
    
ORDER BY 
  1,17,3'

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;


END -- Procedure

GO