SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAdidasGIN                                       */
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

CREATE PROCEDURE [dbo].[nspAdidasGIN] (
     @c_externreceiptkey NVARCHAR(20)
 )
 AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   CREATE TABLE #TempGIN (
      Sku NVARCHAR(20),
      Facility NVARCHAR(5) NULL,
      Externreceiptkey NVARCHAR(20),
      lottable05 datetime,
      Descr NVARCHAR(60),
      Descrsku NVARCHAR(5),
      Lottable02 NVARCHAR(18) NULL ,
      Itemclass NVARCHAR(10) NULL,
      Qty int,
      BilledContainerQty int,
   )
   SELECT SUBSTRING(Rd.Sku, 1, 6) Sku, R.facility, R.Externreceiptkey, Rd.Lottable05, S.Descr, SUBSTRING(Rd.Sku, 8, 5) Descrsku,
   Rd.lottable02, S.itemclass, Rd.QtyReceived, R.BilledContainerQty
   INTO #TEMPADDSGIN
   FROM   Receipt R (NOLOCK), Receiptdetail Rd (NOLOCK), SKU S (NOLOCK)
   WHERE  R.receiptkey = Rd.receiptkey
   AND    Rd.Sku = S.Sku
   AND    Rd.Storerkey = S.Storerkey
   --AND    R.Rectype = 'NORMAL'
   AND    Rd.FinalizeFlag = 'Y'
   AND    R.externreceiptkey = @c_externreceiptkey
   --Group By Sku , R.facility,R.Externreceiptkey, Rd.Lottable05, S.Descr, Descrsku,
   --       Rd.lottable02, S.itemclass, Rd.QtyReceived, R.BilledContainerQty
   ORDER BY Rd.Sku
   INSERT INTO #TempGIN ( sku, facility, externreceiptkey, lottable05,descr, descrsku, lottable02, itemclass, qty, billedcontainerqty)
   SELECT #TEMPADDSGIN.*  from #TEMPADDSGIN
   SELECT * FROM #TempGIN
   GROUP BY sku, facility, externreceiptkey, lottable05,descr, descrsku, lottable02, itemclass, qty, billedcontainerqty
   DROP TABLE #TempGIN
   DROP TABLE #TEMPADDSGIN
END

GO