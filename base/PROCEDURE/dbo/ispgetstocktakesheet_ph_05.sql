SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/************************************************************************/        
/* Stored Procedure: ispGetStockTakeSheet_PH_05                         */        
/* Creation Date: 15-JUL-2019                                           */        
/* Copyright: IDS                                                       */        
/* Written by: CSCHONG                                                  */        
/*                                                                      */        
/* Purpose: WMS-9856 - [PH] Unilever - Stock Take Count Sheet           */        
/*                                                                      */       
/* Input Parameters:  @c_CCkey_Start      , @c_CCkey_End                */      
/*                   ,@c_SKU_Start        , @c_SKU_End                  */        
/*                   ,@c_ItemClass_Start  , @c_ItemClass_End            */      
/*                   ,@c_StorerKey_Start  , @c_StorerKey_End            */      
/*                   ,@c_LOC_Start        , @c_LOC_End                  */      
/*                   ,@c_Zone_Start       , @c_Zone_End                 */      
/*                   ,@c_CCSheetNo_Start  , @c_CCSheetNo_End            */      
/*                   ,@c_WithQty                                        */      
/*                   ,@c_CountNo                                        */      
/*                   ,@c_FinalizeFlag                                   */      
/*                                                                      */      
/* Output Parameters:  None                                             */      
/*                                                                      */      
/* Return Status:  None                                                 */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Local Variables:                                                     */      
/*                                                                      */       
/* Called By: r_dw_stocktake_ph_05                                      */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */        
/* 19/12/2019   WLChooi  1.1  WMS-11367 - Modify to support calling     */
/*                            main and subdatawindow (WL01)             */
/************************************************************************/        
      
CREATE PROC [dbo].[ispGetStockTakeSheet_PH_05]      
    @c_CCkey_Start      NVARCHAR(10), @c_CCkey_End     NVARCHAR(10)          
   ,@c_SKU_Start        NVARCHAR(20), @c_SKU_End       NVARCHAR(20)      
   ,@c_ItemClass_Start  NVARCHAR(10), @c_ItemClass_End NVARCHAR(10)      
   ,@c_StorerKey_Start  NVARCHAR(15), @c_StorerKey_End NVARCHAR(15)      
   ,@c_LOC_Start        NVARCHAR(10), @c_LOC_End       NVARCHAR(10)      
   ,@c_Zone_Start       NVARCHAR(10), @c_Zone_End      NVARCHAR(10)      
   ,@c_CCSheetNo_Start  NVARCHAR(10), @c_CCSheetNo_End NVARCHAR(10)      
   ,@c_WithQty          NVARCHAR(10)       
   ,@c_CountNo          NVARCHAR(10)      
   ,@c_FinalizeFlag     NVARCHAR(10)
   ,@c_Type             NVARCHAR(10) = ''      --WL01
      
AS      
BEGIN      
   SET NOCOUNT ON       -- SQL 2005 Standard      
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF         
   SET CONCAT_NULL_YIELDS_NULL OFF         
      
   DECLARE @n_Continue  INT      
         , @n_Err       INT      
         , @b_Success   INT      
         , @c_ErrMsg    NVARCHAR(255)      
      
   DECLARE @c_Storerkey NVARCHAR(15)      
         , @c_Configkey NVARCHAR(30)      
         , @c_SValue    NVARCHAR(10)      
      
   SET @n_Continue = 1      
   SET @n_Err      = 0      
   SET @b_Success  = 1      
   SET @c_ErrMsg   = ''      
   
   --WL01 Start
   IF @c_Type = 'H1'  
   BEGIN  
      SELECT @c_CCkey_Start     , @c_CCkey_End      
            ,@c_SKU_Start       , @c_SKU_End         
            ,@c_ItemClass_Start , @c_ItemClass_End   
            ,@c_StorerKey_Start , @c_StorerKey_End   
            ,@c_LOC_Start       , @c_LOC_End         
            ,@c_Zone_Start      , @c_Zone_End        
            ,@c_CCSheetNo_Start , @c_CCSheetNo_End   
            ,@c_WithQty                
            ,@c_CountNo               
            ,@c_FinalizeFlag      
      GOTO QUIT  
   END      
   --WL01 End
       
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
   END AS CountNo,      
         PACK.PalletTI,      
         PACK.PalletHI,      
         LOC.LOCBAY AS LOCBAY,      
 LOTT.Lottable13 AS LOTT13           
    FROM CCDetail (NOLOCK)         
         LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )      
         LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey )       
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )       
         LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )         
         LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone )       
         LEFT JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.LOT = CCDetail.Lot      
   LEFT OUTER JOIN CODELKUP (NOLOCK) ON ( SKU.SKUGROUP = CODELKUP.CODE AND CODELKUP.LISTNAME='SKUGROUP' and CODELKUP.short ='CBA' and CODELKUP.long ='CL')       
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End      
 AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End      
AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End      
 AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End      
 AND   ISNULL(SKU.ItemClass,'') Between @c_ItemClass_Start AND @c_ItemClass_End      
 AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End      
 AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End        
 AND @c_FinalizeFlag = CASE @c_CountNo      
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
   END AS CountNo,          
         0 AS PalletTI,       
         0 AS PalletHI,      
         LOC.LOCBAY AS LOCBAY,      
   LOTT.Lottable13 AS LOTT13            
    FROM CCDetail (NOLOCK)         
   JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )       
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone )       
   LEFT JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.LOT = CCDetail.Lot      
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
 ORDER BY CCDetail.CCDetailKey      
         
      
      
   QUIT:      
            
END 

GO