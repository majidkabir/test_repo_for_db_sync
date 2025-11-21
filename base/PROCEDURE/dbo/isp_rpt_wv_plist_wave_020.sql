SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_WV_PLIST_WAVE_020                               */
/* Creation Date: 02-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22363 - [TW] PEC & MLB_PickSlip_Report_CR               */
/*        :                                                             */
/* Called By: RPT_WV_PLIST_WAVE_020                                     */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 02-May-2023  WLChooi   1.0 DevOps Combine Script                     */
/* 27-Jun-2023  WLChooi   1.1 WMS-22363 - Use PreGenRptData (WL01)      */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_020]
(
   @c_Wavekey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''   --WL01
)
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
         , @c_RptLogo       NVARCHAR(255)
         , @c_QRCode        NVARCHAR(255)
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
   SET @n_MaxLineno = 8
   SET @n_PrnQty = 1
   SET @n_MaxId = 1
   SET @n_MaxRec = 1
   SET @n_CurrentRec = 1
   SET @n_Page = 1
   SET @n_getPageno = 1
   SET @c_recgroup = 1


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
    , RowID           INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , PLOC            NVARCHAR(10) NOT NULL
    , OrderLineNumber NVARCHAR(5)  NULL
   )

   CREATE TABLE #TMP_PICK
   (
      rowid         INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Orderkey      NVARCHAR(10)  NOT NULL
    , OrdDate       DATETIME
    , PickSlipNo    NVARCHAR(10)  NOT NULL
    , OIPlatform    NVARCHAR(40)
    , EditDate      DATETIME
    , Contact1      NVARCHAR(45)  NULL
    , SKU           NVARCHAR(30)  NULL
    , RetailSKU     NVARCHAR(20)  NULL
    , Notes         NVARCHAR(800) NULL
    , Qty           INT
    , CUDF01        NVARCHAR(255) NULL
    , RPTLOGO       NVARCHAR(255) NULL
    , EcomOrdID     NVARCHAR(45)  NULL
    , PLOC          NVARCHAR(10)  NULL
    , SDESCR        NVARCHAR(150) NULL
    , Notes2        NVARCHAR(800) NULL
    , ReferenceId   NVARCHAR(20)  NULL
    , SSIZE         NVARCHAR(10)  NULL
    , QRCode        NVARCHAR(250) NULL
    , Wavedetailkey NVARCHAR(10)  NULL
    , a1            INT
    , a2            INT
   )

   SELECT @c_PreGenRptData = IIF(ISNULL(@c_PreGenRptData,'') IN ('','0'),'',@c_PreGenRptData)   --WL01

   SET @c_Facility = N''
   SELECT @c_Facility = OH.Facility
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_Wavekey

   SELECT TOP 1 @c_RptLogo = ISNULL(CL2.Long, '')
              , @c_QRCode = ISNULL(CL2.UDF01, '')
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS ORD (NOLOCK) ON WD.OrderKey = ORD.OrderKey
   JOIN CODELKUP CL2 WITH (NOLOCK) ON  CL2.LISTNAME = 'RPTLogo'
                                   AND CL2.Storerkey = ORD.StorerKey
                                   AND CL2.Code = ORD.OrderGroup
   WHERE WD.WaveKey = @c_Wavekey

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
          , PID.Loc
          , OD.OrderLineNumber
   ORDER BY WAVEDETAIL.WaveDetailKey

   INSERT INTO #TMP_PCK_2 (WaveKey, a1, a2)
   SELECT Wavekey
        , COUNT(DISTINCT Wavedetailkey)
        , COUNT(Wavedetailkey)
   FROM #TMP_PCK_1 WITH (NOLOCK)
   GROUP BY Wavekey

   IF @c_PreGenRptData = 'Y'   --WL01
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

      SET @n_NoOfReqPSlip = 0

      SELECT @n_NoOfReqPSlip = COUNT(1)
      FROM #TMP_PCK_1
      WHERE PickSlipNo = ''

      IF @n_NoOfReqPSlip > 0
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
   END   --WL01

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

   INSERT INTO #TMP_PICK (Orderkey, OrdDate, PickSlipNo, OIPlatform, EditDate, Contact1, SKU, RetailSKU, Notes, Qty
                        , CUDF01, RPTLOGO, EcomOrdID, PLOC, SDESCR, Notes2, ReferenceId, SSIZE, QRCode, Wavedetailkey
                        , a1, a2)
   SELECT OS.OrderKey
        , OS.OrderDate
        , t.PickSlipNo
        , ISNULL(CL2.[UDF01], '')
        , OS.EditDate
        , OS.C_contact1
        , (SKU.Style + SKU.Color)
        , OD.UserDefine01
        , ISNULL(CL3.Notes, '')
        , SUM(PID.Qty)
        , ISNULL(CL1.UDF01, '')
        , ISNULL(@c_RptLogo, '')
        , OI.EcomOrderId
        , PID.Loc
        , ISNULL(OD.Notes, '')
        , ISNULL(CL4.Notes, '')
        , ISNULL(OI.ReferenceId, '')
        , SKU.Size
        , ISNULL(@c_QRCode, '') AS QRCode
        , t.Wavedetailkey
        , t2.a1
        , t2.a2
   FROM #TMP_PCK_1 t
   JOIN ORDERS OS (NOLOCK) ON t.Orderkey = OS.OrderKey
   LEFT JOIN OrderInfo OI (NOLOCK) ON OS.OrderKey = OI.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = t.Orderkey AND t.OrderLineNumber = OD.OrderLineNumber
   JOIN PICKDETAIL PID (NOLOCK) ON  PID.OrderKey = OD.OrderKey
                                AND PID.Sku = OD.Sku
                                AND PID.OrderLineNumber = OD.OrderLineNumber
   JOIN SKU (NOLOCK) ON OD.Sku = SKU.Sku AND OD.StorerKey = SKU.StorerKey
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON  OS.StorerKey = CL1.Storerkey
                                   AND CL1.LISTNAME = 'ECDLMODE'
                                   AND CL1.Code = OS.ShipperKey
                                   AND CL1.code2 = ''
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON  OS.StorerKey = CL2.Storerkey
                                   AND CL2.LISTNAME = 'PLATFORM'
                                   AND CL2.Code = OI.Platform
   LEFT JOIN CODELKUP CL3 (NOLOCK) ON  OS.StorerKey = CL3.Storerkey
                                   AND CL3.LISTNAME = 'REPORTCFG'
                                   AND CL3.Code = OI.Platform
                                   AND CL3.code2 = '01'
   LEFT JOIN CODELKUP CL4 (NOLOCK) ON  OS.StorerKey = CL4.Storerkey
                                   AND CL4.LISTNAME = 'REPORTCFG'
                                   AND CL4.Code = OI.Platform
                                   AND CL4.code2 = '02'
   LEFT JOIN #TMP_PCK_2 t2 (NOLOCK) ON t.Wavekey = t2.WaveKey
   WHERE t.Wavekey = @c_Wavekey
   GROUP BY OS.OrderKey
          , OS.OrderDate
          , t.PickSlipNo
          , ISNULL(CL2.[UDF01], '')
          , OS.EditDate
          , OS.C_contact1
          , (SKU.Style + SKU.Color)
          , OD.UserDefine01
          , ISNULL(CL3.Notes, '')
          , ISNULL(CL1.UDF01, '')
          , OI.EcomOrderId
          , PID.Loc
          , ISNULL(OD.Notes, '')
          , ISNULL(CL4.Notes, '')
          , ISNULL(OI.ReferenceId, '')
          , SKU.Size
          , t.RowID
          , t.Wavedetailkey
          , t2.a1
          , t2.a2
   ORDER BY t.RowID
          , PID.Loc

   IF @c_PreGenRptData = ''   --WL01
   BEGIN
      SELECT Orderkey
           , OrdDate
           , PickSlipNo
           , OIPlatform
           , EditDate
           , Contact1
           , SKU
           , RetailSKU
           , Notes
           , Qty
           , CUDF01
           , RPTLOGO
           , EcomOrdID
           , PLOC
           , SDESCR
           , Notes2
           , ReferenceId
           , SSIZE
           , QRCode
           , RecNo = (ROW_NUMBER() OVER (PARTITION BY Orderkey
                                         ORDER BY rowid
                                                , PLOC
                                                , SKU))
           , Wavedetailkey
           , RowID = CASE WHEN a1 = a2 THEN 0
                          ELSE rowid END
      FROM #TMP_PICK
      ORDER BY RowID
             , PLOC
             , SKU
   END   --WL01

   QUIT_RESULT:
END -- procedure   

GO