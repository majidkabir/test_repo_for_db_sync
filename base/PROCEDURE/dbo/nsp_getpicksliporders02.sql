SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders02                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Create Normal Pickslip for IDSTH                           */
/*                                                                      */
/* Input Parameters:  @c_LoadKey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder02                  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 01-Oct-2003  WJTan         PGD TH - add in new field lottable02      */
/*                            (SOS15608)                                */
/* 01-Jul-2004  YTWan         NSC - Order Import - Operation Route Code */
/*                            Updating (SOS24796)                       */
/* 26-Jul-2004  MaryVong      Add Packkey, UOM and modified sku format  */
/*                            (SOS25509)                                */
/* 27-Oct-2004 MaryVong      Add Invoice No to Normal PickSlip Header   */
/*                                    (SOS28698)                        */
/* 19-Nov-2009  Shong         Performance Tuning                        */
/* 04-Apr-2013  NJOW01        274740-Add pickzone                       */
/* 16-OCT-2013  YTWan         SOS#292385 -Print Slip Route from orders  */
/*                            (Wan01)                                   */
/* 29-MAY-2014  YTWan         SOS#311898 - TH-Request Add fields data   */
/*                            UOM QTY in report Pick Slip.(Wan02)       */
/* 29-Apr-2015  CSCHONG       SOS339808  (CS01)                         */
/* 09-Jul-2015  CSCHONG       SOS346307 (CS02)                          */
/* 04-Oct-2018  CSCHONG        WMS-6179 - add report config (CS03)      */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/* 30-Sep-2022  NJOW01         WMS-20895 remove loadkey criteria when   */
/*                             when search pickslip                     */
/************************************************************************/
CREATE PROC [dbo].[nsp_GetPickSlipOrders02] (@c_LoadKey NVARCHAR(10))
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
            @c_Route_Desc      NVARCHAR(60), -- RouteMaster.Desc
            @c_TrfRoom         NVARCHAR(5),  -- LoadPlan.TrfRoom
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
            @c_Lottable01      NVARCHAR(10),
            @c_Lottable02      NVARCHAR(10), -- SOS15608
            @d_Lottable04      DATETIME,
            @c_LabelPrice      NVARCHAR(5),
            @c_InvoiceNo       NVARCHAR(10),
            @c_uom_master      NVARCHAR(10),
            @d_DeliveryDate    DATETIME,
            @c_OrderType       NVARCHAR(250),
            @c_Packkey         NVARCHAR(10), -- SOS25509
            @c_Pickzone        NVARCHAR(10)
    
    DECLARE @c_PrevOrderKey    NVARCHAR(10),
            @n_Pallets         INT,
            @n_Cartons         INT,
            @n_Eaches          INT,
            @n_UOMQty          INT,
            @n_starttcnt       INT 
    
    DECLARE @n_qtyorder        INT,
            @n_qtyallocated    INT

   DECLARE @n_OrderRoute         INT            --(Wan01)
         , @n_ShowUOMQty         INT            --(Wan02)
         , @n_Pallet             FLOAT          --(Wan02)
         , @n_InnerPack          FLOAT          --(Wan02)   
		 , @c_showdisdate        INT            --(CS03)
		 , @c_OHUDF06            NVARCHAR(20)   --(CS03)

    /*CS01 Start*/
   DECLARE @c_LRoute        NVARCHAR(10),
           @c_LEXTLoadKey   NVARCHAR(20),
           @c_LPriority     NVARCHAR(10),
           @c_LUdef01       NVARCHAR(20)
		 
   /*CS01 END*/
     
   
   SET @n_OrderRoute = 0                        --(Wan01)
   SET @n_ShowUOMQty = 0                        --(Wan02)
   SET @n_Pallet     = 0.00                     --(Wan02)
   SET @n_CaseCnt    = 0.00                     --(Wan02)
   SET @n_InnerPack  = 0.00                     --(Wan02)   
    
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
       Route_Desc       NVARCHAR(60),  -- RouteMaster.Desc
       TrfRoom          NVARCHAR(5),   -- LoadPlan.TrfRoom
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
       Lottable01       NVARCHAR(10),
       Lottable02       NVARCHAR(10),  -- SOS15608
       Lottable04       DATETIME,
       LabelPrice       NVARCHAR(5),
       storerkey        NVARCHAR(18),
       invoiceno        NVARCHAR(10),
       deliverydate     DATETIME,
       ordertype        NVARCHAR(250),
       qtyorder         INT NULL DEFAULT 0,
       qtyallocated     INT NULL DEFAULT 0,
       logicallocation  NVARCHAR(18),
       packkey          NVARCHAR(10),  -- SOS25509
       uom              NVARCHAR(10),
       pickzone         NVARCHAR(10),
       Pallet           FLOAT          --(Wan02)
    ,  CaseCnt          FLOAT          --(Wan02)
    ,  InnerPack        FLOAT          --(Wan02)
    ,  ShowUOMQty       INT            --(Wan02)
    ,  LRoute           NVARCHAR(10) NULL  --(CS01)
    ,  LEXTLoadKey      NVARCHAR(20) NULL  --(CS01)
    ,  LPriority        NVARCHAR(10) NULL  --(CS01) 
    ,  LUdef01          NVARCHAR(20) NULL  --(CS01)

    ) -- SOS25509
    
    SELECT @n_continue = 1,
           @n_starttcnt = @@TRANCOUNT  


   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
    
    SELECT @n_RowNo = 0
    SELECT @c_firstorderkey = 'N'
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
    IF EXISTS(
           /*SELECT 1
           FROM   PickHeader(NOLOCK)
           WHERE  ExternOrderKey = @c_LoadKey AND
                  Zone = '3'*/
           SELECT 1   --NJOW01
           FROM PICKHEADER PH (NOLOCK)
           JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Orderkey = LPD.Orderkey
           WHERE LPD.Loadkey = @c_Loadkey
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
    
    BEGIN TRAN
 
    DECLARE pick_cur           CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT PickDetail.sku,
               PickDetail.loc,
               SUM(PickDetail.qty),
               PACK.Qty,
               PickDetail.storerkey,
               PickDetail.OrderKey,
               PickDetail.UOM,
               LOC.LogicalLocation,
               Pickdetail.Lot,
               PickDetail.Packkey,
               CASE WHEN ISNULL(STORERCONFIG.Svalue,'0') = '1' THEN '' ELSE LOC.Pickzone END AS Pickzone,
               Loadplan.Route ,                       --(CS01)
               Loadplan.Externloadkey,                --(CS01) 
               Loadplan.Priority,                     --(CS01)
               --Loadplan.Userdefine01                  --(CS01) --(CS02)
               REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') --(CS02)
        FROM   PickDetail(NOLOCK)
               JOIN LoadPlanDetail  (NOLOCK) ON PickDetail.OrderKey = LoadPlanDetail.OrderKey 
               JOIN LoadPlan   (NOLOCK) ON LoadPlan.Loadkey = LoadPlanDetail.Loadkey       --(CS01)
               JOIN PACK (NOLOCK) ON  PickDetail.Packkey = PACK.Packkey
               JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
               LEFT JOIN STORERCONFIG (NOLOCK) ON PickDetail.Storerkey = STORERCONFIG.Storerkey AND STORERCONFIG.Configkey = 'PICKORD02_HIDEZONE'
        WHERE  PickDetail.Status < '9' AND 
               LoadPlanDetail.LoadKey = @c_LoadKey               
        GROUP BY
               PickDetail.sku,
               PickDetail.loc,
               PACK.Qty,
               PickDetail.storerkey,
               PickDetail.OrderKey,
               PickDetail.UOM,
               LOC.LogicalLocation,
               Pickdetail.Lot,
               PickDetail.Packkey, -- SOS25509
               CASE WHEN ISNULL(STORERCONFIG.Svalue,'0') = '1' THEN '' ELSE LOC.Pickzone END,
               Loadplan.Route ,                       --(CS01)
               Loadplan.Externloadkey,                --(CS01) 
               Loadplan.Priority,                     --(CS01) 
               --Loadplan.Userdefine01                  --(CS01)  --(CS02)
               REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') --(CS02)
        ORDER BY
               PickDetail.ORDERKEY
    
    OPEN pick_cur
    SELECT @c_PrevOrderKey = ''
    FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
    @c_orderkey, @c_UOM, @c_logicalloc, @c_lot, @c_packkey, @c_pickzone,@c_LRoute,@c_LEXTLoadKey,@c_LPriority,@c_LUDef01  --(CS01)
    
    WHILE (@@FETCH_STATUS<>-1)
    BEGIN
        IF @c_OrderKey<>@c_PrevOrderKey
        BEGIN
            IF NOT EXISTS(
                   SELECT 1
                   FROM   PICKHEADER(NOLOCK)
                   WHERE  OrderKey = @c_OrderKey AND
                          Zone = '3' 
                          --EXTERNORDERKEY = @c_LoadKey  --NJOW01 removed
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
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73000   
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Pickheader Table. (nsp_GetPickSlipOrders26)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
 
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
                WHERE  Zone = '3' AND
                       OrderKey = @c_OrderKey
                       --ExternOrderKey = @c_LoadKey AND  --NJOW01 Removed
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
                   @c_InvoiceNo = ''
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
                   -- @c_invoiceno     = ORDERS.ExternOrderKey,      -- SOS28698               
                   @c_InvoiceNo = ORDERS.InvoiceNo,   -- SOS28698
                   @d_DeliveryDate = ORDERS.deliverydate,
                   @c_OrderType = CODELKUP.DESCRIPTION
            FROM   ORDERS(NOLOCK),
                   CODELKUP(NOLOCK)
            WHERE  ORDERS.OrderKey = @c_OrderKey AND
                   ORDERS.TYPE = CODELKUP.CODE AND
                   LISTNAME = 'ORDERTYPE'
        END -- IF @c_OrderKey = ''
        
        
        SELECT @c_TrfRoom = ISNULL(LoadPlan.TrfRoom, ''),
               @c_Route = ISNULL(LoadPlan.Route, ''),
               @c_VehicleNo = ISNULL(LoadPlan.TruckSize, ''),
               @c_Carrierkey = ISNULL(LoadPlan.CarrierKey, '')
        FROM   LoadPlan(NOLOCK)
        WHERE  Loadkey = @c_LoadKey
        
         --(Wan01) - START
         SELECT @n_OrderRoute = ISNULL(MAX(CASE WHEN CODE = 'ORDERROUTE' THEN 1 ELSE 0 END),0)  
               ,@n_ShowUOMQty = ISNULL(MAX(CASE WHEN CODE = 'SHOWUOMQTY' THEN 1 ELSE 0 END),0)  --(Wan02) 
			   ,@c_showdisdate = ISNULL(MAX(CASE WHEN CODE = 'SHOWDISPATCHDATE' THEN 1 ELSE 0 END),0)--(CS03)
         FROM CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'REPORTCFG'
         AND   Storerkey = @c_Storerkey
         AND   Long = 'r_dw_print_pickorder02'
         AND   ISNULL(RTRIM(Short),'') <> 'N'
         
         IF  @n_OrderRoute = 1
         BEGIN
            SELECT @c_Route = ISNULL(RTRIM(Route), '')
            FROM ORDERS WITH (NOLOCK)
            WHERE Orderkey = @c_Orderkey
         END   
         --(Wan01) - END

		 --CS03 Start
		 SET @c_OHUDF06 = ''
		 if @c_showdisdate = 1
		 BEGIN
		    SELECT @c_OHUDF06 =  REPLACE(CONVERT(NVARCHAR(12),ORDERS.userdefine06,106),' ','/')
            FROM ORDERS WITH (NOLOCK)
            WHERE Orderkey = @c_Orderkey

		 END
		 --CS03 End
        SELECT TOP 1 
               @c_Route_Desc = ISNULL(RouteMaster.Descr, '')
        FROM   RouteMaster(NOLOCK)
        WHERE  ROUTE = @c_Route
        
        
        
        SELECT @c_Lottable01 = Lottable01,
               @c_Lottable02 = Lottable02,   -- SOS15608
               @d_Lottable04 = Lottable04
        FROM   LOTATTRIBUTE(NOLOCK)
        WHERE  LOT = @c_LOT
        
        IF @c_Lottable01 IS NULL
            SELECT @c_Lottable01 = ''
        
        IF @c_Lottable02 IS NULL
            SELECT @c_Lottable02 = '' -- SOS15608
        IF @d_Lottable04 IS NULL
            SELECT @d_Lottable04 = '01/01/1900'
        
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
               @c_SkuDesc = ISNULL(SKU.Descr, '')
            ,  @n_Pallet = PACK.Pallet                --(Wan02)
            ,  @n_CaseCnt= PACK.CaseCnt               --(Wan02)
            ,  @n_InnerPack = PACK.InnerPack          --(Wan02)
        FROM   SKU WITH (NOLOCK)
               JOIN PACK WITH (NOLOCK)
                    ON  (PACK.PackKey=SKU.PackKey)
        WHERE  SKU.Storerkey = @c_storerkey AND
               SKU.SKU = @c_SKU
        
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
            Lottable01,
            Lottable02, -- SOS15608
            Lottable04,
            LabelPrice,
            storerkey,
            invoiceno,
            deliverydate,
            ordertype,
            qtyorder,
            qtyallocated,
            logicallocation,
            packkey,
            uom,
            pickzone
          , Pallet                           --(Wan02)
          , CaseCnt                          --(Wan02)
          , InnerPack                        --(Wan02)
          , ShowUOMQty                       --(Wan02)
          , LRoute                           --(CS01)
          , LEXTLoadKey                      --(CS01)
          , LPriority                        --(CS01) 
          , LUDef01                          --(CS01) 
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
            @c_Lottable01,
            @c_Lottable02, -- SOS15608
            @d_Lottable04,
            @c_labelprice,
            @c_storerkey,
            @c_invoiceno,
            @d_deliverydate,
            @c_ordertype,
            @n_qtyorder,
            @n_qtyallocated,
            @c_logicalloc,
            @c_packkey,
            @c_UOM_master,
            @c_Pickzone
          , @n_Pallet                        --(Wan02)
          , @n_CaseCnt                       --(Wan02)
          , @n_InnerPack                     --(Wan02)
          , @n_ShowUOMQty                    --(Wan02)
          , @c_LRoute                        --(CS01)
          , @c_LEXTLoadKey                   --(CS01)
          , @c_LPriority                     --(CS01) 
          , CASE WHEN @c_showdisdate=1 THEN @c_OHUDF06 ELSE @c_LUDef01  END  --(CS01)  --(CS03)
          )
        
        SELECT @c_PrevOrderKey = @c_OrderKey
        FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
        @c_orderkey, @c_UOM, @c_logicalloc, @c_lot, @c_packkey, @c_Pickzone,@c_LRoute,@c_LEXTLoadKey,@c_LPriority,@c_LUDef01   --(CS01)
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

    SELECT --#temp_pick.*,
            #temp_pick.PickSlipNo        
          , #temp_pick.LoadKey           
          , #temp_pick.OrderKey          
          , #temp_pick.Externorderkey    
          , #temp_pick.ConsigneeKey      
          , #temp_pick.Company           
          , #temp_pick.Addr1             
          , #temp_pick.Addr2             
          , #temp_pick.Addr3             
          , #temp_pick.PostCode          
          , #temp_pick.ROUTE             
          , #temp_pick.Route_Desc        
          , #temp_pick.TrfRoom           
          , #temp_pick.Notes1            
          , #temp_pick.Notes2            
          , #temp_pick.LOC               
          , #temp_pick.SKU               
          , #temp_pick.SkuDesc           
          , #temp_pick.Qty               
          , #temp_pick.TempQty1          
          , #temp_pick.TempQty2          
          , #temp_pick.PrintedFlag       
          , #temp_pick.Zone              
          , #temp_pick.PgGroup           
          , #temp_pick.RowNum            
          , #temp_pick.Lot               
          , #temp_pick.Carrierkey        
          , #temp_pick.VehicleNo         
          , #temp_pick.Lottable01        
          , #temp_pick.Lottable02        
          , #temp_pick.Lottable04        
          , #temp_pick.LabelPrice        
          , #temp_pick.storerkey         
          , #temp_pick.invoiceno         
          , #temp_pick.deliverydate      
          , #temp_pick.ordertype         
          , #temp_pick.qtyorder          
          , #temp_pick.qtyallocated      
          , #temp_pick.logicallocation   
          , #temp_pick.packkey           
          , #temp_pick.uom               
          , #temp_pick.pickzone,
           pickheader.adddate,
           ORDERS.Door -- Added by YTWan on 1-July-2004 (SOS#:24796)
          , #temp_pick.Pallet       --(Wan02)
          , #temp_pick.CaseCnt      --(Wan02)
          , #temp_pick.Innerpack    --(Wan02)
          , #temp_pick.ShowUOMQty   --(Wan02)
          , #Temp_Pick.LRoute       --(CS01)
          , #Temp_Pick.LEXTLoadKey  --(CS01)
          , #Temp_Pick.LPriority    --(CS01)
          , #Temp_Pick.LUdef01      --(CS01)
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders02'  
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