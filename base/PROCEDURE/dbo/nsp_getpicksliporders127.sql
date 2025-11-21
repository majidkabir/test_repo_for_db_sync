SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders127                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose:  TH-Michelin - CR Picking Slip for GA/New Tire type         */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder127                 */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.9                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 19-Nov-2021  Mingle        DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders127] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey  NVARCHAR(10),
      @n_continue          int,
      @c_errmsg            NVARCHAR(255),
      @b_success           int,
      @n_err               int,
      @c_sku               NVARCHAR(25),   
      @n_qty               int,
      @c_loc               NVARCHAR(10),
      @n_cases             int,
      @n_perpallet         int,
      @c_storer            NVARCHAR(15),
      @c_orderkey          NVARCHAR(10),
      @c_ConsigneeKey      NVARCHAR(15),
      @c_Company           NVARCHAR(45),
      @c_Addr1             NVARCHAR(45),
      @c_Addr2             NVARCHAR(45),
      @c_Addr3             NVARCHAR(45),
      @c_PostCode          NVARCHAR(15),
      @c_Route             NVARCHAR(10),
      @c_Route_Desc        NVARCHAR(60), -- RouteMaster.Desc
      @c_TrfRoom           NVARCHAR(5),  -- LoadPlan.TrfRoom
      @c_Notes1            NVARCHAR(60),
      @c_Notes2            NVARCHAR(60),
      @c_SkuDesc           NVARCHAR(60),
      @n_CaseCnt           int,
      @n_InnerPack         int,      
      @n_PalletCnt         int,
      @c_ReceiptTm         NVARCHAR(20),
      @c_PrintedFlag       NVARCHAR(1),
      @c_UOM               NVARCHAR(10),
      @n_UOM3              int,
      @c_Lot               NVARCHAR(10),
      @c_StorerKey         NVARCHAR(15),
      @c_Zone              NVARCHAR(1),
      @n_PgGroup           int,
      @n_TotCases          int,
      @n_RowNo             int,
      @c_PrevSKU           NVARCHAR(25),   
      @n_SKUCount          int,
      @c_Carrierkey        NVARCHAR(60),
      @c_VehicleNo         NVARCHAR(10),
      @c_firstorderkey     NVARCHAR(10),
      @c_superorderflag    NVARCHAR(1),
      @c_firsttime         NVARCHAR(1),
      @c_logicalloc        NVARCHAR(18),
      @c_Lottable01        NVARCHAR(10),
      @d_Lottable04        datetime,
      @c_labelPrice        NVARCHAR(5),
      @c_externorderkey    NVARCHAR(50),            
      @c_Facility          NVARCHAR(5),
      @c_Lottable02        NVARCHAR(18),
      @c_DeliveryNote      NVARCHAR(10),
      @c_ShowCustomFormula NVARCHAR(10), 
      @c_SortByLogicalLoc  NVARCHAR(10), 
      @d_DeliveryDate      DATETIME,      
      @c_Addr4             NVARCHAR(45),
      @c_State             NVARCHAR(45),
      @c_City              NVARCHAR(45),
      @c_Country           NVARCHAR(45),
      @c_Priority          NVARCHAR(20),
      @c_ID                NVARCHAR(20),
      @c_Lottable03        NVARCHAR(10),
      @c_Lottable12        NVARCHAR(10),
      @c_OHRoute           NVARCHAR(10)
      
        
   
   DECLARE @c_PrevOrderKey     NVARCHAR(10),
      @n_Pallets          int,
      @n_Cartons          int,
      @n_Eaches           int,
      @n_UOMQty           int

    
   DECLARE @c_Style           NVARCHAR(20)
         , @c_Color           NVARCHAR(10)
         , @c_Size            NVARCHAR(5)
         , @c_Measurement     NVARCHAR(5)
         , @c_SkuPattern      NVARCHAR(10)
         , @n_WrapSkuDesc     INT            

   DECLARE @c_AltSku          NVARCHAR(20)
         , @n_ShowAltSku      INT         
         , @n_CustCol01       INT         
         , @c_CustCol01_Text  NVARCHAR(60)
         , @c_CustCol01_Field NVARCHAR(60)
         , @n_CustCol02       INT         
         , @c_CustCol02_Text  NVARCHAR(60)
         , @c_CustCol02_Field NVARCHAR(60)
         , @n_CustCol03       INT         
         , @c_CustCol03_Text  NVARCHAR(60)
         , @c_CustCol03_Field NVARCHAR(60)
         , @c_SQL             NVARCHAR(MAX)
         
   DECLARE @c_Sku2          NVARCHAR(20),
           @c_Consigneekey2 NVARCHAR(15)      

   SET @c_Style   = ''
   SET @c_Color   = ''
   SET @c_Size    = ''
   SET @c_Measurement= ''
   SET @c_SkuPattern = ''
         
        
   CREATE TABLE #temp_pick
   (  PickSlipNo          NVARCHAR(10) NULL,
      LoadKey             NVARCHAR(10),
      OrderKey            NVARCHAR(10),
      ConsigneeKey        NVARCHAR(15),
      Company             NVARCHAR(45),
      Addr1               NVARCHAR(45),
      Addr2               NVARCHAR(45),
      Addr3               NVARCHAR(45),
      PostCode            NVARCHAR(15),
      Route               NVARCHAR(10),
      Route_Desc          NVARCHAR(60), -- RouteMaster.Desc
      TrfRoom             NVARCHAR(5),  -- LoadPlan.TrfRoom
      Notes1              NVARCHAR(60),
      Notes2              NVARCHAR(60),
      LOC                 NVARCHAR(10),
      SKU                 NVARCHAR(25),   
      SkuDesc             NVARCHAR(60),
      Qty                 int,
      TempQty1            int,
      TempQty2            int,
      PrintedFlag         NVARCHAR(1),
      Zone                NVARCHAR(1),
      PgGroup             int,
      RowNum              int,
      Lot                 NVARCHAR(10),
      Carrierkey          NVARCHAR(60),
      VehicleNo           NVARCHAR(10),
      Lottable01          NVARCHAR(10),
      Lottable04          datetime, 
      LabelPrice          NVARCHAR(5),
      ExternOrderKey      NVARCHAR(50),  
      -- SOS59298         
      Facility            NVARCHAR(5),
      Lottable02          NVARCHAR(18),
      DeliveryNote        NVARCHAR(10),
      DeliveryDate        datetime,
      SKU2                NVARCHAR(20),
      Consigneekey2       NVARCHAR(15),
      WrapSkuDesc         INT             
   ,  ShowAltSku          INT             
   ,  CustCol01           INT             
   ,  CustCol01_Text      NVARCHAR(60)    
   ,  CustCol02           INT             
   ,  CustCol02_Text      NVARCHAR(60)    
   ,  CustCol03           INT             
   ,  CustCol03_Text      NVARCHAR(60)    
   ,  ShowCustomFormula   NVARCHAR(10)    
   ,  LogicalLoc          NVARCHAR(20)    
   ,  Addr4               NVARCHAR(45)
   ,  [State]             NVARCHAR(45)
   ,  City                NVARCHAR(45)
   ,  Country             NVARCHAR(45)
   ,  [Priority]          NVARCHAR(45)
   ,  ID                  NVARCHAR(10)
   ,  Lottable03          NVARCHAR(10)
   ,  Lottable12          NVARCHAR(10)
   ,  OHRoute             NVARCHAR(10)
       )      
       
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
   
   DECLARE pick_cur CURSOR FOR
   SELECT PickDetail.sku,       PickDetail.loc, 
        SUM(PickDetail.qty),  PACK.Qty,
        PickDetail.storerkey, PickDetail.OrderKey, 
        PickDetail.UOM,       LOC.LogicalLocation,
        Pickdetail.Lot,       PICKDETAIL.ID
   FROM   PickDetail (NOLOCK),  LoadPlanDetail (NOLOCK), 
        PACK (NOLOCK),        LOC (NOLOCK),
        LOTATTRIBUTE (NOLOCK)
   WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
   --AND    PickDetail.Status < '5'
   AND    PickDetail.Packkey = PACK.Packkey
   AND    LOC.Loc = PICKDETAIL.Loc
   --AND    LOTxLOCxID.ID = PICKDETAIL.ID
   AND    PickDetail.Lot = LOTATTRIBUTE.Lot
   AND    LoadPlanDetail.LoadKey = @c_loadkey
   GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
          PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
          LOC.LogicalLocation,  Pickdetail.Lot,      PICKDETAIL.ID    
   ORDER BY PICKDETAIL.ORDERKEY,LOC.LogicalLocation,PickDetail.loc,PickDetail.sku         
       
   OPEN pick_cur
   SELECT @c_PrevOrderKey = ''
   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
      @c_orderkey,  @c_UOM, @c_logicalloc, @c_lot, @c_ID
            
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF @c_OrderKey <> @c_PrevOrderKey
         BEGIN
            SELECT @n_ShowAltSku     = ISNULL(MAX(CASE WHEN Code = 'ShowAltSku' THEN 1 ELSE 0 END),0)
               ,   @n_CustCol01      = ISNULL(MAX(CASE WHEN Code = 'CustCol01' THEN 1 ELSE 0 END),0)
               ,   @c_CustCol01_Text = ISNULL(MAX(CASE WHEN Code = 'CustCol01' THEN UDF01 ELSE '' END),'')
               ,   @c_CustCol01_Field= ISNULL(MAX(CASE WHEN Code = 'CustCol01' THEN UDF02 ELSE '' END),'') 
               ,   @n_CustCol02      = ISNULL(MAX(CASE WHEN Code = 'CustCol02' THEN 1 ELSE 0 END),0)
               ,   @c_CustCol02_Text = ISNULL(MAX(CASE WHEN Code = 'CustCol02' THEN UDF01 ELSE '' END),'')
               ,   @c_CustCol02_Field= ISNULL(MAX(CASE WHEN Code = 'CustCol02' THEN UDF02 ELSE '' END),'')
               ,   @n_CustCol03      = ISNULL(MAX(CASE WHEN Code = 'CustCol03' THEN 1 ELSE 0 END),0)
               ,   @c_CustCol03_Text = ISNULL(MAX(CASE WHEN Code = 'CustCol03' THEN UDF01 ELSE '' END),'')
               ,   @c_CustCol03_Field= ISNULL(MAX(CASE WHEN Code = 'CustCol03' THEN UDF02 ELSE '' END),'')  
            FROM CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'REPORTCFG'
            AND   Storerkey = @c_Storerkey
            AND   Long = 'r_dw_print_pickorder06'
            AND   ISNULL(Short,'') <> 'N'
         END

         IF @c_OrderKey = ''
         BEGIN
            SELECT @c_ConsigneeKey = '',
               @c_Company      = '',
               @c_Addr1        = '',
               @c_Addr2        = '',
               @c_Addr3        = '',
               @c_PostCode     = '',
               @c_Route        = '',
               @c_Route_Desc   = '',
               @c_Notes1       = '',
               @c_Notes2       = '',
               -- SOS59298
               @c_Facility     = '',
               @c_DeliveryNote = '',
               @c_Consigneekey2 = '', 
               @c_Addr4         = '',       
               @c_State         = '',             
               @c_City          = '',              
               @c_Country       = '',
               @c_OHRoute       = ''           
         END
         ELSE
         BEGIN
          SELECT @c_ConsigneeKey = ORDERS.BillToKey,
                 @c_Company      = ORDERS.c_Company,
                 @c_Addr1        = ORDERS.C_Address1,
                 @c_Addr2        = ORDERS.C_Address2,
                 @c_Addr3        = ORDERS.C_Address3,
                 @c_PostCode     = ORDERS.C_Zip,
                 @c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes),
                 @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),
                 @c_labelprice   = ISNULL( ORDERS.LabelPrice, 'N' ),
                 @c_externorderkey = ExternOrderKey,
                 @c_Facility     = ORDERS.Facility,    
                 @c_DeliveryNote = ORDERS.DeliveryNote,
                 @d_DeliveryDate = ORDERS.DeliveryDate, 
                 @c_ConsigneeKey2 = ORDERS.Consigneekey, 
                 @c_Addr4        = ORDERS.C_Address4,
                 @c_State        = ORDERS.C_State,
                 @c_City         = ORDERS.C_City,
                 @c_Country      = ORDERS.C_Country,
                 @c_OHRoute      = ORDERS.Route
          FROM   ORDERS (NOLOCK)  
          WHERE  ORDERS.OrderKey = @c_OrderKey
         END -- IF @c_OrderKey = ''
   
         SELECT @c_TrfRoom   = IsNULL(LoadPlan.TrfRoom, ''),
              @c_Route     = IsNULL(LoadPlan.Route, ''),
              @c_VehicleNo = IsNULL(LoadPlan.TruckSize, ''),
              @c_Carrierkey = IsNULL(LoadPlan.CarrierKey,''),
              @c_Priority = IsNULL(LoadPlan.Priority,'')
         FROM   LoadPlan (NOLOCK)
         WHERE  Loadkey = @c_LoadKey
         
         SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, '')
         FROM   RouteMaster (NOLOCK)
         WHERE  Route = @c_Route
         
         SELECT @c_SkuDesc = IsNULL(Descr,'')
               ,@c_Style   = ISNULL(RTRIM(Style),'')              
               ,@c_Color   = ISNULL(RTRIM(Color),'')              
               ,@c_Size    = ISNULL(RTRIM(Size),'')               
               ,@c_Measurement = ISNULL(RTRIM(Measurement),'')    
               ,@c_AltSku  = ISNULL(RTRIM(AltSku),'')             
         FROM   SKU  (NOLOCK)
         WHERE  Storerkey = @c_storerkey  
         AND    SKU = @c_SKU
         
         --SELECT @c_Lottable01 = Lottable01,
         --   @c_Lottable02 = Lottable02,   -- SOS59298
         --   @d_Lottable04 = Lottable04
         --FROM LOTATTRIBUTE (NOLOCK)
         --WHERE LOT = @c_LOT

         SET @c_SQL = N'SELECT'
                    + ' @c_Lottable01 = ' + CASE WHEN @n_CustCol01 = 0 THEN 'Lottable01' ELSE @c_CustCol02_Field END
                    + ',@c_Lottable02 = ' + CASE WHEN @n_CustCol02 = 0 THEN 'Lottable02' ELSE @c_CustCol02_Field END
                    + ',@d_Lottable04 = ' + CASE WHEN @n_CustCol03 = 0 THEN 'Lottable04' ELSE @c_CustCol03_Field END
                    + ',@c_Lottable03 = ' + 'Lottable03'
                    + ',@c_Lottable12 = ' + 'Lottable12'
                    + ' FROM LOTATTRIBUTE WITH (NOLOCK)'
                    + ' WHERE LOT = @c_Lot'

         EXEC sp_ExecuteSQL @c_SQL
                        , N' @c_Lot          NVARCHAR(10)
                           , @c_Lottable01   NVARCHAR(18)   OUTPUT
                           , @c_Lottable02   NVARCHAR(18)   OUTPUT
                           , @d_Lottable04   DATETIME       OUTPUT
                           , @c_Lottable03   NVARCHAR(18)   OUTPUT
                           , @c_Lottable12   NVARCHAR(18)   OUTPUT'
                        ,  @c_Lot
                        ,  @c_Lottable01 OUTPUT
                        ,  @c_Lottable02 OUTPUT
                        ,  @d_Lottable04 OUTPUT
                        ,  @c_Lottable03 OUTPUT
                        ,  @c_Lottable12 OUTPUT

         IF @c_Lottable01    IS NULL SELECT @c_Lottable01 = ''
         IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = '01/01/1900'         
         IF @c_Notes1        IS NULL SELECT @c_Notes1 = ''
         IF @c_Notes2        IS NULL SELECT @c_Notes2 = ''
         IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ''
         IF @c_Company       IS NULL SELECT @c_Company = ''
         IF @c_Addr1         IS NULL SELECT @c_Addr1 = ''
         IF @c_Addr2         IS NULL SELECT @c_Addr2 = ''
         IF @c_Addr3         IS NULL SELECT @c_Addr3 = ''
         IF @c_PostCode      IS NULL SELECT @c_PostCode = ''
         IF @c_Route         IS NULL SELECT @c_Route = ''
         IF @c_CarrierKey    IS NULL SELECT @c_Carrierkey = ''
         IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ''
         -- SOS59298
         IF @c_Facility      IS NULL SELECT @c_Facility = ''
         IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ''         
         IF @c_DeliveryNote  IS NULL SELECT @c_DeliveryNote = ''
         IF @c_Consigneekey2 IS NULL SELECT @c_Consigneekey2 = ''
         IF @c_Addr4         IS NULL SELECT @c_Addr4 = ''
         IF @c_State         IS NULL SELECT @c_State = ''
         IF @c_City          IS NULL SELECT @c_City = ''
         IF @c_Country       IS NULL SELECT @c_Country = ''
         IF @c_Priority      IS NULL SELECT @c_Priority = ''
         IF @c_Lottable03    IS NULL SELECT @c_Lottable03 = ''
         IF @c_Lottable12    IS NULL SELECT @c_Lottable12 = ''
         IF @c_OHRoute       IS NULL SELECT @c_OHRoute = ''

         IF @c_superorderflag = 'Y' 
          SELECT @c_orderkey = ''
         
         SELECT @n_RowNo = @n_RowNo + 1
         SELECT @n_Pallets = 0,
              @n_Cartons = 0,
              @n_Eaches  = 0
         -- SOS31612
         -- SELECT @n_UOMQty = 0
         -- SELECT @n_UOMQty = CASE @c_UOM
         --                      WHEN '1' THEN PACK.CaseCnt -- Modified by Vicky 17 June 2003 SOS#11807
         --                      WHEN '2' THEN PACK.CaseCnt
         --                      WHEN '3' THEN PACK.InnerPack
         --                      ELSE 1
         --                    END
         -- Select casecnt and innerpack instead of based on UOM, then store into TempQty1 and TempQty2 
         SELECT @n_CaseCnt = 0, @n_InnerPack = 0
         SELECT @n_CaseCnt   = PACK.CaseCnt,
              @n_InnerPack = PACK.InnerPack
         FROM   PACK (nolock), SKU (nolock)
         WHERE  SKU.SKU = @c_SKU
         AND    PACK.PackKey = SKU.PackKey
         AND    SKU.Storerkey = @c_storerkey --SOS237725
         
         SELECT @c_pickheaderkey = NULL
         
         SELECT @c_pickheaderkey = ISNULL(PickHeaderKey, '') 
         FROM PickHeader (NOLOCK) 
         WHERE ExternOrderKey = @c_loadkey
         AND   Zone = '3'
         AND   OrderKey = @c_OrderKey
          
         SELECT @c_SkuPattern = ISNULL(RTRIM(SValue),'')
         FROM STORERCONFIG WITH (NOLOCK) 
         WHERE Storerkey = @c_Storerkey
         AND   ConfigKey = 'PickSlip06_SkuPattern'

         IF @c_SkuPattern = '2'
         BEGIN
         	SET @c_Sku2 = @c_Sku
            SET @n_ShowAltSku = 0
            SET @c_AltSku = ''                     	  
         END
         ELSE
         BEGIN
            --SET @c_Consigneekey2 = ''
            SET @c_Sku2 = ''
            IF @n_ShowAltSku = 1
            BEGIN
               SET @c_Sku2 = @c_AltSku  
            END 
         END
          
         IF @c_SkuPattern IN('1','2') AND LEN(@c_Style + @c_Color + @c_Size + @c_Measurement) > 0
         BEGIN         	  
            SET @c_Sku = @c_Style + '-' + @c_Color + '-' + @c_Size + '-' + @c_Measurement
         END
         
        
         SET @n_WrapSkuDesc = 0
         SELECT @n_WrapSkuDesc = 1
         FROM CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'REPORTCFG'
         AND   Code = 'WrapSkuDesc'
         AND   Storerkey = @c_Storerkey
         AND   Long = 'r_dw_print_pickorder06'
         AND   ISNULL(Short,'') <> 'N'
         
         SET @c_ShowCustomFormula = 'N'
         SELECT @c_ShowCustomFormula = ISNULL(Short,'N')
         FROM CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'REPORTCFG'
         AND   Code = 'ShowCustomFormula'
         AND   Storerkey = @c_Storerkey
         AND   Long = 'r_dw_print_pickorder06'

          
         SET @c_SortByLogicalLoc = 'N'
         SELECT @c_SortByLogicalLoc = ISNULL(Short,'N')
         FROM CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'REPORTCFG'
         AND   Code = 'SortByLogicalLoc'
         AND   Storerkey = @c_Storerkey
         AND   Long = 'r_dw_print_pickorder06'
          
         
         INSERT INTO #Temp_Pick
            (PickSlipNo,         LoadKey,          OrderKey,         ConsigneeKey,
            Company,             Addr1,            Addr2,            PgGroup,
            Addr3,               PostCode,         Route,
            Route_Desc,          TrfRoom,          Notes1,           RowNum,
            Notes2,              LOC,              SKU,
            SkuDesc,             Qty,              TempQty1,
            TempQty2,            PrintedFlag,      Zone,
            Lot,                 CarrierKey,       VehicleNo,        Lottable01,
            Lottable04,          LabelPrice,       ExternOrderKey,
            Facility,            Lottable02,       DeliveryNote ,    DeliveryDate,  
            SKU2,						Consigneekey2
          , WrapSkuDesc                                                                
          , ShowAltSku,          CustCol01,        CustCol01_Text    
          , CustCol02,           CustCol02_Text,   CustCol03         
          , CustCol03_Text                                           
          , ShowCustomFormula   
          , LogicalLoc  
          , Addr4,               State,            City
          , Country,             Priority,         ID 
          , Lottable03,          Lottable12,       OHRoute
            )
         VALUES 
            (@c_pickheaderkey,   @c_LoadKey,       @c_OrderKey,     @c_ConsigneeKey,
             @c_Company,         @c_Addr1,         @c_Addr2,        0,    
             @c_Addr3,           @c_PostCode,      @c_Route,
             @c_Route_Desc,      @c_TrfRoom,       @c_Notes1,       @n_RowNo,
             @c_Notes2,          @c_LOC,           @c_SKU,
             -- SOS31612
             -- @c_SKUDesc,         @n_Qty,           CAST(@c_UOM as int),
             -- @n_UOMQty,          @c_PrintedFlag,   '3',
             @c_SKUDesc,         @n_Qty,           @n_CaseCnt,
             @n_InnerPack,       @c_PrintedFlag,   '3',
             @c_Lot,             @c_Carrierkey,    @c_VehicleNo,     @c_Lottable01,
             @d_Lottable04,      @c_labelprice,    @c_externorderkey,
             @c_Facility,        @c_Lottable02,    @c_DeliveryNote, @d_DeliveryDate,          
             @c_Sku2,			   @c_Consigneekey2
            ,@n_WrapSkuDesc                                                               
          , @n_ShowAltSku,       @n_CustCol01,     @c_CustCol01_Text    
          , @n_CustCol02,        @c_CustCol02_Text,@n_CustCol03         
          , @c_CustCol03_Text                                           
          , @c_ShowCustomFormula   
          , CASE WHEN @c_SortByLogicalLoc = 'Y' THEN @c_logicalloc ELSE '' END 
          , @c_Addr4,            @c_State,         @c_City
          , @c_Country,          @c_Priority,      @c_ID   
          , @c_Lottable03,       @c_Lottable12,    @c_OHRoute
             )
             
         SELECT @c_PrevOrderKey = @c_OrderKey
          
         FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
                                       @c_orderkey, @c_UOM, @c_logicalloc, @c_LOT,@c_ID
      END
       
   CLOSE pick_cur   
   DEALLOCATE pick_cur   

   DECLARE @n_pickslips_required int,
          @c_NextNo NVARCHAR(10) 
   
   SELECT @n_pickslips_required = Count(DISTINCT OrderKey) 
   FROM #TEMP_PICK
   WHERE dbo.fnc_RTrim(PickSlipNo) IS NULL OR dbo.fnc_RTrim(PickSlipNo) = ''
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
         
         IF dbo.fnc_RTrim(@c_OrderKey) IS NULL OR dbo.fnc_RTrim(@c_OrderKey) = ''
            BREAK
         
         IF NOT Exists(SELECT 1 FROM PickHeader (NOLOCK) WHERE OrderKey = @c_OrderKey)
         BEGIN
            SELECT @c_pickheaderkey = 'P' + @c_NextNo 
            SELECT @c_NextNo = RIGHT ( REPLICATE ('0', 9) + dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_NextNo AS int) + 1))), 9)
            
            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_pickheaderkey, @c_OrderKey, @c_LoadKey, '0', '3', '')
            
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
      FROM  PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   #TEMP_PICK.PickSlipNo IS NULL

   END
   GOTO SUCCESS

   FAILURE:
      DELETE FROM #TEMP_PICK

   SUCCESS:
      -- SOS30692 
      -- Do Auto Scan-in when only 1 storer found and configkey is setup      
      DECLARE @nCnt  int,
         @cStorerKey NVARCHAR(15)
   
      IF ( SELECT COUNT(DISTINCT StorerKey) FROM  ORDERS(NOLOCK), LOADPLANDETAIL(NOLOCK)
         WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND   LOADPLANDETAIL.LoadKey = @c_loadkey ) = 1
      BEGIN 
         -- Only 1 storer found
         SELECT @cStorerKey = ''
         SELECT @cStorerKey = (SELECT DISTINCT StorerKey 
                               FROM   ORDERS(NOLOCK), LOADPLANDETAIL(NOLOCK)
                               WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey 
                               AND     LOADPLANDETAIL.LoadKey = @c_loadkey )
      
         IF EXISTS (SELECT 1 FROM STORERCONFIG(NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
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
               
               IF dbo.fnc_RTrim(@cPickSlipNo) IS NULL OR dbo.fnc_RTrim(@cPickSlipNo) = ''
                  BREAK
               
               IF NOT Exists(SELECT 1 FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
               BEGIN
                  INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                  VALUES (@cPickSlipNo, GetDate(), sUser_sName(), NULL)
               END          
            END
         END -- Configkey is setup
      END -- Only 1 storer found
      -- End of SOS30692
 
     SELECT PickSlipNo         
         ,  LoadKey            
         ,  OrderKey           
         ,  ConsigneeKey       
         ,  Company            
         ,  Addr1              
         ,  Addr2              
         ,  Addr3              
         ,  PostCode           
         ,  Route              
         ,  Route_Desc         
         ,  TrfRoom            
         ,  Notes1             
         ,  Notes2             
         ,  LOC                
         ,  SKU                
         ,  SkuDesc            
         ,  Qty                
         ,  TempQty1           
         ,  TempQty2           
         ,  PrintedFlag        
         ,  Zone               
         ,  PgGroup            
         ,  RowNum             
         ,  Lot                
         ,  Carrierkey         
         ,  VehicleNo          
         ,  Lottable01         
         ,  Lottable04         
         ,  LabelPrice         
         ,  ExternOrderKey     
         ,  Facility           
         ,  Lottable02         
         ,  DeliveryNote       
         ,  DeliveryDate       
         ,  SKU2               
         ,  Consigneekey2      
         ,  WrapSkuDesc 
         ,  ShowAltSku                 
         ,  CustCol01                  
         ,  CustCol01_Text             
         ,  CustCol02                  
         ,  CustCol02_Text             
         ,  CustCol03                  
         ,  CustCol03_Text             
         ,  CASE WHEN TempQty1 > 0 AND ShowCustomFormula = 'Y' THEN FLOOR(Qty / TempQty1) ELSE 0 END AS CS   
         ,  CASE WHEN TempQty2 > 0 AND ShowCustomFormula = 'Y' THEN FLOOR((Qty - (CASE WHEN TempQty1 > 0 THEN FLOOR(Qty / TempQty1) * TempQty1 ELSE 0 END) ) / TempQty2) ELSE 0 END AS InnerP   
         ,  CASE WHEN ShowCustomFormula = 'Y' THEN Qty -   
            (CASE WHEN TempQty1 > 0 THEN FLOOR(Qty / TempQty1) * TempQty1 ELSE 0 END) -   
            (CASE WHEN TempQty2 > 0 THEN FLOOR((Qty - (CASE WHEN TempQty1 > 0 THEN FLOOR(Qty / TempQty1) * TempQty1 ELSE 0 END) ) / TempQty2) ELSE 0 END * TempQty2) ELSE 0 END AS EA   
         ,  ShowCustomFormula   
         ,  LogicalLoc 
         ,  Addr4             
         ,  [State]             
         ,  City                
         ,  Country
         ,  Priority 
         ,  ID  
         ,  Lottable03
         ,  Lottable12
         ,  OHRoute
     FROM #TEMP_PICK 
     --ORDER BY OrderKey, LogicalLoc, LOC, SKU	   
     order by loadkey,orderkey,id,Lottable01,Lottable03,Lottable12
     DROP Table #TEMP_PICK  

 END

GO