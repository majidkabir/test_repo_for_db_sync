SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_UCC_Carton_Label_79                            */  
/* Creation Date: 01-Apr-2019                                           */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose:  WMS-8373 - CN SWIRE carton label  CR                       */  
/*                                                                      */  
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  r_dw_ucc_carton_label_79                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_UCC_Carton_Label_79] (  
      @c_StorerKey      NVARCHAR(20),   
      @c_PickSlipNo     NVARCHAR(20),  
      @c_StartCartonNo  NVARCHAR(20),  
      @c_EndCartonNo    NVARCHAR(20)  
   )  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue  INT = 1         
  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN         
      SELECT DISTINCT PACKHEADER.PickSlipNo  
                     ,Orders.LoadKey  
                     ,Orders.ExternOrderkey   
                     ,Orders.C_Company  
                     ,RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')' AS state_city  
                     ,(Orders.C_Address1 + ' ' + RTRIM(ISNULL(Orders.C_Address2,'')) + ' ' + RTRIM(ISNULL(Orders.C_Address3,'')) + ' ' + RTRIM(ISNULL(Orders.C_Address4,''))) as C_Address1  
                     ,Orders.C_Contact1 AS c_contact1  
                     ,Orders.C_Contact2 AS c_contact2  
                     ,Orders.C_Phone1 AS c_phone1  
                     ,Orders.C_Phone2 AS c_phone2  
                     ,PACKDETAIL.SKU   
                     ,SKU.Size  
                     ,PACKDETAIL.Qty  
                     ,PackDetail.CartonNo   
                     ,TotalCtn = CASE PACKHEADER.Status   
                                 WHEN '9' THEN (SELECT count(distinct cartonno) from packdetail where PickSlipNo = Packheader.PickslipNo)   
                                 ELSE 0  
                                 END  
                     ,PACKHEADER.editwho          
                     ,LEFT(SKU.BUSR1,10) as SBusr1  
                     ,CONVERT(DECIMAL(16,2),ISNULL(PACKINFO.Weight,0.00))  
                     ,CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN  
                                CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)  
                                ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))  
                     WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN   
                     CL.UDF01 + PACKDETAIL.LABELNO  
                     ELSE '' END AS NewLabelNo  
                     --   ,ISNULL(CL.SHORT,'N') AS ShowBarcode  
      FROM ORDERS WITH (NOLOCK)   
      INNER JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)    
      JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)  
      JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)   
      LEFT JOIN PACKINFO WITH (NOLOCK)ON (PACKDETAIL.PICKSLIPNO = PACKINFO.PICKSLIPNO AND PACKDETAIL.CARTONNO = PACKINFO.CARTONNO)  
      OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM  
                   CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND  
                   (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL  
      WHERE ORDERS.StorerKey = @c_StorerKey AND PACKHEADER.PickSlipNo = @c_PickSlipNo   
      AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int)  
   END  
  
END  

GO