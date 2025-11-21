SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPADJ] 
AS 
SELECT [Adjustmentkey]
, [CustomerRefNo]
, [AdjustmentType]
, [AdjustmentLineNumber]
, [SKU]
, [Lottable01]
, [Lottable02]
, [Lottable03]
, [Lottable04]
, [Lottable05]
, [Qty]
, [ReasonCode]
, [HOSTWHCODE]
, [TRANSFLAG]
FROM [WMSEXPADJ] (NOLOCK) 

GO