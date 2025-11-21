SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_PackListBySku24_rdt                            */  
/* Creation Date: 23-MARCH-2022                                         */  
/* Copyright: LFL                                                       */  
/* Written by: WZPANG                                                   */  
/*                                                                      */  
/* Purpose: WMS-19271 - [CN] NAOS PackingList                           */  
/*                                                                      */  
/* Called By: report dw = r_dw_packing_list_by_sku24_rdt                */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver.  Purposes                                 */  
/* 23-Mar-2022  WLChooi  1.0   DevOps Combine Script                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListBySku24_rdt] (  
   @c_Pickslipno NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey      NVARCHAR(10)  
         , @n_MaxLineno     INT = 25  
         , @n_CurrentRec    INT  
         , @n_MaxRec        INT  
         , @n_cartonno      INT  
  
   SET @c_Orderkey = @c_Pickslipno  
  
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)  
   BEGIN  
      SELECT @c_Orderkey = OrderKey  
      FROM PACKHEADER (NOLOCK)  
      WHERE PickSlipNo = @c_Pickslipno  
   END  
  
   SELECT ISNULL(St.B_contact1, '') AS B_Contact1 
        , ISNULL(St.B_contact2, '') AS B_Contact2
        , ISNULL(OH.M_Company, '')  AS M_Company
        , ISNULL(OH.Notes, '') AS Notes
        , ISNULL(OH.UserDefine03, '') AS UserDefine03
        , ISNULL(OH.UserDefine06, '') AS UserDefine06
        , OD.Sku  
        , SUM(PD.Qty) AS PackedQty  
        , OH.OrderKey AS Orderkey  
        , ISNULL(OD.Notes, '') AS Notes
        , ISNULL(OD.Notes2, '') AS Notes2   
        , ISNULL(OD.ExternLineNo, '') AS ExternLineNo  
        , ISNULL(OD.Userdefine01, '') AS Userdefine01  
        , ISNULL(OD.Userdefine02, '') AS Userdefine02  
        , ISNULL(F.Address1,'') AS FAddress1
        , OH.ExternOrderKey
   FROM ORDERS OH (NOLOCK)  
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey   
   JOIN SKU S (NOLOCK) ON S.SKU = OD.SKU AND S.StorerKey = OD.StorerKey  
   JOIN Storer ST(NOLOCK) ON ST.Storerkey = OH.Storerkey  
   JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility  
   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
                              AND PD.Sku = OD.Sku  
   WHERE OH.Orderkey = @c_Orderkey  
   GROUP BY ISNULL(St.B_contact1, '')
          , ISNULL(St.B_contact2, '')   
          , ISNULL(OH.M_Company, '') 
          , ISNULL(Oh.Notes, '') 
          , ISNULL(OH.UserDefine03, '')   
          , ISNULL(OH.UserDefine06, '') 
          , OD.Sku  
          , OH.OrderKey   
          , ISNULL(OD.Notes, '')  
          , ISNULL(OD.Notes2 , '')
          , ISNULL(OD.ExternLineNo, '')  
          , ISNULL(OD.Userdefine01, '')   
          , ISNULL(OD.Userdefine02, '')   
          , ISNULL(F.Address1,'')  
          , OH.ExternOrderKey
   ORDER BY ISNULL(OD.ExternLineNo, ''), OD.Sku
  
END  

GO