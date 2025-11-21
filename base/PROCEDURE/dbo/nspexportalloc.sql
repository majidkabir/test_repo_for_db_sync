SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportAlloc                                     */
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

CREATE PROCEDURE [dbo].[nspExportAlloc] -- drop proc nspexportalloc
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_count int

   SELECT @n_count = COUNT(*)
   FROM Transmitlog
   WHERE transmitflag = '0'
   AND key3 in (select externorderkey from orderdetail)

   -- select candidate orders for export
   SELECT ORDERDETAIL.ExternOrderKey,
   ORDERS.BILLTOKEY,
   ORDERDETAIL.ExternLineNo ,
   ORDERDETAIL.Sku,
   Qtyallocated=sum(ORDERDETAIL.QtyAllocated)/pack.casecnt,
   EditDate =     RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, ORDERDETAIL.EditDate))),4)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, ORDERDETAIL.EditDate))),2)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, ORDERDETAIL.EditDate))),2),
   DeliveryDate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, ORDERS.DeliveryDate))),4)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, ORDERS.DeliveryDate))),2)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, ORDERS.DeliveryDate))),2),
   OrderDate  =   RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, ORDERS.OrderDate))),4)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, ORDERS.OrderDate))),2)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, ORDERS.OrderDate))),2)

   INTO #TEMP
   FROM ORDERDETAIL (nolock),
   ORDERS (nolock),
   TRANSMITLOG (nolock),
   PACK (nolock)
   WHERE  ORDERDETAIL.OrderKey = ORDERS.OrderKey
   AND    Orderdetail.qtyallocated > 0
   AND  	Orders.Orderkey = Orderdetail.Orderkey
   AND	Orderdetail.Orderlinenumber  = Transmitlog.Key2
   AND 	Transmitlog.Key1=Orderdetail.Orderkey
   AND	Transmitlog.Transmitflag = '0'
   AND  	Transmitlog.TableName = 'Orders'
   AND  	Orderdetail.qtypicked+orderdetail.shippedqty = 0
   AND    PACK.Packkey = 'U'+Orderdetail.SKU
   AND 	Orders.Type = 0
   AND    Orders.Externorderkey Not in (
   select distinct externorderkey
   from orderdetail (nolock)
   where externorderkey is not null
   and qtypicked+shippedqty > 0
   group by  externorderkey
   having count (*) > 1)

   GROUP BY ORDERDETAIL.ExternOrderKey,
   ORDERS.BILLTOKEY,
   ORDERDETAIL.ExternLineNo ,
   ORDERDETAIL.Sku,
   ORDERDETAIL.EditDate,
   ORDERS.DeliveryDate,
   ORDERS.OrderDate,
   PACK.Casecnt


   --  SELECT * FROM #Temp

   SELECT externorderkey,
   BilltoKey,
   ExternLineNo,
   SKU,
   sum(QtyAllocated),
   Editdate,
   DeliveryDate,
   OrderDate
   FROM #TEMP
   GROUP BY externorderkey,
   BilltoKey,
   ExternLineNo,
   SKU,
   Editdate,
   DeliveryDate,
   OrderDate
  Order by Externorderkey,externlineno


   DROP TABLE #Temp

END

GO