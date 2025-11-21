SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*********************************************************************************/
/* Store Procedure: isp_Print_Invoice_GSK                    							*/
/* Creation Date: 16-Mar-2010                                    						*/
/* Copyright: IDS																						*/
/* Written by: GTGoh                                     								*/
/*																											*/
/* Purpose:  GSKMY - Print GSK Invoice (SOS#164017)									   */
/*																											*/   
/* Input Parameters: @cStorerKey - StorerKey,												*/
/*                   @cfacility	- Facility,													*/
/*                   @cstartorder - From OrderNo,		    								*/
/*                   @cendorder	 - To OrderNo,			    								*/
/*                   @cstartinvoice - From InvoiceNo,	    								*/
/*                   @cendinvoice - To InvoiceNo,		    								*/
/*                   @cstartmboldt - From MBOL Date,	    								*/
/*                   @cendmboldt	 - To MBOL Date		    								*/
/*																											*/
/* Usage: Call by dw = r_dw_invoice_gsk														*/
/*																											*/
/* PVCS Version: 1.0																					*/
/*																											*/
/* Version: 5.4																						*/
/*																											*/
/* Data Modifications:																				*/
/*																											*/
/* Updates:																								*/
/* Date         Author        Purposes															*/
/* 16-Dec-2018  TLTING01 1.1  missing nolock                                     */
/*********************************************************************************/

CREATE PROC [dbo].[isp_Print_Invoice_GSK] ( 
   @cStorerKey    NVARCHAR( 15),
   @cfacility     NVARCHAR( 5), 
   @cstartorder   NVARCHAR( 10),
   @cendorder     NVARCHAR( 10),
   @cstartinvoice NVARCHAR( 20), 
	@cendinvoice NVARCHAR( 20),
	@cstartmboldt  datetime,
	@cendmboldt		datetime )
AS
BEGIN
	SET NOCOUNT ON 
   SET ANSI_NULLS OFF
	SET QUOTED_IDENTIFIER OFF 
	SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE	@b_debug int

	SET @b_debug = 0
   SET @cEndMbolDt = CONVERT(DATETIME, CONVERT(VARCHAR(20), @cEndMbolDt, 112) + " 23:59:59:999" ) -- (ChewKP01)
  
   
	SELECT DISTINCT ORDERS.ConsigneeKey,   
		ORDERS.InvoiceNo,
		CASE Orders.Type    
			WHEN 'SO' THEN CODELKUP2.Short 
			WHEN 'CO' THEN CODELKUP2.Short 
			WHEN 'SE' THEN CODELKUP2.Short 
			ELSE Orders.Type  
		END AS DocType,
		ORDERS.Type,   
		--CODELKUP2.Short,
		ORDERS.UserDefine01,   
		MBOL.EditDate,   
		ORDERS.OrderDate,   
		ORDERS.ExternPOKey,   
		ORDERS.Salesman,   
		ORDERDetail.UserDefine06,   
		ORDERS.C_contact1,   
		ORDERS.C_Company,   
		ORDERS.C_Address1,   
		ORDERS.C_Address2,   
		ORDERS.C_Address3,   
		STORER.B_Company,   
		STORER.B_Address1,   
		STORER.B_Address2,   
		STORER.B_Address3,   
		STORER.B_Address4,   
		CAST(ISNULL(ORDERS.Notes,'') AS NVARCHAR(200)) AS Notes,   
		CAST(ISNULL(ORDERS.Notes2,'') AS NVARCHAR(200)) AS Notes2,   
		ORDERS.UserDefine02,   
		SKU.Sku,   
		SKU.DESCR,   
		(SUM(PICKDETAIL.Qty) - (SUM(PICKDETAIL.Qty) % CAST(PACK.InnerPack AS Int)))/ PACK.InnerPack AS Qty ,   
		SUM(PICKDETAIL.Qty) % CAST(PACK.InnerPack AS INT) AS InnerPack, 
		(ORDERDETAIL.UnitPrice * PACK.InnerPack) AS UnitPrice,   
		LOTATTRIBUTE.Lottable02,   
		LOTATTRIBUTE.Lottable04,   
		CAST(ISNULL(CODELKUP.Notes,'') AS NVARCHAR(5)) AS days,   
		CAST(ISNULL(CODELKUP.Notes2,'') AS NVARCHAR(5)) AS percentage,
		(SUM(PICKDETAIL.Qty) * ORDERDETAIL.UnitPrice) AS TotPrice,
		ISNULL(STORER.SUSR5, '') AS SUSR5
		
	FROM ORDERS  (NOLOCK)
		JOIN ORDERDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey  ) 
		JOIN PICKDETAIL (NOLOCK) ON ( PICKDETAIL.StorerKey = ORDERDETAIL.StorerKey
		AND PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey 
		AND PICKDETAIL.SKU = ORDERDETAIL.SKU   AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)  
		JOIN LOTATTRIBUTE (NOLOCK) ON ( LOTATTRIBUTE.StorerKey = PICKDETAIL.StorerKey  --tlting01
		AND LOTATTRIBUTE.SKU = PICKDETAIL.SKU 
		AND LOTATTRIBUTE.LOT = PICKDETAIL.LOT) 
		JOIN MBOL (NOLOCK) ON ( MBOL.MBOLKey = ORDERDETAIL.MBOLKey )  
		JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey  
		AND SKU.SKU = ORDERDETAIL.SKU )
		JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey )
		JOIN STORER (NOLOCK) ON ( STORER.StorerKey = ORDERS.ConsigneeKey )   
		JOIN CODELKUP (NOLOCK) ON ( CODELKUP.Code = ORDERS.PmtTerm 
		AND  CODELKUP.ListName = 'PMTTERM')  
		JOIN CODELKUP CODELKUP2 (NOLOCK) ON ( CODELKUP2.Code = ORDERS.Type
		AND  CODELKUP2.ListName = 'OrderType')  
		
