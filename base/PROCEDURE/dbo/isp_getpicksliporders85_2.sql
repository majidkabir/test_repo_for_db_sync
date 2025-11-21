SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders85_2                          */
/* Creation Date: 21-FEB-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*             Copy and change from isp_GetPickSlipOrders55             */
/* Purpose:  WMS-8051 - [TW] POI-Create New RCM Pick Slip Report        */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder85_2  (NON-ECOM)    */
/*                                                                      */
/* Local Variables:                                                     */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders85_2] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_PickheaderKey   NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PrintedFlag     NVARCHAR(1) 
         , @n_continue        INT 
         , @c_errmsg          NVARCHAR(255) 
         , @b_success         INT 
         , @n_err             INT 

         , @c_Facility        NVARCHAR(5)  
         , @c_orderkey        NVARCHAR(10) 
         , @c_Externorderkey  NVARCHAR(30) 
         , @c_Consigneekey    NVARCHAR(15) 
         , @c_BillToKey       NVARCHAR(15) 
         , @c_Company         NVARCHAR(45) 
         , @c_Addr1           NVARCHAR(45) 
         , @c_Addr2           NVARCHAR(45) 
         , @c_Addr3           NVARCHAR(45) 
         , @c_PostCode        NVARCHAR(15) 
         , @c_Route           NVARCHAR(10) 
         , @c_Route_Desc      NVARCHAR(60)  -- RouteMaster.Desc
         , @c_TrfRoom         NVARCHAR(5)   -- LoadPlan.TrfRoom
         , @c_Carrierkey      NVARCHAR(60) 
         , @c_VehicleNo       NVARCHAR(10) 
         , @c_DeliveryNote    NVARCHAR(10)          
         , @d_DeliveryDate    DATETIME            
         , @c_labelPrice      NVARCHAR(5)   
         , @c_Notes1          NVARCHAR(60)  
         , @c_Notes2          NVARCHAR(60)  

         , @c_StorerKey       NVARCHAR(15)  
         , @c_sku             NVARCHAR(20) 
         , @c_SkuDesc         NVARCHAR(60)  
         , @c_UOM             NVARCHAR(10)  
         , @c_loc             NVARCHAR(10) 
         , @c_ID              NVARCHAR(18)  
         , @n_qty             INT 
         , @c_Logicalloc      NVARCHAR(18)

         , @c_firsttime       NVARCHAR(1)  
  
   DECLARE @c_RetailSKU       NVARCHAR(40)
         , @c_Color           NVARCHAR(10)
         , @c_Size            NVARCHAR(5)
         , @c_Article         NVARCHAR(70) 

   DECLARE @n_PS_required     INT 
         , @c_NextNo          NVARCHAR(10)
         , @c_cdescr          NVARCHAR(120)   --CS02
         , @c_ecomflag        NVARCHAR(50)

   SET @c_RetailSKU   = ''
   SET @c_Color   = ''
   SET @c_Size    = ''
   SET @c_cdescr = ''            --CS02
   
   --Check ECOM orders (WL01)
  SELECT TOP 1 @c_ecomflag = LTRIM(RTRIM(ISNULL(ORDERS.TYPE,'')))
  FROM ORDERS (NOLOCK)
  WHERE ORDERS.LOADKEY = @c_loadkey

  IF (@c_ecomflag = 'ECOM')
  GOTO QUIT_RESULT
        
   CREATE TABLE #temp_pick
   (  PickSlipNo       NVARCHAR(10) NULL 
   ,  PrintedFlag      NVARCHAR(1) 
   ,  Facility         NVARCHAR(5) 
   ,  LoadKey          NVARCHAR(10) 
   ,  OrderKey         NVARCHAR(10) 
   ,  ExternOrderKey   NVARCHAR(30)
   ,  Consigneekey     NVARCHAR(15)
   ,  Company          NVARCHAR(45) 
   ,  Addr1            NVARCHAR(45) 
   ,  Addr2            NVARCHAR(45) 
   ,  Addr3            NVARCHAR(45) 
   ,  PostCode         NVARCHAR(15) 
   ,  BillToKey        NVARCHAR(15) 
   ,  Route            NVARCHAR(10) 
   ,  Route_Desc       NVARCHAR(60)  -- RouteMaster.Desc
   ,  TrfRoom          NVARCHAR(5)   -- LoadPlan.TrfRoom
   ,  Carrierkey       NVARCHAR(60)
   ,  VehicleNo        NVARCHAR(10)
   ,  DeliveryNote     NVARCHAR(10)  
   ,  DeliveryDate     DATETIME  
   ,  LabelPrice       NVARCHAR(5) 
   ,  Notes1           NVARCHAR(60) 
   ,  Notes2           NVARCHAR(60) 
   ,  Article          NVARCHAR(70) 
   ,  SKU              NVARCHAR(20)    
   ,  SkuDesc          NVARCHAR(60) 
   ,  Qty              INT
   ,  LOC              NVARCHAR(10)
   ,  ID               NVARCHAR(18) 
   ,  CDESCR           NVARCHAR(120)               --CS02
 )    
       
   SET @n_continue = 1 
    
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)
   WHERE ExternOrderKey = @c_loadkey
   AND   Zone = '3')
   BEGIN
      SET @c_firsttime = 'N'
      SET @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SET @c_firsttime = 'Y'
      SET @c_PrintedFlag = 'N'
   END -- Record Not Exists

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER WITH (ROWLOCK)
      SET PickType = '1',
      TrafficCop = NULL
   WHERE ExternOrderKey = @c_loadkey
   AND Zone = '3'
   AND PickType = '0'

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
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
         SET @n_continue = 3
         ROLLBACK TRAN
         GOTO FAILURE
      END
   END

   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.OrderKey  
         ,PICKDETAIL.Storerkey
         ,PICKDETAIL.Sku
         ,PICKDETAIL.loc
         ,PICKDETAIL.UOM 
         ,PICKDETAIL.ID
         ,SUM(PICKDETAIL.qty)
         ,LOC.LogicalLocation 
   FROM PICKDETAIL WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK)  ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)
   JOIN LOC  WITH (NOLOCK) ON ( LOC.Loc = PICKDETAIL.Loc)
   WHERE  LOADPLANDETAIL.LoadKey = @c_loadkey
   GROUP BY PICKDETAIL.OrderKey
         ,  PICKDETAIL.storerkey
         ,  PICKDETAIL.sku
         ,  PICKDETAIL.loc
         ,  PICKDETAIL.UOM
         ,  PICKDETAIL.ID
         ,  LOC.LogicalLocation

   ORDER BY PICKDETAIL.ORDERKEY
       
   OPEN CUR_PICK

   
   FETCH NEXT FROM CUR_PICK INTO @c_Orderkey
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_loc
                              ,  @c_UOM
                              ,  @c_ID
                              ,  @n_Qty
                              ,  @c_Logicalloc

            
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @c_OrderKey = ''
      BEGIN
         SET @c_Facility     = '' 
         SET @c_Externorderkey = ''
         SET @c_Consigneekey = '' 
         SET @c_Company      = '' 
         SET @c_Addr1        = '' 
         SET @c_Addr2        = '' 
         SET @c_Addr3        = '' 
         SET @c_PostCode     = '' 
         SET @c_Route        = '' 
         SET @c_Route_Desc   = '' 
         SET @c_BillToKey    = '' 
         SET @c_DeliveryNote = '' 
         SET @c_Labelprice   = 'N'
         SET @c_Notes1       = '' 
         SET @c_Notes2       = '' 
         SET @c_cdescr       = ''
      END
      ELSE
      BEGIN
         SELECT  @c_Facility     = ORDERS.Facility 
               , @c_Externorderkey = ORDERS.ExternOrderKey 
               , @c_ConsigneeKey = ORDERS.Consigneekey 
               , @c_Company      = ORDERS.c_Company 
               , @c_Addr1        = ORDERS.C_Address1 
               , @c_Addr2        = ORDERS.C_Address2 
               , @c_Addr3        = ORDERS.C_Address3
               , @c_PostCode     = ORDERS.C_Zip 
               , @c_BillToKey    = ORDERS.BillToKey 
               , @c_DeliveryNote = ORDERS.DeliveryNote 
               , @d_DeliveryDate = ORDERS.DeliveryDate 
               , @c_Labelprice   = ISNULL( ORDERS.LabelPrice, 'N' ) 
               , @c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes) 
               , @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2)
               , @c_cdescr        = ISNULL(CL.[Description],'') 
          FROM   ORDERS WITH (NOLOCK)  
          LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.listname = 'CVS_CONV'
                                        AND CL.STORERKEY=ORDERS.STORERKEY 
                                        AND CL.UDF01=Left(Orders.MarkforKey,1) 
          WHERE  ORDERS.OrderKey = @c_OrderKey 
      END -- IF @c_OrderKey = ''

      SELECT @c_TrfRoom   = ISNULL(LoadPlan.TrfRoom, '') 
           , @c_Route     = ISNULL(LoadPlan.Route, '') 
           , @c_VehicleNo = ISNULL(LoadPlan.TruckSize, '') 
           , @c_Carrierkey= ISNULL(LoadPlan.CarrierKey,'')
      FROM   LoadPlan WITH (NOLOCK)
      WHERE  Loadkey = @c_LoadKey
      
      SELECT @c_Route_Desc  = ISNULL(RouteMaster.Descr, '')
      FROM   RouteMaster WITH (NOLOCK)
      WHERE  Route = @c_Route
      
      SELECT @c_SkuDesc   = ISNULL(Descr,'')
            ,@c_RetailSKU = ISNULL(RTRIM(RetailSKU),'')              
            ,@c_Color     = ISNULL(RTRIM(Color),'')               
            ,@c_Size      = ISNULL(RTRIM(Size),'') 
            ,@c_Sku       = Sku              
      FROM   SKU WITH (NOLOCK)
      WHERE  Storerkey = @c_storerkey   
      AND    SKU = @c_SKU
      
      IF @c_Facility      IS NULL SET @c_Facility = ''
      IF @c_Consigneekey  IS NULL SET @c_Consigneekey  = ''
      IF @c_Company       IS NULL SET @c_Company = ''
      IF @c_Addr1         IS NULL SET @c_Addr1 = ''
      IF @c_Addr2         IS NULL SET @c_Addr2 = ''
      IF @c_Addr3         IS NULL SET @c_Addr3 = ''
      IF @c_PostCode      IS NULL SET @c_PostCode = ''
      IF @c_BillToKey     IS NULL SET @c_BillToKey = ''
      IF @c_Route         IS NULL SET @c_Route = ''
      IF @c_CarrierKey    IS NULL SET @c_Carrierkey = ''
      IF @c_Route_Desc    IS NULL SET @c_Route_Desc = ''
      IF @c_DeliveryNote  IS NULL SET @c_DeliveryNote = ''
      IF @c_Notes1        IS NULL SET @c_Notes1 = ''
      IF @c_Notes2        IS NULL SET @c_Notes2 = ''

      SET @c_PickheaderKey = ''

      SELECT @c_PickheaderKey = ISNULL(PickHeaderKey, '') 
      FROM PICKHEADER (NOLOCK) 
      WHERE ExternOrderKey = @c_loadkey
      AND   OrderKey = @c_OrderKey
      AND   Zone = '3'

      SET @c_Article = @c_RetailSKU + '-' + @c_Color + '-' + @c_Size  

      INSERT INTO #Temp_Pick
         (  PickSlipNo
         ,  PrintedFlag
         ,  Facility
         ,  LoadKey
         ,  OrderKey 
         ,  ExternOrderKey
         ,  Consigneekey
         ,  Company
         ,  Addr1
         ,  Addr2
         ,  Addr3
         ,  PostCode
         ,  BillToKey 
         ,  Route
         ,  Route_Desc
         ,  TrfRoom
         ,  CarrierKey
         ,  VehicleNo
         ,  DeliveryNote
         ,  DeliveryDate
         ,  LabelPrice 
         ,  Notes1             
         ,  Notes2
         ,  Loc
         ,  Sku 
         ,  SkuDesc 
         ,  Qty
         ,  ID
         ,  Article   
         ,  CDESCR                --CS02          
         )
      VALUES
         (  @c_PickheaderKey
         ,  @c_PrintedFlag
         ,  @c_Facility
         ,  @c_LoadKey
         ,  @c_OrderKey 
         ,  @c_ExternOrderKey
         ,  @c_Consigneekey
         ,  @c_Company
         ,  @c_Addr1
         ,  @c_Addr2
         ,  @c_Addr3
         ,  @c_PostCode
         ,  @c_BillToKey 
         ,  @c_Route
         ,  @c_Route_Desc
         ,  @c_TrfRoom
         ,  @c_CarrierKey
         ,  @c_VehicleNo
         ,  @c_DeliveryNote
         ,  @d_DeliveryDate
         ,  @c_LabelPrice 
         ,  @c_Notes1             
         ,  @c_Notes2
         ,  @c_Loc
         ,  @c_Sku 
         ,  @c_SkuDesc 
         ,  @n_Qty
         ,  @c_ID
         ,  @c_Article 
         ,  @c_cdescr                    --CS02
         )
                 
      FETCH NEXT FROM CUR_PICK INTO @c_Orderkey
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_loc
                                 ,  @c_UOM
                                 ,  @c_ID
                                 ,  @n_Qty
                                 ,  @c_Logicalloc

             
   END
       
   CLOSE CUR_PICK   
   DEALLOCATE CUR_PICK   

   SELECT @n_PS_required = Count(DISTINCT OrderKey) 
   FROM #TEMP_PICK
   WHERE PickSlipNo IS NULL OR RTrim(PickSlipNo) = ''

   IF @n_PS_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP'
                        , 9
                        , @c_NextNo    OUTPUT
                        , @b_success   OUTPUT
                        , @n_err       OUTPUT
                        , @c_errmsg    OUTPUT
                        , 0
                        , @n_PS_required
      IF @b_success <> 1 
         GOTO FAILURE 
      
      
      SET @c_OrderKey = ''
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM   #TEMP_PICK 
      WHERE  PickSlipNo IS NULL OR RTrim(PickSlipNo) = ''
 
      ORDER BY OrderKey

      OPEN CUR_PS
      
      FETCH NEXT FROM CUR_PS INTO @c_Orderkey
               
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF @c_OrderKey IS NULL OR RTrim(@c_OrderKey) = ''
         BEGIN
            BREAK
         END 

         IF NOT EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK) WHERE OrderKey = @c_OrderKey)
         BEGIN
            SET @c_PickheaderKey = 'P' + @c_NextNo 
            SET @c_NextNo = RIGHT ( '000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_NextNo) + 1), 9)
            
            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_PickheaderKey, @c_OrderKey, @c_LoadKey, '0', '3', '')
            
            SET @n_err = @@ERROR
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
      
         FETCH NEXT FROM CUR_PS INTO @c_Orderkey     
      END   -- WHILE
      CLOSE CUR_PS
      DEALLOCATE CUR_PS

      UPDATE #TEMP_PICK 
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM  PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   (#TEMP_PICK.PickSlipNo IS NULL OR RTrim(#TEMP_PICK.PickSlipNo) = '')    --(Wan01)
      --AND   #TEMP_PICK.PickSlipNo IS NULL OR RTrim(#TEMP_PICK.PickSlipNo) = ''    --(Wan01)
   END
   GOTO SUCCESS

   FAILURE:
      DELETE FROM #TEMP_PICK

   SUCCESS:
      IF ( SELECT COUNT(DISTINCT StorerKey) 
           FROM  ORDERS WITH (NOLOCK)
           JOIN  LOADPLANDETAIL(NOLOCK) ON (LOADPLANDETAIL.OrderKey = ORDERS.OrderKey) 
           WHERE LOADPLANDETAIL.LoadKey = @c_loadkey ) = 1
      BEGIN 
         -- Only 1 storer found
         SET @c_StorerKey = ''

         SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey 
         FROM  ORDERS WITH (NOLOCK)
         JOIN  LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = ORDERS.OrderKey) 
         WHERE     LOADPLANDETAIL.LoadKey = @c_loadkey
      
         IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
                    SValue = '1' AND StorerKey = @c_StorerKey)
         BEGIN 
            -- Configkey is setup
            DECLARE CUR_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickSlipno
            FROM   #TEMP_PICK 
            WHERE  PickSlipNo IS NOT NULL OR RTrim(PickSlipNo) <> ''
       
            ORDER BY OrderKey

            OPEN CUR_PI
            
            FETCH NEXT FROM CUR_PI INTO @c_PickSlipno
                     
            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
              
               IF NOT EXISTS(SELECT 1 FROM PICKINGINFO WITH(NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
               BEGIN
                  INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                  VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)
               END  
               FETCH NEXT FROM CUR_PI INTO @c_PickSlipno        
            END
         END -- Configkey is setup
         CLOSE CUR_PI
         DEALLOCATE CUR_PI
      END -- Only 1 storer found

      SELECT 	PickSlipNo       
            ,  PrintedFlag      
            ,  Facility         
            ,  LoadKey          
            ,  OrderKey         
            ,  ExternOrderKey   
            ,  Consigneekey     
            ,  Company          
            ,  Addr1            
            ,  Addr2            
            ,  Addr3            
            ,  PostCode         
            ,  BillToKey        
            ,  Route            
            ,  Route_Desc       
            ,  TrfRoom          
            ,  Carrierkey       
            ,  VehicleNo        
            ,  DeliveryNote     
            ,  DeliveryDate     
            ,  LabelPrice       
            ,  Notes1           
            ,  Notes2           
            ,  Article          
            ,  SKU              
            ,  SkuDesc          
            ,  Qty              
            ,  LOC              
            ,  ID       
            ,  CDESCR                --CS02        
      FROM #TEMP_PICK  
      ORDER BY Orderkey
            ,  Loc
            ,  ID
            ,  Article
            ,  SKU

      DROP Table #TEMP_PICK  
      
 QUIT_RESULT:

 END

GO