SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispPrtStockCheckVariance_byCount_SG                */
/* Creation Date:                                     						*/
/* Copyright: IDS                                                       */
/* Written by:                                           					*/
/*                                                                      */
/* Purpose:  Print Stock Take Variance Report - by Count No for IDSSG.  */
/*           (Get from ispPrtStockCheckVariance_byCount)						*/
/*                                                                      */
/* Input Parameters: @c_StockTakeKey,     - StockTakeKey						*/
/*                   @c_StorerKeyStart,   - StorerKey Start             */
/*                   @c_StorerKeyEnd,     - StorerKey End               */
/*                   @c_SKUStart,         - Sku Start                   */
/*                   @c_SKUEnd,           - Sku End                     */
/*                   @c_CountNo           - StockTake Count No.         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_stocktake_variance_cnt1_SG         */
/*			  r_dw_stocktake_variance_cnt2_SG & 									*/
/*			  r_dw_stocktake_variance_cnt3_SG										*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*	10-Dec-2004	 MaryVong		Added 1 new field:Lottable05(ShipmentDate)*/
/*										(SOS30061)								         */
/*	13-May-2005	 June 			Added 2 new field:Lottable05_cnt2 & 		*/
/* 									Lottable05_cnt3 to fix bug in SOS30061		*/	
/* 16-Sep-2005  MaryVong      Change Permanent Table TempStkVar to      */
/*                            Temp Table #TempStkVar                    */		
/*																								*/
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_byCount_SG] (
			@c_StockTakeKey NVARCHAR(10),
			@c_StorerKeyStart NVARCHAR(15),
			@c_StorerKeyEnd NVARCHAR(15),
			@c_SKUStart NVARCHAR(20),
			@c_SKUEnd NVARCHAR(20),
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
			[STORERKEY] [char] (10),  
			[CCKey] [char] (10),  
			[Sku] [char] (20),		
			[Descr] [char] (60) NULL,  
			[TagNo] [char] (10) NULL,	
			[SUSR3] [char] (18) NULL,  
			[Cost] [money] NULL,  
			[Facility] [char] (5) NULL,	
			[Lot] [char] (10) NULL,	
			[Loc] [char] (10) NULL,	
			[Lottable02] [char] (18) NULL,		
			[Lottable02_Cnt2] [char] (18) NULL,  
			[Lottable02_Cnt3] [char] (18) NULL,	
			[Lottable04] [datetime] NULL,		
			[Lottable04_Cnt2] [datetime] NULL,	
			[Lottable04_Cnt3] [datetime] NULL,	
			[Qty] [int],   
			[Qty_Cnt2] [int],	
			[Qty_Cnt3] [int],	
			[PackUOM3] [char] (10) NULL,   
			[PackQty] [float],  
			[LotXLocXId_Qty] [int],	
			[VarQty_cal] [int],		
			[VarHKD_cal] [float] NULL,
	      [SkuGroup] [char] (10) NULL,			-- Added By Vicky 11 June 2003 SOS#11275
			[CompanyName] [char] (45) NULL,		-- (YokeBeen01)
			[Currency] [char] (45) NULL, 			-- (YokeBeen01)
			[Lottable05] [datetime] NULL,			-- SOS30061
			[Lottable05_Cnt2] [datetime] NULL,	-- SOS30061
			[Lottable05_Cnt3] [datetime] NULL) 	-- SOS30061


  INSERT INTO #TempStkVar 
	 (	STORERKEY,			CCKey,				Sku,						Descr,					TagNo,			SUSR3,
		Cost,					Facility,			Lot,						Loc,						Lottable02,		Lottable02_Cnt2,	
		Lottable02_Cnt3,	Lottable04,			Lottable04_Cnt2,		Lottable04_Cnt3,		Qty,				Qty_Cnt2,	
		Qty_Cnt3,			PackUOM3,			PackQty,					LotXLocXId_Qty,		VarQty_cal,		VarHKD_cal, 
      SkuGroup,   -- Added By Vicky 11 June 2003 SOS#11275
		CompanyName, Currency,		-- (YokeBeen01)
		Lottable05,       Lottable05_Cnt2, Lottable05_Cnt3)			-- SOS30061
  SELECT CCDETAIL.STORERKEY,  
			CCDETAIL.CCKey,  
         CCDetail.Sku,   
			SKU.Descr,  
			ISNULL(CCDetail.TagNo, '') AS TagNo,   
			SKU.SUSR3,  
			SKU.Cost,  
			LOC.Facility,   
         CCDetail.Lot,   
         CCDetail.Loc,   
			CCDetail.Lottable02,   
			CCDetail.Lottable02_Cnt2,  
			CCDetail.Lottable02_Cnt3,  
         CCDetail.Lottable04,  
			CCDetail.Lottable04_Cnt2,  
			CCDetail.Lottable04_Cnt3,   
         CCDetail.Qty AS Qty,   
         CCDetail.Qty_Cnt2 AS Qty_Cnt2,   
         CCDetail.Qty_Cnt3 AS Qty_Cnt3,   
			PACK.PackUOM3,   
			PACK.Qty AS PackQty,  
			ccdetail.systemqty AS lotxlocxid_qty, 
			VarQty_cal = case @c_countno
								when '1' then CCDetail.Qty - ccdetail.systemqty
								when '2' then CCDetail.Qty_Cnt2 - ccdetail.systemqty
								when '3' then CCDetail.Qty_Cnt3 - ccdetail.systemqty
								else 0
							 end, 
			-- Modified by YokeBeen on 07-Nov-2002.  Check for cost if NULL or Space, then assign 0.
			-- This checking is applied for Phase 4.
			varhkd_cal = case when ((convert(decimal(15,3), sku.cost) = null) or (convert(decimal(15,3), sku.cost) = 0) 
											or (convert(NVARCHAR(15), sku.cost) = '')) then 0.0	
						else case @c_countno
								when '1' then convert(decimal(20,2), sku.cost * (CCDetail.Qty - ccdetail.systemqty))
								when '2' then convert(decimal(20,2), sku.cost * (CCDetail.Qty_Cnt2 - ccdetail.systemqty))
								when '3' then convert(decimal(20,2), sku.cost * (CCDetail.Qty_Cnt3 - ccdetail.systemqty))
								else 0.0
							 end
						end,
         SKU.SkuGroup,			-- Added By Vicky 11 June 2003 SOS#11275
			COMPANY.Company,		-- (YokeBeen01)
			CURRENCY.Company,		-- (YokeBeen01)
			CCDetail.Lottable05,	-- SOS30061
			CCDetail.Lottable05_Cnt2,	-- SOS30061
			CCDetail.Lottable05_Cnt3   -- SOS30061
    FROM CCDetail CCDetail (NOLOCK)  
	 JOIN SKU SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDETAIL.StorerKey) 
	 JOIN PACK PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
	 JOIN LOC LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
	 JOIN STORER COMPANY (NOLOCK) ON (COMPANY.Storerkey = 'JDHR')			-- (YokeBeen01)
	 JOIN STORER CURRENCY (NOLOCK) ON (CURRENCY.Storerkey = 'CURRENCY')	-- (YokeBeen01)
	WHERE ( CCDetail.CCKey = @c_StockTakeKey )  
	  AND ( CCDetail.StorerKey >= @c_StorerKeyStart )  
	  AND ( CCDetail.StorerKey <= @c_StorerKeyEnd )  
	  AND ( CCDetail.Sku >= @c_SkuStart )  
	  AND ( CCDetail.Sku <= @c_SkuEnd )
ORDER BY CCDETAIL.STORERKEY,  
			CCDETAIL.CCKey,  
         CCDetail.Sku,  
			SKU.SUSR3,  
			LOC.Facility,   
         CCDetail.Loc,   
			CCDetail.Lottable02,   
			CCDetail.Lottable02_Cnt2,  
			CCDetail.Lottable02_Cnt3,  
         CCDetail.Lottable04,  
			CCDetail.Lottable04_Cnt2,  
			CCDetail.Lottable04_Cnt3,  
         CCDetail.Lot  

   -- Added by YokeBeen on 28-Aug-2002.
   -- To remove all the records with no variance.
   DELETE #TempStkVar FROM #TempStkVar WHERE #TempStkVar.VarQty_cal = 0

   SELECT * FROM #TempStkVar  

END -- End Procedure


GO