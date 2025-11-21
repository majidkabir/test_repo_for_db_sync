SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispReCalculateQtyOnHold                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Patching incorrect QtyOnHold in LOT Table                   */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 29-Jun-2005  Shong         Debugging                                 */
/* 05-May-2011  Shong         Bug Fixing - Calculate ID hold should     */
/*                            Filter ID <> Blank                        */
/* 27-Jul-2017  TLTING  1.1   SET Option                                */
/************************************************************************/
CREATE PROC [dbo].[ispReCalculateQtyOnHold]
AS
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

Declare @cLot NVARCHAR(10),
        @nTotQtyHoldByID int,
        @nTotQtyHoldByLoc int

SELECT @cLOT = SPACE(10)

DECLARE C_RC_LOT CURSOR READ_ONLY FAST_FORWARD FOR
SELECT LOT.LOT
FROM   LOT (NOLOCK)
WHERE  (QtyOnHold <> 0) 
UNION 
SELECT DISTINCT LOT.LOT 
FROM LOT (NOLOCK) 
JOIN LOTxLOCxID L (NOLOCK) ON L.LOT = LOT.LOT 
JOIN LOC (nolock) ON L.LOC = LOC.LOC 
WHERE (LOC.Status = 'HOLD' OR LOC.LocationFlag = 'HOLD')
AND   LOT.QtyOnHold = 0 
UNION 
SELECT DISTINCT LOT.LOT 
FROM LOT (NOLOCK) 
JOIN LOTxLOCxID L (NOLOCK) ON L.LOT = LOT.LOT 
JOIN ID (nolock) ON L.ID = ID.ID 
WHERE (ID.Status = 'HOLD')
AND   LOT.QtyOnHold = 0 
ORDER BY LOT

OPEN C_RC_LOT

FETCH NEXT FROM C_RC_LOT INTO @cLot 

WHILE @@FETCH_STATUS <> -1 
BEGIN
   Print 'ReCalculate LOT# ' + @cLot

   -- Get total qty on-hold where this ID not exists in LOC that Held
   SELECT @nTotQtyHoldByID = ISNULL(SUM(LOTxLOCxID.QTY),0)
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.LOC = LOC.LOC
   AND LOTxLOCxID.ID = ID.ID
   AND ID.STATUS = 'HOLD'
   AND LOC.STATUS = 'OK'
   AND LOTxLOCxID.LOT = @cLot
   AND LOTxLOCxID.QTY > 0 
   AND ID.ID <> ''

   SELECT @nTotQtyHoldByLoc = ISNULL(SUM(LOTxLOCxID.QTY),0)
   FROM LOTxLOCxID (NOLOCK)
   JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC  
   WHERE (LOC.STATUS <> 'OK' OR LOC.LocationFlag = 'HOLD' OR LOC.LocationFlag = 'DAMAGE')
   AND LOTxLOCxID.LOT = @cLot
   AND LOTxLOCxID.QTY > 0 

   IF (SELECT QtyOnHold FROM LOT (NOLOCK) WHERE LOT = @cLOT) <> ISNULL(@nTotQtyHoldByID,0) + ISNULL(@nTotQtyHoldByLoc,0)
   BEGIN
      SELECT LOT, Qty, ISNULL(@nTotQtyHoldByID,0) as HoldByID, 
             ISNULL(@nTotQtyHoldByLoc,0) as HoldByLoc, 
             QtyOnHold 
      FROM   LOT (NOLOCK) 
      WHERE  LOT = @cLOT

      UPDATE LOT WITH (ROWLOCK)
       SET QtyOnHold = ISNULL(@nTotQtyHoldByID,0) + ISNULL(@nTotQtyHoldByLoc,0)
      WHERE LOT = @cLOT
   END

   Print 'Lot:' + @cLot + ' Total Qty Hold=' + Cast(ISNULL(@nTotQtyHoldByID,0) + ISNULL(@nTotQtyHoldByLoc,0) as NVARCHAR(10))
   
   FETCH NEXT FROM C_RC_LOT INTO @cLot 
END
CLOSE C_RC_LOT 
DEALLOCATE C_RC_LOT

GO