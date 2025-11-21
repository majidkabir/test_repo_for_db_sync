SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCompare_inv2a_sku                               */
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

CREATE PROCEDURE [dbo].[nspCompare_inv2a_sku] (
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
   SELECT PHYSICAL.StorerKey, PHYSICAL.Sku, SUM(PHYSICAL.Qty) "QtyTeamA", 0 "QtyLOTxLOCxID"
   INTO #PHYSICAL
   FROM PHYSICAL, PHYSICALPARAMETERS
   WHERE PHYSICAL.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND PHYSICALPARAMETERS.StorerKeyMax
   AND PHYSICAL.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND PHYSICALPARAMETERS.SkuMax
   AND PHYSICAL.Team = "A"
   GROUP BY StorerKey, Sku
   UNION
   SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.Sku, 0 "QtyTeamA", SUM(LOTxLOCxID.Qty) "QtyLOTxLOCxID"
   FROM LOTxLOCxID, PHYSICALPARAMETERS
   WHERE LOTxLOCxID.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND PHYSICALPARAMETERS.StorerKeyMax
   AND LOTxLOCxID.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND PHYSICALPARAMETERS.SkuMax
   GROUP BY StorerKey, Sku
   ORDER BY StorerKey, Sku
   IF @c_ResultMode = "T"
   BEGIN
      DELETE PHY_INV2A_SKU
      INSERT INTO PHY_INV2A_SKU (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID)
      SELECT StorerKey, Sku, SUM(QtyTeamA) "QtyTeamA", SUM(QtyLOTxLOCxID) "QtyLOTxLOCxID"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku
      HAVING NOT SUM(QtyTeamA) = SUM(QtyLOTxLOCxID)
      ORDER BY StorerKey, Sku
   END
ELSE
   BEGIN
      SELECT StorerKey, Sku, SUM(QtyTeamA) "QtyTeamA", SUM(QtyLOTxLOCxID) "QtyLOTxLOCxID"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku
      HAVING NOT SUM(QtyTeamA) = SUM(QtyLOTxLOCxID)
      ORDER BY StorerKey, Sku
   END
END


GO