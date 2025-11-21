SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_ST_CCSHEET_011                             */        
/* CreatiON Date: 04-JUL-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-22927 (PH)                                              */      
/*                                                                      */        
/* Called By: RPT_ST_CCSHEET_011             									*/        
/*                                                                      */        
/* PVCS VersiON: 1.1                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 04-JUL-2023  WZPang   1.0  DevOps Combine Script                     */
/* 01-Apr-2024  WLChooi  1.1  UWP-17600 - Add CCRef Barcode (WL01)      */
/* 07-May-2024  WLChooi  1.2  Global Timezone (SD01)                    */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_ST_CCSHEET_011] (
        @c_CCkey_Start     NVARCHAR (20)
     ,  @c_CCkey_End       NVARCHAR (20)
     ,  @c_SKU_Start       NVARCHAR (20)
     ,  @c_SKU_End         NVARCHAR (20)
     ,  @c_ItemClass_Start NVARCHAR (20)
     ,  @c_ItemClass_End   NVARCHAR (20)
     ,  @c_StorerKey_Start NVARCHAR (20)
     ,  @c_StorerKey_End   NVARCHAR (20)
     ,  @c_LOC_Start       NVARCHAR (20)
     ,  @c_LOC_End         NVARCHAR (20)
     ,  @c_Zone_Start      NVARCHAR (20)
     ,  @c_Zone_End        NVARCHAR (20)
     ,  @c_CCSheetNo_Start NVARCHAR (20)
     ,  @c_CCSheetNo_End   NVARCHAR (20)
     ,  @c_WithQty         NVARCHAR (20)
     --,  @c_Type            NVARCHAR (10) = '' 
     ,  @c_CountNo         NVARCHAR (20)
     ,  @c_FinalizeFlag    NVARCHAR (20)     
)        
   AS        
   BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

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
         [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable05) AS Lottable05,   --SD01
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
		 [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, GETDATE()) AS CurrentDateTime,   --SD01
         ShowCCRefBarcode = ISNULL(CL1.Short, 'N')   --WL01
    FROM CCDetail (NOLOCK)   
         LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )
         LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )   
         LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
			LEFT OUTER JOIN CODELKUP (NOLOCK) ON ( SKU.SKUGROUP = CODELKUP.CODE AND CODELKUP.LISTNAME='SKUGROUP' and CODELKUP.short ='CBA' and CODELKUP.long ='CL') 
			LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON ( CL1.LISTNAME = 'REPORTCFG' 
                                                AND CL1.Code = 'ShowCCRefBarcode' 
                                                AND CL1.Storerkey = CCDETAIL.Storerkey 
                                                AND CL1.Long = 'RPT_ST_CCSHEET_011'
                                                AND CL1.Short = 'Y' )   --WL01 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End 
	AND   CCDetail.StorerKey Between @c_StorerKey_Start AND @c_StorerKey_End
	AND   CCDetail.SKU Between @c_SKU_Start AND @c_SKU_End
	AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
	AND   ISNULL(SKU.ItemClass,'') Between @c_ItemClass_Start AND @c_ItemClass_End
	AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
	AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
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
         [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, CCDetail.Lottable05) AS Lottable05,   --SD01   
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
		 [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, GETDATE()) AS CurrentDateTime,   --SD01
         ShowCCRefBarcode = ISNULL(CL1.Short, 'N')   --WL01
    FROM CCDetail (NOLOCK)   
         JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc ) 
         LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
         LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON ( CL1.LISTNAME = 'REPORTCFG' 
                                                AND CL1.Code = 'ShowCCRefBarcode' 
                                                AND CL1.Storerkey = CCDETAIL.Storerkey 
                                                AND CL1.Long = 'RPT_ST_CCSHEET_011'
                                                AND CL1.Short = 'Y' )   --WL01 
   WHERE CCDetail.CCKey Between @c_CCkey_Start AND @c_CCKey_End
	AND   CCDETAIL.CCSheetNo Between @c_CCSheetNo_Start AND @c_CCSheetNo_End
	AND   LOC.LOC Between @c_LOC_Start AND @c_LOC_End
	AND   LOC.PutawayZone Between @c_Zone_Start AND @c_Zone_End  
	AND	@c_FinalizeFlag = CASE @c_CountNo
										WHEN '1' THEN CCDETAIL.FinalizeFlag
										WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
										WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
									 END
	AND   CCDETAIL.SystemQty = 0
	ORDER BY CCDetail.CCSheetNo, CCDETAIL.CCDetailKey 
         

END -- procedure    

GO