SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCompare_a2b_sku                                 */
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

CREATE PROCEDURE [dbo].[nspCompare_a2b_sku] (
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
   SELECT StorerKey, Sku, SUM(Qty) "QtyTeamA", 0 "QtyTeamB"
   INTO #PHYSICAL
   FROM PHYSICAL
   WHERE Team = "A"
   GROUP BY StorerKey, Sku
   UNION
   SELECT StorerKey, Sku, 0 "QtyTeamA", SUM(Qty) "QtyTeamB"
   FROM PHYSICAL
   WHERE Team = "B"
   GROUP BY StorerKey, Sku
   ORDER BY StorerKey, Sku
   IF @c_ResultMode = "T"
   BEGIN
      DELETE PHY_A2B_SKU
      INSERT INTO PHY_A2B_SKU (StorerKey, Sku, QtyTeamA, QtyTeamB)
      SELECT StorerKey, Sku, SUM(QtyTeamA) "QtyTeamA", SUM(QtyTeamB) "QtyTeamB"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku
      HAVING NOT SUM(QtyTeamA) = SUM(QtyTeamB)
      ORDER BY StorerKey, Sku
   END
ELSE
   BEGIN
      SELECT StorerKey, Sku, SUM(QtyTeamA) "QtyTeamA", SUM(QtyTeamB) "QtyTeamB"
      FROM #PHYSICAL
      GROUP BY StorerKey, Sku
      HAVING NOT SUM(QtyTeamA) = SUM(QtyTeamB)
      ORDER BY StorerKey, Sku
   END
END


GO