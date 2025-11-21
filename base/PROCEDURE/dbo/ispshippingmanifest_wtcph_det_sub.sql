SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: ispShippingManifest_WTCPH_Det_Sub                   */  
/* Creation Date: 28-Jun-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MaryVong                                                 */  
/*                                                                      */  
/* Purpose: IDSPH Watsons Shipping Manifest by Batch (SOS76510)         */  
/*          - sub-report under Detail Report                            */  
/*          - Get TotalQty, Consignee and LoadPlan data                 */  
/*                        */  
/* Input Parameters:  @c_Batch,                                         */  
/*        @c_ConsigneeKey,               */  
/*        @c_type                                           */  
/*                                                                      */  
/* Output Parameters: report                                            */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: - r_dw_shippingmanifest_wtcph_det_case                    */  
/*            - r_dw_shippingmanifest_wtcph_det_tote                    */  
/*            - r_dw_shippingmanifest_wtcph_det_storeaddr               */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 16-Dec-2008  YTWan   1.1   SOS#124182 Add Manufacturing lot and      */  
/*                              Expiry date to the report (YTWan01)     */  
/* 2009-11-19   TLTING  1.2   Performance Tune                          */
/************************************************************************/  
  
CREATE PROC [dbo].[ispShippingManifest_WTCPH_Det_Sub] (  
   @c_Batch          NVARCHAR(15),  
   @c_ConsigneeKey   NVARCHAR(15),  
   @c_Type           NVARCHAR(1)  )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   IF OBJECT_ID('tempdb..#tTempData') IS NOT NULL  
      DROP TABLE #tTempData  
  
   --DECLARE @tTempData TABLE (  
   CREATE TABLE #tTempData  (  
      ConsigneeKey    NVARCHAR(15) NULL DEFAULT (''),  
      Type            NVARCHAR(1)  NULL DEFAULT (''),  
      CaseID          NVARCHAR(18) NULL DEFAULT (''),  
      StorerKey       NVARCHAR(15) NULL DEFAULT (''),  
      SKU             NVARCHAR(20) NULL DEFAULT (''),  
      SKUDescr        NVARCHAR(60) NULL DEFAULT (''),  
      CountedQty      int      NULL DEFAULT (0),  
      RefNo1          NVARCHAR(20) NULL DEFAULT (''),  
      RefNo2          NVARCHAR(20) NULL DEFAULT (''),  
      RefNo3          NVARCHAR(20) NULL DEFAULT (''),  
      RefNo4          NVARCHAR(20) NULL DEFAULT (''),  
  Lottable02   NVARCHAR(18) NULL DEFAULT (''),            -- YTWan01  
  Lottable04   datetime NULL                  -- YTWan01  
   )  
  
   IF OBJECT_ID('tempdb..#tTempResult') IS NOT NULL  
      DROP TABLE #tTempResult  
  
   --DECLARE @tTempResult TABLE (  
   CREATE TABLE #tTempResult  (  
      RowID           int identity (1,1),   
      Batch           NVARCHAR(15) NULL DEFAULT (''),  
      ConsgineeKey    NVARCHAR(15) NULL DEFAULT (''),  
      Type            NVARCHAR(1)  NULL DEFAULT (''),       
      CaseID          NVARCHAR(18) NULL DEFAULT (''),  
      CaseIDPrefix    NVARCHAR(1)  NULL DEFAULT (''),  
      Category        NVARCHAR(30) NULL DEFAULT (''),  
      SKU             NVARCHAR(20) NULL DEFAULT (''),  
      SKUDescr        NVARCHAR(60) NULL DEFAULT (''),  
      RefNo1          NVARCHAR(20) NULL DEFAULT (''),  
      RefNo2          NVARCHAR(20) NULL DEFAULT (''),  
      RefNo3          NVARCHAR(20) NULL DEFAULT (''),  
      RefNo4          NVARCHAR(20) NULL DEFAULT (''),  
      CaseQty         int NULL DEFAULT (0),  
      EachQty         int NULL DEFAULT (0),  
      SKUPrice        float NULL DEFAULT (0),  
  Lottable02   NVARCHAR(18) NULL DEFAULT (''),            -- YTWan01  
  Lottable04   datetime NULL                  -- YTWan01  
   )  
  
   -- Get all matching data into tempData table  
   INSERT INTO #tTempData  
      (ConsigneeKey, Type, CaseID, StorerKey, SKU, SKUDescr, CountedQty, RefNo1, RefNo2, RefNo3, RefNo4,  
       Lottable02, Lottable04)                       -- YTWan01  
   SELECT AU.ConsigneeKey, AU.Type, AU.CaseID, AU.StorerKey, AU.SKU, AU.DESCR,   
         CASE WHEN AU.Type <> 'T' THEN MIN(AU.CountQty_B) ELSE SUM(ISNULL(PD.QTY,0)) END AS CountedQty, -- YTWan01   
         AU.RefNo1, AU.RefNo2, AU.RefNo3, AU.RefNo4, LA.Lottable02, LA.Lottable04      -- YTWan01  
   FROM RDT.RDTCSAudit_BATCH BA (NOLOCK) 
   INNER JOIN RDT.RDTCSAudit AU WITH (NOLOCK) ON (BA.BatchID = AU.BatchID)  
   LEFT OUTER JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.CaseID = AU.CaseID)     -- YTWan01  
                    AND (PD.DropID = AU.RowRef)     -- YTWan01  
                    AND (PD.Storerkey = AU.Storerkey)   -- YTWan01  
                    AND (PD.Sku       = AU.Sku)     -- YTWan01  
                AND (AU.Type     <> 'S')  
   LEFT OUTER JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.Lot = PD.Lot)      -- YTWan01  
   WHERE BA.Batch = @c_Batch      
   AND   AU.ConsigneeKey = @c_ConsigneeKey  
   AND   AU.Type = @c_Type  
   AND   AU.Status >= '5'  
   GROUP BY AU.ConsigneeKey, AU.Type, AU.CaseID, AU.StorerKey, AU.SKU, AU.DESCR,    -- YTWan01  
            AU.RefNo1, AU.RefNo2, AU.RefNo3, AU.RefNo4, LA.Lottable02, LA.Lottable04 -- YTWan01  
   ORDER BY AU.CaseID  
  
   /*************************/  
   /* Full Case             */  
   /* Type = 'C'            */  
   /* CaseID prefix = 'C'   */  
   /*************************/  
   IF @c_Type = 'C'  
   BEGIN  
      -- Insert into result table  
      INSERT INTO #tTempResult  
         (Batch,      ConsgineeKey,      Type,      CaseID,   CaseIDPrefix,  
         Category,    SKU,               SKUDescr,  RefNo1,   RefNo2,  
         RefNo3,      RefNo4,         CaseQty,   EachQty,  SKUPrice,  
    Lottable02, Lottable04 )                  -- YTWan01  
      SELECT @c_Batch, @c_ConsigneeKey, @c_Type,   
         CaseID,        
         SUBSTRING(CaseID,1,1),  
         'Full Case',   -- Category  
         T.SKU,  
         SKUDescr,  
         '',            -- RefNo1  
         '',            -- RefNo2  
         '',            -- RefNo3  
         '',            -- RefNo4  
         1,             -- CaseQty  
         CountedQty,    -- EachQty  
         S.Price,       -- SKUPrice  
   T.Lottable02,                      -- YTWan01  
   T.Lottable04                      -- YTWan01  
      FROM #tTempData T  
      INNER JOIN SKU S WITH (NOLOCK) ON (T.StorerKey = S.StorerKey AND T.SKU = S.SKU)  
      ORDER BY T.SKU  
   END  
     
   /**********************************/  
   /* Tote                           */  
   /* Type = 'T'                     */  
   /* CaseID prefix = 'T','K','V'    */  
   /**********************************/  
   ELSE IF @c_Type = 'T'  
   BEGIN  
      -- Insert into result table  
      INSERT INTO #tTempResult  
         (Batch,      ConsgineeKey,      Type,      CaseID,   CaseIDPrefix,  
         Category,    SKU,               SKUDescr,  RefNo1,   RefNo2,  
         RefNo3,      RefNo4,            CaseQty,   EachQty,  SKUPrice,  
    Lottable02, Lottable04 )                  -- YTWan01  
      SELECT @c_Batch, @c_ConsigneeKey, @c_Type,   
         CaseID,        
         SUBSTRING(CaseID,1,1),  
         CASE WHEN SUBSTRING(CaseID,1,1) = 'T' THEN 'Tote Boxes'  
            WHEN SUBSTRING(CaseID,1,1) IN ('K','V') THEN 'Carton Boxes'  
         END,           -- Category  
         T.SKU,  
         SKUDescr,  
         RefNo1,        -- RefNo1  
         RefNo2,        -- RefNo2  
         RefNo3,        -- RefNo3  
         RefNo4,        -- RefNo4  
         0,             -- CaseQty  
         CountedQty,    -- EachQty  
         S.Price,       -- SKUPrice  
   T.Lottable02,                      -- YTWan01  
   T.Lottable04                      -- YTWan01  
      FROM #tTempData T  
      INNER JOIN SKU S WITH (NOLOCK) ON (T.StorerKey = S.StorerKey AND T.SKU = S.SKU)  
      AND   SUBSTRING(CaseID,1,1) IN ('T','K','V')  
      ORDER BY CaseID, T.SKU  
   END  
  
   /**********************************/  
   /* Store-Addressed                */  
   /* Type = 'S'                     */  
   /* CaseID prefix = 'S','B','R'    */  
   /**********************************/   
   ELSE IF @c_Type = 'S'  
   BEGIN  
      -- Insert into result table  
      INSERT INTO #tTempResult  
         (Batch,      ConsgineeKey,      Type,      CaseID,   CaseIDPrefix,  
         Category,    SKU,               SKUDescr,  RefNo1,   RefNo2,  
         RefNo3,      RefNo4,            CaseQty,   EachQty,  SKUPrice,  
    Lottable02, Lottable04 )                  -- YTWan01  
      SELECT @c_Batch, @c_ConsigneeKey, @c_Type,   
         CaseID,        
         SUBSTRING(CaseID,1,1),  
         CASE WHEN SUBSTRING(CaseID,1,1) = 'S' THEN 'Store-Addressed'  
              WHEN SUBSTRING(CaseID,1,1) = 'B' THEN 'BST Boxes'  
              WHEN SUBSTRING(CaseID,1,1) = 'R' THEN 'Consignor Boxes'  
         END,           -- Category  
         '',            -- SKU  
         '',            -- SKUDescr  
         '',            -- RefNo1  
         '',            -- RefNo2  
         '',            -- RefNo3  
         '',            -- RefNo4  
         1,             -- CaseQty  
         0,             -- EachQty  
         0,             -- SKUPrice  
   '',                        -- YTWan01  
     NULL                        -- YTWan01  
      FROM #tTempData T  
      WHERE SUBSTRING(CaseID,1,1) IN ('S','B','R')  
      ORDER BY CaseID  
   END     
  
   -- Return result  
   SELECT  
      Batch,       ConsgineeKey,      Type,      CaseID,   CaseIDPrefix,  
      Category,    SKU,               SKUDescr,  RefNo1,   RefNo2,  
      RefNo3,      RefNo4,            CaseQty,   EachQty,  SKUPrice,  
  Lottable02,  Lottable04                   -- YTWan01  
   FROM #tTempResult  
   ORDER BY RowID  
  
END  



GO