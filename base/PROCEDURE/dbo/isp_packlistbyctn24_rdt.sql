SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListByCtn24_rdt                                 */
/* Creation Date: 17-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23426 - CN - ULWGQ NEW Packing List Datawindow CR       */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_ctn24_rdt                            */
/*          : Copy from isp_PackListBySku30_rdt                         */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 17-Aug-2023  WLChooi   1.0 DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_PackListByCtn24_rdt]
   @c_Pickslipno    NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT = 1

   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Pickslipno)  
   BEGIN  
      SELECT @c_Pickslipno = PickSlipNo  
      FROM PACKHEADER (NOLOCK)  
      WHERE OrderKey = @c_Pickslipno  
   END  
  
   SELECT TRIM(ISNULL(OH.M_Company, ''))  AS M_Company
        , TRIM(ISNULL(OH.Notes, '')) AS Notes
        , ISNULL(OH.UserDefine07, '') AS UserDefine07
        , TRIM(ISNULL(OH.UserDefine03, '')) AS UserDefine03
        , TRIM(ISNULL(OH.ExternOrderKey, '')) AS ExternOrderKey 
        , PD.CartonNo
        , TRIM(ISNULL(PD.Sku, '')) AS Sku  
        , TRIM(ISNULL(S.ALTSKU, '')) AS ALTSKU 
        , TRIM(ISNULL(S.Notes2, '')) AS Notes2   
        , SUM(PD.Qty) AS PackedQty  
        , OH.Facility AS Facility
        , (SELECT COUNT(DISTINCT PDET.CartonNo) FROM PACKDETAIL PDET (NOLOCK) WHERE PDET.PickSlipNo = PD.PickSlipNo) AS MaxCartonNo
        , PD.PickSlipNo
   FROM PACKHEADER PH (NOLOCK)  
   JOIN ORDERS OH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.StorerKey   
   WHERE PH.PickSlipNo = @c_Pickslipno  
   GROUP BY TRIM(ISNULL(OH.M_Company, ''))
          , TRIM(ISNULL(OH.Notes, ''))
          , ISNULL(OH.UserDefine07, '')
          , TRIM(ISNULL(OH.UserDefine03, ''))
          , TRIM(ISNULL(OH.ExternOrderKey, ''))
          , PD.CartonNo
          , TRIM(ISNULL(PD.Sku, ''))
          , TRIM(ISNULL(S.ALTSKU, ''))
          , TRIM(ISNULL(S.Notes2, ''))
          , PD.PickSlipNo
          , OH.Facility
   ORDER BY PD.CartonNo, TRIM(ISNULL(PD.Sku, ''))

   QUIT_SP:

END -- procedure

GO