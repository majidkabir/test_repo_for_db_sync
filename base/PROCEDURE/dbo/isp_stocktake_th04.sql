SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_Stocktake_TH04                                     */
/* Creation Date: 14-MAR-2014                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  TH-Revise Exceed Report to support RDT project #1             */
/*                                                                         */
/* Called By: PB: r_dw_stocktake_th04                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/

CREATE PROC [dbo].[isp_Stocktake_TH04]
           @c_CCKeyStart      NVARCHAR(10) 
         , @c_CCKeyEnd        NVARCHAR(10)
         , @c_SkuStart        NVARCHAR(20)
         , @c_SkuEnd          NVARCHAR(20)
         , @c_StorerkeyStart  NVARCHAR(15)
         , @c_StorerkeyEnd    NVARCHAR(15)
         , @c_ItemClassStart  NVARCHAR(20)
         , @c_ItemClassEnd    NVARCHAR(20)
         , @c_LocStart        NVARCHAR(10)
         , @c_LocEnd          NVARCHAR(10)
         , @c_ZoneStart       NVARCHAR(10)
         , @c_ZoneEnd         NVARCHAR(10)
         , @c_CCSheetNoStart  NVARCHAR(10)
         , @c_CCSheetNoEnd    NVARCHAR(10)
         , @c_WithQty         NVARCHAR(1)
         , @c_CountNo         NVARCHAR(1)
         , @c_FinalizeFlag    NVARCHAR(1)
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_Storerkey NVARCHAR(15)


   -- Storerkey Value can be Facility code or storer code.
   SELECT Storerkey
         ,ShowPackTIHI = ISNULL(MAX(CASE WHEN Code = 'ShowPackTIHI' THEN 1 ELSE 0 END),0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Long     = 'r_dw_stocktake_th04'
   AND   (Short    IS NULL OR Short = 'N')
   GROUP BY Storerkey


  SELECT CCDETAIL.CCKey    
       , CCDETAIL.CCSheetNo  
       , CCDETAIL.Storerkey   
       , CCDETAIL.Sku    
       , CCDETAIL.Lot    
       , CASE WHEN CCDETAIL.FinalizeFlag = 'Y' THEN 
                 CASE @c_CountNo
                 WHEN '1' THEN SUM(CCDETAIL.Qty)
                 WHEN '2' THEN SUM(CCDETAIL.Qty_Cnt2)
                 WHEN '3' THEN SUM(CCDETAIL.Qty_CNt3)
                 ELSE 0
                 END
         ELSE 0
         END AS CountQty    
       , CASE 
            WHEN @c_WithQty = 'Y' THEN 
               SUM(CCDETAIL.SystemQty)
            ELSE 0
         END AS SystemQty   
       , CASE CCDETAIL.FinalizeFlag 
            WHEN 'N' THEN CCDETAIL.Lottable01 
            WHEN 'Y' THEN CASE @c_CountNo
                          WHEN '1' THEN CCDETAIL.Lottable01
                          WHEN '2' THEN CCDETAIL.Lottable01_Cnt2
                          WHEN '3' THEN CCDETAIL.Lottable01_Cnt3
                          END
         END As Lottable01    
       , CASE CCDETAIL.FinalizeFlag 
            WHEN 'N' THEN CCDETAIL.Lottable02 
            WHEN 'Y' THEN CASE @c_CountNo
                          WHEN '1' THEN CCDETAIL.Lottable02
                          WHEN '2' THEN CCDETAIL.Lottable02_Cnt2
                          WHEN '3' THEN CCDETAIL.Lottable02_Cnt3
                          END
         END As Lottable02   
       , CASE CCDETAIL.FinalizeFlag 
            WHEN 'N' THEN CCDETAIL.Lottable03 
            WHEN 'Y' THEN CASE @c_CountNo
                          WHEN '1' THEN CCDETAIL.Lottable03
                          WHEN '2' THEN CCDETAIL.Lottable03_Cnt2
                          WHEN '3' THEN CCDETAIL.Lottable03_Cnt3
                          END
         END As Lottable03    
       , CASE CCDETAIL.FinalizeFlag 
            WHEN 'N' THEN CCDETAIL.Lottable04 
            WHEN 'Y' THEN CASE @c_CountNo
                          WHEN '1' THEN CCDETAIL.Lottable04
                          WHEN '2' THEN CCDETAIL.Lottable04_Cnt2
                          WHEN '3' THEN CCDETAIL.Lottable04_Cnt3
                          END
         END As Lottable04    
       , PACK.PackKey    
       , PACK.CaseCnt    
       , PACK.InnerPack    
       , SKU.DESCR   
       , CCDETAIL.Lottable05   
       , CCDETAIL.FinalizeFlag    
       , LOC.Facility   
       , LOC.PutawayZone   
       , LOC.LocLevel   
       , STORER.Company    
       , LOC.CCLogicalLoc  
       , LOC.LocAisle   
       , LOC.Loc  
       , CASE CCDETAIL.FinalizeFlag 
            WHEN 'N' THEN '1'
            WHEN 'Y' THEN @c_CountNo
         END AS CountNo 
       , CCDETAIL.Id 
       , TIHI = CONVERT(VARCHAR(8),Pack.PALLETTI) + ' x ' + CONVERT(VARCHAR(8), Pack.PALLETHI) 
       , ISNULL(ShowPackTIHI,0) 
   FROM CCDETAIL        WITH (NOLOCK)   
   LEFT OUTER JOIN SKU  WITH (NOLOCK) ON ( CCDETAIL.Storerkey = SKU.StorerKey 
                                      AND  CCDETAIL.Sku = SKU.Sku )
   LEFT OUTER JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
   JOIN LOC             WITH (NOLOCK) ON ( CCDETAIL.Loc = LOC.Loc ) 
   LEFT JOIN STORER     WITH (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )   
   LEFT OUTER JOIN STOCKTAKESHEETPARAMETERS WITH (NOLOCK) ON (STOCKTAKESHEETPARAMETERS.Stocktakekey = CCDETAIL.CCkey)   
   LEFT OUTER JOIN #TMP_RPTCFG RC           WITH (NOLOCK) ON (CCDETAIL.Storerkey = RC.Storerkey)
                                                          OR (LOC.Facility = RC.Storerkey)

   WHERE CCDETAIL.CCKey Between @c_CCkeyStart AND @c_CCkeyEnd
   AND   CCDETAIL.StorerKey Between @c_StorerKeyStart AND @c_StorerKeyEnd
   AND   CCDETAIL.SKU Between @c_SkuStart AND @c_SKUEnd
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   ISNULL(SKU.ItemClass, '') Between @c_ItemClassStart AND @c_ItemClassEnd
   AND   LOC.LOC Between @c_LOCStart AND @c_LOCEnd
   AND   LOC.PutawayZone Between @c_ZoneStart AND @c_ZoneEnd  
   AND   CCDETAIL.FinalizeFlag = @c_FinalizeFlag
   GROUP BY CCDETAIL.CCKey  
          , CCDETAIL.CCSheetNo   
          , CCDETAIL.Storerkey   
          , CCDETAIL.Sku   
          , CCDETAIL.Lot   
          , STOCKTAKESHEETPARAMETERS.WithQuantity 
          , CASE CCDETAIL.FinalizeFlag 
               WHEN 'N' THEN CCDETAIL.Lottable01 
               WHEN 'Y' THEN CASE @c_CountNo 
                             WHEN '1' THEN CCDETAIL.Lottable01
                             WHEN '2' THEN CCDETAIL.Lottable01_Cnt2
                             WHEN '3' THEN CCDETAIL.Lottable01_Cnt3
                             END
            END    
          , CASE CCDETAIL.FinalizeFlag 
               WHEN 'N' THEN CCDETAIL.Lottable02 
               WHEN 'Y' THEN CASE @c_CountNo 
                             WHEN '1' THEN CCDETAIL.Lottable02
                             WHEN '2' THEN CCDETAIL.Lottable02_Cnt2
                             WHEN '3' THEN CCDETAIL.Lottable02_Cnt3
                             END
            END   
          , CASE CCDETAIL.FinalizeFlag 
               WHEN 'N' THEN CCDETAIL.Lottable03 
               WHEN 'Y' THEN CASE @c_CountNo
                             WHEN '1' THEN CCDETAIL.Lottable03
                             WHEN '2' THEN CCDETAIL.Lottable03_Cnt2
                             WHEN '3' THEN CCDETAIL.Lottable03_Cnt3
                             END
            END   
          , CASE CCDETAIL.FinalizeFlag 
               WHEN 'N' THEN CCDETAIL.Lottable04 
               WHEN 'Y' THEN CASE @c_CountNo
                             WHEN '1' THEN CCDETAIL.Lottable04
                             WHEN '2' THEN CCDETAIL.Lottable04_Cnt2
                             WHEN '3' THEN CCDETAIL.Lottable04_Cnt3
                             END
            END   
          , PACK.PackKey   
          , PACK.CaseCnt   
          , PACK.InnerPack  
          , SKU.DESCR 
          , CCDETAIL.Lottable05  
          , CCDETAIL.FinalizeFlag   
          , LOC.Facility   
          , LOC.PutawayZone   
          , LOC.LocLevel   
          , STORER.Company  
          , LOC.CCLogicalLoc   
          , LOC.LocAisle   
          , LOC.Loc
          , CCDETAIL.Id
          ,CONVERT(VARCHAR(8),Pack.PALLETTI) + ' x ' + CONVERT(VARCHAR(8), Pack.PALLETHI) 
          , ISNULL(ShowPackTIHI,0) 
   ORDER BY CCDETAIL.CCSheetNo 




END

SET QUOTED_IDENTIFIER OFF 

GO