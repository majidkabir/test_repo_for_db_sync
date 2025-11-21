SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nsp_GetPickSlipOrders39                            */  
/* Creation Date: 08-Mac-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: AQSKC                                                    */  
/*                                                                      */  
/* Purpose: SFC pick list SOS#XXXXXX                                    */  
/*          -Pickslip by Pickzone                                       */
/*          -One SKU will be located in 1 pickzone only & never         */
/*           multiple pickzone                                          */                           
/*                                                                      */  
/* Called By: r_dw_print_pickorder36                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_GetPickSlipOrders39] (@c_loadkey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_pickheaderkey      NVARCHAR(10),  
           @n_continue           int,  
           @c_errmsg             NVARCHAR(255),  
           @b_success            int,  
           @n_err                int,  
           @c_Orderkey           NVARCHAR(10),
           @c_Pickzone           NVARCHAR(10),
           @c_Pickdetailkey      NVARCHAR(10),
           @c_PrevLoadkey        NVARCHAR(10),
           @c_PrevOrderkey       NVARCHAR(10),
           @c_PrevPickzone       NVARCHAR(10),
           @c_Pickslipno         NVARCHAR(10),
           @c_Orderlinenumber    NVARCHAR(5)
                
    SELECT RefKeyLookup.PickSlipNo,                                                                  
           ORDERS.Billtokey,  
           ORDERS.B_Company,  
           ORDERS.B_Address1,  
           ORDERS.B_Address2,  
           ISNULL(ORDERS.B_City,'') AS B_City,  
           ISNULL(ORDERS.B_State,'') AS B_State,  
           ISNULL(ORDERS.B_Zip,'') AS B_Zip,  
           ORDERS.Consigneekey,  
           ORDERS.C_Company,  
           ORDERS.C_Address1,  
           ORDERS.C_Address2,  
           ISNULL(ORDERS.C_City,'') AS C_City,  
           ISNULL(ORDERS.C_State,'') AS C_State,  
           ISNULL(ORDERS.C_Zip,'') AS C_Zip,  
           ORDERS.Externorderkey,  
           ORDERS.Deliverydate,  
           ORDERS.C_fax2,  
           ORDERS.M_Fax1,  
           ORDERS.Buyerpo,  
           ORDERS.Invoiceno,  
           ORDERS.Orderkey,  
           LOADPLAN.Loadkey,  
           PICKDETAIL.Loc,  
           SKU.Style,  
           SKU.Color,  
           SKU.Size,  
           SKU.Busr1,  
           SKU.Busr8,                  
           SUM(PICKDETAIL.Qty) AS Qty,  
           ORDERDETAIL.Unitprice,  
           ORDERDETAIL.Tax01,  
           ORDERDETAIL.Tax02,  
           ORDERDETAIL.Extendedprice,  
           (SUM(PICKDETAIL.Qty) * ORDERDETAIL.Unitprice) + ORDERDETAIL.Tax01 - ORDERDETAIL.Tax02 + ORDERDETAIL.Extendedprice AS Amount,  
           ORDERDETAIL.Sku,  
           ORDERDETAIL.Userdefine01 AS ODUserdefine01,  
           ORDERDETAIL.Userdefine02 AS ODUserdefine02,  
           ORDERDETAIL.Userdefine05 AS ODUserdefine05,  
           ORDERS.Userdefine10 AS OUserdefine10,  
           ORDERS.Invoiceamount,  
           ISNULL(SUBSTRING(ORDERS.Notes,1,250),'') AS Notes1a,  
           ISNULL(SUBSTRING(ORDERS.Notes,251,250),'') AS Notes1b,  
           ISNULL(SUBSTRING(ORDERS.Notes,501,250),'') AS Notes1c,  
           ISNULL(SUBSTRING(ORDERS.Notes,751,250),'') AS Notes1d,  
           ISNULL(SUBSTRING(ORDERS.Notes2,1,250),'') AS Notes2a,  
           ISNULL(SUBSTRING(ORDERS.Notes2,251,250),'') AS Notes2b,             
           ISNULL(SUBSTRING(ORDERS.Notes2,501,250),'') AS Notes2c,  
           ISNULL(SUBSTRING(ORDERS.Notes2,751,250),'') AS Notes2d,  
           STORER.Company,  
           FACILITY.Descr,  
           FACILITY.Userdefine01 AS FUserdefine01,  
           FACILITY.Userdefine03 AS FUserdefine03,  
           RTRIM(LEFT(FACILITY.Userdefine04,5))+'-'+RTRIM(LTRIM(RIGHT(FACILITY.Userdefine04,4))) AS FUSERDEFINE45,  
           suser_sname() AS UserName,  
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo
                     AND Orderkey = ORDERS.Orderkey AND  Zone = 'LP') , 'N') AS PrintedFlag,  
           ORDERS.Pokey,  
           LOC.Putawayzone,   
           LOC.Logicallocation,  
           LOC.Pickzone,
           ORDERDETAIL.Userdefine06 AS ODUserdefine06,  
           ISNULL(STORER.Address1,'') AS Address1,  
           ISNULL(STORER.Address2,'') AS Address2,  
           ISNULL(STORER.City,'') AS City,  
           ISNULL(STORER.State,'') AS State,  
           ISNULL(STORER.Zip,'') AS Zip,             
           ISNULL(STORER.Phone1,'') AS Phone1,             
           ISNULL(STORER.Fax1,'') AS Fax1,  
           ORDERS.B_Contact1,  
           ORDERS.C_Contact1,  
           ORDERDETAIL.ManufacturerSku,  
           ORDERS.DeliveryNote AS ODeliveryNote,
           CONVERT(NVARCHAR(255),ISNULL(STORER.Notes1,''))  AS Remarks         
    INTO #TEMP_PICK             
    FROM LOADPLAN (NOLOCK)   
    JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)  
    JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
    JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)  
    JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
    JOIN STORER (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)  
    JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey   
                          AND ORDERDETAIL.Sku = SKU.Sku)   
    JOIN PICKDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey   
                                 AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)  
    JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)  
    LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)
    WHERE LOADPLAN.Loadkey = @c_loadkey  
    GROUP BY RefKeyLookup.PickSlipNo,  
           ORDERS.Billtokey,  
           ORDERS.B_Company,  
           ORDERS.B_Address1,  
           ORDERS.B_Address2,  
           ISNULL(ORDERS.B_City,''),  
           ISNULL(ORDERS.B_State,''),  
           ISNULL(ORDERS.B_Zip,''),  
           ORDERS.Consigneekey,  
           ORDERS.C_Company,  
           ORDERS.C_Address1,  
           ORDERS.C_Address2,  
           ISNULL(ORDERS.C_City,''),  
           ISNULL(ORDERS.C_State,''),  
           ISNULL(ORDERS.C_Zip,''),  
           ORDERS.Externorderkey,  
           ORDERS.Deliverydate,  
           ORDERS.C_fax2,  
           ORDERS.M_Fax1,  
           ORDERS.Buyerpo,  
           ORDERS.Invoiceno,  
           ORDERS.Orderkey,  
           LOADPLAN.Loadkey,  
           PICKDETAIL.Loc,  
           SKU.Style,  
           SKU.Color,  
           SKU.Size,  
           SKU.Busr1,  
           SKU.Busr8,                  
           ORDERDETAIL.Unitprice,  
           ORDERDETAIL.Tax01,  
           ORDERDETAIL.Tax02,  
           ORDERDETAIL.Extendedprice,  
           ORDERDETAIL.Sku,  
           ORDERDETAIL.Userdefine01,  
           ORDERDETAIL.Userdefine02,  
           ORDERDETAIL.Userdefine05,  
           ORDERS.Userdefine10,  
           ORDERS.Invoiceamount,  
           ISNULL(SUBSTRING(ORDERS.Notes,1,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes,251,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes,501,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes,751,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes2,1,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes2,251,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes2,501,250),''),  
           ISNULL(SUBSTRING(ORDERS.Notes2,751,250),''),  
           STORER.Company,  
           FACILITY.Descr,  
           FACILITY.Userdefine01,  
           FACILITY.Userdefine03,  
           RTRIM(LEFT(FACILITY.Userdefine04,5))+'-'+RTRIM(LTRIM(RIGHT(FACILITY.Userdefine04,4))),  
           ORDERS.Pokey,  
           LOC.Putawayzone,   
           LOC.Logicallocation,  
           LOC.Pickzone,
           ORDERDETAIL.Userdefine06,  
           ISNULL(STORER.Address1,''),  
           ISNULL(STORER.Address2,''),  
           ISNULL(STORER.City,''),   
           ISNULL(STORER.State,''),   
           ISNULL(STORER.Zip,''),  
           ISNULL(STORER.Phone1,''),             
           ISNULL(STORER.Fax1,''),             
           ORDERS.B_Contact1,  
           ORDERS.C_Contact1,  
           ORDERDETAIL.ManufacturerSku,  
           ORDERS.DeliveryNote,
           CONVERT(NVARCHAR(255),ISNULL(STORER.Notes1,''))     

   BEGIN TRAN    
   
   -- Uses PickType as a Printed Flag    
   UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL   
       FROM   PickHeader
       JOIN   #TEMP_PICK ON  (PickHeader.Orderkey = #TEMP_PICK.Orderkey)
       WHERE  PickHeader.Zone = 'LP'
--       WHERE ExternOrderKey = @c_LoadKey   
--       AND Zone = 'LP'   
  
   SELECT @n_err = @@ERROR   
   
   IF @n_err <> 0     
   BEGIN    
      SELECT @n_continue = 3    
      IF @@TRANCOUNT >= 1    
      BEGIN    
         ROLLBACK TRAN    
      END    
   END    
   ELSE 
   BEGIN    
      IF @@TRANCOUNT > 0     
      BEGIN    
         COMMIT TRAN    
      END    
      ELSE 
      BEGIN    
         SELECT @n_continue = 3    
         ROLLBACK TRAN    
      END    
   END    

   SET @c_LoadKey = ''  
   SET @c_OrderKey = ''  
   SET @c_PickDetailKey = ''  
   SET @n_Continue = 1   
  
   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT LoadKey, OrderKey, Pickzone   
   FROM   #TEMP_PICK   
   WHERE  PickSlipNo IS NULL or PickSlipNo = ''  
   ORDER BY LoadKey, Pickzone, Orderkey

   OPEN C_LoadKey_ExternOrdKey   
  
   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_OrderKey, @c_Pickzone    
  
   WHILE (@@Fetch_Status <> -1)  
   BEGIN -- while 1  
      IF ISNULL(@c_OrderKey, '0') = '0'  
         BREAK  
  
      IF @c_PrevLoadKey <> @c_LoadKey OR   
         @c_PrevOrderKey <> @c_OrderKey OR
         @c_PrevPickzone <> @c_Pickzone   
      BEGIN       
         SET @c_PickSlipNo = ''  
  
-- now possible to have 1 loadkey/orderkey having multiple pickheader record so cannot perform
-- the below checking
--         SELECT @c_PickSlipNo = PICKHEADERKEY  
--         FROM PICKHEADER (NOLOCK)   
--         WHERE ExternOrderKey = @c_LoadKey AND OrderKey = @c_OrderKey  
--           AND Zone = 'LP'  
  
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

            INSERT PICKHEADER (pickheaderkey, OrderKey,    zone, PickType,   Wavekey)  
                       VALUES (@c_PickSlipNo, @c_OrderKey, 'LP', '0',  @c_PickSlipNo)  

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
  
         IF @n_Continue = 1   
         BEGIN  
            DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber    
            FROM   PickDetail WITH (NOLOCK)  
            JOIN   OrderDetail WITH (NOLOCK) 
                   ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
                       PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
            JOIN   LOC WITH (NOLOCK)
                   ON (PICKDETAIL.Loc = LOC.Loc)
            JOIN   LOADPLANDETAIL LD (NOLOCK) ON LD.ORDERKEY = ORDERDETAIL.OrderKey                   
            WHERE  OrderDetail.OrderKey = @c_OrderKey    
            AND    LD.LoadKey   = @c_LoadKey  
            AND    Loc.PickZone = @c_PickZone
            ORDER BY PickDetail.PickDetailKey   
  
            OPEN C_PickDetailKey  
  
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber   
  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
               BEGIN   
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
                  VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey)                          
               END   
  
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber   
            END   
            CLOSE C_PickDetailKey   
            DEALLOCATE C_PickDetailKey   
  
         END   
        
      END -- @c_PrevLoadKey <> @c_LoadKey OR @c_PrevOrderKey <> @c_OrderKey OR  @c_PrevPickzone <> @c_Pickzone   
  
      UPDATE #TEMP_PICK  
         SET PickSlipNo = @c_PickSlipNo  
      WHERE OrderKey = @c_OrderKey  
      AND   LoadKey = @c_LoadKey         
      AND   PickZone = @c_Pickzone
      AND   (PickSlipNo IS NULL OR PickSlipNo = '')  

      SET @c_PrevLoadKey = @c_LoadKey   
      SET @c_PrevOrderKey = @c_OrderKey 
      SET @c_PrevPickzone = @c_Pickzone 
  
      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_OrderKey, @c_Pickzone       
   END -- while 1   
  
   CLOSE C_LoadKey_ExternOrdKey  
   DEALLOCATE C_LoadKey_ExternOrdKey   
  
   SELECT  Pickslipno,                                                                  
           Billtokey,  
           B_Company,  
           B_Address1,  
           B_Address2,  
           B_City,  
           B_State,  
           B_Zip,  
           Consigneekey,  
           C_Company,  
           C_Address1,  
           C_Address2,  
           C_City,  
           C_State,  
           C_Zip,  
           Externorderkey,  
           Deliverydate,  
           C_fax2,  
           M_Fax1,  
           Buyerpo,  
           Invoiceno,  
           Orderkey,  
           Loadkey,  
           Loc,  
           Style,  
           Color,  
           Size,  
           Busr1,  
           Qty,  
           Unitprice,  
           Tax01,  
           Tax02,  
           Extendedprice,  
           Amount,  
           Sku,  
           ODUserdefine01,  
           ODUserdefine02,  
           ODUserdefine05,  
           OUserdefine10,  
           Invoiceamount,  
           Notes1a,  
           Notes1b,  
           Notes1c,  
           Notes1d,  
           Notes2a,  
           Notes2b,             
           Notes2c,  
           Notes2d,  
           Company,  
           Descr,  
           FUserdefine01,  
           FUserdefine03,  
           FUSERDEFINE45,  
           UserName,  
           PrintedFlag,  
           Pokey,  
           Putawayzone,   
           Logicallocation,  
           ODUserdefine06,  
           Address1,  
           Address2,  
           City,  
           State,  
           Zip,             
           Phone1,             
           Fax1,  
           B_Contact1,  
           C_Contact1,  
           ManufacturerSku,  
           ODeliveryNote,
           Remarks,
           PickZone       
   FROM #TEMP_PICK
   ORDER BY LoadKey, Pickzone, OrderKey, Pickslipno   

  
   DROP Table #TEMP_PICK    

END  

GO