SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_SKU_BALANCE]
AS
SELECT SOH.Facility,
       SKU.StorerKey,
       SKU.SKU,
       SKU.DESCR,
       SOH.Qty,
       SOH.QtyAllocated,
       SOH.QtyPicked,
       ISNULL(HOLDSKU.QtyOnHold, 0) AS QtyOnHold
FROM SKU WITH (NOLOCK)
JOIN (SELECT l.Facility,
             sl.StorerKey,
             sl.SKU,
             SUM(sl.Qty) AS Qty,
             SUM(sl.QtyAllocated) AS QtyAllocated,
             SUM(sl.QtyPicked) AS QtyPicked
      FROM SKUxLOC sl WITH (NOLOCK)
      JOIN LOC l WITH (NOLOCK) ON l.Loc = sl.Loc
      GROUP BY l.Facility, sl.StorerKey, sl.SKU
) AS SOH ON SOH.Sku = SKU.Sku AND SOH.StorerKey = SKU.StorerKey
LEFT OUTER JOIN (
    SELECT H.Facility, H.StorerKey, H.SKU, SUM(H.QtyOnHold) AS QtyOnHold
    FROM (SELECT LOTxLOCxID.StorerKey,
                   LOC.Facility,
                   LOTxLOCxID.SKU,
                   ISNULL(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),0) QtyOnHold
            FROM  dbo.LOT LOT WITH (NOLOCK)
            JOIN dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK) ON LOT.lot = LOTxLOCxID.lot
            JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
            WHERE LOT.Status = 'HOLD'
            GROUP BY  LOTxLOCxID.StorerKey, LOC.Facility, LOTxLOCxID.SKU
            UNION ALL
            SELECT LOTxLOCxID.StorerKey,
                   LOC.Facility,
                   LOTxLOCxID.SKU,
                   ISNULL(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),0) QtyOnHold
            FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
            JOIN dbo.LOT LOT WITH (NOLOCK) on LOT.lot = LOTxLOCxID.lot
            JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
            JOIN dbo.ID ID WITH (NOLOCK) on LOTxLOCxID.id = ID.id
            WHERE LOT.Status <> 'HOLD'
            AND (LOC.locationFlag = 'HOLD' OR LOC.Status = 'HOLD' OR LOC.locationFlag = 'DAMAGE')
            AND ID.Status = 'OK'
            GROUP BY  LOTxLOCxID.StorerKey, LOC.Facility, LOTxLOCxID.SKU
            HAVING SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
            UNION ALL
            SELECT LOTxLOCxID.StorerKey,
                   LOC.Facility,
                   LOTxLOCxID.SKU,
                   ISNULL(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),0) QtyOnHold
            FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
            JOIN dbo.LOT LOT WITH (NOLOCK) on LOT.lot = LOTxLOCxID.lot
            JOIN dbo.LOC LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc
            JOIN dbo.ID ID WITH (NOLOCK) on LOTxLOCxID.id = ID.id
            WHERE LOT.Status <> 'HOLD'
            AND (LOC.locationFlag <> 'HOLD' AND LOC.Status <> 'HOLD' AND LOC.locationFlag <> 'DAMAGE')
            AND ID.Status = 'HOLD'
            GROUP BY  LOTxLOCxID.StorerKey, LOC.Facility, LOTxLOCxID.SKU
            HAVING SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0 ) AS H
    GROUP BY H.Facility, H.StorerKey, H.SKU) AS HOLDSKU ON SOH.StorerKey = HOLDSKU.StorerKey AND SOH.Sku = HOLDSKU.Sku
    AND SOH.Facility = HOLDSKU.Facility


GO