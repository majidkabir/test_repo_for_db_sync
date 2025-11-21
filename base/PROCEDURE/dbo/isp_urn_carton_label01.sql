SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_URN_Carton_Label01                             */
/* Creation Date: 29-APR-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Rick Liew                                                */
/*                                                                      */
/* Purpose: URN Carton Label01                                          */
/*                                                                      */
/* Called By:  RDT Spooler                                              */ 
/*                                                                      */
/* Parameters: (Input)  @c_LabelCode   = URN Label                      */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Apr-2009  Rick Liew 1.0   Initial created for SOS#133231          */
/* 21-Jun-2009  James     1.1   Bug fix (james01)                       */
/* 03-Mar-2010  GTGOH     1.2   SOS162593 - Print UPC from SKU.AltSKU   */
/*                                          (Goh01)                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_URN_Carton_Label01]
   @c_LabelCode01   NVARCHAR(30), @c_LabelCode02 NVARCHAR(30)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @c_externorderkey    NVARCHAR(6),
            @c_consigneekey      NVARCHAR(4),
            @c_Intermodalvehicle NVARCHAR(3),
            @c_UrnNo             NVARCHAR(6),
            @c_Busr5             NVARCHAR(5),
            @c_CodeItemClass     NVARCHAR(3),
            @c_qty               NVARCHAR(3),
            @c_BarcodeEnd        NVARCHAR(2),
            @c_ItemClass         NVARCHAR(10),
            @c_Company           NVARCHAR(45),
            @c_LabelCode         NVARCHAR(60), -- No Space
            @c_LabelCodehr       NVARCHAR(50), -- With Space
            @c_LabelName         NVARCHAR(45) -- Storer.Company, find from Consigneekey
            ,@c_AltSku            NVARCHAR(20) -- GOH01
 
   SET @c_LabelCode = RTRIM(@c_LabelCode01) + RTRIM(@c_LabelCode02)

   SET @c_consigneekey = Substring (@c_LabelCode,1,4) 
   SET @c_Intermodalvehicle = Substring (@c_LabelCode,5,3)  
   SET @c_UrnNo = Substring (@c_LabelCode,8,6) 
   SET @c_Busr5 = Substring (@c_LabelCode,14,5)  
-- SET @c_CodeItemClass = Substring (@c_LabelCode,19,3) (james01) no need display dept prefix
   SET @c_CodeItemClass = RIGHT('000'+RIGHT(ISNULL(Substring (@c_LabelCode,19,3),''),2),3)
   SET @c_externorderkey = Substring (@c_LabelCode,22,6)  
   SET @c_qty = Substring (@c_LabelCode,28,3) 
   SET @c_BarcodeEnd = Substring (@c_LabelCode,31,2) 

-- GOH01 Start
	SELECT @c_AltSku = SKU.AltSKU FROM PACKINFO PINFO (NOLOCK)
	JOIN PACKDETAIL PD (NOLOCK)
	ON PD.PickSlipNo = PINFO.PickSlipNo	AND PD.CartonNo = PINFO.CartonNo
	JOIN SKU SKU (NOLOCK) ON SKU.SKU = PD.SKU
	WHERE PINFO.RefNo = @c_LabelCode
-- GOH01 End

-- SELECT  TOP 1 @c_ItemClass = SKU.Itemclass, @c_Company = Storer.Company  FROM ORDERDETAIL (NOLOCK)  (james01)
-- JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
-- LEFT JOIN STORER (NOLOCK) ON (SKU.Busr5 = STORER.Storerkey)
-- WHERE ORDERDETAIL.ExternOrderkey = @c_externorderkey

	SELECT @c_Company = Storer.Company FROM Storer Storer WITH (NOLOCK)	--(james01)
	JOIN SKU SKU WITH (NOLOCK) ON (Storer.Storerkey = SKU.Busr5)
	WHERE SKU.Busr5 = @c_Busr5
	 
   SELECT TOP 1 @c_LabelName = StorerConsignee.Company FROM Storer StorerConsignee (NOLOCK)
   WHERE StorerConsignee.Storerkey = @c_consigneekey

   SET @c_ItemClass = Substring (@c_LabelCode,19,3) -- (james01)
   
   SELECT 1 As pkgno, 
   @c_consigneekey As Consigneekey,
   @c_externorderkey As ExternOrderKey,
   @c_ItemClass As ItemClass,
   @c_Busr5 As Busr5,
   @c_Company As Company,
   @c_Intermodalvehicle As Intermodalvehicle,
   @c_qty As Qty,
   @c_UrnNo As Urnno,
   1 As TotalPkgs,
   (RTRIM(@c_consigneekey)+RTRIM(@c_Intermodalvehicle)+RTRIM(@c_UrnNo)+
   ISNULL(RTRIM(@c_Busr5),'')+RIGHT('000'+RIGHT(ISNULL(RTRIM(@c_CodeItemClass),''),3),3)+
   RTRIM(@c_externorderkey)+
   RIGHT(RTRIM(CONVERT(char(3),@c_qty)),3)+ @c_BarcodeEnd) AS labelcode,
   (RTRIM(@c_consigneekey)+' '+RTRIM(@c_Intermodalvehicle)+' '+RTRIM(@c_UrnNo)+' '+
   ISNULL(RTRIM(@c_Busr5),'')+' '+RIGHT('000'+RIGHT(ISNULL(RTRIM(@c_CodeItemClass),''),3),3)+' '+
   RTRIM(@c_externorderkey)+' '+
   RIGHT(RTRIM(CONVERT(char(3),@c_qty)),3)+' '+@c_BarcodeEnd) AS labelcodehr,
   @c_LabelName
	,@c_AltSku AS AltSKU		--GOH01
END -- End PROC

GO