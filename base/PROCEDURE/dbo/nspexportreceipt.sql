SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE   [dbo].[nspExportReceipt]  
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
 
   IF (SELECT COUNT(*)  
       FROM  Receipt (nolock), ReceiptDetail (nolock), PODetail (nolock)
       WHERE Receipt.receiptkey = ReceiptDetail.receiptkey
         AND ReceiptDetail.exportstatus = '0'
         AND ReceiptDetail.qtyreceived > 0
         AND ReceiptDetail.pokey = PODetail.pokey
         AND ReceiptDetail.externlineno = PODetail.externlineno
         AND Receipt.receiptkey NOT LIKE 'DUMMY%') <> @n_count
   BEGIN
     UPDATE ReceiptDetail
     SET ReceiptDetail.externlineno = PODetail.externlineno,
 		Trafficcop = NULL
     FROM ReceiptDetail, PODetail
     WHERE ReceiptDetail.pokey = PODetail.pokey
       AND ReceiptDetail.sku = PODetail.sku
       AND ReceiptDetail.exportstatus = '0'
       AND ReceiptDetail.qtyreceived > 0
   END
 
   -- select candidate receipts with type 'RPO' for export
   SELECT PODetail.externpokey,
 	 Receipt.receiptkey, 
       	 Receipt.storerkey,
          Receipt.warehousereference,
 	 Receipt.origincountry,		-- 'FROM' logical whse for branch returns
 	 ReceiptDetail.lottable03,	-- warehouse logical code
 	 ReceiptLineNumber = '00000',
 	 Receiptdetail.externlineno,	-- po line number
 	 ReceiptDetail.sku,
 	 QTYRECEIVED=(ReceiptDetail.qtyreceived-Receiptdetail.freegoodqtyreceived),
 	 ReceiptDetail.FreeGoodQtyExpected,	-- new field
 	 ExpiryDate = RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(month, ReceiptDetail.lottable04))),2) + '/'
                       + RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(day, ReceiptDetail.lottable04))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('00' + CONVERT(char(4), DATEPART(year, ReceiptDetail.lottable04))),4),
 	 ReceiptDetail.lottable02,	-- manufacturer lot number
 	 BeforeReceivedQty=(ReceiptDetail.qtyreceived-Receiptdetail.freegoodqtyreceived),
 	 ReceiptDetail.FreeGoodQtyReceived,
 	 Receipt.rectype,		-- receipt type
 	 carrierkey = UPPER(Receipt.carrierkey),
 	 ReceiptDate = RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(month, ReceiptDetail.editdate))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(day, ReceiptDetail.editdate))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('00' + CONVERT(char(4), DATEPART(year, ReceiptDetail.editdate))),4),
 	 Receipt.asnreason,		-- return reason code
 	 Receiptdetail.subreasoncode,
 	 Receipt.carrierreference,	-- invoice number
 	 Receipt.vehiclenumber		-- salesman code
   INTO #Temp
     FROM  Receipt (nolock), ReceiptDetail (nolock), PODetail (nolock)
     WHERE Receipt.rectype = 'RPO'
       AND Receipt.receiptkey = ReceiptDetail.receiptkey
       AND ReceiptDetail.exportstatus = '0'
       AND ReceiptDetail.qtyreceived > 0
       AND ReceiptDetail.pokey = PODetail.pokey
       AND ReceiptDetail.externlineno = PODetail.externlineno
       AND Receipt.receiptkey NOT LIKE 'DUMMY%'
 
   -- select candidate receipts with type 'RET' or 'RRB' for export
   SELECT externpokey = 'RET-RRB',
 	 Receipt.receiptkey, 
 	 Receipt.storerkey,
          Receipt.warehousereference,
 	 Receipt.origincountry,		-- 'FROM' logical whse for branch returns
 	 ReceiptDetail.lottable03,	-- warehouse logical code
 	 ReceiptLineNumber = '00000',
 	 Receiptdetail.externlineno,	-- po line number
 	 ReceiptDetail.sku,
 	 QTYRECIEVED=(ReceiptDetail.qtyreceived-Receiptdetail.freegoodqtyreceived),
 	 ReceiptDetail.FreeGoodQtyExpected,	-- new field
 	 ExpiryDate = RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(month, ReceiptDetail.lottable04))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(day, ReceiptDetail.lottable04))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('00' + CONVERT(char(4), DATEPART(year, ReceiptDetail.lottable04))),4),
 	 ReceiptDetail.lottable02,	-- manufacturer lot number
 	 ReceiptDetail.BeforeReceivedQty,
 	 ReceiptDetail.FreeGoodQtyReceived,
 	 Receipt.rectype,		-- receipt type
 	 carrierkey = UPPER(Receipt.carrierkey),
 	 ReceiptDate = RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(month, ReceiptDetail.editdate))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('0' + CONVERT(char(2), DATEPART(day, ReceiptDetail.editdate))),2) + '/'
          	      + RIGHT(dbo.fnc_RTrim('00' + CONVERT(char(4), DATEPART(year, ReceiptDetail.editdate))),4),
 	 Receipt.asnreason,		-- return reason code
 	 Receiptdetail.subreasoncode,
 	 Receipt.carrierreference,	-- invoice number
 	 Receipt.vehiclenumber		-- salesman code
   INTO #Temp1
   FROM  Receipt (nolock), ReceiptDetail (nolock)
   WHERE Receipt.rectype in ('RET', 'RRB')
     AND Receipt.receiptkey = ReceiptDetail.receiptkey
     AND	ReceiptDetail.exportstatus = '0'
     AND ReceiptDetail.qtyreceived <> 0
    -- AND Receipt.receiptkey NOT LIKE 'DUMMY%'
 
   -- merge two result sets since types 'RET' and 'RRB' does not require POs
   INSERT #Temp SELECT * FROM #Temp1
 
   UPDATE #Temp
   SET ExpiryDate = NULL
   WHERE ExpiryDate = '0/0/00'
 
   DECLARE @c_receiptkey	 NVARCHAR(10),
   	  @c_sku	 NVARCHAR(20),
 	  @c_externlineno NVARCHAR(5),
 	  @n_qtyreceived	int,
 	  @n_qtyadjusted	int,
 	  @n_total		int
 
   -- ensure that the total qtyreceived is repeated if a detail line used lot breakdown
   SELECT receiptkey, externlineno, sku, total = SUM(qtyreceived)
   INTO #Temp2
   FROM #Temp
   WHERE receiptkey IN (SELECT receiptkey 
 		       FROM RECEIPTDETAIL (nolock)
 		       WHERE exportstatus <> '9')
   GROUP BY receiptkey,externlineno,sku
 
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT * FROM #Temp2 
  
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_receiptkey, @c_externlineno, @c_sku, @n_total
   WHILE (@@fetch_status <> -1)
   BEGIN
     UPDATE #Temp
     SET qtyreceived = @n_total
     WHERE receiptkey + externlineno = @c_receiptkey + @c_externlineno
       AND sku = @c_sku
 
     FETCH NEXT FROM cur_1 INTO @c_receiptkey, @c_externlineno, @c_sku, @n_total
   END
   CLOSE cur_1
   DEALLOCATE cur_1
 
 
   -- ensure that the total freegoodqtyexpected is repeated when lot breakdown
   SELECT receiptkey, externlineno, sku, total = SUM(freegoodqtyexpected)
   INTO #Temp3
   FROM #Temp
   WHERE freegoodqtyexpected <> 0
   GROUP BY receiptkey, externlineno, sku
 
   IF @@ROWCOUNT = 0
   BEGIN
     GOTO Quit
   END
   ELSE
   BEGIN
     DECLARE cur_2 CURSOR FAST_FORWARD READ_ONLY
     FOR
     SELECT * FROM #Temp3
 
     OPEN cur_2
     FETCH NEXT FROM cur_2 INTO @c_receiptkey, @c_externlineno, @c_sku, @n_total
     WHILE (@@fetch_status <> -1)
     BEGIN
       UPDATE #Temp
       SET freegoodqtyexpected = @n_total, qtyreceived = 0
       WHERE receiptkey + externlineno = @c_receiptkey + @c_externlineno
         AND freegoodqtyreceived <> 0
         AND sku = @c_sku
       FETCH NEXT FROM cur_2 INTO @c_receiptkey, @c_externlineno, @c_sku, @n_total
     END
     CLOSE cur_2
     DEALLOCATE cur_2
   END
 
 Quit:
   -- delete all safekeeping transactions
   DELETE #Temp
   WHERE LEFT(lottable03, 2) = 'SK'
 
 --  SELECT * FROM #Temp 
   SELECT externpokey,
 	 receiptkey,
 	 storerkey,
 	 warehousereference,
 	 origincountry,
 	 lottable03,
 	 receiptlinenumber,
 	 externlineno,
 	 sku,
 	 Qtyreceived =sum(beforereceivedqty-freegoodqtyreceived),
 	 freegoodqtyexpected = SUM(freegoodqtyexpected),
 	 expirydate,
 	 lottable02,
 	 beforereceivedqty= sum(beforereceivedqty-freegoodqtyreceived),
 	 freegoodqtyreceived = SUM(freegoodqtyreceived),
 	 rectype,
 	 carrierkey,
 	 receiptdate,
 	 asnreason,
 	 subreasoncode,
 	 carrierreference,
 	 vehiclenumber
   FROM #TEMP
   GROUP BY externpokey,
 	 receiptkey,
 	 storerkey,
 	 warehousereference,
 	 origincountry,
 	 lottable03,
 	 receiptlinenumber,
 	 externlineno,
 	 sku,
 	 expirydate,
 	 lottable02,
 	 rectype,
 	 carrierkey,
 	 receiptdate,
 	 asnreason,
 	 subreasoncode,
 	 carrierreference,
 	 vehiclenumber
	 --freegoodqtyexpected,freegoodqtyreceived
   
 
   DROP TABLE #Temp
   DROP TABLE #Temp1
   DROP TABLE #Temp2
   DROP TABLE #Temp3
 END

GO