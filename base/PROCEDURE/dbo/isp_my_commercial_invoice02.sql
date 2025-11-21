SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_my_commercial_invoice02                        */
/* Creation Date: 16-NOV-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CHONG                                                    */
/*                                                                      */
/* Purpose: WMS-18462 [MY] - SBUXM - add MBOLKEY to invoice as optional */
/*                    retrieval argument - IML - CR                     */
/*                                                                      */
/* Called By: Report module (r_my_commercial_invoice02)                 */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 01-Dec-2021  CHONGCS   1.0   DevOps Combine Script                   */ 
/* 06-Dec-2021  CSCHONG   1.1   WMS-18462 chane SQL to SP (CS01)        */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_my_commercial_invoice02]
 @c_loadkey       NVARCHAR(20) ,
 @c_orderkey      NVARCHAR(20) = '',
 @c_mbolkey       NVARCHAR(20) = ''

AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  

   if ISNULL(@c_mbolkey,'') = '' set @c_mbolkey = ''
   if ISNULL(@c_orderkey,'') = '' set @c_orderkey = ''


   SELECT ST.StorerKey, 
	   ST.Company,
	   Address1 = Upper(ST.Address1),
	   Address2 = Upper(ST.Address2),
	   Address3 = Upper(ST.Address3),
	   ST.Zip, 
	   City = Upper(ST.City),
	   ST.Phone1, 
	   DeliveryPlace = Upper(O.DeliveryPlace), 
	   --MB.Remarks, //WMS-17274
	   C_City = Upper(O.C_City),
	   O.C_Company,
	   C_Address1 = Upper(O.C_Address1),
	   C_Address2 = Upper(O.C_Address2),
	   C_Address3 = Upper(O.C_Address3),
	   O.C_Zip,
	   DeliveryDate = Upper(FORMAT(O.DeliveryDate, 'dd-MMM-yyyy')),
	   --MB.MbolKey, 
        OD.Sku, S.DESCR, S.SKUGROUP,
	   O.OrderKey,
	   ExpiryDate = Upper(FORMAT(LA.Lottable04, 'dd-MMM-yyyy')),
	   UOM = LTrim(RTrim(P.PackUOM3)),
	   PickQty = CASE WHEN O.Status = '2' THEN OD.QtyAllocated
						    WHEN O.Status = '5' THEN OD.QtyPicked
						    WHEN O.Status = '9' THEN OD.ShippedQty
							ELSE 1 END, --WMS-17274
	   M3 = S.STDCUBE * PD.Qty,
	   TotalKG = S.STDGROSSWGT * PD.Qty,
	   S.Price,
	   TotalAmount_RM = PD.Qty * S.Price,
        O.LoadKey,
	   O.Externorderkey --WMS-17274
FROM dbo.V_ORDERS O with (nolock) Inner Join dbo.V_ORDERDETAIL OD with (nolock) ON OD.StorerKey = O.StorerKey and OD.OrderKey = O.OrderKey and OD.Loadkey = O.Loadkey
     Inner Join dbo.V_PICKDETAIL PD with (nolock) ON PD.StorerKey = OD.StorerKey and PD.OrderKey = OD.OrderKey and PD.SKU = OD.SKU and PD.OrderLineNumber = OD.OrderLineNumber 
	 Inner Join dbo.V_SKU S with (nolock) ON S.StorerKey = PD.StorerKey and S.SKU = PD.SKU
	 Inner Join dbo.V_PACK P with (nolock) ON P.PackKey = S.PackKey
	 --Inner Join dbo.V_MBOL MB with (nolock) ON MB.MbolKey = O.MbolKey //WMS-17274
	 Inner Join dbo.V_STORER ST with (nolock) ON ST.StorerKey = O.StorerKey
	 Inner Join dbo.V_LOTATTRIBUTE LA with (nolock) ON LA.StorerKey = PD.StorerKey and LA.Lot = PD.Lot and LA.Sku = PD.Sku
	 Inner Join dbo.V_LOADPLANDETAIL LD with (nolock) ON  LD.Orderkey = O.orderkey
WHERE O.StorerKey = 'SBUXM' 
--AND O.Status = '9' 
AND O.SOStatus <> 'CANC' 
--AND OD.ShippedQty <> 0 
AND O.LoadKey LIKE '%' + IsNull(@c_loadkey, '')
--OR O.OrderKey = @c_OrderKey
AND O.OrderKey = CASE WHEN ISNULL(@c_orderkey,'') <> '' THEN @c_orderkey ELSE O.OrderKey END --CS01
AND O.MBOLKey = CASE WHEN ISNULL(@c_mbolkey,'') <> '' THEN @c_mbolkey ELSE O.MBOLKey END --CS01
   
   
  
END

GO