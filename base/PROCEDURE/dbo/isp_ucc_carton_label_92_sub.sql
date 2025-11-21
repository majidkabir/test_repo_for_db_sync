SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_92_SUB                        */
/* Creation Date: 16-Dec-2019                                           */
/* Copyright: LFL                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose:  WMS-11393 - CN_Pandora_ECOM Carton Label                   */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_92                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 12Dec2019    mingle01 1.0  add orders.m_company                      */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_92_SUB] (
	           @c_StorerKey      NVARCHAR(15), 
              @c_PickSlipNo     NVARCHAR(10),
              @c_StartCartonNo  NVARCHAR(5),
              @c_EndCartonNo    NVARCHAR(5)
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
      SELECT PACKHEADER.Loadkey, 
             ORDERS.ExternOrderKey,      
             CASE WHEN ISNULL(ORDERS.C_Company,'') = '0' THEN '' ELSE ISNULL(ORDERS.C_Company,'') END, 
             ORDERS.C_Address1, 
             ORDERS.C_Address2, 
             ORDERS.C_City,
             ORDERS.C_Contact1,
             ORDERS.C_Phone1,
             PACKDETAIL.CartonNo,        
             (SELECT ISNULL(MAX(P2.CartonNo), '') 
             FROM PACKDETAIL P2 (NOLOCK) 
             WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo
             HAVING SUM(P2.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)
             WHERE OD2.OrderKey = PACKHEADER.OrderKey) ) AS CartonMax, 
             SUM(PACKDETAIL.Qty) AS Qty,
             ISNULL(CLR.short,'N') AS showfield,
             CASE WHEN ISNULL(CLR.short,'N') = 'Y' THEN CONVERT(NVARCHAR(10),(ROUND(sum(S.STDGROSSWGT * PACKDETAIL.Qty),4)+ISNULL(CTN.CartonWeight,0)))
                                              ELSE '' END AS ctnweight,
             CASE WHEN ISNULL(CLR2.SHORT,'N') = 'Y' AND CAST(CLR2.LONG AS INT) <> 0 THEN
             CLR2.UDF01 + RIGHT(REPLICATE('0',CLR2.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CLR2.UDF02 AS INT),CAST(CLR2.UDF03 AS INT)-CAST(CLR2.UDF02 AS INT)+1)
                               ,CAST(CLR2.LONG AS INT)-LEN(CLR2.UDF01))
                  WHEN ISNULL(CLR2.SHORT,'N') = 'Y' AND CAST(CLR2.LONG AS INT) = 0 THEN 
                  CLR2.UDF01 + PACKDETAIL.LABELNO
                  ELSE '' END AS NewLabelNo,
             PD.DropID,
             ORDERS.M_company          --mingle01
      FROM ORDERS ORDERS (NOLOCK) 
      JOIN PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
      JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
      CROSS APPLY (SELECT TOP 1 DropID FROM PICKDETAIL (NOLOCK) WHERE PICKDETAIL.OrderKey = ORDERS.OrderKey) AS PD  --WL01
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_92_rdt' AND ISNULL(CLR.Short,'') <> 'N')
      LEFT JOIN  CARTONIZATION CTN (NOLOCK) ON CTN.cartontype='CARTON' AND CTN.cartonizationgroup = 'lccncarton'
      --LEFT JOIN CODELKUP CLR2 WITH (NOLOCK) ON (CLR2.LISTNAME = 'BARCODELEN' AND CLR2.STORERKEY = ORDERS.STORERKEY AND CLR2.CODE = 'SUPERHUB')
      OUTER APPLY (SELECT TOP 1 CLR2.SHORT, CLR2.LONG, CLR2.UDF01, CLR2.UDF02, CLR2.UDF03, CLR2.CODE2 FROM
                   CODELKUP CLR2 WITH (NOLOCK) WHERE (CLR2.LISTNAME = 'BARCODELEN' AND CLR2.STORERKEY = ORDERS.STORERKEY AND CLR2.CODE = 'SUPERHUB' AND
                  (CLR2.CODE2 = ORDERS.FACILITY OR CLR2.CODE2 = '') ) ORDER BY CASE WHEN CLR2.CODE2 = '' THEN 2 ELSE 1 END ) AS CLR2
      JOIN SKU S (NOLOCK) ON s.StorerKey=PACKDETAIL.StorerKey AND s.sku = PACKDETAIL.sku
      WHERE ORDERS.StorerKey = @c_StorerKey AND PACKHEADER.PickSlipNo = @c_PickSlipNo 
      AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int)
      GROUP BY PACKHEADER.Pickslipno, 
               PACKHEADER.Orderkey, 
               PACKHEADER.Loadkey, 
               ORDERS.ExternOrderKey,      
               CASE WHEN ISNULL(ORDERS.C_Company,'') = '0' THEN '' ELSE ISNULL(ORDERS.C_Company,'') END, 
               ORDERS.C_Address1, 
               ORDERS.C_Address2, 
               ORDERS.C_City,
               ORDERS.C_Contact1,
               ORDERS.C_Phone1,
               PACKDETAIL.CartonNo,
               ISNULL(CLR.short,'N'),
               ISNULL(CTN.CartonWeight,0),
               PACKDETAIL.LabelNo,
               ISNULL(CLR2.short,'N'),
               CLR2.UDF01,
               CLR2.UDF02,
               CLR2.UDF03,
               CLR2.LONG,
               PD.DropID,
               ORDERS.M_company                --mingle01
      ORDER BY PACKDETAIL.CartonNo

   END

END


GO