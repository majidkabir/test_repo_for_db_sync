SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nsp_GetPickSlipOrders59                            */  
/* Creation Date: 08-Mac-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: AQSKC                                                    */  
/*                                                                      */  
/* Purpose: SFC pick list SOS#XXXXXX                                    */  
/*          -Pickslip by Pickzone                                       */
/*          -One SKU will be located in 1 pickzone only & never         */
/*           multiple pickzone                                          */                           
/*                                                                      */  
/* Called By: r_dw_print_pickorder59                                    */  
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
  
CREATE PROC [dbo].[nsp_GetPickSlipOrders59] (@c_loadkey NVARCHAR(10))  
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
           @c_Orderlinenumber    NVARCHAR(5),
           @c_UOM                NVARCHAR(50),
           @c_PrevUOM            NVARCHAR(50) 
                
    SELECT RefKeyLookup.PickSlipNo AS PickSlipNo, 
           LOADPLAN.Loadkey AS LoadKey,
           ORDERS.Orderkey AS Orderkey,
           ORDERS.Consigneekey AS ConsigneeKey, 
           ORDERS.C_Company AS Company,  
           ORDERS.C_Address1 AS Addr1,  
           ORDERS.C_Address2 AS Addr2, 
           IsNull(ORDERS.C_Address3,'') AS Addr3,  
           ISNULL(ORDERS.C_Zip,'') AS PostCode,  
           ISNull(ORDERS.Route,'') AS Route, 
           ISNull(RouteMaster.Descr, '') Route_Desc,
           ORDERS.Door AS TrfRoom,
           CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) Notes1,                                    
          -- 0 AS RowNo, 
           CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) Notes2,
           PICKDETAIL.Loc AS LOC,  
           PickDetail.id AS ID,
           SKU.SKU AS SKU,
           ISNULL(Sku.Descr,'') AS SkuDesc,
           SUM(PICKDETAIL.Qty) AS Qty,
           CASE PickDetail.UOM
             WHEN '1' THEN PACK.Pallet   
             WHEN '2' THEN PACK.CaseCnt    
             WHEN '3' THEN PACK.InnerPack  
             ELSE 1  END  AS TempQty1,
           0 AS TempQty2,
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo
                     AND Orderkey = ORDERS.Orderkey AND  Zone = 'LP') , 'N') AS PrintedFlag,  

           'LP' AS Zone,
           0 AS PgGroup,
           0 AS RowNo,
           Pickdetail.Lot AS LOT,                         
           ORDERS.DischargePlace AS CarrierKey,   
           '' AS VehicleNo,
           LotAttribute.Lottable02 AS Lottable02,                
           IsNUll(LotAttribute.Lottable04, '19000101') AS Lottable04,        
           PACK.Pallet AS packpallet,
           PACK.CaseCnt AS packcasecnt,
           pack.innerpack AS packinner, 
           PACK.Qty AS packeaches,             
           ORDERS.ExternOrderKey AS ExternOrderKey,               
           ISNULL(LOC.LogicalLocation, '') AS LogicalLocation, 
           IsNull(AreaDetail.AreaKey, '00') AS Areakey,    
           IsNull(OrderDetail.UOM, '') AS UOM,            
           case Pack.Pallet when 0 then 0 
                           else FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
                        end AS Pallet_cal,  
           0 as Cartons_cal,
           0 AS inner_cal,
           0 AS Each_cal,
           sum(pickdetail.qty) AS Total_cal,
           IsNUll(ORDERS.DeliveryDate, '19000101') AS DeliveryDate        
          ,LotAttribute.Lottable01  AS   Lottable01                  
          ,LotAttribute.Lottable03  AS    Lottable03                  
          ,ISNULL(LotAttribute.Lottable05 , '19000101')  AS Lottable05 
          ,ORDERS.DischargePlace AS DischargePlace                        
          ,ORDERS.InvoiceNo  AS InvoiceNo        
          ,'' AS Pltcnt                    
          ,IsNull(ORDERS.C_Address4,'') AS Addr4            
          ,IsNull(ORDERS.C_City,'')  AS City
          ,IsNull(ORDERS.Storerkey,'')  AS Storerkey
          ,CASE WHEN pickdetail.uom = '1' THEN 'PALLET PICKING LIST' ELSE 'EACH PICKING LIST' END  as RptTitle 
          ,ORDERS.ExternPOKey       
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
    JOIN lotattribute WITH (NOLOCK) ON pickdetail.lot = lotattribute.lot
    JOIN pack WITH (NOLOCK) ON pickdetail.packkey = pack.packkey
    LEFT OUTER JOIN areadetail WITH (NOLOCK) ON loc.putawayzone = areadetail.putawayzone
    lEFT OUTER JOIN routemaster WITH (NOLOCK) ON ORDERS.route = routemaster.route
    LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)
    WHERE LOADPLAN.Loadkey = @c_loadkey  
   GROUP BY RefKeyLookup.PickSlipNo,  
           LOADPLAN.Loadkey,
           ORDERS.Orderkey,
           ORDERS.Consigneekey, 
           ORDERS.C_Company,  
           ORDERS.C_Address1 ,  
           ORDERS.C_Address2 , 
           IsNull(ORDERS.C_Address3,'') ,  
           ISNULL(ORDERS.C_Zip,'') ,  
           ISNull(ORDERS.Route,'') , 
           ISNull(RouteMaster.Descr, '') ,
           ORDERS.Door ,
           CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) ,                                     
           CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) ,
           PICKDETAIL.Loc,  
           PickDetail.id,
           SKU.SKU,
           ISNULL(Sku.Descr,''),
           Pickdetail.Lot,                         
           ORDERS.DischargePlace ,   
           LotAttribute.Lottable02,                
           IsNUll(LotAttribute.Lottable04, '19000101'),        
           PACK.Pallet,
           PACK.CaseCnt,
           pack.innerpack, 
           PACK.Qty,    
           PICKDETAIL.UOM,         
           ORDERS.ExternOrderKey ,               
           ISNULL(LOC.LogicalLocation, '') , 
           IsNull(AreaDetail.AreaKey, '00'),    
           IsNull(OrderDetail.UOM, '') ,            
           IsNUll(ORDERS.DeliveryDate, '19000101')         
          ,LotAttribute.Lottable01                      
          ,LotAttribute.Lottable03                       
          ,ISNULL(LotAttribute.Lottable05 , '19000101')  
          ,ORDERS.DischargePlace                         
          ,ORDERS.InvoiceNo                            
          ,IsNull(ORDERS.C_Address4,'')             
          ,IsNull(ORDERS.C_City,'')  
          ,IsNull(ORDERS.Storerkey,'')
          ,pickdetail.uom   
          ,ORDERS.ExternPOKey    

    BEGIN TRAN    
   
    UPDATE #TEMP_PICK
      SET cartons_cal = case packcasecnt
                           when 0 then 0
                           else floor(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)
                        end
      
      -- update inner qty
      update #TEMP_PICK
      set inner_cal = case packinner
                        when 0 then 0
                        else floor(total_cal/packinner) - 
                              ((packpallet*pallet_cal)/packinner) - ((packcasecnt*cartons_cal)/packinner)
                      end
      
      -- update each qty
      update #TEMP_PICK
      set each_cal = total_cal - (packpallet*pallet_cal) - (packcasecnt*cartons_cal) - (packinner*inner_cal)

      -- Start : SOS101659
      UPDATE #TEMP_PICK
      SET    Pltcnt = TTLPLT.PltCnt
      FROM   ( SELECT Orderkey, PltCnt = COUNT(DISTINCT ISNULL(ID, 0))
               FROM  #temp_Pick
               WHERE ID > ''
               GROUP BY Orderkey ) As TTLPLT
      WHERE #temp_pick.Orderkey = TTLPLT.Orderkey


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
  
   Declare @b_debug nvarchar(1)

   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT LoadKey, OrderKey, zone,RptTitle   
   FROM   #TEMP_PICK   
   WHERE  PickSlipNo IS NULL or PickSlipNo = ''  
   ORDER BY LoadKey, zone, Orderkey,RptTitle

   OPEN C_LoadKey_ExternOrdKey   
  
   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_OrderKey, @c_Pickzone,@c_UOM    
  
   WHILE (@@Fetch_Status <> -1)  
   BEGIN -- while 1  
      IF ISNULL(@c_OrderKey, '0') = '0'  
       BREAK  
  
      IF @c_PrevLoadKey <> @c_LoadKey OR   
         @c_PrevOrderKey <> @c_OrderKey OR
         @c_PrevPickzone <> @c_Pickzone  OR
         @c_PrevUOM <> @c_UOM  
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
      AND   Zone = @c_Pickzone
      AND   (PickSlipNo IS NULL OR PickSlipNo = '')  
      AND RptTitle = @c_UOM

      SET @c_PrevLoadKey = @c_LoadKey   
      SET @c_PrevOrderKey = @c_OrderKey 
      SET @c_PrevPickzone = @c_Pickzone 
      SET @c_PrevUOM = @c_UOM
  
      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_OrderKey, @c_Pickzone,@c_UOM        
   END -- while 1   
  
   CLOSE C_LoadKey_ExternOrdKey  
   DEALLOCATE C_LoadKey_ExternOrdKey   
  
   SELECT * FROM #TEMP_PICK 
   ORDER BY Pickslipno   

        
QUIT:  
   DROP Table #TEMP_PICK    

END  

GO