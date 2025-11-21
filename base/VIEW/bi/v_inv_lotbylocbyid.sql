SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_Inv_LotByLocByID]
AS
SELECT        dbo.LOTxLOCxID.StorerKey, dbo.LOTxLOCxID.Sku, dbo.LOTxLOCxID.Lot, dbo.LOTxLOCxID.Loc, dbo.LOTxLOCxID.Id, dbo.LOTxLOCxID.Qty, dbo.LOTxLOCxID.QtyAllocated, dbo.LOTxLOCxID.QtyPicked, 
                         dbo.LOTxLOCxID.QtyExpected, dbo.LOTxLOCxID.QtyPickInProcess, dbo.LOTxLOCxID.PendingMoveIN, 
                         dbo.LOTxLOCxID.Qty - dbo.LOTxLOCxID.QtyAllocated - dbo.LOTxLOCxID.QtyPicked - CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END AS Available, dbo.LOTATTRIBUTE.Lottable01, 
                         dbo.LOTATTRIBUTE.Lottable02, dbo.LOTATTRIBUTE.Lottable03, dbo.LOTATTRIBUTE.Lottable04, dbo.LOTATTRIBUTE.Lottable05, dbo.LOTATTRIBUTE.Lottable06, dbo.LOTATTRIBUTE.Lottable07, dbo.LOTATTRIBUTE.Lottable08, 
                         dbo.LOTATTRIBUTE.Lottable09, dbo.LOTATTRIBUTE.Lottable10, dbo.LOTATTRIBUTE.Lottable11, dbo.LOTATTRIBUTE.Lottable12, dbo.LOTATTRIBUTE.Lottable13, dbo.LOTATTRIBUTE.Lottable14, dbo.LOTATTRIBUTE.Lottable15, 
                         dbo.LOC.Facility, dbo.LOC.LocationType, dbo.LOC.LocationFlag, dbo.LOC.LocationCategory, dbo.LOC.HOSTWHCODE, dbo.SKU.DESCR, dbo.SKU.CLASS, dbo.SKU.itemclass, ISNULL
                             ((SELECT        MAX(Description) AS Expr1
                                 FROM            dbo.CODELKUP AS a WITH (NOLOCK)
                                 WHERE        (LISTNAME = 'ITEMCLASS') AND (Code = dbo.SKU.itemclass)), '****NO ITEMCLASS') AS Brand, CASE WHEN (ID.Status = N'HOLD' AND LOT.Status = N'HOLD' AND LOC.Status = N'HOLD') 
                         THEN 'HOLD (ID, LOT, LOC)' WHEN (ID.Status = N'HOLD' AND LOT.Status = N'HOLD') THEN 'HOLD (ID, LOT)' WHEN (ID.Status = N'HOLD' AND LOC.Status = N'HOLD') THEN 'HOLD (ID, LOC)' WHEN (LOT.Status = N'HOLD' AND 
                         LOC.Status = N'HOLD') THEN 'HOLD (LOT, LOC)' WHEN (ID.Status = N'HOLD') THEN 'HOLD (ID)' WHEN (LOC.LocationFlag = N'HOLD' OR
                         LOC.LocationFlag = N'DAMAGE') THEN 'HOLD (LOC)' WHEN (LOC.Status = N'HOLD') THEN 'HOLD (LOC)' WHEN (LOT.Status = N'HOLD') THEN 'HOLD (LOT)' ELSE 'OK' END AS HoldStatus, dbo.SKU.Style, dbo.SKU.Color, 
                         dbo.SKU.Measurement, dbo.SKU.Size, dbo.LOTxLOCxID.QtyReplen, ISNULL
                             ((SELECT        MAX(Status) AS Expr1
                                 FROM            dbo.INVENTORYHOLD AS a WITH (NOLOCK)
                                 WHERE        (Id > '0') AND (Hold = '1') AND (Id = dbo.LOTxLOCxID.Id)), 'FREE') AS Status, CONVERT(char(10), dbo.LOTxLOCxID.EditDate, 101) AS EditDate, dbo.LOTxLOCxID.EditWho, dbo.SKU.SUSR5
FROM            dbo.LOTxLOCxID WITH (NOLOCK) INNER JOIN
                         dbo.LOTATTRIBUTE WITH (NOLOCK) ON dbo.LOTxLOCxID.Lot = dbo.LOTATTRIBUTE.Lot INNER JOIN
                         dbo.LOC WITH (NOLOCK) ON dbo.LOTxLOCxID.Loc = dbo.LOC.Loc INNER JOIN
                         dbo.ID WITH (NOLOCK) ON dbo.LOTxLOCxID.Id = dbo.ID.Id INNER JOIN
                         dbo.LOT WITH (NOLOCK) ON dbo.LOTxLOCxID.Lot = dbo.LOT.Lot INNER JOIN
                         dbo.SKU WITH (NOLOCK) ON dbo.LOTxLOCxID.StorerKey = dbo.SKU.StorerKey AND dbo.LOTxLOCxID.Sku = dbo.SKU.Sku
