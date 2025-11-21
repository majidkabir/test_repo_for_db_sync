SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_CartonManifestLabel37_1_rdt                    */    
/* Creation Date: 14-Jun-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-17265 - Adidas UCC Shipping & Carton Label              */    
/*                                                                      */    
/* Called By: r_dw_carton_manifest_label_37_1_rdt                       */    
/*                                                                      */    
/* GitLab Version: 1.1                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */ 
/* 2021-06-14  WLChooi  1.0   Created - DevOps Combine Script           */    
/* 2022-03-31  WLChooi  1.1   WMS-17265 - Modify Column Filter (WL01)   */
/************************************************************************/    
CREATE PROC [dbo].[isp_CartonManifestLabel37_1_rdt] (    
       @c_Loadkey          NVARCHAR(10),     
       @c_Dropid           NVARCHAR(20),    
       @c_Externorderkey   NVARCHAR(50),
       @c_Style            NVARCHAR(20)
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
    
   SELECT SkuSize       = ISNULL(RTRIM(SKU.Size),'') + '/'  
                        + CONVERT(VARCHAR(5), SUM(PACKDETAIL.Qty))
         ,Seperator     = ', '
   FROM PACKHEADER  WITH (NOLOCK) 
   JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.Orderkey    = ORDERS.Orderkey) 
   JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey  = SKU.Storerkey)     
                                  AND(PACKDETAIL.Sku        = SKU.Sku)
   LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'SIZELSTORD')
                                    AND(CODELKUP.Storerkey= PACKDETAIL.Storerkey)
                                    AND(CODELKUP.Code = ISNULL(RTRIM(SKU.Size),''))
   CROSS APPLY (SELECT TOP 1 ISNULL(ORDERDETAIL.UserDefine02,'') AS UserDefine02  --WL01
                FROM ORDERDETAIL (NOLOCK)                                         --WL01
                WHERE ORDERDETAIL.OrderKey = ORDERS.OrderKey) AS OD               --WL01
   WHERE PACKHEADER.Loadkey = @c_Loadkey
   AND   PACKDETAIL.LabelNo  = @c_dropid
   --AND   ORDERS.ExternOrderkey = @c_externorderkey   --WL01
   AND   OD.UserDefine02 = @c_externorderkey   --WL01
   AND   SKU.Style = @c_style
   GROUP BY ISNULL(RTRIM(SKU.Size),'')
         ,  CONVERT(INT, CASE WHEN CODELKUP.Short IS NULL THEN '99999' ELSE CODELKUP.Short END)
   ORDER BY CONVERT(INT, CASE WHEN CODELKUP.Short IS NULL THEN '99999' ELSE CODELKUP.Short END) 

END 

GO