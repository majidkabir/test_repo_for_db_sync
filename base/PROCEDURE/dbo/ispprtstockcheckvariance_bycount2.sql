SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- For IDSPH StockTake Variance Report SOS11081
-- Created By June on 8.May.2003

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_byCount2] (
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
			varhkd_cal = case when ((convert(decimal(15,3), sku.cost) = null) or (convert(decimal(15,3), sku.cost) = 0) 
											or (convert(NVARCHAR(15), sku.cost) = '')) then 0.0	
						else case @c_countno
								when '1' then convert(decimal(20,2), sku.cost * (CCDetail.Qty - ccdetail.systemqty))
								when '2' then convert(decimal(20,2), sku.cost * (CCDetail.Qty_Cnt2 - ccdetail.systemqty))
								when '3' then convert(decimal(20,2), sku.cost * (CCDetail.Qty_Cnt3 - ccdetail.systemqty))
								else 0.0
							 end
						end,
		   QtyinCS = CASE WHEN PACK.Casecnt > 0 THEN ROUND(CCDetail.Qty / PACK.Casecnt, 2) Else 0 End,   
		   QtyinCS_Cnt2 = CASE WHEN PACK.Casecnt > 0 THEN ROUND(CCDetail.Qty_Cnt2 / PACK.Casecnt, 2) Else 0 End,   
		   QtyinCS_Cnt3 = CASE WHEN PACK.Casecnt > 0 THEN ROUND(CCDetail.Qty_Cnt3 / PACK.Casecnt, 2) Else 0 End,
			LotXLocXId_QtyinCS = CASE WHEN PACK.Casecnt > 0 THEN ROUND(ccdetail.systemqty / PACK.Casecnt, 2) Else 0 End
	INTO #result
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
	
DELETE #RESULT WHERE VarQty_cal = 0
SELECT * FROM #RESULT
SET NOCOUNT OFF

END -- End Procedure

GO