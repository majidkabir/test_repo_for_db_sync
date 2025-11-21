SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PackListByCtn21                                     */  
/* Creation Date: 06-MAY-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-16937 - CN NAOS B2B PackList By Carton CR               */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_by_ctn21                                */  
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
CREATE PROC [dbo].[isp_PackListByCtn21]
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

   
   SELECT PACKHEADER.PickSlipNo,
         PICKINGINFO.ScanOutDate,
         STORER.Company,
         ORDERS.OrderKey,   
         ORDERS.ExternOrderKey, 
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Consigneekey IS NOT NULL THEN
            CHILDORD.Consigneekey 
            ELSE ORDERS.Consigneekey END Consigneekey,
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Company 
            ELSE ORDERS.C_Company END AS C_Company,    
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_contact1 
            ELSE ORDERS.C_contact1 END AS C_contact1,  
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_contact2 
            ELSE ORDERS.C_contact2 END AS C_contact2,  
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address1 
            ELSE ORDERS.C_Address1 END AS C_Address1,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address2 
            ELSE ORDERS.C_Address2 END AS C_Address2,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address3 
            ELSE ORDERS.C_Address3 END AS C_Address3,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address4 
            ELSE ORDERS.C_Address4 END AS C_Address4,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Phone1 
            ELSE ORDERS.C_Phone1 END AS C_Phone1,
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Phone2 
            ELSE ORDERS.C_Phone2 END AS C_Phone2,
         CONVERT(NVARCHAR(250),ORDERS.Notes2) AS Notes2,
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.BuyerPO 
            ELSE ORDERS.BuyerPO END AS BuyerPO,    
         PackDetail.CartonNo,   
         PackDetail.LabelNo,
         SKU = PackDetail.SKU,
         SKU.DESCR,
         Color = ISNULL(RTRIM(SKU.BUSR7),''),
         Price = ISNULL(SKU.Price,0),
         PACK.PackUOM3,
         Packqty = SUM(DISTINCT PackDetail.qty),
       --  PackQty = ( SELECT sum(PD.Qty) FROM PACKDETAIL PD WITH (NOLOCK) 
                     --WHERE PD.Pickslipno = @c_Pickslipno AND PD.Cartonno = PACKDETAIL.Cartonno 
                     --AND PD.Labelno = PACKDETAIL.Labelno AND PD.SKU = PACKDETAIL.Sku ) ,
         ORDERS.storerkey,SKU.sku AS S_SKU,packdetail.LOTTABLEVALUE AS LOTTABLEVALUE,
         lott.Lottable04,orders.ordergroup        
    FROM ORDERS     WITH (NOLOCK)    
    JOIN PackHeader WITH (NOLOCK) ON (Orders.Orderkey = Packheader.Orderkey)
    JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
    JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.StorerKey = SKU.StorerKey AND PACKDETAIL.Sku = SKU.Sku)
    JOIN PACK       WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey) 
    JOIN STORER     WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
    JOIN PICKINGINFO WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PICKINGINFO.PickSlipNo)
    JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey=Packheader.Orderkey AND pd.sku=packdetail.sku AND pd.Storerkey=packdetail.storerkey
    JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.Lot=PD.Lot AND LOTT.Lottable02=packdetail.LOTTABLEVALUE 
                                            AND LOTT.sku = PD.Sku AND LOTT.StorerKey=PD.Storerkey                
    LEFT JOIN ORDERS CHILDORD WITH (NOLOCK) ON ( STORER.Susr2 = CHILDORD.Storerkey AND ORDERS.BuyerPO = CHILDORD.ExternOrderkey )
    LEFT JOIN CODELKUP CL WITH (NOLOCK) ON ( ORDERS.Billtokey = CL.Code AND CL.Listname = 'LFA2LFK' )
    --LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (ORDERS.Storerkey = CL1.Storerkey AND CL1.listname='REPORTCFG' AND CL1.code ='SHOWCHINESEWROD')
    --LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (ORDERS.Storerkey = CL2.Storerkey AND CL2.listname='REPORTCFG' AND CL2.code ='SHOWSKU' AND CL2.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL2.Short,'') <> 'N')
    --LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON (ORDERS.Storerkey = CL3.Storerkey AND CL3.listname='REPORTCFG' AND CL3.code ='SHOWBUSR1' AND CL3.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL3.Short,'') <> 'N')   
    --LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON (ORDERS.Storerkey = CL4.Storerkey AND CL4.listname='REPORTCFG' AND CL4.code ='ShowAltSku' AND CL4.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL4.Short,'') <> 'N')   
    --LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON (ORDERS.Storerkey = CL5.Storerkey AND CL5.listname='REPORTCFG' AND CL5.code ='ShowSKUDetails' AND CL5.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL5.Short,'') <> 'N')  
    --LEFT JOIN CODELKUP CL6 WITH (NOLOCK) ON (ORDERS.Storerkey = CL6.Storerkey AND CL6.listname='REPORTCFG' AND CL6.code ='ShowColor' AND CL6.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL6.Short,'') <> 'N')     
