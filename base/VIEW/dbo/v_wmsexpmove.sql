SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPMOVE] 
AS 
SELECT [SKU]
, [Lottable01]
, [Lottable02]
, [Lottable03]
, [Lottable04]
, [Lottable05]
, [Qty]
, [FromWhCode]
, [ToWhCode]
, [ITRNKEY]
, [Transflag]
FROM [WMSEXPMOVE] (NOLOCK) 

GO