WHERE ORDERS.Status = '9' 
		AND ORDERS.StorerKey = @cstorerkey 
		AND ORDERS.Facility = @cfacility
		AND (ORDERS.OrderKey >= @cstartorder AND ORDERS.OrderKey <= @cendorder 
		AND  ORDERS.InvoiceNo >= @cstartinvoice AND ORDERS.InvoiceNo <= @cendinvoice )
		AND MBOL.EditDate >= @cstartmboldt AND MBOL.EditDate <= @cendmboldt 
	GROUP BY ORDERS.ConsigneeKey,   
		ORDERS.InvoiceNo,   
		ORDERS.Type,   
		CODELKUP2.Short,
		ORDERS.UserDefine01,   
		MBOL.EditDate,   
		ORDERS.OrderDate,   
		ORDERS.ExternPOKey,   
		ORDERS.Salesman,   
		ORDERDetail.UserDefine06,   
		ORDERS.C_contact1,   
		ORDERS.C_Company,   
		ORDERS.C_Address1,   
		ORDERS.C_Address2,   
		ORDERS.C_Address3,   
		STORER.B_Company,   
		STORER.B_Address1,   
		STORER.B_Address2,   
		STORER.B_Address3,   
		STORER.B_Address4,   
		CAST(ISNULL(ORDERS.Notes,'') AS NVARCHAR(200)),   
		CAST(ISNULL(ORDERS.Notes2,'') AS NVARCHAR(200)),   
		ORDERS.UserDefine02,   
		SKU.Sku,   
		SKU.DESCR,   
		PACK.InnerPack, 
		ORDERDETAIL.UnitPrice,   
		LOTATTRIBUTE.Lottable02,   
		LOTATTRIBUTE.Lottable04,   
		CAST(ISNULL(CODELKUP.Notes,'') AS NVARCHAR(5)),   
		CAST(ISNULL(CODELKUP.Notes2,'') AS NVARCHAR(5)),
		STORER.SUSR5

END

GO