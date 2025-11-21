SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store Procedure: isp_UCC_Carton_Label_15                                      */
/* Creation Date: 29-Dec-2021                                                    */
/* Copyright:                                                                    */
/* Written by: CSCHONG                                                           */
/*                                                                               */
/* Purpose: WMS-18654 SG - Prestige - Shipping Label [CR]                        */
/*                                                                               */   
/* Input Parameters: @cStorerKey - StorerKey,                                    */
/*                   @cPickSlipNo - Pickslipno,                                  */
/*                   @cFromCartonNo - From CartonNo,                             */
/*                   @cToCartonNo - To CartonNo,                                 */
/*                                                                               */
/* Usage: Call by dw = r_dw_ucc_carton_label_15                                  */
/*                                                                               */
/* PVCS Version: 1.0                                                             */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date         Author        Purposes                                           */
/* 29/12/2021   CSCHONG       Devops Scripts Combine                             */
/*********************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_15] ( 
   @c_StorerKey     NVARCHAR( 15),
   @c_PickSlipNo    NVARCHAR( 10), 
   @c_StartCartonNo NVARCHAR( 10),
   @c_EndCartonNo   NVARCHAR( 10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_debug int

   DECLARE 
      @nFromCartonNo         int,
      @nToCartonNo           int,
      @cUCC_LabelNo          NVARCHAR( 20),
      @cUCC_FilePath_Barcode NVARCHAR( 200)   -- using file path + bmp to display barcode

   SET @b_debug = 0

   SET @nFromCartonNo = CAST( @c_StartCartonNo AS int)
   SET @nToCartonNo = CAST( @c_EndCartonNo AS int)
   
  

   SELECT PACKHEADER.PickSlipNo, 
       PACKDETAIL.LabelNo, 
       ORDERS.ORDERKEY, 
      CASE WHEN ISNULL(CLR.short,'N') = 'N' THEN ORDERS.ExternOrderKey
         ELSE PACKHEADER.Route END as 'ExternOrderKey', 
       ORDERS.InvoiceNo,
       PACKDETAIL.CartonNo, 
       (SELECT ISNULL(MAX(P2.CartonNo), '') 
        FROM PACKDETAIL P2 (NOLOCK) 
        WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo
        HAVING SUM(P2.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)
                              WHERE OD2.OrderKey = PACKHEADER.OrderKey) ) AS CartonMax, 
       SUM(PACKDETAIL.Qty) AS Qty, 
       ORDERS.Userdefine04, 
       ORDERS.Consigneekey, 
       ORDERS.C_Company, 
       ORDERS.C_Address1, 
       ORDERS.C_Address2, 
       ORDERS.C_Address3, 
       ORDERS.C_Address4, 
       ORDERS.C_City,      /* SOS31757 */
       CASE WHEN ISNULL(CLR.short,'N') = 'N' THEN PACKHEADER.Route
          ELSE ORDERS.ExternOrderKey END as 'Route', 
       ORDERS.C_Zip, 
       MAX(IDS.Company) CompanyFrom,
       MAX(IDS.Address1) Address1From,
       MAX(IDS.Address2) Address2From,
       MAX(IDS.Address3) Address3From,
       CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + ' ' + CONVERT(CHAR(8), GetDate(), 108)),
       ORDERS.DeliveryDate,
       MAX(SKU.AltSKU) AlternateSKu,
       ISNULL(STORERCONFIG.SValue, '0') sValue,
       ORDERS.BUYERPO, 
       PACKHEADER.AddWho,
       CASE WHEN ISNULL(CLR.short,'N') = 'Y' THEN (ISNULL(ORDERS.Notes,'') +' ' + ISNULL(ORDERS.Notes2,''))
       ELSE '' END as 'ORD_Note',
       ISNULL(PACKINFO.[Weight],0.00) AS CartonWeight,
       CASE WHEN ISNULL(CLR.short,'N') = 'N' THEN 'DO# ' ELSE 'Route ' END AS 'Tittle' ,
       CASE WHEN ISNULL(CLR.short,'N') = 'N' THEN '0' ELSE '1' END AS 'Showfield',
       CASE WHEN ISNULL(CLR1.short,'N') = 'N' THEN '0' ELSE '1' END AS 'Showqrcode',
       CASE WHEN ISNULL(CLR1.short,'N') = 'N'  THEN '' ELSE ORDERS.ExternOrderKey END qrcode
  FROM ORDERS ORDERS (NOLOCK) 
  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
  JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)
  JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
  LEFT OUTER JOIN STORER STORERContact (NOLOCK) ON ( STORERContact.Type = '2' AND STORERContact.StorerKey = ORDERS.ConsigneeKey)  
  LEFT OUTER JOIN FACILITY (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility) 
  LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = FACILITY.UserDefine10) 
  LEFT OUTER JOIN V_STORERCONFIG2 STORERCONFIG (NOLOCK) ON (ORDERS.Consigneekey = STORERCONFIG.Storerkey AND STORERCONFIG.Configkey = 'ALTSKUonCTNLBL')
  LEFT OUTER JOIN PACKINFO (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo AND PACKDETAIL.CartonNo = PACKINFO.CartonNo) 
  LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                        
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_15' AND ISNULL(CLR.Short,'') <> 'N')  
 LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWQRCODE'                                        
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_ucc_carton_label_15' AND ISNULL(CLR1.Short,'') <> 'N') 
 WHERE ORDERS.StorerKey = @c_StorerKey 
   AND PACKHEADER.PickSlipNo = @c_PickSlipNo 
   AND PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int) 
 GROUP BY PACKHEADER.PickSlipNo, 
         PACKDETAIL.LabelNo, 
         ORDERS.ORDERKEY, 
         ORDERS.ExternOrderKey, 
         ORDERS.InvoiceNo,
         PACKDETAIL.CartonNo, 
         ORDERS.Userdefine04, 
         ORDERS.Consigneekey, 
         ORDERS.C_Company, 
         ORDERS.C_Address1, 
         ORDERS.C_Address2, 
         ORDERS.C_Address3, 
         ORDERS.C_Address4, 
         ORDERS.C_City,    /* SOS31757 */
         PACKHEADER.Route, 
         ORDERS.C_Zip, 
         PACKHEADER.OrderKey,
         ORDERS.DeliveryDate,
         STORERCONFIG.SValue,
         ORDERS.BUYERPO, 
         PACKHEADER.AddWho, 
         ISNULL(PACKINFO.[Weight],0.00) ,
         ORDERS.Notes,
         ORDERS.Notes2,
         CLR.short,CLR1.short  
ORDER BY  PACKDETAIL.CartonNo

  

END

GO