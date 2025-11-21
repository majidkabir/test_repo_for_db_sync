SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store Procedure: isp_Print_UCC_CartonLabel_13             							*/
/* Creation Date: 28-Oct-2009                                    						*/
/* Copyright: IDS																						*/
/* Written by: GTGoh                                     								*/
/*																											*/
/* Purpose:  CN TBL - Print UCC Carton Label (SOS#151274)								*/
/*                  - Duplicate from isp_Print_UCC_CartonLabel							*/
/*																											*/   
/* Input Parameters: @cStorerKey - StorerKey,												*/
/*                   @cPickSlipNo - Pickslipno,												*/
/*                   @cFromCartonNo - From CartonNo,										*/
/*                   @cToCartonNo - To CartonNo,											*/
/*                   @cFilePath - File path that store the barcode					*/
/*																											*/
/* Usage: Call by dw = r_dw_ucc_carton_label_13												*/
/*																											*/
/* PVCS Version: 1.0																					*/
/*																											*/
/* Version: 5.4																						*/
/*																											*/
/* Data Modifications:																				*/
/*																											*/
/* Updates:																								*/
/* Date         Author        Purposes															*/
/* 30/12/2009	 GTGOH			SOS#157508 - Modify to print Total Carton after    */
/*										Pack Confirm													*/
/*********************************************************************************/

CREATE PROC [dbo].[isp_Print_UCC_CartonLabel_13] ( 
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10), 
   @cFromCartonNo NVARCHAR( 10),
   @cToCartonNo   NVARCHAR( 10),
   @cFilePath     NVARCHAR( 100) )
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

   SET @nFromCartonNo = CAST( @cFromCartonNo AS int)
   SET @nToCartonNo = CAST( @cToCartonNo AS int)
   
   SET @cUCC_LabelNo = ''
   SET @cUCC_FilePath_Barcode = ''

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

   SELECT PACKHEADER.PickSlipNo, 
		 PACKDETAIL.LabelNo, 
		 ORDERS.InvoiceNo, 
		 ORDERS.ExternOrderKey,
		 CASE ORDERS.Type WHEN 'D' THEN 'D' WHEN 'R' THEN 'R' ELSE '' END As CartonType, 
		 PACKDETAIL.CartonNo, 
		 (SELECT ISNULL(MAX(P2.CartonNo), '') 
		  FROM PACKDETAIL P2 (NOLOCK) 
		  WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo) AS CartonMax, 
		 SUM(PACKDETAIL.Qty) AS Qty, 
		 ORDERS.BillToKey,
		 ORDERS.ConsigneeKey, 	
		 ORDERS.C_Company, 
		 ORDERS.C_Address1, 
		 ORDERS.C_Address2, 
		 ORDERS.C_Address3, 
		 ORDERS.C_Address4, 
		 ORDERS.C_City, 
		 ORDERS.C_Zip,
		 ORDERS.C_Country,
--		 ORDERS.B_Address1, 
		 PACKHEADER.Route,
		 MAX(IDS.Company)  CompanyFrom,
		 MAX(IDS.Address1) Address1From,
		 MAX(IDS.Address2) Address2From,
		 MAX(IDS.Address3) Address3From,
		 GetDate() PrintDate,
		 @cUCC_FilePath_Barcode
		 ,PACKHEADER.Status		--SOS#157508
  FROM ORDERS ORDERS (NOLOCK) 
  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
  JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)
  JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
  LEFT OUTER JOIN STORER STORERContact (NOLOCK) ON (STORERContact.Type = '2' AND 
                                                    STORERContact.StorerKey = ORDERS.ConsigneeKey)  
  LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = 'IDS')
 WHERE ORDERS.StorerKey = @cStorerKey 
	AND PACKHEADER.PickSlipNo = @cPickSlipNo 
	AND PACKDETAIL.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo 
 GROUP BY PACKHEADER.PickSlipNo, 
			PACKDETAIL.LabelNo, 
			ORDERS.InvoiceNo, 
			ORDERS.ExternOrderKey, 
			PACKDETAIL.CartonNo, 
 		   ORDERS.BillToKey,
		   ORDERS.ConsigneeKey, 	
		   ORDERS.C_Company, 
		   ORDERS.C_Address1, 
		   ORDERS.C_Address2, 
		   ORDERS.C_Address3, 
		   ORDERS.C_Address4, 
		   ORDERS.C_City, 
--		   ORDERS.B_Address1, 
		   ORDERS.C_Country, 
		   PACKHEADER.Route, 
			ORDERS.C_Zip, 
			ORDERS.Type,
			PACKHEADER.Status		--SOS#157508 
END

GO