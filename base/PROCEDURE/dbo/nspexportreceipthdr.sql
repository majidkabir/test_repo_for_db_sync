SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportReceiptHdr                                */
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

CREATE PROCEDURE [dbo].[nspExportReceiptHdr]  --drop proc nspexportreceipthdr
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_count int
   SELECT @n_count = COUNT(*)
   FROM ReceiptDetail (nolock)
   WHERE exportstatus = '0'
   AND qtyreceived > 0
   AND receiptkey NOT LIKE 'DUMMY%'
   Declare @c_whseid char (2),@c_batchno char (5),@c_adddate NVARCHAR(8),@n_totrec int, @n_totrej int, @n_hashtot int,@n_hashcal int
   -- select candidate receipts for export
   SELECT WhseId= '01',
   Batchno = ncounter.keycount,
   --	 Receipt.receiptkey,
   Adddate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2),
   TotRec = count(receiptdetail.receiptkey),
   totrej = 0,
   HashTot=sum(Receiptdetail.Qtyreceived),
   HashCal = 0
   INTO #Temp
   FROM  Receipt (nolock), ReceiptDetail (nolock), ncounter (nolock)
   WHERE Receipt.receiptkey = ReceiptDetail.receiptkey
   AND ReceiptDetail.exportstatus = '0'
   AND ReceiptDetail.qtyreceived > 0
   AND Ncounter.Keyname = 'rrbatch'
   AND RECEIPT.RECTYPE <> 'RET'
   GROUP BY Ncounter.Keycount
   -- select candidate receipts with type 'RET' or 'RRB' for export
   SELECT  whseid,batchno,adddate,totrec,totrej,hashtot,hashcal
   FROM	  #temp
   DROP TABLE #Temp
END


GO