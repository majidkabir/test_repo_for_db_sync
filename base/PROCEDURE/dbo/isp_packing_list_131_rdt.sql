SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_Packing_List_131_rdt                           */  
/* Creation Date: 2023-02-09                                            */  
/* Copyright: LFL                                                       */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose: WMS-21714 [CN] SWELLFUN_PackingList                         */  
/*                                                                      */  
/* Called By: r_dw_Packing_List_131_rdt                                 */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 2023-02-09   Mingle  1.0   Created.(Devops Combine Script)           */  
/************************************************************************/  
  
CREATE    PROC [dbo].[isp_Packing_List_131_rdt] (  
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
  
   SELECT DISTINCT
      OH.userdefine04, 
      OH.Externorderkey, 
      OH.orderkey, 
      OH.C_CONTACT1, 
      OH.C_PHONE1, 
      CONCAT(OH.C_STATE,OH.C_CITY,OH.C_ADDRESS1,OH.C_ADDRESS2) AS c_address, 
      OH.NOTES, 
      OH.B_CONTACT1, 
      CONCAT(OH.B_STATE,OH.B_CITY,OH.B_ADDRESS1,OH.B_ADDRESS2) AS b_address, 
      CURRENT_TIMESTAMP AS [time], 
      S.DESCR, 
      S.SKU, 
      PD.QTY,
      S.AltSKU,
      ST.Company,
      OH.B_Phone1
   FROM ORDERS OH (NOLOCK)  
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey  
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey  
   JOIN SKU S (NOLOCK) ON S.StorerKey = OH.StorerKey AND S.SKU = OD.SKU  
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND  
                               PD.Sku = OD.Sku  
   --JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   WHERE PH.PickSlipNo = @c_Pickslipno 
  
END

GO