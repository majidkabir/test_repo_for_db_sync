SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_carton_manifest_label_117_rdt                       */  
/* Creation Date: 25-Jul-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose:  WMS-17356                                                  */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_main                                    */  
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
  
CREATE PROC [dbo].[isp_carton_manifest_label_117_rdt] (    
		@c_Pickslipno     NVARCHAR(10)    
    , @c_FromCartonNo   NVARCHAR(5)  = '' 
    , @c_ToCartonNo     NVARCHAR(5)  = ''
    , @c_FromLabelNo    NVARCHAR(20) = ''  
    , @c_ToLabelNo      NVARCHAR(20) = ''
    , @c_DropID         NVARCHAR(20) = ''
	
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF  
	
	IF ISNULL(@c_FromCartonNo,'') = '' OR ISNULL(@c_ToCartonNo,'') = ''
   BEGIN
      SELECT @c_FromCartonNo  = MIN(PD.CartonNo)
           , @c_ToCartonNo    = MAX(PD.CartonNo)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
      AND PD.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   END

   IF ISNULL(@c_FromLabelNo,'') = '' OR ISNULL(@c_ToLabelNo,'') = ''
   BEGIN
      SELECT @c_FromLabelNo   = MIN(PD.LabelNo)
           , @c_ToLabelNo     = MAX(PD.LabelNo)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
      AND PD.CartonNo BETWEEN @c_FromCartonNo AND @c_ToCartonNo
   END
  
   	SELECT   ORDERS.Orderkey
			,  ConsigneeKey = ISNULL(RTRIM(ORDERS.ConsigneeKey),'') 
			,	C_Company  = ISNULL(RTRIM(ORDERS.C_Company),'') 
			,	B_Address1 = ISNULL(RTRIM(ORDERS.B_ADDRESS1),'')  
			,	C_Address1 = ISNULL(RTRIM(ORDERS.C_ADDRESS1),'')      
			,	C_Address2 = ISNULL(RTRIM(ORDERS.C_ADDRESS2),'') 
			,	C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')   
			,	C_Address4 = ISNULL(RTRIM(ORDERS.C_Address4),'')  
			,	C_City     = ISNULL(RTRIM(ORDERS.C_City),'')  
			,	C_Zip      = ISNULL(RTRIM(ORDERS.C_Zip),'')   
			,	Route      = ISNULL(RTRIM(ORDERS.Route),'')   
			,	Carrier    = ISNULL(RTRIM(ROUTEMASTER.CarrierKey),'')  
			,	ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')    
			,	ExternPOKey    = ISNULL(RTRIM(ORDERS.ExternPOKey),'')   
 		   ,  Invoice        = ISNULL(RTRIM(ORDERS.InvoiceNo),'')  
    		,	DELIVERYDATE = ORDERS.DeliveryDate
			,  Notes = CONVERT(NVARCHAR(60), ORDERS.Notes)
			,	PACKHEADER.PickSlipNo 
			,  EditWho = CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'') = '' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'') END   
			,	PACKDETAIL.CartonNo  
			,	PACKDETAIL.SKU  
			,	DIV = SUBSTRING(SKU.SkuGroup, 1, 2) 
			,  PACKDETAIL.QTY
			,	UOM = PACK.PackUOM3
			,  DropID = ISNULL(RTRIM(PACKDETAIL.DropID),'')
			,  CartonLBL = CASE WHEN CL.Code IS NOT NULL THEN RIGHT(ISNULL(RTRIM(ORDERS.ExternOrderkey),''),4) ELSE '' END
         ,  showskudesc = CL1.Short
         ,  SKU.DESCR
		,  PACKDETAIL.LabelNo
		,  CASE WHEN ISNULL(CL2.Short,'N') = 'Y' AND ISNULL(CL2.UDF02,'') <> '' AND ISNULL(CL3.Code2,'') <> '' THEN ISNULL(CL2.UDF02,'') ELSE '' END AS ShowBarcode
		,  ISNULL(Loadplanlanedetail.loc,'') AS LPDLOC
		,  ISNULL(ORDERS.Userdefine09,'') AS UDF01 
		,  CASE WHEN LEN(PACKDETAIL.LabelNo) = '20' THEN SUBSTRING(PACKDETAIL.LabelNo,11,20) ELSE PACKDETAIL.LabelNo END as BarcodeLabelno 
		,  totalcartonno = (SELECT max(PD.CartonNo) FROM dbo.PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = PackDetail.Pickslipno)
		,  TASKDETAIL.EditWho
		,  MAX(TASKDETAIL.EditDate)
		,	totalqty = (SELECT sum(PD.qty) FROM dbo.PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = PackDetail.Pickslipno)
	FROM  PACKDETAIL  WITH (NOLOCK) 
	JOIN  PACKHEADER  WITH (NOLOCK)  ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)
	JOIN  ORDERS      WITH (NOLOCK)  ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
	JOIN  SKU         WITH (NOLOCK)  ON (PACKDETAIL.Storerkey = SKU.Storerkey)
							 				  AND (PACKDETAIL.Sku = SKU.Sku)
   JOIN  PACK        WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey) 
	JOIN  TASKDETAIL  WITH (NOLOCK)  ON TaskDetail.Sku = PackDetail.SKU AND TaskDetail.OrderKey = PackHeader.OrderKey
                                   AND TaskDetail.CASEID=PackDetail.LABELNO
   LEFT JOIN Loadplanlanedetail WITH (NOLOCK) ON Loadplanlanedetail.ExternOrderKey = ORDERS.ExternOrderKey 
												     AND Loadplanlanedetail.LoadKey = orders.LoadKey   
	LEFT JOIN  ROUTEMASTER WITH (NOLOCK)  ON (ORDERS.Route  = ROUTEMASTER.Route)
   LEFT JOIN  CODELKUP CL WITH (NOLOCK)  ON (CL.ListName = 'REPORTCFG') 
												     AND(CL.Code = 'ShowLast4ExtSONo')
                                         AND(CL.Storerkey = PACKHEADER.Storerkey)
													  AND(CL.Long = 'r_dw_carton_manifest_label_117_rdt')
												     AND(CL.Short IS NULL OR CL.Short = 'N')
  LEFT JOIN  CODELKUP CL1 WITH (NOLOCK)  ON (CL1.ListName = 'REPORTCFG') 
												     AND(CL1.Code = 'SHOWSKUDESC')
                                         AND(CL1.Storerkey = PACKHEADER.Storerkey)
													  AND(CL1.Long = 'r_dw_carton_manifest_label_117_rdt')
  LEFT JOIN  RDT.RDTUSER WITH (NOLOCK)  ON (PACKHEADER.EditWho = RDT.RDTUSER.UserName) 
  LEFT JOIN  CODELKUP CL2 WITH (NOLOCK)  ON (CL2.ListName = 'REPORTCFG') 
												     AND(CL2.Code = 'ShowLabelNo')
                                         AND(CL2.Storerkey = PACKHEADER.Storerkey)
													  AND(CL2.Long = 'r_dw_carton_manifest_label_117_rdt')
	LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ORDERS.Consigneekey)
	LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON (CL3.ListName = 'NikeUCCLBL') AND (CL3.Storerkey = PACKHEADER.Storerkey)
	                                                             AND (CL3.Code2 = ST.CustomerGroupCode)
	WHERE PACKDETAIL.PICKSLIPNO = @c_Pickslipno  
   AND PACKDETAIL.CARTONNO BETWEEN @c_FromCartonNo AND @c_ToCartonNo
	--AND PACKDETAIL.LABELNO BETWEEN @c_FromLabelNo AND @c_ToLabelNo
	--AND PACKDETAIL.DROPID = @c_DropID 
	GROUP BY ORDERS.Orderkey
			,  ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
			,	ISNULL(RTRIM(ORDERS.C_Company),'')
			,	ISNULL(RTRIM(ORDERS.B_ADDRESS1),'') 
			,	ISNULL(RTRIM(ORDERS.C_ADDRESS1),'')     
			,	ISNULL(RTRIM(ORDERS.C_ADDRESS2),'')
			,	ISNULL(RTRIM(ORDERS.C_Address3),'')
			,	ISNULL(RTRIM(ORDERS.C_Address4),'') 
			,	ISNULL(RTRIM(ORDERS.C_City),'')  
			,	ISNULL(RTRIM(ORDERS.C_Zip),'')        
			,	ISNULL(RTRIM(ORDERS.Route),'') 
			,	ISNULL(RTRIM(ROUTEMASTER.Carrierkey),'')   
    		,	ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
			,	ISNULL(RTRIM(ORDERS.ExternPOKey),'') 
			,	ISNULL(RTRIM(ORDERS.InvoiceNo),'')  
			,	ORDERS.DeliveryDate   
			,	CONVERT(NVARCHAR(60), ORDERS.Notes) 
			,	PACKHEADER.PickSlipNo 
			,  CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'') = '' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'') END   
			,	PACKDETAIL.CartonNo  
  			,	PACKDETAIL.SKU  
 			,	SUBSTRING(SKU.SkuGroup, 1, 2)   
			,	SKU.Packkey  
			,	PACKDETAIL.QTY
			,  PACK.PackUOM3
			,  ISNULL(RTRIM(PACKDETAIL.DropID),'')
			,  CL.Code
         ,  CL1.short
         ,  SKU.DESCR
		,  PACKDETAIL.LabelNo
		,  CASE WHEN ISNULL(CL2.Short,'N') = 'Y' AND ISNULL(CL2.UDF02,'') <> '' AND ISNULL(CL3.Code2,'') <> ''THEN ISNULL(CL2.UDF02,'') ELSE '' END
	    ,  ISNULL(Loadplanlanedetail.loc,'') 
		,  ISNULL(ORDERS.Userdefine09,'') 
		,   CASE WHEN LEN(PACKDETAIL.LabelNo) = '20' THEN SUBSTRING(PACKDETAIL.LabelNo,11,20) ELSE PACKDETAIL.LabelNo END 
		,	PACKDETAIL.Pickslipno
		,  TASKDETAIL.EditWho
		--,  TASKDETAIL.EditDate

  
END -- procedure  

GO