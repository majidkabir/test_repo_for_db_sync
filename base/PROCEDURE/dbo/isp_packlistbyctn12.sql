SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackListByCtn12                                     */
/* Creation Date: 11-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-6144 - [CN] Dickies_packing list_CR                    */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_ctn012                               */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListByCtn12]
              --@c_Storerkey         NVARCHAR(20),
			  @c_PickSlipNo        NVARCHAR(10),
			  @c_StartCartonNo     NVARCHAR(10) = '',
			  @c_EndCartonNo       NVARCHAR(10) = ''  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT
         
         , @n_PrintOrderAddresses   INT
		 , @c_Storerkey             NVARCHAR(20)
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1


   SET @c_Storerkey = ''

   SELECT @c_Storerkey = ORDERS.Storerkey
   FROM ORDERS (NOLOCK)      
   JOIN PackHeader (NOLOCK) ON ( Packheader.Orderkey = Orders.Orderkey 
										AND Packheader.Loadkey = Orders.Loadkey 
										AND Packheader.Consigneekey = Orders.Consigneekey )
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 

  	SELECT ORDERS.OrderKey as Orderkey,   
           orders.orderdate as orderdate,
           orders.deliverydate as deliverydate,
           ORDERS.ExternOrderKey as ExternOrderKey,   
           ORDERS.C_contact1 as C_contact1 ,   
           ORDERS.C_Address1 as C_Address1,   
           ORDERS.C_Phone1 as C_Phone1,   
           PackDetail.SKU as SKU, 
           PackDetail.CartonNo as CartonNo,   
           PackHeader.LoadKey as Loadkey,
           SUM(Packdetail.Qty) as PackQty ,
           ORDERS.C_Company as C_Company, 
           PACK.PackUOM3 as PackUOM3,
		   PackDetail.LabelNo as LabelNo,
		   SKU.DESCR as DESCR, 
           SKU.Stdnetwgt as Stdnetwgt, 
           SKU.Stdcube as Stdcube,
           SKU.ALTSKU as ALTSKU,
           ISNULL(CLR.short,'') AS short 
          ,ISNULL(CLR1.Short,'N') AS grpbycarton
          ,CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END AS ByCartonNo  
          ,ISNULL(CLR2.Short,'N') AS hidewgtcube
	      ,ISNULL(CLR3.Short,'N') AS SUMQTYBYCARTON
    FROM ORDERS (NOLOCK)   
    --JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )   
    JOIN PackHeader (NOLOCK) ON ( Packheader.Orderkey = Orders.Orderkey 
										AND Packheader.Loadkey = Orders.Loadkey 
										AND Packheader.Consigneekey = Orders.Consigneekey )
    JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo  )   
    JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
    JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'PGBREAKBYCARTON'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR1.Short,'') <> 'N')  
    LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'HIDEWGTCUBE'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR2.Short,'') <> 'N') 
	LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR3.Storerkey AND CLR3.Code = 'SUMQTYBYCARTON'   
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR3.Short,'') <> 'N')  
  WHERE ( RTRIM(PackHeader.OrderKey) IS NOT NULL AND RTRIM(PackHeader.OrderKey) <> '') 
   AND ORDERS.StorerKey = @c_Storerkey
	AND PACKHEADER.PickSlipNo = @c_PickSlipNo 
	AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int) 
GROUP BY ORDERS.OrderKey,   
         orders.orderdate,
         orders.deliverydate,
         ORDERS.ExternOrderKey,   
         ORDERS.C_contact1,   
         ORDERS.C_Address1,   
         ORDERS.C_Phone1,   
         PackDetail.SKU, 
         PackDetail.CartonNo,   
         PackHeader.LoadKey,
         ORDERS.C_Company, 
         PACK.PackUOM3,
		 PackDetail.LabelNo,
		 SKU.DESCR,  
         SKU.Stdnetwgt, 
         SKU.Stdcube,
         SKU.ALTSKU,
         ISNULL(CLR.short,'')
        ,ISNULL(CLR1.Short,'N')
        ,ISNULL(CLR2.Short,'N') 
		 ,ISNULL(CLR3.Short,'N')
   UNION ALL
  SELECT '' as OrderKey,   
         '' as ExternOrderKey,   
         '' as orderdate,
         '' as deliverydate,
         MAX(ORDERS.C_contact1) as C_contact1,   
         MAX(ORDERS.C_Address1) as C_Address1,   
         MAX(ORDERS.C_Phone1) as C_Phone1,   
         PackDetail.SKU as SKU , 
         PackDetail.CartonNo AS CartonNo,   
         PackHeader.LoadKey as Loadkey,
         CASE WHEN (ISNULL(CLR1.Short,'N') = 'Y' OR ISNULL(CLR3.SHORT,'N') = 'Y') THEN
        (SELECT SUM(P.Qty) FROM PACKDETAIL P(NOLOCK) WHERE P.Pickslipno = PACKHEADER.Pickslipno AND P.Cartonno = PACKDETAIL.CartonNo AND P.Sku = PACKDETAIL.Sku) 
        ELSE 
        (SELECT SUM(P.Qty) FROM PACKDETAIL P(NOLOCK) WHERE P.Pickslipno = PACKHEADER.Pickslipno AND P.Sku = PACKDETAIL.Sku)
         END AS PackQty, 
         MAX(Orders.C_Company) as C_Company, 
         PACK.PackUOM3 as PackUOM3,
	  	 PackDetail.LabelNo as LabelNo,
		 SKU.DESCR as DESCR,    
         SKU.Stdnetwgt as Stdnetwgt, 
         SKU.Stdcube as Stdcube,
         SKU.ALTSKU as ALTSKU,
         ISNULL(CLR.short,'') AS short  
         ,ISNULL(CLR1.Short,'N') AS grpbycarton
         ,CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END AS ByCartonNo
        ,ISNULL(CLR2.Short,'N')  as hidewgtcube
	    ,ISNULL(CLR3.Short,'N') AS SUMQTYBYCARTON
    FROM PackDetail (NOLOCK)    
    JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo ) 
    JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey ) 
    JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )   
    JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey ) 
    JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR.Short,'') <> 'N')  
    LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'PGBREAKBYCARTON'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR1.Short,'') <> 'N')  
    LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'HIDEWGTCUBE'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR2.Short,'') <> 'N')
	LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR3.Storerkey AND CLR3.Code = 'SUMQTYBYCARTON'   
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR3.Short,'') <> 'N')
    WHERE ORDERS.StorerKey = @c_Storerkey
	  	  AND PACKHEADER.PickSlipNo = @c_PickSlipNo 
		  AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int)
		  AND ISNULL(Packheader.Orderkey,'') = '' --Conso
		  AND ISNULL(Packheader.Loadkey,'') <> '' --Conso
	 GROUP BY PackDetail.SKU, 
	 PackDetail.CartonNo, 
	 PackHeader.LoadKey,
	 PACK.PackUOM3,
	 PackDetail.LabelNo,
	 SKU.DESCR, 
	 SKU.Stdnetwgt, 
	 SKU.Stdcube,
	 SKU.ALTSKU,
	 ISNULL(CLR.short,''), 
	 ISNULL(CLR1.Short,'N'),
	 CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END,
	 PACKHEADER.Pickslipno
	 ,ISNULL(CLR2.Short,'N') 
	  ,ISNULL(CLR3.Short,'N') 

QUIT_SP:
END -- procedure

GO