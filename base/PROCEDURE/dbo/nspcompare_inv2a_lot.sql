SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCompare_inv2a_lot                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspCompare_inv2a_lot] (
@c_ResultMode  NVARCHAR(1)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug tinyint
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @c_ResultMode "ResultMode"
   END
   SELECT PHYSICAL.StorerKey, PHYSICAL.Sku, PHYSICAL.Lot, SUM(PHYSICAL.Qty) "QtyTeamA", 0 "QtyLOTxLOCxID"
   INTO #PHYSICAL
   FROM PHYSICAL, PHYSICALPARAMETERS
   WHERE PHYSICAL.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND PHYSICALPARAMETERS.StorerKeyMax
   AND PHYSICAL.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND PHYSICALPARAMETERS.SkuMax
   AND PHYSICAL.Team = "A"
   GROUP BY StorerKey, Sku, Lot
   UNION
   SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.Sku, LOTxLOCxID.Lot, 0 "QtyTeamA", SUM(LOTxLOCxID.Qty) "QtyLOTxLOCxID"
   FROM LOTxLOCxID, PHYSICALPARAMETERS
   WHERE LOTxLOCxID.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND PHYSICALPARAMETERS.StorerKeyMax
   AND LOTxLOCxID.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND PHYSICALPARAMETERS.SkuMax
   GROUP BY StorerKey, Sku, Lot
   ORDER BY StorerKey, Sku, Lot
   IF @c_ResultMode = "T"
   BEGIN
      DELETE PHY_INV2A_LOT
      INSERT INTO PHY_INV2A_LOT (StorerKey, Sku, Lot, QtyTeamA, QtyLOTxLOCxID)
      SELECT StorerKey, Sku, Lot, SUM(QtyTeamA) "QtyTeamA", SUM(QtyLOTxLOCxID) "QtyLOTxLOCxID"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku, Lot
      HAVING NOT SUM(QtyTeamA) = SUM(QtyLOTxLOCxID)
      ORDER BY StorerKey, Sku, Lot
   END
ELSE
   BEGIN
      SELECT StorerKey, Sku, Lot, SUM(QtyTeamA) "QtyTeamA", SUM(QtyLOTxLOCxID) "QtyLOTxLOCxID"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku, Lot
      HAVING NOT SUM(QtyTeamA) = SUM(QtyLOTxLOCxID)
      ORDER BY StorerKey, Sku, Lot
   END
END


GO