WHERE ( Packheader.Pickslipno = @c_Pickslipno )
     AND ( PackHeader.OrderKey <> '' )  
GROUP BY PACKHEADER.PickSlipNo,
         PICKINGINFO.ScanOutDate,
         STORER.Company,
         ORDERS.OrderKey,   
         ORDERS.ExternOrderKey,
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Consigneekey IS NOT NULL THEN
            CHILDORD.Consigneekey 
            ELSE ORDERS.Consigneekey END,
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Company 
            ELSE ORDERS.C_Company END,     
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_contact1 
            ELSE ORDERS.C_contact1 END,
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_contact2 
            ELSE ORDERS.C_contact2 END,     
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address1 
            ELSE ORDERS.C_Address1 END,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address2 
            ELSE ORDERS.C_Address2 END,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address3 
            ELSE ORDERS.C_Address3 END,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Address4 
            ELSE ORDERS.C_Address4 END,   
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Phone1 
            ELSE ORDERS.C_Phone1 END, 
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.C_Phone2 
            ELSE ORDERS.C_Phone2 END,
         CONVERT(NVARCHAR(250),ORDERS.Notes2), 
         CASE WHEN CL.Code IS NOT NULL AND CHILDORD.Orderkey IS NOT NULL THEN
            CHILDORD.BuyerPO 
            ELSE ORDERS.BuyerPO END,   
         PackDetail.CartonNo,   
         PackDetail.LabelNo,
         PACKDETAIL.Sku,
         ISNULL(RTRIM(SKU.Style),'') + '-' + ISNULL(RTRIM(SKU.Color),'') + '-' + ISNULL(RTRIM(SKU.Size),''), 
         SKU.DESCR, 
         ISNULL(RTRIM(SKU.BUSR7),''),
         ISNULL(SKU.Price,0),
         PACK.PackUOM3,
         ORDERS.storerkey,SKU.sku,packdetail.LOTTABLEVALUE,lott.Lottable04,orders.ordergroup   
