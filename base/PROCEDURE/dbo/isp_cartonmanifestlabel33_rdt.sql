SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CartonManifestLabel33_rdt                      */
/* Creation Date: 11 MAR 2020                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-12355                                                   */
/*                                                                      */
/* Called By: r_dw_carton_manifest_Label_33_rdt                         */
/*            copy from r_dw_carton_manifest_Label_08                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_CartonManifestLabel33_rdt] (
      @c_Storerkey      NVARCHAR(15)
   ,  @c_Pickslipno     NVARCHAR(10)
   ,  @c_StartcartonNo  NVARCHAR(5)
   ,  @c_EndcartonNo    NVARCHAR(5))
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
    SELECT PACKHEADER.Pickslipno, PACKHEADER.LoadKey
         ,MAX(ISNULL(RTRIM(ORDERS.Consigneekey),'')) AS Consigneekey
         ,MAX(ISNULL(RTRIM(ORDERS.C_Company),'')) AS C_Company
         ,ISNULL(PACKDETAIL.CartonNo,0) AS CartonNo 
         ,(SELECT SUM(PKD.Qty) From PACKDETAIL PKD WITH (NOLOCK) 
                        WHERE PKD.PickslipNo = PACKHEADER.Pickslipno 
                        AND PKD.CartonNo = PACKDETAIL.CartonNo) AS Qty
         , MAX(PICKDETAIL.caseid) AS DropID 
    INTO #TEMP_PACK33RDT
    FROM PACKHEADER WITH (NOLOCK) 
    JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Loadkey = ORDERS.Loadkey)
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.DropID = PACKDETAIL.LabelNo 
                                 AND PICKDETAIL.SKU = PACKDETAIL.SKU)
    JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)      
                                  AND(PACKDETAIL.Sku = SKU.Sku)   
   WHERE ORDERS.Storerkey = @c_Storerkey
   AND PACKHEADER.PickSlipNo = @c_pickslipno 
   AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
   GROUP BY PACKHEADER.Pickslipno, PACKHEADER.LoadKey, PACKDETAIL.CartonNo
   ORDER BY ISNULL(PACKDETAIL.CartonNo,0)   
   
   SELECT P.PickslipNo, 
          P.LoadKey,
          P.Consigneekey,
          P.C_Company,
          P.CartonNo,
          P.Qty,          
          SUM(CASE WHEN SKU.BUSR3  = 'JDV' THEN PD.Qty ELSE 0 END) AS ClassQty1,              
          SUM(CASE WHEN SKU.BUSR3  = 'LAC' THEN PD.Qty ELSE 0 END) AS ClassQty2,              
          SUM(CASE WHEN SKU.BUSR3  = 'LDV' THEN PD.Qty ELSE 0 END) AS ClassQty3,              
          SUM(CASE WHEN SKU.BUSR3  = 'MAC' THEN PD.Qty ELSE 0 END) AS ClassQty4,              
          SUM(CASE WHEN SKU.BUSR3  = 'MDV' THEN PD.Qty ELSE 0 END) AS ClassQty5,              
          '' AS ClassQty6,
          '' AS ClassQty7,
          '' AS ClassQty8,
          '' AS ClassQty9  
          ,P.dropid 
   FROM #TEMP_PACK33RDT P   
   JOIN PACKDETAIL PD(NOLOCK) ON P.Pickslipno = PD.Pickslipno AND P.Cartonno = PD.Cartonno
   JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   GROUP BY P.PickslipNo, 
            P.LoadKey,
            P.Consigneekey,
            P.C_Company,
            P.CartonNo,
            P.Qty
           ,P.dropid
   ORDER BY P.CartonNo
      
END

GO