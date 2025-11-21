SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_WV_PLIST_WAVE_022_ECOM                          */
/* Creation Date: 03-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22367 - [TW] POI_PickSlip_Report_CR                     */
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

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_022_ECOM]
(@c_Wavekey NVARCHAR(10), @c_PreGenRptData NVARCHAR(10) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt     INT
         , @n_Continue      INT
         , @b_Success       INT
         , @n_Err           INT
         , @c_Errmsg        NVARCHAR(255)
         , @n_NoOfReqPSlip  INT
         , @c_Orderkey      NVARCHAR(10)
         , @c_PickSlipNo    NVARCHAR(10)
         , @c_PickHeaderKey NVARCHAR(10)
         , @c_Storerkey     NVARCHAR(15)
         , @c_AutoScanIn    NVARCHAR(10)
         , @c_Facility      NVARCHAR(5)
         , @c_Logo          NVARCHAR(50)
         , @n_MaxLine       INT
         , @n_CntRec        INT
         , @c_MaxPSlipno    NVARCHAR(10)
         , @n_LastPage      INT
         , @n_ReqLine       INT
         , @c_JCLONG        NVARCHAR(255)
         , @c_RNotes        NVARCHAR(255)
         , @c_ecomflag      NVARCHAR(50)
         , @n_MaxLineno     INT
         , @n_PrnQty        INT
         , @n_MaxId         INT
         , @n_MaxRec        INT
         , @n_CurrentRec    INT
         , @n_Page          INT
         , @n_getPageno     INT
         , @c_recgroup      INT
         , @c_Loadkey       NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''
   SET @c_Logo = N''
   SET @n_MaxLine = 9
   SET @n_CntRec = 1
   SET @n_LastPage = 0
   SET @n_ReqLine = 1
   SET @n_MaxLineno = 7
   SET @n_PrnQty = 1
   SET @n_MaxId = 1
   SET @n_MaxRec = 1
   SET @n_CurrentRec = 1
   SET @n_Page = 1
   SET @n_getPageno = 1
   SET @c_recgroup = 1
   SET @c_Facility = N''
   SET @c_PreGenRptData = IIF(@c_PreGenRptData = 'Y', 'Y', '')

   --Check ECOM orders  
   SELECT TOP 1 @c_ecomflag = TRIM(ISNULL(ORDERS.Type, ''))
              , @c_Facility = ORDERS.Facility
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey

   IF (@c_ecomflag <> 'ECOM')
      GOTO QUIT_RESULT

   CREATE TABLE #TMP_PCK_2
   (
      WaveKey NVARCHAR(10) NOT NULL
    , a1      INT
    , a2      INT
   )

   CREATE TABLE #TMP_PCK_1
   (
      RowID           INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Loadkey         NVARCHAR(10) NOT NULL
    , Orderkey        NVARCHAR(10) NOT NULL
    , PickSlipNo      NVARCHAR(10) NOT NULL
    , Storerkey       NVARCHAR(15) NOT NULL
    , Wavekey         NVARCHAR(10) NOT NULL
    , Wavedetailkey   NVARCHAR(10) NOT NULL
    , PLOC            NVARCHAR(10) NOT NULL
    , OrderLineNumber NVARCHAR(5)  NULL
   )

   CREATE TABLE #TMP_PCK_185
   (
      RowID                  INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , PickSlipNo             NVARCHAR(10)  NOT NULL
    , Contact1               NVARCHAR(45)  NULL
    , ODUDF03                NVARCHAR(80)  NULL
    , Loadkey                NVARCHAR(10)  NOT NULL
    , Orderkey               NVARCHAR(10)  NOT NULL
    , DelDate                DATETIME
    , SHIPPERKEY             NVARCHAR(20)  NULL
    , ExternOrderkey         NVARCHAR(50)  NULL
    , ExternOrderkey_BARCODE NVARCHAR(50)  NULL
    , Notes                  NVARCHAR(255) NULL
    , Loc                    NVARCHAR(20)  NULL
    , Storerkey              NVARCHAR(15)  NOT NULL
    , SKU                    NVARCHAR(20)  NULL
    , CUDF01                 NVARCHAR(255) NULL
    , CUDF02                 NVARCHAR(255) NULL
    , Qty                    INT
    , ODNotes2               NVARCHAR(255) NULL
    , Pageno                 INT
    , OIPlatform             NVARCHAR(40)
    , CarrierCharges         FLOAT
    , Wavedetailkey          NVARCHAR(10)  NULL
    , a1                     INT
    , a2                     INT
   )

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

   IF @c_PreGenRptData = 'Y'
   BEGIN
      BEGIN TRAN
      -- Uses PickType as a Printed Flag    
      UPDATE PICKHEADER WITH (ROWLOCK)
      SET PickType = '1'
        , EditWho = SUSER_NAME()
        , EditDate = GETDATE()
        , TrafficCop = NULL
      FROM PICKHEADER
      JOIN #TMP_PCK_1 ON (PICKHEADER.PickHeaderKey = #TMP_PCK_1.PickSlipNo)
      WHERE #TMP_PCK_1.PickSlipNo <> ''

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   SET @n_NoOfReqPSlip = 0

   SELECT @n_NoOfReqPSlip = COUNT(1)
   FROM #TMP_PCK_1
   WHERE PickSlipNo = ''

   IF @n_NoOfReqPSlip > 0 AND @c_PreGenRptData = 'Y'
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP'
                        , 9
                        , @c_PickSlipNo OUTPUT
                        , @b_Success OUTPUT
                        , @n_Err OUTPUT
                        , @c_Errmsg OUTPUT
                        , 0
                        , @n_NoOfReqPSlip

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loadkey
           , Orderkey
      FROM #TMP_PCK_1
      WHERE PickSlipNo = ''
      GROUP BY Loadkey
             , Orderkey
             , RowID
      ORDER BY RowID

      OPEN CUR_PSLIP

      FETCH NEXT FROM CUR_PSLIP
      INTO @c_Loadkey
         , @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         SET @c_PickHeaderKey = N'P' + @c_PickSlipNo

         BEGIN TRAN

         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         VALUES (@c_PickHeaderKey, @c_Orderkey, @c_Loadkey, '0', '3', NULL)

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         UPDATE #TMP_PCK_1
         SET PickSlipNo = @c_PickHeaderKey
         WHERE Loadkey = @c_Loadkey AND Orderkey = @c_Orderkey

         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END

         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1), 9)
         FETCH NEXT FROM CUR_PSLIP
         INTO @c_Loadkey
            , @c_Orderkey
      END
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF @c_PreGenRptData = 'Y'
   BEGIN
      DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickSlipNo
           , Orderkey
           , Storerkey
      FROM #TMP_PCK_1
      ORDER BY PickSlipNo

      OPEN CUR_PSNO

      FETCH NEXT FROM CUR_PSNO
      INTO @c_PickSlipNo
         , @c_Orderkey
         , @c_Storerkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_AutoScanIn = N'0'
         EXEC nspGetRight @c_Facility = @c_Facility
                        , @c_StorerKey = @c_Storerkey
                        , @c_sku = ''
                        , @c_ConfigKey = 'AutoScanIn'
                        , @b_Success = @b_Success OUTPUT
                        , @c_authority = @c_AutoScanIn OUTPUT
                        , @n_err = @n_Err OUTPUT
                        , @c_errmsg = @c_Errmsg OUTPUT

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         BEGIN TRAN
         IF @c_AutoScanIn = '1'
         BEGIN
            IF NOT EXISTS (  SELECT 1
                             FROM PickingInfo WITH (NOLOCK)
                             WHERE PickSlipNo = @c_PickSlipNo)
            BEGIN
               INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO QUIT_SP
               END
            END
         END

         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
         FETCH NEXT FROM CUR_PSNO
         INTO @c_PickSlipNo
            , @c_Orderkey
            , @c_Storerkey
      END
      CLOSE CUR_PSNO
      DEALLOCATE CUR_PSNO
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_PSLIP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      INSERT INTO #TMP_PCK_185 (PickSlipNo, Contact1, ODUDF03, Loadkey, Orderkey, DelDate, SHIPPERKEY, ExternOrderkey
                              , ExternOrderkey_BARCODE, Notes, Loc, Storerkey, SKU, CUDF01, CUDF02, Qty, ODNotes2, Pageno
                              , OIPlatform, CarrierCharges, Wavedetailkey, a1, a2)
      SELECT #TMP_PCK_1.PickSlipNo
           , Contact1 = ISNULL(RTRIM(ORDERS.C_contact1), '')
           , ODUDF03 = ISNULL(RTRIM(OD.UserDefine03), '')
           , #TMP_PCK_1.Loadkey
           , #TMP_PCK_1.Orderkey
           , OrdDate = ORDERS.DeliveryDate
           , SHIPPERKEY = ORDERS.ShipperKey
           , ExternOrderkey = ORDERS.ExternOrderKey
           , ExternOrderkey_BARCODE = '*' + ORDERS.ExternOrderKey + '*'
           , Notes = ISNULL(RTRIM(OD.Notes), '')
           , PICKDETAIL.Loc
           , PICKDETAIL.Storerkey
           , SKU = PICKDETAIL.Sku
           , CUDF01 = ISNULL(CL2.UDF01, '')
           , CUDF02 = ISNULL(CL2.UDF02, '')
           , Qty = ISNULL(SUM(PICKDETAIL.Qty), 0)
           , ODNotes2 = ISNULL(RTRIM(OD.Notes2), '')
           , pageno = 1
           , OIPlatform = ISNULL(CL1.UDF01, '')
           , CarrierCharges = OI.CarrierCharges
           , #TMP_PCK_1.Wavedetailkey
           , #TMP_PCK_2.a1
           , #TMP_PCK_2.a2
      FROM #TMP_PCK_1
      JOIN STORER WITH (NOLOCK) ON (#TMP_PCK_1.Storerkey = STORER.StorerKey)
      JOIN ORDERS WITH (NOLOCK) ON (#TMP_PCK_1.Orderkey = ORDERS.OrderKey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON  OD.OrderKey = ORDERS.OrderKey
                                        AND #TMP_PCK_1.OrderLineNumber = OD.OrderLineNumber
      JOIN PICKDETAIL WITH (NOLOCK) ON (   OD.OrderKey = PICKDETAIL.OrderKey
                                       AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber
                                       AND OD.Sku = PICKDETAIL.Sku)
      JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.StorerKey) AND (PICKDETAIL.Sku = SKU.Sku)
      LEFT JOIN OrderInfo OI WITH (NOLOCK) ON OI.OrderKey = ORDERS.OrderKey
      LEFT JOIN CODELKUP CL1 (NOLOCK) ON OI.Platform = CL1.Code AND OD.Lottable02 = CL1.code2
      LEFT JOIN CODELKUP CL2 (NOLOCK) ON  RTRIM(ORDERS.ShipperKey) = CL2.Code
                                      AND CL2.LISTNAME = 'ECDLMODE'
                                      AND CL2.Storerkey = ORDERS.StorerKey
                                      AND CL2.code2 = ''
      LEFT JOIN #TMP_PCK_2 (NOLOCK) ON #TMP_PCK_1.Wavekey = #TMP_PCK_2.WaveKey
      WHERE #TMP_PCK_1.PickSlipNo <> '' AND ORDERS.Type = 'ECOM'
      GROUP BY #TMP_PCK_1.PickSlipNo
             , ISNULL(RTRIM(ORDERS.C_contact1), '')
             , ISNULL(RTRIM(OD.UserDefine03), '')
             , #TMP_PCK_1.Orderkey
             , #TMP_PCK_1.Loadkey
             , ORDERS.DeliveryDate
             , ORDERS.ShipperKey
             , ORDERS.ExternOrderKey
             , ISNULL(RTRIM(OD.Notes), '')
             , PICKDETAIL.Loc
             , PICKDETAIL.Storerkey
             , PICKDETAIL.Sku
             , ISNULL(CL2.UDF01, '')
             , ISNULL(CL2.UDF02, '')
             , ISNULL(RTRIM(OD.Notes2), '')
             , OI.CarrierCharges
             , ISNULL(CL1.UDF01, '')
             , #TMP_PCK_1.RowID
             , #TMP_PCK_1.Wavedetailkey
             , #TMP_PCK_2.a1
             , #TMP_PCK_2.a2
      ORDER BY #TMP_PCK_1.RowID
             , PICKDETAIL.Loc
             , PICKDETAIL.Sku

      SELECT PickSlipNo
           , Contact1
           , ODUDF03
           , Loadkey
           , Orderkey
           , DelDate
           , SHIPPERKEY
           , ExternOrderkey
           , ExternOrderkey_BARCODE
           , Notes
           , Loc
           , Storerkey
           , SKU
           , CUDF01
           , CUDF02
           , Qty
           , ODNotes2
           , Pageno
           , OIPlatform
           , CarrierCharges
           , (  SELECT SUM(TP.Qty)
                FROM #TMP_PCK_185 TP (NOLOCK)
                WHERE TP.Orderkey = #TMP_PCK_185.Orderkey) AS SumQty
           , RecNo = (ROW_NUMBER() OVER (PARTITION BY Orderkey
                                         ORDER BY RowID
                                                , Loc
                                                , SKU))
           , Wavedetailkey
           , RowID = CASE WHEN a1 = a2 THEN 0
                          ELSE RowID END
      FROM #TMP_PCK_185
      ORDER BY RowID
             , Loc
             , SKU
   END
   QUIT_RESULT:
END

GO