WHERE        (dbo.LOTxLOCxID.StorerKey >= N'0') AND (dbo.LOTxLOCxID.StorerKey <= N'ZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZ', 3) = 'ZZZ') AND (dbo.LOTxLOCxID.Sku >= N'0') AND (dbo.LOTxLOCxID.Sku <= N'ZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.SKU.Style, N' ') >= N'') AND (ISNULL(dbo.SKU.Style, ' ') <= N'ZZZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.SKU.Color, N' ') >= N'') AND (ISNULL(dbo.SKU.Color, ' ') <= N'ZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.SKU.Size, N' ') >= N'') AND (ISNULL(dbo.SKU.Size, ' ') <= N'ZZZZZ' OR
                         LEFT('ZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.SKU.Measurement, N' ') >= N'') AND (ISNULL(dbo.SKU.Measurement, ' ') <= N'ZZZZZ' OR
                         LEFT('ZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable01, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable01, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable02, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable02, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable03, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable03, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (CONVERT(CHAR(20), ISNULL(dbo.LOTATTRIBUTE.Lottable04, ' '), 120) BETWEEN CONVERT(CHAR(20), CONVERT(DATETIME, ''), 120) AND CONVERT(CHAR(20), 
                         CONVERT(DATETIME, '2099-12-31'), 120)) AND (CONVERT(CHAR(20), ISNULL(dbo.LOTATTRIBUTE.Lottable05, ' '), 120) BETWEEN CONVERT(CHAR(20), CONVERT(DATETIME, ''), 120) AND CONVERT(CHAR(20), CONVERT(DATETIME, 
                         '2099-12-31'), 120)) AND (ISNULL(dbo.LOTATTRIBUTE.Lottable06, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable06, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable07, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable07, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable08, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable08, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable09, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable09, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable10, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable10, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable11, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable11, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable12, N' ') >= N'') AND (ISNULL(dbo.LOTATTRIBUTE.Lottable12, ' ') <= N'ZZZZZZZZZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZZZZZZZZZ', 3) = 'ZZZ') AND (CONVERT(CHAR(20), ISNULL(dbo.LOTATTRIBUTE.Lottable13, ' '), 120) BETWEEN CONVERT(CHAR(20), CONVERT(DATETIME, ''), 120) AND CONVERT(CHAR(20), 
                         CONVERT(DATETIME, '2099-12-31'), 120)) AND (CONVERT(CHAR(20), ISNULL(dbo.LOTATTRIBUTE.Lottable14, ' '), 120) BETWEEN CONVERT(CHAR(20), CONVERT(DATETIME, ''), 120) AND CONVERT(CHAR(20), CONVERT(DATETIME, 
                         '2099-12-31'), 120)) AND (CONVERT(CHAR(20), ISNULL(dbo.LOTATTRIBUTE.Lottable15, ' '), 120) BETWEEN CONVERT(CHAR(20), CONVERT(DATETIME, ''), 120) AND CONVERT(CHAR(20), CONVERT(DATETIME, '2099-12-31'), 120)) 
                         AND (dbo.LOTxLOCxID.Lot >= N'0') AND (dbo.LOTxLOCxID.Lot <= N'ZZZZZZZZZZ') AND (dbo.LOTxLOCxID.Loc >= N'0') AND (dbo.LOTxLOCxID.Loc <= N'ZZZZZZZZZZ') AND (dbo.LOTxLOCxID.Id >= N'') AND 
                         (dbo.LOTxLOCxID.Id <= N'ZZZZZZZZZZZZZZZZZZ') AND (dbo.LOTxLOCxID.Qty >= 1) AND (dbo.LOTxLOCxID.Qty <= 999999999) AND (dbo.LOTxLOCxID.PendingMoveIN >= 0) AND 
                         (dbo.LOTxLOCxID.PendingMoveIN <= 999999999) AND (ISNULL(dbo.LOC.Facility, N' ') >= N'0') AND (ISNULL(dbo.LOC.Facility, ' ') <= N'ZZZZZZZZZZ' OR
                         LEFT('ZZZZZZZZZZ', 3) = 'ZZZ')

GO