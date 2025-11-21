SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_93_rdt                                 */
/* Creation Date: 12-Dec-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15848 - VF Packing List                                 */
/*        :                                                             */
/* Called By: r_dw_packing_list_93_rdt                                  */
/*          :                                                           */
/* GitLab Version: 1.5                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2021-01-28   WLChooi   1.1 Do not join Packdetail to get Qty, use    */
/*                            SUM(PICKDETAIL.Qty) instead (WL01)        */
/* 2021-10-26   Mingle    1.2 WMS-18229 Modify logic(ML01)              */
/* 2021-10-26   Mingle    1.2 DevOps Combine Script                     */
/* 2022-03-28   WLChooi   1.3 WMS-19347 - Use Codelkup to store Brand   */
/*                            - UserDefine01 (WL02)                     */
/* 2022-07-11   Mingle    1.4 WMS-20153 Add m_company(ML02)             */
/* 2022-12-01   WLChooi   1.5 WMS-21278 - Add Codelkup.Notes (WL03)     */
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_93_rdt]
   @c_Pickslipno NVARCHAR(15) --Could be Storerkey/Pickslipno/Orderkey  
 , @c_Orderkey   NVARCHAR(10) = '' --Could be Orderkey  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @b_Success   INT
         , @n_Err       INT
         , @c_Errmsg    NVARCHAR(255)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''

   IF ISNULL(@c_Orderkey, '') = ''
      SET @c_Orderkey = ''

   CREATE TABLE #TMP_Orders
   (
      Orderkey NVARCHAR(10)
   )

   IF EXISTS (  SELECT 1
                FROM PackHeader (NOLOCK)
                WHERE PickSlipNo = @c_Pickslipno AND @c_Pickslipno <> '')
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT OrderKey
      FROM PackHeader (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END
   ELSE IF EXISTS (  SELECT 1
                     FROM ORDERS (NOLOCK)
                     WHERE OrderKey = @c_Pickslipno AND @c_Pickslipno <> '')
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT @c_Pickslipno
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT OrderKey
      FROM ORDERS (NOLOCK)
      WHERE StorerKey = @c_Pickslipno AND Orderkey = @c_Orderkey
   END

   SELECT CASE WHEN OH.StorerKey = '18405' THEN ISNULL(OH.OrderKey, '')
               ELSE ISNULL(OH.ExternOrderKey, '')END AS Externorderkey --ML01  
        --ISNULL(OH.Externorderkey,'') AS Externorderkey  
        , ISNULL(OH.M_Company, '') AS M_Company --ML02  
        --, CASE WHEN OH.StorerKey = '18405' THEN ISNULL(OH.TrackingNo,'') ELSE ISNULL(OH.M_Company,'') END AS M_Company  --ML01  
        , ISNULL(OH.TrackingNo, '') --ML02  
        , LTRIM(RTRIM(ISNULL(OH.C_contact1, ''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Contact2, ''''))) AS C_Contact
        , LTRIM(RTRIM(ISNULL(OH.C_Address2, ''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address3, ''''))) + ' '
          + LTRIM(RTRIM(ISNULL(OH.C_Address4, ''''))) AS C_Addresses
        , OH.C_Phone1
        , ISNULL(OH.Salesman, '') AS Salesman
        , OH.ShipperKey
        , S.ALTSKU
        , PID.Loc
        , SUM(PID.Qty) AS Qty --WL01 Use PICKDETAIL.Qty Instead  
        , S.Sku
        , PH.PickSlipNo
        , OH.OrderKey
        , ISNULL(CL.Long, '') AS QRCode
        , OH.UserDefine01 --WL02  
        , TRIM(ISNULL(CL.Notes,'')) AS Notes   --WL03
   FROM ORDERS OH (NOLOCK)
   JOIN PackHeader PH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   --JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo                      --WL01  
   --JOIN PICKDETAIL PID (NOLOCK) ON PID.OrderKey = OH.OrderKey AND PID.SKU = PD.SKU   --WL01  
   JOIN PICKDETAIL PID (NOLOCK) ON PID.OrderKey = OH.OrderKey --WL01  
   JOIN SKU S (NOLOCK) ON S.Sku = PID.Sku AND S.StorerKey = OH.StorerKey
   JOIN #TMP_Orders t ON t.Orderkey = OH.OrderKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'TNFQRCode'
                                  AND CL.Code = OH.Salesman
                                  AND CL.Storerkey = OH.StorerKey
   --WL02 S  
   JOIN CODELKUP CL1 (NOLOCK) ON  CL1.LISTNAME = 'TNFBRAND'
                              AND CL1.Storerkey = OH.StorerKey
                              AND CL1.Code = OH.UserDefine01
                              AND CL1.Short = 'Y'
                              AND CL1.Long = 'r_dw_packing_list_93_rdt'
                              AND CL1.code2 = OH.DocType
   --WHERE OH.UserDefine01 = 'VC30'  
   --AND OH.DocType = 'E'  
   --WL02 E  
   --WL01 S  
   GROUP BY CASE WHEN OH.StorerKey = '18405' THEN ISNULL(OH.OrderKey, '')
                 ELSE ISNULL(OH.ExternOrderKey, '')END --ML01  
          --ISNULL(OH.Externorderkey,'')  
          , ISNULL(OH.M_Company, '') --ML02  
          --,CASE WHEN OH.StorerKey = '18405' THEN ISNULL(OH.TrackingNo,'') ELSE ISNULL(OH.M_Company,'') END  --ML01  
          , ISNULL(OH.TrackingNo, '') --ML02  
          , LTRIM(RTRIM(ISNULL(OH.C_contact1, ''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Contact2, '''')))
          , LTRIM(RTRIM(ISNULL(OH.C_Address2, ''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address3, ''''))) + ' '
            + LTRIM(RTRIM(ISNULL(OH.C_Address4, '''')))
          , OH.C_Phone1
          , ISNULL(OH.Salesman, '')
          , OH.ShipperKey
          , S.ALTSKU
          , PID.Loc
          , S.Sku
          , PH.PickSlipNo
          , OH.OrderKey
          , ISNULL(CL.Long, '')
          , OH.UserDefine01 --WL02  
          , TRIM(ISNULL(CL.Notes,''))   --WL03
   --WL01 E  

   QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_Orders') IS NOT NULL
      DROP TABLE #TMP_Orders
END -- procedure  

GO