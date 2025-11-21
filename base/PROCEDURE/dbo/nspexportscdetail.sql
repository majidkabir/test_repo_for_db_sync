SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportSCDetail                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspExportSCDetail] -- drop proc nspExportSCDetail
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- select candidate orders for export
   SELECT distinct WhseID='01',
   MBOL.MBOLKey,
   Orders.BilltoKey,
   Consigneekey=Orders.BilltoKey ,
   Orderdetail.Externorderkey,
   Orderdetail.ExternLineno,
   SequenceNo = '1',
   Orderdetail.SKU,
   Loadplan.Route,
   weight = (sku.stdgrosswgt*((Orderdetail.Qtypicked+Shippedqty)/pack.casecnt)),
   IDS_Vehicle.weight,	 -- Modify By Ricky for IDSV5
   --	 Openqty=Orderdetail.Openqty,
   Orderflag = case
   when orderdetail.openqty <> orderdetail.qtypicked + orderdetail.shippedqty then 'P'
else 'F'
end,
Qty=(Orderdetail.Qtypicked+Shippedqty)/pack.casecnt,
Location = '11',
Mbol.VesselQualifier,
MBOL.CarrierKey,
DeliveryDate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, Orders.Deliverydate))),4) +
RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, Orders.Deliverydate))),2) +
RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, Orders.Deliverydate))),2),
ShipDate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, Orders.Userdefine06))),4)
+ RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, Orders.Userdefine06))),2)
+ RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, Orders.Userdefine06))),2),
Orders.Priority,
Qtypicked=(Orderdetail.Qtypicked+Shippedqty)/pack.casecnt,
--CreationDate = RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, MBOL.ADDDate))),2) + "/"
--             + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, MBOL.ADDDate))),2) + "/"
--	      + RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, MBOL.ADDDate))),4),
AddDate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, Orders.Adddate))),4)
+ RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, Orders.Adddate))),2)
+ RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, Orders.Adddate))),2),
Addtime = Orders.Adddate
--    INTO #TEMP1
FROM MBOL (nolock),
MBOLDETAIL (nolock),
LOADPLAN (nolock),
TRANSMITLOG (nolock),
ORDERS (nolock),
ORDERDETAIL (nolock),
IDS_VEHICLE (nolock),  -- Modify By Ricky for IDSV5
sku (nolock),
pack (nolock)
WHERE  MBOL.mbolkey=MBOLDETAIL.mbolkey
and 	MBOLDetail.orderkey=orderdetail.orderkey
and 	ORDERS.orderkey=ORDERDETAIL.orderkey
and 	MBOLDETAIL.mbolkey=Orderdetail.mbolkey
and mboldetail.loadkey = loadplan.loadkey
and 	TRANSMITLOG.key1 = MBOL.mbolkey
and transmitlog.key3 = orders.externorderkey
and    IDS_VEHICLE.vehiclenumber=MBOL.Vessel	-- Modify By Ricky for IDSV5
and orderdetail.sku = sku.sku
and orderdetail.storerkey = sku.storerkey
and sku.packkey = pack.packkey
AND	Transmitlog.Transmitflag = '0'
AND  	Transmitlog.TableName = 'MBOL'
AND 	orders.Status = '9'
and orders.type = '0'
END


GO