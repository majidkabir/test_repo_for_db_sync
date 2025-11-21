SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/      
/* Stored Procedure: isp_CartonManifestLabel38_rdt                      */      
/* Creation Date: 25-Oct-2021                                           */      
/* Copyright: LFL                                                       */      
/* Written by: mingle                                                   */      
/*                                                                      */      
/* Purpose: WMS-18187 - SG - Adidas SEA - Shipping and Carton Label     */      
/*                                                                      */      
/* Called By: r_dw_carton_manifest_label_38_rdt                         */      
/*                                                                      */      
/* GitLab Version: 1.0                                                  */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver   Purposes                                  */   
/* 2021-10-25   mingle  1.0   Created - DevOps Combine Script           */       
/************************************************************************/      
CREATE PROC [dbo].[isp_CartonManifestLabel38_rdt] (            
       @c_DropID       NVARCHAR(20)  
)      
AS      
BEGIN      
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @n_continue    INT,      
           @c_errmsg      NVARCHAR(255),      
           @b_success     INT,      
           @n_err         INT,       
           @b_debug       INT,  
           @c_pickslipno  NVARCHAR(20)      
         
   SET @b_debug = 0   
     
   SELECT @c_pickslipno = PH.PickSlipNo  
   FROM PACKHEADER PH WITH (NOLOCK)                                         
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
   WHERE PD.DropID = @c_DropID AND PD.Storerkey = 'ADIDAS'    
  
      
   SELECT Loadkey        = PACKHEADER.Loadkey  
         ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
         ,CtnCnt1        = (SELECT COUNT(DISTINCT PD.LabelNo)                                      
                            FROM PACKHEADER PH WITH (NOLOCK)                                      
                            JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)   
                            WHERE PD.PickSlipNo = @c_pickslipno)                                    
         --,CartonNo       = ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         --START ML01  
         ,Cartonno = (Select Count(Distinct PD2.Cartonno) 
          FROM PackDetail PD2 
          WHERE PD2.Cartonno < PACKDETAIL.Cartonno + 1 AND PD2.PickSlipNo = @c_pickslipno)
         --END ML01
         ,DropID         = ISNULL(RTRIM(PACKDETAIL.DropID),'')  
         ,Style          = ISNULL(RTRIM(SKU.Style),'')   
         ,SkuDesc        = ''--ISNULL(RTRIM(SKU.Descr),'')      
         ,SizeQty        = SUM(PACKDETAIL.Qty)   
         ,ShowLargeFont  = ISNULL(CL.SHORT,'N')  
         ,ShowSONo       = ISNULL(CL1.SHORT,'N')  
         ,M_VAT          = ISNULL(ORDERS.M_VAT,'')  
   FROM PACKHEADER WITH (NOLOCK)    
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
   JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)       
                         AND (PACKDETAIL.Sku = SKU.Sku)  
   JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)  
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowLargeFont' )  
                                      AND (CL.LONG = 'r_dw_carton_manifest_label_38_rdt' AND CL.STORERKEY = ORDERS.Storerkey)  
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.LISTNAME = 'REPORTCFG' AND CL1.CODE = 'ShowSONo' )  
                    AND (CL1.LONG = 'r_dw_carton_manifest_label_38_rdt' AND CL1.STORERKEY = ORDERS.Storerkey)  
   WHERE PACKDETAIL.DROPID = @c_DropID AND PACKDETAIL.Storerkey = 'ADIDAS'  
   GROUP BY PACKHEADER.Loadkey  
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
         --,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')  
         ,  ISNULL(RTRIM(PACKDETAIL.DropID),'')  
         ,  ISNULL(RTRIM(SKU.Style),'')  
         --,  ISNULL(RTRIM(SKU.Descr),'')   
         ,  ISNULL(CL.SHORT,'N')    
         ,  ISNULL(CL1.SHORT,'N')  
         ,  ISNULL(ORDERS.M_VAT,'')
         ,  PACKDETAIL.Cartonno  
   ORDER BY PACKHEADER.Loadkey  
         ,  ISNULL(RTRIM(PACKDETAIL.DropID),'')  
         ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')  
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
         ,  ISNULL(RTRIM(SKU.Style),'')    
  
END   

GO