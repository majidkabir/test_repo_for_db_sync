SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Stored Proc : isp_GetPickSlipOrders52                                   */    
/* Creation Date:                                                          */    
/* Copyright: IDS                                                          */    
/* Written by:                                                             */    
/*                                                                         */    
/* Purpose:  267262-Nike PickSlipNo by PickZone                            */    
/*                                                                         */    
/*                                                                         */    
/* Usage:                                                                  */    
/*                                                                         */    
/* Local Variables:                                                        */    
/*                                                                         */    
/* Called By: r_dw_print_pickorder52                                       */    
/*                                                                         */    
/* PVCS Version: 1.3                                                       */    
/*                                                                         */    
/* Version: 5.4                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date        Author  Ver  Purposes                                       */    
/* 14-Oct-2018  JunYan      1.0   WMS-6405 - Add Priority field, change    */        
/*                                DeliveryDate format to DD/MM/YYYY (CJY01)*/    
/* 08-JAN-2019  CSCHONG     1.1   WMS-7486 Revised deliverydate logic (CS01)*/
/* 16-Jan-2019  SPChin      1.2   INC0543023 - Enhancement & Revise ErrMsg */
/* 28-Jan-2019  TLTING_ext  1.3   enlarge externorderkey field length      */
/* 07-Jan-2010  WLChooi     1.4   WMS-11559 - Add ReportCFG to extend route*/
/*                                column length (WL01)                     */
/***************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickSlipOrders52] (@c_loadkey NVARCHAR(10))     
 AS    
 BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @c_pickheaderkey    NVARCHAR(10),    
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
		   @c_externorderkey   NVARCHAR(50),       --tlting_ext
		   @n_pickslips_required int,      
		   @c_areakey          NVARCHAR(10),    
		   @c_skugroup         NVARCHAR(10), -- SOS144415      
		   @c_Pickzone         NVARCHAR(10), --NJOW01  
		   @c_PrevPickzone     NVARCHAR(10), --NJOW01  
		   @c_Pickslipno       NVARCHAR(10), --NJOW01  
		   @c_Pickdetailkey    NVARCHAR(10), --NJOW01  
		   @c_ExecStatement    NVARCHAR(4000), --NJOW01  
		   @c_OrderLineNumber  NVARCHAR(5) --NJOW01    
                       
    DECLARE @c_PrevOrderKey NVARCHAR(10),    
            @n_Pallets      int,    
            @n_Cartons      int,    
            @n_Eaches       int,    
            @n_UOMQty       int
              
    CREATE TABLE #TEMP_PICK    
       ( PickSlipNo             NVARCHAR(10) NULL,    
         LoadKey                NVARCHAR(10),    
         OrderKey               NVARCHAR(10),    
         ConsigneeKey           NVARCHAR(15),    
         Company                NVARCHAR(45),    
         Addr1                  NVARCHAR(45) NULL,    
         Addr2                  NVARCHAR(45) NULL,    
         Addr3                  NVARCHAR(45) NULL,    
         PostCode               NVARCHAR(15) NULL,    
         Route                  NVARCHAR(10) NULL,    
         Route_Desc             NVARCHAR(60) NULL, -- RouteMaster.Desc    
         TrfRoom                NVARCHAR(5) NULL,  -- LoadPlan.TrfRoom    
         Notes1                 NVARCHAR(60) NULL,    
         Notes2                 NVARCHAR(60) NULL,    
         LOC                    NVARCHAR(10) NULL,     
         ID                     NVARCHAR(18) NULL,    -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)     
         SKU                    NVARCHAR(20),    
         SkuDesc                NVARCHAR(60),    
         Qty                    int,    
         TempQty1               int,    
         TempQty2               int,    
         PrintedFlag            NVARCHAR(1) NULL,    
         Zone                   NVARCHAR(2),    
         PgGroup                int,    
         RowNum                 int,    
         Lot                    NVARCHAR(10),    
         Carrierkey             NVARCHAR(60) NULL,    
         VehicleNo              NVARCHAR(10) NULL,    
         Lottable02             NVARCHAR(18) NULL, -- SOS14561    
         Lottable04             datetime NULL,    
         packpallet             int,    
         packcasecnt            int,     
         packinner              int,     -- sos 7545 wally 27.aug.2002    
         packeaches             int,       -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)     
         externorderkey         NVARCHAR(50) NULL,     --tlting_ext
         LogicalLoc             NVARCHAR(18) NULL,      
         Areakey                NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)    
         UOM                    NVARCHAR(10),          -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)    
         Pallet_cal             int,      
         Cartons_cal            int,      
         inner_cal              int,     -- sos 7545 wally 27.aug.2002     
         Each_cal               int,      
         Total_cal              int,       -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)     
         --DeliveryDate         datetime NULL,     -- (CJY01)          
         DeliveryDate           NVARCHAR(10) NULL,   -- (CJY01)    
         RetailSku              NVARCHAR(20) NULL,  -- Added by MaryVong on 22Sept04 (SOS27518)    
         BuyerPO                NVARCHAR(20) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         InvoiceNo              NVARCHAR(10) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         OrderDate              datetime NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         Susr4                  NVARCHAR(18) NULL,  -- sos 26373 wally 18.oct.2004    
         vat                    NVARCHAR(18) NULL,    
         OVAS                   NVARCHAR(30) NULL,  -- SOS41046    
         SKUGROUP               NVARCHAR(10) NULL, -- SOS144415      
         ContainerType          NVARCHAR(20) NULL,  
         PIckzone               NVARCHAR(10) NULL,  --NJOW01    
         Priority               NVARCHAR(250),       -- (CJY01)   
         ExtendRouteDescLength  NVARCHAR(10) )   --WL01 
           
       INSERT INTO #TEMP_PICK    
            (PickSlipNo,   LoadKey,         OrderKey,   ConsigneeKey,    
             Company,      Addr1,           Addr2,       PgGroup,    
             Addr3,        PostCode,        Route,    
             Route_Desc,   TrfRoom,         Notes1,      RowNum,    
             Notes2,       LOC,             ID,          SKU,    
             SkuDesc,      Qty,             TempQty1,    
             TempQty2,     PrintedFlag,     Zone,    
             Lot,          CarrierKey,      VehicleNo,   Lottable02, -- SOS14561    
             Lottable04,   packpallet,      packcasecnt, packinner,      
             packeaches,   externorderkey,  LogicalLoc,  Areakey,    UOM,     
             Pallet_cal,   Cartons_cal,     inner_cal,   Each_cal,   Total_cal,     
             DeliveryDate, RetailSku,       BuyerPO,     InvoiceNo,  OrderDate,    
             Susr4,        Vat,             OVAS,        SKUGROUP,  ContainerType, -- SOS144415    
             Pickzone, --NJOW01  
             Priority, ExtendRouteDescLength ) -- (CJY01)   --WL01 
        --SELECT  (SELECT PICKHEADERKEY FROM PICKHEADER     
        --       WHERE ExternOrderKey = @c_LoadKey     
        --       AND OrderKey = PickDetail.OrderKey     
        --       AND ZONE = '3'),    
        SELECT RefKeyLookup.PickSlipNo,  --NJOW01         
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
        --IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,     
        ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo  
                     AND Orderkey = Pickdetail.Orderkey AND  Zone = 'LP') , 'N') AS PrintedFlag,  --NJOW01  
        'LP' Zone,   --NJOW01  
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
      --ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,   -- (CJY01)           
      CONVERT(NVARCHAR(10),CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine03, '') = '' THEN ISNULL(ORDERS.DeliveryDate, '19000101') ELSE CAST(ORDERS.UserDefine03 AS DATETIME) END, 103),  -- (CJY01) --(CS01)       
          
      /* Added By YokeBeen on 20-Mar-2002 (Ticket # 2539 / 3377) - End */    
        CASE WHEN IsNULL(Sku.RetailSku,'') = '' THEN  
             ISNULL(Sku.Altsku,'')  
        ELSE Sku.RetailSku END AS RetailSku,  --NJOW01          
        IsNULL(ORDERS.BuyerPO,'') BuyerPO,        -- Added by MaryVong on 23Sept04 (SOS27518)    
        IsNULL(ORDERS.InvoiceNo,'') InvoiceNo,       -- Added by MaryVong on 23Sept04 (SOS27518)    
        IsNUll(ORDERS.OrderDate, '19000101') OrderDate,   -- Added by MaryVong on 23Sept04 (SOS27518)    
      SKU.Susr4,               -- sos 26373 wally 18.oct.2004    
      ST.vat,    
      SKU.OVAS, -- SOS41046    
      SKU.SKUGROUP, -- SOS#144415     
      ORDERS.ContainerType,  
      LOC.Pickzone, --NJOW01  
      CASE WHEN ISNULL(CODELKUP.Long,'') = '' THEN ORDERS.Priority ELSE CODELKUP.Long END, -- (CJY01)    
      ISNULL(CL1.SHORT,'N') AS ExtendRouteDescLength   --WL01
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
        left outer join RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey) --NJOW01   
        LEFT JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.LISTNAME = 'ORDRPRIOR' AND CODELKUP.code = ORDERS.Priority -- (CJY01)   
        LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ExtendRouteDescLength' AND CL1.Storerkey = Orders.StorerKey
                                            AND CL1.Long = 'r_dw_print_pickorder52'   --WL01
     WHERE PickDetail.Status < '5'      
       AND LoadPlanDetail.LoadKey = @c_LoadKey    
     GROUP BY RefKeyLookup.PickSlipNo, --NJOW01   
        PickDetail.OrderKey,                                
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
        --  ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,   -- (CJY01)           
        CONVERT(NVARCHAR(10),CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine03, '') = '' THEN ISNULL(ORDERS.DeliveryDate, '19000101') ELSE CAST(ORDERS.UserDefine03 AS DATETIME) END, 103),  -- (CJY01)  --(CS01)      
        CASE WHEN IsNULL(Sku.RetailSku,'') = '' THEN  
        ISNULL(Sku.Altsku,'')  
        ELSE Sku.RetailSku END,  --NJOW01          
        IsNULL(ORDERS.BuyerPO,''),        -- Added by MaryVong on 23Sept04 (SOS27518)    
        IsNULL(ORDERS.InvoiceNo,''),       -- Added by MaryVong on 23Sept04 (SOS27518)    
        IsNUll(ORDERS.OrderDate, '19000101'),      -- Added by MaryVong on 23Sept04 (SOS27518)    
        SKU.Susr4,            -- sos 26373 wally 18.oct.2004    
        ST.vat,    
        SKU.OVAS, -- SOS41046    
        SKU.SKUGROUP, -- SOS#144415    
        ORDERS.ContainerType,  
        LOC.Pickzone, --NJOW01    
        CASE WHEN ISNULL(CODELKUP.Long,'') = '' THEN ORDERS.Priority ELSE CODELKUP.Long END, -- (CJY01)   
        ISNULL(CL1.SHORT,'N')   --WL01     
  -- SOS 7236    
  -- wally 16.aug.2002    
  -- commented the cursor below and instead update directly the temp table    
  -- update case qty    
  update #temp_pick    
  set cartons_cal = case packcasecnt    
         when 0 then 0    
         --else floor(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)    
         else floor(total_cal/packcasecnt)    
        end    
      
  -- update inner qty    
  update #temp_pick    
  set inner_cal = case packinner    
        when 0 then 0    
        --else floor(total_cal/packinner) -     
        --  ((packpallet*pallet_cal)/packinner) - ((packcasecnt*cartons_cal)/packinner)    
        else floor(total_cal/packinner) - ((packcasecnt*cartons_cal)/packinner)    
        end    
      
  -- update each qty    
  update #temp_pick    
  --set each_cal = total_cal - (packpallet*pallet_cal) - (packcasecnt*cartons_cal) - (packinner*inner_cal)    
  set each_cal = total_cal - (packcasecnt*cartons_cal) - (packinner*inner_cal)     
    
     BEGIN TRAN      
     -- Uses PickType as a Printed Flag      
     UPDATE PickHeader with (RowLOck)    -- tlting01  
      SET PickType = '1', TrafficCop = NULL     
     WHERE ExternOrderKey = @c_LoadKey     
     AND Zone = 'LP' --NJOW01     
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
       
     /*  
     SELECT @n_pickslips_required = Count(DISTINCT OrderKey)     
     FROM #TEMP_PICK    
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
 --                                                     from #TEMP_PICK as Rank     
 --                                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )     
 --                    ) -- str    
 --                    )) -- dbo.fnc_RTrim    
 --                 , 9)     
 --              , OrderKey, LoadKey, '0', '8', ''    
 --             FROM #TEMP_PICK WHERE PickSlipNo IS NULL    
 --             GROUP By LoadKey, OrderKey    
         INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)    
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +     
             dbo.fnc_LTrim( dbo.fnc_RTrim(    
                STR(     
                   CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey)     
                                                     from #TEMP_PICK as Rank     
                                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )     
                    ) -- str    
                    )) -- dbo.fnc_RTrim    
                 , 9)     
              , OrderKey, LoadKey, '0', '3', ''    
             FROM #TEMP_PICK WHERE PickSlipNo IS NULL    
             GROUP By LoadKey, OrderKey    
         UPDATE #TEMP_PICK     
         SET PickSlipNo = PICKHEADER.PickHeaderKey    
         FROM PICKHEADER (NOLOCK)    
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey    
         AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey    
         AND   PICKHEADER.Zone = '3'    
   AND   #TEMP_PICK.PickSlipNo IS NULL    
     END    
     GOTO SUCCESS  
   */  
     
   --NJOW01  
      SET @c_OrderKey = ''    
      SET @c_Pickzone = ''  
      SET @c_PrevOrderkey = ''  
      SET @c_PrevPickzone = ''  
      SET @c_PickDetailKey = ''    
      SET @n_continue = 1  
       
      DECLARE C_Orderkey_Pickzone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT DISTINCT OrderKey, Pickzone  
      FROM   #TEMP_PICK     
      WHERE  ISNULL(PickSlipNo,'') = ''    
      ORDER BY OrderKey, Pickzone  
  
      OPEN C_Orderkey_Pickzone     
       
      FETCH NEXT FROM C_Orderkey_Pickzone INTO @c_OrderKey, @c_Pickzone  
       
      WHILE (@@Fetch_Status <> -1)    
      BEGIN -- while 1    
         IF ISNULL(@c_OrderKey, '0') = '0'    
            BREAK    
         
         --INC0543023 Start
         IF EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)    
         BEGIN
            SELECT Top 1 @c_PickSlipNo = PickSlipNo FROM RefKeyLookup WITH (NOLOCK) WHERE OrderKey = @c_OrderKey
            
            UPDATE #TEMP_PICK    
               SET PickSlipNo = @c_PickSlipNo    
            WHERE OrderKey = @c_OrderKey    
            AND   Pickzone = @c_Pickzone  
            AND   ISNULL(PickSlipNo,'') = ''    
            
            SELECT @n_err = @@ERROR    
            IF @n_err <> 0     
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @n_err = 63505  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #Temp_Pick Failed. (isp_GetPickSlipOrders52)'      
               GOTO FAILURE  
            END   
         END   --INC0543023 End           
         ELSE
         BEGIN
            IF @c_PrevOrderKey <> @c_OrderKey   
               --OR @c_PrevPickzone <> @c_Pickzone   
            BEGIN         
