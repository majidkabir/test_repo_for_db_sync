SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_ST_CCSHEET_012                                */
/* Creation Date:  17-Aug-2023                                             */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-23413 - [TW]PRT_LogiReport_CCSHEET_NEW                     */
/*                                                                         */
/* Called By: RPT_ST_CCSHEET_012                                           */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 17-Aug-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ST_CCSHEET_012]
(
   @c_CCkey_Start     NVARCHAR(20)
 , @c_CCkey_End       NVARCHAR(20)
 , @c_SKU_Start       NVARCHAR(20)
 , @c_SKU_End         NVARCHAR(20)
 , @c_ItemClass_Start NVARCHAR(20)
 , @c_ItemClass_End   NVARCHAR(20)
 , @c_StorerKey_Start NVARCHAR(20)
 , @c_StorerKey_End   NVARCHAR(20)
 , @c_LOC_Start       NVARCHAR(20)
 , @c_LOC_End         NVARCHAR(20)
 , @c_Zone_Start      NVARCHAR(20)
 , @c_Zone_End        NVARCHAR(20)
 , @c_CCSheetNo_Start NVARCHAR(20)
 , @c_CCSheetNo_End   NVARCHAR(20)
 , @c_WithQty         NVARCHAR(20)
 , @c_CountNo         NVARCHAR(20)
 , @c_FinalizeFlag    NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SQL       NVARCHAR(MAX) = ''
         , @c_Sorting   NVARCHAR(500) = ''
         , @c_Storerkey NVARCHAR(15) = ''

   CREATE TABLE #TMP_CC
   (
      [CCKey]        NVARCHAR(10)
    , [CCSheetNo]    NVARCHAR(10) NULL
    , [TagNo]        NVARCHAR(10) NULL
    , [Storerkey]    NVARCHAR(15) NULL
    , [Sku]          NVARCHAR(20) NULL
    , [Lot]          NVARCHAR(10) NULL
    , [Id]           NVARCHAR(18) NULL
    , [SystemQty]    INT NULL
    , [CountQty]     INT NULL
    , [Lottable01]   NVARCHAR(18) NULL
    , [Lottable02]   NVARCHAR(18) NULL
    , [Lottable03]   NVARCHAR(18) NULL
    , [Lottable04]   DATETIME NULL
    , [PackKey]      NVARCHAR(10) NULL
    , [CaseCnt]      FLOAT NULL
    , [InnerPack]    FLOAT NULL
    , [DESCR]        NVARCHAR(60) NULL
    , [CCDetailKey]  NVARCHAR(10) NULL
    , [Lottable05]   DATETIME NULL
    , [FinalizeFlag] NVARCHAR(1) NULL
    , [Facility]     NVARCHAR(5) NULL
    , [PutawayZone]  NVARCHAR(10) NULL
    , [LocLevel]     INT NULL
    , [Company]      NVARCHAR(45) NULL
    , [AreaKey]      NVARCHAR(10) NULL
    , [CCLogicalLoc] NVARCHAR(18) NULL
    , [LocAisle]     NVARCHAR(10) NULL
    , [Loc]          NVARCHAR(10) NULL
    , [CountNo]      NVARCHAR(20) NULL
   )

   INSERT INTO #TMP_CC (CCKey, CCSheetNo, TagNo, Storerkey, Sku, Lot, Id, SystemQty, CountQty, Lottable01, Lottable02
                      , Lottable03, Lottable04, PackKey, CaseCnt, InnerPack, DESCR, CCDetailKey, Lottable05, FinalizeFlag
                      , Facility, PutawayZone, LocLevel, Company, AreaKey, CCLogicalLoc, LocAisle, Loc, CountNo)
   SELECT CCDetail.CCKey
        , CCDetail.CCSheetNo
        , CCDetail.TagNo
        , CCDetail.Storerkey
        , CCDetail.Sku
        , CCDetail.Lot
        , CCDetail.Id
        , CCDetail.SystemQty
        , CASE @c_WithQty
               WHEN 'Y' THEN CASE CCDetail.FinalizeFlag
                                  WHEN 'N' THEN CCDetail.SystemQty
                                  WHEN 'Y' THEN CASE @c_CountNo
                                                     WHEN '1' THEN CCDetail.Qty
                                                     WHEN '2' THEN CCDetail.Qty_Cnt2
                                                     WHEN '3' THEN CCDetail.Qty_Cnt3
                                                     ELSE 0 END END
               ELSE 0 END AS CountQty
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable01
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable01
                                  WHEN '2' THEN CCDetail.Lottable01_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable01_Cnt3 END END AS Lottable01
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable02
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable02
                                  WHEN '2' THEN CCDetail.Lottable02_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable02_Cnt3 END END AS Lottable02
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable03
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable03
                                  WHEN '2' THEN CCDetail.Lottable03_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable03_Cnt3 END END AS Lottable03
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable04
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable04
                                  WHEN '2' THEN CCDetail.Lottable04_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable04_Cnt3 END END AS Lottable04
        , PACK.PackKey
        , PACK.CaseCnt
        , PACK.InnerPack
        , SKU.DESCR
        , CCDetail.CCDetailKey
        , CCDetail.Lottable05
        , CCDetail.FinalizeFlag
        , LOC.Facility
        , LOC.PutawayZone
        , LOC.LocLevel
        , STORER.Company
        , AreaDetail.AreaKey
        , LOC.CCLogicalLoc
        , LOC.LocAisle
        , LOC.Loc
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN '1'
               WHEN 'Y' THEN @c_CountNo END AS CountNo
   FROM CCDetail (NOLOCK)
   LEFT OUTER JOIN SKU (NOLOCK) ON (CCDetail.Storerkey = SKU.StorerKey AND CCDetail.Sku = SKU.Sku)
   LEFT OUTER JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
   JOIN LOC (NOLOCK) ON (CCDetail.Loc = LOC.Loc)
   LEFT JOIN STORER (NOLOCK) ON (STORER.StorerKey = SKU.StorerKey)
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutawayZone)
   WHERE CCDetail.CCKey BETWEEN @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.Storerkey BETWEEN @c_StorerKey_Start AND @c_StorerKey_End
   AND   CCDetail.Sku BETWEEN @c_SKU_Start AND @c_SKU_End
   AND   CCDetail.CCSheetNo BETWEEN @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   SKU.itemclass BETWEEN @c_ItemClass_Start AND @c_ItemClass_End
   AND   LOC.Loc BETWEEN @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone BETWEEN @c_Zone_Start AND @c_Zone_End
   AND   @c_FinalizeFlag = CASE @c_CountNo
                                WHEN '1' THEN CCDetail.FinalizeFlag
                                WHEN '2' THEN CCDetail.FinalizeFlag_Cnt2
                                WHEN '3' THEN CCDetail.FinalizeFlag_Cnt3 END
   AND   CCDetail.SystemQty > 0
   UNION
   SELECT CCDetail.CCKey
        , CCDetail.CCSheetNo
        , CCDetail.TagNo
        , CCDetail.Storerkey
        , CCDetail.Sku
        , CCDetail.Lot
        , CCDetail.Id
        , CCDetail.SystemQty
        , CASE @c_WithQty
               WHEN 'Y' THEN CASE CCDetail.FinalizeFlag
                                  WHEN 'N' THEN CCDetail.SystemQty
                                  WHEN 'Y' THEN CASE @c_CountNo
                                                     WHEN '1' THEN CCDetail.Qty
                                                     WHEN '2' THEN CCDetail.Qty_Cnt2
                                                     WHEN '3' THEN CCDetail.Qty_Cnt3
                                                     ELSE 0 END END
               ELSE 0 END AS CountQty
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable01
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable01
                                  WHEN '2' THEN CCDetail.Lottable01_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable01_Cnt3 END END AS Lottable01
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable02
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable02
                                  WHEN '2' THEN CCDetail.Lottable02_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable02_Cnt3 END END AS Lottable02
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable03
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable03
                                  WHEN '2' THEN CCDetail.Lottable03_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable03_Cnt3 END END AS Lottable03
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN CCDetail.Lottable04
               WHEN 'Y' THEN CASE @c_CountNo
                                  WHEN '1' THEN CCDetail.Lottable04
                                  WHEN '2' THEN CCDetail.Lottable04_Cnt2
                                  WHEN '3' THEN CCDetail.Lottable04_Cnt3 END END AS Lottable04
        , '' AS Packkey
        , '' AS CaseCnt
        , '' AS InnerPack
        , SKU.DESCR AS DESCR
        , CCDetail.CCDetailKey
        , CCDetail.Lottable05
        , CCDetail.FinalizeFlag
        , LOC.Facility
        , LOC.PutawayZone
        , LOC.LocLevel
        , '' AS Company
        , AreaDetail.AreaKey
        , LOC.CCLogicalLoc
        , LOC.LocAisle
        , LOC.Loc
        , CASE CCDetail.FinalizeFlag
               WHEN 'N' THEN '1'
               WHEN 'Y' THEN @c_CountNo END AS CountNo
   FROM CCDetail (NOLOCK)
   LEFT OUTER JOIN SKU (NOLOCK) ON (CCDetail.Storerkey = SKU.StorerKey AND CCDetail.Sku = SKU.Sku)
   JOIN LOC (NOLOCK) ON (CCDetail.Loc = LOC.Loc)
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutawayZone)
   WHERE CCDetail.CCKey BETWEEN @c_CCkey_Start AND @c_CCkey_End
   AND   CCDetail.CCSheetNo BETWEEN @c_CCSheetNo_Start AND @c_CCSheetNo_End
   AND   LOC.Loc BETWEEN @c_LOC_Start AND @c_LOC_End
   AND   LOC.PutawayZone BETWEEN @c_Zone_Start AND @c_Zone_End
   AND   @c_FinalizeFlag = CASE @c_CountNo
                                WHEN '1' THEN CCDetail.FinalizeFlag
                                WHEN '2' THEN CCDetail.FinalizeFlag_Cnt2
                                WHEN '3' THEN CCDetail.FinalizeFlag_Cnt3 END
   AND   CCDetail.SystemQty = 0
   ORDER BY CCDetail.CCSheetNo
          , CCDetail.TagNo
          , LOC.LocAisle
          , LOC.LocLevel
          , LOC.CCLogicalLoc
          , LOC.Loc
          , CCDetail.Sku

   SELECT @c_Storerkey = TC.Storerkey
   FROM #TMP_CC TC

   SELECT @c_Sorting = ISNULL(CL.Notes,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Long = 'RPT_ST_CCSHEET_012'
   AND CL.Code = 'RPTSORT'
   AND CL.Short = 'Y'

   IF ISNULL(@c_Sorting,'') = ''
   BEGIN
      SET @c_Sorting = 'CCSheetNo, TagNo, LocAisle, LocLevel, CCLogicalLoc, Loc, Sku'
   END

   SET @c_SQL = ' SELECT * FROM #TMP_CC ORDER BY '
   SET @c_SQL = @c_SQL + ' ' + @c_Sorting

   EXEC sp_ExecuteSql @c_SQL   

   IF OBJECT_ID('tempdb..#TMP_CC') IS NOT NULL
      DROP TABLE #TMP_CC
END

GO