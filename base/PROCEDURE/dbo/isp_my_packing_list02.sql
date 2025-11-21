SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_my_packing_list02                              */
/* Creation Date: 16-NOV-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: MINGLE                                                   */
/*                                                                      */
/* Purpose: WMS-17873 [MY]-SBUXM Packing List-[CR]                      */
/*                                                                      */
/* Called By: Report module (r_my_packing_list02     )                  */
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
/* 22-Nov-2021  Mingle    1.0   DevOps Combine Script                   */ 
/* 03-Jan-2022  ian       2.0   fix date issue                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_my_packing_list02]
 @c_mbolkey       NVARCHAR(20),
 @c_loadkey       NVARCHAR(20) = '',
 @c_orderkey      NVARCHAR(20) = '',
 --@dt_deliverydate DATETIME = '',
 @c_deliverydate NVARCHAR(20) = '',
 @c_route         NVARCHAR(20) = ''

AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  

   if ISNULL(@c_mbolkey,'') = '' set @c_mbolkey = ''
   if ISNULL(@c_loadkey,'') = '' set @c_loadkey = ''
   if ISNULL(@c_orderkey,'') = '' set @c_orderkey = ''
   --if ISNULL(@dt_deliverydate,'') = '' set @dt_deliverydate = '' 
   if ISNULL(@c_deliverydate,'') = '' set @c_deliverydate = ''
   if ISNULL(@c_route,'') = '' set @c_route = ''

   SELECT ST.StorerKey, 
	   ST.Company,
	   Address1 = Upper(ST.Address1),
	   Address2 = Upper(ST.Address2),
	   Address3 = Upper(ST.Address3),
	   ST.Zip, 
	   City = Upper(ST.City),
	   ST.Phone1, 
	   DeliveryPlace = Upper(O.DeliveryPlace), 
	   --MB.Remarks, 
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
							ELSE 1 END, 
	   M3 = S.STDCUBE * PD.Qty,
	   TotalKG = S.STDGROSSWGT * PD.Qty,
	   S.Price,
	   TotalAmount_RM = PD.Qty * S.Price,
        O.Externorderkey 
   FROM dbo.V_ORDERS O with (nolock) Inner Join dbo.V_ORDERDETAIL OD with (nolock) ON OD.StorerKey = O.StorerKey and OD.OrderKey = O.OrderKey and OD.Loadkey = O.Loadkey 
     Inner Join dbo.V_PICKDETAIL PD with (nolock) ON PD.StorerKey = OD.StorerKey and PD.OrderKey = OD.OrderKey and PD.SKU = OD.SKU and PD.OrderLineNumber = OD.OrderLineNumber 
	 Inner Join dbo.V_SKU S with (nolock) ON S.StorerKey = PD.StorerKey and S.SKU = PD.SKU
	 Inner Join dbo.V_PACK P with (nolock) ON P.PackKey = S.PackKey
	 --Inner Join dbo.V_MBOL MB with (nolock) ON MB.MbolKey = O.MbolKey 
	 Inner Join dbo.V_STORER ST with (nolock) ON ST.StorerKey = O.StorerKey
	 Inner Join dbo.V_LOTATTRIBUTE LA with (nolock) ON LA.StorerKey = PD.StorerKey and LA.Lot = PD.Lot and LA.Sku = PD.Sku
	 Left Outer Join dbo.V_RouteMaster RM with (nolock) ON RM.Route = O.Route
	 INNER Join dbo.V_Loadplandetail LPD with (nolock) ON LPD.Orderkey = O.Orderkey
   WHERE O.MBOLKEY = CASE WHEN ISNULL(@c_mbolkey, '') = '' THEN O.MBOLKEY ELSE @c_mbolkey END
   AND LPD.LOADKEY = CASE WHEN ISNULL(@c_loadkey, '') = '' THEN LPD.LOADKey ELSE @c_loadkey END
   AND O.OrderKey = CASE WHEN ISNULL(@c_orderkey, '') = '' THEN O.OrderKey ELSE @c_orderkey END
   --AND Convert(VarChar(10), Convert(Date, O.DeliveryDate)) = CASE WHEN ISNULL(@c_deliverydate, '') = '' THEN O.DeliveryDate ELSE @c_deliverydate END
   --AND O.DeliveryDate = CASE WHEN ISNULL(@c_deliverydate, '') = '' THEN Convert(VarChar(20), Convert(Date, O.DeliveryDate)) ELSE @c_deliverydate END --ian2.0
   AND Convert(VarChar(20), Convert(Date, O.DeliveryDate)) = CASE WHEN ISNULL(@c_deliverydate, '') = '' THEN Convert(VarChar(20), Convert(Date, O.DeliveryDate)) ELSE @c_deliverydate END --ian2.0
   --AND Convert(VarChar(10), Convert(Date, O.DeliveryDate)) = CASE WHEN ISNULL(@c_deliverydate, '') = '' THEN Convert(VarChar(10), Convert(Date, O.DeliveryDate)) ELSE @c_deliverydate END
   AND (Case When IsNull(RM.Descr, '') <> '' Then RM.Descr Else O.Route End) LIKE '%' + IsNull(@c_route, '')
   --AND O.Route = (Case When IsNull(RM.Descr, '') <> '' Then RM.Descr Else @c_route End)
   --AND O.StorerKey = 'SBUXM' 
   --AND O.Status >= '2'  
   --AND O.Status = '9' 
   AND O.SOStatus <> 'CANC' 
   --AND OD.ShippedQty <> 0 
   AND OD.QtyAllocated + OD.QtyPicked +OD.ShippedQty > 0   
   ORDER BY o.ExternOrderKey,OD.Sku
   
   
  
END

GO