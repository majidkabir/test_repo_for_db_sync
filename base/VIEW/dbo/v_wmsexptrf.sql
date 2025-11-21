SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPTRF] 
AS 
SELECT [Transferkey]
, [ReasonCode]
, [CustomerRefNo]
, [TransferLineNumber]
, [FROMSKU]
, [FROMQty]
, [FROMWHCODE]
, [FROMLottable01]
, [FROMLottable02]
, [FromLottable03]
, [FROMLottable04]
, [FromLottable05]
, [TOSKU]
, [TOQty]
, [TOWHCODE]
, [ToLottable01]
, [ToLottable02]
, [ToLottable03]
, [ToLottable04]
, [ToLottable05]
, [TRANSFLAG]
FROM [WMSEXPTRF] (NOLOCK) 

GO