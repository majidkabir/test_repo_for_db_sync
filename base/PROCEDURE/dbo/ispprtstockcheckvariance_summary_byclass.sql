SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* StoredProc: ispPrtStockCheckVariance_Summary_byClass                 */
/* Creation Date: 2021-11-16                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18337 - PH UNILEVER STOCK TAKE VARIANCE REPORT -        */
/*          BY CLASSIFICATION                                           */
/*                                                                      */
/* Called By: r_dw_stocktake_variance_summary_byclass                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 2021-11-16   WLChooi 1.0   DevOps Combine Script                     */
/* 2021-12-20   WLChooi 1.1   Fix - Convert SystemQty to Casecnt (WL01) */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispPrtStockCheckVariance_Summary_byClass] (
         @c_StockTakeKey   NVARCHAR(10),
         @c_StorerKeyStart NVARCHAR(15),
         @c_StorerKeyEnd   NVARCHAR(15),
         @c_SkuStart       NVARCHAR(20),
         @c_SkuEnd         NVARCHAR(20),
         @c_CountNo        NVARCHAR(2)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL 
      DROP TABLE #TempStkVar

   CREATE TABLE [#TempStkVar] (
         [RowID]          [INT] NOT NULL IDENTITY(1,1) PRIMARY KEY,
         [StorerKey]      [NVARCHAR] (10),  
         [CCKey]          [NVARCHAR] (10),  
         [Sku]            [NVARCHAR] (20),      
         [Descr]          [NVARCHAR] (60) NULL,  
         [SUSR3]          [NVARCHAR] (18) NULL,  
         [Qty]            [INT],   
         [Qty_Cnt2]       [INT],   
         [Qty_Cnt3]       [INT],   
         [PackUOM]        [NVARCHAR] (10) NULL,   
         [LotxLocxId_Qty] [INT],   
         [VarQty_cal]     [INT],
         [Class]          [NVARCHAR] (50) NULL,  
      )

   INSERT INTO #TempStkVar 
   (StorerKey,   CCKey,      Sku,        Descr,            Qty,         
    Qty_Cnt2,    Qty_Cnt3,   PackUOM,   LotxLocxId_Qty,   VarQty_cal,
    Class
   )
   SELECT TRIM(CCDetail.StorerKey),  
          CCDetail.CCKey,  
          TRIM(CCDetail.Sku),   
          SKU.Descr,   
          CASE WHEN ISNULL(PACK.CaseCnt,0) = 0 THEN SUM(CCDetail.Qty) ELSE SUM(CCDetail.Qty) / ISNULL(PACK.CaseCnt,0) END AS Qty,   
          CASE WHEN ISNULL(PACK.CaseCnt,0) = 0 THEN SUM(CCDetail.Qty_Cnt2) ELSE SUM(CCDetail.Qty_Cnt2) / ISNULL(PACK.CaseCnt,0) END AS Qty_Cnt2,   
          CASE WHEN ISNULL(PACK.CaseCnt,0) = 0 THEN SUM(CCDetail.Qty_Cnt3) ELSE SUM(CCDetail.Qty_Cnt3) / ISNULL(PACK.CaseCnt,0) END AS Qty_Cnt3,   
          TRIM(PACK.PackUOM1),   
          CASE WHEN ISNULL(PACK.CaseCnt,0) = 0 THEN SUM(CCDetail.SystemQty) ELSE SUM(CCDetail.SystemQty) / ISNULL(PACK.CaseCnt,0) END AS LotxLocxId_qty,   --WL01 
          --VarQty_cal = CASE @c_countno
          --               WHEN '1' THEN SUM(CCDetail.Qty) - SUM(CCDetail.SystemQty)
          --               WHEN '2' THEN SUM(CCDetail.Qty_Cnt2) - SUM(CCDetail.SystemQty)
          --               WHEN '3' THEN SUM(CCDetail.Qty_Cnt3) - SUM(CCDetail.SystemQty)
          --               ELSE 0
          --             END,
          VarQty_cal = 0,
          --TRIM(ISNULL(CL.[Description],''))
          TRIM(ISNULL(SKU.CLASS,''))
   FROM  CCDetail CCDetail (NOLOCK)  
   JOIN  SKU SKU (NOLOCK) ON ( SKU.SKU = CCDetail.SKU AND SKU.StorerKey = CCDetail.StorerKey) 
   JOIN  PACK PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey ) 
   JOIN  LOC LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )  
   JOIN  STORER COMPANY (NOLOCK) ON (COMPANY.Storerkey = 'JDHR')
   JOIN  STORER CURRENCY (NOLOCK) ON (CURRENCY.Storerkey = 'CURRENCY')
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'SKUFLAG' AND CL.Storerkey = SKU.Storerkey
                                 AND CL.Code = SKU.CLASS
   WHERE ( CCDetail.CCKey = @c_StockTakeKey )  
   AND   ( CCDetail.StorerKey >= @c_StorerKeyStart )  
   AND   ( CCDetail.StorerKey <= @c_StorerKeyEnd )  
   AND   ( CCDetail.Sku >= @c_SkuStart )  
   AND   ( CCDetail.Sku <= @c_SkuEnd )
   GROUP BY CCDetail.StorerKey,  
            CCDetail.CCKey,  
            CCDetail.Sku,   
            SKU.Descr,   
            TRIM(PACK.PackUOM1), 
            TRIM(ISNULL(SKU.CLASS,'')),
            ISNULL(PACK.CaseCnt,0)
   ORDER BY CCDetail.StorerKey,  
            CCDetail.CCKey,
            TRIM(ISNULL(SKU.CLASS,'')),  
            CCDetail.Sku  

   -- Remove all the records with no variance
   -- DELETE #TempStkVar FROM #TempStkVar WHERE #TempStkVar.VarQty_cal = 0

   SELECT StorerKey    
        , CCKey         
        , Sku          
        , Descr        
        , StorerKey        
        , Qty          
        , Qty_Cnt2     
        , Qty_Cnt3      
        , PackUOM      
        , LotxLocxId_Qty
        , VarQty_cal = CASE @c_countno
                       WHEN '1' THEN Qty - LotxLocxId_qty
                       WHEN '2' THEN Qty_Cnt2 - LotxLocxId_qty
                       WHEN '3' THEN Qty_Cnt3 - LotxLocxId_qty
                       ELSE 0
                     END   
        , Class      
   FROM #TempStkVar  
   ORDER BY RowID

   IF OBJECT_ID('tempdb..#TempStkVar') IS NOT NULL 
      DROP TABLE #TempStkVar

END

GO