SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO










CREATE VIEW [dbo].[LOTxID]
( Lot,
Id,
Qty
) AS
SELECT    LOTxLOCxID.Lot,
LOTxLOCxID.Id,
Sum(Qty)
FROM LOTxLOCxID
GROUP BY  LOTxLOCxID.Lot,
LOTxLOCxID.Id
HAVING Sum(Qty) > 0





GO