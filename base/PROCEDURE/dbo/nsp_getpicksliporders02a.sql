SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders02a                       		*/
/* Creation Date: 04-Feb-2010                           						*/
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                     					*/
/*                                                                      */
/* Purpose:  Create Normal Pickslip for IDSTH - MCLTH   						*/
/*                                                                      */
/* Input Parameters:  @c_LoadKey  - Loadkey 										*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder02a         			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 04-Feb-2010  Vanessa   1.0  SOS161110 Add ALTSKU on pickslip.(Vanessa01) */
/* 04-Jun-2010  NJOW01    1.1  175383 - MCLTH Picking Slip Modify       */
/* 22-Dec-2010  NJOW02    1.2  200315 - Add store type column(storer.susr2)*/
/* 29-Apr-2015  CSCHONG   1.3  SOS339808  (CS01)                        */
/* 09-Jul-2015  CSCHONG   1.4  SOS346307 (CS02)                         */
/* 04-Aug-2015  CSCHONG   1.5  SOS348826 (CS03)                         */
/* 17-Aug-2015  CSCHONG   1.6  SOS350161 (CS04)                         */
/* 28-Jan-2019  TLTING_ext 1.7  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[nsp_GetPickSlipOrders02a] (@c_LoadKey NVARCHAR(10))
 AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @c_pickheaderkey   NVARCHAR(10),
            @n_continue        INT,
            @c_errmsg          NVARCHAR(255),
            @b_success         INT,
            @n_err             INT,
            @c_sku             NVARCHAR(20),
            @c_altsku          NVARCHAR(20), -- (Vanessa01)
            @n_qty             INT,
            @c_loc             NVARCHAR(10),
            @n_cases           INT,
            @n_perpallet       INT,
            @c_storer          NVARCHAR(15),
            @c_orderkey        NVARCHAR(10),
            @c_Externorderkey  NVARCHAR(50),  --tlting_ext
            @c_ConsigneeKey    NVARCHAR(15),
            @c_Company         NVARCHAR(45),
            @c_Addr1           NVARCHAR(45),
            @c_Addr2           NVARCHAR(45),
            @c_Addr3           NVARCHAR(45),
            @c_PostCode        NVARCHAR(15),
            @c_Route           NVARCHAR(10),
            @c_Route_Desc      NVARCHAR(60),	-- RouteMaster.Desc
            @c_TrfRoom         NVARCHAR(5),	-- LoadPlan.TrfRoom
            @c_Notes1          NVARCHAR(60),
            @c_Notes2          NVARCHAR(60),
            @c_SkuDesc         NVARCHAR(60),
            @n_CaseCnt         INT,
            @n_PalletCnt       INT,
            @c_ReceiptTm       NVARCHAR(20),
            @c_PrintedFlag     NVARCHAR(1),
            @c_UOM             NVARCHAR(10),
            @n_UOM3            INT,
            @c_Lot             NVARCHAR(10),
            @c_StorerKey       NVARCHAR(15),
            @c_Zone            NVARCHAR(1),
            @n_PgGroup         INT,
            @n_TotCases        INT,
            @n_RowNo           INT,
            @c_PrevSKU         NVARCHAR(20),
            @n_SKUCount        INT,
            @c_Carrierkey      NVARCHAR(60),
            @c_VehicleNo       NVARCHAR(10),
            @c_firstorderkey   NVARCHAR(10),
            @c_superorderflag  NVARCHAR(1),
            @c_firsttime       NVARCHAR(1),
            @c_logicalloc      NVARCHAR(18),
            @c_Lottable01      NVARCHAR(18),             --(CS03)  
            @c_Lottable02      NVARCHAR(18),	-- SOS15608 --(CS03)
            @c_Lottable03      NVARCHAR(18),             --(CS03)
            @c_Lottable04      NVARCHAR(12),             --(CS03) 
            --@d_Lottable04      DATETIME,               
            @c_LabelPrice      NVARCHAR(5),
            @c_InvoiceNo       NVARCHAR(10),
            @c_uom_master      NVARCHAR(10),
            @d_DeliveryDate    DATETIME,
            @c_OrderType       NVARCHAR(250),
            --@c_Packkey         NVARCHAR(10) -- SOS25509
            @c_id              NVARCHAR(18), --NJOW01
            @c_class           NVARCHAR(10),                                          
            @c_busr6           NVARCHAR(30), 
            @c_busr7           NVARCHAR(30), 
            @c_style           NVARCHAR(20), 
            @c_color           NVARCHAR(10),                                         
            @c_size            NVARCHAR(5),
            @c_susr2           NVARCHAR(20), --NJOW02
            @n_ShowField       INT,          --(CS03)
            @c_Getstorer       NVARCHAR(15), --(CS03)
            @c_Getorderkey     NVARCHAR(10)  --(CS03)
    
    DECLARE @c_PrevOrderKey    NVARCHAR(10),
            @n_Pallets         INT,
            @n_Cartons         INT,
            @n_Eaches          INT,
            @n_UOMQty          INT,
            @n_starttcnt       INT 

   /*CS01 Start*/
   DECLARE @c_LRoute        NVARCHAR(10),
           @c_LEXTLoadKey   NVARCHAR(20),
           @c_LPriority     NVARCHAR(10),
           @c_LUdef01       NVARCHAR(20)
   /*CS01 END*/

  DECLARE @n_OrderRoute         INT             --(CS04)
         , @n_ShowUOMQty         INT            --(CS04)
         , @n_Pallet             FLOAT          --(CS04)
         , @n_InnerPack          FLOAT          --(CS04)   
    
    DECLARE @n_qtyorder        INT,
            @n_qtyallocated    INT
    


    SET @n_ShowUOMQty = 0                        --(CS04)
    SET @n_Pallet     = 0.00                     --(CS04)
    SET @n_CaseCnt    = 0.00                     --(CS04)
    SET @n_InnerPack  = 0.00                     --(CS04)   
    
    CREATE TABLE #temp_pick
    (
       PickSlipNo       NVARCHAR(10),
       LoadKey          NVARCHAR(10),
       OrderKey         NVARCHAR(10),
       Externorderkey   NVARCHAR(50),  --tlting_ext
       ConsigneeKey     NVARCHAR(15),
       Company          NVARCHAR(45),
       Addr1            NVARCHAR(45),
       Addr2            NVARCHAR(45),
       Addr3            NVARCHAR(45),
       PostCode         NVARCHAR(15),
       ROUTE            NVARCHAR(10),
       Route_Desc       NVARCHAR(60),	-- RouteMaster.Desc
       TrfRoom          NVARCHAR(5),	-- LoadPlan.TrfRoom
       Notes1           NVARCHAR(60),
       Notes2           NVARCHAR(60),
       LOC              NVARCHAR(10),
       SKU              NVARCHAR(20),
       SkuDesc          NVARCHAR(60),
       Qty              INT,
       TempQty1         INT,
       TempQty2         INT,
       PrintedFlag      NVARCHAR(1),
       Zone             NVARCHAR(1),
       PgGroup          INT,
       RowNum           INT,
       Lot              NVARCHAR(10),
       Carrierkey       NVARCHAR(60),
       VehicleNo        NVARCHAR(10),
       --Lottable04       DATETIME,
       LabelPrice       NVARCHAR(5),
       storerkey        NVARCHAR(18),
       invoiceno        NVARCHAR(10),
       deliverydate     DATETIME,
       ordertype        NVARCHAR(250),
       qtyorder         INT NULL DEFAULT 0,
       qtyallocated     INT NULL DEFAULT 0,
       logicallocation  NVARCHAR(18),
       --packkey          NVARCHAR(10),	-- SOS25509
       ALTSKU           NVARCHAR(20),	-- (Vanessa01)
       uom              NVARCHAR(10),
       ID               NVARCHAR(18), --NJOW01
       Class            NVARCHAR(10),
       Busr6            NVARCHAR(30),
       Busr7            NVARCHAR(30),
       Style            NVARCHAR(20),
       Color            NVARCHAR(10),
       Size             NVARCHAR(5),
       Susr2            NVARCHAR(20) NULL, --NJOW02
       LRoute           NVARCHAR(10) ,   --(CS01)
       LEXTLoadKey      NVARCHAR(20),  --(CS01)
       LPriority        NVARCHAR(10),   --(CS01) 
       LUdef01          NVARCHAR(20),   --(CS01)
       ShowField        INT NULL DEFAULT 0,            --(CS03)            
       Lottable01       NVARCHAR(10) NULL,               --(CS03)
       Lottable02       NVARCHAR(10) NULL,	-- SOS15608  --(CS03)
       Lottable03       NVARCHAR(10) NULL,               --(CS03)
       Lottable04       NVARCHAR(12) NULL,	             --(CS03)
       Pallet           FLOAT,          --(CS04)
       CaseCnt          FLOAT,          --(CS04)
       InnerPack        FLOAT,          --(CS04)
       ShowUOMQty       INT             --(CS04)
    ) -- SOS25509
    
    SELECT @n_continue = 1,
           @n_starttcnt = @@TRANCOUNT  

   


   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
    
    SELECT @n_RowNo = 0
    SELECT @c_firstorderkey = 'N'
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
    IF EXISTS(
           SELECT 1
           FROM   PickHeader(NOLOCK)
           WHERE  ExternOrderKey = @c_LoadKey AND
                  Zone = '3'
       )
    BEGIN
        SELECT @c_firsttime = 'N'
        SELECT @c_PrintedFlag = 'Y'
    END
    ELSE
    BEGIN
        SELECT @c_firsttime = 'Y'
        SELECT @c_PrintedFlag = 'N'
    END -- Record Not Exists

    SET @n_ShowField   = 0
    SET @c_GetStorer = ''

          
      SELECT @c_GetStorer = MIN(storerkey) 
      FROM loadplandetail LP WITH (nolock)
      JOIN orders ORD WITH (NOLOCK) on LP.ORDERKEY=ORD.ORDERKEY
      WHERE LP.LOADKEY=@c_LoadKey

      SELECT  @n_ShowField = ISNULL(MAX(CASE WHEN Code = 'SHOWFIELD' AND short ='Y' THEN 1 ELSE 0 END),0)
             ,@n_ShowUOMQty = ISNULL(MAX(CASE WHEN CODE = 'SHOWUOMQTY' THEN 1 ELSE 0 END),0)  --(CS04)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'REPORTCFG'
      AND Storerkey = @c_GetStorer
      AND Long = 'r_dw_print_pickorder02a'
      --AND (Short IS NULL OR Short <> 'Y')
    
    BEGIN TRAN
 
    DECLARE pick_cur           CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT UPPER(PickDetail.sku),
               PickDetail.loc,
               SUM(PickDetail.qty),
               PACK.Qty,
               PickDetail.storerkey,
               PickDetail.OrderKey,
               PickDetail.UOM,
               LOC.LogicalLocation,
               Pickdetail.Lot,
               --PickDetail.Packkey,
               PickDetail.ID,    --NJOW01    
               ISNULL(Loadplan.Route,'') ,                       --(CS01)
               Loadplan.Externloadkey,                --(CS01) 
               Loadplan.Priority,                     --(CS01)  
               --Loadplan.Userdefine01                  --(CS01)  --(CS02)
               ISNULL(REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/'),'') --(CS02)
        FROM   PickDetail(NOLOCK),
               LoadPlanDetail  (NOLOCK),
               PACK            (NOLOCK),
               LOC             (NOLOCK),
               LoadPlan        (NOLOCK)               
        WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey AND
               -- SOS 5933 Pickslips can be displayed even confirmed picked
               LoadPlan.Loadkey = LoadPlanDetail.LoadKey  AND          --(CS01)
               --PickDetail.Status < '9' AND                           --(CS04)
               PickDetail.Packkey = PACK.Packkey AND
               LOC.Loc = PICKDETAIL.Loc AND
               LoadPlanDetail.LoadKey = @c_LoadKey
        GROUP BY
               UPPER(PickDetail.sku),
               PickDetail.loc,
               PACK.Qty,
               PickDetail.storerkey,
               PickDetail.OrderKey,
               PickDetail.UOM,
               LOC.LogicalLocation,
               Pickdetail.Lot,
               --PickDetail.Packkey, -- SOS25509
               PickDetail.ID, --NJOW01
               Loadplan.Route ,                       --(CS01)
               Loadplan.Externloadkey,                --(CS01) 
               Loadplan.Priority,                      --(CS01)
               --Loadplan.Userdefine01                  --(CS01) --(CS02)
               REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') --(CS02)
        ORDER BY
               PickDetail.ORDERKEY
    
    OPEN pick_cur
    SELECT @c_PrevOrderKey = ''
    FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
    @c_orderkey, @c_UOM, @c_logicalloc, @c_lot, @c_id,@c_LRoute,@c_LEXTLoadKey,@c_LPriority,@c_LUdef01  --(CS01) -- SOS25509
    
    WHILE (@@FETCH_STATUS<>-1)
    BEGIN
        IF @c_OrderKey<>@c_PrevOrderKey
        BEGIN
            IF NOT EXISTS(
                   SELECT 1
                   FROM   PICKHEADER(NOLOCK)
                   WHERE  EXTERNORDERKEY = @c_LoadKey AND
                          OrderKey = @c_OrderKey AND
                          Zone = '3'
               )
            BEGIN
                EXECUTE nspg_GetKey
                'PICKSLIP',
                9, 
                @c_pickheaderkey OUTPUT,
                @b_success OUTPUT,
                @n_err OUTPUT,
                @c_errmsg OUTPUT
                
                SELECT @c_pickheaderkey = 'P'+@c_pickheaderkey
                
                INSERT INTO PICKHEADER
                  (
                    PickHeaderKey,
                    OrderKey,
                    ExternOrderKey,
                    PickType,
                    Zone,
                    TrafficCop
                  )
                VALUES
                  (
                    @c_pickheaderkey,
                    @c_OrderKey,
                    @c_LoadKey,
                    '0',
                    '3',
                    ''
                  )
                
                SELECT @n_err = @@ERROR
                IF @n_err<>0
                BEGIN
                    SET @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73000   
                    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Pickheader Table. (nsp_GetPickSlipOrders26)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
 
                    GOTO QUIT_SP
                END
                ELSE
                BEGIN
                  WHILE @@TRANCOUNT > 0
                     COMMIT TRAN
                END 
                
                SELECT @c_firstorderkey = 'Y'
            END
            ELSE
            BEGIN
                SELECT TOP 1 
                       @c_pickheaderkey = PickHeaderKey
                FROM   PickHeader(NOLOCK)
                WHERE  ExternOrderKey = @c_LoadKey AND
                       Zone = '3' AND
                       OrderKey = @c_OrderKey
            END
        END
        
        IF @c_OrderKey=''
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
                   @c_InvoiceNo = '',
                   @c_susr2 = '' --NJOW02
        END
        ELSE
        BEGIN
            SELECT @c_Externorderkey = orders.Externorderkey,
                   @c_ConsigneeKey = Orders.ConsigneeKey,
                   @c_Company = ORDERS.c_Company,
                   @c_Addr1 = ORDERS.C_Address1,
                   @c_Addr2 = ORDERS.C_Address2,
                   @c_Addr3 = ORDERS.C_Address3,
                   @c_PostCode = ORDERS.C_Zip,
                   @c_Notes1 = CONVERT(NVARCHAR(60), ORDERS.Notes),
                   @c_Notes2 = CONVERT(NVARCHAR(60), ORDERS.Notes2),
                   @c_LabelPrice = ISNULL(ORDERS.LabelPrice, 'N'),
                   -- @c_invoiceno		= ORDERS.ExternOrderKey,  		-- SOS28698				     
                   @c_InvoiceNo = ORDERS.InvoiceNo,	-- SOS28698
                   @d_DeliveryDate = ORDERS.deliverydate,
                   @c_OrderType = CODELKUP.DESCRIPTION,
                   @c_susr2 = S2.Susr2 --NJOW02
            FROM   ORDERS (NOLOCK)
                   JOIN CODELKUP (NOLOCK) ON ORDERS.TYPE = CODELKUP.CODE
                   JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
                   LEFT JOIN STORER S2 (NOLOCK) ON ORDERS.Consigneekey = S2.Storerkey
            WHERE  ORDERS.OrderKey = @c_OrderKey AND
                   CODELKUP.LISTNAME = 'ORDERTYPE'
        END -- IF @c_OrderKey = ''
        
        
        SELECT @c_TrfRoom = ISNULL(LoadPlan.TrfRoom, ''),
               @c_Route = ISNULL(LoadPlan.Route, ''),
               @c_VehicleNo = ISNULL(LoadPlan.TruckSize, ''),
               @c_Carrierkey = ISNULL(LoadPlan.CarrierKey, '')
        FROM   LoadPlan(NOLOCK)
        WHERE  Loadkey = @c_LoadKey

        SELECT TOP 1 
               @c_Route_Desc = ISNULL(RouteMaster.Descr, '')
        FROM   RouteMaster(NOLOCK)
        WHERE  ROUTE = @c_Route
        
        
        /*CS03 Start*/
        SELECT @c_Lottable01 = Lottable01,
               @c_Lottable02 = Lottable02,	-- SOS15608
               @c_Lottable03 = Lottable03,	
               @c_Lottable04 = REPLACE(CONVERT(NVARCHAR(12),Lottable04,106),' ','/') 
               --@d_Lottable04 = Lottable04
        FROM   LOTATTRIBUTE(NOLOCK)
        WHERE  LOT = @c_LOT
        
        IF @c_Lottable01 IS NULL
            SELECT @c_Lottable01 = ''
        
        IF @c_Lottable02 IS NULL
            SELECT @c_Lottable02 = '' -- SOS15608

        IF @c_Lottable03 IS NULL
            SELECT @c_Lottable03 = ''

        IF @c_Lottable04 IS NULL
            SELECT @c_Lottable04 = ''

--        IF @d_Lottable04 IS NULL
--            SELECT @d_Lottable04 = '01/01/1900'

        /*CS03 End*/
        
        IF @c_Notes1 IS NULL
            SELECT @c_Notes1 = ''
        
        IF @c_Notes2 IS NULL
            SELECT @c_Notes2 = ''
        
        IF @c_Externorderkey IS NULL
            SELECT @c_Externorderkey = ''
        
        IF @c_ConsigneeKey IS NULL
            SELECT @c_ConsigneeKey = ''
        
        IF @c_InvoiceNo IS NULL
            SELECT @c_InvoiceNo = '' -- SOS28698
        IF @c_Company IS NULL
            SELECT @c_Company = ''
        
        IF @c_Addr1 IS NULL
            SELECT @c_Addr1 = ''
        
        IF @c_Addr2 IS NULL
            SELECT @c_Addr2 = ''
        
        IF @c_Addr3 IS NULL
            SELECT @c_Addr3 = ''
        
        IF @c_PostCode IS NULL
            SELECT @c_PostCode = ''
        
        IF @c_Route IS NULL
            SELECT @c_Route = ''
        
        IF @c_CarrierKey IS NULL
            SELECT @c_Carrierkey = ''
        
        IF @c_Route_Desc IS NULL
            SELECT @c_Route_Desc = ''
        
        IF @c_SuperOrderFlag='Y'
            SELECT @c_OrderKey = ''
        
        SELECT @n_RowNo = @n_RowNo+1
        SELECT @n_Pallets = 0,
               @n_Cartons = 0,
               @n_Eaches = 0
        
        SELECT @n_UOMQty = 0
        SELECT @n_UOMQty = CASE @c_UOM
                                WHEN '1' THEN PACK.Pallet
                                WHEN '2' THEN PACK.CaseCnt
                                WHEN '3' THEN PACK.InnerPack
                                ELSE 1
                           END,
               -- @c_UOM_master = PACK.PackUOM3  -- SOS25509
               @c_UOM_master = CASE @c_UOM
                                    WHEN '1' THEN PACK.PackUOM4
                                    WHEN '2' THEN PACK.PackUOM1
                                    WHEN '6' THEN PACKUOM3
                                    WHEN '7' THEN PACKUOM3
                                    ELSE ''
                               END,
               @c_SkuDesc = ISNULL(SKU.Descr, ''),
               @c_altsku  = CASE WHEN @n_ShowField = 0 THEN ISNULL(SKU.ALTSKU, '') ELSE '' END,   --(CS03)
               @c_class = ISNULL(SKU.Class,''), --NJOW01
               @c_busr6 = ISNULL(SKU.BUSR6,''),
               @c_busr7 = ISNULL(SKU.BUSR7,''),
               @c_style = ISNULL(SKU.Style,''),
               @c_color = ISNULL(SKU.Color,''),
               @c_size = ISNULL(SKU.Size,'') ,
               @n_Pallet = PACK.Pallet,                --(CS04)
               @n_CaseCnt= PACK.CaseCnt,              --(CS04)
               @n_InnerPack = PACK.InnerPack          --(CS04)                                               
        FROM   SKU WITH (NOLOCK)
               JOIN PACK WITH (NOLOCK)
                    ON  (PACK.PackKey=SKU.PackKey)
        WHERE  SKU.Storerkey = @c_storerkey AND
               SKU.SKU = @c_SKU

        --select '1',@c_LUdef01
        
        INSERT INTO #Temp_Pick
          (
            PickSlipNo,
            LoadKey,
            OrderKey,
            Externorderkey,
            ConsigneeKey,
            Company,
            Addr1,
            Addr2,
            PgGroup,
            Addr3,
            PostCode,
            ROUTE,
            Route_Desc,
            TrfRoom,
            Notes1,
            RowNum,
            Notes2,
            LOC,
            SKU,
            SkuDesc,
            Qty,
            TempQty1,
            TempQty2,
            PrintedFlag,
            Zone,
            Lot,
            CarrierKey,
            VehicleNo,
            Lottable01,              --(CS03) 
            Lottable02,	-- SOS15608  --(CS03)
            Lottable03,              --(CS03) 
            Lottable04,              --(CS03) 
            --Lottable04,
            LabelPrice,
            storerkey,
            invoiceno,
            deliverydate,
            ordertype,
            qtyorder,
            qtyallocated,
            logicallocation,
            --packkey,
            ALTSKU,      -- (Vanessa01)
            uom,
            id, --NJOW01
            class,
            Busr6, 
            Busr7, 
            Style, 
            Color, 
            SIZE,
            Susr2, --NJOW02                        
            LRoute,                           --(CS01)
            LEXTLoadKey,                      --(CS01)
            LPriority,                        --(CS01) 
            LUDef01,                          --(CS01) 
            ShowField,                        --(CS03)
            Pallet,                           --(CS04)
            CaseCnt,                          --(CS04)
            InnerPack,                        --(CS04)
            ShowUOMQty                        --(CS04)  
          )-- SOS25509
        VALUES
          (
            @c_pickheaderkey,
            @c_LoadKey,
            @c_OrderKey,
            @c_Externorderkey,
            @c_ConsigneeKey,
            @c_Company,
            @c_Addr1,
            @c_Addr2,
            0,
            @c_Addr3,
            @c_PostCode,
            @c_Route,
            @c_Route_Desc,
            @c_TrfRoom,
            @c_Notes1,
            @n_RowNo,
            @c_Notes2,
            @c_LOC,
            @c_SKU,
            @c_SKUDesc,
            @n_Qty,
            CAST(@c_UOM AS INT),
            @n_UOMQty,
            @c_PrintedFlag,
            '3',
            @c_Lot,
            @c_Carrierkey,
            @c_VehicleNo,
            @c_Lottable01,              --(CS03)
            @c_Lottable02,	-- SOS15608  --(CS03)
            @c_Lottable03,              --(CS03)
            @c_Lottable04,              --(CS03)  
            --@d_Lottable04,
            @c_labelprice,
            @c_storerkey,
            @c_invoiceno,
            @d_deliverydate,
            @c_ordertype,
            @n_qtyorder,
            @n_qtyallocated,
            @c_logicalloc,
            --@c_packkey,
            @c_altsku,     -- (Vanessa01)
            @c_UOM_master,
            @c_id,  --NJOW01
            @c_class,
            @c_busr6,
            @c_busr7,
            @c_style,
            @c_color,
            @c_size,
            @c_Susr2, --NJOW02            
            @c_LRoute,                        --(CS01)
            @c_LEXTLoadKey,                   --(CS01)
            @c_LPriority,                     --(CS01)  
            @c_LUDef01,                       --(CS01)
            @n_ShowField,                     --(CS03)
            @n_Pallet,                        --(CS04)
            @n_CaseCnt,                       --(CS04)
            @n_InnerPack,                     --(CS04)
            @n_ShowUOMQty                     --(CS04)
          )
        
        SELECT @c_PrevOrderKey = @c_OrderKey
        FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
        @c_orderkey, @c_UOM, @c_logicalloc, @c_lot, @c_id,@c_LRoute,@c_LEXTLoadKey,@c_LPriority,@c_LUDef01  --(CS01)
    END
    CLOSE pick_cur 
    DEALLOCATE pick_cur   
    
    DECLARE cur1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT DISTINCT OrderKey
        FROM   #temp_pick
        WHERE  ORDERKEY<>''
    
    OPEN cur1
    FETCH NEXT FROM cur1 INTO @c_orderkey
    
    WHILE (@@fetch_status<>-1)
    BEGIN
        SELECT @n_qtyorder = SUM(ORDERDETAIL.OpenQty),
               @n_qtyallocated = SUM(ORDERDETAIL.QtyAllocated)
        FROM   orderdetail(NOLOCK)
        WHERE  ORDERDetail.orderkey = @c_orderkey
        
        UPDATE #temp_pick
        SET    QtyOrder = @n_qtyorder,
               QtyAllocated = @n_qtyallocated
        WHERE  orderkey = @c_orderkey
        
        FETCH NEXT FROM cur1 INTO @c_orderkey
    END
    CLOSE cur1
    DEALLOCATE cur1   
    
    SELECT #temp_pick.*,
           pickheader.adddate,
           ORDERS.Door -- Added by YTWan on 1-July-2004 (SOS#:24796)
    FROM   #temp_pick,
           pickheader(NOLOCK),
           ORDERS(NOLOCK) -- Added by YTWan on 1-July-2004 (SOS#:24796)
    WHERE  #temp_pick.pickslipno = pickheader.pickheaderkey AND
           #temp_pick.OrderKey = ORDERS.OrderKey -- Added by YTWan on 1-July-2004 (SOS#:24796)
           
           
QUIT_SP:
    
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 

   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders02a'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END

END

GO