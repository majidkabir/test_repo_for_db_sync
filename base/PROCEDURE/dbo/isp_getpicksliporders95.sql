SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Proc : isp_GetPickSlipOrders95                                   */    
/* Creation Date:08/08/2019                                                */    
/* Copyright: LFL                                                          */    
/* Written by: WLChooi                                                     */    
/*                                                                         */    
/* Purpose:  WMS-10177 - WMS-10177 - LVS Picking Slip                      */
/*           Modified from isp_GetPickSlipOrders78                         */    
/*                                                                         */    
/* Usage:                                                                  */    
/*                                                                         */    
/* Local Variables:                                                        */    
/*                                                                         */    
/* Called By: r_dw_print_pickorder95                                       */    
/*                                                                         */    
/* PVCS Version: 1.1                                                       */    
/*                                                                         */    
/* Version: 5.4                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date        Author      Ver   Purposes                                  */ 
/* 2020-12-21  WLChooi     1.1   WMS-15856 - Add SKU.Putawayzone (WL01)    */
/***************************************************************************/     
CREATE PROC [dbo].[isp_GetPickSlipOrders95] (@c_loadkey NVARCHAR(10))     
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_pickheaderkey    NVARCHAR(10),    
           @n_continue         int = 1,    
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
  
    /*CREATE TABLE #TEMP_PICK95    
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
         --TrfRoom          NVARCHAR(5) NULL,  -- LoadPlan.TrfRoom    
         Notes1           NVARCHAR(60) NULL,    
         Notes2           NVARCHAR(60) NULL,    
         --LOC              NVARCHAR(10) NULL,     
         --ID               NVARCHAR(18) NULL,    -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)     
         --SKU              NVARCHAR(20),    
         --SkuDesc          NVARCHAR(60),    
         --Qty              int,    
         --TempQty1         int,    
         --TempQty2         int,    
         PrintedFlag      NVARCHAR(1) NULL,    
         --Zone             NVARCHAR(1),    
         --PgGroup          int,    
         --RowNum           int,    
         --Lot              NVARCHAR(10),    
         Carrierkey       NVARCHAR(60) NULL,    
         VehicleNo        NVARCHAR(10) NULL,    
         --Lottable02       NVARCHAR(18) NULL, -- SOS14561    
         --Lottable04       datetime NULL,    
         --packpallet       int,    
         --packcasecnt      int,     
         --packinner        int,     -- sos 7545 wally 27.aug.2002    
         --packeaches       int,       -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)     
         externorderkey   NVARCHAR(30) NULL,    
         --LogicalLoc       NVARCHAR(18) NULL,      
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)    
         --UOM              NVARCHAR(10),          -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)    
         --Pallet_cal       int,      
         --Cartons_cal      int,      
         --inner_cal        int,     -- sos 7545 wally 27.aug.2002     
         --Each_cal         int,      
         --Total_cal        int,       -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657)     
         DeliveryDate     datetime NULL,    
         --RetailSku        NVARCHAR(20) NULL,  -- Added by MaryVong on 22Sept04 (SOS27518)    
         BuyerPO          NVARCHAR(20) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         InvoiceNo        NVARCHAR(10) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         OrderDate        datetime NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         --Susr4            NVARCHAR(18) NULL,  -- sos 26373 wally 18.oct.2004    
         vat              NVARCHAR(18) NULL,    
         --OVAS             NVARCHAR(30) NULL,  -- SOS41046    
         --SKUGROUP         NVARCHAR(10) NULL, -- SOS144415      
         ContainerType    NVARCHAR(20) NULL  
         --RptGrp           NVARCHAR(1) NULL)  */  
              
   CREATE TABLE #TEMP_PICK95    
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
         Notes1           NVARCHAR(60) NULL,    
         Notes2           NVARCHAR(60) NULL,    
         PrintedFlag      NVARCHAR(1) NULL,    
         Carrierkey       NVARCHAR(60) NULL,    
         VehicleNo        NVARCHAR(10) NULL,    
         externorderkey   NVARCHAR(50) NULL,    
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)    
         DeliveryDate     datetime NULL,     
         BuyerPO          NVARCHAR(20) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         InvoiceNo        NVARCHAR(10) NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)    
         OrderDate        datetime NULL,  -- Added by MaryVong on 23Sept04 (SOS27518)      
         vat              NVARCHAR(18) NULL,    
         ContainerType    NVARCHAR(20) NULL,  
         ItemClassDescr   NVARCHAR(100) NULL,  
         SKU              NVARCHAR(50) NULL,  
         LOC              NVARCHAR(50) NULL,  
         ID               NVARCHAR(50) NULL,  
         TotalQTY         INT NULL,  
         Storerkey        NVARCHAR(20) NULL,
         Putawayzone      NVARCHAR(10) NULL )   --WL01 
     
   INSERT INTO #TEMP_PICK95 ( PickSlipNo        
                             ,LoadKey           
                             ,OrderKey          
                             ,ConsigneeKey      
                             ,Company           
                             ,Addr1             
                             ,Addr2             
                             ,Addr3             
                             ,PostCode          
                             ,Route             
                             ,Route_Desc        
                             ,Notes1            
                             ,Notes2            
                             ,PrintedFlag       
                             ,Carrierkey        
                             ,VehicleNo         
                             ,externorderkey    
                             ,Areakey           
                             ,DeliveryDate      
                             ,BuyerPO           
                             ,InvoiceNo         
                             ,OrderDate         
                             ,vat               
                             ,ContainerType  
                             ,ItemClassDescr  
                             ,SKU  
                             ,LOC  
                             ,ID   
                             ,TotalQTY  
                             ,Storerkey
                             ,Putawayzone )   --WL01   
       --INSERT INTO #TEMP_PICK95    
       --     (PickSlipNo,          LoadKey,         OrderKey,   ConsigneeKey,    
       --      Company,             Addr1,           Addr2,         PgGroup,    
       --      Addr3,               PostCode,        Route,    
       --      Route_Desc,          TrfRoom,         Notes1,        RowNum,    
       --      Notes2,              LOC,             ID,            SKU,    
       --      SkuDesc,             Qty,             TempQty1,    
       --      TempQty2,            PrintedFlag,     Zone,    
       --      Lot,                 CarrierKey,      VehicleNo,     Lottable02, -- SOS14561    
       --      Lottable04,          packpallet,       packcasecnt,  packinner,      
       --      packeaches,          externorderkey,  LogicalLoc,  Areakey,    UOM,     
       --      Pallet_cal,          Cartons_cal,      inner_cal,   Each_cal,   Total_cal,     
       --      DeliveryDate,        RetailSku,        BuyerPO,      InvoiceNo,  OrderDate,    
       --      Susr4,               Vat,                OVAS,         SKUGROUP,    ContainerType,RptGrp) -- SOS144415    
   SELECT  (SELECT PICKHEADERKEY FROM PICKHEADER     
            WHERE ExternOrderKey = @c_LoadKey     
            AND OrderKey = PickDetail.OrderKey     
            AND ZONE = '3'),    
           @c_LoadKey as LoadKey,                     
           PickDetail.OrderKey,                                
           IsNull(ORDERS.ConsigneeKey, '') AS ConsigneeKey,      
           IsNull(ORDERS.c_Company, '')  AS Company,       
           IsNull(ORDERS.C_Address1,'') AS Addr1,                
           IsNull(ORDERS.C_Address2,'') AS Addr2,                              
           IsNull(ORDERS.C_Address3,'') AS Addr3,                
           IsNull(ORDERS.C_Zip,'') AS PostCode,    
           IsNull(ORDERS.Route,'') AS Route,             
           IsNull(RouteMaster.Descr, '') Route_Desc,        
           CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) Notes1,  
           CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) Notes2,    
           IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,                                
           '' CarrierKey,                                      
           '' AS VehicleNo,      
           ORDERS.ExternOrderKey AS ExternOrderKey,                
           IsNull(AreaDetail.AreaKey, '00') AS Areakey,     
           IsNUll(ORDERS.DeliveryDate, '19000101') DeliveryDate,               
           IsNULL(ORDERS.BuyerPO,'') BuyerPO,          
           IsNULL(ORDERS.InvoiceNo,'') InvoiceNo,         
           IsNUll(ORDERS.OrderDate, '19000101') OrderDate,    
           ST.vat,    
           ORDERS.ContainerType,  
           --(SELECT TOP 1 ISNULL(C.[Description],'') FROM CODELKUP C (NOLOCK) WHERE C.LISTNAME = 'ITEMCLASS' AND C.STORERKEY = ORDERS.STORERKEY AND C.Code = SKU.ItemClass)  
           C.[Description],  
           SKU.SKU,  
           LOC.LOC,  
           PICKDETAIL.ID,  
           SUM(pickdetail.Qty),  
           Orders.Storerkey,
           SKU.Putawayzone   --WL01
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
   LEFT JOIN CODELKUP C (NOLOCK) ON C.Listname = 'ITEMCLASS' AND C.Storerkey = Orders.Storerkey AND C.Code = SKU.ItemClass   
   WHERE PickDetail.Status < '5'      
   AND LoadPlanDetail.LoadKey = @c_LoadKey    
   GROUP BY PickDetail.OrderKey,                                                             
            IsNull(ORDERS.ConsigneeKey, ''),      
            IsNull(ORDERS.c_Company, ''),       
            IsNull(ORDERS.C_Address1,''),                
            IsNull(ORDERS.C_Address2,''),                              
            IsNull(ORDERS.C_Address3,''),                
            IsNull(ORDERS.C_Zip,''),    
            IsNull(ORDERS.Route,''),             
            IsNull(RouteMaster.Descr, ''),        
            CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')),  
            CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')),                               
            ORDERS.ExternOrderKey,                
            IsNull(AreaDetail.AreaKey, '00'),     
            IsNUll(ORDERS.DeliveryDate, '19000101'),               
            IsNULL(ORDERS.BuyerPO,''),          
            IsNULL(ORDERS.InvoiceNo,''),         
            IsNUll(ORDERS.OrderDate, '19000101'),    
            ST.vat,    
            ORDERS.ContainerType,  
            C.[Description],  
            SKU.SKU,  
            LOC.LOC,  
            PICKDETAIL.ID,  
            Orders.Storerkey,
            SKU.Putawayzone   --WL01 
  
            
   --IF @n_continue = 1 OR @n_continue = 2  
   --BEGIN  
   --   update #TEMP_PICK95    
   --   set cartons_cal = case packcasecnt    
   --                     when 0 then 0    
   --                     else floor(total_cal/packcasecnt)  --NJOW01    
   --                     end    
   --   -- update inner qty    
   --   update #TEMP_PICK95    
   --   set inner_cal = case packinner    
   --                   when 0 then 0    
   --                   else floor(total_cal/packinner) - ((packcasecnt*cartons_cal)/packinner) --NJOW01    
   --                   end    
   --   -- update each qty    
   --   update #TEMP_PICK95    
   --   set each_cal = total_cal - (packcasecnt*cartons_cal) - (packinner*inner_cal) --NJOW01    
   --END  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
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
   END  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
   SELECT @n_pickslips_required = Count(DISTINCT OrderKey)     
   FROM #TEMP_PICK95    
   WHERE PickSlipNo IS NULL   
  
      IF @@ERROR <> 0    
      BEGIN  
         GOTO FAILURE    
      END    
      ELSE IF @n_pickslips_required > 0    
      BEGIN    
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required     
         INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)    
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +     
         dbo.fnc_LTrim( dbo.fnc_RTrim(    
            STR(     
               CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey)     
                                                 from #TEMP_PICK95 as Rank     
                                                 WHERE Rank.OrderKey < #TEMP_PICK95.OrderKey )     
                ) -- str    
                )) -- dbo.fnc_RTrim    
             , 9)     
          , OrderKey, LoadKey, '0', '3', ''    
         FROM #TEMP_PICK95 WHERE PickSlipNo IS NULL    
         GROUP By LoadKey, OrderKey    
  
         UPDATE #TEMP_PICK95     
         SET PickSlipNo = PICKHEADER.PickHeaderKey    
         FROM PICKHEADER (NOLOCK)    
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK95.LoadKey    
         AND   PICKHEADER.OrderKey = #TEMP_PICK95.OrderKey    
         AND   PICKHEADER.Zone = '3'    
         AND   #TEMP_PICK95.PickSlipNo IS NULL    
      END    
  
      GOTO SUCCESS    
   END  
  
