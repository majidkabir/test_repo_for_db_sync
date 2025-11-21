SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO










CREATE VIEW [dbo].[IDxLOC]
( Loc,
Id,
Qty
) AS
SELECT    LOTxLOCxID.Loc,
LOTxLOCxID.Id,
Sum(Qty)
FROM LOTxLOCxID
GROUP BY  LOTxLOCxID.Loc,
LOTxLOCxID.Id
HAVING Sum(Qty) > 0





GO