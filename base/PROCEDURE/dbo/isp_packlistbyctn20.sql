SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PackListByCtn20                                     */  
/* Creation Date: 23-Feb-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-16333 - [CN] Pandora B2B Packing List label_CR          */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_by_ctn20                                */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[isp_PackListByCtn20]
            @c_Pickslipno         NVARCHAR(10),
            @c_StartCartonNo      NVARCHAR(10) = '',
            @c_EndCartonNo        NVARCHAR(10) = ''
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   IF ISNULL(@c_StartCartonNo,'') = '' SET @c_StartCartonNo = '1'
   IF ISNULL(@c_EndCartonNo  ,'') = '' SET @c_EndCartonNo   = '99999'

   SELECT ORDERS.OrderKey   
        , ORDERS.ExternOrderKey   
        , ORDERS.C_contact1   
        , ORDERS.C_Address1   
        , ORDERS.C_Phone1   
        , PackDetail.SKU 
        , PackDetail.CartonNo   
        , PackHeader.LoadKey
        , SUM(Packdetail.Qty) as PackQty
        , ORDERS.C_Company
        , PACK.PackUOM3
        , PackDetail.LabelNo
        , SKU.DESCR
        , SKU.Stdnetwgt 
        , SKU.Stdcube
        , ISNULL(CLR.short,'') AS short 
        , ISNULL(CLR1.Short,'N') AS grpbycarton
        , CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END AS ByCartonNo  
        , ISNULL(CLR2.Short,'N') AS hidewgtcube
        , ISNULL(CLR3.Short,'N') AS SUMQTYBYCARTON
        , ISNULL(CLR4.Short,'N') AS ShowPallet
        , ISNULL(CLR5.short,'N') AS showuserdefine01
        , ISNULL(ORDERS.USERDEFINE01,'') as userdefine01
   FROM ORDERS (NOLOCK)   
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = ORDERS.OrderKey
   JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )   
   JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo 
                             AND Packheader.Orderkey = Orders.Orderkey 
                             AND Packheader.Loadkey = LPD.Loadkey 
                             AND Packheader.Consigneekey = Orders.Consigneekey )
   JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'PGBREAKBYCARTON'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR1.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'HIDEWGTCUBE'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR2.Short,'') <> 'N') 
   LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR3.Storerkey AND CLR3.Code = 'SUMQTYBYCARTON'   
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR3.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR4 (NOLOCK) ON (Orders.Storerkey = CLR4.Storerkey AND CLR4.Code = 'ShowPallet'   
                                       AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR4.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR5 (NOLOCK) ON (Orders.Storerkey = CLR5.Storerkey AND CLR5.Code = 'showuserdefine01'   
                                       AND CLR5.Listname = 'REPORTCFG' AND CLR5.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR5.Short,'') <> 'N')
   WHERE ( RTRIM(PackHeader.OrderKey) IS NOT NULL AND RTRIM(PackHeader.OrderKey) <> '') and 
         ( Packheader.Pickslipno = @c_Pickslipno ) AND ( Packdetail.CartonNo BETWEEN CAST(@c_StartCartonNo AS INT) AND CAST(@c_EndCartonNo AS INT) )
   GROUP BY ORDERS.OrderKey   
          , ORDERS.ExternOrderKey   
          , ORDERS.C_contact1   
          , ORDERS.C_Address1   
          , ORDERS.C_Phone1   
          , PackDetail.SKU 
          , PackDetail.CartonNo   
          , PackHeader.LoadKey
          , ORDERS.C_Company 
          , PACK.PackUOM3
          , PackDetail.LabelNo
          , SKU.DESCR  
          , SKU.Stdnetwgt 
          , SKU.Stdcube
          , ISNULL(CLR.short,'')
          , ISNULL(CLR1.Short,'N')
          , ISNULL(CLR2.Short,'N') 
          , ISNULL(CLR3.Short,'N')
          , ISNULL(CLR4.Short,'N')
          , ISNULL(CLR5.short,'N')
          , ISNULL(ORDERS.USERDEFINE01,'')
   UNION ALL
   SELECT '' as OrderKey   
        , '' as ExternOrderKey   
        , MAX(ORDERS.C_contact1) as C_contact1   
        , MAX(ORDERS.C_Address1) as C_Address1   
        , MAX(ORDERS.C_Phone1) as C_Phone1   
        , PackDetail.SKU 
        , PackDetail.CartonNo   
        , PackHeader.LoadKey
        , CASE WHEN (ISNULL(CLR1.Short,'N') = 'Y' OR ISNULL(CLR3.SHORT,'N') = 'Y') THEN
             (SELECT SUM(P.Qty) FROM PACKDETAIL P(NOLOCK) WHERE P.Pickslipno = PACKHEADER.Pickslipno AND P.Cartonno = PACKDETAIL.CartonNo AND P.Sku = PACKDETAIL.Sku) 
          ELSE 
             (SELECT SUM(P.Qty) FROM PACKDETAIL P(NOLOCK) WHERE P.Pickslipno = PACKHEADER.Pickslipno AND P.Sku = PACKDETAIL.Sku)
          END AS PackQty
        , MAX(Orders.C_Company) as C_Company
        , PACK.PackUOM3
        , PackDetail.LabelNo
        , SKU.DESCR    
        , SKU.Stdnetwgt 
        , SKU.Stdcube
        , ISNULL(CLR.short,'') AS short  
        , ISNULL(CLR1.Short,'N') AS grpbycarton
        , CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END AS ByCartonNo
        , ISNULL(CLR2.Short,'N')  as hidewgtcube
        , ISNULL(CLR3.Short,'N') AS SUMQTYBYCARTON
        , ISNULL(CLR4.Short,'N') AS ShowPallet
        , ISNULL(CLR5.short,'N') AS showuserdefine01
        , ISNULL(ORDERS.USERDEFINE01,'') as userdefine01
   FROM PackDetail (NOLOCK)    
   JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo ) 
   JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey ) 
   JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )   
   JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey ) 
   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'PGBREAKBYCARTON'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR1.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'HIDEWGTCUBE'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR2.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR3.Storerkey AND CLR3.Code = 'SUMQTYBYCARTON'   
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR3.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR4 (NOLOCK) ON (Orders.Storerkey = CLR4.Storerkey AND CLR4.Code = 'ShowPallet'   
                                       AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR4.Short,'') <> 'N') 
   LEFT OUTER JOIN Codelkup CLR5 (NOLOCK) ON (Orders.Storerkey = CLR5.Storerkey AND CLR5.Code = 'showuserdefine01'   
                                       AND CLR5.Listname = 'REPORTCFG' AND CLR5.Long = 'r_dw_packing_list_by_ctn20' AND ISNULL(CLR5.Short,'') <> 'N') 
   WHERE   ( Packheader.Pickslipno = @c_Pickslipno ) AND ( Packdetail.CartonNo BETWEEN CAST(@c_StartCartonNo AS INT) AND CAST(@c_EndCartonNo AS INT) )
   AND ISNULL(Packheader.Orderkey,'') = '' --Conso
   AND ISNULL(Packheader.Loadkey,'') <> '' --Conso
   GROUP BY PackDetail.SKU
          , PackDetail.CartonNo 
          , PackHeader.LoadKey
          , PACK.PackUOM3
          , PackDetail.LabelNo
          , SKU.DESCR 
          , SKU.Stdnetwgt 
          , SKU.Stdcube
          , ISNULL(CLR.short,'') 
          , ISNULL(CLR1.Short,'N')
          , CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END
          , PACKHEADER.Pickslipno
          , ISNULL(CLR2.Short,'N') 
          , ISNULL(CLR3.Short,'N')  
          , ISNULL(CLR4.Short,'N')
          , ISNULL(CLR5.short,'N')
          , ISNULL(ORDERS.USERDEFINE01,'')

QUIT_SP:  

END -- procedure

GO