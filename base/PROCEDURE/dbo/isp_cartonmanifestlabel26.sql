SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CartonManifestLabel26    								*/
/* Creation Date: 24 JUL 2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-5699 -CN Mizuno New Exceed PackList                     */
/*                                                                      */
/* Called By: r_dw_carton_manifest_Label_26                             */
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

CREATE PROC [dbo].[isp_CartonManifestLabel26] (
   --   @c_Storerkey      NVARCHAR(15)
      @c_Pickslipno     NVARCHAR(10)
   ,  @c_StartcartonNo  NVARCHAR(5)
   ,  @c_EndcartonNo    NVARCHAR(5))
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

  
   
    SELECT PACKHEADER.Pickslipno
         --,MAX(ISNULL(RTRIM(ORDERS.Consigneekey),'')) AS Consigneekey
         --,MAX(ISNULL(RTRIM(ORDERS.C_Company),'')) AS C_Company
         ,ISNULL(PACKDETAIL.CartonNo,0) AS CartonNo 
			,PACKDETAIL.SKU as SKU
			,SKU.Descr AS SkuDescr
         ,PACKDETAIL.qty AS Qty
         
			,SKU.altsku AS Altsku
			,SKU.SIZE AS SSize
			, PACKHEADER.OrderRefNo as OrderRefno
    --INTO #TEMP_PACK
    FROM PACKHEADER WITH (NOLOCK) 
    JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Loadkey = ORDERS.Loadkey)
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)		
                                  AND(PACKDETAIL.Sku = SKU.Sku)	
   WHERE PACKHEADER.PickSlipNo = @c_pickslipno 
     AND	PACKDETAIL.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
   GROUP BY PACKHEADER.Pickslipno, PACKHEADER.OrderRefNo, PACKDETAIL.CartonNo,PACKDETAIL.SKU,SKU.altsku,
	         SKU.SIZE ,SKU.Descr,PACKDETAIL.qty
   ORDER BY ISNULL(PACKDETAIL.CartonNo,0)   
   

      
END

GO