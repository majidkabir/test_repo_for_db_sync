SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_112_rdt                                */
/* Creation Date: 01-SEP-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-17785 -[CN]Brembo_B2C_packing list_new                  */
/*        :                                                             */
/* Called By: r_dw_packing_list_112_rdt                                 */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 08-SEP-2021 CSHONG   1.1   WMs-17785 revised print logic (CS01)      */
/* 28-Feb-2023 WLChooi  1.2   WMS-21853 - Modify Logic (WL01)           */
/* 28-Feb-2023 WLChooi  1.2   DevOps Combine Script                     */
/* 30-Mar-2023 WLChooi  1.3   WMS-22126 - Modify Table Linkage (WL02)   */
/************************************************************************/
CREATE   PROC [dbo].[isp_packing_list_112_rdt]
   @c_PickSlipNo NVARCHAR(10)
 , @c_CallFrom   NVARCHAR(10) = 'PM'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @c_SkipPrn   NVARCHAR(5)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_SkipPrn = N'N'

   CREATE TABLE #TMP_PL112Orders
   (
      Orderkey NVARCHAR(10)
   )

   IF ISNULL(@c_CallFrom, '') = ''
   BEGIN
      SET @c_CallFrom = 'PM'
   END

   IF @c_CallFrom = 'PM'
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM PackHeader (NOLOCK)
                   WHERE PickSlipNo = @c_PickSlipNo AND @c_PickSlipNo <> '')
      BEGIN
         INSERT INTO #TMP_PL112Orders (Orderkey)
         SELECT PH.OrderKey
         FROM PackHeader PH WITH (NOLOCK)
         JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PH.OrderKey
         WHERE PH.PickSlipNo = @c_PickSlipNo AND OH.OpenQty = 1
      END
      ELSE IF EXISTS (  SELECT 1
                        FROM ORDERS (NOLOCK)
                        WHERE OrderKey = @c_PickSlipNo AND @c_PickSlipNo <> '')
      BEGIN
         INSERT INTO #TMP_PL112Orders (Orderkey)
         SELECT OH.OrderKey
         FROM ORDERS OH WITH (NOLOCK)
         WHERE OH.OrderKey = @c_PickSlipNo AND OH.OpenQty = 1
      END
   END
   ELSE
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM ORDERS (NOLOCK)
                   WHERE OrderKey = @c_PickSlipNo AND @c_PickSlipNo <> '')
      BEGIN

         INSERT INTO #TMP_PL112Orders (Orderkey)
         SELECT OH.OrderKey
         FROM ORDERS OH WITH (NOLOCK)
         WHERE OH.OrderKey = @c_PickSlipNo AND OH.OpenQty > 1

      END
      ELSE IF EXISTS (  SELECT 1
                        FROM ORDERS (NOLOCK)
                        WHERE LoadKey = @c_PickSlipNo AND @c_PickSlipNo <> '')
      BEGIN

         INSERT INTO #TMP_PL112Orders (Orderkey)
         SELECT OH.OrderKey
         FROM ORDERS OH WITH (NOLOCK)
         WHERE OH.LoadKey = @c_PickSlipNo AND OH.OpenQty > 1

      END
   END

   SELECT SortBy = ROW_NUMBER() OVER (ORDER BY OH.OrderKey
                                             , PD.Loc
                                             , OH.StorerKey
                                             , OH.OrderKey
                                             , ISNULL(RTRIM(OD.Sku), ''))
        , RowNo = ROW_NUMBER() OVER (PARTITION BY OH.OrderKey
                                     ORDER BY OH.OrderKey
                                            , PD.Loc
                                            , OH.StorerKey
                                            , OH.OrderKey
                                            , ISNULL(RTRIM(OD.Sku), ''))
        , PrintTime = GETDATE()
        , OH.StorerKey
        , ISNULL(PH.PickSlipNo, '') AS PickSlipNo
        , OH.LoadKey
        , OH.OrderKey
        , SBUSR2 = ISNULL(RTRIM(SKU.BUSR2), '') --30
        , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderKey), '')
        , C_Zip = ISNULL(RTRIM(OH.C_Zip), '')
        , C_Contact1 = ISNULL(RTRIM(OH.C_contact1), '') + ' '
        , C_Phone1 = ISNULL(RTRIM(OH.C_Phone1), '') + ' '
        , C_Address = ISNULL(RTRIM(OH.C_City), '') + ' ' + ISNULL(RTRIM(OH.C_State), '') + ' '
                      + ISNULL(RTRIM(OH.C_Address1), '')
        , sku = ISNULL(RTRIM(OD.Sku), '')
        , CLNotes = ISNULL(RTRIM(CL.Notes), '')
        , TBatchNo = ISNULL(RTRIM(PT.TaskBatchNo), '')
        , SkuDesr = ISNULL(RTRIM(SKU.DESCR), '')
        , Qty = ISNULL(SUM(PD.Qty), 0)
        , Loc = PD.Loc
        , TrackingNo = OH.TrackingNo
        , AddDate = CONVERT(NVARCHAR(10), OH.AddDate, 120)
        , PTDevPos = ISNULL(RTRIM(PT.DevicePosition), '')
        , MCompany = ISNULL(RTRIM(OH.M_Company), '')
        , Shipperkey = ISNULL(CL1.Long, '')
        , WAREHOUSE = ISNULL(CL2.Notes, '')
        , UserDefine03 = ISNULL(TRIM(OH.UserDefine03),'')   --WL01
        , ReportTitle = ISNULL(TRIM(CL3.Long), N'布 雷 博 天 猫 旗 舰 店')   --WL01
        , ReportLogo = ISNULL(TRIM(CL3.Notes), N'brembo_logo.bmp')   --WL01
   --FROM PACKHEADER PH WITH (NOLOCK)
   --JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey
   LEFT JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (   OD.OrderKey = PD.OrderKey
                                       AND OD.StorerKey = PD.Storerkey
                                       AND OD.Sku = PD.Sku
                                       AND OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN SKU SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey) AND (OD.Sku = SKU.Sku)
   LEFT JOIN PackTask PT WITH (NOLOCK) ON PT.Orderkey = OH.OrderKey
   LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'bremtrans' AND CL.Storerkey = OH.StorerKey
   LEFT JOIN dbo.CODELKUP CL1 WITH (NOLOCK) ON  CL1.LISTNAME = 'bremkdgs'
                                            AND CL1.Storerkey = OH.StorerKey
                                            AND CL1.Short = OH.ShipperKey
   LEFT JOIN dbo.CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'bremfaci' AND CL2.Storerkey = OH.StorerKey
   JOIN #TMP_PL112Orders t ON t.Orderkey = OH.OrderKey
   LEFT JOIN dbo.CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME = 'BremTitle' AND CL3.Storerkey = OH.StorerKey   --WL01
                                           AND CL3.Notes2 = OH.UserDefine03   --WL01   --WL02
   --  WHERE PH.PickSlipNo = @c_PickSlipNo
   GROUP BY ISNULL(PH.PickSlipNo, '')
          , OH.StorerKey
          , OH.LoadKey
          , OH.OrderKey
          , ISNULL(RTRIM(OH.UserDefine03), '')
          , ISNULL(RTRIM(OH.ExternOrderKey), '')
          , ISNULL(RTRIM(OH.C_Zip), '')
          , ISNULL(RTRIM(OH.C_contact1), '')
          , ISNULL(RTRIM(OH.C_Phone1), '')
          , ISNULL(RTRIM(OH.C_City), '')
          , ISNULL(RTRIM(OH.C_State), '')
          , ISNULL(RTRIM(OH.C_Address1), '')
          , ISNULL(RTRIM(CL.Notes), '')
          , ISNULL(RTRIM(PT.TaskBatchNo), '')
          , ISNULL(RTRIM(PT.DevicePosition), '')
          , ISNULL(RTRIM(OD.Sku), '')
          , ISNULL(RTRIM(SKU.DESCR), '')
          , ISNULL(RTRIM(SKU.BUSR2), '')
          , PD.Loc
          , OH.TrackingNo
          , CONVERT(NVARCHAR(10), OH.AddDate, 120)
          , ISNULL(RTRIM(OH.M_Company), '')
          , ISNULL(CL1.Long, '')
          , ISNULL(CL2.Notes, '')
          , ISNULL(TRIM(OH.UserDefine03),'')   --WL01
          , ISNULL(TRIM(CL3.Long), N'布 雷 博 天 猫 旗 舰 店')   --WL01
          , ISNULL(TRIM(CL3.Notes), N'brembo_logo.bmp')   --WL01
   ORDER BY OH.OrderKey
          , PD.Loc

   QUIT_SP:

   IF OBJECT_ID('tempdb..#TMP_PL112Orders') IS NOT NULL
      DROP TABLE #TMP_PL112Orders

END -- procedure

GO