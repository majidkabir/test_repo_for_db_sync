SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCompare_inv2a_id                                */
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

CREATE PROCEDURE [dbo].[nspCompare_inv2a_id] (
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
   SELECT PHYSICAL.StorerKey, PHYSICAL.Sku, PHYSICAL.Id, SUM(PHYSICAL.Qty) "QtyTeamA", 0 "QtyLOTxLOCxID"
   INTO #PHYSICAL
   FROM PHYSICAL, PHYSICALPARAMETERS
   WHERE PHYSICAL.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND PHYSICALPARAMETERS.StorerKeyMax
   AND PHYSICAL.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND PHYSICALPARAMETERS.SkuMax
   AND PHYSICAL.Team = "A"
   GROUP BY StorerKey, Sku, Id
   UNION
   SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.Sku, LOTxLOCxID.Id, 0 "QtyTeamA", SUM(LOTxLOCxID.Qty) "QtyLOTxLOCxID"
   FROM LOTxLOCxID, PHYSICALPARAMETERS
   WHERE LOTxLOCxID.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND PHYSICALPARAMETERS.StorerKeyMax
   AND LOTxLOCxID.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND PHYSICALPARAMETERS.SkuMax
   GROUP BY StorerKey, Sku, Id
   ORDER BY StorerKey, Sku, Id
   IF @c_ResultMode = "T"
   BEGIN
      DELETE PHY_INV2A_ID
      INSERT INTO PHY_INV2A_ID (StorerKey, Sku, Id, QtyTeamA, QtyLOTxLOCxID)
      SELECT StorerKey, Sku, Id, SUM(QtyTeamA) "QtyTeamA", SUM(QtyLOTxLOCxID) "QtyLOTxLOCxID"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku, Id
      HAVING NOT SUM(QtyTeamA) = SUM(QtyLOTxLOCxID)
      ORDER BY StorerKey, Sku, Id
   END
ELSE
   BEGIN
      SELECT StorerKey, Sku, Id, SUM(QtyTeamA) "QtyTeamA", SUM(QtyLOTxLOCxID) "QtyLOTxLOCxID"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku, Id
      HAVING NOT SUM(QtyTeamA) = SUM(QtyLOTxLOCxID)
      ORDER BY StorerKey, Sku, Id
   END
END


GO