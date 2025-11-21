SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_PackListBySku19_rdt                                 */
/* Creation Date: 08-Mar-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16517 - [CN]Tapestry-Coach_B2B New Packing List         */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku19_rdt                            */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 23-MAR-2022 CSCHONG  1.0   Devops Scripts Combine                    */
/* 23-MAR-2022 CSCHONG  1.1   WMS-19224 add new field (CS01)            */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku19_rdt]
            @c_Storerkey      NVARCHAR(15),      --Could be Storerkey/Orderkey       (Storerkey + Pickslipno + LabelNoFrom + LabelNoTo / Storerkey + Orderkey / Orderkey / Pickslipno)
            @c_Pickslipno     NVARCHAR(15) = '', --Could be Pickslipno/Orderkey
            @c_CartonNoStart  NVARCHAR(20) = '', --Could be CartonNoStart
            @c_CartonNoEnd    NVARCHAR(20) = ''  --Could be CartonNoEnd
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt         INT
         , @n_Continue          INT
         , @n_Err               INT = 0
         , @c_ErrMsg            NVARCHAR(255) = ''
         , @b_success           INT = 1
         , @c_Externorderkeys   NVARCHAR(4000) = ''
         , @c_Consigneekey      NVARCHAR(15) = ''
         , @c_FromCartonNo      NVARCHAR(10) = ''
         , @c_ToCartonNo        NVARCHAR(10) = ''

   CREATE TABLE #TMP_Orders (
      Pickslipno   NVARCHAR(10)
   )

   --(Storerkey + Pickslipno + CartonNoStart + LabelNoTo)
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno AND @c_Pickslipno <> '')
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT @c_Pickslipno
   END
   ELSE IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Storerkey AND @c_Storerkey <> '')   --Pickslipno
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT @c_Storerkey

      SET @c_CartonNoStart = '1'
      SET @c_CartonNoEnd   = '99999'
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE Orderkey = @c_Storerkey AND @c_Storerkey <> '')   --(Orderkey)
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT TOP 1 Pickslipno
      FROM PACKHEADER (NOLOCK)
      WHERE Orderkey = @c_Storerkey

      SET @c_CartonNoStart = '1'
      SET @c_CartonNoEnd   = '99999'
   END
   ELSE   --(Storerkey + Orderkey)
   BEGIN
      INSERT INTO #TMP_Orders (Pickslipno)
      SELECT TOP 1 Pickslipno
      FROM PACKHEADER (NOLOCK)
      WHERE Orderkey = @c_Pickslipno

      SET @c_CartonNoStart = '1'
      SET @c_CartonNoEnd   = '99999'
   END

   --Header (Text)
   CREATE TABLE #TMP_Header (
      RowID    INT NOT NULL IDENTITY(1,1)
    , H01      NVARCHAR(255)
    , H02      NVARCHAR(255)
    , H03      NVARCHAR(255)
    , H04      NVARCHAR(255)
    , H05      NVARCHAR(255)
    , H06      NVARCHAR(255)
    , H07      NVARCHAR(255)
    , H08      NVARCHAR(255)
    , H09      NVARCHAR(255)
    , H10      NVARCHAR(255)
    , H11      NVARCHAR(255)
    , H12      NVARCHAR(255)
    , H13      NVARCHAR(255)
    , H14      NVARCHAR(255)
    , H15      NVARCHAR(255)
    , H16      NVARCHAR(255)
    , H17      NVARCHAR(255)
    , H18      NVARCHAR(255)
    , H19      NVARCHAR(255)
    , H20      NVARCHAR(255)
    , H21      NVARCHAR(255)        --CS01
   )

   INSERT INTO #TMP_Header
   (
      H01,
      H02,
      H03,
      H04,
      H05,
      H06,
      H07,
      H08,
      H09,
      H10,
      H11,
      H12,
      H13,
      H14,
      H15,
      H16,
      H17,
      H18,
      H19,
      H20,
      H21                 --CS01
   )
   VALUES
   (
      N'品牌:'
    , N'发出仓：'
    , N'接收仓：'
    , N'订单类型：'
    , N'出库库位：'
    , N'发货单号：'
    , N'货物类别：'
    , N'日期：'
    , N'箱号：'
    , N'SKU'
    , N'料号'
    , N'颜色'
    , N'尺码'
    , N'单位'
    , N'描述'
    , N'数量'
    , N'汇总：'
    , ''
    , ''
    , ''
    , N'PO单号:'    --CS01
   )

   SELECT PD.LabelNo
        , ISNULL(ST.B_Company,'') AS B_Company
        , ISNULL(F.Descr,'') AS FDescr
        , ISNULL(OH.UserDefine05,'') AS UserDefine05
        , ISNULL(OH.C_Company,'') AS C_Company
        , ISNULL((SELECT Short FROM CODELKUP (NOLOCK)
                  WHERE LISTNAME='TPYNOTETRF' AND Storerkey = OH.StorerKey
                  AND Code = LEFT(OH.Notes,1)),LEFT(OH.Notes,1)) + SUBSTRING(OH.Notes,2,LEN(OH.Notes)) AS OrdTyp
        , OH.UserDefine01
        , ISNULL(ST.Company,'') AS STCompany
        , OH.M_Company
        , ISNULL(CL1.UDF02,'') AS UDF02
        , CONVERT(NVARCHAR(10), GETDATE(), 111) AS TodayDate
        , PD.CartonNo
        , S.SKU
        , S.Style
        , S.Color
        , S.Size
        , P.PackUOM3
        , S.DESCR
        , SUM(PD.Qty) AS Qty
        , MAX(TH.H01) AS H01
        , MAX(TH.H02) AS H02
        , MAX(TH.H03) AS H03
        , MAX(TH.H04) AS H04
        , MAX(TH.H05) AS H05
        , MAX(TH.H06) AS H06
        , MAX(TH.H07) AS H07
        , MAX(TH.H08) AS H08
        , MAX(TH.H09) AS H09
        , MAX(TH.H10) AS H10
        , MAX(TH.H11) AS H11
        , MAX(TH.H12) AS H12
        , MAX(TH.H13) AS H13
        , MAX(TH.H14) AS H14
        , MAX(TH.H15) AS H15
        , MAX(TH.H16) AS H16
        , MAX(TH.H17) AS H17
        , MAX(TH.H18) AS H18
        , MAX(TH.H19) AS H19
        , MAX(TH.H20) AS H20
        , MAX(TH.H21) AS H21     --CS01
        , OH.xdockpokey          --CS01
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   JOIN SKU S (NOLOCK) ON PD.StorerKey = S.StorerKey AND PD.SKU = S.SKU
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
   JOIN Storer ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'TPYORDTYPE' AND CL1.Storerkey = OH.StorerKey
                                  AND CL1.Code = OH.UserDefine10
   JOIN #TMP_Header TH ON TH.RowID = 1
   JOIN #TMP_Orders TOS ON TOS.Pickslipno = PH.Pickslipno
   WHERE PD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd
   --WHERE PH.Pickslipno = @c_Pickslipno
   GROUP BY PD.LabelNo
          , ISNULL(ST.B_Company,'')
          , ISNULL(F.Descr,'')
          , ISNULL(OH.UserDefine05,'')
          , ISNULL(OH.C_Company,'')
          , OH.UserDefine01
          , ISNULL(ST.Company,'')
          , OH.M_Company
          , ISNULL(CL1.UDF02,'')
          , PD.CartonNo
          , S.SKU
          , S.Style
          , S.Color
          , S.Size
          , P.PackUOM3
          , S.DESCR
          , OH.StorerKey
          , OH.Notes
          , OH.xdockpokey          --CS01
   ORDER BY PD.CartonNo, S.SKU

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_Header') IS NOT NULL
      DROP TABLE #TMP_Header

   IF OBJECT_ID('tempdb..#TMP_Orders') IS NOT NULL
      DROP TABLE #TMP_Orders

   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
       execute nsp_logerror @n_err, @c_errmsg, "isp_PackListBySku19_rdt"
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_success = 1
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
       RETURN
    END
END -- procedure

GO