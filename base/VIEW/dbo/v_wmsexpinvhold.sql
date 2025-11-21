SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPINVHOLD] 
AS 
SELECT [Transmitlogkey]
, [InventoryHoldKey]
, [Loc]
, [FromWhCode]
, [TOWhCode]
, [Lottable01]
, [Lottable02]
, [Lottable03]
, [Lottable04]
, [Lottable05]
, [Sku]
, [Qty]
, [TransFlag]
FROM [WMSEXPINVHOLD] (NOLOCK) 

GO