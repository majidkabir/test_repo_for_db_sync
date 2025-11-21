SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_Print_UCC_CartonLabel_48                        */
/* Creation Date: 06-Sep-2016                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-311 - Jet Sunny Shipping Label                          */
/*                                                                      */
/* Input Parameters: @cStorerKey - StorerKey,                           */
/*                   @cPickSlipNo - Pickslipno,                         */
/*                   @cFromCartonNo - From CartonNo,                    */
/*                   @cToCartonNo - To CartonNo,                        */
/*                   @cFilePath - File path that store the barcode      */
/*                                                                      */
/* Usage: Call by dw = r_dw_ucc_carton_label_48                         */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_UCC_CartonLabel_48] ( 
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10), 
   @cFromCartonNo NVARCHAR( 10),
   @cToCartonNo   NVARCHAR( 10))
  -- @cFilePath     NVARCHAR( 100) )
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
      ,@cFilePath            NVARCHAR( 100) 


   DECLARE @n_Address1Mapping INT
         , @n_C_CityMapping   INT
         , @n_ShowAddr2And3      INT            
         , @c_FromLFName         NVARCHAR(60)   
         , @c_ShowDeliveryDate   INT            

   SET @b_debug = 0

   SET @nFromCartonNo = CAST( @cFromCartonNo AS int)
   SET @nToCartonNo = CAST( @cToCartonNo AS int)
   
   SET @cUCC_LabelNo = ''
   SET @cUCC_FilePath_Barcode = ''
   SET @cFilePath = ''

   SELECT @cUCC_LabelNo = LabelNo
   FROM PACKDETAIL (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo 
   AND StorerKey = @cStorerKey 
   AND CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo
   GROUP BY LabelNo

   IF RIGHT(dbo.fnc_RTrim(dbo.fnc_LTrim(@cFilePath)), 1) <> '\'
      SET @cFilePath = dbo.fnc_RTrim(dbo.fnc_LTrim(@cFilePath)) + '\'

   -- Add file path
   SET @cUCC_FilePath_Barcode = dbo.fnc_RTrim(dbo.fnc_LTrim(@cFilePath)) + dbo.fnc_RTrim(dbo.fnc_LTrim(@cUCC_LabelNo)) + '.bmp' 


   SET @n_Address1Mapping = 0
   SET @n_C_CityMapping   = 0

   SELECT @n_Address1Mapping = MAX(CASE WHEN Code = 'C_ADDRESS1' THEN 1 ELSE 0 END)
        , @n_C_CityMapping   = MAX(CASE WHEN Code = 'C_CITY'     THEN 1 ELSE 0 END)
   FROM CODELKUP IWHT (NOLOCK)
   WHERE ListName = 'UCCLBLTBL'
   AND StorerKey  = @cStorerKey 

   SET @n_ShowAddr2And3 = 0
   SET @c_FromLFName  = ''
   SET @c_ShowDeliveryDate = 0
   SELECT @n_ShowAddr2And3 = ISNULL(MAX(CASE WHEN Code = 'ShowAddr2And3' THEN 1 ELSE 0 END),0)
        , @c_FromLFName  = ISNULL(MAX(CASE WHEN Code = 'FromLFName'  THEN UDF01 ELSE '' END),'')
        , @c_ShowDeliveryDate = ISNULL(MAX(CASE WHEN Code = 'ShowDeliveryDate' THEN 1 ELSE 0 END),0)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'REPORTCFG'
   AND CL.Storerkey = @cStorerKey
   AND CL.Long = 'r_dw_ucc_carton_label_48' 
   AND ISNULL(CL.Short,'') <> 'N'  
   
   SELECT PACKHEADER.PickSlipNo, 
       PACKDETAIL.LabelNo, 
       ORDERS.InvoiceNo as InvoicNo, 
       ORDERS.ExternOrderKey,
       CASE ORDERS.Type WHEN 'D' THEN 'D' WHEN 'R' THEN 'R' ELSE '' END As CartonType, 
       PACKDETAIL.CartonNo, 
       (SELECT ISNULL(MAX(P2.CartonNo), '') 
        FROM PACKDETAIL P2 (NOLOCK) 
        WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo) AS CartonMax, 
       SUM(PACKDETAIL.Qty) AS Qty, 
       ORDERS.C_Company,
       c_Address1  = ISNULL(RTRIM(ORDERS.C_Address1),'') ,
       c_City      = MAX(CASE WHEN @n_C_CityMapping   = 1 THEN ISNULL(RTRIM(ORDERS.C_Address2),'')  
                                                        ELSE ISNULL(RTRIM(ORDERS.C_City),'') END), 
       ORDERS.C_Zip,
       ORDERS.C_Country,
       ORDERS.B_Address1, 
       PACKHEADER.Route,
       MAX(IDS.Company)  CompanyFrom,
       MAX(IDS.Address1) Address1From,
       MAX(IDS.Address2) Address2From,
       MAX(ISNULL(IDS.Address3,'')) Address3From,
       GetDate() PrintDate,
       @cUCC_FilePath_Barcode as ucc_filepath_barcode,
       FACILITY.Address1 as FacilityAddress,
       CODELKUP.Short as Brand
      ,showaddr2and3 = @n_ShowAddr2And3
      ,c_Address2 = ISNULL(MAX(CASE WHEN @n_ShowAddr2And3 = 1 THEN ISNULL(RTRIM(ORDERS.C_Address2),'') ELSE '' END),'')
      ,c_Address3 = ISNULL(MAX(CASE WHEN @n_ShowAddr2And3 = 1 THEN ISNULL(RTRIM(ORDERS.C_Address3),'') ELSE '' END),'')
      ,FromLFName = @c_FromLFName
      ,showdeliverydate = @c_ShowDeliveryDate 
      ,ORDERS.DeliveryDate
		,ORDRoute = ORDERS.Route
		,Orderkey = PACKHEADER.Orderkey 
		,ORDERS.Consigneekey
		,ORDERS.Notes
  FROM ORDERS ORDERS (NOLOCK) 
  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
  JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)
  JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
  LEFT OUTER JOIN STORER STORERContact (NOLOCK) ON (STORERContact.Type = '2' AND 
                                                    STORERContact.StorerKey = ORDERS.ConsigneeKey)  
  LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = 'IDS')
  LEFT OUTER JOIN FACILITY (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility)            
  LEFT OUTER JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.LISTNAME = 'VFBRAND')
                                        AND(CODELKUP.Storerkey= ORDERS.Storerkey)
                                        AND(CODELKUP.Code= ORDERS.Userdefine01) 
 WHERE ORDERS.StorerKey = @cStorerKey 
   AND PACKHEADER.PickSlipNo = @cPickSlipNo 
   AND PACKDETAIL.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo 
 GROUP BY PACKHEADER.PickSlipNo, 
         PACKDETAIL.LabelNo, 
         ORDERS.InvoiceNo, 
         ORDERS.ExternOrderKey, 
         PACKDETAIL.CartonNo, 
         ORDERS.C_Company, 
         ORDERS.C_Address1, 
         ORDERS.C_City, 
         ORDERS.B_Address1, 
         ORDERS.C_Country, 
         PACKHEADER.Route, 
         ORDERS.C_Zip, 
         ORDERS.Type,
         FACILITY.Address1,
         CODELKUP.Short
       , ORDERS.DeliveryDate  
       ,ORDERS.Route
		,PACKHEADER.Orderkey 
		,ORDERS.Consigneekey
		,ORDERS.Notes     


END

GO