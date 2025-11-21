SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_WV_PLIST_WAVE_021_ECOM                          */
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

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_021_ECOM]
(@c_Wavekey NVARCHAR(10), @c_PreGenRptData NVARCHAR(10) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickheaderKey   NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PrintedFlag     NVARCHAR(1)
         , @n_continue        INT
         , @c_errmsg          NVARCHAR(255)
         , @b_success         INT
         , @n_err             INT
         , @c_Wavedetailkey   NVARCHAR(10)
         , @n_a1              INT
         , @n_a2              INT

         --ORDERS Table    
         , @c_orderkey        NVARCHAR(10)  = N''
         , @c_Externorderkey  NVARCHAR(30)  = N''
         , @d_DeliveryDate    DATETIME
         , @c_Contact1        NVARCHAR(30)  = N''
         , @c_Loadkey         NVARCHAR(10)

         --ORDERDETAIL Table  
         , @c_Notes           NVARCHAR(60)  = N''

         --OrderInfo Table           
         , @c_Platform        NVARCHAR(20)  = N''

         --Pickdetail Table  
         , @c_sku             NVARCHAR(20)  = N''
         , @c_loc             NVARCHAR(10)  = N''
         , @n_qty             INT           = 0

         --Sku Table  
         , @c_ManufacturerSKU NVARCHAR(20)  = N''

         --Codelkup  
         , @c_UDF02           NVARCHAR(60)  = N''
         , @c_StorerKey       NVARCHAR(15)  = N''
         , @c_UOM             NVARCHAR(10)  = N''
         , @c_ID              NVARCHAR(18)  = N''
         , @c_Logicalloc      NVARCHAR(18)  = N''
         , @c_firsttime       NVARCHAR(1)   = N''
         , @c_ECOMFlag        NVARCHAR(10)  = N''
         , @n_MaxRec          INT           = 1
         , @n_CurrentRec      INT           = 1
         , @n_MaxLineno       INT           = 10
         , @c_RptLogo         NVARCHAR(255) = N''
         , @c_H01             NVARCHAR(255) = N''
         , @c_H02             NVARCHAR(255) = N''
         , @c_D01             NVARCHAR(255) = N''
         , @c_D02             NVARCHAR(255) = N''
         , @c_D03             NVARCHAR(255) = N''
         , @c_D04             NVARCHAR(255) = N''
         , @c_D05             NVARCHAR(255) = N''
         , @c_D06             NVARCHAR(255) = N''
         , @c_D07             NVARCHAR(255) = N''
         , @c_D08             NVARCHAR(255) = N''
         , @c_D09             NVARCHAR(255) = N''
         , @c_D10             NVARCHAR(255) = N''
         , @c_D11             NVARCHAR(255) = N''
         , @c_D12             NVARCHAR(255) = N''
         , @c_D13             NVARCHAR(255) = N''
         , @c_D14             NVARCHAR(255) = N''
         , @c_QRCODE          NVARCHAR(255) = N''

   DECLARE @n_PS_required INT
         , @c_NextNo      NVARCHAR(10)

   CREATE TABLE #TMP_PCK_2
   (
      WaveKey NVARCHAR(10) NOT NULL
    , a1      INT
    , a2      INT
   )

   CREATE TABLE #TMP_PCK_1
   (
      Loadkey         NVARCHAR(10) NOT NULL
    , Orderkey        NVARCHAR(10) NOT NULL
    , PickSlipNo      NVARCHAR(10) NOT NULL
    , Storerkey       NVARCHAR(15) NOT NULL
    , Wavekey         NVARCHAR(10) NOT NULL
    , Wavedetailkey   NVARCHAR(10) NOT NULL
    , PLOC            NVARCHAR(10) NOT NULL
    , OrderLineNumber NVARCHAR(5)  NULL
   )

   CREATE TABLE #temp_pick
   (
      rowid           INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , OrderKey        NVARCHAR(10)
    , ExternOrderKey  NVARCHAR(50)
    , PickSlipNo      NVARCHAR(10) NULL
    , [Platform]      NVARCHAR(20)
    , DeliveryDate    DATETIME     NULL
    , C_Contact1      NVARCHAR(30)
    , Loc             NVARCHAR(10)
    , SKU             NVARCHAR(20)
    , ManufacturerSKU NVARCHAR(20)
    , Notes           NVARCHAR(60)
    , Qty             INT
    , UDF02           NVARCHAR(60)
    , PrintedFlag     NVARCHAR(1)
    , Loadkey         NVARCHAR(10)
    , Wavedetailkey   NVARCHAR(10)
    , a1              INT
    , a2              INT
   )

   SET @n_continue = 1
   SET @c_PreGenRptData = IIF(@c_PreGenRptData = 'Y', 'Y', '')

   SELECT TOP 1 @c_ECOMFlag = TRIM(ISNULL(ORDERS.Type, ''))
              , @c_StorerKey = ORDERS.StorerKey
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey

   IF (@c_ECOMFlag <> 'ECOM')
      GOTO QUIT_RESULT

   INSERT INTO #TMP_PCK_1 (Loadkey, Orderkey, PickSlipNo, Storerkey, Wavekey, Wavedetailkey, PLOC, OrderLineNumber)
   SELECT LoadPlanDetail.LoadKey
        , LoadPlanDetail.OrderKey
        , ISNULL(TRIM(PICKHEADER.PickHeaderKey), '')
        , ORDERS.StorerKey
        , WAVEDETAIL.WaveKey
        , WAVEDETAIL.WaveDetailKey
        , PID.Loc
        , OD.OrderLineNumber
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON  (LoadPlanDetail.LoadKey = PICKHEADER.ExternOrderKey)
                                      AND (LoadPlanDetail.OrderKey = PICKHEADER.OrderKey)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = ORDERS.OrderKey
   JOIN PICKDETAIL PID (NOLOCK) ON  PID.OrderKey = OD.OrderKey
                                AND PID.Sku = OD.Sku
                                AND PID.OrderLineNumber = OD.OrderLineNumber
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey
   GROUP BY LoadPlanDetail.LoadKey
          , LoadPlanDetail.OrderKey
          , ISNULL(TRIM(PICKHEADER.PickHeaderKey), '')
          , ORDERS.StorerKey
          , WAVEDETAIL.WaveKey
          , WAVEDETAIL.WaveDetailKey
          , WAVEDETAIL.WaveDetailKey
          , PID.Loc
          , OD.OrderLineNumber
   ORDER BY WAVEDETAIL.WaveDetailKey

   INSERT INTO #TMP_PCK_2 (WaveKey, a1, a2)
   SELECT Wavekey
        , COUNT(DISTINCT Wavedetailkey)
        , COUNT(Wavedetailkey)
   FROM #TMP_PCK_1 WITH (NOLOCK)
   GROUP BY Wavekey

   SELECT @c_RptLogo = CL2.Long
   FROM CODELKUP CL2 WITH (NOLOCK)
   WHERE CL2.LISTNAME = 'RPTLogo' AND CL2.Storerkey = @c_StorerKey AND CL2.Code = 'LVSPICK'

   SELECT @c_H01 = MAX(CASE WHEN CLR.code2 = 'H01' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_H02 = MAX(CASE WHEN CLR.code2 = 'H02' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D01 = MAX(CASE WHEN CLR.code2 = 'D01' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D02 = MAX(CASE WHEN CLR.code2 = 'D02' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D03 = MAX(CASE WHEN CLR.code2 = 'D03' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D04 = MAX(CASE WHEN CLR.code2 = 'D04' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D05 = MAX(CASE WHEN CLR.code2 = 'D05' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D06 = MAX(CASE WHEN CLR.code2 = 'D06' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D07 = MAX(CASE WHEN CLR.code2 = 'D07' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D08 = MAX(CASE WHEN CLR.code2 = 'D08' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D09 = MAX(CASE WHEN CLR.code2 = 'D09' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D10 = MAX(CASE WHEN CLR.code2 = 'D10' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D11 = MAX(CASE WHEN CLR.code2 = 'D11' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D12 = MAX(CASE WHEN CLR.code2 = 'D12' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D13 = MAX(CASE WHEN CLR.code2 = 'D13' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_D14 = MAX(CASE WHEN CLR.code2 = 'D14' THEN ISNULL(CLR.Notes, '')
                            ELSE '' END)
        , @c_QRCODE = MAX(CASE WHEN CLR.code2 = 'QRCODE' THEN ISNULL(CLR.Notes, '')
                               ELSE '' END)
   FROM CODELKUP CLR WITH (NOLOCK)
   WHERE CLR.LISTNAME = 'REPORTCFG' AND CLR.Storerkey = @c_StorerKey AND CLR.Code = 'ECOM'

   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.OrderKey
        , PICKDETAIL.Storerkey
        , PICKDETAIL.Sku
        , PICKDETAIL.Loc
        , PICKDETAIL.UOM
        , PICKDETAIL.ID
        , SUM(PICKDETAIL.Qty)
        , LOC.LogicalLocation
        , ORDERS.LoadKey
        , WAVEDETAIL.WaveDetailKey
        , T2.a1
        , T2.a2
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN PICKDETAIL WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey)
   JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN LOC WITH (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc)
   JOIN #TMP_PCK_2 (NOLOCK) T2 ON WAVEDETAIL.WaveKey = T2.WaveKey
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey
   GROUP BY PICKDETAIL.OrderKey
          , PICKDETAIL.Storerkey
          , PICKDETAIL.Sku
          , PICKDETAIL.Loc
          , PICKDETAIL.UOM
          , PICKDETAIL.ID
          , LOC.LogicalLocation
          , WAVEDETAIL.WaveDetailKey
          , ORDERS.LoadKey
          , T2.a1
          , T2.a2
   ORDER BY WAVEDETAIL.WaveDetailKey
          , PICKDETAIL.Loc
          , PICKDETAIL.ID
          , PICKDETAIL.Sku

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
      , @c_Loadkey
      , @c_Wavedetailkey
      , @n_a1
      , @n_a2

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order    
      IF EXISTS (  SELECT 1
                   FROM PICKHEADER (NOLOCK)
                   WHERE ExternOrderKey = @c_Loadkey AND Zone = '3')
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
         WHERE ExternOrderKey = @c_Loadkey AND Zone = '3' AND PickType = '0'

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

      IF @c_orderkey = ''
      BEGIN
         SET @c_Externorderkey = N''
         SET @c_Contact1 = N''
         SET @c_Notes = N''
         SET @c_Platform = N''
         SET @c_UDF02 = N''
      END
      ELSE
      BEGIN
         SELECT @c_Externorderkey = ORDERS.ExternOrderKey
              , @d_DeliveryDate = ORDERS.DeliveryDate
              , @c_Contact1 = ORDERS.C_contact1
              , @c_Platform = ISNULL(OrderInfo.[Platform], '')
              , @c_UDF02 = ISNULL(CL.UDF02, '')
         FROM ORDERS WITH (NOLOCK)
         JOIN OrderInfo WITH (NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  CL.Storerkey = ORDERS.StorerKey
                                             AND CL.LISTNAME = 'ECDLMODE'
                                             AND CL.Code = ORDERS.ShipperKey
         WHERE ORDERS.OrderKey = @c_orderkey
      END -- IF @c_OrderKey = ''    

      SELECT @c_ManufacturerSKU = ISNULL(SKU.MANUFACTURERSKU, '')
           , @c_sku = SKU.Sku
           , @c_Notes = ORDERDETAIL.Notes
      FROM SKU WITH (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.Sku = SKU.Sku AND SKU.StorerKey = ORDERDETAIL.StorerKey
      WHERE SKU.StorerKey = @c_StorerKey AND SKU.Sku = @c_sku AND ORDERDETAIL.OrderKey = @c_orderkey

      IF @c_Externorderkey IS NULL
         SET @c_Externorderkey = N''
      IF @c_Contact1 IS NULL
         SET @c_Contact1 = N''
      IF @c_Notes IS NULL
         SET @c_Notes = N''
      IF @c_Platform IS NULL
         SET @c_Platform = N''
      IF @c_UDF02 IS NULL
         SET @c_UDF02 = N''

      SET @c_PickheaderKey = N''

      SELECT @c_PickheaderKey = ISNULL(PickHeaderKey, '')
      FROM PICKHEADER (NOLOCK)
      WHERE ExternOrderKey = @c_Loadkey AND OrderKey = @c_orderkey AND Zone = '3'

      INSERT INTO #temp_pick (OrderKey, ExternOrderKey, PickSlipNo, [Platform], DeliveryDate, C_Contact1, Loc, SKU
                            , ManufacturerSKU, Notes, Qty, UDF02, PrintedFlag, Loadkey, Wavedetailkey, a1, a2)
      VALUES (@c_orderkey, @c_Externorderkey, @c_PickheaderKey, @c_Platform, @d_DeliveryDate, @c_Contact1, @c_loc
            , @c_sku, @c_ManufacturerSKU, @c_Notes, @n_qty, @c_UDF02, @c_PrintedFlag, @c_Loadkey, @c_Wavedetailkey
            , @n_a1, @n_a2)

      FETCH NEXT FROM CUR_PICK
      INTO @c_orderkey
         , @c_StorerKey
         , @c_sku
         , @c_loc
         , @c_UOM
         , @c_ID
         , @n_qty
         , @c_Logicalloc
         , @c_Loadkey
         , @c_Wavedetailkey
         , @n_a1
         , @n_a2
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


      SET @c_orderkey = N''
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loadkey
           , OrderKey
      FROM #temp_pick
      WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''
      GROUP BY Loadkey
             , OrderKey
             , Wavedetailkey
      ORDER BY Wavedetailkey

      OPEN CUR_PS

      FETCH NEXT FROM CUR_PS
      INTO @c_Loadkey
         , @c_orderkey

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
            VALUES (@c_PickheaderKey, @c_orderkey, @c_Loadkey, '0', '3', '')

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
            , @c_orderkey
      END -- WHILE    
      CLOSE CUR_PS
      DEALLOCATE CUR_PS

      UPDATE #temp_pick
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #temp_pick.Loadkey
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
      SELECT DISTINCT Loadkey
      FROM #temp_pick

      OPEN CUR_SCANIN

      FETCH NEXT FROM CUR_SCANIN
      INTO @c_Loadkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF (  SELECT COUNT(DISTINCT StorerKey)
               FROM ORDERS WITH (NOLOCK)
               JOIN LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
               WHERE LoadPlanDetail.LoadKey = @c_Loadkey) = 1
         BEGIN
            -- Only 1 storer found    
            SET @c_StorerKey = N''

            SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey
            FROM ORDERS WITH (NOLOCK)
            JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
            WHERE LoadPlanDetail.LoadKey = @c_Loadkey

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
               CLOSE CUR_PI
               DEALLOCATE CUR_PI
            END -- Configkey is setup    

         END -- Only 1 storer found   

         FETCH NEXT FROM CUR_SCANIN
         INTO @c_Loadkey
      END
      CLOSE CUR_SCANIN
      DEALLOCATE CUR_SCANIN
   END

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      SELECT OrderKey
           , ExternOrderKey
           , PickSlipNo
           , [Platform]
           , DeliveryDate
           , C_Contact1
           , Loc
           , SKU
           , ManufacturerSKU
           , Notes
           , Qty
           , UDF02
           , RptLogo = UPPER(@c_RptLogo)
           , PrintedFlag
           , Loadkey
           , H01 = @c_H01
           , H02 = @c_H02
           , D01 = @c_D01
           , D02 = @c_D02
           , D03 = @c_D03
           , D04 = @c_D04
           , D05 = @c_D05
           , D06 = @c_D06
           , D07 = @c_D07
           , D08 = @c_D08
           , D09 = @c_D09
           , D10 = @c_D10
           , D11 = @c_D11
           , D12 = @c_D12
           , D13 = @c_D13
           , D14 = @c_D14
           , QRCODE = @c_QRCODE
           , Group1 = OrderKey + ExternOrderKey + PickSlipNo + [Platform]
                      + CAST(ISNULL(DeliveryDate, '19000101') AS NVARCHAR) + C_Contact1 + UDF02
           , RecNo = (ROW_NUMBER() OVER (PARTITION BY OrderKey + ExternOrderKey + PickSlipNo + [Platform]
                                                      + CAST(ISNULL(DeliveryDate, '19000101') AS NVARCHAR) + C_Contact1
                                                      + UDF02
                                         ORDER BY rowid
                                                , OrderKey
                                                , Loc))
           , RowID = CASE WHEN a1 = a2 THEN 0
                          ELSE rowid END
      FROM #temp_pick
      ORDER BY RowID
             --, RowID    
             , Loc
             , OrderKey
   END

   IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL
      DROP TABLE #temp_pick
   IF OBJECT_ID('tempdb..#TMP_PCK_1') IS NOT NULL
      DROP TABLE #TMP_PCK_1
   IF OBJECT_ID('tempdb..#TMP_PCK_2') IS NOT NULL
      DROP TABLE #TMP_PCK_2

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

   QUIT_RESULT:
END

GO