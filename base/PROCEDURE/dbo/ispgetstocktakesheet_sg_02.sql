SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure:  ispGetStockTakeSheet_sg_02                         */      
/* Creation Date: 26-JUN-2012                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                       */      
/*                                                                      */      
/* Purpose: 247342 - Singapore Stocktake Sheet                          */      
/*          (modified from ispGetStockTakeSheet)                        */      
/*                                                                      */      
/* Called By: r_dw_stocktake_sg_02                            */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 6.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver.   Purposes                                */      
/* 22-MAY-2014  CSCHONG  1.0    Added Lottables 06-15 (CS01)            */      
/* 16-Dec-2015  CSCHONG  1.1    SOS#358647 (CS02)                       */      
/* 19-AUG-2015  WAN01    1.2    SOS#375359- MHAP - STOCK TAKE COUNT     */      
/*                              SHEET.                                  */  
/* 12-Dec-2018  CHEEMUN  1.3    INC0502109 - Fix Column Name Align with */    
/*                                   Datawindow                 */      
/************************************************************************/      
      
CREATE PROC [dbo].[ispGetStockTakeSheet_sg_02] (      
@c_CCKey_Start       NVARCHAR(10),      
@c_CCKey_End         NVARCHAR(10),      
@c_Sku_Start         NVARCHAR(20),      
@c_Sku_End           NVARCHAR(20),      
@c_SKUClass_Start    NVARCHAR(10),      
@c_SKUClass_End      NVARCHAR(10),      
@c_StorerKey_Start   NVARCHAR(15),      
@c_StorerKey_End     NVARCHAR(15),      
@c_Loc_Start         NVARCHAR(10),      
@c_Loc_End           NVARCHAR(10),      
@c_zone_start       NVARCHAR(10),      
@c_zone_end          NVARCHAR(10),      
@c_ccsheetno_start NVARCHAR(10),      
@c_ccsheetno_end  NVARCHAR(10),      
@c_withqty NVARCHAR(1),      
@c_CountNo  NVARCHAR(1)      
)      
AS      
BEGIN       
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
  -- prepare result table      
  SELECT CCDETAIL.CCKey,  -- SOS63326      
         CCDETAIL.ccsheetno,      
         CCDETAIL.lot,      
         CCDETAIL.loc,      
         CCDETAIL.id,      
         CCDETAIL.storerkey,      
         CCDETAIL.sku,      
         descr = space(60),      
          CASE @c_CountNo       
               WHEN '1' THEN CCDETAIL.lottable01      
               WHEN '2' THEN CCDETAIL.lottable01_Cnt2      
               WHEN '3' THEN CCDETAIL.lottable01_Cnt3                 
          END as Lottable01,      
          CASE @c_CountNo       
               WHEN '1' THEN CCDETAIL.lottable02      
               WHEN '2' THEN CCDETAIL.lottable02_Cnt2      
               WHEN '3' THEN CCDETAIL.lottable02_Cnt3                 
          END as Lottable02,      
          CASE @c_CountNo       
               WHEN '1' THEN CCDETAIL.lottable03      
               WHEN '2' THEN CCDETAIL.lottable03_Cnt2      
               WHEN '3' THEN CCDETAIL.lottable03_Cnt3                 
          END as Lottable03,      
          CASE @c_CountNo       
               WHEN '1' THEN CCDETAIL.lottable04      
               WHEN '2' THEN CCDETAIL.lottable04_Cnt2      
               WHEN '3' THEN CCDETAIL.lottable04_Cnt3                 
          END as Lottable04,      
          CASE @c_CountNo       
               WHEN '1' THEN CCDETAIL.lottable05      
               WHEN '2' THEN CCDETAIL.lottable05_Cnt2      
               WHEN '3' THEN CCDETAIL.lottable05_Cnt3                 
          END as Lottable05,      
         CASE @c_CountNo       
                WHEN '1' THEN CCDETAIL.qty      
                WHEN '2' THEN CCDETAIL.Qty_Cnt2      
                WHEN '3' THEN CCDETAIL.Qty_Cnt3      
          END AS Qty,      
         packuom3 = space(10),      
         LOC.putawayzone,      
         LOC.loclevel,      
         LOC.locaisle as aisle,    --INC0502109       
         LOC.facility,      
         CaseCnt = 0,      
         SKUGroupDesc = SPACE(60),      
         SKUGroup=SPACE(10),      
         PalletCnt = 0,      
          CCDetailKey,      
          CCDETAIL.SystemQty,    -- 22Sep2005 by ONG SOS40884, It will be set to '0' IF @c_withqty <> 'Y'       
          SKU.RetailSku,      
     /*CS01 Start*/      
  CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable06      
           WHEN '2' THEN CCDETAIL.lottable06_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable06_Cnt3      
      END as Lottable06,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable07      
           WHEN '2' THEN CCDETAIL.lottable07_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable07_Cnt3      
      END as Lottable07,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable08      
           WHEN '2' THEN CCDETAIL.lottable08_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable08_Cnt3      
      END as Lottable08,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable09      
           WHEN '2' THEN CCDETAIL.lottable09_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable09_Cnt3      
      END as Lottable09,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable10      
           WHEN '2' THEN CCDETAIL.lottable10_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable10_Cnt3      
      END as Lottable10,      
  CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable11      
           WHEN '2' THEN CCDETAIL.lottable11_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable11_Cnt3      
      END as Lottable11,     --INC0502109      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable12      
           WHEN '2' THEN CCDETAIL.lottable12_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable12_Cnt3      
      END as Lottable12,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable13      
           WHEN '2' THEN CCDETAIL.lottable13_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable13_Cnt3      
      END as Lottable13,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable14      
           WHEN '2' THEN CCDETAIL.lottable14_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable14_Cnt3      
      END as Lottable14,      
      CASE @c_CountNo      
           WHEN '1' THEN CCDETAIL.lottable15      
           WHEN '2' THEN CCDETAIL.lottable15_Cnt2      
           WHEN '3' THEN CCDETAIL.lottable15_Cnt3      
      END as Lottable15      
  /*CS01 END*/      
     ,innerpack = 0                                                                --CS02      
     ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowUOM2Qty     --CS02      
     ,titlelabel_1 = CASE WHEN CLR1.Code IS NULL THEN '' ELSE CLR1.UDF01 END      
     ,titlelabel_2 = CASE WHEN CLR2.Code IS NULL THEN '' ELSE CLR2.UDF01 END      
     ,titlelabel_3 = CASE WHEN CLR3.Code IS NULL THEN '' ELSE CLR3.UDF01 END      
     ,Remark       = CASE WHEN CLR4.Code IS NULL THEN '' ELSE CLR4.UDF01 END      
  INTO #RESULT      
  FROM CCDETAIL (NOLOCK)      
  LEFT OUTER JOIN  LOC (NOLOCK) ON (LOC.loc = CCDETAIL.loc)      
   LEFT OUTER JOIN  SKU (NOLOCK) ON (CCDETAIL.StorerKey = SKU.StorerKey AND CCDETAIL.SKU = SKU.SKU)      
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (CCDETAIL.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWUOM2QTY'                                       --CS01      
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_stocktake_sg_02' AND ISNULL(CLR.Short,'') <> 'N')       --CS01      
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (CCDETAIL.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SKUGroupLabel'                                  --Wan01      
                             AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_stocktake_sg_02' AND ISNULL(CLR1.Short,'') <> 'N')    --Wan01      
   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (CCDETAIL.Storerkey = CLR2.Storerkey AND CLR2.Code = 'PackkeyLabel'                                   --Wan01      
     AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_stocktake_sg_02' AND ISNULL(CLR2.Short,'') <> 'N')    --Wan01      
   LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (CCDETAIL.Storerkey = CLR3.Storerkey AND CLR3.Code = 'Lottable02Label'                                --Wan01      
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_stocktake_sg_02' AND ISNULL(CLR3.Short,'') <> 'N')    --Wan01      
   LEFT OUTER JOIN Codelkup CLR4 (NOLOCK) ON (CCDETAIL.Storerkey = CLR4.Storerkey AND CLR4.Code = 'ShowRemarkLabel'                                   --Wan01      
                                       AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_stocktake_sg_02' AND ISNULL(CLR4.Short,'') <> 'N')    --Wan01      
   WHERE CCDETAIL.CCKey BETWEEN @c_CCKey_Start AND @c_CCKey_End      
   AND   CCDETAIL.ccsheetno BETWEEN @c_ccsheetno_start AND @c_ccsheetno_end      
   AND   LOC.PutawayZone BETWEEN @c_zone_start AND @c_zone_end      
   AND   LOC.LOC BETWEEN @c_Loc_start AND @c_Loc_end         
        
  IF @c_withqty = 'Y'      
     UPDATE #RESULT       
      SET #RESULT.packuom3 = PACK.packuom3,       
          #RESULT.descr = SKU.descr,      
          #RESULT.CaseCnt = PACK.CaseCnt,      
          #RESULT.PalletCnt = PACK.Pallet,      
          #RESULT.SKUGroupDesc = CODELKUP.Description,      
          #RESULT.SKUGroup = SKU.SKUGroup,      
          #RESULT.innerpack = CASE WHEN ISNULL(PACK.innerpack,'') > 1 THEN PACK.innerpack ELSE 1 END      
     FROM SKU (NOLOCK)       
     JOIN #RESULT ON SKU.sku = #RESULT.sku      
                  AND SKU.StorerKey = #RESULT.StorerKey -- SOS# 161802      
     JOIN PACK (NOLOCK) ON SKU.packkey = PACK.packkey      
      LEFT JOIN CodeLkUp (NOLOCK) ON SKU.SKUGroup = CodeLkUp.Code      
                                  AND CodeLkUp.ListName = 'SKUGROUP'      
  ELSE      
     UPDATE #RESULT       
      SET #RESULT.packuom3 = PACK.packuom3,       
      #RESULT.descr = SKU.descr,       
      #RESULT.qty = 0,      
      #RESULT.CaseCnt = PACK.CaseCnt,      
      #RESULT.PalletCnt = PACK.Pallet,      
      #RESULT.SKUGroupDesc = CODELKUP.Description,      
      #RESULT.SKUGroup = SKU.SKUGroup,      
      #RESULT.SystemQty = 0,      
      #RESULT.innerpack = CASE WHEN ISNULL(PACK.innerpack,'') > 1 THEN PACK.innerpack ELSE 1 END      
     FROM SKU (NOLOCK) INNER JOIN #RESULT      
     ON SKU.sku = #RESULT.sku      
     AND SKU.StorerKey = #RESULT.StorerKey -- SOS# 161802      
     INNER JOIN PACK      
     ON SKU.packkey = PACK.packkey      
                   LEFT OUTER JOIN CodeLkUp      
                   ON SKU.SKUGroup = CodeLkUp.Code      
                   AND CodeLkUp.ListName = 'SKUGROUP'      
         
  SELECT * FROM #RESULT       
   WHERE StorerKey BETWEEN @c_StorerKey_Start AND @c_StorerKey_End      
   AND   SKU BETWEEN @c_SKU_Start AND @c_SKU_End      
   -- AND   itemclass Between @c_SKUClass_Start AND @c_SKUClass_End      
         
  DROP TABLE #RESULT      
END 

GO