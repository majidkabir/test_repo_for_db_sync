SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspExportC4_Receipt]
 as
 begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 Declare @c_Receiptkey NVARCHAR(10)
 ,       @c_ReceiptLineNumber NVARCHAR(5)
 Insert into C4_Rec_Exp(Messageh,Messagedate,Rev_Date,PO_Number,Supplycode,Head,Line,SKU,Qty,Best_Before_Date,Documentkey)
 SELECT  Messageh= Receipt.Externreceiptkey, 
         Messagedate=convert(char(10),getdate(),112),
         Rev_Date=convert(char(10),RECEIPTDETAIL.DateReceived,112),  
 	PO_Number=left(LTrim(RTrim(PO.ExternPOkey)),9)+right(replicate(' ',11),11),
         Supplycode=left(LTrim(RTrim(PO.SellerName)),10)+right(replicate(' ',8),8),   
	HEAD=(Select Short From Codelkup (Nolock) where codelkup.listname = 'POTYPE' and Codelkup.code = PO.POTYPE),
         Line=receiptdetail.Externlineno,
         SKU=Receiptdetail.sku,
         QtyReceived=sum(RECEIPTDETAIL.QtyReceived),
         Best_Before_Date=case when (convert(char(10),podetail.best_bf_date,108) ='NULL')
          then convert(char(10),podetail.best_bf_date,112)
          else convert(char(10),getdate(),112)
          end,  
          DocumentKey = Receiptdetail.receiptkey+receiptdetail.RECEIPTLineNumber
   /* FROM  PO(nolock),
          Receipt(nolock),
          Receiptdetail(nolock),
          PODETAIL(nolock),   
          transmitlog(nolock)
    WHERE (PO.POKEY=ReceiptDETAIL.POKEY) AND
          (po.pokey=podetail.pokey) and
          (PO.STORERKEY Between 'C4LG000000' AND 'C4LGZZZZZZ') AND 
			 (PO.POTYPE NOT IN ('2', '8', '8A')) AND  
          (receiptdetail.receiptkey=receipt.receiptkey) and   
          (receiptdetail.polinenumber=podetail.polinenumber) and
          (receiptdetail.QtyReceived > 0 ) AND 
          (transmitlog.key1 = RECEIPTDETAIL.Receiptkey)  and  
          (Transmitlog.key2 = RECEIPTDETAIL.Receiptlinenumber) AND
          (transmitlog.transmitflag = '0')   AND 
          (transmitlog.tablename = 'RECEIPT') */
    FROM  PO WITH (nolock)
    JOIN  PODETAIL WITH (nolock) ON (PO.pokey=PODETAIL.pokey) 
    JOIN  Receiptdetail WITH (nolock) ON  (PO.POKEY=ReceiptDETAIL.POKEY) 
												  AND (Receiptdetail.POLineNumber=PODETAIL.POLineNumber) 
    JOIN  Receipt WITH (nolock) ON (RECEIPT.Receiptkey = ReceiptDETAIL.Receiptkey)
	 JOIN  Transmitlog WITH (nolock) ON  (Transmitlog.key1 = RECEIPTDETAIL.Receiptkey)  
												AND (Transmitlog.key2 = RECEIPTDETAIL.Receiptlinenumber) 
	 LEFT OUTER JOIN CODELKUP FLOWTHRU (NOLOCK) ON (FLOWTHRU.CODE = PO.POTYPE)
											 				 AND (FLOWTHRU.Listname = 'FLOWTHRU') -- SOS96737
    WHERE (Transmitlog.transmitflag = '0')   
	 AND   (Transmitlog.tablename = 'RECEIPT') 
	 AND   (PO.STORERKEY Between 'C4LG000000' AND 'C4LGZZZZZZ') 
	 AND   (Receiptdetail.QtyReceived > 0) 
	 AND   FLOWTHRU.CODE IS NULL -- SOS96737    
        group by receiptdetail.sku,receiptdetail.externlineno,Receiptdetail.receiptkey,Receiptdetail.DateReceived,
        po.ExternPOkey,po.SellerName,podetail.best_bf_date,receipt.externreceiptkey,receiptdetail.RECEIPTlineNUMBER, 
        PO.POTYPE 
 DECLARE cur_update_transmitlog CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT left(Documentkey,10),right(Documentkey,5) 
          FROM C4_Rec_Exp (nolock)
          where status='0'
          OPEN cur_update_transmitlog
          WHILE (1 = 1)
          BEGIN
          FETCH NEXT FROM cur_update_transmitlog INTO @c_Receiptkey,@c_ReceiptLineNumber
          IF @@FETCH_STATUS <> 0 BREAK
          BEGIN TRAN updateTransmitlog
             UPDATE transmitlog 
             SET Transmitflag='9'
             WHERE key1=@c_Receiptkey
             and key2=@c_ReceiptLineNumber
             and transmitflag='0'
             and tablename='RECEIPT'
          COMMIT TRAN updateTransmitlog
       End   -- while      
     close cur_update_Transmitlog
    deallocate cur_update_Transmitlog
 End
 --delete c4_rec_exp
 --select * from c4_rec_exp
 --select Messageh,Messagedate,Rev_Date,Po_Number,Buyer,Supplycode,Head,Line,sku,Qty=Sum(Qty),Best_Before_Date from c4_rec_exp group by sku,line,Messageh,Messagedate,Rev_Date,Po_Number,Buyer,Supplycode,Head,Best_Before_Date order by line,sku
 --exec nspExportc4_Receipt

GO