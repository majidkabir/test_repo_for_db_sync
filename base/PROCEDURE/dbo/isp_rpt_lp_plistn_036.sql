SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc:isp_RPT_LP_PLISTN_036                                    */
/* Creation Date: 06-FEB-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-21957 - Customize - New Picking Slip - Display only Zone*/
/*                                                                      */
/* Called By: RPT_LP_PLISTN_036                                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver   Purposes                                   */
/* 04-Apr-2023 WZPang  1.0   DevOps Combine Script                      */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PLISTN_036]
(
   @c_Loadkey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey   NVARCHAR(10)
         , @n_continue        INT
         , @c_errmsg          NVARCHAR(255)
         , @b_success         INT
         , @n_err             INT
         , @c_sku             NVARCHAR(20)
         , @n_qty             INT
         , @c_loc             NVARCHAR(10)
         , @n_cases           INT
         , @n_perpallet       INT
         , @c_storer          NVARCHAR(15)
         , @c_orderkey        NVARCHAR(10)
         , @c_Externorderkey  NVARCHAR(50)
         , @c_ConsigneeKey    NVARCHAR(15)
         , @c_Company         NVARCHAR(45)
         , @c_Addr1           NVARCHAR(45)
         , @c_Addr2           NVARCHAR(45)
         , @c_Addr3           NVARCHAR(45)
         , @c_PostCode        NVARCHAR(15)
         , @c_Route           NVARCHAR(10)
         , @c_Route_Desc      NVARCHAR(60)
         , @c_TrfRoom         NVARCHAR(5)
         , @c_Notes1          NVARCHAR(60)
         , @c_Notes2          NVARCHAR(60)
         , @c_SkuDesc         NVARCHAR(60)
         , @n_CaseCnt         INT
         , @n_PalletCnt       INT
         , @c_ReceiptTm       NVARCHAR(20)
         , @c_PrintedFlag     NVARCHAR(1)
         , @c_UOM             NVARCHAR(10)
         , @n_UOM3            INT
         , @c_Lot             NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)
         , @c_Zone            NVARCHAR(1)
         , @n_PgGroup         INT
         , @n_TotCases        INT
         , @n_RowNo           INT
         , @c_PrevSKU         NVARCHAR(20)
         , @n_SKUCount        INT
         , @c_Carrierkey      NVARCHAR(60)
         , @c_VehicleNo       NVARCHAR(10)
         , @c_firstorderkey   NVARCHAR(10)
         , @c_superorderflag  NVARCHAR(1)
         , @c_firsttime       NVARCHAR(1)
         , @c_logicalloc      NVARCHAR(18)
         , @c_Lottable01      NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @d_Lottable04      DATETIME
         , @c_labelPrice      NVARCHAR(5)
         , @c_invoiceno       NVARCHAR(10)
         , @c_uom_master      NVARCHAR(10)
         , @d_deliverydate    DATETIME
         , @c_ordertype       NVARCHAR(250)
         , @n_loccnt          INT
         , @c_ID              NVARCHAR(18) = NULL
         , @c_PAZone          NVARCHAR(10) = NULL
         , @c_RetailSKU       NVARCHAR(20) = NULL
         , @n_CurrentPG       INT          = 1
         , @c_LastPutawayzone NVARCHAR(10) = N''
         , @c_LastLoadkey     NVARCHAR(10) = N''
         , @c_LastOrderkey    NVARCHAR(10) = N''

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT
         , @n_inner        INT

   DECLARE @n_qtyorder             INT
         , @n_qtyallocated         INT
         , @c_skuindicator         NVARCHAR(1)
         , @c_ShowSusr5            NVARCHAR(5)
         , @c_susr5                NVARCHAR(18)
         , @c_ShowFullLoc          NVARCHAR(5)
         , @c_showordtype          NVARCHAR(5)
         , @c_showcitystate        NVARCHAR(5)
         , @c_OHTypeDesc           NVARCHAR(50)
         , @c_NewPostCode          NVARCHAR(120)
         , @c_ShowPickdetailID     NVARCHAR(5)
         , @c_BreakByPAZone        NVARCHAR(5)
         , @c_ShowRetailSKU        NVARCHAR(5)
         , @c_SQL                  NVARCHAR(4000)
         , @c_OrderBy              NVARCHAR(4000)
         , @n_MaxLine              INT           = 10
         , @c_GetPutawayzone       NVARCHAR(10)
         , @c_GetLoadkey           NVARCHAR(10)
         , @c_GetOrderkey          NVARCHAR(10)
         , @n_GetTotalPage         INT           = 0
         , @n_CurrentCnt           INT           = 1
         , @c_ShowPageNoByOrderkey NVARCHAR(10)
         , @b_flag                 INT           = 0
         , @c_ShowEachInInnerCol   NVARCHAR(10)
         , @n_GetQty               INT
         , @c_GetSKU               NVARCHAR(10)


   DECLARE @c_LRoute      NVARCHAR(10)
         , @c_LEXTLoadKey NVARCHAR(20)
         , @c_LPriority   NVARCHAR(10)
         , @c_LUDef01     NVARCHAR(20)

   IF @c_PreGenRptData IN ( '0' )
      SET @c_PreGenRptData = ''

   CREATE TABLE #PagenoByOrderkey
   (
      Pickslipno NVARCHAR(10)
    , Loadkey    NVARCHAR(10)
    , Orderkey   NVARCHAR(10)
    , TotalPage  INT
   )


   SELECT @c_ShowPickdetailID = ISNULL(MAX(CASE WHEN Code = 'ShowPickdetailID' THEN 'Y'
                                                ELSE 'N' END)
                                     , 'N')
        , @c_BreakByPAZone = ISNULL(MAX(CASE WHEN Code = 'BreakByPAZone' THEN 'Y'
                                             ELSE 'N' END)
                                  , 'N')
        , @c_ShowRetailSKU = ISNULL(MAX(CASE WHEN Code = 'ShowRetailSKU' THEN 'Y'
                                             ELSE 'N' END)
                                  , 'N')
        , @c_ShowPageNoByOrderkey = ISNULL(MAX(CASE WHEN Code = 'ShowPageNoByOrderkey' THEN 'Y'
                                                    ELSE 'N' END)
                                         , 'N')
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'REPORTCFG'
   AND   Storerkey = (  SELECT TOP 1 StorerKey
                        FROM ORDERS (NOLOCK)
                        WHERE LoadKey = @c_Loadkey)
   AND   Long = 'RPT_LP_PLISTN_036'
   AND   ISNULL(Short, '') <> 'N'

   IF @c_ShowPickdetailID = NULL
      SET @c_ShowPickdetailID = N''
   IF @c_BreakByPAZone = NULL
      SET @c_BreakByPAZone = N''
   IF @c_ShowRetailSKU = NULL
      SET @c_ShowRetailSKU = N''
   IF @c_ShowPageNoByOrderkey = NULL
      SET @c_ShowPageNoByOrderkey = N''



   CREATE TABLE #temp_pick
   (
      PickSlipNo           NVARCHAR(10)
    , LoadKey              NVARCHAR(10)
    , OrderKey             NVARCHAR(10)
    , Externorderkey       NVARCHAR(50)
    , ConsigneeKey         NVARCHAR(15)
    , Company              NVARCHAR(45)
    , Addr1                NVARCHAR(45)
    , Addr2                NVARCHAR(45)
    , Addr3                NVARCHAR(45)
    , PostCode             NVARCHAR(15)
    , Route                NVARCHAR(10)
    , Route_Desc           NVARCHAR(60)
    , TrfRoom              NVARCHAR(5)
    , Notes1               NVARCHAR(60)
    , Notes2               NVARCHAR(60)
    , LOC                  NVARCHAR(10)
    , SKU                  NVARCHAR(20)
    , SkuDesc              NVARCHAR(60)
    , Qty                  INT
    , TempQty1             INT
    , TempQty2             INT
    , PrintedFlag          NVARCHAR(1)
    , Zone                 NVARCHAR(1)
    , PgGroup              INT
    , RowNum               INT
    , Carrierkey           NVARCHAR(60)
    , VehicleNo            NVARCHAR(10)
    , Lottable01           NVARCHAR(18)
    , Lottable02           NVARCHAR(18)
    , Lottable03           NVARCHAR(18)
    , Lottable04           DATETIME
    , LabelPrice           NVARCHAR(5)   NULL
    , storerkey            NVARCHAR(18)
    , invoiceno            NVARCHAR(10)  NULL
    , deliverydate         DATETIME      NULL
    , ordertype            NVARCHAR(250) NULL
    , qtyorder             INT           NULL DEFAULT 0
    , qtyallocated         INT           NULL DEFAULT 0
    , logicallocation      NVARCHAR(18)
    , casecnt              INT
    , pallet               INT
    , innerpack            INT
    , Skuindicator         NVARCHAR(1)   NULL
    , LRoute               NVARCHAR(10)  NULL
    , LEXTLoadKey          NVARCHAR(20)  NULL
    , LPriority            NVARCHAR(10)  NULL
    , LUDef01              NVARCHAR(20)  NULL
    , SUSR5                NVARCHAR(18)  NULL
    , ShowSUSR5            NVARCHAR(5)   NULL
    , ShowFullLoc          NVARCHAR(5)   NULL
    , ShowOrdType          NVARCHAR(5)   NULL
    , ShowCityState        NVARCHAR(5)   NULL
    , OHTypeDesc           NVARCHAR(50)  NULL
    , NewPostcode          NVARCHAR(120) NULL
    , ShowPickdetailID     NVARCHAR(5)   NULL
    , ID                   NVARCHAR(18)  NULL
    , Putawayzone          NVARCHAR(10)  NULL
    , BreakByPAZone        NVARCHAR(10)  NULL
    , RetailSKU            NVARCHAR(20)  NULL
    , CurrentPage          INT           NULL
    , TotalPage            INT           NULL
    , ShowPageNoByOrderkey NVARCHAR(10)  NULL
    , ShowEachInInnerCol   NVARCHAR(10)  NULL
   )
   CREATE TABLE #temp_pick2
   (
      PickSlipNo           NVARCHAR(10)
    , LoadKey              NVARCHAR(10)
    , OrderKey             NVARCHAR(10)
    , Externorderkey       NVARCHAR(50)
    , ConsigneeKey         NVARCHAR(15)
    , Company              NVARCHAR(45)
    , Addr1                NVARCHAR(45)
    , Addr2                NVARCHAR(45)
    , Addr3                NVARCHAR(45)
    , PostCode             NVARCHAR(15)
    , Route                NVARCHAR(10)
    , Route_Desc           NVARCHAR(60)
    , TrfRoom              NVARCHAR(5)
    , Notes1               NVARCHAR(60)
    , Notes2               NVARCHAR(60)
    , LOC                  NVARCHAR(10)
    , SKU                  NVARCHAR(20)
    , SkuDesc              NVARCHAR(60)
    , Qty                  INT
    , TempQty1             INT
    , TempQty2             INT
    , PrintedFlag          NVARCHAR(1)
    , Zone                 NVARCHAR(1)
    , PgGroup              INT
    , RowNum               INT
    , Carrierkey           NVARCHAR(60)
    , VehicleNo            NVARCHAR(10)
    , Lottable01           NVARCHAR(18)
    , Lottable02           NVARCHAR(18)
    , Lottable03           NVARCHAR(18)
    , Lottable04           DATETIME
    , LabelPrice           NVARCHAR(5)   NULL
    , storerkey            NVARCHAR(18)
    , invoiceno            NVARCHAR(10)  NULL
    , deliverydate         DATETIME      NULL
    , ordertype            NVARCHAR(250) NULL
    , qtyorder             INT           NULL DEFAULT 0
    , qtyallocated         INT           NULL DEFAULT 0
    , logicallocation      NVARCHAR(18)
    , casecnt              INT
    , pallet               INT
    , innerpack            INT
    , Skuindicator         NVARCHAR(1)   NULL
    , LRoute               NVARCHAR(10)  NULL
    , LEXTLoadKey          NVARCHAR(20)  NULL
    , LPriority            NVARCHAR(10)  NULL
    , LUDef01              NVARCHAR(20)  NULL
    , SUSR5                NVARCHAR(18)  NULL
    , ShowSUSR5            NVARCHAR(5)   NULL
    , ShowFullLoc          NVARCHAR(5)   NULL
    , ShowOrdType          NVARCHAR(5)   NULL
    , ShowCityState        NVARCHAR(5)   NULL
    , OHTypeDesc           NVARCHAR(50)  NULL
    , NewPostcode          NVARCHAR(120) NULL
    , ShowPickdetailID     NVARCHAR(5)   NULL
    , ID                   NVARCHAR(18)  NULL
    , Putawayzone          NVARCHAR(10)  NULL
    , BreakByPAZone        NVARCHAR(10)  NULL
    , RetailSKU            NVARCHAR(20)  NULL
    , CurrentPage          INT           NULL
    , TotalPage            INT           NULL
    , ShowPageNoByOrderkey NVARCHAR(10)  NULL
    , ShowEachInInnerCol   NVARCHAR(10)  NULL
   )

   SET @c_ShowSusr5 = N''
   SET @c_ShowFullLoc = N''

   SELECT @n_continue = 1
   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = N'N'


   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE ExternOrderKey = @c_loadkey AND Zone = '3')
   BEGIN
      SELECT @c_firsttime = N'N'
      SELECT @c_PrintedFlag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = N'Y'
      SELECT @c_PrintedFlag = N'N'
   END

   DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT COUNT(PICKDETAIL.Sku)
        , PICKDETAIL.Loc
        , SUM(PICKDETAIL.Qty)
        , PACK.Qty
        , PICKDETAIL.Storerkey
        , PICKDETAIL.OrderKey
        , PICKDETAIL.UOM
        , LOC.LogicalLocation
        --, PICKDETAIL.Lot
        , LoadPlan.Route
        , LoadPlan.ExternLoadKey
        , LoadPlan.Priority
        , CONVERT(NVARCHAR(10), LoadPlan.lpuserdefdate01, 103)
        , CASE WHEN @c_ShowPickdetailID = 'Y' THEN PICKDETAIL.ID
               ELSE '' END
        , CASE WHEN @c_BreakByPAZone = 'Y' THEN LOC.PutawayZone
               ELSE '' END
        , CASE WHEN @c_ShowRetailSKU = 'Y' THEN SKU.RETAILSKU
               ELSE '' END
   FROM PICKDETAIL (NOLOCK)
      , LoadPlanDetail (NOLOCK)
      , PACK (NOLOCK)
      , LOC (NOLOCK)
      , LoadPlan (NOLOCK)
      , SKU (NOLOCK)
   WHERE PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey
   AND   PICKDETAIL.PackKey = PACK.PackKey
   AND   LOC.Loc = PICKDETAIL.Loc
   AND   LoadPlan.LoadKey = LoadPlanDetail.LoadKey
   AND   PICKDETAIL.Sku = SKU.Sku
   AND   PICKDETAIL.Storerkey = SKU.StorerKey
   AND   LoadPlanDetail.LoadKey = @c_loadkey
   GROUP BY PICKDETAIL.Sku
          , PICKDETAIL.Loc
          , PACK.Qty
          , PICKDETAIL.Storerkey
          , PICKDETAIL.OrderKey
          , PICKDETAIL.UOM
          , LOC.LogicalLocation
          --, PICKDETAIL.Lot
          , LoadPlan.Route
          , LoadPlan.ExternLoadKey
          , LoadPlan.Priority
          , CONVERT(NVARCHAR(10), LoadPlan.lpuserdefdate01, 103)
          , CASE WHEN @c_ShowPickdetailID = 'Y' THEN PICKDETAIL.ID
                 ELSE '' END
          , CASE WHEN @c_BreakByPAZone = 'Y' THEN LOC.PutawayZone
                 ELSE '' END
          , CASE WHEN @c_ShowRetailSKU = 'Y' THEN SKU.RETAILSKU
                 ELSE '' END
   ORDER BY PICKDETAIL.OrderKey

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
      , @c_logicalloc
      --, @c_Lot
      , @c_LRoute
      , @c_LEXTLoadKey
      , @c_LPriority
      , @c_LUDef01
      , @c_ID
      , @c_PAZone
      , @c_RetailSKU

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @c_orderkey <> @c_PrevOrderKey
      BEGIN
         IF  NOT EXISTS (  SELECT 1
                           FROM PICKHEADER (NOLOCK)
                           WHERE ExternOrderKey = @c_loadkey AND OrderKey = @c_orderkey AND Zone = '3')
         AND @c_PreGenRptData = 'Y'
         BEGIN
            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_pickheaderkey OUTPUT
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            SELECT @c_pickheaderkey = N'P' + @c_pickheaderkey

            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_pickheaderkey, @c_orderkey, @c_loadkey, '0', '3', '')

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
            SELECT @c_firstorderkey = N'Y'
         END
         ELSE
         BEGIN
            SELECT @c_pickheaderkey = PickHeaderKey
            FROM PICKHEADER (NOLOCK)
            WHERE ExternOrderKey = @c_loadkey AND Zone = '3' AND OrderKey = @c_orderkey
         END
      END
      IF @c_orderkey = ''
      BEGIN
         SELECT @c_ConsigneeKey = N''
              , @c_Company = N''
              , @c_Addr1 = N''
              , @c_Addr2 = N''
              , @c_Addr3 = N''
              , @c_PostCode = N''
              , @c_Route = N''
              , @c_Route_Desc = N''
              , @c_Notes1 = N''
              , @c_Notes2 = N''
              , @c_invoiceno = N''
              , @c_NewPostCode = N''

      END
      ELSE
      BEGIN
         SELECT @c_Externorderkey = ORDERS.ExternOrderKey
              , @c_ConsigneeKey = ORDERS.ConsigneeKey
              , @c_Company = ORDERS.C_Company
              , @c_Addr1 = ORDERS.C_Address1
              , @c_Addr2 = ORDERS.C_Address2
              , @c_Addr3 = ORDERS.C_Address3
              , @c_PostCode = ORDERS.C_Zip
              , @c_Notes1 = CONVERT(NVARCHAR(60), ORDERS.Notes)
              , @c_Notes2 = CONVERT(NVARCHAR(60), ORDERS.Notes2)
              , @c_labelPrice = ISNULL(ORDERS.LabelPrice, 'N')
              , @c_invoiceno = ORDERS.ExternOrderKey
              , @d_deliverydate = ORDERS.DeliveryDate
              , @c_ordertype = CODELKUP.Description
              , @c_Route = ISNULL(ORDERS.Route, '')
              , @c_NewPostCode = (ISNULL(ORDERS.C_City, '') + ' ' + ISNULL(ORDERS.C_State, '') + ' '
                                  + ISNULL(ORDERS.C_Zip, ''))
              , @c_OHTypeDesc = ISNULL(CODELKUP.Short, '')
         FROM ORDERS (NOLOCK)
            , CODELKUP (NOLOCK)
         WHERE ORDERS.OrderKey = @c_orderkey AND ORDERS.Type = CODELKUP.Code AND LISTNAME = 'ORDERTYPE'
      END



      SELECT @n_loccnt = COUNT(DISTINCT PICKDETAIL.Loc)
      FROM PICKDETAIL (NOLOCK)
         , LoadPlanDetail (NOLOCK)
         , PACK (NOLOCK)
         , LOC (NOLOCK)
      WHERE PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey
      AND   PICKDETAIL.PackKey = PACK.PackKey
      AND   LOC.Loc = PICKDETAIL.Loc
      AND   LoadPlanDetail.LoadKey = @c_loadkey
      AND   PICKDETAIL.Sku = @c_sku
      GROUP BY LoadPlanDetail.LoadKey

      SELECT @c_skuindicator = CASE WHEN ISNULL(CL.Code, '') <> '' AND @n_loccnt <> 1 THEN 'R'
                                    ELSE '' END
           , @c_ShowSusr5 = CASE WHEN (CL1.Short IS NULL OR CL1.Short = 'N') THEN 'N'
                                 ELSE 'Y' END
           , @c_ShowFullLoc = CASE WHEN (CL2.Short IS NULL OR CL2.Short = 'N') THEN 'N'
                                   ELSE 'Y' END
           , @c_showordtype = CASE WHEN (CL3.Short IS NULL OR CL3.Short = 'N') THEN 'N'
                                   ELSE 'Y' END --(CS05)  
           , @c_showcitystate = CASE WHEN (CL4.Short IS NULL OR CL4.Short = 'N') THEN 'N'
                                     ELSE 'Y' END --(CS05)  
           , @c_ShowEachInInnerCol = CASE WHEN (CL5.Short IS NULL OR CL5.Short = 'N') THEN 'N'
                                          ELSE 'Y' END
      FROM SKU s WITH (NOLOCK)
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (   CL.LISTNAME = 'RPTCFGPICK'
                                             AND CL.Long = 'RPT_LP_PLISTN_036'
                                             AND CL.Storerkey = s.StorerKey
                                             AND CL.Code = s.SUSR3)
      LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'
                                           AND CL1.Long = 'RPT_LP_PLISTN_036'
                                           AND CL1.Code = 'SHOWSUSR5'
                                           AND CL1.Storerkey = s.StorerKey
      LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON  CL2.LISTNAME = 'REPORTCFG'
                                           AND CL2.Long = 'RPT_LP_PLISTN_036'
                                           AND CL2.Code = 'ShowFullLoc'
                                           AND CL2.Storerkey = s.StorerKey
      LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON  CL3.LISTNAME = 'REPORTCFG'
                                           AND CL3.Long = 'RPT_LP_PLISTN_036'
                                           AND CL3.Code = 'ShowOrdType'
                                           AND CL3.Storerkey = s.StorerKey
      LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON  CL4.LISTNAME = 'REPORTCFG'
                                           AND CL4.Long = 'RPT_LP_PLISTN_036'
                                           AND CL4.Code = 'ShowCityState'
                                           AND CL4.Storerkey = s.StorerKey
      LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON  CL5.LISTNAME = 'REPORTCFG'
                                           AND CL5.Long = 'RPT_LP_PLISTN_036'
                                           AND CL5.Code = 'ShowEachInInnerCol'
                                           AND CL5.Storerkey = s.StorerKey
      WHERE s.StorerKey = @c_StorerKey AND s.Sku = @c_sku





      SELECT @c_TrfRoom = ISNULL(LoadPlan.TrfRoom, '')
           , @c_VehicleNo = ISNULL(LoadPlan.TruckSize, '')
           , @c_Carrierkey = ISNULL(LoadPlan.CarrierKey, '')
      FROM LoadPlan (NOLOCK)
      WHERE LoadKey = @c_loadkey

      SELECT @c_Route_Desc = ISNULL(RouteMaster.Descr, '')
      FROM RouteMaster (NOLOCK)
      WHERE Route = @c_Route

      SELECT @c_SkuDesc = ISNULL(DESCR, '')
           , @c_susr5 = ISNULL(SUSR5, '')
      FROM SKU (NOLOCK)
      WHERE Sku = @c_sku AND StorerKey = @c_StorerKey

      SELECT @c_Lottable01 = Lottable01
           , @c_Lottable02 = ISNULL(Lottable02, '')
           , @c_Lottable03 = ISNULL(Lottable03, '')
           , @d_Lottable04 = Lottable04
      FROM LOTATTRIBUTE (NOLOCK)
      WHERE Lot = @c_Lot

      IF @c_Lottable01 IS NULL
         SELECT @c_Lottable01 = N''
      IF @d_Lottable04 IS NULL
         SELECT @d_Lottable04 = '01/01/1900'
      IF @c_Notes1 IS NULL
         SELECT @c_Notes1 = N''
      IF @c_Notes2 IS NULL
         SELECT @c_Notes2 = N''
      IF @c_Externorderkey IS NULL
         SELECT @c_Externorderkey = N''
      IF @c_ConsigneeKey IS NULL
         SELECT @c_ConsigneeKey = N''
      IF @c_Company IS NULL
         SELECT @c_Company = N''
      IF @c_Addr1 IS NULL
         SELECT @c_Addr1 = N''
      IF @c_Addr2 IS NULL
         SELECT @c_Addr2 = N''
      IF @c_Addr3 IS NULL
         SELECT @c_Addr3 = N''
      IF @c_PostCode IS NULL
         SELECT @c_PostCode = N''
      IF @c_Route IS NULL
         SELECT @c_Route = N''
      IF @c_Carrierkey IS NULL
         SELECT @c_Carrierkey = N''
      IF @c_Route_Desc IS NULL
         SELECT @c_Route_Desc = N''

      IF @c_superorderflag = 'Y'
         SELECT @c_orderkey = N''

      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0
           , @n_Cartons = 0
           , @n_inner = 0
           , @n_Eaches = 0

      SELECT @n_UOMQty = 0

      SELECT @n_UOMQty = CASE @c_UOM
                              WHEN '1' THEN PACK.Pallet
                              WHEN '2' THEN PACK.CaseCnt
                              WHEN '3' THEN PACK.InnerPack
                              ELSE 1 END
           , @c_uom_master = PACK.PackUOM3
           , @n_Pallets = PACK.Pallet
           , @n_Cartons = PACK.CaseCnt
           , @n_inner = PACK.InnerPack
      FROM PACK
         , SKU
      WHERE SKU.Sku = @c_sku AND SKU.StorerKey = @c_StorerKey AND PACK.PackKey = SKU.PACKKey


      IF @c_ShowEachInInnerCol = 'Y'
      BEGIN
         SELECT @c_ShowEachInInnerCol = CASE WHEN ISNULL(PACK.PackUOM9, '') <> ''
                                             AND  ISNULL(PACK.PackUOM9, '') NOT IN (  SELECT DISTINCT Code
                                                                                      FROM CODELKUP (NOLOCK)
                                                                                      WHERE Storerkey = SKU.StorerKey
                                                                                      AND   LISTNAME = 'ELANCO_UOM' )
                                             AND  PACK.OtherUnit2 > 0 THEN 'Y'
                                             ELSE 'N' END
         FROM SKU (NOLOCK)
         JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
         WHERE SKU.Sku = @c_sku AND SKU.StorerKey = @c_StorerKey
      END

      INSERT INTO #temp_pick (PickSlipNo, LoadKey, OrderKey, Externorderkey, ConsigneeKey, Company, Addr1, Addr2
                            , PgGroup, Addr3, PostCode, Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, SKU
                            , SkuDesc, Qty, TempQty1, TempQty2, PrintedFlag, Zone, Carrierkey, VehicleNo
                            , Lottable01, Lottable02, Lottable03, Lottable04, LabelPrice, storerkey, invoiceno
                            , deliverydate, ordertype, qtyorder, qtyallocated, logicallocation, casecnt, pallet
                            , innerpack, Skuindicator, LRoute, LEXTLoadKey, LPriority, LUDef01, SUSR5, ShowSUSR5
                            , ShowFullLoc, ShowOrdType, ShowCityState, OHTypeDesc, NewPostcode, ShowPickdetailID, ID
                            , Putawayzone, BreakByPAZone, RetailSKU, ShowPageNoByOrderkey, ShowEachInInnerCol)
      VALUES (@c_pickheaderkey, @c_loadkey, @c_orderkey, @c_Externorderkey, @c_ConsigneeKey, @c_Company, @c_Addr1
            , @c_Addr2, 0, @c_Addr3, @c_PostCode, @c_Route, @c_Route_Desc, @c_TrfRoom, @c_Notes1, @n_RowNo, @c_Notes2
            , @c_loc, @c_sku, @c_SkuDesc, @n_qty, CAST(@c_UOM AS INT), @n_UOMQty, @c_PrintedFlag, '3'
            , @c_Carrierkey, @c_VehicleNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @c_labelPrice
            , @c_StorerKey, @c_invoiceno, @d_deliverydate, @c_ordertype, @n_qtyorder, @n_qtyallocated, @c_logicalloc
            , @n_Cartons, @n_Pallets, @n_inner, @c_skuindicator, @c_LRoute, @c_LEXTLoadKey, @c_LPriority, @c_LUDef01
            , @c_susr5, @c_ShowSusr5, @c_ShowFullLoc, @c_showordtype, @c_showcitystate, @c_OHTypeDesc, @c_NewPostCode
            , @c_ShowPickdetailID, @c_ID, @c_PAZone, @c_BreakByPAZone, @c_RetailSKU, @c_ShowPageNoByOrderkey
            , @c_ShowEachInInnerCol)

      SELECT @c_PrevOrderKey = @c_orderkey

      FETCH NEXT FROM pick_cur
      INTO @c_sku
         , @c_loc
         , @n_qty
         , @n_UOM3
         , @c_StorerKey
         , @c_orderkey
         , @c_UOM
         , @c_logicalloc
         --, @c_Lot
         , @c_LRoute
         , @c_LEXTLoadKey
         , @c_LPriority
         , @c_LUDef01
         , @c_ID
         , @c_PAZone
         , @c_RetailSKU
   END

   CLOSE pick_cur
   DEALLOCATE pick_cur

   DECLARE cur1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderKey
   FROM #temp_pick
   WHERE OrderKey <> ''

   OPEN cur1
   FETCH NEXT FROM cur1
   INTO @c_orderkey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SELECT @n_qtyorder = SUM(ORDERDETAIL.OpenQty)
           , @n_qtyallocated = SUM(ORDERDETAIL.QtyAllocated)
      FROM ORDERDETAIL (NOLOCK)
      WHERE ORDERDETAIL.OrderKey = @c_orderkey




      UPDATE #temp_pick
      SET qtyorder = @n_qtyorder
        , qtyallocated = @n_qtyallocated
      WHERE OrderKey = @c_orderkey

      FETCH NEXT FROM cur1
      INTO @c_orderkey
   END

   CLOSE cur1
   DEALLOCATE cur1


   IF @c_ShowPageNoByOrderkey = 'Y'
   BEGIN
      INSERT INTO #PagenoByOrderkey (Pickslipno, Loadkey, Orderkey, TotalPage)
      SELECT t.PickSlipNo
           , t.LoadKey
           , t.OrderKey
           , COUNT(t.LoadKey + t.OrderKey + t.Putawayzone) / @n_MaxLine + 1
      FROM #temp_pick t
      GROUP BY t.Putawayzone
             , t.PickSlipNo
             , t.LoadKey
             , t.OrderKey

      SELECT TOP 1 @c_LastPutawayzone = Putawayzone
      FROM #temp_pick t
      ORDER BY LoadKey
             , OrderKey
             , Putawayzone
             , logicallocation
             , LOC
             , SKU
             , Lottable01
             , Lottable02
             , Lottable03
             , Lottable04
             , ID

      DECLARE CUR_LOOP CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT t.Putawayzone
                    , t.LoadKey
                    , t.OrderKey
                    , logicallocation
                    , LOC
                    , SKU
                    , Lottable01
                    , Lottable02
                    , Lottable03
                    , Lottable04
                    , ID
      FROM #temp_pick t
      ORDER BY LoadKey
             , OrderKey
             , Putawayzone
             , logicallocation
             , LOC
             , SKU
             , Lottable01
             , Lottable02
             , Lottable03
             , Lottable04
             , ID

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetPutawayzone
         , @c_GetLoadkey
         , @c_GetOrderkey
         , @c_logicalloc
         , @c_loc
         , @c_sku
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @d_Lottable04
         , @c_ID

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF  @c_LastPutawayzone <> @c_GetPutawayzone
         AND @c_LastLoadkey = @c_GetLoadkey
         AND @c_LastOrderkey = @c_GetOrderkey
         AND @b_flag = 0
         BEGIN
            SET @n_CurrentPG = @n_CurrentPG + 1
            SET @n_CurrentCnt = 1
         END
         IF @c_LastLoadkey = @c_GetLoadkey AND @c_LastOrderkey <> @c_GetOrderkey
         BEGIN
            SET @n_CurrentPG = 1
            SET @n_CurrentCnt = 1
         END



         SET @b_flag = 0

         UPDATE #temp_pick
         SET CurrentPage = @n_CurrentPG
         WHERE Putawayzone = @c_GetPutawayzone
         AND   LoadKey = @c_GetLoadkey
         AND   OrderKey = @c_GetOrderkey
         AND   logicallocation = @c_logicalloc
         AND   LOC = @c_loc
         AND   SKU = @c_sku
         AND   Lottable01 = @c_Lottable01
         AND   Lottable02 = @c_Lottable02
         AND   Lottable03 = @c_Lottable03
         AND   Lottable04 = @d_Lottable04
         AND   ID = @c_ID

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

         FETCH NEXT FROM CUR_LOOP
         INTO @c_GetPutawayzone
            , @c_GetLoadkey
            , @c_GetOrderkey
            , @c_logicalloc
            , @c_loc
            , @c_sku
            , @c_Lottable01
            , @c_Lottable02
            , @c_Lottable03
            , @d_Lottable04
            , @c_ID
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      DECLARE CUR_LOOPUDPATE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT t.LoadKey
           , t.OrderKey
           , MAX(CurrentPage)
      FROM #temp_pick t
      GROUP BY t.LoadKey
             , t.OrderKey

      OPEN CUR_LOOPUDPATE

      FETCH NEXT FROM CUR_LOOPUDPATE
      INTO @c_GetLoadkey
         , @c_GetOrderkey
         , @n_GetTotalPage

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE #temp_pick
         SET TotalPage = @n_GetTotalPage
         WHERE LoadKey = @c_GetLoadkey AND OrderKey = @c_GetOrderkey

         FETCH NEXT FROM CUR_LOOPUDPATE
         INTO @c_GetLoadkey
            , @c_GetOrderkey
            , @n_GetTotalPage
      END
      CLOSE CUR_LOOPUDPATE
      DEALLOCATE CUR_LOOPUDPATE
   END
   
    DECLARE CUR_LOOPUDPATE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT t.Putawayzone
            ,SUM(T.qty)
            ,COUNT(T.Putawayzone)
      FROM #temp_pick t
      GROUP BY t.Putawayzone
      Order by t.Putawayzone
      OPEN CUR_LOOPUDPATE

      FETCH NEXT FROM CUR_LOOPUDPATE
      INTO @c_GetPutawayzone
      ,@n_GetQty
      ,@c_GetSKU

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         UPDATE #temp_pick 
         SET Qty  = @n_GetQty
            ,SKU  = @c_GetSKU
         WHERE Putawayzone = @c_GetPutawayzone
 
             Insert into #temp_pick2(PickSlipNo, LoadKey, OrderKey, Externorderkey, ConsigneeKey, Company, Addr1, Addr2
                            , PgGroup, Addr3, PostCode, Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, SKU
                            , SkuDesc, Qty, TempQty1, TempQty2, PrintedFlag, Zone, Carrierkey, VehicleNo
                            , Lottable01, Lottable02, Lottable03, Lottable04, LabelPrice, storerkey, invoiceno
                            , deliverydate, ordertype, qtyorder, qtyallocated, logicallocation, casecnt, pallet
                            , innerpack, Skuindicator, LRoute, LEXTLoadKey, LPriority, LUDef01, SUSR5, ShowSUSR5
                            , ShowFullLoc, ShowOrdType, ShowCityState, OHTypeDesc, NewPostcode, ShowPickdetailID, ID
                            , Putawayzone, BreakByPAZone, RetailSKU, ShowPageNoByOrderkey, ShowEachInInnerCol)
      SELECT  top 1 PickSlipNo, LoadKey, OrderKey, Externorderkey, ConsigneeKey, Company, Addr1, Addr2
                            , PgGroup, Addr3, PostCode, Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, SKU
                            , SkuDesc, Qty, TempQty1, TempQty2, PrintedFlag, Zone, Carrierkey, VehicleNo
                            , Lottable01, Lottable02, Lottable03, Lottable04, LabelPrice, storerkey, invoiceno
                            , deliverydate, ordertype, qtyorder, qtyallocated, logicallocation, casecnt, pallet
                            , innerpack, Skuindicator, LRoute, LEXTLoadKey, LPriority, LUDef01, SUSR5, ShowSUSR5
                            , ShowFullLoc, ShowOrdType, ShowCityState, OHTypeDesc, NewPostcode, ShowPickdetailID, ID
                            , Putawayzone, BreakByPAZone, RetailSKU, ShowPageNoByOrderkey, ShowEachInInnerCol
      FROM #temp_pick(NOLOCK)
      WHERE Putawayzone = @c_GetPutawayzone
        
         FETCH NEXT FROM CUR_LOOPUDPATE
         INTO @c_GetPutawayzone
      ,@n_GetQty
      ,@c_GetSKU

      END
      CLOSE CUR_LOOPUDPATE
      DEALLOCATE CUR_LOOPUDPATE
      
   IF ISNULL(@c_PreGenRptData, '') = ''
   BEGIN
      SET @c_SQL = N'SELECT #temp_pick2.*, pickheader.adddate ' + CHAR(13) + N'FROM #temp_pick2, pickheader (nolock) '
                   + CHAR(13) + N'WHERE #temp_pick2.pickslipno = pickheader.pickheaderkey ' + CHAR(13)

      --IF @c_BreakByPAZone = 'Y'
      --BEGIN
      --   SET @c_OrderBy = N'ORDER BY #temp_pick2.loadkey, #temp_pick2.orderkey, #temp_pick2.Putawayzone, #temp_pick2.LogicalLocation, #temp_pick2.LOC, '
      --                    + N'#temp_pick2.sku, #temp_pick2.lottable01, #temp_pick2.lottable02, #temp_pick2.lottable03, #temp_pick2.lottable04, #temp_pick2.id '
      --END
      IF @c_BreakByPAZone = 'Y'
      BEGIN
         SET @c_OrderBy = N'ORDER BY #temp_pick2.Putawayzone'
      END
      ELSE
      --BEGIN
      --   SET @c_OrderBy = N'ORDER BY #temp_pick2.loadkey, #temp_pick2.orderkey, #temp_pick2.logicallocation, #temp_pick2.loc, '
      --                    + CHAR(13)
      --                    + N'#temp_pick2.sku, #temp_pick2.lottable01, #temp_pick2.lottable02, #temp_pick2.lottable03, #temp_pick2.lottable04 '
      --END
      BEGIN
         SET @c_OrderBy = N'ORDER BY #temp_pick2.Putawayzone'
      END

      SET @c_SQL = @c_SQL + N' ' + @c_OrderBy

      EXECUTE sp_executesql @c_SQL
   END
END

GO