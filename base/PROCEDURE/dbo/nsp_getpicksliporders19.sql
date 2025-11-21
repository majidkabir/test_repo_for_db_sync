SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders19                            */
/* Creation Date: 30th Aug 2005                                         */
/* Copyright: IDS                                                       */
/* Written by: Shong (Copy from nsp_GetPickSlipOrders04)                */
/*                                                                      */
/* Purpose: SOS# 39810 Picklist for KCPI (Philippine)                   */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4.2                                                       */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 22-Jun-2006  UngDH         SOS52808 - All pick list must sort by     */
/*                            LogicalLocation                           */
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/* 18-Sep-2015  CSCHONG         SOS#352276 (CS01)                       */
/************************************************************************/
 
CREATE PROC [dbo].[nsp_GetPickSlipOrders19] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey NVARCHAR(10),
      @c_PickSlipNo NVARCHAR(10),
      @c_PrevOrderKey NVARCHAR(10),
      @c_PrevLoadKey NVARCHAR(10),
      @c_PickDetailKey NVARCHAR(10), 
      @c_storerkey NVARCHAR(18),
      @c_consigneekey NVARCHAR(15),
      @b_success int,
      @n_err int,
      @c_errmsg NVARCHAR(255), 
      @n_Continue int, 
      @c_OrderLineNumber NVARCHAR(5)  

   SELECT RefKeyLookup.PickSlipNo,
      PICKDETAIL.Lot,   
      PICKDETAIL.Loc, 
      PICKDETAIL.ID, 
      PickedQty=SUM(PICKDETAIL.Qty),      
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02,   
      LOTATTRIBUTE.Lottable03,   
      LOTATTRIBUTE.Lottable04,
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,   
      ORDERDETAIL.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      billto.company as B_company,
      billto.address1 as B_address1,
      billto.address2 as B_address2,
      billto.address3 as B_address3,
      billto.address4 as B_address4,
      consignee.company as C_company,
      consignee.address1 as C_address1,
      consignee.address2 as C_address2,
      consignee.address3 as C_address3,
      consignee.address4 as C_address4,
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      Prepared = CONVERT(NVARCHAR(10), Suser_Sname()),
      ORDERDETAIL.LoadKey as Rdd, --ORDERS.Rdd,
      sku.susr3,
      CODELKUP.description as principal,
      ORDERS.Facility, -- Add by June 11.Jun.03 (SOS11736)
      FacilityDescr = Facility.Descr,  -- Add by June 11.Jun.03 (SOS11736)
      LOC.LogicalLocation, -- SOS52808. All pick list must sort by LogicalLocation 
      Loadplan.Route AS LRoute,                                                --(CS01)
      Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01) 
      Loadplan.Priority AS LPriority,                                          --(CS01)
      Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)  
   INTO  #RESULT
   FROM  LOC (Nolock) join PICKDETAIL (Nolock)
      ON LOC.Loc = PICKDETAIL.Loc
   JOIN ORDERS (Nolock)
      ON ORDERS.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER (Nolock)
      ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN STORER billto (nolock)
      ON billto.storerkey = ORDERS.billtokey
   LEFT OUTER JOIN STORER consignee (nolock)
      ON consignee.storerkey = ORDERS.consigneekey
   JOIN SKU (Nolock)
      ON SKU.StorerKey = PICKDETAIL.Storerkey and
         SKU.Sku = PICKDETAIL.Sku
   JOIN LOTATTRIBUTE (Nolock)
      ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   JOIN PACK (Nolock) 
      ON PACK.PackKey = SKU.PackKey
   JOIN ORDERDETAIL (NOLOCK)
      ON PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey and
         PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
   LEFT OUTER JOIN CODELKUP (nolock)
      ON codelkup.listname = 'PRINCIPAL' and
         codelkup.code = sku.susr3
   INNER JOIN FACILITY (nolock) 
      ON Facility.Facility = ORDERS.Facility -- Add by June 11.Jun.03 (SOS11736) 
   LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey 
   JOIN LOADPLAN WITH (NOLOCK)                     --(CS01)
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey    --(CS01)
   WHERE ORDERDETAIL.Loadkey = @c_loadkey
   GROUP BY 
      RefKeyLookup.PickSlipNo,
      PICKDETAIL.Lot,  
      PICKDETAIL.ID, 
      PICKDETAIL.Loc,    
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02,   
      LOTATTRIBUTE.Lottable03,   
      LOTATTRIBUTE.Lottable04,
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,
      ORDERDETAIL.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      billto.company,
      billto.address1,
      billto.address2,
      billto.address3,
      billto.address4,
      consignee.company,
      consignee.address1,
      consignee.address2,
      consignee.address3,
      consignee.address4,
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes),
      SKU.SUSR3,
      CODELKUP.Description,
      ORDERS.Facility, -- Add by June 11.Jun.03 (SOS11736)
      Facility.Descr, -- Add by June 11.Jun.03 (SOS11736)
      LOC.LogicalLocation, -- SOS52808. All pick list must sort by LogicalLocation 
      Loadplan.Route ,                                             --(CS01)
      Loadplan.Externloadkey ,                                      --(CS01) 
      Loadplan.Priority ,                                           --(CS01)
      Loadplan.LPuserdefDate01           --(CS01) 
      -- process PickSlipNo
      
   
   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT LoadKey, OrderKey 
   FROM   #RESULT 
   WHERE  PickSlipNo IS NULL or PickSlipNo = ''
   ORDER BY LoadKey, OrderKey 

   SET @c_LoadKey = ''
   SET @c_OrderKey = ''
   SET @c_PickDetailKey = ''
   SET @n_Continue = 1 

   OPEN C_LoadKey_ExternOrdKey 

   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_OrderKey  

   WHILE (@@Fetch_Status <> -1)
   BEGIN -- while 1
      IF ISNULL(@c_OrderKey, '0') = '0'
         BREAK

      IF @c_PrevLoadKey <> @c_LoadKey OR 
         @c_PrevOrderKey <> @c_OrderKey 
      BEGIN     
         SET @c_PickSlipNo = ''

         SELECT @c_PickSlipNo = PICKHEADERKEY
         FROM PICKHEADER (NOLOCK) 
         WHERE ExternOrderKey = @c_LoadKey AND OrderKey = @c_OrderKey
           AND Zone = 'LB'

         IF dbo.fnc_RTrim(@c_PickSlipNo) IS NULL OR dbo.fnc_RTrim(@c_PickSlipNo) = ''  
         BEGIN
            EXECUTE nspg_GetKey
               'PICKSLIP',
               9,   
               @c_PickSlipNo   OUTPUT,
               @b_success      OUTPUT,
               @n_err          OUTPUT,
               @c_errmsg       OUTPUT
      
            IF @b_success = 1 
            BEGIN
               SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo          

               INSERT PICKHEADER (pickheaderkey, externOrderKey, OrderKey,    zone)
                          VALUES (@c_PickSlipNo, @c_loadkey,     @c_OrderKey, 'LB')

               IF @@ERROR <> 0 
               BEGIN
                  SET @n_Continue = 3 
                  BREAK 
               END 
            END -- @b_success = 1  
            ELSE 
            BEGIN
               BREAK 
            END 
         END 

         IF @n_Continue = 1 
         BEGIN
            DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber  
            FROM   PickDetail (NOLOCK)
            JOIN   OrderDetail (NOLOCK) ON PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                                           PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber 
            WHERE  OrderDetail.OrderKey = @c_OrderKey AND 
                   OrderDetail.LoadKey  = @c_LoadKey 
            ORDER BY PickDetail.PickDetailKey 

            OPEN C_PickDetailKey

            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber 

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey) 
               BEGIN 
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                  VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey)                        
               END 

               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber 
            END 
            CLOSE C_PickDetailKey 
            DEALLOCATE C_PickDetailKey 

         END 
      
      END -- @c_PrevLoadKey <> @c_LoadKey 

      UPDATE #RESULT
         SET PickSlipNo = @c_PickSlipNo
      WHERE OrderKey = @c_OrderKey
      AND   LoadKey = @c_LoadKey       
      AND   (PickSlipNo IS NULL OR PickSlipNo = '')

      IF @c_PrevOrderKey <> @c_OrderKey
      BEGIN 
         -- update print flag
         UPDATE ORDERS
         SET trafficcop = null,
             printflag = 'Y'
         WHERE OrderKey = @c_OrderKey
      END

      SET @c_PrevLoadKey = @c_LoadKey 
      SET @c_PrevOrderKey = @c_OrderKey

      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_OrderKey  
   END -- while 1 

   CLOSE C_LoadKey_ExternOrdKey
   DEALLOCATE C_LoadKey_ExternOrdKey 

   IF @n_Continue = 1 
   BEGIN
      -- return result set
      SELECT * FROM #RESULT ORDER BY PickSlipNo 
   END 

   -- drop table
   DROP TABLE #RESULT 


END

GO