SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  ispPrtStockCheckVariance_byCount                  */  
/* Creation Date:                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                */  
/*                                                                      */  
/* Purpose:  Print Stock Take Variance Report - by Count No for IDSSG.  */  
/*           (Get from ispPrtStockCheckVariance_byCount)      */  
/*                                                                      */  
/* Input Parameters: @c_StockTakeKey,     - StockTakeKey      */  
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
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                              */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 16-Aug-2002  YokeBeen  StockTake Variance Reports (FBR7046)      */  
/*          (SOS30061)                 */  
/* 15-Jul-2004  YokeBeen   (SOS#25214) Added 2 new fields,           */  
/*                            CompanyName & Currency.               */  
/*          This is to allow each site having the own */  
/*                            CompanyName & title of Currency in the    */  
/*                            report without hardcoding.                */  
/* 24-Apr-2007  Shong         Change Permanent Table TempStkVar to      */  
/*                            Temp Table #TempStkVar                    */  
/* 09-May-2008  TLTING        Change Permanent Table TempStkVar to     */  
/* 30-Mar-2010  Leong         Insert record from #TempStkVar to         */  
/*                            TempStkVar for datawindow                 */  
/*                            r_dw_stocktake_variance_summary(Leong01)  */  
/* 2017-07-25   TLTING  1.1   SET Option                                */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_byCount] (  
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
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL  
      DROP TABLE #TempStkVar  
  
  
 CREATE TABLE [#TempStkVar] (  
   [STORERKEY] [NVARCHAR] (10),  
   [CCKey] [NVARCHAR] (10),  
   [Sku] [NVARCHAR] (20),  
   [Descr] [NVARCHAR] (60) NULL,  
   [TagNo] [NVARCHAR] (10) NULL,  
   [SUSR3] [NVARCHAR] (18) NULL,  
   [Cost] [money] NULL,  
   [Facility] [NVARCHAR] (5) NULL,  
   [Lot] [NVARCHAR] (10) NULL,  
   [Loc] [NVARCHAR] (10) NULL,  
   [Lottable02] [NVARCHAR] (18) NULL,  
   [Lottable02_Cnt2] [NVARCHAR] (18) NULL,  
   [Lottable02_Cnt3] [NVARCHAR] (18) NULL,  
   [Lottable04] [datetime] NULL,  
   [Lottable04_Cnt2] [datetime] NULL,  
   [Lottable04_Cnt3] [datetime] NULL,  
   [Qty] [int],  
   [Qty_Cnt2] [int],  
   [Qty_Cnt3] [int],  
   [PackUOM3] [NVARCHAR] (10) NULL,  
   [PackQty] [float],  
   [LotXLocXId_Qty] [int],  
   [VarQty_cal] [int],  
   [VarHKD_cal] [float] NULL,  
       [SkuGroup] [NVARCHAR] (10) NULL,   -- Added By Vicky 11 June 2003 SOS#11275  
   [CompanyName] [NVARCHAR] (45) NULL,  -- (YokeBeen01)  
   [Currency] [NVARCHAR] (45) NULL )   -- (YokeBeen01)  
  
   --Leong01 (Start)  
   DELETE TempStkVar  
   WHERE CCKey = @c_StockTakeKey  
     AND StorerKey >= @c_StorerKeyStart  
     AND StorerKey <= @c_StorerKeyEnd  
     AND Sku >= @c_SkuStart  
     AND Sku <= @c_SkuEnd  
  --Leong01 (End)  
  
  INSERT INTO #TempStkVar  
  ( STORERKEY,   CCKey,    Sku,      Descr,     TagNo,   SUSR3,  
  Cost,     Facility,   Lot,      Loc,      Lottable02,  Lottable02_Cnt2,  
  Lottable02_Cnt3, Lottable04,   Lottable04_Cnt2,  Lottable04_Cnt3,  Qty,    Qty_Cnt2,  
  Qty_Cnt3,   PackUOM3,   PackQty,     LotXLocXId_Qty,  VarQty_cal,  VarHKD_cal,  
      SkuGroup,   -- Added By Vicky 11 June 2003 SOS#11275  
  CompanyName, Currency )  -- (YokeBeen01)  
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
         SKU.SkuGroup,   -- Added By Vicky 11 June 2003 SOS#11275  
   COMPANY.Company,  -- (YokeBeen01)  
   CURRENCY.Company  -- (YokeBeen01)  
    FROM CCDetail CCDetail (NOLOCK)  
  JOIN SKU SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDETAIL.StorerKey)  
  JOIN PACK PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey )  
  JOIN LOC LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
  JOIN STORER COMPANY (NOLOCK) ON (COMPANY.Storerkey = 'JDHR')   -- (YokeBeen01)  
  JOIN STORER CURRENCY (NOLOCK) ON (CURRENCY.Storerkey = 'CURRENCY') -- (YokeBeen01)  
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
  
--Leong01 (Start)  
INSERT INTO TempStkVar  
( STORERKEY  
, CCKey  
, Sku  
, Descr  
, TagNo  
, SUSR3  
, Cost  
, Facility  
, Lot  
, Loc  
, Lottable02  
, Lottable02_Cnt2  
, Lottable02_Cnt3  
, Lottable04  
, Lottable04_Cnt2  
, Lottable04_Cnt3  
, Qty  
, Qty_Cnt2  
, Qty_Cnt3  
, PackUOM3  
, PackQty  
, LotXLocXId_Qty  
, VarQty_cal  
, VarHKD_cal  
, SkuGroup  
, CompanyName  
, Currency)  
SELECT STORERKEY  
, CCKey  
, Sku  
, Descr  
, TagNo  
, SUSR3  
, Cost  
, Facility  
, Lot  
, Loc  
, Lottable02  
, Lottable02_Cnt2  
, Lottable02_Cnt3  
, Lottable04  
, Lottable04_Cnt2  
, Lottable04_Cnt3  
, Qty  
, Qty_Cnt2  
, Qty_Cnt3  
, PackUOM3  
, PackQty  
, LotXLocXId_Qty  
, VarQty_cal  
, VarHKD_cal  
, SkuGroup  
, CompanyName  
, Currency FROM #TempStkVar  
--Leong01 (End)  
  
SELECT * FROM #TempStkVar  
  
END -- End Procedure  
  

GO