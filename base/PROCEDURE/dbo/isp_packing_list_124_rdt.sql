SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_Packing_List_124_rdt                           */  
/* Creation Date: 2022-05-10                                            */  
/* Copyright: LFL                                                       */  
/* Written by: Mingle             */  
/*                                                                      */  
/* Purpose: WMS-19578 [CN] Columbia_B2C_PackingList                     */  
/*                                                                      */  
/* Called By: r_dw_Packing_List_124_rdt                                 */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 2022-05-10   Mingle  1.0   Created.(Devops Combine Script)           */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_124_rdt] (  
   @c_Pickslipno     NVARCHAR(10)  
)  
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Pickslipno)  
   BEGIN  
    SELECT @c_Pickslipno = Pickheaderkey  
    FROM PICKHEADER (NOLOCK)  
    WHERE OrderKey = @c_Pickslipno  
   END  
  
   SELECT  OH.Orderkey  
        , OH.C_contact1  
--        , SUBSTRING(OH.M_Company, 1 ,  
--case when  CHARINDEX('|', OH.M_Company ) = 0 then LEN(OH.M_Company)   
--else CHARINDEX('|', OH.M_Company) -1 end)  
  , CASE WHEN CHARINDEX('|', OH.M_Company) = 0 THEN OH.M_Company ELSE LEFT(OH.M_Company, CHARINDEX('|', OH.M_Company)-1) END  
  --, SUBSTRING(OH.M_Company, 1 , CHARINDEX('|', OH.M_Company + '|' ) -1)  
        , OH.C_Phone1  
  , OH.C_Phone2    
        , OH.ShipperKey  
        , OH.C_Address1 + '' + OH.C_Address2 AS C_ADDRESSES  
        , PH.AddDate  
        , S.AltSKU  
        , SUM(PD.Qty)  
        , OD.SKU  
        , S.SUSR5  
        , OD.UnitPrice  
   FROM ORDERS OH (NOLOCK)  
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey  
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey  
   JOIN SKU S (NOLOCK) ON S.StorerKey = OH.StorerKey AND S.SKU = OD.SKU  
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND  
                               PD.Sku = OD.Sku  
   --JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
   WHERE PH.PickSlipNo = @c_Pickslipno  
   GROUP BY OH.Orderkey  
        , OH.C_contact1  
        , OH.M_Company  
        , OH.C_Phone1  
  , OH.C_Phone2    
        , OH.ShipperKey  
        , OH.C_Address1  
  , OH.C_Address2  
        , PH.AddDate  
        , S.AltSKU  
        --, PD.Qty  
        , OD.SKU  
        , S.SUSR5  
        , OD.UnitPrice  
  
END

GO