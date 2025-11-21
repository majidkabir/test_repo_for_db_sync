SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspdeliveryrep                                     */
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

CREATE PROCEDURE [dbo].[nspdeliveryrep]   --nspdeliveryrep '11/28/01','12/28/01','12/28/01'
(@d_orderdatestart datetime,
@d_orderdateend   datetime,
@d_deliverydate datetime)

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   select 	deliverydate=RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, 		b.orderdate))),4) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, 		b.orderdate))),2) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, 		b.orderdate))),2),
   b.invoiceno,
   b.invoiceamount,
   deliverydate=RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, 		a.deliverydate))),4) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, 		a.deliverydate))),2) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, 		a.deliverydate))),2),
   deliverydate=RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, 		a.deliverytime))),4) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, 		a.deliverytime))),2) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, 		a.deliverytime))),2),
   b.billtokey,
   b.storerkey
   from mboldetail a, orders b
   where a.mbolkey=b.mbolkey
   and a.orderkey=b.orderkey
   and a.orderdate between @d_orderdatestart and @d_orderdateend
   and (a.deliverydate is null
   or a.deliverydate = ''
   or a.deliverydate > @d_deliverydate)
   and b.type = 'INV'
   order by b.orderdate, b.invoiceno, b.storerkey, b.billtokey

END


GO