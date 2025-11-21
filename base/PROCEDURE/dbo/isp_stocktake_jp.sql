SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_Stocktake_JP                                       */
/* Creation Date: 28-APR-2020                                              */
/* Copyright: LF                                                           */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose:  WMS-13151 - Japan Cycle Count Sheet                           */
/*                                                                         */
/* Called By: PB: r_dw_stocktake_jp                                        */
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

CREATE PROC [dbo].[isp_Stocktake_JP]
           @c_CCKeyStart      NVARCHAR(10) 
         , @c_CCKeyEnd        NVARCHAR(10)
         , @c_SkuStart        NVARCHAR(20)
         , @c_SkuEnd          NVARCHAR(20)
         , @c_ItemClassStart  NVARCHAR(20)
         , @c_ItemClassEnd    NVARCHAR(20)
         , @c_StorerkeyStart  NVARCHAR(15)
         , @c_StorerkeyEnd    NVARCHAR(15)
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

   SELECT CCDetail.CCKey,   
          CCDetail.CCSheetNo,   
          CCDetail.TagNo,   
          CCDetail.Storerkey,   
          CCDetail.Sku,     
          CCDetail.Lot,   
          CCDetail.Id,   
          CCDetail.SystemQty,   
          CASE @c_WithQty 
            WHEN 'Y' Then 
               CASE CCDetail.FinalizeFlag 
                  WHEN 'N' THEN CCDetail.SystemQty 
                  WHEN 'Y' THEN CASE @c_CountNo 
                                    WHEN '1' THEN CCDetail.Qty
                                    WHEN '2' THEN CCDETAIL.Qty_Cnt2
                                    WHEN '3' THEN CCDETAIL.Qty_CNt3
                                    ELSE 0 
                                 END
               END 
            ELSE
               0
            END AS CountQty,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable01 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable01
                              WHEN '2' THEN CCDetail.Lottable01_Cnt2
                              WHEN '3' THEN CCDetail.Lottable01_Cnt3
                           END
            END As Lottable01,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable02 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable02
                              WHEN '2' THEN CCDetail.Lottable02_Cnt2
                              WHEN '3' THEN CCDetail.Lottable02_Cnt3
								  END
          END As Lottable02,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable03 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable03
                              WHEN '2' THEN CCDetail.Lottable03_Cnt2
                              WHEN '3' THEN CCDetail.Lottable03_Cnt3
								  END
          END As Lottable03,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable04 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable04
                              WHEN '2' THEN CCDetail.Lottable04_Cnt2
                              WHEN '3' THEN CCDetail.Lottable04_Cnt3
								  END
         END As Lottable04,   
         PACK.PackKey,   
         PACK.Pallet,  
         PACK.CaseCnt,  
         PACK.InnerPack,   
         SKU.DESCR, 
         ISNULL(RTRIM(SKU.Busr8),'') AS Busr8,   
         ISNULL(SKU.Busr9,'') AS Busr9,   
         ISNULL(SKU.Color,'') AS Color,   
         ISNULL(SKU.Busr10,'') AS Busr10,    
         ISNULL(CODELKUP.LISTNAME,'') AS Listname, 
         ISNULL(SKU.SkuGroup,'') AS SkuGroup, 
         CCDetail.CCDetailKey,   
         CCDetail.Lottable05,   
         CCDetail.FinalizeFlag,   
         LOC.Facility,   
         LOC.PutawayZone,   
         LOC.LocLevel,   
         STORER.Company,   
         AreaDetail.AreaKey,   
         LOC.CCLogicalLoc,   
         LOC.LocAisle,   
         LOC.Loc,  
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN '1'
            WHEN 'Y' THEN @c_CountNo 
         END AS CountNo    
   FROM CCDetail (NOLOCK)   
   LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
   LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
   JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
   LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )   
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   LEFT OUTER JOIN CODELKUP (NOLOCK) ON ( SKU.SKUGROUP = CODELKUP.CODE AND CODELKUP.LISTNAME='SKUGROUP' and CODELKUP.short ='CBA' and CODELKUP.long ='CL') 
   WHERE CCDetail.CCKey Between @c_CCKeyStart AND @c_CCKeyEnd
   AND   CCDetail.StorerKey Between @c_StorerkeyStart AND @c_StorerkeyEnd
   AND   CCDetail.SKU Between @c_SKUStart AND @c_SKUEnd
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   ISNULL(SKU.ItemClass,'') Between @c_ItemClassStart AND @c_ItemClassEnd
   AND   LOC.LOC Between @c_LocStart AND @c_LocEnd
   AND   LOC.PutawayZone Between @c_ZoneStart AND @c_ZoneEnd  
   AND	@c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                            END
	AND   CCDETAIL.SystemQty > 0
   UNION
   SELECT CCDetail.CCKey,   
          CCDetail.CCSheetNo,   
          CCDetail.TagNo,   
          CCDetail.Storerkey,   
          CCDetail.Sku,   
          CCDetail.Lot,   
          CCDetail.Id,   
          CCDetail.SystemQty,   
          CASE @c_WithQty 
          WHEN 'Y' Then 
            CASE CCDetail.FinalizeFlag 
               WHEN 'N' THEN CCDetail.SystemQty 
               WHEN 'Y' THEN CASE @c_CountNo 
                                    WHEN '1' THEN CCDetail.Qty
                                    WHEN '2' THEN CCDETAIL.Qty_Cnt2
                                    WHEN '3' THEN CCDETAIL.Qty_CNt3
                                    ELSE 0
   									  END
               END 
            ELSE
               0
            END AS CountQty,    
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable01 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable01
                              WHEN '2' THEN CCDetail.Lottable01_Cnt2
                              WHEN '3' THEN CCDetail.Lottable01_Cnt3
                           END
          END As Lottable01,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable02 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable02
                              WHEN '2' THEN CCDetail.Lottable02_Cnt2
                              WHEN '3' THEN CCDetail.Lottable02_Cnt3
   							  END
          END As Lottable02,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable03 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable03
                              WHEN '2' THEN CCDetail.Lottable03_Cnt2
                              WHEN '3' THEN CCDetail.Lottable03_Cnt3
   							  END
          END As Lottable03,   
          CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN CCDetail.Lottable04 
            WHEN 'Y' THEN CASE @c_CountNo 
                              WHEN '1' THEN CCDetail.Lottable04
                              WHEN '2' THEN CCDetail.Lottable04_Cnt2
                              WHEN '3' THEN CCDetail.Lottable04_Cnt3
                           END
         END As Lottable04,   
         '' As Packkey,   
         '' As Pallet,   
         '' As CaseCnt,   
         '' As InnerPack,   
         '' As DESCR,
         '' As Busr8,
         '' As Busr9,
         '' As Color,
         '' As Busr10,
         '' As Listname,
         '' As SkuGroup,
         CCDetail.CCDetailKey,   
         CCDetail.Lottable05,   
         CCDetail.FinalizeFlag,   
         LOC.Facility,   
         LOC.PutawayZone,   
         LOC.LocLevel,   
         '' As Company,   
         AreaDetail.AreaKey,   
         LOC.CCLogicalLoc,   
         LOC.LocAisle,   
         LOC.Loc,  
         CASE CCDetail.FinalizeFlag 
         	WHEN 'N' THEN '1'
         	WHEN 'Y' THEN @c_CountNo 
         END AS CountNo    
   FROM CCDetail (NOLOCK)   
   JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCKeyStart AND @c_CCKeyEnd
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   LOC.LOC Between @c_LocStart AND @c_LocEnd
   AND   LOC.PutawayZone Between @c_ZoneStart AND @c_ZoneEnd  
   AND	@c_FinalizeFlag = CASE @c_CountNo
                               WHEN '1' THEN CCDETAIL.FinalizeFlag
                               WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                               WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                            END
   AND   CCDETAIL.SystemQty = 0
   ORDER BY CCDetail.CCSheetNo, LOC.Loc, CCDetail.ID

END

SET QUOTED_IDENTIFIER OFF 

GO