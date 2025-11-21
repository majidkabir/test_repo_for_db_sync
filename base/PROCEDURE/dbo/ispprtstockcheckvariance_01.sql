SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispPrtStockCheckVariance_01                         */
/* Creation Date: 27-Jun-2016                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:[TW] Add Stock Variance Report(SOS372155)                    */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Usage: Call by dw = r_stockcheck_variance_01                         */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 13-Feb-2017  CSCHONG        WMS-1063 Sum up qty by style color (CS01)*/
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_01] (
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

  SELECT UPPER(CCDETAIL.STORERKEY) AS storerkey,  
         UPPER(CCDetail.Sku) as sku,
			CountQty = case @c_countno
								when '1' then SUM(CCDetail.Qty )           --(CS01)
								when '2' then SUM(CCDetail.Qty_Cnt2)       --(CS01)
								when '3' then SUM(CCDetail.Qty_Cnt3)       --(CS01)
								else 0
						  end,
			QtyLOTxLOCxID = SUM(ccdetail.systemqty),          --(CS01)
			SKU.Descr,
			SKU.packkey,  
			ccdetail.ccsheetno,
			ccdetail.loc,
			variance = case @c_countno
								when '1' then SUM(CCDetail.Qty - ccdetail.systemqty)       --(CS01)
								when '2' then SUM(CCDetail.Qty_Cnt2 - ccdetail.systemqty)  --(CS01)
								when '3' then SUM(CCDetail.Qty_Cnt3 - ccdetail.systemqty)  --(CS01)
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
			'',--ccdetail.id, 
			ccdetail.refno as 'uccno',
			RTrim(SKU.style)+RTrim(SKU.color) as 'Article No',
			SKU.Size AS Size ,
			SUM(ccdetail.systemqty) AS 'Available Qty'  --(ISNULL((SL.QTY-SL.QtyAllocated-SL.QtyPicked),0)) as 'Available Qty'    --(CS01)
    FROM CCDetail (NOLOCK)  
	 JOIN SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.Storerkey = CCDetail.Storerkey) 
	 JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
	 JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
	 LEFT JOIN SKUXLOC SL (NOLOCK) ON SL.SKu = CCDETAIL.Sku AND SL.Loc = CCDETAIL.Loc AND SL.Storerkey = CCDETAIL.Storerkey
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
  /*CS01 Start*/				
  GROUP BY 	UPPER(CCDETAIL.STORERKEY),  
         UPPER(CCDetail.Sku),
         SKU.Descr,
			SKU.packkey,  
			ccdetail.ccsheetno,
			ccdetail.loc,	
		--	ccdetail.id, 
			ccdetail.refno,
			RTrim(SKU.style)+RTrim(SKU.color) ,
			SKU.Size 		
  /*CS01 End*/       
ORDER BY UPPER(CCDETAIL.STORERKEY),  
			--CCDETAIL.CCKey,  
         UPPER(CCDetail.Sku),  
         CCDetail.Loc  

END -- End Procedure

GO