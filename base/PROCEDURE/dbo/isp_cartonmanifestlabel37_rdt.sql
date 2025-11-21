SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_CartonManifestLabel37_rdt                      */    
/* Creation Date: 14-Jun-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-17265 - Adidas UCC Shipping & Carton Label              */    
/*                                                                      */    
/* Called By: r_dw_carton_manifest_label_37_rdt                         */    
/*                                                                      */    
/* GitLab Version: 1.3                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */ 
/* 2021-06-14  WLChooi  1.0   Created - DevOps Combine Script           */     
/* 2021-11-11  WLChooi  1.1   WMS-17265 - Add CartonType and Userkey    */
/*                            (WL01)                                    */
/* 2021-11-15  WLChooi  1.2   WMS-17265- Add BuyerPO (WL02)             */
/* 2022-03-31  WLChooi  1.3   WMS-17265 - Modify Column Mapping (WL03)  */
/************************************************************************/    
CREATE PROC [dbo].[isp_CartonManifestLabel37_rdt] (    
       @c_Pickslipno   NVARCHAR(10),     
       @c_FromCartonNo NVARCHAR(10),    
       @c_ToCartonNo   NVARCHAR(10),
       @c_FromLabelNo  NVARCHAR(20),
       @c_ToLabelNo    NVARCHAR(20),
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
           @b_debug       INT    
       
   SET @b_debug = 0    
    
   SELECT Loadkey        = PACKHEADER.Loadkey
         ,ExternOrderkey = ISNULL(RTRIM(OD.UserDefine02),'')   --WL03
         ,CtnCnt1        = (SELECT COUNT(DISTINCT PD.LabelNo)                                    
                            FROM PACKHEADER PH WITH (NOLOCK)                                    
                            JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) 
                            WHERE PH.PickSlipNo = @c_Pickslipno)                                 
         ,CartonNo       = ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,DropID         = ISNULL(RTRIM(PACKDETAIL.LabelNo),'')
         ,Style          = ISNULL(RTRIM(SKU.Style),'') 
         ,SkuDesc        = ''--ISNULL(RTRIM(SKU.Descr),'')    
         ,SizeQty        = SUM(PACKDETAIL.Qty) 
         ,ShowLargeFont  = ISNULL(CL.SHORT,'N')
         ,ShowSONo       = ISNULL(CL1.SHORT,'N')
         ,CartonType     = ISNULL(PIF.CartonType,'')   --WL01
         ,UserkeyOverride= TD.UserkeyOverride   --WL01
         ,BuyerPO        = ISNULL(ORDERS.BuyerPO,'')   --WL02
   FROM PACKHEADER WITH (NOLOCK)  
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)     
                         AND (PACKDETAIL.Sku = SKU.Sku)
   JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowLargeFont' )
                                      AND (CL.LONG = 'r_dw_carton_manifest_label_37_rdt' AND CL.STORERKEY = ORDERS.Storerkey)
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.LISTNAME = 'REPORTCFG' AND CL1.CODE = 'ShowSONo' )
                                       AND (CL1.LONG = 'r_dw_carton_manifest_label_37_rdt' AND CL1.STORERKEY = ORDERS.Storerkey)
   LEFT JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PACKDETAIL.PickSlipNo   --WL01
                                  AND PIF.CartonNo = PACKDETAIL.CartonNo       --WL01
   OUTER APPLY (SELECT TOP 1 ISNULL(TASKDETAIL.UserkeyOverride,'')             --WL01
                AS UserkeyOverride                                             --WL01
                FROM TASKDETAIL (NOLOCK)                                       --WL01
                WHERE TASKDETAIL.Storerkey = PACKHEADER.StorerKey              --WL01
                AND TASKDETAIL.Caseid = PACKDETAIL.LabelNo                     --WL01
                AND TASKDETAIL.TaskType = 'CPK') AS TD                         --WL01
   CROSS APPLY (SELECT TOP 1 ISNULL(ORDERDETAIL.UserDefine02,'') AS UserDefine02  --WL03
                FROM ORDERDETAIL (NOLOCK)                                         --WL03
                WHERE ORDERDETAIL.OrderKey = ORDERS.OrderKey) AS OD               --WL03
   WHERE PACKHEADER.PickSlipNo = @c_Pickslipno 
   --AND PACKD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT) 
   AND PACKDETAIL.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   GROUP BY PACKHEADER.Loadkey
         ,  ISNULL(RTRIM(OD.UserDefine02),'')   --WL03
         ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,  ISNULL(RTRIM(PACKDETAIL.LabelNo),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         --,  ISNULL(RTRIM(SKU.Descr),'') 
         ,  ISNULL(CL.SHORT,'N')
         ,  ISNULL(CL1.SHORT,'N')
         ,  ISNULL(PIF.CartonType,'')   --WL01
         ,  TD.UserkeyOverride          --WL01
         ,  ISNULL(ORDERS.BuyerPO,'')   --WL02
   ORDER BY PACKHEADER.Loadkey
         ,  ISNULL(RTRIM(PACKDETAIL.LabelNo),'')
         ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,  ISNULL(RTRIM(OD.UserDefine02),'')   --WL03
         ,  ISNULL(RTRIM(SKU.Style),'')  

END 

GO