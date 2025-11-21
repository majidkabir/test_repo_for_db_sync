SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: nsp_GetPickSlipOrders124                           */  
/* Creation Date: 2021-09-03                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose: WMS-17851 TH-TRIUMPH-CUSTOMIZE-PICKING_SLIP                 */  
/*                                                                      */  
/* Called By: r_dw_print_pickorder124                                   */  
/*                                                                      */  
/* PVCS Version:                                                        */  
/*                                                                      */  
/* Version:                                                             */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */    
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_GetPickSlipOrders124] (@c_loadkey NVARCHAR(10)) -- 0000365810  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @c_pickheaderkey  NVARCHAR(10),  
   @n_continue    int,  
   @c_errmsg    NVARCHAR(255),  
   @b_success    int,  
   @n_err     int,  
   @c_sku     NVARCHAR(20),  
   @n_qty     int,  
   @c_loc     NVARCHAR(10),  
   @n_cases     int,  
   @n_perpallet   int,  
   @c_storer    NVARCHAR(15),  
   @c_orderkey    NVARCHAR(10),  
   @c_Externorderkey    NVARCHAR(50),    
   @c_ConsigneeKey  NVARCHAR(15),  
   @c_Company    NVARCHAR(45),  
   @c_Addr1     NVARCHAR(45),  
   @c_Addr2     NVARCHAR(45),  
   @c_Addr3     NVARCHAR(45),  
   @c_PostCode    NVARCHAR(15),  
   @c_Route     NVARCHAR(10),  
   @c_Route_Desc   NVARCHAR(60), -- RouteMaster.Desc  
   @c_TrfRoom    NVARCHAR(5),  -- LoadPlan.TrfRoom  
   @c_Notes1    NVARCHAR(60),  
   @c_Notes2    NVARCHAR(60),  
   @c_SkuDesc    NVARCHAR(60),  
   @n_CaseCnt    int,  
   @n_PalletCnt   int,  
   @c_ReceiptTm   NVARCHAR(20),  
   @c_PrintedFlag   NVARCHAR(1),  
   @c_UOM     NVARCHAR(10),  
   @n_UOM3     int,  
   @c_Lot     NVARCHAR(10),  
   @c_StorerKey   NVARCHAR(15),  
   @c_Zone     NVARCHAR(1),  
   @n_PgGroup    int,  
   @n_TotCases    int,  
   @n_RowNo     int,  
   @c_PrevSKU    NVARCHAR(20),  
   @n_SKUCount    int,  
   @c_Carrierkey   NVARCHAR(60),  
   @c_VehicleNo   NVARCHAR(10),  
   @c_firstorderkey  NVARCHAR(10),  
   @c_superorderflag  NVARCHAR(1),  
   @c_firsttime   NVARCHAR(1),  
   @c_logicalloc   NVARCHAR(18),  
   @c_Lottable01   NVARCHAR(18),  
   @c_Lottable02   NVARCHAR(18),  
   @c_Lottable03   NVARCHAR(18),  
   @d_Lottable04   datetime,  
   @c_labelPrice   NVARCHAR(5),  
   @c_invoiceno   NVARCHAR(10),  
   @c_uom_master   NVARCHAR(10),  
   @d_deliverydate  Datetime,  
   @c_ordertype   NVARCHAR(250),  
   @n_loccnt          int,  
   @c_ID              NVARCHAR(18) = NULL,       
   @c_PAZone          NVARCHAR(10) = NULL,       
   @c_RetailSKU       NVARCHAR(20) = NULL,        
   @n_CurrentPG       INT = 1,                   
   @c_LastPutawayzone NVARCHAR(10) = '',         
   @c_LastLoadkey     NVARCHAR(10) = '',         
   @c_LastOrderkey    NVARCHAR(10) = ''          
  
   DECLARE @c_PrevOrderKey  NVARCHAR(10),  
            @n_Pallets    int,  
            @n_Cartons    int,  
            @n_Eaches    int,  
            @n_UOMQty    int,  
            @n_inner             int  
  
   DECLARE @n_qtyorder         int,  
            @n_qtyallocated        int,  
            @c_skuindicator           NVARCHAR(1) ,                  
            @c_ShowSusr5              NVARCHAR(5),                   
            @c_susr5                  NVARCHAR(18),                  
            @c_ShowFullLoc            NVARCHAR(5),                        
            @c_showordtype            NVARCHAR(5),                     
            @c_showcitystate          NVARCHAR(5),                    
            @c_OHTypeDesc             NVARCHAR(50),                  
            @c_NewPostCode            NVARCHAR(120),                 
            @c_ShowPickdetailID       NVARCHAR(5),                   
            @c_BreakByPAZone          NVARCHAR(5),                   
            @c_ShowRetailSKU          NVARCHAR(5),                   
            @c_SQL                    NVARCHAR(4000),                
            @c_OrderBy                NVARCHAR(4000),                
            @n_MaxLine                INT = 10,                      
            @c_GetPutawayzone         NVARCHAR(10),                  
            @c_GetLoadkey             NVARCHAR(10),                  
            @c_GetOrderkey            NVARCHAR(10),                  
            @n_GetTotalPage           INT = 0,                       
            @n_CurrentCnt             INT = 1,                       
            @c_ShowPageNoByOrderkey   NVARCHAR(10),                  
            @b_flag                   INT = 0,                       
            @c_ShowEachInInnerCol     NVARCHAR(10)                   
   
   DECLARE @c_LRoute        NVARCHAR(10),  
           @c_LEXTLoadKey   NVARCHAR(20),  
           @c_LPriority     NVARCHAR(10),  
           @c_LUDef01       NVARCHAR(20)     
   
   CREATE TABLE #PagenoByOrderkey  
   ( Pickslipno    NVARCHAR(10),  
     Loadkey       NVARCHAR(10),  
     Orderkey      NVARCHAR(10),  
     TotalPage     INT )  
  
 
   SELECT @c_ShowPickdetailID      = ISNULL(MAX(CASE WHEN Code = 'ShowPickdetailID' THEN 'Y' ELSE 'N' END),'N')      
         ,@c_BreakByPAZone         = ISNULL(MAX(CASE WHEN Code = 'BreakByPAZone' THEN 'Y' ELSE 'N' END),'N')      
         ,@c_ShowRetailSKU         = ISNULL(MAX(CASE WHEN Code = 'ShowRetailSKU' THEN 'Y' ELSE 'N' END),'N')    
         ,@c_ShowPageNoByOrderkey  = ISNULL(MAX(CASE WHEN Code = 'ShowPageNoByOrderkey' THEN 'Y' ELSE 'N' END),'N')   
   FROM CODELKUP WITH (NOLOCK)      
   WHERE ListName = 'REPORTCFG'      
   AND   Storerkey= (SELECT TOP 1 STORERKEY FROM ORDERS (NOLOCK) WHERE LOADKEY = @c_loadkey)      
   AND   Long = 'r_dw_print_pickorder10'      
   AND   ISNULL(Short,'') <> 'N'      
  
   IF @c_ShowPickdetailID = NULL SET @c_ShowPickdetailID = ''  
   IF @c_BreakByPAZone = NULL SET @c_BreakByPAZone = ''  
   IF @c_ShowRetailSKU = NULL SET @c_ShowRetailSKU = ''   
   IF @c_ShowPageNoByOrderkey = NULL SET @c_ShowPageNoByOrderkey = ''    
       
   CREATE TABLE #temp_pick  
   (  PickSlipNo   NVARCHAR(10),  
   LoadKey       NVARCHAR(10),  
   OrderKey       NVARCHAR(10),  
   Externorderkey   NVARCHAR(50),   
   ConsigneeKey     NVARCHAR(15),  
   Company       NVARCHAR(45),  
   Addr1        NVARCHAR(45),  
   Addr2        NVARCHAR(45),  
   Addr3        NVARCHAR(45),  
   PostCode       NVARCHAR(15),  
   Route        NVARCHAR(10),  
   Route_Desc      NVARCHAR(60), -- RouteMaster.Desc  
   TrfRoom       NVARCHAR(5),  -- LoadPlan.TrfRoom  
   Notes1         NVARCHAR(60),  
   Notes2         NVARCHAR(60),  
   LOC          NVARCHAR(10),  
   SKU          NVARCHAR(20),  
   SkuDesc       NVARCHAR(60),  
   Qty          int,  
   TempQty1       int,  
   TempQty2       int,  
   PrintedFlag    NVARCHAR(1),  
   Zone          NVARCHAR(1),  
   PgGroup       int,  
   RowNum         int,  
   Lot                  NVARCHAR(10),  
   Carrierkey           NVARCHAR(60),  
   VehicleNo            NVARCHAR(10),  
   Lottable01           NVARCHAR(18),  
   Lottable02           NVARCHAR(18),  
   Lottable03           NVARCHAR(18),  
   Lottable04           datetime,  
   LabelPrice           NVARCHAR(5)  NULL,     
   storerkey            NVARCHAR(18),
   invoiceno            NVARCHAR(10) NULL,       
   deliverydate         Datetime  NULL,   
   ordertype            NVARCHAR(250) NULL,     
   qtyorder             int NULL DEFAULT 0,  
   qtyallocated         int NULL DEFAULT 0,  
   logicallocation      NVARCHAR(18),  
   casecnt              int,  
   pallet               int,  
   innerpack            int,  
   Skuindicator         NVARCHAR(1) NULL,                  
   LRoute               NVARCHAR(10) NULL,     
   LEXTLoadKey          NVARCHAR(20) NULL,     
   LPriority            NVARCHAR(10) NULL,      
   LUDef01              NVARCHAR(20) NULL,      
   SUSR5                NVARCHAR(18) NULL,      
   ShowSUSR5            NVARCHAR(5)  NULL,       
   ShowFullLoc          NVARCHAR(5) NULL,        
   ShowOrdType          NVARCHAR(5) NULL,        
   ShowCityState        NVARCHAR(5) NULL,        
   OHTypeDesc           NVARCHAR(50) NULL,       
   NewPostcode          NVARCHAR(120) NULL,      
   ShowPickdetailID     NVARCHAR(5) NULL,        
   ID                   NVARCHAR(18) NULL,       
   Putawayzone          NVARCHAR(10) NULL,       
   BreakByPAZone        NVARCHAR(10) NULL,       
   RetailSKU            NVARCHAR(20) NULL,       
   CurrentPage          INT NULL,                
   TotalPage            INT NULL,                
   ShowPageNoByOrderkey NVARCHAR(10) NULL,       
   ShowEachInInnerCol   NVARCHAR(10) NULL        
  
    )   
  
  
   SET @c_ShowSusr5 = ''  
   SET @c_ShowFullLoc = ''                 
  
   SELECT @n_continue = 1  
   SELECT @n_RowNo = 0  
   SELECT @c_firstorderkey = 'N'  
  
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)  
   WHERE ExternOrderKey = @c_loadkey  
   AND   Zone = '3')  
   BEGIN  
      SELECT @c_firsttime = 'N'  
      SELECT @c_PrintedFlag = 'Y'  
   END  
   ELSE  
   BEGIN  
      SELECT @c_firsttime = 'Y'  
      SELECT @c_PrintedFlag = 'N'  
   END -- Record Not Exists  
  
   DECLARE pick_cur CURSOR  FAST_FORWARD READ_ONLY FOR  
   SELECT PickDetail.sku,       PickDetail.loc,  
   SUM(PickDetail.qty),  PACK.Qty,  
   PickDetail.storerkey, PickDetail.OrderKey,  
   PickDetail.UOM,       LOC.LogicalLocation,  
   Pickdetail.Lot, Loadplan.Route ,                         
   Loadplan.Externloadkey,                   
   Loadplan.Priority,                        
   --Loadplan.UserDefine01                         
   convert(nvarchar(10),Loadplan.LPuserdefDate01,103),      
   CASE WHEN @c_ShowPickdetailID = 'Y' THEN Pickdetail.ID ELSE '' END,    
   CASE WHEN @c_BreakByPAZone = 'Y' THEN LOC.PutawayZone ELSE '' END,     
   CASE WHEN @c_ShowRetailSKU = 'Y' THEN SKU.RETAILSKU ELSE '' END        
   FROM   PickDetail (NOLOCK),  LoadPlanDetail (NOLOCK),  
   PACK (NOLOCK),        LOC (NOLOCK), LoadPlan (NOLOCK),  
   SKU (NOLOCK)   
   WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey  
   --       AND    PickDetail.Status < '9' -- SOS 5933 Pickslips can be displayed even confirmed picked  
   AND    PickDetail.Packkey = PACK.Packkey  
   AND    LOC.Loc = PICKDETAIL.Loc  
   AND Loadplan.loadkey=loadplandetail.loadkey                      
   AND PickDetail.SKU = SKU.SKU AND PickDetail.Storerkey = SKU.Storerkey     
   AND    LoadPlanDetail.LoadKey = @c_loadkey  
   GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,  
   PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,  
   LOC.LogicalLocation,  Pickdetail.Lot, Loadplan.Route ,                         
   Loadplan.Externloadkey,                   
   Loadplan.Priority,                         
   --Loadplan.UserDefine01                     --CS03  
   convert(nvarchar(10),Loadplan.LPuserdefDate01,103),      
   CASE WHEN @c_ShowPickdetailID = 'Y' THEN Pickdetail.ID ELSE '' END,   
   CASE WHEN @c_BreakByPAZone = 'Y' THEN LOC.PutawayZone ELSE '' END,    
   CASE WHEN @c_ShowRetailSKU = 'Y' THEN SKU.RETAILSKU ELSE '' END       
   ORDER BY PICKDETAIL.ORDERKEY  
  
   OPEN pick_cur  
  
   SELECT @c_PrevOrderKey = ''  
  
   FETCH NEXT FROM pick_cur INTO @c_sku,   @c_loc, @n_Qty,   @n_uom3, @c_storerkey,  
   @c_orderkey, @c_UOM, @c_logicalloc, @c_lot,@c_LRoute,@c_LEXTLoadKey,@c_LPriority,@c_LUDef01,    
   @c_ID,      
   @c_PAZone, @c_RetailSKU   
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      IF @c_OrderKey <> @c_PrevOrderKey  
      BEGIN  
         IF NOT EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE EXTERNORDERKEY = @c_LoadKey  
         AND OrderKey = @c_OrderKey AND Zone = '3' )  
         BEGIN  
            EXECUTE nspg_GetKey  
            'PICKSLIP',  
            9,  
            @c_pickheaderkey OUTPUT,  
            @b_success   OUTPUT,  
            @n_err    OUTPUT,  
            @c_errmsg   OUTPUT  
  
            SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey  
  
            BEGIN TRAN  
               INSERT INTO PICKHEADER  
               (PickHeaderKey,  OrderKey,  ExternOrderKey, PickType, Zone,  TrafficCop)  
               VALUES  
               (@c_pickheaderkey, @c_OrderKey, @c_LoadKey,   '0',   '3',  '')  
  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  IF @@TRANCOUNT >= 1  
                  BEGIN  
                     ROLLBACK TRAN  
                  END  
               END  
            ELSE  
               BEGIN  
                  IF @@TRANCOUNT > 0  
                  COMMIT TRAN  
               ELSE  
                  ROLLBACK TRAN  
               END  
               SELECT @c_firstorderkey = 'Y'  
            END  
         ELSE  
            BEGIN  
               SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)  
               WHERE ExternOrderKey = @c_loadkey  
               AND   Zone = '3'  
               AND   OrderKey = @c_OrderKey  
            END  
         END  
         IF @c_OrderKey = ''  
         BEGIN  
            SELECT @c_ConsigneeKey = '',  
            @c_Company = '',  
            @c_Addr1 = '',  
            @c_Addr2 = '',  
            @c_Addr3 = '',  
            @c_PostCode = '',  
            @c_Route = '',  
            @c_Route_Desc = '',  
            @c_Notes1 = '',  
            @c_Notes2 = '',  
            @c_invoiceno = '',  
            @c_NewPostCode = ''              
              
         END  
      ELSE  
         BEGIN  
            SELECT  @c_Externorderkey= orders.Externorderkey,  
            @c_ConsigneeKey = Orders.ConsigneeKey,  
            @c_Company   = ORDERS.c_Company,  
            @c_Addr1   = ORDERS.C_Address1,  
            @c_Addr2   = ORDERS.C_Address2,  
            @c_Addr3   = ORDERS.C_Address3,  
            @c_PostCode  = ORDERS.C_Zip,  
            @c_Notes1   = CONVERT(NVARCHAR(60), ORDERS.Notes),  
            @c_Notes2   = CONVERT(NVARCHAR(60), ORDERS.Notes2),  
            @c_labelprice  = ISNULL( ORDERS.LabelPrice, 'N' ),  
            @c_invoiceno  = ORDERS.ExternOrderKey,  
            @d_deliverydate = ORDERS.deliverydate,  
            @c_ordertype    = CODELKUP.DESCRIPTION,  
            @c_Route        = IsNULL(ORDERS.Route, ''),  
            @c_NewPostCode = (ISNULL(ORDERS.C_City,'') + ' ' + ISNULL(ORDERS.C_State,'') + ' ' +ISNULL(ORDERS.C_Zip,'')),   
            @c_OHTypeDesc = ISNULL(CODELKUP.short,'')                                                                       
            FROM   ORDERS (NOLOCK), CODELKUP (NOLOCK)  
            WHERE   ORDERS.OrderKey = @c_OrderKey  
            AND     ORDERS.TYPE = CODELKUP.CODE  
            AND     LISTNAME = 'ORDERTYPE'  
         END -- IF @c_OrderKey = ''  
   
  
         SELECT @n_loccnt=count(distinct PickDetail.loc)  
         FROM   PickDetail (NOLOCK),  LoadPlanDetail (NOLOCK),  
         PACK (NOLOCK),        LOC (NOLOCK)  
         WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey  
         --       AND    PickDetail.Status < '9' -- SOS 5933 Pickslips can be displayed even confirmed picked  
         AND    PickDetail.Packkey = PACK.Packkey  
         AND    LOC.Loc = PICKDETAIL.Loc  
         AND    LoadPlanDetail.LoadKey = @c_loadkey  
         AND    PickDetail.sku = @c_SKU  
         GROUP BY LoadPlanDetail.LoadKey    
           
         SELECT @c_skuindicator = case when isnull(cl.code,'') <> '' and @n_loccnt <> 1 Then 'R' else '' end  
               ,@c_ShowSusr5 = CASE WHEN (CL1.Short IS NULL OR CL1.Short = 'N') THEN 'N' ELSE 'Y' END  
               ,@c_ShowFullLoc = CASE WHEN (CL2.Short IS NULL OR CL2.Short = 'N') THEN 'N' ELSE 'Y' END  
               ,@c_showordtype = CASE WHEN (CL3.Short IS NULL OR CL3.Short = 'N') THEN 'N' ELSE 'Y' END                          
               ,@c_Showcitystate = CASE WHEN (CL4.Short IS NULL OR CL4.Short = 'N') THEN 'N' ELSE 'Y' END                          
               ,@c_ShowEachInInnerCol = CASE WHEN (CL5.Short IS NULL OR CL5.Short = 'N') THEN 'N' ELSE 'Y' END     
         FROM sku s WITH (NOLOCK)  
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'RPTCFGPICK' AND CL.Long = 'r_dw_print_pickorder10'    
                                        AND CL.Storerkey = s.Storerkey and CL.Code=s.susr3)   
         LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.ListName = 'REPORTCFG' AND CL1.Long = 'r_dw_print_pickorder10'  
                                              AND CL1.Code = 'SHOWSUSR5'   
                                              AND CL1.Storerkey = s.StorerKey  
         LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.ListName = 'REPORTCFG' AND CL2.Long = 'r_dw_print_pickorder10'  
                                              AND CL2.Code = 'ShowFullLoc' AND CL2.Storerkey = s.StorerKey      
         LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.ListName = 'REPORTCFG' AND CL3.Long = 'r_dw_print_pickorder10'  
                                              AND CL3.Code = 'ShowOrdType' AND CL3.Storerkey = s.StorerKey   
         LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.ListName = 'REPORTCFG' AND CL4.Long = 'r_dw_print_pickorder10'  
                                              AND CL4.Code = 'ShowCityState' AND CL4.Storerkey = s.StorerKey                                             
         LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON CL5.ListName = 'REPORTCFG' AND CL5.Long = 'r_dw_print_pickorder10'  
                                             AND CL5.Code = 'ShowEachInInnerCol' AND CL5.Storerkey = s.StorerKey                                        
         WHERE s.storerkey= @c_storerkey    
         AND s.sku = @c_SKU  
  
  
  
  
  
         SELECT @c_TrfRoom    = IsNULL(LoadPlan.TrfRoom, ''),  
                @c_VehicleNo  = IsNULL(LoadPlan.TruckSize, ''),  
                @c_Carrierkey = IsNULL(LoadPlan.CarrierKey,'')  
         FROM   LoadPlan (NOLOCK)  
         WHERE  Loadkey = @c_LoadKey  
  
         SELECT @c_Route_Desc = IsNull(RouteMaster.Descr, '')  
         FROM   RouteMaster (NOLOCK)  
         WHERE  Route = @c_Route  
  
         SELECT @c_SkuDesc = IsNULL(Descr,'')  
               ,@c_susr5 = ISNULL(SUSR5,'')                
         FROM   SKU  (NOLOCK)  
         WHERE  SKU = @c_SKU  
         and storerkey = @c_storerkey  
  
         SELECT @c_Lottable01 = Lottable01,  
                @c_Lottable02 = ISNULL(Lottable02, ''),  
                @c_Lottable03 = ISNULL(Lottable03, ''),  
                @d_Lottable04 = Lottable04  
         FROM   LOTATTRIBUTE (NOLOCK)  
         WHERE  LOT = @c_LOT  
  
         IF @c_Lottable01  IS NULL SELECT @c_Lottable01 = ''  
         IF @d_Lottable04  IS NULL SELECT @d_Lottable04 = '01/01/1900'  
         IF @c_Notes1   IS NULL SELECT @c_Notes1 = ''  
         IF @c_Notes2   IS NULL SELECT @c_Notes2 = ''  
         IF @c_Externorderkey IS NULL SELECT @c_Externorderkey=''  
         IF @c_ConsigneeKey IS NULL SELECT @c_ConsigneeKey = ''  
         IF @c_Company   IS NULL SELECT @c_Company = ''  
         IF @c_Addr1    IS NULL SELECT @c_Addr1 = ''  
         IF @c_Addr2    IS NULL SELECT @c_Addr2 = ''  
         IF @c_Addr3    IS NULL SELECT @c_Addr3 = ''  
         IF @c_PostCode   IS NULL SELECT @c_PostCode = ''  
         IF @c_Route    IS NULL SELECT @c_Route = ''  
         IF @c_CarrierKey  IS NULL SELECT @c_Carrierkey = ''  
         IF @c_Route_Desc  IS NULL SELECT @c_Route_Desc = ''  
  
         IF @c_superorderflag = 'Y' SELECT @c_orderkey = ''  
  
         SELECT @n_RowNo = @n_RowNo + 1  
         SELECT @n_Pallets = 0,  
         @n_Cartons = 0,  
         @n_inner = 0, -- Add by June 09.Dec.03 (SOS18183)  
         @n_Eaches  = 0  
  
         SELECT @n_UOMQty = 0  
  
         SELECT @n_UOMQty = CASE @c_UOM  
                            WHEN '1' THEN PACK.Pallet  
                            WHEN '2' THEN PACK.CaseCnt  
                            WHEN '3' THEN PACK.InnerPack  
                            ELSE 1  
                            END,  
                @c_UOM_master = PACK.PackUOM3,  
                @n_pallets = pack.pallet,  
                @n_cartons = pack.casecnt,  
                @n_inner = pack.innerpack  
         FROM   PACK, SKU  
         WHERE  SKU.SKU = @c_SKU  
         AND    SKU.Storerkey = @c_storerkey -- Add by June 09.Dec.03 (SOS18183)  
         AND    PACK.PackKey = SKU.PackKey  

         IF @c_ShowEachInInnerCol = 'Y'
         BEGIN
            SELECT @c_ShowEachInInnerCol = CASE WHEN ISNULL(PACK.PackUOM9,'') <> '' AND
                                                     ISNULL(PACK.PackUOM9,'') NOT IN (SELECT DISTINCT Code 
                                                                                      FROM Codelkup (NOLOCK) 
                                                                                      WHERE Storerkey = SKU.Storerkey AND LISTNAME = 'ELANCO_UOM') AND
                                                     PACK.OtherUnit2 > 0 THEN 'Y' ELSE 'N' END
            FROM SKU (NOLOCK) 
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            WHERE SKU.SKU = @c_SKU AND SKU.Storerkey = @c_storerkey
         END
  
      INSERT INTO #Temp_Pick  
      (PickSlipNo,    LoadKey,          OrderKey,  Externorderkey, ConsigneeKey,  
      Company,       Addr1,            Addr2,         PgGroup,  
      Addr3,         PostCode,         Route,  
      Route_Desc,    TrfRoom,          Notes1,        RowNum,  
      Notes2,        LOC,              SKU,  
      SkuDesc,   Qty,     TempQty1,  
      TempQty2,    PrintedFlag,      Zone,  
      Lot,    CarrierKey,       VehicleNo,     Lottable01,  
      Lottable02,    Lottable03,       Lottable04,  LabelPrice,  
      storerkey,  invoiceno,   deliverydate,  
      ordertype,  qtyorder,   qtyallocated, logicallocation, casecnt, pallet, innerpack,skuindicator , LRoute     
      , LEXTLoadKey , LPriority,LUdef01,SUSR5,ShowSusr5,ShowFullLoc          
      ,Showordtype,ShowCityState,OHTypeDesc,NewPostcode,ShowPickdetailID,ID, Putawayzone, BreakByPAZone, RetailSKU, ShowPageNoByOrderkey,      
      ShowEachInInnerCol)   
      VALUES  
      (@c_pickheaderkey, @c_LoadKey,      @c_OrderKey,  @c_Externorderkey, @c_ConsigneeKey,  
      @c_Company,     @c_Addr1,        @c_Addr2,     0,  
      @c_Addr3,       @c_PostCode,     @c_Route,  
      @c_Route_Desc,     @c_TrfRoom,      @c_Notes1,   @n_RowNo,  
      @c_Notes2,     @c_LOC,          @c_SKU,  
      @c_SKUDesc,     @n_Qty,          CAST(@c_UOM as int),  
      @n_UOMQty,     @c_PrintedFlag, '3',  
      @c_Lot,        @c_Carrierkey,   @c_VehicleNo,  @c_Lottable01,  
      @c_Lottable02,     @c_Lottable03,   @d_Lottable04,  @c_labelprice,  
      @c_storerkey,     @c_invoiceno,    @d_deliverydate,  
      @c_ordertype,    @n_qtyorder,     @n_qtyallocated,@c_logicalloc, @n_cartons, @n_pallets,  
      @n_inner,          @c_skuindicator, @c_LRoute , @c_LEXTLoadKey, @c_LPriority,@c_LUDef01,@c_susr5,@c_ShowSusr5,@c_ShowFullLoc,       
      @c_showordtype,    @c_showcitystate,@c_OHTypeDesc,@c_NewPostCode,@c_ShowPickdetailID,@c_ID, @c_PAZone, @c_BreakByPAZone, @c_RetailSKU,      
      @c_ShowPageNoByOrderkey, @c_ShowEachInInnerCol)      
  
      SELECT @c_PrevOrderKey = @c_OrderKey  
  
      FETCH NEXT FROM pick_cur INTO @c_sku,   @c_loc, @n_Qty,   @n_uom3, @c_storerkey,  
      @c_orderkey, @c_UOM, @c_logicalloc, @c_LOT,@c_LRoute,@c_LEXTLoadKey,@c_LPriority,@c_LUDef01,    
      @c_ID,      
      @c_PAZone, @c_RetailSKU   
   END  
  
   CLOSE pick_cur  
   DEALLOCATE pick_cur  
  
   DECLARE cur1 CURSOR  FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT OrderKey FROM #temp_pick  
   WHERE ORDERKEY <> ''  
  
   OPEN cur1  
   FETCH next FROM cur1  
   INTO @c_orderkey  
  
   WHILE (@@fetch_status <> -1)  
   BEGIN  
      SELECT @n_qtyorder = SUM(ORDERDETAIL.OpenQty),  
             @n_qtyallocated = SUM(ORDERDETAIL.QtyAllocated)  
      FROM orderdetail (nolock)  
      WHERE ORDERDetail.orderkey = @c_orderkey  
  
