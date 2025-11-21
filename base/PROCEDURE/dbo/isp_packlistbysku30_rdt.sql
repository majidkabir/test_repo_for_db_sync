SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_PackListBySku30_rdt                            */  
/* Creation Date: 16-Aug-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-20522 - UPD B2C Packing List                            */  
/*                                                                      */  
/* Called By: report dw = r_dw_packing_list_by_sku30_rdt                */  
/*                                                                      */  
/* GitLab Version: 1.3                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver.  Purposes                                 */  
/* 16-Aug-2022  WLChooi  1.0   DevOps Combine Script                    */
/* 29-MAR-2023  CSCHONG  1.1   WMS-21923 fix sorting issue (CS01)       */
/* 14-Sep-2023  WLChooi  1.2   WMS-23624 - Add new logic (WL01)         */
/* 09-Oct-2023  WLChooi  1.3   WMS-23624 - Change barcode mapping (WL02)*/
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_PackListBySku30_rdt] (  
      @c_Pickslipno NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey     NVARCHAR(10)
         , @n_continue     INT = 1
  
   SET @c_Orderkey = @c_Pickslipno  
  
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)  
   BEGIN  
      SELECT @c_Orderkey = OrderKey  
      FROM PACKHEADER (NOLOCK)  
      WHERE PickSlipNo = @c_Pickslipno  
   END  
  
   SELECT TRIM(ISNULL(OH.M_Company, '')) AS M_Company
        , TRIM(ISNULL(OH.Notes, '')) AS Notes
        , IIF(ISNULL(CL2.Short, 'N') = 'Y', OH.OrderDate, OH.UserDefine07) AS UserDefine07   --WL01
        , TRIM(ISNULL(OH.UserDefine03, '')) AS UserDefine03
        , IIF(ISNULL(CL2.Short, 'N') = 'Y', TRIM(ISNULL(OH.Orderkey, '')), TRIM(ISNULL(OH.ExternOrderKey, ''))) AS ExternOrderKey   --WL02
        , TRIM(ISNULL(OD.ExternLineNo, '')) AS ExternLineNo
        , TRIM(ISNULL(OD.Sku, '')) AS Sku
        , TRIM(ISNULL(S.ALTSKU, '')) AS ALTSKU
        , IIF(ISNULL(CL2.Short, 'N') = 'Y', TRIM(ISNULL(S.DESCR, '')), TRIM(ISNULL(S.NOTES2, ''))) AS Notes2
        , SUM(PD.Qty) AS PackedQty
        , OH.Facility AS Facility --WL01
        , IIF(ISNULL(CL1.Notes, '') = '', N'江苏省昆山市花桥镇新生路718号C1库C1-1门 UPD项目组', TRIM(CL1.Notes)) AS RetAddr   --WL01
        , HideMCompany = ISNULL(CL2.Short, 'N')   --WL01
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   JOIN SKU S (NOLOCK) ON S.Sku = OD.Sku AND S.StorerKey = OD.StorerKey
   JOIN PICKDETAIL PD (NOLOCK) ON  PD.OrderKey = OD.OrderKey
                               AND PD.OrderLineNumber = OD.OrderLineNumber
                               AND PD.Sku = OD.Sku
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'   --WL01 S
                                   AND CL1.Storerkey = OH.StorerKey
                                   AND CL1.Code = 'RETADDR' 
                                   AND CL1.Long = 'r_dw_packing_list_by_sku30_rdt'
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON  CL2.LISTNAME = 'REPORTCFG'
                                   AND CL2.Storerkey = OH.StorerKey
                                   AND CL2.Code = 'HideMCompany'
                                   AND CL2.Long = 'r_dw_packing_list_by_sku30_rdt'   --WL01 E
   WHERE OH.OrderKey = @c_Orderkey
   GROUP BY TRIM(ISNULL(OH.M_Company, ''))
          , TRIM(ISNULL(OH.Notes, ''))
          , IIF(ISNULL(CL2.Short, 'N') = 'Y', OH.OrderDate, OH.UserDefine07)   --WL01
          , TRIM(ISNULL(OH.UserDefine03, ''))
          , IIF(ISNULL(CL2.Short, 'N') = 'Y', TRIM(ISNULL(OH.Orderkey, '')), TRIM(ISNULL(OH.ExternOrderKey, '')))   --WL02
          , TRIM(ISNULL(OD.ExternLineNo, ''))
          , TRIM(ISNULL(OD.Sku, ''))
          , TRIM(ISNULL(S.ALTSKU, ''))
          , IIF(ISNULL(CL2.Short, 'N') = 'Y', TRIM(ISNULL(S.DESCR, '')), TRIM(ISNULL(S.NOTES2, '')))
          , OH.Facility --WL01
          , IIF(ISNULL(CL1.Notes, '') = '', N'江苏省昆山市花桥镇新生路718号C1库C1-1门 UPD项目组', TRIM(CL1.Notes))   --WL01
          , ISNULL(CL2.Short, 'N')   --WL01
   ORDER BY CAST(TRIM(ISNULL(OD.ExternLineNo, '')) AS INT), TRIM(ISNULL(OD.Sku, '')) --CS01
  
END  

GO