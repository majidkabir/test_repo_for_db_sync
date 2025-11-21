SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO










CREATE VIEW [dbo].[V_ASN]
as
Select RECEIPT.RECType, PODETAIL.ExternPokey As ExternReceiptKey1,PODETAIL.ExternPokey 
			 As ExternReceiptKey2,PODETAIL.ExternPokey As ExternReceiptKey3 , RECEIPTDETAIL.ExternLineNo , 
			 RECEIPTDETAIL.StorerKey, RECEIPTDETAIL.Sku, RECEIPTDETAIL.DateReceived , RECEIPTDETAIL.Lottable02, 
 			 Case WHEN RECEIPTDETAIL.UOM = Pack.PackUOM1 Then FLOOR(RECEIPTDETAIL.QtyReceived/Pack.CaseCnt) 
			 WHEN RECEIPTDETAIL.UOM = Pack.PackUOM2 Then FLOOR(RECEIPTDETAIL.QtyReceived/Pack.InnerPack) 
			 WHEN RECEIPTDETAIL.UOM = Pack.PackUOM4 Then FLOOR(RECEIPTDETAIL.QtyReceived/Pack.Pallet) 
			 Else RECEIPTDETAIL.QtyReceived End As QtyReceived, 
			 RECEIPTDETAIL.UOM, RECEIPTDETAIL.SubReasonCode , '' as BillToKey, '' as ConsigneeKey,Receipt.Facility, Loc.HostWhCode As LOC, 
			 RECEIPT.Signatory As Shipment_no, RECEIPTDETAIL.Lottable04 As Expirydate,
          RECEIPTDETAIL.ReceiptKey, RECEIPTDETAIL.ReceiptLineNumber 
			 From RECEIPTDETAIL With (nolock) 
   			 Inner Join receipt With (nolock) On receiptdetail.receiptkey=receipt.receiptkey 
   			 Inner Join TransmitLog TL With (nolock) On ReceiptDetail.ReceiptKey = TL.Key1 And ReceiptDetail.ReceiptLineNumber = TL.Key2 
			 And TL.TableName = 'OWRCPT' And TL.TransmitFlag = '9' 
   			 Left Outer Join PODETAIL With (nolock) On receiptdetail.pokey = PODETAIL.pokey And receiptdetail.pokey <> '' 
            		 And receiptdetail.polinenumber = podetail.polinenumber 
   			 Join Pack With (nolock) On ( RECEIPTDETAIL.PackKey = Pack.PackKey ) 
   			 Join Loc With (nolock) On (Receiptdetail.Toloc = Loc.Loc) 
			 WHERE RECEIPT.RECType = 'NORMAL' 
UNION 
			 Select RECEIPT.RecType, PODETAIL.ExternPokey As ExternReceiptKey1,PODETAIL.ExternPokey As ExternReceiptKey2, 
			 PODETAIL.ExternPokey As ExternReceiptKey3 , RECEIPTDETAIL.ExternLineNo , 
			 RECEIPTDETAIL.StorerKey, RECEIPTDETAIL.Sku, RECEIPTDETAIL.DateReceived , RECEIPTDETAIL.Lottable02, 
			 Case RECEIPTDETAIL.UOM WHEN Packuom1 Then (RECEIPTDETAIL.qtyreceived) % cast(PACK.casecnt As Int) 
			 WHEN Packuom2 Then (RECEIPTDETAIL.qtyreceived) % cast(PACK.innerpack As Int) 
			 WHEN Packuom3 Then (RECEIPTDETAIL.qtyreceived) % 1 
			 WHEN Packuom4 Then (RECEIPTDETAIL.qtyreceived) % cast(PACK.pallet As Int) End As QtyReceived, 
			 Pack.Packuom3 As UOM, RECEIPTDETAIL.SubReasonCode, '' as BillToKey, '' as ConsigneeKey,Receipt.Facility, Loc.HostWhCode As LOC, 
			 RECEIPT.Signatory As Shipment_no, RECEIPTDETAIL.Lottable04 As Expirydate,
          RECEIPTDETAIL.ReceiptKey, RECEIPTDETAIL.ReceiptLineNumber 
			 FROM RECEIPTDETAIL With (nolock) 
   			 Inner Join receipt With (nolock) On receiptdetail.receiptkey=receipt.receiptkey 
   			 Inner Join TransmitLog TL With (nolock) On ReceiptDetail.ReceiptKey = TL.Key1 And ReceiptDetail.ReceiptLineNumber = TL.Key2 
            		 And TL.TableName = 'OWRCPT' And TL.TransmitFlag = '9' 
   			 Left Outer Join PODETAIL With (nolock) On receiptdetail.pokey = PODETAIL.pokey And receiptdetail.pokey <> '' 
            		 And receiptdetail.polinenumber = podetail.polinenumber 
   			 Join Pack With (nolock) On ( RECEIPTDETAIL.PackKey = Pack.PackKey ) 
   			 Join Loc With (nolock) On (Receiptdetail.Toloc = Loc.Loc) 
			 WHERE Case RECEIPTDETAIL.UOM WHEN PACK.Packuom1 Then (RECEIPTDETAIL.qtyreceived) % cast(PACK.casecnt As Int) 
		 	 WHEN PACK.Packuom2 Then (RECEIPTDETAIL.qtyreceived) % cast(PACK.innerpack As Int) 
		 	 WHEN PACK.Packuom3 Then (RECEIPTDETAIL.qtyreceived) % 1 
		 	 WHEN PACK.Packuom4 Then (RECEIPTDETAIL.qtyreceived) % cast(PACK.pallet As Int) 
			 End > 0 And RECEIPT.RECType = 'NORMAL' 








GO