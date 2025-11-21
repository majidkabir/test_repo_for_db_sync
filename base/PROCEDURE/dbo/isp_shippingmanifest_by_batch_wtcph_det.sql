SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: isp_ShippingManifest_By_Batch_WTCPH_Det             */  
/* Creation Date: 08-May-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by: FKLIM                                                    */  
/*                                                                      */  
/* Purpose: IDSPH Watsons Shipping Manifest by Batch (SOS76510)         */  
/*                                                                      */  
/* Called By: r_shipping_manifest_by_batch_wtcph_det                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/*                                                                      */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ShippingManifest_By_Batch_WTCPH_Det] (  
   @c_Loadkey NVARCHAR(10),   
   @c_Batch NVARCHAR(15) )  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
 DECLARE   
  @b_success int,  
  @n_err int,  
  @c_errmsg NVARCHAR(255),  
      @c_Consigneekey NVARCHAR(15),  
      @c_CaseId NVARCHAR(18),  
      @n_Stotal int,  
      @n_Btotal int,  
      @n_Rtotal int,  
      @n_Ctotal int,  
      @n_Ttotal int,  
      @n_Ktotal int,  
      @n_Vtotal int  
  
   SELECT  
  @b_success      = 0,  
  @n_err          = 0,  
  @c_errmsg       = '',  
      @n_Stotal       = 0,   
      @n_Btotal       = 0,   
      @n_Rtotal       = 0,   
      @n_Ctotal       = 0,   
      @n_Ttotal       = 0,   
      @n_Ktotal       = 0,   
      @n_Vtotal       = 0   
  
  SELECT ORIGIN.Company,  
         ORIGIN.Address1,  
         ORIGIN.Address2,  
         ORIGIN.Address3,  
   LOADPLAN.AddDate,  
         LOADPLAN.UserDefine10,  
   ORDERS.ConsigneeKey,     
         ORDERS.C_Company,     
         ORDERS.C_Address1,     
         ORDERS.C_Address2,     
         ORDERS.C_Address3,  
   ORDERDETAIL.OriginalQty,  
   RDT.RDTCSAUDIT.Sku,  
   RDT.RDTCSAUDIT.Descr,  
   RDT.RDTCSAUDIT.RefNo1,  
   RDT.RDTCSAUDIT.RefNo2,  
   RDT.RDTCSAUDIT.RefNo3,  
   RDT.RDTCSAUDIT.RefNo4,  
   CASE WHEN PACK.Casecnt <> 0 THEN SUM(PICKDETAIL.QTY)/PACK.Casecnt  
   ELSE 0 END as FullCaseCseQty,  
   SUM(PICKDETAIL.Qty) as pcsQty,  
         (SKU.Price * SUM(PICKDETAIL.Qty)) as TotalAmount,  
   CASE UPPER(LEFT(RDT.RDTCSAUDIT.CaseId, 1))   
   WHEN 'B' THEN 'BST Boxes'  
   WHEN 'R' THEN 'Consignor Boxes'  
   WHEN 'S' THEN 'Store Addressed'  
   WHEN 'C' THEN 'Full Cases'  
   WHEN 'K' THEN 'Carton Boxes'  
   WHEN 'V' THEN 'Carton Boxes'  
   WHEN 'T' THEN 'Tote Boxes'  
   END as Category,  
   UPPER(RDT.RDTCSAUDIT.CaseId) as CaseId,  
         STotal = 0,  
         BTotal = 0,  
         RTotal = 0,  
         CTotal = 0,  
         TTotal = 0,  
         KTotal = 0,  
         VTotal = 0   
    INTO #TempResult  
    FROM ORDERS WITH (NOLOCK)     
  JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)   
  JOIN PO WITH (NOLOCK) ON (ORDERS.Pokey = PO.ExternPOKey AND ORDERS.StorerKey = PO.StorerKey)    
  JOIN STORER WITH (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)   
  JOIN LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LoadKey = ORDERS.LoadKey)   
  JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey   
   and PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)    
  JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.SKU = SKU.SKU AND SKU.StorerKey = PICKDETAIL.StorerKey)  
  JOIN PACK WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)   
  JOIN RDT.RDTCSAUDIT WITH (NOLOCK) ON (RDT.RDTCSAUDIT.Consigneekey = ORDERS.Consigneekey    
         AND RDT.RDTCSAUDIT.CaseId = PICKDETAIL.CaseId  
         AND RDT.RDTCSAUDIT.SKU = PICKDETAIL.SKU  
   AND RDT.RDTCSAUDIT.StorerKey = PICKDETAIL.StorerKey   
         AND RDT.RDTCSAUDIT.RowRef = PICKDETAIL.DropId)   
    JOIN RDT.RDTCSAUDIT_BATCH WITH (NOLOCK) ON (RDT.RDTCSAUDIT.BatchId = RDT.RDTCSAUDIT_BATCH.BatchId)   
  LEFT OUTER JOIN STORER ORIGIN (NOLOCK) ON (ORIGIN.StorerKey = 'IDS')   
    WHERE LOADPLAN.UserDefine09 = @c_Loadkey   
  AND  RDT.RDTCSAUDIT_BATCH.Batch = @c_Batch  
    GROUP BY ORIGIN.Company,  
    ORIGIN.Address1,  
    ORIGIN.Address2,  
    ORIGIN.Address3,  
    LOADPLAN.AddDate,  
    LOADPLAN.UserDefine10,  
    ORDERS.ConsigneeKey,     
    ORDERS.C_Company,     
    ORDERS.C_Address1,     
    ORDERS.C_Address2,     
    ORDERS.C_Address3,  
    ORDERDETAIL.OriginalQty,  
    RDT.RDTCSAUDIT.Sku,  
    RDT.RDTCSAUDIT.Descr,  
    RDT.RDTCSAUDIT.RefNo1,  
    RDT.RDTCSAUDIT.RefNo2,  
    RDT.RDTCSAUDIT.RefNo3,  
    RDT.RDTCSAUDIT.RefNo4,  
    SKU.Price,  
    PO.POType,  
    RDT.RDTCSAUDIT.CaseId,  
    PACK.Casecnt    
  ORDER BY ORDERS.Consigneekey, Category, UPPER(RDT.RDTCSAUDIT.CaseId), RDT.RDTCSAUDIT.Descr  
  
   DECLARE Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  
   SELECT DISTINCT consigneekey FROM #TempResult WITH (NOLOCK)   
    ORDER BY consigneekey   
  
   OPEN Cur   
   FETCH NEXT FROM Cur INTO @c_Consigneekey   
  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
  
      SET @n_Stotal = 0   
      SET @n_Btotal = 0   
      SET @n_Rtotal = 0  
      SET @n_Ctotal = 0   
      SET @n_Ttotal = 0  
      SET @n_Ktotal = 0  
      SET @n_Vtotal = 0   
  
      DECLARE CurCaseId CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT CaseId   
      FROM #TempResult WITH (NOLOCK)  
      WHERE ConsigneeKey= @c_Consigneekey  
        
      OPEN CurCaseId  
      FETCH NEXT FROM CurCaseId INTO @c_CaseId   
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
         IF LEFT(@c_CaseId,1)='S'  
            SET @n_Stotal = @n_Stotal + 1  
  
         ELSE IF LEFT(@c_CaseId,1)='B'  
            SET @n_Btotal = @n_Btotal + 1  
  
         ELSE IF LEFT(@c_CaseId,1)='R'  
            SET @n_Rtotal = @n_Rtotal + 1  
  
         ELSE IF LEFT(@c_CaseId,1)='C'  
            SET @n_Ctotal = @n_Ctotal + 1  
  
         ELSE IF LEFT(@c_CaseId,1)='T'  
            SET @n_Ttotal = @n_Ttotal + 1  
  
          ELSE IF LEFT(@c_CaseId,1)='K'  
            SET @n_Ktotal = @n_Ktotal + 1  
  
         ELSE IF LEFT(@c_CaseId,1)='V'  
            SET @n_Vtotal = @n_Vtotal + 1  
  
         FETCH NEXT FROM CurCaseId INTO @c_CaseId  
      END  
     
      CLOSE CurCaseId  
      DEALLOCATE CurCaseId  
     
      UPDATE #TempResult WITH (ROWLOCK)  
      SET STotal = @n_Stotal,  
          BTotal = @n_Btotal,  
          RTotal = @n_Rtotal,  
          CTotal = @n_Ctotal,  
          TTotal = @n_Ttotal,  
          KTotal = @n_Ktotal,  
          VTotal = @n_Vtotal   
      WHERE Consigneekey= @c_Consigneekey     
  
      FETCH NEXT FROM Cur INTO @c_Consigneekey  
   END  
  
   CLOSE Cur  
   DEALLOCATE Cur  
  
   -- return result SET  
 SELECT * FROM #TempResult WITH (NOLOCK)   
 ORDER BY Consigneekey, Category, CaseId, Descr  
     
 -- drop table  
 DROP TABLE #TempResult  
END

GO