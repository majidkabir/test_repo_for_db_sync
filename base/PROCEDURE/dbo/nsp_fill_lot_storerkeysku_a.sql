SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_fill_lot_StorerkeySku_a                        */
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

CREATE PROCEDURE [dbo].[nsp_fill_lot_StorerkeySku_a]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug tinyint
   SELECT @b_debug = 2
   IF @b_debug = 1
   BEGIN
      SELECT * FROM PhysicalParameters
   END
   SELECT LOTATTRIBUTE.StorerKey, LOTATTRIBUTE.Sku, COUNT(DISTINCT LOT) "DupCount"
   INTO #LotException
   FROM LOTATTRIBUTE, PHYSICALPARAMETERS
   WHERE LOTATTRIBUTE.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND
   PHYSICALPARAMETERS.StorerKeyMax
   AND LOTATTRIBUTE.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND
   PHYSICALPARAMETERS.SkuMax
   GROUP BY LOTATTRIBUTE.StorerKey, LOTATTRIBUTE.Sku
   ORDER BY LOTATTRIBUTE.StorerKey, LOTATTRIBUTE.Sku
   IF @b_debug = 1
   BEGIN
      SELECT * FROM #LotException
      SELECT Team, StorerKey, Sku, Lot FROM PHYSICAL WHERE Team = "A" ORDER BY Team, StorerKey, Sku, Lot
      SELECT StorerKey, Sku, Lot FROM LOTATTRIBUTE ORDER BY StorerKey, Sku, Lot
   END
   UPDATE PHYSICAL
   SET PHYSICAL.Lot = LOTATTRIBUTE.Lot
   FROM PHYSICAL, LOTATTRIBUTE, PHYSICALPARAMETERS
   WHERE PHYSICAL.StorerKey = LOTATTRIBUTE.StorerKey
   AND PHYSICAL.Sku = LOTATTRIBUTE.Sku
   AND PHYSICAL.Team = "A"
   AND PHYSICAL.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND
   PHYSICALPARAMETERS.StorerKeyMax
   AND PHYSICAL.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND
   PHYSICALPARAMETERS.SkuMax
   AND dbo.fnc_LTrim(dbo.fnc_RTrim(PHYSICAL.Lot)) IS NULL
   AND PHYSICAL.StorerKey + PHYSICAL.Sku IN
   (SELECT StorerKey + Sku FROM #LotException WHERE DupCount = 1)
   IF @b_debug = 1
   BEGIN
      SELECT Team, StorerKey, Sku, Lot
      FROM PHYSICAL
      WHERE PHYSICAL.Team = "A"
      ORDER BY Team, StorerKey, Sku, Lot
   END
   DROP TABLE #LotException
END

GO