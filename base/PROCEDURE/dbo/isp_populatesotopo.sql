SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- DROP PROC isp_PopulateSOtoPO    
    
/************************************************************************/    
/* Stored Procedure: isp_PopulateSOtoPO                                 */    
/* Creation Date: 23-March012                                           */    
/* Copyright: LF LOGISTICS                                              */    
/* Written by: Ricky Yee                                                */    
/*                                                                      */    
/* Purpose: Non-Trade PO                                                */    
/*                                                                      */    
/* Called By: SQL Scheduler                                             */     
/*                                                                      */    
/* Parameters:                                                          */    
/*                                                                      */    
/* PVCS Version: 1.0                                                 */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver. Purposes                                 */    
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_PopulateSOtoPO]    
        @c_storerkey NVARchar(15)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
     
   DECLARE  @n_continue int,    
            @n_cnt int,    
            @c_orderkey NVARchar(10), @c_prevorderkey NVARchar(10), @d_orderdate datetime, @d_Deliverydate datetime,     
   @c_consignee NVARchar(15), @c_company NVARchar(15), @c_address1 NVARchar(45), @c_address2 NVARchar(45),    
   @c_facility NVARchar(5), @c_ordertype NVARchar(10), @c_orderline NVARchar(5), @c_orderextline NVARchar(5),    
   @c_sku NVARchar(20), @n_qty Int, @c_packkey NVARchar(10), @c_uom NVARchar(5),     
   @c_Scompany NVARchar(15), @c_saddress1 NVARchar(45), @c_saddress2 NVARchar(45), @c_skudescr NVARchar(60),     
   @c_pono NVARchar(10), @b_success NVARchar(1), @n_err int, @c_errmsg NVARchar(255),    
   @c_billtokey NVARchar(15), @c_bcompany NVARchar(15), @c_baddress1 NVARchar(45), @c_baddress2 NVARchar(45)      
    
 SELECT  @c_orderkey = '', @c_prevorderkey = ''     
    
 DECLARE CUR_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
 SELECT O.Orderkey, O.OrderDate, O.DeliveryDate, O.Consigneekey,     
     O.c_Company, O.C_Address1, O.C_Address2, O.Facility, O.Type, S.Company, S.Address1, S.Address2,     
     OD.OrderLineNumber, OD.ExternLineNo, OD.Sku, OD.OriginalQty, OD.PackKey, OD.UOM, SKU.DESCR,    
     O.BilltoKey, O.B_Company, O.B_Address1, O.B_Address2      
   FROM ORDERS O (NOLOCK), ORDERDETAIL OD (NOLOCK), STORER S (NOLOCK), SKU (NOLOCK)     
  WHERE O.Storerkey = @c_storerkey AND O.Userdefine01 = 'N' AND O.Status = '0'     
    AND O.Orderkey = OD.Orderkey AND O.Storerkey = S.Storerkey     
    AND OD.Storerkey = SKU.Storerkey AND OD.SKU = SKU.SKU    
 ORDER BY O.ORDERKEY, OD.OrderLineNumber    
    
 OPEN CUR_Order      
    
 FETCH NEXT FROM CUR_Order INTO @c_orderkey, @d_orderdate, @d_Deliverydate, @c_consignee, @c_company, @c_address1,     
           @c_address2, @c_facility, @c_ordertype, @c_Scompany, @c_saddress1, @c_saddress2,     
           @c_orderline, @c_orderextline, @c_sku, @n_qty, @c_packkey, @c_uom, @c_skudescr,    
           @c_billtokey, @c_bcompany, @c_baddress1, @c_baddress2            
    
 WHILE @@FETCH_STATUS = 0     
 BEGIN   
        
  IF @c_prevorderkey <> @c_orderkey     
  BEGIN    
   SELECT @c_prevorderkey = @c_orderkey    
    
   BEGIN TRAN  
   EXECUTE nspg_GetKey    
       'PO',    
       10,       
       @c_pono        OUTPUT,    
       @b_success     OUTPUT,    
       @n_err         OUTPUT,    
       @c_errmsg      OUTPUT      
   IF @b_success <> 1    
   BEGIN    
      ROLLBACK TRAN  
      SELECT 'PO KEY Failed'    
      BREAK    
   END    
    
   IF @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   BEGIN TRAN  
   --  INSERT PO     
   INSERT PO (POKEY, EXTERNPOKEY, STORERKEY, PODATE, POTYPE, SELLERNAME, SELLERADDRESS1, SELLERADDRESS2,    
        BUYERNAME, BUYERADDRESS1, BUYERADDRESS2, LOADINGDATE, BuyersReference, SellersReference)    
   VALUES (@c_pono, @c_orderkey, @c_storerkey, @d_orderdate, @c_ordertype, @c_bcompany, @c_baddress1, @c_baddress2,    
      @c_company, @c_address1, @c_address2, @d_Deliverydate, @c_consignee, @c_billtokey)    
   SELECT @n_err = @@ERROR    
   IF @n_err <> 0    
   BEGIN    
      ROLLBACK TRAN  
      SELECT 'PO Creation Failed'    
      BREAK    
   END    
    
   -- Update Order to indicate PO has created for this order    
   UPDATE ORDERS with (ROWLOCK)    
   SET Userdefine01 = 'Y', Trafficcop = NULL, Editdate = getdate()    
   Where ORDERKEY = @c_orderkey    
   SELECT @n_err = @@ERROR    
   IF @n_err <> 0    
   BEGIN    
      ROLLBACK TRAN  
      SELECT 'Update SO Failed'    
      BREAK    
   END    
   COMMIT TRAN  
  END    
  BEGIN TRAN  
  --  INSERT PO DETAIL    
    
  INSERT PODETAIL (POKEY, POLINENUMBER, STORERKEY, EXTERNPOKEY, EXTERNLINENO, SKU, SKUDESCRIPTION, QTYORDERED, PACKKEY, UOM, FACILITY)    
  VALUES (@c_pono, @c_orderline, @c_storerkey, @c_orderkey, @c_orderextline, @c_sku, @c_skudescr, @n_qty, @c_packkey, @c_uom, @c_facility)    
    
  SELECT @n_err = @@ERROR    
  IF @n_err <> 0    
  BEGIN    
     ROLLBACK TRAN  
     SELECT 'PODETAIL Creation Failed'    
     BREAK    
  END    
  COMMIT TRAN  
  FETCH NEXT FROM CUR_Order INTO @c_orderkey, @d_orderdate, @d_Deliverydate, @c_consignee, @c_company, @c_address1,     
            @c_address2, @c_facility, @c_ordertype, @c_Scompany, @c_saddress1, @c_saddress2,     
            @c_orderline, @c_orderextline, @c_sku, @n_qty, @c_packkey, @c_uom, @c_skudescr,    
            @c_billtokey, @c_bcompany, @c_baddress1, @c_baddress2             
 END    
    
 CLOSE CUR_Order    
 DEALLOCATE CUR_Order    
    
END 


GO