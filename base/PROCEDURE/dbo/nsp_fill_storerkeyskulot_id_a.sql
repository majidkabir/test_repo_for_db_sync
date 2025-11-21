SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_fill_StorerkeySkuLot_id_a                      */
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

CREATE PROCEDURE [dbo].[nsp_fill_StorerkeySkuLot_id_a]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug tinyint
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT Id, Lot, StorerKey, Sku FROM PHYSICAL ORDER BY Id, Lot, StorerKey, Sku
      SELECT Id, Lot FROM LOTxID ORDER BY Id, Lot
   END
   UPDATE PHYSICAL
   SET PHYSICAL.Lot = LOTxID.Lot,
   PHYSICAL.Storerkey = LOT.Storerkey,
   PHYSICAL.Sku = LOT.Sku
   FROM PHYSICAL, LOTxID, LOT, PHYSICALPARAMETERS
   WHERE dbo.fnc_LTrim(dbo.fnc_RTrim(PHYSICAL.Id)) IS NOT NULL
   AND PHYSICAL.Id = LOTxID.Id
   AND LOTxID.LOT = LOT.LOT
   AND LOT.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin AND
   PHYSICALPARAMETERS.StorerKeyMax
   AND LOT.Sku BETWEEN PHYSICALPARAMETERS.SkuMin AND
   PHYSICALPARAMETERS.SkuMax
   AND PHYSICAL.Team = "A"
   AND dbo.fnc_LTrim(dbo.fnc_RTrim(PHYSICAL.Lot)) IS NULL
   IF @b_debug = 1
   BEGIN
      SELECT Id, Lot, StorerKey, Sku FROM PHYSICAL ORDER BY Id, Lot, StorerKey, Sku
   END
END

GO