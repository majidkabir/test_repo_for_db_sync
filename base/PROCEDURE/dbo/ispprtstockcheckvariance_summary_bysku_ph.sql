SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPrtStockCheckVariance_Summary_bySKU_ph                   */
/* Creation Date: 11-Nov-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose: WMS-18313 PH UNILEVER STOCK TAKE VARIANCE REPORT - BY SKU CR*/
/*          Notes : Modified from ispPrtStockCheckVariance_Summary_bySKU*/
/*                                                                      */
/* Called By: 		                                                      */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 09-Nov-2021  Mingle        DevOps Combine Script                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_Summary_bySKU_ph] (
			@c_StockTakeKey NVARCHAR(10),
			@c_StorerKeyStart NVARCHAR(15),
			@c_StorerKeyEnd NVARCHAR(15),
			@c_SkuStart NVARCHAR(20),
			@c_SkuEnd NVARCHAR(20),
			@c_CountNo  NVARCHAR(2)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 --  IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL 
 --     DROP TABLE #TempStkVar

   
 
	--CREATE TABLE [#TempStkVar] (
	--		[StorerKey] [char] (10),  
	--		[CCKey] [char] (10),  
	--		[Sku] [char] (20),		
	--		[Descr] [char] (60) NULL,  
	--		[SUSR3] [char] (18) NULL,  
	--		[Qty] [FLOAT],   
	--		[Qty_Cnt2] [int],	
	--		[Qty_Cnt3] [int],	
	--		[PackUOM3] [char] (10) NULL,   
	--		[LotxLocxId_Qty] [FLOAT],	
	--		[VarQty_cal] [float],
 --        [Casecnt] [INT]
	--	)


 --  INSERT INTO #TempStkVar 
	-- (	StorerKey,	CCKey,		Sku,			Descr,		SUSR3,		Qty,			
	--	Qty_Cnt2,	Qty_Cnt3,	PackUOM3,	LotxLocxId_Qty,	VarQty_cal,
 --     Casecnt
	--)

   
   SELECT CCDetail.StorerKey,  
         CCDetail.CCKey,  
         CCDetail.Sku,   
			SKU.Descr,  
			SKU.SUSR3,  
         ROUND((SUM(CCDetail.Qty)/PACK.CaseCnt),2) AS Qty,  
         --SUM(CCDetail.Qty)/PACK.CaseCnt AS Qty, 
         --CAST((SUM(CCDetail.Qty_Cnt2)/PACK.CaseCnt)AS DECIMAL(5,2)) AS Qty_Cnt2, 
         ROUND((SUM(CCDetail.Qty_Cnt2)/PACK.CaseCnt),2) AS Qty_Cnt2,  
         ROUND((SUM(CCDetail.Qty_Cnt3)/PACK.CaseCnt),2) AS Qty_Cnt3,   
			PACK.PackUOM1,   
			ROUND((SUM(CCDetail.SystemQty)/PACK.CaseCnt),2) AS LotxLocxId_qty,--system qty--system qty 
			--VarQty_cal = CASE @c_countno
			--					WHEN '1' THEN (SUM(CCDetail.Qty) - SUM(CCDetail.SystemQty))/PACK.CaseCnt
			--					WHEN '2' THEN (SUM(CCDetail.Qty_Cnt2) - SUM(CCDetail.SystemQty))/PACK.CaseCnt
			--					WHEN '3' THEN (SUM(CCDetail.Qty_Cnt3) - SUM(CCDetail.SystemQty))/PACK.CaseCnt
			--					ELSE 0
			--				 END,
        -- VarQty_cal = CASE @c_countno
								--WHEN '1' THEN CAST(((SUM(CCDetail.Qty) - SUM(CCDetail.SystemQty))/PACK.CaseCnt)AS DECIMAL(5,2))
								--WHEN '2' THEN CAST(((SUM(CCDetail.Qty_Cnt2) - SUM(CCDetail.SystemQty))/PACK.CaseCnt)AS DECIMAL(5,2))
								--WHEN '3' THEN CAST(((SUM(CCDetail.Qty_Cnt3) - SUM(CCDetail.SystemQty))/PACK.CaseCnt)AS DECIMAL(5,2))
								--ELSE 0
							 --END,
         VarQty_cal = CASE '1'
								WHEN '1' THEN ROUND(((SUM(CCDetail.Qty) - SUM(CCDetail.SystemQty))/PACK.CaseCnt),2)
								WHEN '2' THEN ROUND(((SUM(CCDetail.Qty_Cnt2) - SUM(CCDetail.SystemQty))/PACK.CaseCnt),2)
								WHEN '3' THEN ROUND(((SUM(CCDetail.Qty_Cnt3) - SUM(CCDetail.SystemQty))/PACK.CaseCnt),2)
								ELSE 0
							 END,
         --ColumnA <> CONVERT(int,ColumnA)
         PACK.CaseCnt
   FROM  CCDetail CCDetail (NOLOCK)  
   JOIN  SKU SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDetail.StorerKey) 
   JOIN  PACK PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
   JOIN  LOC LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
   JOIN  STORER COMPANY (NOLOCK) ON (COMPANY.Storerkey = 'JDHR')			-- (YokeBeen01) SOS25214
   JOIN  STORER CURRENCY (NOLOCK) ON (CURRENCY.Storerkey = 'CURRENCY')	-- (YokeBeen01)
	WHERE ( CCDetail.CCKey = @c_StockTakeKey )  
   AND   ( CCDetail.StorerKey >= @c_StorerKeyStart )  
   AND   ( CCDetail.StorerKey <= @c_StorerKeyEnd )  
   AND   ( CCDetail.Sku >= @c_SkuStart )  
   AND   ( CCDetail.Sku <= @c_SkuEnd )
	GROUP BY CCDetail.StorerKey,  
         CCDetail.CCKey,  
         CCDetail.Sku,   
			SKU.Descr,  
			SKU.SUSR3,  
			PACK.PackUOM1,
         PACK.CaseCnt
   ORDER BY CCDetail.StorerKey,  
			CCDetail.CCKey,  
         CCDetail.Sku,  
			SKU.SUSR3

   -- Remove all the records with no variance
   -- DELETE #TempStkVar FROM #TempStkVar WHERE #TempStkVar.VarQty_cal = 0

   --SELECT * FROM #TempStkVar  

END


--sp_helptext 'ispPrtStockCheckVariance_Summary_bySKU_cn'

GO