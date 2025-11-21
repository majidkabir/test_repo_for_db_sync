SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ISP_RPT_LP_PIDXDPLIST_001                          */
/* Creation Date: 03-MAR-2023                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21902 & WMS-23565 Migrate WMS report to Logi Report     */
/*                    r_dw_print_pickorder127  (TH)                     */
/*                                                                      */
/* Called By: RPT_LP_PIDXDPLIST_001                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 03-MAR-2023  WZPang   1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ISP_RPT_LP_PIDXDPLIST_001]
(
   @c_Loadkey       NVARCHAR(10)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS ON

   DECLARE @c_pickheaderkey     NVARCHAR(10)
         , @n_continue          INT
         , @c_errmsg            NVARCHAR(255)
         , @b_success           INT
         , @n_err               INT
         , @c_sku               NVARCHAR(25)
         , @n_qty               INT
         , @c_loc               NVARCHAR(10)
         , @n_cases             INT
         , @n_perpallet         INT
         , @c_storer            NVARCHAR(15)
         , @c_orderkey          NVARCHAR(10)
         , @c_ConsigneeKey      NVARCHAR(15)
         , @c_Company           NVARCHAR(45)
         , @c_Addr1             NVARCHAR(45)
         , @c_Addr2             NVARCHAR(45)
         , @c_Addr3             NVARCHAR(45)
         , @c_PostCode          NVARCHAR(15)
         , @c_Route             NVARCHAR(10)
         , @c_Route_Desc        NVARCHAR(60) -- RouteMaster.Desc
         , @c_TrfRoom           NVARCHAR(5) -- LoadPlan.TrfRoom
         , @c_Notes1            NVARCHAR(60)
         , @c_Notes2            NVARCHAR(60)
         , @c_SkuDesc           NVARCHAR(60)
         , @n_CaseCnt           INT
         , @n_InnerPack         INT
         , @n_PalletCnt         INT
         , @c_ReceiptTm         NVARCHAR(20)
         , @c_PrintedFlag       NVARCHAR(1)
         , @c_UOM               NVARCHAR(10)
         , @n_UOM3              INT
         , @c_Lot               NVARCHAR(10)
         , @c_StorerKey         NVARCHAR(15)
         , @c_Zone              NVARCHAR(1)
         , @n_PgGroup           INT
         , @n_TotCases          INT
         , @n_RowNo             INT
         , @c_PrevSKU           NVARCHAR(25)
         , @n_SKUCount          INT
         , @c_Carrierkey        NVARCHAR(60)
         , @c_VehicleNo         NVARCHAR(10)
         , @c_firstorderkey     NVARCHAR(10)
         , @c_superorderflag    NVARCHAR(1)
         , @c_firsttime         NVARCHAR(1)
         , @c_logicalloc        NVARCHAR(18)
         , @c_Lottable01        NVARCHAR(10)
         , @d_Lottable04        DATETIME
         , @c_labelPrice        NVARCHAR(5)
         , @c_externorderkey    NVARCHAR(50)
         , @c_Facility          NVARCHAR(5)
         , @c_Lottable02        NVARCHAR(18)
         , @c_DeliveryNote      NVARCHAR(10)
         , @c_ShowCustomFormula NVARCHAR(10)
         , @c_SortByLogicalLoc  NVARCHAR(10)
         , @d_DeliveryDate      DATETIME
         , @c_Addr4             NVARCHAR(100)
         , @c_State             NVARCHAR(100)
         , @c_City              NVARCHAR(100)
         , @c_Country           NVARCHAR(100)
         , @c_Priority          NVARCHAR(20)
         , @c_ID                NVARCHAR(20)
         , @c_Lottable03        NVARCHAR(10)
         , @c_Lottable12        NVARCHAR(10)
         , @c_OHRoute           NVARCHAR(10)

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT


   DECLARE @c_Style       NVARCHAR(20)
         , @c_Color       NVARCHAR(10)
         , @c_Size        NVARCHAR(5)
         , @c_Measurement NVARCHAR(5)
         , @c_SkuPattern  NVARCHAR(10)
         , @n_WrapSkuDesc INT

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

   DECLARE @c_Sku2          NVARCHAR(20)
         , @c_Consigneekey2 NVARCHAR(15)
         , @n_starttrancnt  INT

   SET @c_Style = N''
   SET @c_Color = N''
   SET @c_Size = N''
   SET @c_Measurement = N''
   SET @c_SkuPattern = N''

   CREATE TABLE #temp_pick
   (
      PickSlipNo        NVARCHAR(10) NULL
    , LoadKey           NVARCHAR(10)
    , OrderKey          NVARCHAR(10)
    , ConsigneeKey      NVARCHAR(15)
    , Company           NVARCHAR(45)
    , Addr1             NVARCHAR(45)
    , Addr2             NVARCHAR(45)
    , Addr3             NVARCHAR(45)
    , PostCode          NVARCHAR(15)
    , Route             NVARCHAR(10)
    , Route_Desc        NVARCHAR(60) -- RouteMaster.Desc
    , TrfRoom           NVARCHAR(5) -- LoadPlan.TrfRoom
    , Notes1            NVARCHAR(60)
    , Notes2            NVARCHAR(60)
    , LOC               NVARCHAR(10)
    , SKU               NVARCHAR(25)
    , SkuDesc           NVARCHAR(60)
    , Qty               INT
    , TempQty1          INT
    , TempQty2          INT
    , PrintedFlag       NVARCHAR(1)
    , Zone              NVARCHAR(1)
    , PgGroup           INT
    , RowNum            INT
    , Lot               NVARCHAR(10)
    , Carrierkey        NVARCHAR(60)
    , VehicleNo         NVARCHAR(10)
    , Lottable01        NVARCHAR(10)
    , Lottable04        DATETIME
    , LabelPrice        NVARCHAR(5)
    , ExternOrderKey    NVARCHAR(50)
    , Facility          NVARCHAR(5)
    , Lottable02        NVARCHAR(18)
    , DeliveryNote      NVARCHAR(10)
    , DeliveryDate      DATETIME
    , SKU2              NVARCHAR(20)
    , Consigneekey2     NVARCHAR(15)
    , WrapSkuDesc       INT
    , ShowAltSku        INT
    , CustCol01         INT
    , CustCol01_Text    NVARCHAR(60)
    , CustCol02         INT
    , CustCol02_Text    NVARCHAR(60)
    , CustCol03         INT
    , CustCol03_Text    NVARCHAR(60)
    , ShowCustomFormula NVARCHAR(10)
    , LogicalLoc        NVARCHAR(20)
    , Addr4             NVARCHAR(45)
    , [State]           NVARCHAR(45)
    , City              NVARCHAR(45)
    , Country           NVARCHAR(45)
    , [Priority]        NVARCHAR(45)
    , ID                NVARCHAR(10)
    , Lottable03        NVARCHAR(10)
    , Lottable12        NVARCHAR(10)
    , OHRoute           NVARCHAR(10)
   )

   SELECT @n_continue = 1
   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = N'N'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE ExternOrderKey = @c_Loadkey AND Zone = '3')
   BEGIN
      SELECT @c_firsttime = N'N'
      SELECT @c_PrintedFlag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = N'Y'
      SELECT @c_PrintedFlag = N'N'
   END -- Record Not Exists

   SELECT @n_starttrancnt = @@TRANCOUNT

   BEGIN TRAN

   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER
   SET PickType = '1'
     , TrafficCop = NULL
   WHERE ExternOrderKey = @c_Loadkey AND Zone = '3' AND PickType = '0'

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
   SELECT PICKDETAIL.Sku
        , PICKDETAIL.Loc
        , SUM(PICKDETAIL.Qty)
        , PACK.Qty
        , PICKDETAIL.Storerkey
        , PICKDETAIL.OrderKey
        , PICKDETAIL.UOM
        , LOC.LogicalLocation
        , ''
        , PICKDETAIL.ID
        , LOTATTRIBUTE.Lottable01
        , LOTATTRIBUTE.Lottable03
        , LOTATTRIBUTE.Lottable12
   FROM PICKDETAIL (NOLOCK)
   JOIN LoadPlanDetail (NOLOCK) ON PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey
   JOIN PACK (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
   JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
   JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   WHERE LoadPlanDetail.LoadKey = @c_Loadkey
   GROUP BY PICKDETAIL.Sku
          , PICKDETAIL.Loc
          , PACK.Qty
          , PICKDETAIL.Storerkey
          , PICKDETAIL.OrderKey
          , PICKDETAIL.UOM
          , LOC.LogicalLocation
          --, PICKDETAIL.Lot
          , PICKDETAIL.ID
          , LOTATTRIBUTE.Lottable01
          , LOTATTRIBUTE.Lottable03
          , LOTATTRIBUTE.Lottable12
   ORDER BY PICKDETAIL.OrderKey ASC
          , LOC.LogicalLocation ASC
          , PICKDETAIL.Sku ASC
          , SUM(PICKDETAIL.Qty) DESC 
          , PICKDETAIL.ID ASC

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
      , @c_Lot
      , @c_ID
      , @c_Lottable01
      , @c_Lottable03
      , @c_Lottable12

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
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
              , @c_Facility = N''
              , @c_DeliveryNote = N''
              , @c_Consigneekey2 = N''
              , @c_Addr4 = N''
              , @c_State = N''
              , @c_City = N''
              , @c_Country = N''
              , @c_OHRoute = N''
      END
      ELSE
      BEGIN
         SELECT @c_ConsigneeKey = ORDERS.BillToKey
              , @c_Company = ORDERS.C_Company
              , @c_Addr1 = ORDERS.C_Address1
              , @c_Addr2 = ORDERS.C_Address2
              , @c_Addr3 = ORDERS.C_Address3
              , @c_PostCode = ORDERS.C_Zip
              , @c_Notes1 = CONVERT(NVARCHAR(60), ORDERS.Notes)
              , @c_Notes2 = CONVERT(NVARCHAR(60), ORDERS.Notes2)
              , @c_labelPrice = ISNULL(ORDERS.LabelPrice, 'N')
              , @c_externorderkey = ExternOrderKey
              , @c_Facility = ORDERS.Facility
              , @c_DeliveryNote = ORDERS.DeliveryNote
              , @d_DeliveryDate = ORDERS.DeliveryDate
              , @c_Consigneekey2 = ORDERS.ConsigneeKey
              , @c_Addr4 = ORDERS.C_Address4
              , @c_State = ORDERS.C_State
              , @c_City = ORDERS.C_City
              , @c_Country = ORDERS.C_Country
              , @c_OHRoute = ORDERS.Route
         FROM ORDERS (NOLOCK)
         WHERE ORDERS.OrderKey = @c_orderkey
      END -- IF @c_OrderKey = ''

      SELECT @c_TrfRoom = ISNULL(LoadPlan.TrfRoom, '')
           , @c_Route = ISNULL(LoadPlan.Route, '')
           , @c_VehicleNo = ISNULL(LoadPlan.TruckSize, '')
           , @c_Carrierkey = ISNULL(LoadPlan.CarrierKey, '')
           , @c_Priority = ISNULL(LoadPlan.Priority, '')
      FROM LoadPlan (NOLOCK)
      WHERE LoadKey = @c_Loadkey

      SELECT @c_Route_Desc = ISNULL(RouteMaster.Descr, '')
      FROM RouteMaster (NOLOCK)
      WHERE Route = @c_Route

      SELECT @c_SkuDesc = ISNULL(DESCR, '')
           , @c_Style = ISNULL(RTRIM(Style), '')
           , @c_Color = ISNULL(RTRIM(Color), '')
           , @c_Size = ISNULL(RTRIM(Size), '')
           , @c_Measurement = ISNULL(RTRIM(Measurement), '')
      FROM SKU (NOLOCK)
      WHERE StorerKey = @c_StorerKey AND Sku = @c_sku

      IF @c_Lottable01 IS NULL
         SELECT @c_Lottable01 = N''
      IF @d_Lottable04 IS NULL
         SELECT @d_Lottable04 = '01/01/1900'
      IF @c_Notes1 IS NULL
         SELECT @c_Notes1 = N''
      IF @c_Notes2 IS NULL
         SELECT @c_Notes2 = N''
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
      IF @c_Facility IS NULL
         SELECT @c_Facility = N''
      IF @c_Lottable02 IS NULL
         SELECT @c_Lottable02 = N''
      IF @c_DeliveryNote IS NULL
         SELECT @c_DeliveryNote = N''
      IF @c_Consigneekey2 IS NULL
         SELECT @c_Consigneekey2 = N''
      IF @c_Addr4 IS NULL
         SELECT @c_Addr4 = N''
      IF @c_State IS NULL
         SELECT @c_State = N''
      IF @c_City IS NULL
         SELECT @c_City = N''
      IF @c_Country IS NULL
         SELECT @c_Country = N''
      IF @c_Priority IS NULL
         SELECT @c_Priority = N''
      IF @c_Lottable03 IS NULL
         SELECT @c_Lottable03 = N''
      IF @c_Lottable12 IS NULL
         SELECT @c_Lottable12 = N''
      IF @c_OHRoute IS NULL
         SELECT @c_OHRoute = N''

      IF @c_superorderflag = 'Y'
         SELECT @c_orderkey = N''

      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0
           , @n_Cartons = 0
           , @n_Eaches = 0
      SELECT @n_CaseCnt = 0
           , @n_InnerPack = 0
      SELECT @n_CaseCnt = PACK.CaseCnt
           , @n_InnerPack = PACK.InnerPack
      FROM PACK (NOLOCK)
      JOIN SKU (NOLOCK) ON PACK.PackKey = SKU.PACKKey
      WHERE SKU.Sku = @c_sku AND SKU.StorerKey = @c_StorerKey

      SELECT @c_pickheaderkey = NULL

      SELECT @c_pickheaderkey = ISNULL(PickHeaderKey, '')
      FROM PICKHEADER (NOLOCK)
      WHERE ExternOrderKey = @c_Loadkey AND Zone = '3' AND OrderKey = @c_orderkey

      INSERT INTO #temp_pick (PickSlipNo, LoadKey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, PgGroup, Addr3
                            , PostCode, Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, SKU, SkuDesc, Qty
                            , TempQty1, TempQty2, PrintedFlag, Zone, Lot, Carrierkey, VehicleNo, Lottable01, Lottable04
                            , LabelPrice, ExternOrderKey, Facility, Lottable02, DeliveryNote, DeliveryDate, SKU2
                            , Consigneekey2, WrapSkuDesc, ShowAltSku, CustCol01, CustCol01_Text, CustCol02
                            , CustCol02_Text, CustCol03, CustCol03_Text, ShowCustomFormula, LogicalLoc, Addr4, State
                            , City, Country, Priority, ID, Lottable03, Lottable12, OHRoute)
      VALUES (@c_pickheaderkey, @c_Loadkey, @c_orderkey, @c_ConsigneeKey, @c_Company, @c_Addr1, @c_Addr2, 0, @c_Addr3
            , @c_PostCode, @c_Route, @c_Route_Desc, @c_TrfRoom, @c_Notes1, @n_RowNo, @c_Notes2, @c_loc, @c_sku
            , @c_SkuDesc, @n_qty, @n_CaseCnt, @n_InnerPack, @c_PrintedFlag, '3', @c_Lot, @c_Carrierkey, @c_VehicleNo
            , @c_Lottable01, NULL, @c_labelPrice, @c_externorderkey, @c_Facility, ''
            , @c_DeliveryNote, @d_DeliveryDate, @c_Sku2, @c_Consigneekey2, @n_WrapSkuDesc, @n_ShowAltSku, @n_CustCol01
            , @c_CustCol01_Text, @n_CustCol02, @c_CustCol02_Text, @n_CustCol03, @c_CustCol03_Text, @c_ShowCustomFormula
            , CASE WHEN @c_SortByLogicalLoc = 'Y' THEN @c_logicalloc
                   ELSE '' END, @c_Addr4, @c_State, @c_City, @c_Country, @c_Priority, @c_ID, @c_Lottable03
            , @c_Lottable12, @c_OHRoute)

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
         , @c_Lot
         , @c_ID
         , @c_Lottable01
         , @c_Lottable03
         , @c_Lottable12
   END

   CLOSE pick_cur
   DEALLOCATE pick_cur

   DECLARE @n_pickslips_required INT
         , @c_NextNo             NVARCHAR(10)

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #temp_pick
   WHERE dbo.fnc_RTRIM(PickSlipNo) IS NULL OR dbo.fnc_RTRIM(PickSlipNo) = ''
   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_pickslips_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP'
                        , 9
                        , @c_NextNo OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                        , 0
                        , @n_pickslips_required
      IF @b_success <> 1
         GOTO FAILURE


      SELECT @c_orderkey = N''
      WHILE 1 = 1
      BEGIN
         SELECT @c_orderkey = MIN(OrderKey)
         FROM #temp_pick
         WHERE OrderKey > @c_orderkey AND PickSlipNo IS NULL

         IF dbo.fnc_RTRIM(@c_orderkey) IS NULL OR dbo.fnc_RTRIM(@c_orderkey) = ''
            BREAK

         IF NOT EXISTS (  SELECT 1
                          FROM PICKHEADER (NOLOCK)
                          WHERE OrderKey = @c_orderkey)
         BEGIN
            SELECT @c_pickheaderkey = N'P' + @c_NextNo
            SELECT @c_NextNo = RIGHT(REPLICATE('0', 9) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(STR(CAST(@c_NextNo AS INT) + 1))), 9)

            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_pickheaderkey, @c_orderkey, @c_Loadkey, '0', '3', '')

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
      END -- WHILE

      UPDATE #temp_pick
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #temp_pick.LoadKey
      AND   PICKHEADER.OrderKey = #temp_pick.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   #temp_pick.PickSlipNo IS NULL

   END
   GOTO SUCCESS

   FAILURE:
   DELETE FROM #temp_pick

   SUCCESS:    
   DECLARE @nCnt       INT
         , @cStorerKey NVARCHAR(15)

   IF (  SELECT COUNT(DISTINCT StorerKey)
         FROM ORDERS (NOLOCK)
            , LoadPlanDetail (NOLOCK)
         WHERE LoadPlanDetail.OrderKey = ORDERS.OrderKey AND LoadPlanDetail.LoadKey = @c_Loadkey) = 1
   BEGIN
      -- Only 1 storer found
      SELECT @cStorerKey = N''
      SELECT @cStorerKey = (  SELECT DISTINCT StorerKey
                              FROM ORDERS (NOLOCK)
                                 , LoadPlanDetail (NOLOCK)
                              WHERE LoadPlanDetail.OrderKey = ORDERS.OrderKey AND LoadPlanDetail.LoadKey = @c_Loadkey)

      IF EXISTS (  SELECT 1
                   FROM StorerConfig (NOLOCK)
                   WHERE ConfigKey = 'AUTOSCANIN' AND SValue = '1' AND StorerKey = @cStorerKey)
      BEGIN
         -- Configkey is setup
         DECLARE @cPickSlipNo NVARCHAR(10)

         SELECT @cPickSlipNo = N''
         WHILE 1 = 1
         BEGIN
            SELECT @cPickSlipNo = MIN(PickSlipNo)
            FROM #temp_pick
            WHERE PickSlipNo > @cPickSlipNo

            IF dbo.fnc_RTRIM(@cPickSlipNo) IS NULL OR dbo.fnc_RTRIM(@cPickSlipNo) = ''
               BREAK

            IF NOT EXISTS (  SELECT 1
                             FROM PickingInfo (NOLOCK)
                             WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME(), NULL)
            END
         END
      END -- Configkey is setup
   END -- Only 1 storer found

   SELECT TOP 1 @c_Orderkey = TP.Orderkey
   FROM #temp_pick TP
   ORDER BY TP.OrderKey DESC

   SELECT PickSlipNo
        , LoadKey
        , OrderKey
        , ConsigneeKey
        , Company
        , Addr1
        , Addr2
        , Addr3
        , PostCode
        , Route
        , Route_Desc
        , TrfRoom
        , Notes1
        , Notes2
        , LOC
        , SKU
        , SkuDesc
        , Qty
        , TempQty1
        , TempQty2
        , PrintedFlag
        , Zone
        , PgGroup
        , RowNum
        , Lot
        , Carrierkey
        , VehicleNo
        , Lottable01
        , Lottable04
        , LabelPrice
        , ExternOrderKey
        , Facility
        , Lottable02
        , DeliveryNote
        , DeliveryDate
        , SKU2
        , Consigneekey2
        , WrapSkuDesc
        , ShowAltSku
        , CustCol01
        , CustCol01_Text
        , CustCol02
        , CustCol02_Text
        , CustCol03
        , CustCol03_Text
        , CASE WHEN TempQty1 > 0 AND ShowCustomFormula = 'Y' THEN FLOOR(Qty / TempQty1)
               ELSE 0 END AS CS
        , CASE WHEN TempQty2 > 0 AND ShowCustomFormula = 'Y' THEN
                  FLOOR((Qty - (CASE WHEN TempQty1 > 0 THEN FLOOR(Qty / TempQty1) * TempQty1
                                     ELSE 0 END)) / TempQty2)
               ELSE 0 END AS InnerP
        , CASE WHEN ShowCustomFormula = 'Y' THEN
                  Qty - (CASE WHEN TempQty1 > 0 THEN FLOOR(Qty / TempQty1) * TempQty1
                              ELSE 0 END)
                  - (CASE WHEN TempQty2 > 0 THEN
                             FLOOR((Qty - (CASE WHEN TempQty1 > 0 THEN FLOOR(Qty / TempQty1) * TempQty1
                                                ELSE 0 END)) / TempQty2)
                          ELSE 0 END * TempQty2)
               ELSE 0 END AS EA
        , ShowCustomFormula
        , LogicalLoc
        , Addr4
        , [State]
        , City
        , Country
        , Priority
        , ID
        , Lottable03
        , Lottable12
        , OHRoute
        , CASE WHEN OrderKey = @c_Orderkey THEN 'N' ELSE 'Y' END AS FillWholePage
   FROM #temp_pick
   ORDER BY RowNum

   IF CURSOR_STATUS('LOCAL', 'pick_cur') IN ( 0, 1 )
   BEGIN
      CLOSE pick_cur
      DEALLOCATE pick_cur
   END

   IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL
      DROP TABLE #temp_pick

END -- procedure    

GO