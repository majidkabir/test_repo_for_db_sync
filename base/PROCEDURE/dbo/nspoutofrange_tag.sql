SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOutofrange_tag                                  */
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

CREATE PROCEDURE [dbo].[nspOutofrange_tag] (
@c_InventoryTagMin      NVARCHAR(18),
@c_InventoryTagMax      NVARCHAR(18),
@c_Team                 NVARCHAR(1),
@c_ResultMode           NVARCHAR(1)
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
      SELECT @c_InventoryTagMin "InventoryTagMin", @c_InventoryTagMax "InventoryTagMax", @c_Team "Team", @c_ResultMode "ResultMode"
      SELECT InventoryTag FROM PHYSICAL WHERE Team = @c_Team ORDER BY CONVERT(int, InventoryTag)
   END
   DECLARE @n_InventoryTagMin int
   SELECT @n_InventoryTagMin = CONVERT(int, @c_InventoryTagMin)
   DECLARE @n_InventoryTagMax int
   SELECT @n_InventoryTagMax = CONVERT(int, @c_InventoryTagMax)
   IF @c_ResultMode = "T"
   BEGIN
      IF @c_Team = "A"
      BEGIN
         DELETE PHY_outofrange_tag_a
         INSERT INTO PHY_outofrange_tag_a (InventoryTag)
         SELECT InventoryTag
         FROM PHYSICAL
         WHERE Team = @c_Team AND
         CONVERT(int, InventoryTag) NOT BETWEEN @n_InventoryTagMin AND @n_InventoryTagMax
         ORDER BY CONVERT(int, InventoryTag)
      END
   ELSE
      BEGIN
         DELETE PHY_outofrange_tag_b
         INSERT INTO PHY_outofrange_tag_b (InventoryTag)
         SELECT InventoryTag
         FROM PHYSICAL
         WHERE Team = @c_Team AND
         CONVERT(int, InventoryTag) NOT BETWEEN @n_InventoryTagMin AND @n_InventoryTagMax
         ORDER BY CONVERT(int, InventoryTag)
      END
   END
ELSE
   BEGIN
      SELECT InventoryTag
      FROM PHYSICAL
      WHERE Team = @c_Team AND CONVERT(int, InventoryTag) NOT BETWEEN @n_InventoryTagMin AND @n_InventoryTagMax
      ORDER BY CONVERT(int, InventoryTag)
   END
END

GO