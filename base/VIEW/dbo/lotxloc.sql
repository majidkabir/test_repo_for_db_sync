SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO










CREATE VIEW [dbo].[LOTxLOC]
( Lot,
Loc,
Storerkey,
Sku,
Qty
) AS
SELECT    LOTxLOCxID.Lot,
LOTxLOCxID.Loc,
LOTxLOCxID.Storerkey,
LOTxLOCxID.Sku,
Sum(Qty)
FROM LOTxLOCxID
GROUP BY  LOTxLOCxID.Lot,
LOTxLOCxID.Loc,
LOTxLOCxID.Storerkey,
LOTxLOCxID.Sku
HAVING Sum(Qty) > 0





GO