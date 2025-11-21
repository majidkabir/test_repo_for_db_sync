SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_Stocktake_TH07                                  */
/* Creation Date: 29-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18636 - TH ADIDAS Stock Take Report                     */                          
/*                                                                      */
/* Called By: r_dw_stocktake_th07                                       */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Dec-2021  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE PROC [dbo].[isp_Stocktake_TH07] (
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
   
   DECLARE @n_StartTCnt INT
   
   SET @n_StartTCnt = @@TRANCOUNT
   
   
   SELECT CCDETAIL.CCKey
        , CONVERT(NVARCHAR(10), GETDATE(), 103) AS PrintDate
        , CCDETAIL.CCSheetNo
        , CCDETAIL.Loc
   FROM CCDETAIL (NOLOCK)   
   LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDETAIL.Storerkey = SKU.StorerKey AND CCDETAIL.Sku = SKU.Sku )
   LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
   JOIN LOC (NOLOCK) ON ( CCDETAIL.Loc = LOC.Loc ) 
   LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )   
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDETAIL.CCKey BETWEEN @c_CCKeyStart AND @c_CCKeyEnd
   AND   CCDETAIL.StorerKey BETWEEN @c_StorerKeyStart AND @c_StorerKeyEnd
   AND   CCDETAIL.SKU BETWEEN @c_SKUStart AND @c_SKUEnd
   AND   CCDETAIL.CCSheetNo BETWEEN @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   SKU.ItemClass BETWEEN @c_ItemClassStart AND @c_ItemClassEnd
   AND   LOC.LOC BETWEEN @c_LOCStart AND @c_LOCEnd
   AND   LOC.PutawayZone BETWEEN @c_ZoneStart AND @c_ZoneEnd  
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                           END
   AND   CCDETAIL.SystemQty > 0
   UNION
   SELECT CCDETAIL.CCKey
        , CONVERT(NVARCHAR(10), GETDATE(), 103) AS PrintDate
        , CCDETAIL.CCSheetNo
        , CCDETAIL.Loc
   FROM CCDETAIL (NOLOCK)   
   LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDETAIL.Storerkey = SKU.StorerKey AND CCDETAIL.Sku = SKU.Sku )
   LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey ) 
   JOIN LOC (NOLOCK) ON ( CCDETAIL.Loc = LOC.Loc ) 
   LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )   
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone ) 
   WHERE CCDETAIL.CCKey BETWEEN @c_CCKeyStart AND @c_CCKeyEnd
   AND   CCDETAIL.CCSheetNo BETWEEN @c_CCSheetNoStart AND @c_CCSheetNoEnd
   AND   LOC.LOC BETWEEN @c_LOCStart AND @c_LOCEnd
   AND   LOC.PutawayZone BETWEEN @c_ZoneStart AND @c_ZoneEnd  
   AND   @c_FinalizeFlag = CASE @c_CountNo
                              WHEN '1' THEN CCDETAIL.FinalizeFlag
                              WHEN '2' THEN CCDETAIL.FinalizeFlag_Cnt2
                              WHEN '3' THEN CCDETAIL.FinalizeFlag_Cnt3
                           END
   AND   CCDETAIL.SystemQty = 0
   ORDER BY CCDETAIL.CCSheetNo, CCDETAIL.Loc
   
END

GO