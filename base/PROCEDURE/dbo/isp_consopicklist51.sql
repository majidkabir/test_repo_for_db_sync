SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_ConsoPickList51                                */
/* Creation Date:05-SEP-2022                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:  WMS-20537 Request new cluster pick slip report             */
/*                                                                      */
/* Input Parameters:  @c_LoadKey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_consolidated_pick51_1              */
/*                                                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Version Purposes                              */
/* 05-SEP-2022  CHONGCS   1.0     Devops Scripts Combine                */
/* 07-Nov-2022  CHONGCS   1.1     Fix sorting issue (CS01)              */
/* 19-Jan-2023  WLChooi   1.2     WMS-21589 - Change sorting (WL01)     */
/************************************************************************/
CREATE   PROC [dbo].[isp_ConsoPickList51]
(
   @c_LoadKey    NVARCHAR(10)
 , @c_Reporttype NVARCHAR(1) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_pickheaderkey  NVARCHAR(10)
         , @n_continue       INT
         , @c_errmsg         NVARCHAR(255)
         , @b_success        INT
         , @n_err            INT
         , @c_sku            NVARCHAR(20)
         , @n_qty            INT
         , @c_loc            NVARCHAR(10)
         , @n_cases          INT
         , @n_perpallet      INT
         , @c_storer         NVARCHAR(15)
         , @c_orderkey       NVARCHAR(10)
         , @c_Externorderkey NVARCHAR(50)
         , @c_LPExtorderkey  NVARCHAR(50)
         , @c_Route          NVARCHAR(10)
         , @c_Route_Desc     NVARCHAR(60) -- RouteMaster.Desc
         , @c_TrfRoom        NVARCHAR(5) -- LoadPlan.TrfRoom
         , @c_Notes1         NVARCHAR(4000)
         , @c_Notes2         NVARCHAR(4000)
         , @c_SkuDesc        NVARCHAR(60)
         , @n_CaseCnt        INT
         , @n_PalletCnt      INT
         , @c_ReceiptTm      NVARCHAR(20)
         , @c_PrintedFlag    NVARCHAR(1)
         , @c_UOM            NVARCHAR(10)
         , @n_UOM3           INT
         , @c_Lot            NVARCHAR(10)
         , @c_StorerKey      NVARCHAR(15)
         , @c_Zone           NVARCHAR(1)
         , @n_PgGroup        INT
         , @n_TotCases       INT
         , @n_RowNo          INT
         , @c_PrevSKU        NVARCHAR(20)
         , @n_SKUCount       INT
         , @c_Carrierkey     NVARCHAR(60)
         , @c_VehicleNo      NVARCHAR(10)
         , @c_firstorderkey  NVARCHAR(10)
         , @c_superorderflag NVARCHAR(1)
         , @c_firsttime      NVARCHAR(1)
         , @c_logicalloc     NVARCHAR(18)
         , @c_Lottable01     NVARCHAR(10)
         , @c_Lottable02     NVARCHAR(10)
         , @d_Lottable04     DATETIME
         , @c_Lottable06     NVARCHAR(30)
         , @c_LabelPrice     NVARCHAR(5)
         , @c_InvoiceNo      NVARCHAR(10)
         , @c_uom_master     NVARCHAR(10)
         , @d_DeliveryDate   DATETIME
         , @c_OrderType      NVARCHAR(250)
         , @c_Packkey        NVARCHAR(10)
         , @c_Pickzone       NVARCHAR(10)
         , @c_retailsku      NVARCHAR(20)

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT
         , @n_starttcnt    INT

   DECLARE @n_qtyorder     INT
         , @n_qtyallocated INT

   DECLARE @n_OrderRoute  INT
         , @n_ShowUOMQty  INT
         , @n_Pallet      FLOAT
         , @n_InnerPack   FLOAT
         , @c_showdisdate INT
         , @c_OHUDF06     NVARCHAR(20)


   DECLARE @c_LRoute       NVARCHAR(10)
         , @c_LEXTLoadKey  NVARCHAR(20)
         , @c_LPriority    NVARCHAR(10)
         , @c_LUdef01      NVARCHAR(20)
         , @c_LPCarrierkey NVARCHAR(20)

   SET @n_OrderRoute = 0
   SET @n_ShowUOMQty = 0
   SET @n_Pallet = 0.00
   SET @n_CaseCnt = 0.00
   SET @n_InnerPack = 0.00

   CREATE TABLE #temp_cosopick51
   (
      rowno          INT           IDENTITY(1, 1) NOT NULL --CS01 
    , PickSlipNo     NVARCHAR(10)
    , LoadKey        NVARCHAR(10)
    , OrderKey       NVARCHAR(10)
    , Externorderkey NVARCHAR(50)
    , ROUTE          NVARCHAR(10)  NULL --WL01 
    , Notes1         NVARCHAR(4000)
    , Notes2         NVARCHAR(4000)
    , LOC            NVARCHAR(10)
    , SKU            NVARCHAR(20)
    , SkuDesc        NVARCHAR(60)
    , Qty            INT
    , TempQty1       INT
    , TempQty2       INT
    , PrintedFlag    NVARCHAR(1)
    , Zone           NVARCHAR(1)
    , PgGroup        INT
    , RowNum         INT
    , Lottable01     NVARCHAR(18)  NULL --WL01
    , Lottable02     NVARCHAR(18)  NULL --WL01
    , Lottable04     DATETIME      NULL --WL01
    , storerkey      NVARCHAR(18)
    , packkey        NVARCHAR(10)
    , uom            NVARCHAR(10)
    , pickzone       NVARCHAR(10)
    , Pallet         FLOAT
    , CaseCnt        FLOAT
    , InnerPack      FLOAT
    , Lottable06     NVARCHAR(30)  NULL
    , RetailSKU      NVARCHAR(20)  NULL
    , LPCarrierkey   NVARCHAR(20)  NULL
    , Logicalloc     NVARCHAR(18)  NULL --CS01 
   )

   SELECT @n_continue = 1
        , @n_starttcnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = N'N'
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE ExternOrderKey = @c_LoadKey AND Zone = '3')
   BEGIN
      SELECT @c_firsttime = N'N'
      SELECT @c_PrintedFlag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = N'Y'
      SELECT @c_PrintedFlag = N'N'
   END -- Record Not Exists

   BEGIN TRAN

   DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.Sku
        , PICKDETAIL.Loc
        , SUM(PICKDETAIL.Qty)
        , PACK.Qty
        , PICKDETAIL.Storerkey
        , PICKDETAIL.OrderKey
        , PICKDETAIL.UOM
        , PICKDETAIL.Lot
        , PICKDETAIL.PackKey
        , LOC.PickZone AS Pickzone
        , LoadPlan.Route
        , S.RETAILSKU
        , LoadPlanDetail.ExternOrderKey
        , ISNULL(LoadPlan.CarrierKey, '')
        , LOC.LogicalLocation --CS01
   FROM PICKDETAIL (NOLOCK)
   JOIN LoadPlanDetail (NOLOCK) ON PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey
   JOIN LoadPlan (NOLOCK) ON LoadPlan.LoadKey = LoadPlanDetail.LoadKey
   JOIN PACK (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
   JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PICKDETAIL.Storerkey AND S.Sku = PICKDETAIL.Sku
   WHERE PICKDETAIL.Status < '9' AND LoadPlanDetail.LoadKey = @c_LoadKey
   GROUP BY PICKDETAIL.Sku
          , PICKDETAIL.Loc
          , PACK.Qty
          , PICKDETAIL.Storerkey
          , PICKDETAIL.OrderKey
          , PICKDETAIL.UOM
          , PICKDETAIL.Lot
          , PICKDETAIL.PackKey
          , LOC.PickZone
          , LoadPlan.Route
          , S.RETAILSKU
          , LoadPlanDetail.ExternOrderKey
          , LoadPlan.CarrierKey
          , LogicalLocation --CS01
   ORDER BY LOC.PickZone   --WL01 S
          , LOC.LogicalLocation
          , PICKDETAIL.Loc
          , PICKDETAIL.Sku
          , PICKDETAIL.OrderKey
          , PICKDETAIL.Lot
          --, PICKDETAIL.OrderKey --CS01   --WL01 E

   OPEN pick_cur
   SELECT @c_PrevOrderKey = N''
   FETCH NEXT FROM pick_cur
   INTO @c_sku
      , @c_loc
      , @n_qty
      , @n_UOM3
      , @c_StorerKey
      , @c_orderkey
      , @c_UOM
      , @c_Lot
      , @c_Packkey
      , @c_Pickzone
      , @c_LRoute
      , @c_retailsku
      , @c_LPExtorderkey
      , @c_LPCarrierkey
      , @c_logicalloc


   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF NOT EXISTS (  SELECT 1
                       FROM PICKHEADER (NOLOCK)
                       WHERE ExternOrderKey = @c_LoadKey
      -- AND    Zone = '7'
      )
      BEGIN
         EXECUTE nspg_GetKey 'PICKSLIP'
                           , 9
                           , @c_pickheaderkey OUTPUT
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         SELECT @c_pickheaderkey = N'P' + @c_pickheaderkey

         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         VALUES (@c_pickheaderkey, '', @c_LoadKey, '0', '7', '')

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 73000
            SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + N': Update Failed On Table Pickheader Table. (isp_ConsoPickList51)' + N' ( '
                               + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '

            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            COMMIT TRAN
         END

         SELECT @c_firstorderkey = N'Y'
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_pickheaderkey = PickHeaderKey
         FROM PICKHEADER (NOLOCK)
         WHERE ExternOrderKey = @c_LoadKey
      --AND    Zone = 'LP' 
      END

      SELECT @c_Externorderkey = ORDERS.ExternOrderKey
           , @c_Notes1 = ISNULL(ORDERS.Notes, '')
           , @c_Notes2 = ISNULL(ORDERS.Notes2, '')
      FROM ORDERS (NOLOCK)
      WHERE ORDERS.OrderKey = @c_orderkey

      SELECT @c_Lottable01 = Lottable01
           , @c_Lottable02 = Lottable02
           , @d_Lottable04 = Lottable04
           , @c_Lottable06 = Lottable06
      FROM LOTATTRIBUTE (NOLOCK)
      WHERE Lot = @c_Lot

      IF @c_Lottable01 IS NULL
         SELECT @c_Lottable01 = N''

      IF @c_Lottable02 IS NULL
         SELECT @c_Lottable02 = N''
      IF @d_Lottable04 IS NULL
         SELECT @d_Lottable04 = '01/01/1900'

      IF @c_Lottable06 IS NULL
         SELECT @c_Lottable06 = N''

      IF @c_Notes1 IS NULL
         SELECT @c_Notes1 = N''

      IF @c_Notes2 IS NULL
         SELECT @c_Notes2 = N''

      IF @c_LPExtorderkey IS NULL
         SELECT @c_LPExtorderkey = N''

      IF @c_Route IS NULL
         SELECT @c_Route = N''

      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0
           , @n_Cartons = 0
           , @n_Eaches = 0

      SELECT @n_UOMQty = 0
      SELECT @n_UOMQty = CASE @c_UOM
                              WHEN '1' THEN PACK.Pallet
                              WHEN '2' THEN PACK.CaseCnt
                              WHEN '3' THEN PACK.InnerPack
                              ELSE 1 END
           , @c_uom_master = CASE @c_UOM
                                  WHEN '1' THEN PACK.PackUOM4
                                  WHEN '2' THEN PACK.PackUOM1
                                  WHEN '6' THEN PackUOM3
                                  WHEN '7' THEN PackUOM3
                                  ELSE '' END
           , @c_SkuDesc = ISNULL(SKU.DESCR, '')
           , @n_Pallet = PACK.Pallet
           , @n_CaseCnt = PACK.CaseCnt
           , @n_InnerPack = PACK.InnerPack
      FROM SKU WITH (NOLOCK)
      JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)
      WHERE SKU.StorerKey = @c_StorerKey AND SKU.Sku = @c_sku

      INSERT INTO #temp_cosopick51 (PickSlipNo, LoadKey, OrderKey, Externorderkey, PgGroup, ROUTE, Notes1, RowNum
                                  , Notes2, LOC, SKU, SkuDesc, Qty, TempQty1, TempQty2, PrintedFlag, Zone, Lottable01
                                  , Lottable02, Lottable04, storerkey, packkey, uom, pickzone, Pallet, CaseCnt
                                  , InnerPack, Lottable06, RetailSKU, LPCarrierkey
                                  , Logicalloc   --CS01   --WL01
      )
      VALUES (@c_pickheaderkey, @c_LoadKey, @c_orderkey, @c_LPExtorderkey, 0, @c_LRoute, @c_Notes1, @n_RowNo, @c_Notes2
            , @c_loc, @c_sku, @c_SkuDesc, @n_qty, CAST(@c_UOM AS INT), @n_UOMQty, @c_PrintedFlag, '7', @c_Lottable01
            , @c_Lottable02, @d_Lottable04, @c_StorerKey, @c_Packkey, @c_uom_master, @c_Pickzone, @n_Pallet, @n_CaseCnt
            , @n_InnerPack, @c_Lottable06, @c_retailsku, @c_LPCarrierkey
            , @c_logicalloc   --CS01   --WL01
         )

      -- SELECT @c_PrevOrderKey = @c_OrderKey
      FETCH NEXT FROM pick_cur
      INTO @c_sku
         , @c_loc
         , @n_qty
         , @n_UOM3
         , @c_StorerKey
         , @c_orderkey
         , @c_UOM
         , @c_Lot
         , @c_Packkey
         , @c_Pickzone
         , @c_LRoute
         , @c_retailsku
         , @c_LPExtorderkey
         , @c_LPCarrierkey
         , @c_logicalloc --CS01
   END
   CLOSE pick_cur
   DEALLOCATE pick_cur

   --DECLARE cur1 CURSOR LOCAL FAST_FORWARD READ_ONLY
   --FOR
   --    SELECT DISTINCT OrderKey
   --    FROM   #temp_cosopick51
   --    WHERE  ORDERKEY<>''

   --OPEN cur1
   --FETCH NEXT FROM cur1 INTO @c_orderkey

   --WHILE (@@fetch_status<>-1)
   --BEGIN
   --    SELECT @n_qtyorder = SUM(ORDERDETAIL.OpenQty),
   --           @n_qtyallocated = SUM(ORDERDETAIL.QtyAllocated)
   --    FROM   orderdetail(NOLOCK)
   --    WHERE  ORDERDetail.orderkey = @c_orderkey

   --    UPDATE #temp_cosopick51
   --    SET    QtyOrder = @n_qtyorder,
   --           QtyAllocated = @n_qtyallocated
   --    WHERE  orderkey = @c_orderkey

   --    FETCH NEXT FROM cur1 INTO @c_orderkey
   --END
   --CLOSE cur1
   --DEALLOCATE cur1

   IF @c_Reporttype = 'H'
   BEGIN
      SELECT --#temp_pick.*,
         #temp_cosopick51.PickSlipNo
       , #temp_cosopick51.LoadKey
       , #temp_cosopick51.OrderKey
       , #temp_cosopick51.Externorderkey
       , #temp_cosopick51.ROUTE
       , #temp_cosopick51.LOC
       , #temp_cosopick51.SKU
       , #temp_cosopick51.SkuDesc
       , #temp_cosopick51.Qty
       , #temp_cosopick51.TempQty1
       , #temp_cosopick51.TempQty2
       , #temp_cosopick51.PrintedFlag
       , #temp_cosopick51.Zone
       , #temp_cosopick51.PgGroup
       , #temp_cosopick51.RowNum
       , #temp_cosopick51.Lottable01
       , #temp_cosopick51.Lottable02
       , #temp_cosopick51.Lottable04
       , #temp_cosopick51.storerkey
       , #temp_cosopick51.packkey
       , #temp_cosopick51.uom
       , #temp_cosopick51.pickzone
       , #temp_cosopick51.Pallet
       , #temp_cosopick51.CaseCnt
       , #temp_cosopick51.InnerPack
       , #temp_cosopick51.Lottable06
       , #temp_cosopick51.RetailSKU
       , #temp_cosopick51.LPCarrierkey
      FROM #temp_cosopick51
      WHERE #temp_cosopick51.LoadKey = @c_LoadKey
      ORDER BY #temp_cosopick51.rowno        --WL01 S
             , #temp_cosopick51.Lottable01
             , #temp_cosopick51.Lottable02
             , #temp_cosopick51.Lottable04
             , #temp_cosopick51.Lottable06   --WL01 E
   END
   ELSE
   BEGIN
      SELECT DISTINCT --#temp_pick.*,
             #temp_cosopick51.PickSlipNo
           , #temp_cosopick51.OrderKey
           , #temp_cosopick51.LoadKey
           , #temp_cosopick51.Externorderkey
           , #temp_cosopick51.ROUTE
           , #temp_cosopick51.Notes1
           , #temp_cosopick51.Notes2
      FROM #temp_cosopick51
      WHERE #temp_cosopick51.LoadKey = @c_LoadKey
      ORDER BY #temp_cosopick51.PickSlipNo
             , #temp_cosopick51.LoadKey
             , #temp_cosopick51.OrderKey
   END

   QUIT_SP:

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN TRAN

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ConsoPickList51'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END

END

GO