--            BEGIN TRAN  
            SET @c_PickSlipNo = ''  
       
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
               INSERT PICKHEADER (pickheaderkey, OrderKey,    ExternOrderkey, zone, PickType,   Wavekey)    
                          VALUES (@c_PickSlipNo, @c_OrderKey, @c_loadkey, 'LP', '0',  @c_Pickslipno)    
  
               SELECT @n_err = @@ERROR    
               IF @n_err <> 0     
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @n_err = 63501  
              SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into PICKHEADER Failed. (isp_GetPickSlipOrders52)'  
                  GOTO FAILURE  
               END               
            END -- @b_success = 1      
            ELSE     
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @n_err = 63502  
             SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipOrders52)'    
               BREAK     
            END     
         END
         END   
       
         IF @n_Continue = 1    
         BEGIN          
            SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +  
                                    'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +     
                                    'FROM   PickDetail WITH (NOLOCK) ' +  
                                    'JOIN   OrderDetail WITH (NOLOCK) ' +                                         
                                    'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' +   
                                    'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +  
                                    'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +  
                                    'WHERE  OrderDetail.OrderKey = ''' + @c_OrderKey + '''' +  
                                    --' AND    OrderDetail.LoadKey  = ''' + @c_LoadKey  + ''' ' +  
                                    ' AND LOC.PickZone = ''' + RTRIM(@c_Pickzone) + ''' ' +    
                                    ' ORDER BY PickDetail.PickDetailKey '    
     
            EXEC(@c_ExecStatement)  
            OPEN C_PickDetailKey    
       
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber     
       
            WHILE @@FETCH_STATUS <> -1    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)     
               BEGIN     
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)    
                  VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_Loadkey)  
  
                  SELECT @n_err = @@ERROR    
                  IF @n_err <> 0     
                  BEGIN    
                     SELECT @n_continue = 3  
                     SELECT @n_err = 63503  
                    SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipOrders52)'      
                     GOTO FAILURE  
                  END                            
               END     
       
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber     
            END     
            CLOSE C_PickDetailKey     
            DEALLOCATE C_PickDetailKey          
         END     
                  
         UPDATE #TEMP_PICK    
            SET PickSlipNo = @c_PickSlipNo    
         WHERE OrderKey = @c_OrderKey    
         AND   Pickzone = @c_Pickzone  
         AND   ISNULL(PickSlipNo,'') = ''    
  
         SELECT @n_err = @@ERROR    
         IF @n_err <> 0     
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @n_err = 63504  
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #Temp_Pick Failed. (isp_GetPickSlipOrders52)'      
            GOTO FAILURE  
         END    
--         ELSE  
--         BEGIN  
--            WHILE @@TRANCOUNT > 0  
--            COMMIT TRAN  
--         END  
  
         SET @c_PrevOrderKey = @c_OrderKey   
         SET @c_PrevPickzone = @c_Pickzone  
       
         FETCH NEXT FROM C_Orderkey_Pickzone INTO @c_OrderKey, @c_Pickzone  
      END -- while 1     
       
      CLOSE C_Orderkey_Pickzone    
      DEALLOCATE C_Orderkey_Pickzone     
        
      GOTO SUCCESS    
         
 FAILURE:    
     DELETE FROM #TEMP_PICK    
 SUCCESS:    
     SELECT * FROM #TEMP_PICK      
   DROP Table #TEMP_PICK      
 END  


GO