FAILURE:    
   DELETE FROM #TEMP_PICK95    
SUCCESS:    
   SELECT  t.PickSlipNo      
          ,t.LoadKey         
          ,t.OrderKey        
          ,t.ConsigneeKey    
          ,t.Company         
          ,t.Addr1           
          ,t.Addr2           
          ,t.Addr3           
          ,t.PostCode        
          ,t.Route           
          ,t.Route_Desc      
          ,t.Notes1          
          ,t.Notes2          
          ,t.PrintedFlag     
          ,t.Carrierkey      
          ,t.VehicleNo       
          ,t.externorderkey  
          ,t.Areakey         
          ,t.DeliveryDate    
          ,t.BuyerPO         
          ,t.InvoiceNo       
          ,t.OrderDate       
          ,t.vat             
          ,t.ContainerType  
          ,t.ItemClassDescr  
          ,COUNT(DISTINCT t.SKU) AS TotalSKUByItemClass  
          ,COUNT(DISTINCT t.LOC) AS TotalLOCByItemClass  
          ,COUNT(DISTINCT t.ID ) AS TotalIDByItemClass  
          ,SUM(t.TotalQTY) 
          ,t.Putawayzone   --WL01
   FROM #TEMP_PICK95 t  
   GROUP BY t.PickSlipNo      
           ,t.LoadKey         
           ,t.OrderKey        
           ,t.ConsigneeKey    
           ,t.Company         
           ,t.Addr1           
           ,t.Addr2           
           ,t.Addr3           
           ,t.PostCode        
           ,t.Route           
           ,t.Route_Desc      
           ,t.Notes1          
           ,t.Notes2          
           ,t.PrintedFlag     
           ,t.Carrierkey      
           ,t.VehicleNo       
           ,t.externorderkey  
           ,t.Areakey         
           ,t.DeliveryDate    
           ,t.BuyerPO         
           ,t.InvoiceNo       
           ,t.OrderDate       
           ,t.vat             
           ,t.ContainerType  
           ,t.ItemClassDescr  
           ,t.Putawayzone   --WL01
    ORDER BY t.PickSlipNo  
   
    --select t.ItemClassDescr  
    --      ,COUNT(distinct t.SKU) AS TotalSKUByItemClass  
    --      ,COUNT(distinct t.LOC) AS TotalLOCByItemClass  
    --      ,COUNT(distinct t.ID ) AS TotalIDByItemClass  
    --      ,SUM(t.TotalQTY)  
    --from #TEMP_PICK95 t  
    --group by t.ItemClassDescr  
   
   DROP Table #TEMP_PICK95      
END

GO