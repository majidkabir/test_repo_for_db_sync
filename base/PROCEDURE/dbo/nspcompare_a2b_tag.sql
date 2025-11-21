SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCompare_a2b_tag                                 */
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

CREATE PROCEDURE [dbo].[nspCompare_a2b_tag] (
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
   SELECT StorerKey, Sku, Loc, Id, InventoryTag, SUM(Qty) "QtyTeamA", 0 "QtyTeamB"
   INTO #PHYSICAL
   FROM PHYSICAL
   WHERE Team = "A"
   GROUP BY StorerKey, Sku, Loc, Id, InventoryTag
   UNION
   SELECT StorerKey, Sku, Loc, Id, InventoryTag, 0 "QtyTeamA", SUM(Qty) "QtyTeamB"
   FROM PHYSICAL
   WHERE Team = "B"
   GROUP BY StorerKey, Sku, Loc, Id, InventoryTag
   ORDER BY StorerKey, Sku, Loc, Id, InventoryTag
   IF @c_ResultMode = "T"
   BEGIN
      DELETE PHY_A2B_TAG
      INSERT INTO PHY_A2B_TAG (StorerKey, Sku, Loc, Id, InventoryTag, QtyTeamA, QtyTeamB)
      SELECT StorerKey, Sku, Loc, Id, InventoryTag, SUM(QtyTeamA) "QtyTeamA", SUM(QtyTeamB) "QtyTeamB"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku, Loc, Id, InventoryTag
      HAVING NOT SUM(QtyTeamA) = SUM(QtyTeamB)
      ORDER BY StorerKey, Sku, Loc, Id, InventoryTag
   END
ELSE
   BEGIN
      SELECT StorerKey, Sku, Loc, Id, InventoryTag, SUM(QtyTeamA) "QtyTeamA", SUM(QtyTeamB) "QtyTeamB"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku, Loc, Id, InventoryTag
      HAVING NOT SUM(QtyTeamA) = SUM(QtyTeamB)
      ORDER BY StorerKey, Sku, Loc, Id, InventoryTag
   END
END


GO