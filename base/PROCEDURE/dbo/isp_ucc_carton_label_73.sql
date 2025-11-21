SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_73                                 */
/* Creation Date: 06-Dec-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11265 - Convert to PB Compatible                        */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_73                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_73] 
            @c_Storerkey      NVARCHAR(15) 
         ,  @c_Pickslipno     NVARCHAR(10) 
         ,  @c_CartonNoStart  NVARCHAR(5)     
         ,  @c_CartonNoEnd    NVARCHAR(5)     
         ,  @b_Debug          INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT        

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END 

   SELECT PACKHEADER.PickSlipNo, 
          PACKDETAIL.LabelNo, 
          ORDERS.ORDERKEY, 
          ORDERS.ExternOrderKey, 
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
          CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Company ELSE ORDERS.C_Company END As c_company, 
          CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address1 ELSE ORDERS.C_Address1 END as c_address1, 
          CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address2 ELSE ORDERS.C_Address2 END as c_address2, 
          CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address3 ELSE ORDERS.C_Address3 END as c_address3, 
          CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address4 ELSE ORDERS.C_Address4 END as c_address4, 
          CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.City  ELSE ORDERS.C_City END as c_city,		/* WMS-8112 */
          PACKHEADER.Route,   
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
          ISNULL(SC2.SValue, '0') UCCLB03SHOWDOOR, 
          ISNULL(ORDERS.Door,'') Door ,
          PACKDETAIL.DropID, ISNULL(CODELKUP.Short, 'N') AS ShowCartonID, /* WMS-5835 */
          SSO.Route AS SSO_Route,
          ORDERS.Loadkey,
          ISNULL(ORDERS.Notes,'') AS Notes
   FROM ORDERS ORDERS (NOLOCK) 
   JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
   JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
   JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)
   JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
   LEFT OUTER JOIN STORER STORERContact (NOLOCK) ON ( STORERContact.Type = '2' AND STORERContact.StorerKey = ORDERS.ConsigneeKey)  
   LEFT OUTER JOIN FACILITY (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility) 
   LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = FACILITY.UserDefine10) 
   LEFT OUTER JOIN V_STORERCONFIG2 STORERCONFIG (NOLOCK) ON (ORDERS.Consigneekey = STORERCONFIG.Storerkey AND STORERCONFIG.Configkey = 'ALTSKUonCTNLBL')  
   LEFT OUTER JOIN V_STORERCONFIG2 SC2 (NOLOCK) ON (ORDERS.Storerkey = SC2.Storerkey AND SC2.Configkey = 'UCCLB03SHOWDOOR')   
   LEFT OUTER JOIN CODELKUP CODELKUP (NOLOCK) ON ( CODELKUP.LISTNAME = 'REPORTCFG' AND CODELKUP.Code = 'ShowCartonID' 
                                               AND CODELKUP.Long = 'r_dw_ucc_carton_label_73_rdt' AND CODELKUP.Storerkey = ORDERS.StorerKey ) /* WMS-5835 */
   LEFT OUTER JOIN CODELKUP C1 (NOLOCK) ON ( C1.LISTNAME = 'REPORTCFG' AND C1.Code = 'USESTORERADDRESS' 
                                         AND C1.Long = 'r_dw_ucc_carton_label_73_rdt' AND C1.Storerkey = ORDERS.StorerKey ) /* WMS-8112 */
   JOIN STORER STC (NOLOCK) ON (ORDERS.consigneeKey = STC.StorerKey)
   LEFT JOIN StorerSoDefault SSO WITH (NOLOCK) ON SSO.storerkey = ORDERS.consigneekey
   WHERE ORDERS.StorerKey = @c_StorerKey 
     AND PACKHEADER.Pickslipno = @c_Pickslipno
     AND PACKDETAIL.CartonNo BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)
   GROUP BY PACKHEADER.PickSlipNo, 
            PACKDETAIL.LabelNo, 
            ORDERS.ORDERKEY, 
            ORDERS.ExternOrderKey, 
            ORDERS.InvoiceNo,
            PACKDETAIL.CartonNo, 
            ORDERS.Userdefine04, 
            ORDERS.Consigneekey, 
            CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Company ELSE ORDERS.C_Company END, 
            CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address1 ELSE ORDERS.C_Address1 END, 
            CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address2 ELSE ORDERS.C_Address2 END , 
            CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address3 ELSE ORDERS.C_Address3 END, 
            CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.Address4 ELSE  ORDERS.C_Address4 END, 
            CASE WHEN ISNULL(C1.short,'N') = 'Y' THEN  STC.City ELSE  ORDERS.C_City END,		/* SOS31757 */
            PACKHEADER.Route, 
            ORDERS.C_Zip, 
            PACKHEADER.OrderKey,
            ORDERS.DeliveryDate,
            STORERCONFIG.SValue,
            ORDERS.BUYERPO, 
            ISNULL(SC2.SValue, '0'), 
            ISNULL(ORDERS.Door,''), 
            PACKDETAIL.DropID, ISNULL(CODELKUP.Short, 'N'),
            SSO.Route,ISNULL(C1.short,'N'), ORDERS.Loadkey, ISNULL(ORDERS.Notes,'')
QUIT_SP:

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 
END -- procedure

GO