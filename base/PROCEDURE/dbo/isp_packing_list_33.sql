SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Packing_List_33                                */  
/* Creation Date: 23-Aug-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-20599 - Convert Query to SP                             */  
/*                                                                      */  
/* Called By: r_dw_packing_list_33                                      */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 23-Aug-2022  WLChooi   1.0   DevOps Combine Script                   */
/* 25-Aug-2022  WLChooi   1.1   WMS-20599 - Add Notes2 (WL01)           */
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_Packing_List_33]  
      @c_Pickslipno       NVARCHAR(10)
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue        INT,  
           @n_cnt             INT,  
           @n_starttcnt       INT,
           @c_Orderkey        NVARCHAR(10)

   SELECT @n_Continue = 1, @n_starttcnt = @@TRANCOUNT
   
   SELECT Facility      = 'DJ Main DC& EMP DC'   --ISNULL(RTRIM(FACILITY.Descr),'')
      ,STR_Company      = ISNULL(RTRIM(STORER.Company),'')
      ,ExternOrderkey   = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
      ,Loadkey          = ISNULL(RTRIM(ORDERS.Loadkey),'')
      ,ConsigneeKey     = ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
      ,C_Company        = ISNULL(RTRIM(ORDERS.C_Company),'')
      ,C_Address1       = ISNULL(RTRIM(ORDERS.C_Address1),'')
      ,C_Address2       = ISNULL(RTRIM(ORDERS.C_Address2),'')
      ,C_Address3       = ISNULL(RTRIM(ORDERS.C_Address3),'')
      ,C_Address4       = ISNULL(RTRIM(ORDERS.C_Address4),'')
      ,InterModalVehicle= ISNULL(RTRIM(ORDERS.InterModalVehicle),'')
      ,PickSlipNo       = ISNULL(PACKDETAIL.PickSlipNo,0)
      ,CartonNo         = ISNULL(PACKDETAIL.CartonNo,0)
      ,Sku              = ISNULL(RTRIM(PACKDETAIL.Sku),'')
      ,SkuDescr         = ISNULL(RTRIM(SKU.Descr),'')
      ,Qty              = ISNULL(SUM(PACKDETAIL.Qty),0)
      ,UnitPrice        = CASE WHEN RTRIM(ISNULL(ORDERS.Userdefine01,'')) = 'N' THEN 
                               0
                          ELSE 
                            (SELECT TOP 1 ISNULL(UnitPrice,0)
                             FROM ORDERDETAIL WITH (NOLOCK) 
                             WHERE ORDERDETAIL.Orderkey = ISNULL(RTRIM(ORDERS.Orderkey),'')
                             AND   ORDERDETAIL.Storerkey= ISNULL(RTRIM(PACKDETAIL.Storerkey),'')
                             AND   ORDERDETAIL.Sku      = ISNULL(RTRIM(PACKDETAIL.Sku),''))
                          END 
      ,Notes2_1           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),1,41) 
      ,Notes2_2           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),42,41) 
      ,Notes2_3           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),83,41) 
      ,Notes2_4           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),124,41) 
      ,Notes2_5           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),165,41) 
      ,sku_notes1         = ISNULL(SKU.notes1,'')
      ,AltSKU             = ISNULL(SKU.AltSKU,'')
      ,OrderKey           = ORDERS.OrderKey 
      ,BuyerPO            = ISNULL(RTRIM(ORDERS.BuyerPO),'')
      ,Notes2             = ISNULL(RTRIM(OD.Notes2), '')   --WL01
   FROM PACKHEADER WITH (NOLOCK)
   JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   JOIN FACILITY   WITH (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
   JOIN STORER     WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                 AND(PACKDETAIL.Sku = SKU.Sku)
   CROSS APPLY (SELECT TOP 1 ISNULL(O.Notes2,'') AS Notes2
                FROM ORDERDETAIL O WITH (NOLOCK)
                WHERE O.OrderKey = ORDERS.OrderKey) AS OD   --WL01
   WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno
   GROUP BY ISNULL(RTRIM(STORER.Company),'')
         ,  ISNULL(RTRIM(ORDERS.Orderkey),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.Loadkey),'')
         ,  ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,  ISNULL(RTRIM(ORDERS.InterModalVehicle),'')
         ,  ISNULL(PACKDETAIL.PickSlipNo,0)
         ,  ISNULL(PACKDETAIL.CartonNo,0)
         ,  ISNULL(RTRIM(PACKDETAIL.Storerkey),'')
         ,  ISNULL(RTRIM(PACKDETAIL.Sku),'')
         ,  ISNULL(RTRIM(SKU.Descr),'') 
         ,  ORDERS.Userdefine01 
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),1,41) 
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),42,41) 
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),83,41) 
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),124,41) 
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),165,41) 
         ,  ISNULL(SKU.notes1,'')
         ,  ISNULL(SKU.AltSKU,'')
         ,  ORDERS.OrderKey 
         ,  ISNULL(RTRIM(ORDERS.BuyerPO),'')
         ,  ISNULL(RTRIM(OD.Notes2), '')   --WL01
   ORDER BY ISNULL(PACKDETAIL.CartonNo,0)
         ,  ISNULL(RTRIM(PACKDETAIL.Sku),'')

QUIT_SP:     
END

GO