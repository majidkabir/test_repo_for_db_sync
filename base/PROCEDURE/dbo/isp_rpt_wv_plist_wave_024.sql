SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_024                           */
/* Creation Date: 29-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: WZPang                                                    */
/*                                                                       */
/* Purpose: WMS-22417                                                    */
/*                                                                       */
/* Called By: RPT_WV_PLIST_WAVE_024                                      */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 09-May-2023 WZPang  1.0   DevOps Combine Script                       */
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_024]
(@c_Wavekey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickheaderKey  NVARCHAR(10)
         , @c_PickSlipNo     NVARCHAR(10)
         , @c_PrintedFlag    NVARCHAR(1)
         , @n_continue       INT
         , @c_errmsg         NVARCHAR(255)
         , @b_success        INT
         , @n_err            INT
         , @c_Facility       NVARCHAR(5)
         , @c_orderkey       NVARCHAR(10)
         , @c_Externorderkey NVARCHAR(50)
         , @c_Consigneekey   NVARCHAR(15)
         , @c_BillToKey      NVARCHAR(15)
         , @c_Company        NVARCHAR(45)
         , @c_Addr1          NVARCHAR(45)
         , @c_Addr2          NVARCHAR(45)
         , @c_Addr3          NVARCHAR(45)
         , @c_PostCode       NVARCHAR(15)
         , @c_Route          NVARCHAR(10)
         , @c_Route_Desc     NVARCHAR(60)
         , @c_TrfRoom        NVARCHAR(5)
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
         , @c_Loadkey        NVARCHAR(10)       --WZ01  
         , @c_multiflag       NVARCHAR(1)
         , @n_cnt             INT

   DECLARE @c_Style   NVARCHAR(20)
         , @c_Color   NVARCHAR(10)
         , @c_Size    NVARCHAR(5)
         , @c_Article NVARCHAR(70)

   DECLARE @n_PS_required INT
         , @c_NextNo      NVARCHAR(10)
         , @c_cdescr      NVARCHAR(120)

   SET @c_Style = N''
   SET @c_Color = N''
   SET @c_Size = N''
   SET @c_cdescr = N''

   CREATE TABLE #temp_pick
   (
      PickSlipNo     NVARCHAR(10) NULL
    , PrintedFlag    NVARCHAR(1)
    , Facility       NVARCHAR(5)
    , LoadKey        NVARCHAR(10)
    , OrderKey       NVARCHAR(10)
    , ExternOrderKey NVARCHAR(50)
    , Consigneekey   NVARCHAR(15)
    , Company        NVARCHAR(45)
    , Addr1          NVARCHAR(45)
    , Addr2          NVARCHAR(45)
    , Addr3          NVARCHAR(45)
    , PostCode       NVARCHAR(15)
    , BillToKey      NVARCHAR(15)
    , Route          NVARCHAR(10)
    , Route_Desc     NVARCHAR(60)
    , TrfRoom        NVARCHAR(5)
    , Carrierkey     NVARCHAR(60)
    , VehicleNo      NVARCHAR(10)
    , DeliveryNote   NVARCHAR(10)
    , DeliveryDate   DATETIME
    , LabelPrice     NVARCHAR(5)
    , Notes1         NVARCHAR(60)
    , Notes2         NVARCHAR(60)
    , Article        NVARCHAR(70)
    , SKU            NVARCHAR(20)
    , SkuDesc        NVARCHAR(60)
    , Qty            INT
    , LOC            NVARCHAR(10)
    , ID             NVARCHAR(18)
    , CDESCR         NVARCHAR(120)
    , LOGICALLOC     NVARCHAR(18)
    , Wavekey        NVARCHAR(10)
    , StorerKey         NVARCHAR(15)
   )
    DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.OrderKey
        , PICKDETAIL.Storerkey
        , PICKDETAIL.Sku
        , PICKDETAIL.Loc
        , PICKDETAIL.UOM
        , PICKDETAIL.ID
        , SUM(PICKDETAIL.Qty)
        , LOC.LogicalLocation
        , ORDERS.Loadkey
   FROM WAVEDETAIL WITH (NOLOCK)                                                                                                                  --WZ01
   JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)                                                                           --WZ01
   JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.Orderkey = ORDERS.Orderkey)                                                               --WZ01
   JOIN PICKDETAIL WITH (NOLOCK) ON (LoadPlanDetail.Orderkey = PICKDETAIL.Orderkey)    --AND (LoadPlanDetail.Loadkey = PICKDETAIL.ExternOrderkey) --WZ01
   JOIN LOC WITH (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc)                                                                                           --WZ01
   WHERE WAVEDETAIL.Wavekey = @c_Wavekey
   --FROM PICKDETAIL WITH (NOLOCK)                                                                                                                --WZ01
   --JOIN LoadPlanDetail WITH (NOLOCK) ON (PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey)                                                         --WZ01
   --JOIN LOC WITH (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc)                                                                                         --WZ01
   --WHERE LoadPlanDetail.LoadKey = @c_loadkey                                                                                                    --WZ01
   GROUP BY PICKDETAIL.OrderKey
          , PICKDETAIL.Storerkey
          , PICKDETAIL.Sku
          , PICKDETAIL.Loc
          , PICKDETAIL.UOM
          , PICKDETAIL.ID
          , LOC.LogicalLocation
          , ORDERS.Loadkey
   ORDER BY PICKDETAIL.OrderKey

  

   OPEN CUR_PICK


   FETCH NEXT FROM CUR_PICK
   INTO @c_orderkey
      , @c_StorerKey
      , @c_sku
      , @c_loc
      , @c_UOM
      , @c_ID
      , @n_qty
      , @c_Logicalloc
      , @c_loadkey


   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

   SET @n_continue = 1


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
   END

   BEGIN TRAN

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

  
      IF @c_orderkey = ''
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
         WHERE ORDERS.OrderKey = @c_orderkey
      END

      SELECT @c_TrfRoom = ISNULL(LoadPlan.TrfRoom, '')
           , @c_Route = ISNULL(LoadPlan.Route, '')
           , @c_VehicleNo = ISNULL(LoadPlan.TruckSize, '')
           , @c_Carrierkey = ISNULL(LoadPlan.CarrierKey, '')
      FROM LoadPlan WITH (NOLOCK)
      WHERE LoadKey = @c_loadkey

      SELECT @c_Route_Desc = ISNULL(RouteMaster.Descr, '')
      FROM RouteMaster WITH (NOLOCK)
      WHERE Route = @c_Route

      SELECT @c_SkuDesc = ISNULL(DESCR, '')
           , @c_Style = ISNULL(RTRIM(Style), '')
           , @c_Color = ISNULL(RTRIM(Color), '')
           , @c_Size = ISNULL(RTRIM(Size), '')
           , @c_sku = Sku
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey AND Sku = @c_sku


      DECLARE @c_Column NVARCHAR(100) = N''
            , @c_Result NVARCHAR(100) = N''
            , @c_SQL    NVARCHAR(MAX) = N''

      SELECT @c_Column = LTRIM(RTRIM(ISNULL(CL.UDF02, '')))
      FROM CODELKUP AS CL (NOLOCK)
      WHERE CL.LISTNAME = 'REPORTCFG'
      AND   CL.Code = 'Col01'
      AND   CL.Storerkey = @c_StorerKey
      AND   CL.Short = 'Y'
      AND   CL.Long = 'RPT_WV_PLIST_WAVE_024'

      IF ISNULL(@c_Column, '') <> ''
      BEGIN
         SET @c_SQL = N'SELECT @c_Result = ' + @c_Column
                      + N' FROM SKU (NOLOCK) WHERE SKU.Storerkey = @c_Storerkey AND SKU.SKU = @c_SKU '

         EXEC sp_executesql @c_SQL
                          , N'@c_Result NVARCHAR(100) OUTPUT, @c_Storerkey NVARCHAR(15), @c_SKU NVARCHAR(20) '
                          , @c_Result OUTPUT
                          , @c_StorerKey
                          , @c_sku

         SET @c_sku = @c_Result
      END


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
      WHERE ExternOrderKey = @c_loadkey AND OrderKey = @c_orderkey AND Zone = '3'

      SET @c_Article = @c_Style + N'-' + @c_Color + N'-' + @c_Size

      INSERT INTO #temp_pick (PickSlipNo, PrintedFlag, Facility, LoadKey, OrderKey, ExternOrderKey, Consigneekey
                            , Company, Addr1, Addr2, Addr3, PostCode, BillToKey, Route, Route_Desc, TrfRoom, Carrierkey
                            , VehicleNo, DeliveryNote, DeliveryDate, LabelPrice, Notes1, Notes2, LOC, SKU, SkuDesc, Qty
                            , ID, Article, CDESCR, LOGICALLOC, Wavekey, StorerKey)
      VALUES (@c_PickheaderKey, @c_PrintedFlag, @c_Facility, @c_loadkey, @c_orderkey, @c_Externorderkey
            , @c_Consigneekey, @c_Company, @c_Addr1, @c_Addr2, @c_Addr3, @c_PostCode, @c_BillToKey, @c_Route
            , @c_Route_Desc, @c_TrfRoom, @c_Carrierkey, @c_VehicleNo, @c_DeliveryNote, @d_DeliveryDate, @c_labelPrice
            , @c_Notes1, @c_Notes2, @c_loc, @c_sku, @c_SkuDesc, @n_qty, @c_ID, @c_Article, @c_cdescr, @c_Logicalloc, @c_Wavekey, @c_StorerKey)

      FETCH NEXT FROM CUR_PICK
      INTO @c_orderkey
         , @c_StorerKey
         , @c_sku
         , @c_loc
         , @c_UOM
         , @c_ID
         , @n_qty
         , @c_Logicalloc
         , @c_loadkey



   END

   CLOSE CUR_PICK
   DEALLOCATE CUR_PICK

   SELECT @n_PS_required = COUNT(DISTINCT OrderKey)
   FROM #temp_pick
   WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''

   IF @n_PS_required > 0
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


      SET @c_orderkey = N''
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM #temp_pick
      WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''
      ORDER BY OrderKey

      OPEN CUR_PS

      FETCH NEXT FROM CUR_PS
      INTO @c_orderkey

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF @c_orderkey IS NULL OR RTRIM(@c_orderkey) = ''
         BEGIN
            BREAK
         END

         IF NOT EXISTS (  SELECT 1
                          FROM PICKHEADER (NOLOCK)
                          WHERE OrderKey = @c_orderkey)
         BEGIN
            SET @c_PickheaderKey = N'P' + @c_NextNo
            SET @c_NextNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_NextNo) + 1), 9)

            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_PickheaderKey, @c_orderkey, @c_loadkey, '0', '3', '')

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
            END
         END

         FETCH NEXT FROM CUR_PS
         INTO @c_orderkey
      END
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
   DELETE FROM #temp_pick

   SUCCESS:
   IF (  SELECT COUNT(DISTINCT StorerKey)
         FROM ORDERS WITH (NOLOCK)
         JOIN LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
         WHERE LoadPlanDetail.LoadKey = @c_loadkey) = 1
   BEGIN

      SET @c_StorerKey = N''

      SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey
      FROM ORDERS WITH (NOLOCK)
      JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
      WHERE LoadPlanDetail.LoadKey = @c_loadkey

      IF EXISTS (  SELECT 1
                   FROM StorerConfig WITH (NOLOCK)
                   WHERE ConfigKey = 'AUTOSCANIN' AND SValue = '1' AND StorerKey = @c_StorerKey)
      BEGIN

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
      END
      CLOSE CUR_PI
      DEALLOCATE CUR_PI
   END
   SET @n_cnt = 1
   DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT distinct OrderKey
         FROM #temp_pick(NOLOCK)
         ORDER BY OrderKey

         OPEN CUR_Orderkey

         FETCH NEXT FROM CUR_Orderkey
         INTO @c_orderkey

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SELECT @n_cnt = COUNT(orderkey)
            FROM #temp_pick(NOLOCK)
            WHERE Orderkey = @c_orderkey
            IF @n_cnt >1
            BEGIN
               SET @c_multiflag = 'Y'
            END
            FETCH NEXT FROM CUR_Orderkey
            INTO @c_orderkey
         END
         
      CLOSE CUR_Orderkey
      DEALLOCATE CUR_Orderkey
   IF @c_multiflag = 'Y'
   BEGIN
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
        , Article
        , SKU
        , SkuDesc
        , Qty
        , LOC
        , ID
        , CDESCR
        , LOGICALLOC
        , Wavekey
        , StorerKey
   FROM #temp_pick
   ORDER BY OrderKey       --WZ01
          , LOC            --WZ01
          , LOGICALLOC     --WZ01
          , ID             --WZ01
          , Article        --WZ01
          , SKU            --WZ01
   END
   ELSE
   BEGIN
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
        , Article
        , SKU
        , SkuDesc
        , Qty
        , LOC
        , ID
        , CDESCR
        , LOGICALLOC
        , Wavekey
        , StorerKey
   FROM #temp_pick
   ORDER BY LOC       --WZ01
          , Orderkey            --WZ01
          , LOGICALLOC     --WZ01
          , ID             --WZ01
          , Article        --WZ01
          , SKU            --WZ01
   END
   IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL
      DROP TABLE #temp_pick
END

GO