SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_ST_CCSHEET_001                              */
/* Creation Date: 31-05-2021                                             */
/* Copyright: LFL                                                        */
/* Written by: EnTong                                                    */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* GitLab Version: 1.1                                                   */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 31-05-2021  EnTong   1.0   DevOps Combine Script                      */
/* 31-Oct-2023 WLChooi  1.1   UWP-10213 - Global Timezone (GTZ01)        */
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ST_CCSHEET_001]
   @c_CCkey_Start NVARCHAR (20)
,  @c_CCkey_End NVARCHAR (20)
,  @c_SKU_Start NVARCHAR (20)
,  @c_SKU_End NVARCHAR (20)
,  @c_ItemClass_Start NVARCHAR (20)
,  @c_ItemClass_End NVARCHAR (20)
,  @c_StorerKey_Start NVARCHAR (20)
,  @c_StorerKey_End NVARCHAR (20)
,  @c_LOC_Start NVARCHAR (20)
,  @c_LOC_End NVARCHAR (20)
,  @c_Zone_Start NVARCHAR (20)
,  @c_Zone_End NVARCHAR (20)
,  @c_CCSheetNo_Start NVARCHAR (20)
,  @c_CCSheetNo_End NVARCHAR (20)
,  @c_WithQty NVARCHAR (20)
,  @c_CountNo NVARCHAR (20)
,  @c_FinalizeFlag NVARCHAR(20)
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
                  WHEN 'Y' THEN
                  CASE @c_CountNo
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
            WHEN 'Y' THEN
            CASE @c_CountNo
               WHEN '1' THEN CCDetail.Lottable01
               WHEN '2' THEN CCDetail.Lottable01_Cnt2
               WHEN '3' THEN CCDetail.Lottable01_Cnt3
            END
         END As Lottable01,
         CASE CCDetail.FinalizeFlag
            WHEN 'N' THEN CCDetail.Lottable02
            WHEN 'Y' THEN
            CASE @c_CountNo
               WHEN '1' THEN CCDetail.Lottable02
               WHEN '2' THEN CCDetail.Lottable02_Cnt2
               WHEN '3' THEN CCDetail.Lottable02_Cnt3
            END
         END As Lottable02,
         CASE CCDetail.FinalizeFlag
            WHEN 'N' THEN CCDetail.Lottable03
            WHEN 'Y' THEN
            CASE @c_CountNo
               WHEN '1' THEN CCDetail.Lottable03
               WHEN '2' THEN CCDetail.Lottable03_Cnt2
               WHEN '3' THEN CCDetail.Lottable03_Cnt3
            END
         END As Lottable03,
         CASE CCDetail.FinalizeFlag
            WHEN 'N' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04)   --GTZ01
            WHEN 'Y' THEN
            CASE @c_CountNo
               WHEN '1' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04)        --GTZ01
               WHEN '2' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04_Cnt2)   --GTZ01
               WHEN '3' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04_Cnt3)   --GTZ01
            END
         END As Lottable04,
         PACK.PackKey,
         PACK.CaseCnt,
         PACK.InnerPack,
         SKU.DESCR,
         CCDetail.CCDetailKey,
         [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable05) AS Lottable05,   --GTZ01
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
         END AS CountNo,
         [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM CCDetail (NOLOCK)
   LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
   LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey )
   JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )
   LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone )
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End
   AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.ItemClass Between @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End
   AND   @c_FinalizeFlag = CASE @c_CountNo
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
            WHEN 'N' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04)   --GTZ01
            WHEN 'Y' THEN CASE @c_CountNo
                              WHEN '1' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04)        --GTZ01
                              WHEN '2' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04_Cnt2)   --GTZ01
                              WHEN '3' THEN [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable04_Cnt3)   --GTZ01
                           END
         END As Lottable04,
         '' As Packkey,
         '' As CaseCnt,
         '' As InnerPack,
         SKU.DESCR As DESCR,
         CCDetail.CCDetailKey,
         [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable05) AS Lottable05,   --GTZ01
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
         END AS CountNo,
         [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM CCDetail (NOLOCK)
   LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
   JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone )
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                           END
   AND   CCDETAIL.SystemQty = 0
   ORDER BY LOC.Loc, CCDetail.CCSheetNo

END

GO