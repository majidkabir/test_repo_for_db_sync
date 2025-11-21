SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTN_019                              */
/* Creation Date: 21-Nov-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: Adrash                                                   */
/*                                                                      */
/* Purpose: WMS-21195 - Migrate WMS report to Logi Report               */
/*                      r_dw_print_pickorder88_tw (TW)                  */
/*                                                                      */
/* Called By: RPT_LP_PLISTN_019                                         */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 21-Nov-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 26-May-2023  WLChooi  1.1  WMS-21195 - Fix Sorting (WL01)            */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PLISTN_019]
   @c_Loadkey       NVARCHAR(11)
 , @c_OrderkeyFrom  NVARCHAR(10) = ''
 , @c_OrderkeyTo    NVARCHAR(10) = ''
 , @c_PreGenRptData NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt      INT
         , @n_Continue       INT
         , @b_Success        INT
         , @n_Err            INT
         , @c_Errmsg         NVARCHAR(255)
         , @n_NoOfReqPSlip   INT
         , @c_Orderkey       NVARCHAR(10)
         , @c_PickSlipNo     NVARCHAR(10)
         , @c_PickHeaderKey  NVARCHAR(10)
         , @c_Storerkey      NVARCHAR(15)
         , @c_AutoScanIn     NVARCHAR(10)
         , @c_Facility       NVARCHAR(5)
         , @c_Logo           NVARCHAR(50)
         , @n_MaxLine        INT
         , @n_CntRec         INT
         , @c_MaxPSlipno     NVARCHAR(10)
         , @n_LastPage       INT
         , @n_ReqLine        INT
         , @c_JCLONG         NVARCHAR(255)
         , @c_RNotes         NVARCHAR(255)
         , @c_PSNo           NVARCHAR(20)
         , @c_loc            NVARCHAR(50)
         , @c_sku            NVARCHAR(50)
         , @n_rowid          INT
         , @c_MinOrderkey    NVARCHAR(10)
         , @c_MaxOrderkey    NVARCHAR(10)
         , @c_FooterTextBoxA NVARCHAR(150)
         , @c_FooterTextBoxB NVARCHAR(150)
         , @c_FooterTextBoxC NVARCHAR(150)
         , @c_FooterTextBoxD NVARCHAR(4000)
         , @n_MaxRec         INT
         , @n_CurrentRec     INT
         , @n_MaxLineno      INT
         , @c_HDR            NVARCHAR(1) = 'N'   --WL01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''
   SET @c_Logo = N''
   SET @n_MaxLine = 11
   SET @n_CntRec = 1
   SET @n_LastPage = 0
   SET @n_ReqLine = 1

   --WL01 S
   IF LEFT(ISNULL(@c_Loadkey,''), 1) = 'H'
   BEGIN
      SET @c_Loadkey = SUBSTRING(@c_Loadkey, 2, 10)
      SET @c_HDR = 'Y'
   END
   --WL01 E

   IF @c_OrderkeyFrom = NULL
      SET @c_OrderkeyFrom = ''
   IF @c_OrderkeyTo = NULL
      SET @c_OrderkeyTo = ''

   SELECT @c_MinOrderkey = MIN(OrderKey)
        , @c_MaxOrderkey = MAX(OrderKey)
   FROM LoadPlanDetail (NOLOCK)
   WHERE LoadKey = @c_Loadkey

   IF @c_PreGenRptData = '0'
      SET @c_PreGenRptData = ''

   CREATE TABLE #TMP_PCK
   (
      Loadkey    NVARCHAR(10)  NOT NULL
    , Orderkey   NVARCHAR(10)  NOT NULL
    , PickSlipNo NVARCHAR(10)  NOT NULL
    , Storerkey  NVARCHAR(15)  NOT NULL
    , logo       NVARCHAR(255) NULL
    , RNotes     NVARCHAR(255) NULL
   )

   CREATE TABLE #TMP_PCK88TW
   (
      rowid          INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , PickSlipNo     NVARCHAR(10)   NOT NULL
    , Contact1       NVARCHAR(45)   NULL
    , SYCOLORSZ      NVARCHAR(80)   NULL
    , Loadkey        NVARCHAR(10)   NOT NULL
    , Orderkey       NVARCHAR(10)   NOT NULL
    , OrdDate        DATETIME
    , EditDate       DATETIME
    , ExternOrderkey NVARCHAR(50)   NULL
    , Notes          NVARCHAR(255)  NULL
    , Loc            NVARCHAR(20)   NULL
    , Storerkey      NVARCHAR(15)   NOT NULL
    , SKU            NVARCHAR(20)   NULL
    , PFUDF01        NVARCHAR(255)  NULL
    , EMUDF01        NVARCHAR(255)  NULL
    , Qty            INT
    , JCLONG         NVARCHAR(255)  NULL
    , Pageno         INT
    , RptNotes       NVARCHAR(255)
    , RowNo          NVARCHAR(40)
    , FootertxtboxA  NVARCHAR(4000) NULL
    , FootertxtboxB  NVARCHAR(4000) NULL
    , FootertxtboxC  NVARCHAR(4000) NULL
    , FootertxtboxD  NVARCHAR(4000) NULL
   )

   CREATE TABLE #TMP_PCK88TW_Final
   (
      rowid          INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , PickSlipNo     NVARCHAR(10)   NOT NULL
    , Contact1       NVARCHAR(45)   NULL
    , SYCOLORSZ      NVARCHAR(80)   NULL
    , Loadkey        NVARCHAR(10)   NOT NULL
    , Orderkey       NVARCHAR(10)   NOT NULL
    , OrdDate        DATETIME
    , EditDate       DATETIME
    , ExternOrderkey NVARCHAR(50)   NULL
    , Notes          NVARCHAR(255)  NULL
    , Loc            NVARCHAR(20)   NULL
    , Storerkey      NVARCHAR(15)   NOT NULL
    , SKU            NVARCHAR(20)   NULL
    , PFUDF01        NVARCHAR(255)  NULL
    , EMUDF01        NVARCHAR(255)  NULL
    , Qty            INT
    , JCLONG         NVARCHAR(255)  NULL
    , Pageno         INT
    , RptNotes       NVARCHAR(255)
    , RowNo          NVARCHAR(40)
    , FootertxtboxA  NVARCHAR(4000) NULL
    , FootertxtboxB  NVARCHAR(4000) NULL
    , FootertxtboxC  NVARCHAR(4000) NULL
    , FootertxtboxD  NVARCHAR(4000) NULL
   )

   CREATE TABLE #UniquePSNO
   (
      rowid      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , PickslipNo NVARCHAR(10) NOT NULL
   )

   SET @c_Facility = N''
   SELECT @c_Facility = facility
   FROM LoadPlan WITH (NOLOCK)
   WHERE LoadKey = @c_Loadkey

   INSERT INTO #TMP_PCK (Loadkey, Orderkey, PickSlipNo, Storerkey, logo, RNotes)
   SELECT DISTINCT LoadPlanDetail.LoadKey
                 , LoadPlanDetail.OrderKey
                 , ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '')
                 , ORDERS.StorerKey
                 , ''
                 , ''
   FROM LoadPlanDetail WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON  (LoadPlanDetail.LoadKey = PICKHEADER.ExternOrderKey)
                                      AND (LoadPlanDetail.OrderKey = PICKHEADER.OrderKey)
   WHERE LoadPlanDetail.LoadKey = @c_Loadkey
   AND   LoadPlanDetail.OrderKey >= CASE WHEN @c_OrderkeyFrom = '' THEN @c_MinOrderkey
                                         ELSE @c_OrderkeyFrom END
   AND   LoadPlanDetail.OrderKey <= CASE WHEN @c_OrderkeyTo = '' THEN @c_MaxOrderkey
                                         ELSE @c_OrderkeyTo END
   GROUP BY LoadPlanDetail.LoadKey
          , LoadPlanDetail.OrderKey
          , ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '')
          , ORDERS.StorerKey

   IF @c_PreGenRptData = 'Y'
   BEGIN
      BEGIN TRAN

      UPDATE PICKHEADER WITH (ROWLOCK)
      SET PickType = '1'
        , EditWho = SUSER_NAME()
        , EditDate = GETDATE()
        , TrafficCop = NULL
      FROM PICKHEADER
      JOIN #TMP_PCK ON (PICKHEADER.PickHeaderKey = #TMP_PCK.PickSlipNo)
      WHERE #TMP_PCK.PickSlipNo <> ''

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
   FROM #TMP_PCK
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
      SELECT Orderkey
      FROM #TMP_PCK
      WHERE PickSlipNo = ''
      ORDER BY Orderkey

      OPEN CUR_PSLIP

      FETCH NEXT FROM CUR_PSLIP
      INTO @c_Orderkey

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

         UPDATE #TMP_PCK
         SET PickSlipNo = @c_PickHeaderKey
         WHERE Loadkey = @c_Loadkey AND Orderkey = @c_Orderkey

         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END

         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1), 9)
         
         FETCH NEXT FROM CUR_PSLIP
         INTO @c_Orderkey
      END
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickSlipNo
        , Orderkey
        , Storerkey
   FROM #TMP_PCK
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
      IF @c_AutoScanIn = '1' AND @c_PreGenRptData = 'Y'
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

      SET @c_Logo = N''
      SET @c_Logo = (  SELECT TOP 1 oh.OrderGroup
                       FROM ORDERS oh WITH (NOLOCK)
                       WHERE OrderKey = @c_Orderkey)


      SET @c_JCLONG = N''
      SELECT @c_JCLONG = C3.Long
      FROM CODELKUP C3 WITH (NOLOCK)
      WHERE C3.LISTNAME = 'RPTLogo' AND C3.Storerkey = @c_Storerkey AND C3.Code = @c_Logo

      SET @c_RNotes = N''


      SELECT @c_RNotes = ISNULL(CL.Notes, '')
      FROM ORDERS OH (NOLOCK)
      LEFT JOIN OrderInfo OI (NOLOCK) ON OI.OrderKey = OH.OrderKey
      LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                     AND CL.Storerkey = OH.StorerKey
                                     AND CL.Code = ISNULL(OI.[Platform], '')
                                     AND CL.Short = OH.OrderGroup
                                     AND CL.Long = 'RPT_LP_PLISTN_019'
      WHERE OH.OrderKey = @c_Orderkey

      UPDATE #TMP_PCK
      SET logo = @c_JCLONG
        , RNotes = @c_RNotes
      WHERE PickSlipNo = @c_PickSlipNo AND Orderkey = @c_Orderkey AND Storerkey = @c_Storerkey

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

   INSERT INTO #TMP_PCK88TW (PickSlipNo, Contact1, SYCOLORSZ, Loadkey, Orderkey, OrdDate, EditDate, ExternOrderkey
                           , Notes, Loc, Storerkey, SKU, PFUDF01, EMUDF01, Qty, JCLONG, Pageno, RptNotes, RowNo
                           , FootertxtboxA, FootertxtboxB, FootertxtboxC, FootertxtboxD)
   SELECT #TMP_PCK.PickSlipNo
        , Contact1 = ISNULL(RTRIM(ORDERS.C_contact1), '')
        , SYCOLORSZ = PICKDETAIL.Sku
        , #TMP_PCK.Loadkey
        , #TMP_PCK.Orderkey
        , OrdDate = ORDERS.OrderDate
        , EditDate = ORDERS.DeliveryDate
        , ExternOrderkey = ISNULL(RTRIM(OI.EcomOrderId), '')
        , Notes = ISNULL(RTRIM(OD.Notes), '')
        , PICKDETAIL.Loc
        , PICKDETAIL.Storerkey
        , SKU = TRIM(SKU.ALTSKU)
        , PFUDF01 = ISNULL(C1.UDF01, '')
        , EMUDF01 = ISNULL(C2.UDF01, '')
        , Qty = ISNULL(SUM(PICKDETAIL.Qty), 0)
        , JCLONG = ISNULL(#TMP_PCK.logo, '')
        , pageno = (ROW_NUMBER() OVER (PARTITION BY #TMP_PCK.PickSlipNo
                                       ORDER BY #TMP_PCK.PickSlipNo
                                              , #TMP_PCK.Orderkey
                                              , PICKDETAIL.Sku ASC)) / @n_MaxLine
        , RptNotes = ISNULL(#TMP_PCK.RNotes, '')
        , ROW_NUMBER() OVER (PARTITION BY #TMP_PCK.PickSlipNo
                             ORDER BY PICKDETAIL.Loc
                                    , PICKDETAIL.Sku) AS RowNo
        , FooterTextBoxA = ISNULL(C3.UDF01, '')
        , FooterTextBoxB = REPLACE(ISNULL(C3.Notes, ''), '$', '')
        , FooterTextBoxC = ISNULL(C3.UDF02, '')
        , FooterTextBoxD = REPLACE(ISNULL(C3.Notes2, ''), '$', SPACE(2))
   FROM #TMP_PCK
   JOIN STORER WITH (NOLOCK) ON (#TMP_PCK.Storerkey = STORER.StorerKey)
   JOIN ORDERS WITH (NOLOCK) ON (#TMP_PCK.Orderkey = ORDERS.OrderKey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORDERS.OrderKey
   JOIN PICKDETAIL WITH (NOLOCK) ON (   OD.OrderKey = PICKDETAIL.OrderKey
                                    AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber)
   JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.StorerKey) AND (PICKDETAIL.Sku = SKU.Sku)
   LEFT JOIN OrderInfo OI WITH (NOLOCK) ON OI.OrderKey = ORDERS.OrderKey
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME = 'PLATFORM'
                                       AND C1.Storerkey = ORDERS.StorerKey
                                       AND C1.Code = OI.Platform
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON  C2.LISTNAME = 'ECDLMODE'
                                       AND C2.Storerkey = ORDERS.StorerKey
                                       AND C2.Code = ORDERS.ShipperKey
   LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON  C3.LISTNAME = 'REPORTCFG'
                                       AND C3.Storerkey = ORDERS.StorerKey
                                       AND C3.Code = OI.Platform
                                       AND C3.Long = 'RPT_LP_PLISTN_019'
                                       AND C3.Short = ORDERS.OrderGroup
   WHERE #TMP_PCK.PickSlipNo <> ''
   GROUP BY #TMP_PCK.PickSlipNo
          , ISNULL(RTRIM(ORDERS.C_contact1), '')
          , SKU.ALTSKU
          , #TMP_PCK.Orderkey
          , #TMP_PCK.Loadkey
          , ORDERS.OrderDate
          , ORDERS.DeliveryDate
          , ISNULL(RTRIM(OI.EcomOrderId), '')
          , ISNULL(RTRIM(OD.Notes), '')
          , PICKDETAIL.Loc
          , PICKDETAIL.Storerkey
          , PICKDETAIL.Sku
          , ISNULL(C1.UDF01, '')
          , ISNULL(C2.UDF01, '')
          , ISNULL(#TMP_PCK.logo, '')
          , ISNULL(#TMP_PCK.RNotes, '')
          , ISNULL(C3.UDF01, '')
          , REPLACE(ISNULL(C3.Notes, ''), '$', '')
          , ISNULL(C3.UDF02, '')
          , REPLACE(ISNULL(C3.Notes2, ''), '$', SPACE(2))
   ORDER BY #TMP_PCK.PickSlipNo
          , PICKDETAIL.Sku

   SELECT @c_MaxPSlipno = MAX(PickSlipNo)
        , @n_CntRec = COUNT(1)
        , @n_LastPage = MAX(tp.Pageno)
   FROM #TMP_PCK88TW AS tp
   GROUP BY tp.PickSlipNo

   DECLARE CUR_sort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickSlipNo
        , Loc
        , SKU
   FROM #TMP_PCK88TW
   WHERE RowNo = 1
   ORDER BY Loc
          , PickSlipNo
          , SKU DESC
   OPEN CUR_sort

   FETCH NEXT FROM CUR_sort
   INTO @c_PSNo
      , @c_loc
      , @c_sku
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      INSERT INTO #UniquePSNO (PickslipNo)
      SELECT @c_PSNo

      FETCH NEXT FROM CUR_sort
      INTO @c_PSNo
         , @c_loc
         , @c_sku
   END
   CLOSE CUR_sort
   DEALLOCATE CUR_sort

   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT rowid
                 , PickslipNo
   FROM #UniquePSNO
   ORDER BY rowid
   OPEN CUR_PSNO

   FETCH NEXT FROM CUR_PSNO
   INTO @n_rowid
      , @c_PSNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      INSERT INTO #TMP_PCK88TW_Final (PickSlipNo, Contact1, SYCOLORSZ, Loadkey, Orderkey, OrdDate, EditDate
                                    , ExternOrderkey, Notes, Loc, Storerkey, SKU, PFUDF01, EMUDF01, Qty, JCLONG, Pageno
                                    , RptNotes, RowNo, FootertxtboxA, FootertxtboxB, FootertxtboxC, FootertxtboxD)
      SELECT PickSlipNo
           , Contact1
           , SYCOLORSZ
           , Loadkey
           , Orderkey
           , OrdDate
           , EditDate
           , ExternOrderkey
           , Notes
           , Loc
           , Storerkey
           , SKU
           , PFUDF01
           , EMUDF01
           , Qty
           , JCLONG
           , Pageno
           , RptNotes
           , RowNo
           , FootertxtboxA
           , FootertxtboxB
           , FootertxtboxC
           , FootertxtboxD
      FROM #TMP_PCK88TW
      WHERE PickSlipNo NOT IN (  SELECT DISTINCT PickSlipNo
                                 FROM #TMP_PCK88TW_Final ) AND PickSlipNo = @c_PSNo
      ORDER BY Loc
             , SYCOLORSZ   --SKU   --WL01

      FETCH NEXT FROM CUR_PSNO
      INTO @n_rowid
         , @c_PSNo
   END
   CLOSE CUR_PSNO
   DEALLOCATE CUR_PSNO

   --WL01 S
   IF @c_HDR = 'Y'
   BEGIN
      SELECT @c_Loadkey AS Loadkey, 
             (SELECT TOP 1 Orderkey FROM #TMP_PCK88TW_Final WHERE Pickslipno = T.Pickslipno) AS Orderkey
      FROM #UniquePSNO T
      ORDER BY T.rowid
      
      GOTO EXIT_SP
   END
   --WL01 E

   IF ISNULL(@c_PreGenRptData, '') = ''
   BEGIN
      SELECT *
      FROM #TMP_PCK88TW_Final AS tp
      ORDER BY tp.rowid   --PickSlipNo       --WL01
             --, CASE WHEN SKU = '' THEN 2   --WL01
             --       ELSE 1 END             --WL01
             --, tp.Pageno                   --WL01
   END

   EXIT_SP:
END

GO