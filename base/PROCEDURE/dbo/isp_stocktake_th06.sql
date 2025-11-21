SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_stocktake_TH06                                 */
/* Creation Date: 28-Apr-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-16898: TH-IDSMED CR-Count Sheet Report                 */
/*                                                                      */
/* Input Parameters:                                                    */                                     
/*                                                                      */
/* Called By:  dw = r_dw_stocktake_TH06_1                               */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_stocktake_TH06] (
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
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT     INT
         , @n_StartTCnt INT

   SET @n_IsRDT     = 0
   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

 SELECT CCDetail.CCKey AS cckey,   
         CCDetail.CCSheetNo AS CCSheetNo,   
         CCDetail.TagNo AS Tagno,   
         CCDetail.Storerkey AS storerkey,   
         CCDetail.Sku AS sku,   
         CCDetail.Lot AS Lot,   
         CCDetail.Id AS ID,   
         CCDetail.SystemQty AS systemqty,   
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
         PACK.PackKey AS PackKey,   
         PACK.CaseCnt AS CaseCnt,   
         PACK.InnerPack AS InnerPack,   
         SKU.DESCR AS  DESCR,   
         CCDetail.CCDetailKey AS CCDetailKey,   
         CCDetail.Lottable05 AS Lottable05,   
         CCDetail.FinalizeFlag AS FinalizeFlag,   
         LOC.Facility AS Facility,   
         LOC.PutawayZone AS PutawayZone,   
         LOC.LocLevel AS LocLevel,   
         STORER.Company AS Company,   
         AreaDetail.AreaKey AS AreaKey,   
         LOC.CCLogicalLoc AS CCLogicalLoc,   
         LOC.LocAisle AS LocAisle,   
         LOC.Loc AS Loc,  
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN '1'
            WHEN 'Y' THEN @c_CountNo 
         END AS CountNo,
       LTRIM(CCDetail.Lottable08)  +  LTRIM(CCDetail.Lottable09) As BatchNo, 
       LTRIM(CCDetail.Lottable10)  +  LTRIM(CCDetail.Lottable11) As SerialNo,
       LTRIM(CCDetail.Lottable12) As LOTT12    
    FROM CCDetail (NOLOCK)   
         LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )   
         LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCKeyStart AND @c_CCKeyEnd
   AND   CCDetail.StorerKey Between @c_StorerKeyStart AND @c_StorerKeyEnd
   AND   CCDetail.SKU Between @c_SKUStart AND @c_SKUEnd
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   SKU.ItemClass Between @c_ItemClassStart AND @c_ItemClassEnd
   AND   LOC.LOC Between @c_LOCStart AND @c_LOCEnd
   AND   LOC.PutawayZone Between @c_ZoneStart AND @c_ZoneEnd  
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                            END
   AND   CCDETAIL.SystemQty > 0
  UNION
  SELECT CCDetail.CCKey AS cckey,   
         CCDetail.CCSheetNo AS CCSheetNo,   
         CCDetail.TagNo AS Tagno,   
         CCDetail.Storerkey AS storerkey,   
         CCDetail.Sku AS sku,   
         CCDetail.Lot AS Lot,   
         CCDetail.Id AS ID,   
         CCDetail.SystemQty AS systemqty,   
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
         '' As CaseCnt,    
         '' As InnerPack,   
         SKU.DESCR As DESCR,   
         CCDetail.CCDetailKey AS CCDetailKey,   
         CCDetail.Lottable05 AS Lottable05,   
         CCDetail.FinalizeFlag AS FinalizeFlag,   
         LOC.Facility AS Facility,   
         LOC.PutawayZone AS PutawayZone,   
         LOC.LocLevel AS LocLevel,   
         '' As Company,   
         AreaDetail.AreaKey AS AreaKey,   
         LOC.CCLogicalLoc AS CCLogicalLoc,   
         LOC.LocAisle AS LocAisle,   
         LOC.Loc AS Loc,  
         CASE CCDetail.FinalizeFlag 
            WHEN 'N' THEN '1'
            WHEN 'Y' THEN @c_CountNo 
         END AS CountNo,
        LTRIM(CCDetail.Lottable08)  +  LTRIM(CCDetail.Lottable09) As BatchNo, 
        LTRIM(CCDetail.Lottable10)  +  LTRIM(CCDetail.Lottable11) As SerialNo,
        LTRIM(CCDetail.Lottable12) As LOTT12    
    FROM CCDetail (NOLOCK) 
         LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
  
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDetail.CCKey Between @c_CCKeyStart AND @c_CCKeyEnd
   AND   CCDETAIL.CCSheetNo Between @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   LOC.LOC Between @c_LOCStart AND @c_LOCEnd
   AND   LOC.PutawayZone Between @c_ZoneStart AND @c_ZoneEnd  
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                            END
   AND   CCDETAIL.SystemQty = 0
   ORDER BY CCDetail.CCSheetNo 

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO