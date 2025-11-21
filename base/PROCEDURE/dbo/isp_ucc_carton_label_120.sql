SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_120                           */
/* Creation Date: 23 FEB 2023                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21581 -[CN] HasBro Invoice packing list NEW             */
/*                                                                      */
/* Called By: r_dw_UCC_Carton_Label_120                                 */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 23-FEB-2022  CSCHONG 1.0   DEvops Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_UCC_Carton_Label_120] (
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



    SELECT PACKHEADER.Pickslipno
         ,ISNULL(PIF.CartonNo,0) AS CartonNo
         ,PACKDETAIL.SKU as SKU
         ,SKU.Descr AS SkuDescr
         ,PACKDETAIL.qty AS Qty
--       ,PACKDETAIL.sku AS sku
         ,OD.UnitPrice AS Unitprice
         ,ISNULL(CL.notes,'') as Logo
         ,ORDERS.externorderkey AS ExternOrderkey
         ,CONVERT(NVARCHAR(10),ORDERS.adddate,101) AS Adddate
         ,ORDERS.c_Contact1  AS C_Contact1
         ,CONVERT(NVARCHAR(10),oif.PmtDate,101) AS Invdate
         ,ISNULL(ORDERS.c_address1,'') + ' ' + ISNULL(ORDERS.c_address2,'') + ' ' +ISNULL(ORDERS.c_address3,'') + ' ' + ISNULL(ORDERS.c_address4,'') AS CAddress
         ,ISNULL(ORDERS.c_phone1,'') AS CPhone1
         ,ISNULL(CL1.notes,'') as footerText
         ,ROW_NUMBER() OVER (PARTITION BY PACKHEADER.Pickslipno,ISNULL(PIF.CartonNo,0) ORDER BY  PACKHEADER.Pickslipno,ISNULL(PIF.CartonNo,0),PACKDETAIL.sku ) AS Rowno
    FROM PACKHEADER WITH (NOLOCK)
    JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Loadkey = ORDERS.Loadkey)
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                  AND(PACKDETAIL.Sku = SKU.Sku)
    JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PACKDETAIL.pickslipno AND PIF.CartonNo = PACKDETAIL.cartonno
    JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORDERS.orderkey 
    JOIN dbo.OrderInfo OIF WITH (NOLOCK) ON OIF.OrderKey = ORDERS.OrderKey
    JOIN dbo.CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME ='INVTYPE' AND CL2.Storerkey=ORDERS.Storerkey AND CL2.code=ORDERS.c_Country
    LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'RPTLOGO' AND CL.Code='LOGO' AND CL.Storerkey = ORDERS.Storerkey
    LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'HBInvoice' AND CL1.Code='text1' AND CL1.Storerkey = ORDERS.Storerkey
   WHERE PACKHEADER.PickSlipNo = @c_pickslipno
     AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
   GROUP BY PACKHEADER.Pickslipno
         ,ISNULL(PIF.CartonNo,0)
         ,PACKDETAIL.SKU
         ,SKU.Descr
         ,PACKDETAIL.qty 
         ,PACKDETAIL.sku 
         ,OD.UnitPrice 
         ,ISNULL(CL.notes,'')
         ,ORDERS.externorderkey 
         ,CONVERT(NVARCHAR(10),ORDERS.adddate,101) 
         ,ORDERS.c_Contact1  
         ,CONVERT(NVARCHAR(10),oif.PmtDate,101)
         ,ISNULL(ORDERS.c_address1,'') + ' ' + ISNULL(ORDERS.c_address2,'') + ' ' +ISNULL(ORDERS.c_address3,'') + ' ' + ISNULL(ORDERS.c_address4,'')
         ,ISNULL(ORDERS.c_phone1,'') 
         ,ISNULL(CL1.notes,'')
   ORDER BY PACKHEADER.Pickslipno,ISNULL(PIF.CartonNo,0),PACKDETAIL.sku



END

GO