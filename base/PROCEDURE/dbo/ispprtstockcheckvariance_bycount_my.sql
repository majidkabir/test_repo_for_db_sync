SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Trigger: ispPrtStockCheckVariance_byCount_MY                          */  
/* Creation Date: 09-Aug-2005                                            */  
/* Copyright: IDS                                                        */  
/* Written by: MaryVong                                                  */  
/*                                                                       */  
/* Purpose: SOS38777 Modify StockVariance Report for MY                  */  
/*          Notes : Duplicate from ispPrtStockCheckVariance_byCount      */  
/*          Used for report dw :                                         */  
/*          1) r_dw_stocktake_variance_cnt1_MY                           */  
/*      2) r_dw_stocktake_variance_cnt2_MY                    */  
/*      3) r_dw_stocktake_variance_cnt3_MY                    */  
/*                                                                       */  
/* Called By:                                                          */  
/*                                                                       */  
/* PVCS Version: 1.4                                                   */  
/*                                                                       */  
/* Version: 6.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author    Ver. Purposes                                  */  
/* 11-Aug-2005  MaryVong       SOS38777 Add new field Item Class         */  
/* 01-Sep-2005  Shong          Change Permanent Table TempStkVar to      */  
/*                             Temp Table #TempStkVar                    */   
/* 16-Sep-2005  MaryVong       SOS40667 Add new field Lottable05,        */  
/*                             Lottable05_Cnt2, Lottable05_Cnt3          */  
/* 07-Dec-2006  MaryVong       SOS63330 Add CCDetail.EditWho1/2/3 to     */  
/*                             track user performance                    */  
/* 22-Dec-2009  NJOW01         SOS156592 Add Lottable01                  */   
/* 23-Nov-2012  NJOW02         262697-Add in HWCode                      */  
/* 2017-07-25   TLTING  1.1   SET Option                                */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_byCount_MY] (  
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
   IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL   
      DROP TABLE #TempStkVar  
  
 CREATE TABLE [#TempStkVar] (  
   [StorerKey] [NVARCHAR] (10),    
   [CCKey] [NVARCHAR] (10),    
   [Sku] [NVARCHAR] (20),    
   [Descr] [NVARCHAR] (60) NULL,    
   -- [TagNo] [NVARCHAR] (10) NULL, -- SOS38777  
   [CCSheetNo] [NVARCHAR] (10) NULL, -- SOS38777  
   [SUSR3] [NVARCHAR] (18) NULL,    
   [Cost] [money] NULL,    
   [Facility] [NVARCHAR] (5) NULL,   
   [Lot] [NVARCHAR] (10) NULL,   
   [Id] [NVARCHAR] (18) NULL,  -- SOS38777  
   [Loc] [NVARCHAR] (10) NULL,   
   [Lottable01] [NVARCHAR] (18) NULL,-- NJOW01  
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
   [LotxLocxId_Qty] [int],   
   [VarQty_cal] [int],    
   [VarHKD_cal] [float] NULL,  
       [SkuGroup] [NVARCHAR] (10) NULL,  
       [ItemClass] [NVARCHAR] (10) NULL,  -- SOS38777  
   [CompanyName] [NVARCHAR] (45) NULL,  
   [Currency] [NVARCHAR] (45) NULL,  
   [Lottable05] [datetime] NULL,     -- SOS40667  
   [Lottable05_Cnt2] [datetime] NULL, -- SOS40667  
   [Lottable05_Cnt3] [datetime] NULL, -- SOS40667  
   [UserID] [NVARCHAR] (18) NULL,           -- SOS63330  
   [HOSTWHCODE] [NVARCHAR] (10) NULL  --NJOW02  
  )  
  
  
   INSERT INTO #TempStkVar   
  ( STORERKEY,   CCKey,    Sku,     Descr,     CCSheetNo,   SUSR3,  
  Cost,     Facility,   Lot,     Id,                  Loc,     Lottable02,  
  Lottable02_Cnt2, Lottable02_Cnt3, Lottable04,   Lottable04_Cnt2,  Lottable04_Cnt3, Qty,  
  Qty_Cnt2,   Qty_Cnt3,   PackUOM3,   PackQty,     LotxLocxId_Qty, VarQty_cal,  
  VarHKD_cal,   SkuGroup,   ItemClass,        CompanyName,      Currency,  
  Lottable05,   Lottable05_Cnt2, Lottable05_Cnt3,  -- SOS40667  
  UserID,  -- SOS63330  
  Lottable01, --NJOW01  
  HOSTWHCODE --NJOW02  
 )  
   SELECT CCDetail.StorerKey,    
         CCDetail.CCKey,    
         CCDetail.Sku,     
   SKU.Descr,    
   CCDetail.CCSheetNo, -- SOS38777  
   SKU.SUSR3,    
   SKU.Cost,    
   LOC.Facility,  
         CCDetail.Lot,     
         CCDetail.Id,   -- SOS38777  
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
   CCDetail.SystemQty AS LotxLocxId_qty,   
   VarQty_cal = CASE @c_countno  
        WHEN '1' THEN CCDetail.Qty - CCDetail.SystemQty  
        WHEN '2' THEN CCDetail.Qty_Cnt2 - CCDetail.SystemQty  
        WHEN '3' THEN CCDetail.Qty_Cnt3 - CCDetail.SystemQty  
        ELSE 0  
        END,   
   VarHKD_cal = CASE WHEN ((CONVERT(decimal(15,3), SKU.Cost) = null) OR (CONVERT(decimal(15,3), SKU.Cost) = 0)   
           OR (CONVERT(NVARCHAR(15), SKU.Cost) = '')) THEN 0.0   
          ELSE CASE @c_countno  
                              WHEN '1' THEN CONVERT(decimal(20,2), SKU.Cost * (CCDetail.Qty - CCDetail.SystemQty))  
              WHEN '2' THEN CONVERT(decimal(20,2), SKU.Cost * (CCDetail.Qty_Cnt2 - CCDetail.SystemQty))  
              WHEN '3' THEN CONVERT(decimal(20,2), SKU.Cost * (CCDetail.Qty_Cnt3 - CCDetail.SystemQty))  
                ELSE 0.0  
             END  
          END,  
         SKU.SkuGroup,  
         SKU.ItemClass,  
   COMPANY.Company,  
   CURRENCY.Company,  
         CCDetail.Lottable05,       -- SOS40667   
   CCDetail.Lottable05_Cnt2,  -- SOS40667   
   CCDetail.Lottable05_Cnt3,  -- SOS40667   
         -- SOS63330     
   UserID = CASE @c_countno  
        WHEN '1' THEN ISNULL(EditWho_Cnt1, '')  
        WHEN '2' THEN ISNULL(EditWho_Cnt2, '')  
        WHEN '3' THEN ISNULL(EditWho_Cnt3, '')  
        ELSE ''  
                  END,  
      CCDetail.Lottable01, --NJOW01  
      LOC.HOSTWHCODE --NJOW02  
   FROM  CCDetail CCDetail (NOLOCK)    
   JOIN  SKU SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDetail.StorerKey)   
   JOIN  PACK PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey )   
   JOIN  LOC LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )    
   JOIN  STORER COMPANY (NOLOCK) ON (COMPANY.Storerkey = 'JDHR')   -- (YokeBeen01) SOS25214  
   JOIN  STORER CURRENCY (NOLOCK) ON (CURRENCY.Storerkey = 'CURRENCY') -- (YokeBeen01)  
 WHERE ( CCDetail.CCKey = @c_StockTakeKey )    
   AND   ( CCDetail.StorerKey >= @c_StorerKeyStart )    
   AND   ( CCDetail.StorerKey <= @c_StorerKeyEnd )    
   AND   ( CCDetail.Sku >= @c_SkuStart )    
   AND   ( CCDetail.Sku <= @c_SkuEnd )  
   ORDER BY CCDetail.StorerKey,    
   CCDetail.CCKey,    
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
         CCDetail.Lot,  
         CCDetail.Lottable05,       -- SOS40667   
   CCDetail.Lottable05_Cnt2,  -- SOS40667   
   CCDetail.Lottable05_Cnt3   -- SOS40667   
  
   -- Remove all the records with no variance  
   -- DELETE #TempStkVar FROM #TempStkVar WHERE #TempStkVar.VarQty_cal = 0  
  
   SELECT * FROM #TempStkVar    
  
END  

GO