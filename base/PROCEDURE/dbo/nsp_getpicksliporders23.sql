SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: nsp_GetPickSlipOrders23                          		*/  
/* Creation Date: 15-Jan-2007                                       		*/  
/* Copyright: IDS                                                       */  
/* Written by: James                                               			*/  
/*                                                                      */  
/* Purpose:  Pacific Brands - Discrete Pickslip (SOS66014)      				*/  
/*                                                                      */  
/* Input Parameters:  @c_loadkey  - Loadkey           									*/  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_print_pickorder23            			*/  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 14/05/2007   FKLIM    -Add New Field BuyerPO (SOS75657)    			   */  
/* 03/01/2008   SHONG        -Add New Field UserDefine02 (SOS94794)     */
/* 28-Jan-2019  TLTING_ext 1.2 enlarge externorderkey field length      */
  
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_GetPickSlipOrders23] (@c_loadkey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_PickHeaderKey  NVARCHAR(10),  
      @n_continue         int,  
      @c_errmsg           NVARCHAR(255),  
      @b_success          int,  
      @n_err              int,  
      @c_OrderKey         NVARCHAR(10),  
      @c_StorerKey        NVARCHAR(15),  
      @c_SKU              NVARCHAR(20),  
      @c_SKUDesc          NVARCHAR(60),  
      @n_Qty              int,  
      @c_ConsigneeKey     NVARCHAR(15),  
      @c_Company          NVARCHAR(45),  
      @c_Addr1            NVARCHAR(45),  
      @c_Addr2            NVARCHAR(45),  
      @c_Addr3            NVARCHAR(45),  
      @c_Addr4            NVARCHAR(45),  
      @c_PostCode         NVARCHAR(15),  
      @c_Route            NVARCHAR(10),  
      @c_Route_Desc       NVARCHAR(60),   
      @c_Notes1           NVARCHAR(60),  
      @c_Notes2           NVARCHAR(60),  
      @n_CaseCnt          int,  
    	@n_InnerPack    int,     
      @c_ExternOrderKey   NVARCHAR(50),    --tlting_ext
      @c_Zone             NVARCHAR(1),  
      @c_PrintedFlag      NVARCHAR(1),  
      @c_FirstTime        NVARCHAR(1),  
    	@c_BuyerPO       NVARCHAR(20), --FKLIM  
      @c_UserDefine02     NVARCHAR(20)  --SOS94794  
  
   CREATE TABLE #temp_pick  
   (  PickSlipNo       NVARCHAR(10) NULL,  
      LoadKey          NVARCHAR(10) NULL,  
      OrderKey         NVARCHAR(10) NULL,  
      ConsigneeKey     NVARCHAR(15) NULL,  
      Company          NVARCHAR(45) NULL,  
      Addr1            NVARCHAR(45) NULL,  
      Addr2            NVARCHAR(45) NULL,  
      Addr3            NVARCHAR(45) NULL,  
      Addr4            NVARCHAR(45) NULL,  
      PostCode         NVARCHAR(18) NULL,  
      Route            NVARCHAR(10) NULL,  
      Route_Desc       NVARCHAR(60) NULL,  
      Notes1           NVARCHAR(60) NULL,  
      Notes2           NVARCHAR(60) NULL,  
      SKU              NVARCHAR(20) NULL,  
      SkuDesc          NVARCHAR(60) NULL,  
      Qty              int,  
      TempQty1        int,  
      TempQty2        int,  
      ExternOrderKey   NVARCHAR(50) NULL,    --tlting_ext
      Zone             NVARCHAR(1)  NULL,  
      PrintedFlag      NVARCHAR(1)  NULL,  
    	BuyerPO       NVARCHAR(20) NULL, --FKLIM  
      UserDefine02     NVARCHAR(20)  )    --SOS94794  
         
   SELECT @n_continue = 1   
      
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK)  
   WHERE ExternOrderKey = @c_loadkey  
   AND   Zone = '3')  
   BEGIN  
      SELECT @c_FirstTime = 'N'  
      SELECT @c_PrintedFlag = 'Y'  
   END  
   ELSE  
   BEGIN  
      SELECT @c_FirstTime = 'Y'  
      SELECT @c_PrintedFlag = 'N'  
   END -- Record Not Exists  
  
   BEGIN TRAN  
   -- Uses PickType as a Printed Flag  
   UPDATE PickHeader  
   SET PickType = '1',  
       TrafficCop = NULL  
   WHERE ExternOrderKey = @c_loadkey  
   AND Zone = '3'  
   AND PickType = '0'  
  
   SELECT @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SELECT @n_continue = 3  
      IF @@TRANCOUNT >= 1  
      BEGIN  
         ROLLBACK TRAN  
         GOTO FAILURE  
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
         GOTO FAILURE  
      END  
   END  
  
   DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PickDetail.OrderKey,   
      PickDetail.StorerKey,   
      PickDetail.SKU,       
      SUM(PickDetail.Qty)  
   FROM PickDetail WITH (NOLOCK)  
   INNER JOIN LoadPlanDetail WITH (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey)  
   WHERE LoadPlanDetail.LoadKey = @c_loadkey  
   GROUP BY PickDetail.OrderKey,   
      PickDetail.StorerKey,   
      PickDetail.SKU  
   ORDER BY PickDetail.Orderkey  
         
   OPEN pick_cur  
  
   FETCH NEXT FROM pick_cur INTO @c_OrderKey, @c_StorerKey, @c_SKU, @n_Qty   
              
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,  
           @c_Company      = ORDERS.c_Company,  
           @c_Addr1        = ORDERS.C_Address1,  
           @c_Addr2        = ORDERS.C_Address2,  
           @c_Addr3        = ORDERS.C_Address3,  
           @c_Addr4        = ORDERS.C_Address4,  
           @c_PostCode     = ORDERS.C_Zip,  
           @c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes),  
           @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),  
           @c_ExternOrderKey = ORDERS.ExternOrderKey,  
       @c_BuyerPO    = ORDERS.BuyerPO, --FKLIM  
           @c_UserDefine02 = ISNULL(ORDERS.Userdefine02, '') -- SOS94794  
      FROM   ORDERS WITH (NOLOCK)    
      WHERE  ORDERS.OrderKey = @c_OrderKey  
     
      SELECT @c_Route = IsNULL(LoadPlan.Route, '')  
      FROM   LoadPlan WITH (NOLOCK)  
      WHERE  Loadkey = @c_LoadKey  
        
      SELECT @c_Route_Desc  = IsNULL(RouteMaster.Descr, '')  
      FROM   RouteMaster WITH (NOLOCK)  
      WHERE  Route = @c_Route  
        
      SELECT @c_SKUDesc = IsNULL(SKU.Descr,'')  
      FROM   SKU WITH (NOLOCK)  
      WHERE  SKU = @c_SKU  
          
      IF @c_Notes1        IS NULL SELECT @c_Notes1 = ''  
      IF @c_Notes2        IS NULL SELECT @c_Notes2 = ''  
      IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ''  
      IF @c_Company       IS NULL SELECT @c_Company = ''  
      IF @c_Addr1         IS NULL SELECT @c_Addr1 = ''  
      IF @c_Addr2         IS NULL SELECT @c_Addr2 = ''  
      IF @c_Addr3         IS NULL SELECT @c_Addr3 = ''  
      IF @c_Addr4         IS NULL SELECT @c_Addr4 = ''  
      IF @c_PostCode      IS NULL SELECT @c_PostCode = ''  
      IF @c_Route         IS NULL SELECT @c_Route = ''  
      IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ''  
    IF @c_BuyerPO    IS NULL SELECT @c_BuyerPO = '' --FKLIM  
           
      -- Select casecnt and innerpack instead of based on UOM, then store into TempQty1 and TempQty2   
      SELECT @n_CaseCnt = 0, @n_InnerPack = 0  
      SELECT @n_CaseCnt = PACK.CaseCnt,  
         @n_InnerPack = PACK.InnerPack  
      FROM PACK WITH (NOLOCK)  
      INNER JOIN SKU WITH (NOLOCK) ON (PACK.PackKey = SKU.PackKey)  
      WHERE  SKU.SKU = @c_SKU  
        
      SELECT @c_PickHeaderKey = NULL  
           
      SELECT @c_PickHeaderKey = ISNULL(PickHeaderKey, '')   
      FROM PickHeader WITH (NOLOCK)   
      WHERE ExternOrderKey = @c_loadkey  
      AND   Zone = '3'  
      AND   OrderKey = @c_OrderKey  
            
      INSERT INTO #Temp_Pick  
         (PickSlipNo,         LoadKey,          OrderKey,         ConsigneeKey,  
         Company,             Addr1,            Addr2,            Addr3,  
         Addr4,               PostCode,         Route,            Route_Desc,  
         Notes1,              Notes2,           SKU,              SkuDesc,  
         Qty,                 TempQty1,         TempQty2,         ExternOrderKey,  
         Zone,                PrintedFlag,    BuyerPO,          UserDefine02)--FKLIM  
      VALUES   
         (@c_PickHeaderKey,   @c_LoadKey,       @c_OrderKey,     @c_ConsigneeKey,  
          @c_Company,         @c_Addr1,         @c_Addr2,        @c_Addr3,  
          @c_Addr4,           @c_PostCode,      @c_Route,        @c_Route_Desc,  
          @c_Notes1,          @c_Notes2,        @c_SKU,          @c_SKUDesc,  
          @n_Qty,             @n_CaseCnt,       @n_InnerPack,    @c_ExternOrderKey,  
          '3',                @c_PrintedFlag,   @c_BuyerPO,      @c_UserDefine02) --FKLIM  
            
         FETCH NEXT FROM pick_cur INTO @c_OrderKey, @c_StorerKey, @c_SKU, @n_Qty   
      END  
         
   CLOSE pick_cur     
   DEALLOCATE pick_cur     
  
   DECLARE @n_pickslips_required int,  
          @c_NextNo NVARCHAR(10)   
     
   SELECT @n_pickslips_required = Count(DISTINCT OrderKey)   
   FROM #TEMP_PICK  
   WHERE RTRIM(PickSlipNo) IS NULL OR RTRIM(PickSlipNo) = ''  
   IF @@ERROR <> 0  
   BEGIN  
      GOTO FAILURE  
   END  
   ELSE IF @n_pickslips_required > 0  
   BEGIN  
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_NextNo OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
      IF @b_success <> 1   
         GOTO FAILURE   
        
        
      SELECT @c_OrderKey = ''  
      WHILE 1=1  
      BEGIN  
         SELECT @c_OrderKey = MIN(OrderKey)  
         FROM   #TEMP_PICK   
         WHERE  OrderKey > @c_OrderKey  
         AND    PickSlipNo IS NULL   
           
         IF RTRIM(@c_OrderKey) IS NULL OR RTRIM(@c_OrderKey) = ''  
            BREAK  
           
         IF NOT Exists(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)  
         BEGIN  
            SELECT @c_PickHeaderKey = 'P' + @c_NextNo   
            SELECT @c_NextNo = RIGHT ( REPLICATE ('0', 9) + LTRIM( RTRIM( STR( CAST(@c_NextNo AS int) + 1))), 9)  
              
            BEGIN TRAN  
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
            VALUES (@c_PickHeaderKey, @c_OrderKey, @c_LoadKey, '0', '3', '')  
              
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               IF @@TRANCOUNT >= 1  
               BEGIN  
                  ROLLBACK TRAN  
                  GOTO FAILURE  
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
                  ROLLBACK TRAN  
                  GOTO FAILURE  
               END  
            END -- @n_err <> 0  
         END -- NOT Exists         
      END   -- WHILE  
        
      UPDATE #TEMP_PICK   
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM  PICKHEADER WITH (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   #TEMP_PICK.PickSlipNo IS NULL  
  
   END  
   GOTO SUCCESS  
  
 FAILURE:  
  DELETE FROM #TEMP_PICK  
  
 SUCCESS:  
  -- Do Auto Scan-in when only 1 storer found and configkey is setup    
  DECLARE @nCnt int,  
   @cStorerKey NVARCHAR(15)  
   
  IF ( SELECT COUNT(DISTINCT StorerKey) FROM  ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)  
     WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND LOADPLANDETAIL.LoadKey = @c_loadkey ) = 1  
  BEGIN   
   -- Only 1 storer found  
   SELECT @cStorerKey = ''  
   SELECT @cStorerKey = (SELECT DISTINCT StorerKey   
           FROM   ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)  
           WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey   
           AND   LOADPLANDETAIL.LoadKey = @c_loadkey )  
    
   IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND  
        SValue = '1' AND StorerKey = @cStorerKey)  
   BEGIN   
    -- Configkey is setup  
    DECLARE @cPickSlipNo NVARCHAR(10)  
   
        SELECT @cPickSlipNo = ''  
        WHILE 1=1  
        BEGIN  
           SELECT @cPickSlipNo = MIN(PickSlipNo)  
           FROM   #TEMP_PICK   
           WHERE  PickSlipNo > @cPickSlipNo  
             
           IF RTRIM(@cPickSlipNo) IS NULL OR RTRIM(@cPickSlipNo) = ''  
              BREAK  
             
           IF NOT Exists(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
           BEGIN  
              INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
              VALUES (@cPickSlipNo, GetDate(), sUser_sName(), NULL)  
           END            
        END  
   END -- Configkey is setup  
  END -- Only 1 storer found  
   
     SELECT * FROM #TEMP_PICK    
     DROP Table #TEMP_PICK    
  
END  

GO