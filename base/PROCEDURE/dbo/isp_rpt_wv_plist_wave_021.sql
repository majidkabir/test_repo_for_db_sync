SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_WV_PLIST_WAVE_021                               */
/* Creation Date: 03-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22368 - [TW] LVS_PickSlip_Report_CR                     */
/*        :                                                             */
/* Called By: RPT_WV_PLIST_WAVE_021                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 03-May-2023  WLChooi   1.0 DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_021]
(@c_Wavekey NVARCHAR(10), @c_PreGenRptData NVARCHAR(10) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickheaderKey  NVARCHAR(10)
         , @c_PickSlipNo     NVARCHAR(10)
         , @c_PrintedFlag    NVARCHAR(1)
         , @n_continue       INT
         , @c_errmsg         NVARCHAR(255)
         , @b_success        INT
         , @n_err            INT
         , @c_Facility       NVARCHAR(5)
         , @c_Orderkey       NVARCHAR(10)
         , @c_Externorderkey NVARCHAR(30)
         , @c_Consigneekey   NVARCHAR(15)
         , @c_BillToKey      NVARCHAR(15)
         , @c_Company        NVARCHAR(45)
         , @c_Addr1          NVARCHAR(45)
         , @c_Addr2          NVARCHAR(45)
         , @c_Addr3          NVARCHAR(45)
         , @c_PostCode       NVARCHAR(15)
         , @c_Route          NVARCHAR(10)
         , @c_Route_Desc     NVARCHAR(60) -- RouteMaster.Desc        
         , @c_TrfRoom        NVARCHAR(5) -- LoadPlan.TrfRoom        
         , @c_Carrierkey     NVARCHAR(60)
         , @c_VehicleNo      NVARCHAR(10)
         , @c_DeliveryNote   NVARCHAR(10)
         , @d_DeliveryDate   DATETIME
         , @c_labelPrice     NVARCHAR(5)
         , @c_Notes1         NVARCHAR(60)
         , @c_Notes2         NVARCHAR(60)
         , @c_StorerKey      NVARCHAR(15)
         , @c_sku            NVARCHAR(20)
         , @c_SkuDesc        NVARCHAR(60)
         , @c_UOM            NVARCHAR(10)
         , @c_loc            NVARCHAR(10)
         , @c_ID             NVARCHAR(18)
         , @n_qty            INT
         , @c_Logicalloc     NVARCHAR(18)
         , @c_firsttime      NVARCHAR(1)
         , @n_MaxRec         INT = 1
         , @n_CurrentRec     INT = 1
         , @n_MaxLineno      INT = 30
         , @c_Loadkey        NVARCHAR(10)
         , @n_MaxPerPage     INT = 28

   DECLARE @c_Style           NVARCHAR(20)
         , @c_Color           NVARCHAR(10)
         , @c_Size            NVARCHAR(5)
         , @c_Article         NVARCHAR(70)
         , @c_ManufacturerSKU NVARCHAR(70)

   DECLARE @n_PS_required   INT
         , @c_NextNo        NVARCHAR(10)
         , @c_cdescr        NVARCHAR(120)
         , @c_ECOMFlag      NVARCHAR(10)
         , @c_Wavedetailkey NVARCHAR(10)

   SET @c_Style = N''
   SET @c_Color = N''
   SET @c_Size = N''
   SET @c_cdescr = N''
   SET @c_PreGenRptData = IIF(@c_PreGenRptData = 'Y', 'Y', '')

   CREATE TABLE #temp_pick
   (
      rowid           INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , PickSlipNo      NVARCHAR(10)  NULL      
    , PrintedFlag     NVARCHAR(1)   NULL
    , Facility        NVARCHAR(5)   NULL
    , LoadKey         NVARCHAR(10)  NULL
    , OrderKey        NVARCHAR(10)  NULL
    , ExternOrderKey  NVARCHAR(30)  NULL
    , Consigneekey    NVARCHAR(15)  NULL
    , Company         NVARCHAR(45)  NULL
    , Addr1           NVARCHAR(45)  NULL
    , Addr2           NVARCHAR(45)  NULL
    , Addr3           NVARCHAR(45)  NULL
    , PostCode        NVARCHAR(15)  NULL
    , BillToKey       NVARCHAR(15)  NULL
    , Route           NVARCHAR(10)  NULL
    , Route_Desc      NVARCHAR(60)  NULL -- RouteMaster.Desc        
    , TrfRoom         NVARCHAR(5)   NULL -- LoadPlan.TrfRoom        
    , Carrierkey      NVARCHAR(60)  NULL
    , VehicleNo       NVARCHAR(10)  NULL
    , DeliveryNote    NVARCHAR(10)  NULL
    , DeliveryDate    DATETIME      NULL
    , LabelPrice      NVARCHAR(5)   NULL
    , Notes1          NVARCHAR(60)  NULL
    , Notes2          NVARCHAR(60)  NULL
    , ManufacturerSKU NVARCHAR(70)  NULL
    , SKU             NVARCHAR(20)  NULL
    , SkuDesc         NVARCHAR(60)  NULL
    , Qty             INT           NULL
    , LOC             NVARCHAR(10)  NULL
    , ID              NVARCHAR(18)  NULL
    , CDESCR          NVARCHAR(120) NULL
    , Wavedetailkey   NVARCHAR(10)  NULL
   )

   SELECT TOP 1 @c_ECOMFlag = TRIM(ISNULL(ORDERS.Type, ''))
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey

   IF (@c_ECOMFlag = 'ECOM')
      GOTO QUIT_RESULT

   SET @n_continue = 1

   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.OrderKey
        , PICKDETAIL.Storerkey
        , PICKDETAIL.Sku
        , PICKDETAIL.Loc
        , PICKDETAIL.UOM
        , PICKDETAIL.ID
        , SUM(PICKDETAIL.Qty)
        , LOC.LogicalLocation
        , SKU.MANUFACTURERSKU
        , ORDERS.LoadKey
        , WAVEDETAIL.WaveDetailKey
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN PICKDETAIL WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey)
   JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN LOC WITH (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc)
   JOIN SKU WITH (NOLOCK) ON (SKU.Sku = PICKDETAIL.Sku) AND (SKU.StorerKey = PICKDETAIL.Storerkey)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey
   GROUP BY PICKDETAIL.OrderKey
          , PICKDETAIL.Storerkey
          , PICKDETAIL.Sku
          , PICKDETAIL.Loc
          , PICKDETAIL.UOM
          , PICKDETAIL.ID
          , LOC.LogicalLocation
          , SKU.MANUFACTURERSKU
          , WAVEDETAIL.WaveDetailKey
          , ORDERS.LoadKey
   ORDER BY WAVEDETAIL.WaveDetailKey
          , PICKDETAIL.Loc
          , PICKDETAIL.ID
          , PICKDETAIL.Sku

   OPEN CUR_PICK

   FETCH NEXT FROM CUR_PICK
   INTO @c_Orderkey
      , @c_StorerKey
      , @c_sku
      , @c_loc
      , @c_UOM
      , @c_ID
      , @n_qty
      , @c_Logicalloc
      , @c_ManufacturerSKU
      , @c_Loadkey
      , @c_Wavedetailkey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order        
      IF EXISTS (  SELECT 1
                   FROM PICKHEADER (NOLOCK)
                   WHERE ExternOrderKey = @c_loadkey AND Zone = '3')
      BEGIN
         SET @c_firsttime = N'N'
         SET @c_PrintedFlag = N'Y'
      END
      ELSE
      BEGIN
         SET @c_firsttime = N'Y'
         SET @c_PrintedFlag = N'N'
      END -- Record Not Exists        

      IF @c_PreGenRptData = 'Y'
      BEGIN
         BEGIN TRAN
         -- Uses PickType as a Printed Flag        
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET PickType = '1'
           , TrafficCop = NULL
         WHERE ExternOrderKey = @c_loadkey AND Zone = '3' AND PickType = '0'

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
      END

      IF @c_Orderkey = ''
      BEGIN
         SET @c_Facility = N''
         SET @c_Externorderkey = N''
         SET @c_Consigneekey = N''
         SET @c_Company = N''
         SET @c_Addr1 = N''
         SET @c_Addr2 = N''
         SET @c_Addr3 = N''
         SET @c_PostCode = N''
         SET @c_Route = N''
         SET @c_Route_Desc = N''
         SET @c_BillToKey = N''
         SET @c_DeliveryNote = N''
         SET @c_labelPrice = N'N'
         SET @c_Notes1 = N''
         SET @c_Notes2 = N''
         SET @c_cdescr = N''
      END
      ELSE
      BEGIN
         SELECT @c_Facility = ORDERS.Facility
              , @c_Externorderkey = ORDERS.ExternOrderKey
              , @c_Consigneekey = ORDERS.ConsigneeKey
              , @c_Company = ORDERS.C_Company
              , @c_Addr1 = ORDERS.C_Address1
              , @c_Addr2 = ORDERS.C_Address2
              , @c_Addr3 = ORDERS.C_Address3
              , @c_PostCode = ORDERS.C_Zip
              , @c_BillToKey = ORDERS.BillToKey
              , @c_DeliveryNote = ORDERS.DeliveryNote
              , @d_DeliveryDate = ORDERS.DeliveryDate
              , @c_labelPrice = ISNULL(ORDERS.LabelPrice, 'N')
              , @c_Notes1 = CONVERT(NVARCHAR(60), ORDERS.Notes)
              , @c_Notes2 = CONVERT(NVARCHAR(60), ORDERS.Notes2)
              , @c_cdescr = ISNULL(CL.[Description], '')
         FROM ORDERS WITH (NOLOCK)
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  CL.LISTNAME = 'CVS_CONV'
                                             AND CL.Storerkey = ORDERS.StorerKey
                                             AND CL.UDF01 = LEFT(ORDERS.MarkforKey, 1)
         WHERE ORDERS.OrderKey = @c_Orderkey
      END -- IF @c_Orderkey = ''        

      SELECT @c_TrfRoom = ISNULL(LoadPlan.TrfRoom, '')
           , @c_Route = ISNULL(LoadPlan.Route, '')
           , @c_VehicleNo = ISNULL(LoadPlan.TruckSize, '')
           , @c_Carrierkey = ISNULL(LoadPlan.CarrierKey, '')
      FROM LoadPlan WITH (NOLOCK)
      WHERE LoadKey = @c_LoadKey

      SELECT @c_Route_Desc = ISNULL(RouteMaster.Descr, '')
      FROM RouteMaster WITH (NOLOCK)
      WHERE Route = @c_Route

      IF @c_Facility IS NULL
         SET @c_Facility = N''
      IF @c_Consigneekey IS NULL
         SET @c_Consigneekey = N''
      IF @c_Company IS NULL
         SET @c_Company = N''
      IF @c_Addr1 IS NULL
         SET @c_Addr1 = N''
      IF @c_Addr2 IS NULL
         SET @c_Addr2 = N''
      IF @c_Addr3 IS NULL
         SET @c_Addr3 = N''
      IF @c_PostCode IS NULL
         SET @c_PostCode = N''
      IF @c_BillToKey IS NULL
         SET @c_BillToKey = N''
      IF @c_Route IS NULL
         SET @c_Route = N''
      IF @c_Carrierkey IS NULL
         SET @c_Carrierkey = N''
      IF @c_Route_Desc IS NULL
         SET @c_Route_Desc = N''
      IF @c_DeliveryNote IS NULL
         SET @c_DeliveryNote = N''
      IF @c_Notes1 IS NULL
         SET @c_Notes1 = N''
      IF @c_Notes2 IS NULL
         SET @c_Notes2 = N''

      SET @c_PickheaderKey = N''

      SELECT @c_PickheaderKey = ISNULL(PickHeaderKey, '')
      FROM PICKHEADER (NOLOCK)
      WHERE ExternOrderKey = @c_loadkey AND OrderKey = @c_Orderkey AND Zone = '3'

      INSERT INTO #temp_pick (PickSlipNo, PrintedFlag, Facility, LoadKey, OrderKey, ExternOrderKey, Consigneekey
                            , Company, Addr1, Addr2, Addr3, PostCode, BillToKey, Route, Route_Desc, TrfRoom, Carrierkey
                            , VehicleNo, DeliveryNote, DeliveryDate, LabelPrice, Notes1, Notes2, LOC, SKU, SkuDesc, Qty
                            , ID, ManufacturerSKU, CDESCR, Wavedetailkey)
      VALUES (@c_PickheaderKey, @c_PrintedFlag, @c_Facility, @c_LoadKey, @c_Orderkey, @c_Externorderkey
            , @c_Consigneekey, @c_Company, @c_Addr1, @c_Addr2, @c_Addr3, @c_PostCode, @c_BillToKey, @c_Route
            , @c_Route_Desc, @c_TrfRoom, @c_Carrierkey, @c_VehicleNo, @c_DeliveryNote, @d_DeliveryDate, @c_labelPrice
            , @c_Notes1, @c_Notes2, @c_loc, @c_sku, @c_SkuDesc, @n_qty, @c_ID, @c_ManufacturerSKU, @c_cdescr
            , @c_Wavedetailkey)

      FETCH NEXT FROM CUR_PICK
      INTO @c_Orderkey
         , @c_StorerKey
         , @c_sku
         , @c_loc
         , @c_UOM
         , @c_ID
         , @n_qty
         , @c_Logicalloc
         , @c_ManufacturerSKU
         , @c_Loadkey
         , @c_Wavedetailkey
   END

   CLOSE CUR_PICK
   DEALLOCATE CUR_PICK

   SELECT @n_PS_required = COUNT(DISTINCT OrderKey)
   FROM #temp_pick
   WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''

   IF @n_PS_required > 0 AND @c_PreGenRptData = 'Y'
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP'
                        , 9
                        , @c_NextNo OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                        , 0
                        , @n_PS_required
      IF @b_success <> 1
         GOTO FAILURE

      SET @c_Orderkey = N''
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LoadKey
           , OrderKey
      FROM #temp_pick
      WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''
      GROUP BY LoadKey
             , OrderKey
             , Wavedetailkey
      ORDER BY Wavedetailkey

      OPEN CUR_PS

      FETCH NEXT FROM CUR_PS
      INTO @c_Loadkey
         , @c_Orderkey

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF @c_Orderkey IS NULL OR RTRIM(@c_Orderkey) = ''
         BEGIN
            BREAK
         END

         IF NOT EXISTS (  SELECT 1
                          FROM PICKHEADER (NOLOCK)
                          WHERE OrderKey = @c_Orderkey)
         BEGIN
            SET @c_PickheaderKey = N'P' + @c_NextNo
            SET @c_NextNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_NextNo) + 1), 9)

            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_PickheaderKey, @c_Orderkey, @c_LoadKey, '0', '3', '')

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

         FETCH NEXT FROM CUR_PS
         INTO @c_Loadkey
            , @c_Orderkey
      END -- WHILE        
      CLOSE CUR_PS
      DEALLOCATE CUR_PS

      UPDATE #temp_pick
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #temp_pick.LoadKey
      AND   PICKHEADER.OrderKey = #temp_pick.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   (#temp_pick.PickSlipNo IS NULL OR RTRIM(#temp_pick.PickSlipNo) = '')
   END
   GOTO SUCCESS

   FAILURE:
   IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL
      DROP TABLE #temp_pick

   SUCCESS:

   IF @c_PreGenRptData = 'Y'
   BEGIN
      DECLARE CUR_SCANIN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LoadKey
      FROM #temp_pick

      OPEN CUR_SCANIN

      FETCH NEXT FROM CUR_SCANIN
      INTO @c_Loadkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF (  SELECT COUNT(DISTINCT StorerKey)
               FROM ORDERS WITH (NOLOCK)
               JOIN LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
               WHERE LoadPlanDetail.LoadKey = @c_loadkey) = 1
         BEGIN
            -- Only 1 storer found        
            SET @c_StorerKey = N''

            SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey
            FROM ORDERS WITH (NOLOCK)
            JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
            WHERE LoadPlanDetail.LoadKey = @c_loadkey

            IF EXISTS (  SELECT 1
                         FROM StorerConfig WITH (NOLOCK)
                         WHERE ConfigKey = 'AUTOSCANIN' AND SValue = '1' AND StorerKey = @c_StorerKey)
            BEGIN
               -- Configkey is setup        
               DECLARE CUR_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickSlipNo
               FROM #temp_pick
               WHERE PickSlipNo IS NOT NULL OR RTRIM(PickSlipNo) <> ''
               ORDER BY OrderKey

               OPEN CUR_PI

               FETCH NEXT FROM CUR_PI
               INTO @c_PickSlipNo

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN

                  IF NOT EXISTS (  SELECT 1
                                   FROM PickingInfo WITH (NOLOCK)
                                   WHERE PickSlipNo = @c_PickSlipNo)
                  BEGIN
                     INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                     VALUES (@c_PickSlipNo, GETDATE(), SUSER_SNAME(), NULL)
                  END
                  FETCH NEXT FROM CUR_PI
                  INTO @c_PickSlipNo
               END
            END -- Configkey is setup        
            CLOSE CUR_PI
            DEALLOCATE CUR_PI
         END -- Only 1 storer found 

         FETCH NEXT FROM CUR_SCANIN
         INTO @c_Loadkey
      END
      CLOSE CUR_SCANIN
      DEALLOCATE CUR_SCANIN
   END

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      ;WITH CTE AS (
         SELECT PickSlipNo
              , PrintedFlag = CASE WHEN PrintedFlag = 'Y' THEN 'REPRINT' ELSE '' END
              , Facility
              , LoadKey
              , OrderKey
              , ExternOrderKey
              , Consigneekey
              , Company
              , Addr1
              , Addr2
              , Addr3
              , PostCode
              , BillToKey
              , Route
              , Route_Desc
              , TrfRoom
              , Carrierkey
              , VehicleNo
              , DeliveryNote
              , DeliveryDate
              , LabelPrice = CASE WHEN LabelPrice = 'Y' THEN 'Price Labelling Required' ELSE '' END
              , Notes1
              , Notes2
              , ManufacturerSKU
              , SKU
              , SkuDesc
              , Qty
              , LOC
              , ID
              , CDESCR
              , WaveOrder = Orderkey + ' / ' + @c_Wavekey
              , PageNo = (ROW_NUMBER() OVER (PARTITION BY Orderkey ORDER BY RowID, OrderKey, LOC, ID, SKU) - 1 ) / @n_MaxPerPage + 1
              , RowID
         FROM #temp_pick)
      SELECT PickSlipNo
           , PrintedFlag
           , Facility
           , LoadKey
           , OrderKey
           , ExternOrderKey
           , Consigneekey
           , Company
           , Addr1
           , Addr2
           , Addr3
           , PostCode
           , BillToKey
           , Route
           , Route_Desc
           , TrfRoom
           , Carrierkey
           , VehicleNo
           , DeliveryNote
           , DeliveryDate
           , LabelPrice
           , Notes1
           , Notes2
           , ManufacturerSKU
           , SKU
           , SkuDesc
           , Qty
           , LOC
           , ID
           , CDESCR
           , WaveOrder
           , SumPerPage = (SELECT SUM(C.Qty) FROM CTE C WHERE CTE.PageNo = C.PageNo AND CTE.OrderKey = C.OrderKey)
           , PageNo
           , Group1 = Orderkey + CAST(PageNo AS NVARCHAR)
      FROM CTE
      ORDER BY Rowid
             , OrderKey
             , LOC
             , ID
             , SKU
   END

   IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL
      DROP TABLE #temp_pick
 
   IF CURSOR_STATUS('LOCAL', 'CUR_SCANIN') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_SCANIN
      DEALLOCATE CUR_SCANIN
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PI') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_PI
      DEALLOCATE CUR_PI
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PS') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_PS
      DEALLOCATE CUR_PS
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PICK') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
   END

   QUIT_RESULT:
END

GO