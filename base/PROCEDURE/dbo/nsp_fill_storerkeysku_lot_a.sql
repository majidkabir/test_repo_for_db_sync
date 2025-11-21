SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_fill_StorerkeySku_lot_a                        */
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

CREATE PROCEDURE [dbo].[nsp_fill_StorerkeySku_lot_a]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug tinyint
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT * FROM PhysicalParameters
      SELECT Lot, StorerKey, Sku FROM PHYSICAL WHERE PHYSICAL.Team = "A" ORDER BY Lot, StorerKey, Sku
      SELECT Lot, StorerKey, Sku FROM LOTATTRIBUTE ORDER BY Lot, StorerKey, Sku
   END
   UPDATE PHYSICAL
   SET PHYSICAL.StorerKey = LOTATTRIBUTE.StorerKey,
   PHYSICAL.Sku = LOTATTRIBUTE.Sku
   FROM PHYSICAL, LOTATTRIBUTE, PHYSICALPARAMETERS
   WHERE dbo.fnc_LTrim(dbo.fnc_RTrim(PHYSICAL.Lot)) IS NOT NULL
   AND PHYSICAL.Lot = LOTATTRIBUTE.Lot
   AND LOTATTRIBUTE.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND
   PHYSICALPARAMETERS.StorerKeyMax
   AND LOTATTRIBUTE.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND
   PHYSICALPARAMETERS.SkuMax
   AND PHYSICAL.Team = "A"
   AND (dbo.fnc_LTrim(dbo.fnc_RTrim(PHYSICAL.StorerKey)) IS NULL OR
   dbo.fnc_LTrim(dbo.fnc_RTrim(PHYSICAL.Sku)) IS NULL)
   IF @b_debug = 1
   BEGIN
      SELECT Lot, StorerKey, Sku FROM PHYSICAL WHERE PHYSICAL.Team = "A" ORDER BY Lot, StorerKey, Sku
   END
END

GO