SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_Packing_List_127_rdt                                */  
/* Creation Date: 13-OCT-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose:  WMS-20975                                                  */  
/*        :                                                             */  
/* Called By: r_dw_Packing_List_127_rdt                                 */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 13-OCT-2022  Mingle    1.0 WMS-20975 DevOps Combine Script(Created)  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_127_rdt] (  
   @c_Pickslipno NVARCHAR(21) )  
  
AS  
BEGIN  
   SET NOCOUNT ON  
  -- SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   SELECT Facility      = ISNULL(RTRIM(FACILITY.Descr),'')  
  ,STR_Company   = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' THEN 'Lululemon ' + ISNULL(ORDERS.Notes,'')  
        ELSE ISNULL(RTRIM(STORER.Company),'') END  
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
  ,CartonNo         = CASE WHEN ISNULL(CLR.SHORT,'N') = 'Y' THEN (ISNULL(Orders.Buyerpo,0) + '-' + RIGHT('00' + ISNULL(PACKDETAIL.CartonNo,0) , 3))  
       ELSE RIGHT(ISNULL(PACKDETAIL.CartonNo,0) , 3) END  
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
    ,Short        = ISNULL(CLR.SHORT,'N')   
  ,ItemClass     = SKU.ItemClass  
  ,Style        = SKU.Style  
  ,Color        = SKU.Color  
  ,Size         = SKU.Size  
  ,CL.SHORT  
 FROM PACKHEADER WITH (NOLOCK)  
 JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)  
 JOIN FACILITY   WITH (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
 JOIN STORER     WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)  
 JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
 JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)  
           AND(PACKDETAIL.Sku = SKU.Sku)  
 LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'SHOWTITLE' AND CL.STORERKEY = ORDERS.Storerkey  
            AND CL.LONG = 'r_dw_packing_list_127')  
 LEFT JOIN CODELKUP CLR WITH (NOLOCK) ON (CLR.LISTNAME = 'REPORTCFG' AND CLR.CODE = 'HIDECOLUMNS' AND CLR.STORERKEY = ORDERS.Storerkey  
            AND CLR.LONG = 'r_dw_packing_list_127')        
 WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno  
 GROUP BY ISNULL(RTRIM(FACILITY.Descr),'')  
   ,  ISNULL(RTRIM(STORER.Company),'')  
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
   ,  ISNULL(Orders.Buyerpo,0)  
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
     , ISNULL(ORDERS.Notes,'')   
     , ISNULL(CL.SHORT,'N')    
     , ISNULL(CLR.SHORT,'N')   
   , SKU.ItemClass  
   , SKU.Style  
   , SKU.Color  
   , SKU.Size  
   ,CL.SHORT  
    ORDER BY ISNULL(PACKDETAIL.CartonNo,0)  
    ,  ISNULL(RTRIM(PACKDETAIL.Sku),'')  
  
  
END -- procedure  

GO