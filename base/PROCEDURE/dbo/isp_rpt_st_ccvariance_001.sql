SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_RPT_ST_CCVARIANCE_001                          */
/* Creation Date: 2023-01-26                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-21639 Migrate WMS report to Logi Report                  */
/*               r_stockcheck_variance (TH)                             */
/*                                                                      */
/* Input Parameters:  @c_QCKey  - QC Key                                */
/*                    @c_QCline_start  - QCline start                   */
/*                    @c_QCline_end    - QCline end                     */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage: RPT_ST_CCVARIANCE_001                                         */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 2023-01-26   CHONGCS 1.0   Devops Scripts Combine                    */
/* 18-Dec-2023  WLChooi 1.1   UWP-12105 - Global Timezone (GTZ01)       */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_ST_CCVARIANCE_001]
(
   @c_StockTakeKey   NVARCHAR(10)
 , @c_StorerKeyStart NVARCHAR(15)
 , @c_StorerKeyEnd   NVARCHAR(15)
 , @c_SKUStart       NVARCHAR(20)
 , @c_SKUEnd         NVARCHAR(20)
 , @c_locstart       NVARCHAR(10)
 , @c_locend         NVARCHAR(10)
 , @c_skuclassstart  NVARCHAR(10)
 , @c_skuclassend    NVARCHAR(10)
 , @c_zonestart      NVARCHAR(10)
 , @c_zoneend        NVARCHAR(10)
 , @c_sheetstart     NVARCHAR(10)
 , @c_sheetend       NVARCHAR(10)
 , @c_finalize       NVARCHAR(1)
 , @c_CountNo        NVARCHAR(2)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_Type       NVARCHAR(1)  = N'1'
         , @c_DataWindow NVARCHAR(60) = N'RPT_ST_CCVARIANCE_001'
         , @c_RetVal     NVARCHAR(255)


   SET @c_RetVal = N''

   IF ISNULL(@c_StorerKeyStart, '') <> ''
   BEGIN

      EXEC [dbo].[isp_GetCompanyInfo] @c_Storerkey = @c_StorerKeyStart
                                    , @c_Type = @c_Type
                                    , @c_DataWindow = @c_DataWindow
                                    , @c_RetVal = @c_RetVal OUTPUT

   END

   SELECT UPPER(CCDetail.Storerkey)
        , UPPER(CCDetail.Sku) AS sku
        , CountQty = CASE @c_CountNo
                          WHEN '1' THEN CCDetail.Qty
                          WHEN '2' THEN CCDetail.Qty_Cnt2
                          WHEN '3' THEN CCDetail.Qty_Cnt3
                          ELSE 0 END
        , QtyLOTxLOCxID = CCDetail.SystemQty
        , SKU.DESCR
        , SKU.PACKKey
        , CCDetail.CCSheetNo
        , CCDetail.Loc
        , variance = CASE @c_CountNo
                          WHEN '1' THEN CCDetail.Qty - CCDetail.SystemQty
                          WHEN '2' THEN CCDetail.Qty_Cnt2 - CCDetail.SystemQty
                          WHEN '3' THEN CCDetail.Qty_Cnt3 - CCDetail.SystemQty
                          ELSE 0 END
        , @c_StockTakeKey AS 'stocktakekey'
        , @c_StorerKeyStart AS 'storerstart'
        , @c_StorerKeyEnd AS 'storerend'
        , @c_SKUStart AS 'skustart'
        , @c_SKUEnd AS 'skuend'
        , @c_locstart AS 'locstart'
        , @c_locend AS 'locend'
        , @c_skuclassstart AS 'classstart'
        , @c_skuclassend AS 'classend'
        , @c_zonestart AS 'zonestart'
        , @c_zoneend AS 'zoneend'
        , @c_sheetstart AS 'sheetstart'
        , @c_sheetend AS 'sheetend'
        , @c_finalize AS 'finalize'
        , @c_CountNo AS 'countno'
        , CCDetail.Id
        , CCDetail.RefNo AS 'uccno'
        , ISNULL(@c_RetVal, '') AS Logo
        , [dbo].[fnc_ConvSFTimeZone](CCDetail.Storerkey, LOC.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM CCDetail (NOLOCK)
   JOIN SKU (NOLOCK) ON (SKU.Sku = CCDetail.Sku AND SKU.StorerKey = CCDetail.Storerkey)
   JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)
   JOIN LOC (NOLOCK) ON (CCDetail.Loc = LOC.Loc)
   WHERE (CCDetail.CCKey = @c_StockTakeKey)
   AND   (CCDetail.Storerkey >= @c_StorerKeyStart)
   AND   (CCDetail.Storerkey <= @c_StorerKeyEnd)
   AND   (CCDetail.Sku >= @c_SKUStart)
   AND   (CCDetail.Sku <= @c_SKUEnd)
   AND   (SKU.CLASS >= @c_skuclassstart)
   AND   (SKU.CLASS <= @c_skuclassend)
   AND   (LOC.PutawayZone >= @c_zonestart)
   AND   (LOC.PutawayZone <= @c_zoneend)
   AND   (CCDetail.Loc >= @c_locstart)
   AND   (CCDetail.Loc <= @c_locend)
   AND   (CCDetail.CCSheetNo >= @c_sheetstart)
   AND   (CCDetail.CCSheetNo <= @c_sheetend)
   AND   (  CCDetail.FinalizeFlag = @c_finalize
         OR CCDetail.FinalizeFlag_Cnt2 = @c_finalize
         OR CCDetail.FinalizeFlag_Cnt3 = @c_finalize)
   ORDER BY CCDetail.Storerkey
          , CCDetail.CCKey
          , CCDetail.Sku
          , CCDetail.Loc

END -- End Procedure

GO