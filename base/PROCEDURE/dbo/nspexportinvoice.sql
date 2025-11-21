SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportInvoice                                   */
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
/* 2007-07-16  TLTING      SQL2005, Status = 9 put '9'                  */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspExportInvoice Script Date: 8/31/01 11:07:02 AM ******/
CREATE PROCEDURE [dbo].[nspExportInvoice] -- drop proc nspExportInvoice
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT Invoiceno=dbo.fnc_RTrim(Orders.Invoiceno),
   DeliveryDate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, MBOLDetail.DeliveryTime))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, MBOLDetail.DeliveryTime))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, MBOLDetail.DeliveryTime))),2),
   CurrentDate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2) ,
   Editdate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, Orders.editdate))),4) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, orders.editdate))),2) + '/'+
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, orders.editdate))),2)

   INTO #TEMP1
   FROM MBOL WITH (NOLOCK), MBOLDetail WITH (NOLOCK),
   ORDERS WITH (NOLOCK)
   WHERE  MBOL.MBOLKey=MBOLDetail.MBOLKey
   and MBOLdetail.Orderkey=Orders.Orderkey
   AND MBOL.Status = '9'
   and Orders.Facility = 'ACSIE'
   and Orders.Invoiceno is not null
   --  SELECT * FROM #Temp1
   SELECT Invoiceno+Deliverydate
   FROM #TEMP1
   Where Currentdate=Editdate
   GROUP BY  Invoiceno+deliverydate
   DROP TABLE #Temp1
END


GO