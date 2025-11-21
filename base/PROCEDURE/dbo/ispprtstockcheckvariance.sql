SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance] (
			@c_StockTakeKey NVARCHAR(10),
			@c_StorerKeyStart NVARCHAR(15),
			@c_StorerKeyEnd NVARCHAR(15),
			@c_SKUStart NVARCHAR(20),
			@c_SKUEnd NVARCHAR(20),
			@c_locstart NVARCHAR(10),
			@c_locend NVARCHAR(10),
			@c_skuclassstart NVARCHAR(10),
			@c_skuclassend NVARCHAR(10),
			@c_zonestart NVARCHAR(10),
			@c_zoneend NVARCHAR(10),
			@c_sheetstart NVARCHAR(10),
			@c_sheetend NVARCHAR(10),
			@c_finalize NVARCHAR(1),
			@c_CountNo  NVARCHAR(2)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

  SELECT UPPER(CCDETAIL.STORERKEY),  
         UPPER(CCDetail.Sku) as sku,
			CountQty = case @c_countno
								when '1' then CCDetail.Qty
								when '2' then CCDetail.Qty_Cnt2
								when '3' then CCDetail.Qty_Cnt3
								else 0
						  end,
			QtyLOTxLOCxID = ccdetail.systemqty,
			SKU.Descr,
			SKU.packkey,  
			ccdetail.ccsheetno,
			ccdetail.loc,
			variance = case @c_countno
								when '1' then CCDetail.Qty - ccdetail.systemqty
								when '2' then CCDetail.Qty_Cnt2 - ccdetail.systemqty
								when '3' then CCDetail.Qty_Cnt3 - ccdetail.systemqty
								else 0
							 end,
			@c_stocktakekey as 'stocktakekey',
			@c_StorerKeyStart as 'storerstart',
			@c_StorerKeyEnd as 'storerend',
			@c_SKUStart as 'skustart',
			@c_SKUEnd	as 'skuend',
			@c_locstart as 'locstart',
			@c_locend as 'locend',
			@c_skuclassstart as 'classstart',
			@c_skuclassend as 'classend',
			@c_zonestart as 'zonestart',
			@c_zoneend as 'zoneend',
			@c_sheetstart as 'sheetstart',
			@c_sheetend as 'sheetend',
			@c_finalize as 'finalize',
			@c_CountNo as 'countno', 
			ccdetail.id, 
			ccdetail.refno as 'uccno' 
    FROM CCDetail (NOLOCK)  
	 JOIN SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.Storerkey = CCDetail.Storerkey) 
	 JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
	 JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
	WHERE ( CCDetail.CCKey = @c_StockTakeKey )  
	  AND ( CCDetail.StorerKey >= @c_StorerKeyStart )  
	  AND ( CCDetail.StorerKey <= @c_StorerKeyEnd )  
	  AND ( CCDetail.Sku >= @c_SkuStart )  
	  AND ( CCDetail.Sku <= @c_SkuEnd )
	  and ( sku.class >= @c_skuclassstart )
	  and ( sku.class <= @c_skuclassend )
	  and ( loc.putawayzone >= @c_zonestart )
	  and ( loc.putawayzone <= @c_zoneend )
	  and ( ccdetail.loc >= @c_locstart )
	  and ( ccdetail.loc <= @c_locend )
	  and ( ccdetail.ccsheetno >= @c_sheetstart )
	  and ( ccdetail.ccsheetno <= @c_sheetend )
     and ( ccdetail.finalizeflag = @c_finalize 
				or ccdetail.finalizeflag_cnt2 = @c_finalize 
				or ccdetail.finalizeflag_cnt3 = @c_finalize )
ORDER BY CCDETAIL.STORERKEY,  
			CCDETAIL.CCKey,  
         CCDetail.Sku,  
         CCDetail.Loc  

END -- End Procedure

GO