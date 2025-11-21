SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPASN] 
AS 
SELECT [Receiptkey]
, [ExternReceiptkey]
, [ExternLineNo]
, [ReceiptLineNumber]
, [WarehouseReference]
, [ContainerKey]
, [SKU]
, [QtyExpected]
, [QtyAdjusted]
, [QtyReceived]
, [Lottable01]
, [Lottable02]
, [Lottable03]
, [Lottable04]
, [Lottable05]
, [Rectype]
, [HOSTWHCODE]
, [ASNREASON]
, [SubReasonCode]
, [TRANSFLAG]
FROM [WMSEXPASN] (NOLOCK) 

GO