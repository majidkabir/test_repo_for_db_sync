SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Proc : isp_GetPickSlipOrders78                                   */  
/* Creation Date:28/03/2018                                                */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:  WMS-4387 - Modified from nsp_GetPickSlipOrders41              */  
/*                                                                         */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: r_dw_print_pickorder78                                       */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author      Ver   Purposes                                  */  
/* 2020-11-19  WLChooi     1.1   WMS-15729 - Show Full Route (WL01)        */
/***************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipOrders78] (@c_loadkey NVARCHAR(10))   
 AS  
 BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
    DECLARE @c_pickheaderkey NVARCHAR(10),  
   @n_continue         int,  
   @c_errmsg           NVARCHAR(255),  
   @b_success          int,  
   @n_err              int,  
   @c_sku              NVARCHAR(20),  
   @n_qty              int,  
   @c_loc              NVARCHAR(10),  
   @n_cases            int,  
   @n_perpallet        int,  
   @c_storer           NVARCHAR(15),  
   @c_orderkey         NVARCHAR(10),  
   @c_ConsigneeKey     NVARCHAR(15),  
   @c_Company          NVARCHAR(45),  
   @c_Addr1            NVARCHAR(45),  
   @c_Addr2            NVARCHAR(45),  
   @c_Addr3            NVARCHAR(45),  
   @c_PostCode         NVARCHAR(15),  
   @c_Route            NVARCHAR(10),  
   @c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc  
   @c_TrfRoom          NVARCHAR(5),  -- LoadPlan.TrfRoom  
   @c_Notes1           NVARCHAR(60),  
   @c_Notes2           NVARCHAR(60),  
   @c_SkuDesc          NVARCHAR(60),  
   @n_CaseCnt          int,  
   @n_PalletCnt        int,  
   @c_ReceiptTm        NVARCHAR(20),  
   @c_PrintedFlag      NVARCHAR(1),  
   @c_UOM              NVARCHAR(10),  
   @n_UOM3             int,  
   @c_Lot              NVARCHAR(10),  
   @c_StorerKey        NVARCHAR(15),  
   @c_Zone             NVARCHAR(1),  
   @n_PgGroup          int,  
   @n_TotCases         int,  
   @n_RowNo            int,  
   @c_PrevSKU          NVARCHAR(20),  
   @n_SKUCount         int,  
   @c_Carrierkey       NVARCHAR(60),  
   @c_VehicleNo        NVARCHAR(10),  
   @c_firstorderkey    NVARCHAR(10),  
   @c_superorderflag   NVARCHAR(1),  
   @c_firsttime        NVARCHAR(1),  
   @c_logicalloc       NVARCHAR(18),  
   @c_Lottable02       NVARCHAR(10), -- SOS14561  
   @d_Lottable04       datetime,  
   @n_packpallet       int,  
   @n_packcasecnt      int,  
   @c_externorderkey   NVARCHAR(30),    
   @n_pickslips_required int,    
   @c_areakey          NVARCHAR(10),  
   @c_skugroup         NVARCHAR(10) -- SOS144415    
                    
    DECLARE @c_PrevOrderKey NVARCHAR(10),  
            @n_Pallets      int,  
            @n_Cartons      int,  
            @n_Eaches       int,  
            @n_UOMQty       int  
            
    CREATE TABLE #TEMP_PICK78  
       ( PickSlipNo       NVARCHAR(10) NULL,  
         LoadKey          NVARCHAR(10),  
         OrderKey         NVARCHAR(10),  
         ConsigneeKey     NVARCHAR(15),  
         Company          NVARCHAR(45),  
         Addr1            NVARCHAR(45) NULL,  
         Addr2            NVARCHAR(45) NULL,  
         Addr3            NVARCHAR(45) NULL,  
         PostCode         NVARCHAR(15) NULL,  
         Route            NVARCHAR(10) NULL,  
         Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc  
         TrfRoom          NVARCHAR(5) NULL,  -- LoadPlan.TrfRoom  
         Notes1           NVARCHAR(60) NULL,  
         Notes2           NVARCHAR(60) NULL,  
         LOC              NVARCHAR(10) NULL,   
         ID               NVARCHAR(18) NULL,    -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
         SKU              NVARCHAR(20),  
         SkuDesc          NVARCHAR(60),  
         Qty              int,  
         TempQty1         int,  
         TempQty2         int,  
         PrintedFlag      NVARCHAR(1) NULL,  
         Zone             NVARCHAR(1),  
         PgGroup          int,  
         RowNum           int,  
         Lot              NVARCHAR(10),  
         Carrierkey       NVARCHAR(60) NULL,  
         VehicleNo        NVARCHAR(10) NULL,  
         Lottable02       NVARCHAR(18) NULL, -- SOS14561  
         Lottable04       datetime NULL,  
         packpallet       int,  
         packcasecnt      int,   
         packinner        int,     -- sos 7545 wally 27.aug.2002  
         packeaches       int,       -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
         externorderkey   NVARCHAR(30) NULL,  
         LogicalLoc       NVARCHAR(18) NULL,    
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)  
         UOM              NVARCHAR(10),          -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)  
         Pallet_cal       int,    
         Cartons_cal      int,    
         inner_cal        int,     -- sos 7545 wally 27.aug.2002   
         Each_cal         int,    
         Total_cal        int,       -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
         DeliveryDate     datetime NULL,  
         RetailSku        NVARCHAR(20) NULL,  -- Added by MaryVong on 22Sept04 (SOS27518)  
         BuyerPO          NVARCHAR(20) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)  
         InvoiceNo        NVARCHAR(10) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)  
         OrderDate        datetime NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)  
         Susr4            NVARCHAR(18) NULL,  -- sos 26373 wally 18.oct.2004  
         vat              NVARCHAR(18) NULL,  
         OVAS             NVARCHAR(30) NULL,  -- SOS41046  
         SKUGROUP         NVARCHAR(10) NULL, -- SOS144415    
         ContainerType    NVARCHAR(20) NULL,
         RptGrp           NVARCHAR(1)  NULL,
         ShowFullRoute    NVARCHAR(10) NULL   --WL01
       )  
         
       INSERT INTO #TEMP_PICK78  
            (PickSlipNo,          LoadKey,         OrderKey,   ConsigneeKey,  
             Company,             Addr1,           Addr2,         PgGroup,  
             Addr3,               PostCode,        Route,  
             Route_Desc,          TrfRoom,         Notes1,        RowNum,  
             Notes2,              LOC,             ID,            SKU,  
             SkuDesc,             Qty,             TempQty1,  
             TempQty2,            PrintedFlag,     Zone,  
             Lot,                 CarrierKey,      VehicleNo,     Lottable02, -- SOS14561  
             Lottable04,          packpallet,       packcasecnt,  packinner,    
             packeaches,          externorderkey,  LogicalLoc,  Areakey,    UOM,   
             Pallet_cal,          Cartons_cal,      inner_cal,   Each_cal,   Total_cal,   
             DeliveryDate,        RetailSku,        BuyerPO,      InvoiceNo,  OrderDate,  
             Susr4,               Vat,                OVAS,         SKUGROUP,    ContainerType,RptGrp, -- SOS144415  
             ShowFullRoute )   --WL01
        SELECT  (SELECT PICKHEADERKEY FROM PICKHEADER   
                   WHERE ExternOrderKey = @c_LoadKey   
                   AND OrderKey = PickDetail.OrderKey   
                   AND ZONE = '3'),  
        @c_LoadKey as LoadKey,                   
        PickDetail.OrderKey,                              
    -- Changed by YokeBeen on 08-Aug-2002 (Ticket # 6692) - from BillToKey to ConsigneeKey.    
        IsNull(ORDERS.ConsigneeKey, '') AS ConsigneeKey,    
        IsNull(ORDERS.c_Company, '')  AS Company,     
        IsNull(ORDERS.C_Address1,'') AS Addr1,              
        IsNull(ORDERS.C_Address2,'')  AS Addr2,  
        0 AS PgGroup,                                
        IsNull(ORDERS.C_Address3,'') AS Addr3,              
        IsNull(ORDERS.C_Zip,'') AS PostCode,  
        IsNull(ORDERS.Route,'') AS Route,           
        IsNull(RouteMaster.Descr, '') Route_Desc,         
        ORDERS.Door AS TrfRoom,  
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) Notes1,                                      
        0 AS RowNo,   
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) Notes2,  
        PickDetail.loc,     
        PickDetail.id,    -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
        PickDetail.sku,                           
        IsNULL(Sku.Descr,'') SkuDescr,                
        SUM(PickDetail.qty) as Qty,  
        --CASE PickDetail.UOM  
        --     WHEN '1' THEN PACK.Pallet     
        --     WHEN '2' THEN PACK.CaseCnt      
        --     WHEN '3' THEN PACK.InnerPack    
        --     ELSE 1  END AS UOMQty,  
        1 AS UOMQTY, --NJOW01  
        0 AS TempQty2,  
        IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,   
        '3' Zone,  
        Pickdetail.Lot,                           
        '' CarrierKey,                                    
        '' AS VehicleNo,  
        LotAttribute.Lottable02, -- SOS14561                 
        IsNUll(LotAttribute.Lottable04, '19000101') Lottable04,          
        PACK.Pallet,  
        PACK.CaseCnt,  
        pack.innerpack, -- sos 7545 wally 27.aug.2002  
        PACK.Qty,     -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
        ORDERS.ExternOrderKey AS ExternOrderKey,                 
        ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,   
        IsNull(AreaDetail.AreaKey, '00') AS Areakey,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)  
        IsNull(OrderDetail.UOM, '') AS UOM,            -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)  
         /* Added By YokeBeen on 20-Mar-2002 (Ticket # 2539 / 3377) - Start */  
        Pallet_cal = case Pack.Pallet when 0 then 0   
                         else FLOOR(SUM(PickDetail.qty) / Pack.Pallet)    
                         end,    
        Cartons_cal = 0,  
        inner_cal = 0,  
        Each_cal = 0,  
        Total_cal = sum(pickdetail.qty),  
        IsNUll(ORDERS.DeliveryDate, '19000101') DeliveryDate,         
        /* Added By YokeBeen on 20-Mar-2002 (Ticket # 2539 / 3377) - End */  
        IsNULL(Sku.RetailSku,'') RetailSku,        -- Added by MaryVong on 22Sept04 (SOS27518)  
        IsNULL(ORDERS.BuyerPO,'') BuyerPO,        -- Added by MaryVong on 23Sept04 (SOS27518)  
        IsNULL(ORDERS.InvoiceNo,'') InvoiceNo,       -- Added by MaryVong on 23Sept04 (SOS27518)  
        IsNUll(ORDERS.OrderDate, '19000101') OrderDate,   -- Added by MaryVong on 23Sept04 (SOS27518)  
        SKU.Susr4,               -- sos 26373 wally 18.oct.2004  
        ST.vat,  
        SKU.OVAS, -- SOS41046  
        SKU.SKUGROUP, -- SOS#144415   
        ORDERS.ContainerType,
        Rptgrp = CASE WHEN SKU.SKUGROUP = 'F' THEN '1' ELSE '2' END,
        ISNULL(CL.Short,'N') AS ShowFullRoute   --WL01
     FROM pickdetail (nolock)  
         join orders (nolock)  
          on pickdetail.orderkey = orders.orderkey  
         join lotattribute (nolock)  
          on pickdetail.lot = lotattribute.lot  
         join loadplandetail (nolock)  
          on pickdetail.orderkey = loadplandetail.orderkey  
         join orderdetail (nolock)  
          on pickdetail.orderkey = orderdetail.orderkey and pickdetail.orderlinenumber = orderdetail.orderlinenumber     
         join storer (nolock)  
          on pickdetail.storerkey = storer.storerkey  
         join sku (nolock)  
          on pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey  
         join pack (nolock)  
          on pickdetail.packkey = pack.packkey  
         join loc (nolock)  
          on pickdetail.loc = loc.loc  
         left outer join routemaster (nolock)  
          on orders.route = routemaster.route  
         left outer join areadetail (nolock)  
          on loc.putawayzone = areadetail.putawayzone  
         left outer join storer st (nolock)  
          on orders.consigneekey = st.storerkey  
         LEFT OUTER JOIN CODELKUP CL (NOLOCK)   --WL01
          ON CL.Listname = 'REPORTCFG' AND CL.Storerkey = ORDERS.Storerkey AND   --WL01
             CL.Code = 'ShowFullRoute' AND CL.Long = 'r_dw_print_pickorder78'    --WL01
     WHERE PickDetail.Status < '5'    
       AND LoadPlanDetail.LoadKey = @c_LoadKey  
     GROUP BY PickDetail.OrderKey,                              
    -- Changed by YokeBeen on 08-Aug-2002 (Ticket # 6692) - from BillToKey to ConsigneeKey.    
        IsNull(ORDERS.ConsigneeKey, ''),  
        IsNull(ORDERS.c_Company, ''),     
        IsNull(ORDERS.C_Address1,''),  
        IsNull(ORDERS.C_Address2,''),  
        IsNull(ORDERS.C_Address3,''),  
        IsNull(ORDERS.C_Zip,''),  
        IsNull(ORDERS.Route,''),  
        IsNull(RouteMaster.Descr, ''),  
        ORDERS.Door,  
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')),                                      
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')),  
        PickDetail.loc,     
        PickDetail.id,    -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
        PickDetail.sku,                           
        IsNULL(Sku.Descr,''),                  
        --CASE PickDetail.UOM  
        --     WHEN '1' THEN PACK.Pallet     
        --     WHEN '2' THEN PACK.CaseCnt      
        --     WHEN '3' THEN PACK.InnerPack    
        --     ELSE 1  END,  
        Pickdetail.Lot,                           
        LotAttribute.Lottable02,  -- SOS14561  
        IsNUll(LotAttribute.Lottable04, '19000101'),          
        PACK.Pallet,  
        PACK.CaseCnt,  
        pack.innerpack,  -- sos 7545 wally 27.aug.2002  
        PACK.Qty,     -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)   
        ORDERS.ExternOrderKey,  
        ISNULL(LOC.LogicalLocation, ''),    
        IsNull(AreaDetail.AreaKey, '00'),     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)  
        IsNull(OrderDetail.UOM, ''),          -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)  
        IsNUll(ORDERS.DeliveryDate, '19000101'),  
        IsNULL(Sku.RetailSku,''),        -- Added by MaryVong on 22Sept04 (SOS27518)  
        IsNULL(ORDERS.BuyerPO,''),        -- Added by MaryVong on 23Sept04 (SOS27518)  
        IsNULL(ORDERS.InvoiceNo,''),       -- Added by MaryVong on 23Sept04 (SOS27518)  
        IsNUll(ORDERS.OrderDate, '19000101'),      -- Added by MaryVong on 23Sept04 (SOS27518)  
        SKU.Susr4,            -- sos 26373 wally 18.oct.2004  
        ST.vat,  
        SKU.OVAS, -- SOS41046  
        SKU.SKUGROUP, -- SOS#144415  
        ORDERS.ContainerType,
        CASE WHEN SKU.SKUGROUP = 'F' THEN '1' ELSE '2' END,
        ISNULL(CL.Short,'N')   --WL01
  -- SOS 7236  
  -- wally 16.aug.2002  
  -- commented the cursor below and instead update directly the temp table  
  -- update case qty  
  update #TEMP_PICK78  
  set cartons_cal = case packcasecnt  
         when 0 then 0  
         --else floor(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)  
         else floor(total_cal/packcasecnt)  --NJOW01  
        end  
    
  -- update inner qty  
  update #TEMP_PICK78  
  set inner_cal = case packinner  
        when 0 then 0  
        --else floor(total_cal/packinner) -   
        --  ((packpallet*pallet_cal)/packinner) - ((packcasecnt*cartons_cal)/packinner)  
        else floor(total_cal/packinner) - ((packcasecnt*cartons_cal)/packinner) --NJOW01  
        end  
    
  -- update each qty  
  update #TEMP_PICK78  
  --set each_cal = total_cal - (packpallet*pallet_cal) - (packcasecnt*cartons_cal) - (packinner*inner_cal)  
  set each_cal = total_cal - (packcasecnt*cartons_cal) - (packinner*inner_cal) --NJOW01  
  
     BEGIN TRAN    
     -- Uses PickType as a Printed Flag    
     UPDATE PickHeader with (RowLOck)    -- tlting01
      SET PickType = '1', TrafficCop = NULL   
     WHERE ExternOrderKey = @c_LoadKey   
     AND Zone = '3'   
     SELECT @n_err = @@ERROR    
     IF @n_err <> 0     
     BEGIN    
         SELECT @n_continue = 3    
         IF @@TRANCOUNT >= 1    
         BEGIN    
             ROLLBACK TRAN    
         END    
     END    
     ELSE BEGIN    
         IF @@TRANCOUNT > 0     
         BEGIN    
             COMMIT TRAN    
         END    
         ELSE BEGIN    
             SELECT @n_continue = 3    
             ROLLBACK TRAN    
         END    
     END    
     SELECT @n_pickslips_required = Count(DISTINCT OrderKey)   
     FROM #TEMP_PICK78  
     WHERE PickSlipNo IS NULL  
     IF @@ERROR <> 0  
     BEGIN  
         GOTO FAILURE  
     END  
     ELSE IF @n_pickslips_required > 0  
     BEGIN  
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
 --             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +   
 --             dbo.fnc_LTrim( dbo.fnc_RTrim(  
 --                STR(   
 --                   CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey)   
 --                                                     from #TEMP_PICK78 as Rank   
 --                                                     WHERE Rank.OrderKey < #TEMP_PICK78.OrderKey )   
 --                    ) -- str  
 --                    )) -- dbo.fnc_RTrim  
 --                 , 9)   
 --              , OrderKey, LoadKey, '0', '8', ''  
 --             FROM #TEMP_PICK78 WHERE PickSlipNo IS NULL  
 --             GROUP By LoadKey, OrderKey  
         INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +   
             dbo.fnc_LTrim( dbo.fnc_RTrim(  
                STR(   
                   CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey)   
                                                     from #TEMP_PICK78 as Rank   
                                                     WHERE Rank.OrderKey < #TEMP_PICK78.OrderKey )   
                    ) -- str  
                    )) -- dbo.fnc_RTrim  
                 , 9)   
              , OrderKey, LoadKey, '0', '3', ''  
             FROM #TEMP_PICK78 WHERE PickSlipNo IS NULL  
             GROUP By LoadKey, OrderKey  
         UPDATE #TEMP_PICK78   
         SET PickSlipNo = PICKHEADER.PickHeaderKey  
         FROM PICKHEADER (NOLOCK)  
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK78.LoadKey  
         AND   PICKHEADER.OrderKey = #TEMP_PICK78.OrderKey  
         AND   PICKHEADER.Zone = '3'  
   AND   #TEMP_PICK78.PickSlipNo IS NULL  
     END  
     GOTO SUCCESS  
 FAILURE:  
     DELETE FROM #TEMP_PICK78  
 SUCCESS:  
     SELECT * FROM #TEMP_PICK78  
      
   DROP Table #TEMP_PICK78    
 END
 

GO