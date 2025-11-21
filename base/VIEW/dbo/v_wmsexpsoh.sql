SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPSOH] 
AS 
SELECT [TransDate]
, [Sku]
, [Qty]
, [Lottable01]
, [Lottable02]
, [Lottable03]
, [Lottable04]
, [Lottable05]
, [HostWhCode]
FROM [WMSEXPSOH] (NOLOCK) 

GO