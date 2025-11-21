SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_83                            */
/* Creation Date: 01-Apr-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose:  WMS-8456 - [CN] Super Hub Project _                        */ 
/*                      Welmaxing-Carton Label Change (CR)              */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_83                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_83] (
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
     SELECT DISTINCT
		 PACKHEADER.PickSlipNo
      ,PACKHEADER.LoadKey
		,Orders.C_Company
		,RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')' AS state_city
		,Orders.C_Address1
		,Orders.C_Address2
		,Orders.C_Address3
		,Orders.C_Address4
		,Orders.C_Contact1
		,Orders.C_Contact2
		,Orders.C_Phone1
		,Orders.C_Phone2
		,PACKDETAIL.SKU 
		,SKU.Size
		,PACKDETAIL.Qty
		,PackDetail.CartonNo
      ,STORER.Susr1
      ,CASE WHEN Orders.Consigneekey BETWEEN '0003920001' AND '0003929999' THEN
            'W'+RTRIM(PACKHEADER.Loadkey)+RIGHT('00000' + RTRIM(CAST(PackDetail.CartonNo AS CHAR)),5) 
       ELSE 'O'+RTRIM(PACKHEADER.Loadkey)+RIGHT('00000' + RTRIM(CAST(PackDetail.CartonNo AS CHAR)),5) END AS Barcode 
      ,CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN
            CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)
                                       ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))
            WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN 
            CL.UDF01 + PACKDETAIL.LABELNO
            ELSE '' END AS NewLabelNo
       FROM ORDERS WITH (NOLOCK) 
       INNER JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.LoadKey = PACKHEADER.LoadKey)
       JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
       JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)
       JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
       --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB')
       OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                    CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND
                   (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL
       WHERE ORDERS.StorerKey = @c_StorerKey AND PACKHEADER.PickSlipNo = @c_PickSlipNo 
       AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int)
  END

END

GO