--      SET @c_skuindicator = ''           
--  
--      IF EXISTS (SELECT TOP 1 s.sku,s.susr3,c.short  
--                 FROM codelkup c WITH (nolock)  
--                  INNER JOIN sku s WITH (nolock) on s.storerkey=c.storerkey   
--                  AND  s.susr3 = c.short  
--                  AND c.storerkey=@c_storerkey  
--                  AND s.sku=@c_sku  
--                  AND listname = 'REPORTCFG'  
--                  AND code ='SHOWSKUMULTILOC' )  
--  
--         BEGIN  
--         SET @c_skuindicator = 'R'  
--         END  
  
      UPDATE #temp_pick  
      SET QtyOrder     = @n_qtyorder,  
          QtyAllocated = @n_qtyallocated  
       --   SKUIndicator = @c_skuindicator              
      WHERE   orderkey = @c_orderkey  
  
      FETCH NEXT FROM cur1 INTO @c_orderkey  
   End  
  
   CLOSE cur1  
   DEALLOCATE cur1  
     
   IF @c_ShowPageNoByOrderkey = 'Y'  
   BEGIN  
      INSERT INTO #PagenoByOrderkey (Pickslipno, Loadkey, Orderkey, TotalPage)  
      SELECT t.Pickslipno, t.LoadKey, t.OrderKey, COUNT(t.Loadkey + t.OrderKey + t.Putawayzone) / @n_MaxLine + 1  
      FROM #temp_pick t  
      GROUP BY t.Putawayzone, t.Pickslipno, t.LoadKey, t.OrderKey  
  
      SELECT TOP 1 @c_LastPutawayzone = Putawayzone  
      from #temp_pick t  
      ORDER BY LoadKey, OrderKey, Putawayzone, LogicalLocation, loc, sku, lottable01, lottable02, lottable03, lottable04, id  
  
      DECLARE CUR_LOOP CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT t.putawayzone, t.loadkey, t.orderkey, logicallocation, loc, sku, lottable01, lottable02, lottable03, lottable04, id  
      FROM #temp_pick t  
      ORDER BY loadkey, orderkey, Putawayzone, LogicalLocation, loc, sku, lottable01, lottable02, lottable03, lottable04, id  
  
      OPEN CUR_LOOP  
  
      FETCH NEXT FROM CUR_LOOP INTO  @c_GetPutawayzone   
                                    ,@c_GetLoadkey       
                                    ,@c_GetOrderkey   
                                    ,@c_logicalloc  
                                    ,@c_loc  
                                    ,@c_sku  
                                    ,@c_lottable01  
                                    ,@c_lottable02  
                                    ,@c_lottable03  
                                    ,@d_lottable04  
                                    ,@c_id   
  
      WHILE @@FETCH_STATUS <> - 1  
      BEGIN  
         IF @c_LastPutawayzone <> @c_GetPutawayzone AND @c_LastLoadkey = @c_GetLoadkey AND @c_LastOrderkey = @c_GetOrderkey AND @b_flag = 0  
         BEGIN  
            SET @n_CurrentPG = @n_CurrentPG + 1  
            SET @n_CurrentCnt = 1  
         END  
           IF @c_LastLoadkey = @c_GetLoadkey AND @c_LastOrderkey <> @c_GetOrderkey  
         BEGIN  
            SET @n_CurrentPG = 1  
            SET @n_CurrentCnt = 1  
         END  
  
         --SELECT  @n_CurrentCnt, @n_CurrentPG, @c_GetPutawayzone   
         --                           ,@c_GetLoadkey       
         --                           ,@c_GetOrderkey   
         --                           ,@c_logicalloc  
         --                           ,@c_loc  
         --                           ,@c_sku  
         --                           ,@c_lottable01  
         --                           ,@c_lottable02  
         --                           ,@c_lottable03  
         --                           ,@d_lottable04  
         --                           ,@c_id  
  
         SET @b_flag = 0  
  
         UPDATE #temp_pick  
         SET CurrentPage = @n_CurrentPG  
         WHERE Putawayzone =  @c_GetPutawayzone   
         AND Loadkey = @c_GetLoadkey       
         AND Orderkey = @c_GetOrderkey   
         AND logicallocation = @c_logicalloc  
         AND loc = @c_loc  
         AND sku = @c_sku  
         AND lottable01 = @c_lottable01  
         AND lottable02 = @c_lottable02  
         AND lottable03 = @c_lottable03  
         AND lottable04 = @d_lottable04  
         AND id = @c_id  
  
         IF @n_CurrentCnt = @n_MaxLine  
         BEGIN  
            SET @n_CurrentPG = @n_CurrentPG + 1  
            SET @n_CurrentCnt = 0  
            SET @b_flag = 1  
         END  
  
         SET @n_CurrentCnt = @n_CurrentCnt + 1  
         SET @c_LastPutawayzone = @c_GetPutawayzone  
         SET @c_LastLoadkey = @c_GetLoadkey   
         SET @c_LastOrderkey = @c_GetOrderkey  
  
         FETCH NEXT FROM CUR_LOOP INTO  @c_GetPutawayzone   
                                       ,@c_GetLoadkey       
                                       ,@c_GetOrderkey   
                                       ,@c_logicalloc  
                                       ,@c_loc  
                                       ,@c_sku  
                                       ,@c_lottable01  
                                       ,@c_lottable02  
                                       ,@c_lottable03  
                                       ,@d_lottable04  
                                       ,@c_id  
      END  
      CLOSE CUR_LOOP  
      DEALLOCATE CUR_LOOP  
        
      DECLARE CUR_LOOPUDPATE CURSOR FAST_FORWARD READ_ONLY FOR  
      select t.loadkey, t.orderkey, MAX(CURRENTPAGE)  
      from #temp_pick t  
      GROUP BY  t.loadkey, t.orderkey  
  
      OPEN CUR_LOOPUDPATE  
  
      FETCH NEXT FROM CUR_LOOPUDPATE INTO  @c_GetLoadkey       
                                          ,@c_GetOrderkey   
                                          ,@n_GetTotalPage  
                                          
      WHILE @@FETCH_STATUS <> - 1  
      BEGIN  
         UPDATE #temp_pick  
         SET TotalPage = @n_GetTotalPage  
         WHERE LoadKey = @c_GetLoadkey  
         AND OrderKey = @c_GetOrderkey  
  
         FETCH NEXT FROM CUR_LOOPUDPATE INTO  @c_GetLoadkey       
                                             ,@c_GetOrderkey   
                                             ,@n_GetTotalPage  
      END  
      CLOSE CUR_LOOPUDPATE  
      DEALLOCATE CUR_LOOPUDPATE  
   END  
    
  
  
   SET @c_SQL = N'SELECT #temp_pick.*, pickheader.adddate ' + CHAR(13) +   
                 'FROM #temp_pick, pickheader (nolock) ' + CHAR(13) +   
                 'WHERE #temp_pick.pickslipno = pickheader.pickheaderkey '  + CHAR(13)   
  
   IF @c_BreakByPAZone = 'Y'  
   BEGIN  
      SET @c_OrderBy = N'ORDER BY #temp_pick.loadkey, #temp_pick.orderkey, #temp_pick.Putawayzone, #temp_pick.LogicalLocation, #temp_pick.LOC, ' +  
                       N'#temp_pick.sku, #temp_pick.lottable01, #temp_pick.lottable02, #temp_pick.lottable03, #temp_pick.lottable04, #temp_pick.id '  
   END  
   ELSE  
   BEGIN  
      SET @c_OrderBy = N'ORDER BY #temp_pick.loadkey, #temp_pick.orderkey, #temp_pick.logicallocation, #temp_pick.loc, ' + CHAR(13)  
                     +  '#temp_pick.sku, #temp_pick.lottable01, #temp_pick.lottable02, #temp_pick.lottable03, #temp_pick.lottable04 '  
   END  
  
   SET @c_SQL = @c_SQL + ' ' + @c_OrderBy  
  
   EXECUTE sp_executesql @c_SQL  
  
END  

GO