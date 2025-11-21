SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPrtStockCheckVariance_Summary_bySKU_CN                   */
/* Creation Date: 03-Jan-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: June																		*/
/*                                                                      */
/* Purpose: IDSCN Swire (SOS95028)													*/
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
/*                                                                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_Summary_bySKU_CN] (
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
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL 
      DROP TABLE #TempStkVar

	CREATE TABLE [#TempStkVar] (
			[StorerKey] [char] (10),  
			[CCKey] [char] (10),  
			[Sku] [char] (20),		
			[Descr] [char] (60) NULL,  
			[SUSR3] [char] (18) NULL,  
			[Qty] [int],   
			[Qty_Cnt2] [int],	
			[Qty_Cnt3] [int],	
			[PackUOM3] [char] (10) NULL,   
			[LotxLocxId_Qty] [int],	
			[VarQty_cal] [int],
			[Size] [char] (5) NULL
		)


   INSERT INTO #TempStkVar 
	 (	StorerKey,	CCKey,		Sku,			Descr,		SUSR3,		Qty,			
		Qty_Cnt2,	Qty_Cnt3,	PackUOM3,	LotxLocxId_Qty,	VarQty_cal, Size
	)
   SELECT CCDetail.StorerKey,  
         CCDetail.CCKey,  
         CCDetail.Sku,   
			SKU.Descr,  
			SKU.SUSR3,  
         Qty = CASE @c_countno
				WHEN '1' THEN SUM(CCDetail.Qty)
				WHEN '2' THEN SUM(CCDetail.Qty_Cnt2)
				WHEN '3' THEN SUM(CCDetail.Qty_Cnt3)
				ELSE 0
				END,
         SUM(CCDetail.Qty_Cnt2) AS Qty_Cnt2,   
         SUM(CCDetail.Qty_Cnt3) AS Qty_Cnt3,   
			PACK.PackUOM3,   
			SUM(CCDetail.SystemQty) AS LotxLocxId_qty, 
			VarQty_cal = CASE @c_countno
								WHEN '1' THEN SUM(CCDetail.Qty) - SUM(CCDetail.SystemQty)
								WHEN '2' THEN SUM(CCDetail.Qty_Cnt2) - SUM(CCDetail.SystemQty)
								WHEN '3' THEN SUM(CCDetail.Qty_Cnt3) - SUM(CCDetail.SystemQty)
								ELSE 0
							 END,
			SKU.Size 
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
			PACK.PackUOM3,
			SKU.Size 
   ORDER BY CCDetail.StorerKey,  
			CCDetail.CCKey,  
         CCDetail.Sku,  
			SKU.SUSR3

   -- Remove all the records with no variance
   -- DELETE #TempStkVar FROM #TempStkVar WHERE #TempStkVar.VarQty_cal = 0

   SELECT * FROM #TempStkVar  

END

GO