UNION ALL 
   SELECT PACKHEADER.PickSlipNo,
            PICKINGINFO.ScanOutDate,
            STORER.Company,
            '' as OrderKey,
         '' as ExternOrderKey,
            Consigneekey = MAX(Orders.Consigneekey),
         C_Company  = MAX(Orders.C_Company),
         C_contact1 = MAX(ORDERS.C_contact1),
         C_contact2 = MAX(ORDERS.C_contact2),
         C_Address1 = MAX(ORDERS.C_Address1),
         C_Address2 = MAX(ORDERS.C_Address2),
         C_Address3 = MAX(ORDERS.C_Address3),
         C_Address4 = MAX(ORDERS.C_Address4),
         C_Phone1   = MAX(ORDERS.C_Phone1),
         C_Phone2   = MAX(ORDERS.C_Phone2),
         notes2  = MAX(CONVERT(NVARCHAR(250),ORDERS.Notes2)),
         BuyerPO = MAX(ORDERS.BuyerPO),
         PackDetail.CartonNo,
            PackDetail.LabelNo,
         SKU = PackDetail.SKU,
            SKU.DESCR,
            Color = ISNULL(RTRIM(SKU.BUSR7),''),
            Price = ISNULL(SKU.Price,0),
         PACK.PackUOM3,
         PackQty = SUM(Packdetail.Qty),
         MAX(ORDERS.storerkey),
         SKU.sku AS S_SKU ,packdetail.LOTTABLEVALUE,lott.Lottable04,MAX(ORDERS.OrderGroup   ) 
    FROM PACKHEADER WITH (NOLOCK)  
    JOIN PACKDETAIL WITH (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo )
    CROSS APPLY (SELECT TOP 1 O.Storerkey,O.Consigneekey,O.C_Company,O.C_contact1,O.C_contact2,O.C_Address1,O.C_Address2,O.C_Address3,O.C_Address4,O.C_Phone1,O.C_Phone2,O.Notes2,O.BuyerPO,O.b_Company,o.OrderGroup 
                 FROM ORDERS O (NOLOCK)
                 JOIN LOADPLANDETAIL  (NOLOCK) ON O.Orderkey = LOADPLANDETAIL.Orderkey
                 WHERE PACKHEADER.Loadkey = LOADPLANDETAIL.LoadKey) AS ORDERS
    JOIN STORER     WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
    JOIN SKU        WITH (NOLOCK) ON ( PACKDETAIL.StorerKey = SKU.StorerKey AND PACKDETAIL.Sku = SKU.Sku)
    JOIN PACK       WITH (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
    JOIN PICKINGINFO WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PICKINGINFO.PickSlipNo)
    JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey=Packheader.Orderkey AND pd.sku=packdetail.sku AND pd.Storerkey=packdetail.storerkey
    JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.Lot=PD.Lot AND LOTT.Lottable02=packdetail.LOTTABLEVALUE        
    --LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (ORDERS.Storerkey = CL1.Storerkey AND CL1.listname='REPORTCFG' AND CL1.code ='SHOWCHINESEWROD')
    --LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (ORDERS.Storerkey = CL2.Storerkey AND CL2.listname='REPORTCFG' AND CL2.code ='SHOWSKU' AND CL2.Long = 'r_dw_packing_list_by_ctn5' AND ISNULL(CL2.Short,'') <> 'N')
    --LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON (ORDERS.Storerkey = CL3.Storerkey AND CL3.listname='REPORTCFG' AND CL3.code ='SHOWBUSR1' AND CL3.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL3.Short,'') <> 'N')
    --LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON (ORDERS.Storerkey = CL4.Storerkey AND CL4.listname='REPORTCFG' AND CL4.code ='ShowAltSku' AND CL4.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL4.Short,'') <> 'N')
    --LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON (ORDERS.Storerkey = CL5.Storerkey AND CL5.listname='REPORTCFG' AND CL5.code ='ShowSKUDetails' AND CL5.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL5.Short,'') <> 'N')
    --LEFT JOIN CODELKUP CL6 WITH (NOLOCK) ON (ORDERS.Storerkey = CL6.Storerkey AND CL6.listname='REPORTCFG' AND CL6.code ='ShowColor' AND CL6.Long = 'r_dw_packing_list_by_ctn21' AND ISNULL(CL6.Short,'') <> 'N')      
WHERE ( PACKHEADER.Pickslipno = @c_Pickslipno )
     AND ( PACKHEADER.OrderKey = '' )
GROUP BY PACKHEADER.PickSlipNo,
           PICKINGINFO.ScanOutDate,
            STORER.Company,
         PACKDETAIL.CartonNo,
            PACKDETAIL.LabelNo,
            PACKDETAIL.Sku,
         ISNULL(RTRIM(SKU.Style),'') + '-' + ISNULL(RTRIM(SKU.Color),'') + '-' + ISNULL(RTRIM(SKU.Size),''),
            SKU.DESCR,
            ISNULL(RTRIM(SKU.BUSR7),''),
            ISNULL(SKU.Price,0),
         PACK.PackUOM3,
         SKU.sku,packdetail.LOTTABLEVALUE,LOTT.Lottable04

QUIT_SP:  

END -- procedure

GO