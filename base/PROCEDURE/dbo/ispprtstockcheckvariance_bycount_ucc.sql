SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- For StockTake Variance Reports (FBR7046).
-- Created By YokeBeen on 16-Aug-2002

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_byCount_UCC] (
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
      [SkuGroup] [char] (10) NULL, -- Added By Vicky 11 June 2003 SOS#11275
		[UCCNo] [varchar] (20) )  

  INSERT INTO #TempStkVar 
	 (	STORERKEY,			CCKey,				Sku,						Descr,					TagNo,			SUSR3,
		Cost,					Facility,			Lot,						Loc,						Lottable02,		Lottable02_Cnt2,	
		Lottable02_Cnt3,	Lottable04,			Lottable04_Cnt2,		Lottable04_Cnt3,		Qty,				Qty_Cnt2,	
		Qty_Cnt3,			PackUOM3,			PackQty,					LotXLocXId_Qty,		VarQty_cal,		VarHKD_cal, 
      SkuGroup, UCCNo )  -- Added By Vicky 11 June 2003 SOS#11275
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
         SKU.SkuGroup, -- Added By Vicky 11 June 2003 SOS#11275
			CCDETAIL.RefNo -- UCCNo
--	into #result
    FROM CCDetail (NOLOCK)  
	 JOIN SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDETAIL.StorerKey) 
	 JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
	 JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
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