SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  nsp_ShippingManifestDetail                         */  
/* Creation Date: 08-May-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by: FKLIM                                                    */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
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
  
CREATE PROC [dbo].[nsp_ShippingManifestDetails] (@c_Loadkey NVARCHAR(10), @c_Batch NVARCHAR(15))  
AS  
BEGIN  
   SET ANSI_DEFAULTS OFF    
   SET NOCOUNT ON  
  
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
   CASE WHEN PACK.Casecnt<>0 THEN SUM(PICKDETAIL.QTY)/PACK.Casecnt  
   ELSE 0 END as FullCaseCseQty,  
   SUM(PICKDETAIL.Qty) as pcsQty,  
         (SKU.Price * SUM(PICKDETAIL.Qty)) as TotalAmount,  
   CASE UPPER(LEFT(RDT.RDTCSAUDIT.CaseID, 1))   
   WHEN 'B' THEN 'BST Boxes'  
   WHEN 'R' THEN 'Consignor Boxes'  
   WHEN 'S' THEN 'Stored Addressed'  
   WHEN 'C' THEN 'Full Cases'  
   WHEN 'K' THEN 'Carton Boxes'  
   WHEN 'V' THEN 'Carton Boxes'  
   WHEN 'T' THEN 'Tote Boxes'  
   END as Category,  
   UPPER(RDT.RDTCSAUDIT.CaseID) as CaseId,  
         STotal = 0,  
         BTotal = 0,  
         RTotal = 0,  
         CTotal = 0,  
         TTotal = 0,  
         KTotal = 0,  
         VTotal = 0   
    INTO #TEMPRESULTSET  
    FROM ORDERS with (nolock)     
  JOIN ORDERDETAIL with (nolock) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)   
  JOIN PO with (nolock) ON (ORDERS.Pokey = PO.ExternPokey and ORDERS.Storerkey = PO.Storerkey)    
  JOIN STORER with (nolock) ON (STORER.Storerkey = ORDERS.Storerkey)   
  JOIN LOADPLAN with (nolock) ON (LOADPLAN.LoadKey = ORDERS.LoadKey)   
  JOIN PICKDETAIL with (nolock) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey   
   and PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)    
  JOIN SKU with (nolock) on (PICKDETAIL.sku = SKU.sku and SKU.Storerkey = PICKDETAIL.Storerkey)  
  JOIN PACK with (nolock) on (Pack.packkey = SKU.packkey)   
  JOIN RDT.RDTCSAUDIT with (nolock) ON (RDT.RDTCSAUDIT.Consigneekey = ORDERS.Consigneekey    
         AND RDT.RDTCSAUDIT.CaseId = PICKDETAIL.CaseId  
         AND RDT.RDTCSAUDIT.Sku = PICKDETAIL.SKU  
   AND RDT.RDTCSAUDIT.Storerkey = PICKDETAIL.Storerkey   
         AND RDT.RDTCSAUDIT.RowRef = PICKDETAIL.DropId)   
    JOIN RDT.RDTCSAUDIT_BATCH with (nolock) ON (RDT.RDTCSAUDIT.BatchId = RDT.RDTCSAUDIT_BATCH.BatchId)   
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
    RDT.RDTCSAUDIT.CaseID,  
    PACK.Casecnt    
  ORDER BY ORDERS.Consigneekey, Category, UPPER(RDT.RDTCSAUDIT.caseid), RDT.RDTCSAUDIT.Descr  
  
   DECLARE Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  
   SELECT DISTINCT consigneekey FROM #TEMPRESULTSET with (NOLOCK)   
    ORDER BY consigneekey   
  
   OPEN Cur   
   FETCH NEXT FROM Cur INTO @c_Consigneekey   
  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
  
      set @n_Stotal = 0   
      set @n_Btotal = 0   
      set @n_Rtotal = 0  
      set @n_Ctotal = 0   
      set @n_Ttotal = 0  
      set @n_Ktotal = 0  
      set @n_Vtotal = 0   
  
      DECLARE CurCaseId CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      Select distinct caseid   
      from #TEMPRESULTSET with (nolock)  
      where consigneekey= @c_Consigneekey  
        
      OPEN CurCaseId  
      FETCH NEXT FROM CurCaseId INTO @c_CaseId   
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
         IF Left(@c_CaseId,1)='S'  
            SET @n_Stotal = @n_Stotal + 1  
  
         ELSE IF Left(@c_CaseId,1)='B'  
            SET @n_Btotal = @n_Btotal + 1  
  
         ELSE IF Left(@c_CaseId,1)='R'  
            SET @n_Rtotal = @n_Rtotal + 1  
  
         ELSE IF Left(@c_CaseId,1)='C'  
            SET @n_Ctotal = @n_Ctotal + 1  
  
         ELSE IF Left(@c_CaseId,1)='T'  
            SET @n_Ttotal = @n_Ttotal + 1  
  
          ELSE IF Left(@c_CaseId,1)='K'  
            SET @n_Ktotal = @n_Ktotal + 1  
  
         ELSE IF Left(@c_CaseId,1)='V'  
            SET @n_Vtotal = @n_Vtotal + 1  
  
         FETCH NEXT FROM CurCaseId INTO @c_CaseId  
      END  
     
      CLOSE CurCaseId  
      DEALLOCATE CurCaseId  
     
      UPDATE #TEMPRESULTSET with (rowlock)  
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
  
   -- return result set  
 SELECT * FROM #TEMPRESULTSET with (nolock)   
 ORDER BY Consigneekey, Category, caseid, Descr  
     
 -- drop table  
 DROP TABLE #TEMPRESULTSET  
END

GO