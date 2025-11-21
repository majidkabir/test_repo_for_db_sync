SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/  
/* Stored Procedure: nspSalesOrdProcess                                 */  
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
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspSalesOrdProcess] (  
@c_facilitystart NVARCHAR(5),  
@c_facilityend NVARCHAR(5),  
@c_storerstart NVARCHAR(15),  
@c_storerend NVARCHAR(15),  
@d_editdatestart DATETIME,  
@d_editdateend DATETIME ,  
@c_skustart NVARCHAR(20),  
@c_skuend NVARCHAR(20)  
)  
AS  
BEGIN  
  
   Create table #RESULT (  
   externorderkey NVARCHAR(50),  --tlting_ext  
   company NVARCHAR(45) null ,  
   sku NVARCHAR(20),  
   qty int,  
   weight int null,  
   editdate datetime,  
   facility NVARCHAR(5) null,  
   returnqty int null  
   )  
  
   BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
        
  
      SELECT Orders.externorderkey, Orders.c_company, OrderDetail.sku ,Orderdetail.shippedqty, Loadplan.weight, Orderdetail.editdate,  
      Orders.Facility  
      INTO #TempOrd  
      FROM ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), LOADPLAN (NOLOCK), LOADPLANDETAIL (NOLOCK)  
      WHERE Orders.Orderkey = Orderdetail.Orderkey  
      AND   Orderdetail.Loadkey = Loadplandetail.Loadkey  
      AND   Loadplan.Loadkey = Loadplandetail.Loadkey  
      AND   Loadplandetail.Orderkey = Orders.Orderkey  
      AND   Orderdetail.Status = '9'  
      AND   Orders.facility >= @c_facilitystart  
      AND   Orders.facility <= @c_facilityend  
      AND   Orderdetail.storerkey >= @c_storerstart  
      AND   Orderdetail.storerkey <= @c_storerend  
      AND   Orderdetail.editdate >= @d_editdatestart  
      AND   Orderdetail.editdate <= @d_editdateend  
      AND   Orderdetail.sku >= @c_skustart  
      AND   Orderdetail.sku <= @c_skuend  
      ORDER BY Orderdetail.editdate  
  
      INSERT INTO #RESULT (externorderkey, company, sku, qty, weight, editdate, facility,returnqty)  
      SELECT #TempOrd.*  , '' FROM #TempOrd  
  
      --select * From #RESULT  
  
   END  
  
   BEGIN  
      SELECT  Receipt.carriername,Receiptdetail.sku, Itrn.adddate, Receipt.Facility,Receiptdetail.qtyreceived, Receipt.externreceiptkey  
      INTO #TempRecpt  
      FROM RECEIPT (NOLOCK), RECEIPTDETAIL (NOLOCK), ITRN (NOLOCK)  
      WHERE Receipt.Receiptkey = Receiptdetail.Receiptkey  
      AND   Receipt.Rectype <> 'Normal'  
      AND   ITRN.Storerkey = Receiptdetail.Storerkey  
      AND   ITRN.Sku = Receiptdetail.Sku  
      AND   SUBSTRING(Itrn.Sourcekey, 1, 10) = Receiptdetail.Receiptkey  
      AND   SUBSTRING(Itrn.Sourcekey, 11, 5) = Receiptdetail.Receiptlinenumber  
      AND   Itrn.Sourcetype = 'ntrReceiptDetailUpdate'  
      AND   Receipt.facility >= @c_facilitystart  
      AND   Receipt.facility <= @c_facilityend  
      AND   Receiptdetail.storerkey >= @c_storerstart  
      AND   Receipt.storerkey <= @c_storerend  
      AND   Itrn.adddate >= @d_editdatestart  
      AND   Itrn.adddate <= @d_editdateend  
      AND   Receiptdetail.sku > = @c_skustart  
      AND   Receiptdetail.sku <= @c_skuend  
      ORDER BY Itrn.Adddate  
  
      --select * From #temprecpt  
  
      INSERT INTO #RESULT ( externorderkey, company, sku, qty, editdate, facility, returnqty)  
      SELECT '', #TempRecpt.carriername, #TempRecpt.sku, '', #TempRecpt.Adddate, #TempRecpt.facility, #TempRecpt.qtyreceived FROM #TempRecpt  
      WHERE #TempRecpt.ExternReceiptkey <> ' '  
   END  
  
   SELECT *, start_date = @d_editdatestart, end_date = @d_editdateend FROM #RESULT  
  
  
   DROP TABLE #RESULT  
   DROP TABLE #TempOrd  
   DROP TABLE #TempRecpt  
  
END  

GO