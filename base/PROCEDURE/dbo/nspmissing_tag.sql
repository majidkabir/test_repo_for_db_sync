SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[nspMissing_tag] (
@c_InventoryTagMin      NVARCHAR(18),
@c_InventoryTagMax      NVARCHAR(18),
@c_team                 NVARCHAR(1),
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
      SELECT @c_InventoryTagMin "InventoryTagMin", @c_InventoryTagMax "InventoryTagMax", @c_team "Team", @c_ResultMode "ResultMode"
      SELECT Team, InventoryTag FROM PHYSICAL WHERE Team = @c_team ORDER BY CONVERT(int, InventoryTag)
   END
   
   DECLARE @n_InventoryTagMin int
   SELECT @n_InventoryTagMin = CONVERT(int, @c_InventoryTagMin)
   DECLARE @n_InventoryTagMax int
   SELECT @n_InventoryTagMax = CONVERT(int, @c_InventoryTagMax)
   
   DECLARE CURSOR_TAG CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT CONVERT(int, InventoryTag)
   FROM PHYSICAL
   WHERE Team =@c_team AND CONVERT(int, InventoryTag) BETWEEN @n_InventoryTagMin AND @n_InventoryTagMax
   ORDER BY CONVERT(int, InventoryTag)

   OPEN CURSOR_TAG
   DECLARE @n_InventoryTagExpected int
   SELECT @n_InventoryTagExpected = @n_InventoryTagMin
   DECLARE @n_InventoryTagCurrent int
   CREATE TABLE #PHYSICAL (InventoryTag NVARCHAR(18))
   WHILE @n_InventoryTagExpected <= @n_InventoryTagMax
   BEGIN
      FETCH NEXT FROM CURSOR_TAG INTO @n_InventoryTagCurrent
      IF NOT @@FETCH_STATUS = 0
      BEGIN
         WHILE @n_InventoryTagExpected <= @n_InventoryTagMax
         BEGIN
            INSERT #PHYSICAL (InventoryTag) VALUES (CONVERT(char(18), @n_InventoryTagExpected))
            SELECT @n_InventoryTagExpected = @n_InventoryTagExpected + 1
         END
         BREAK
      END
      WHILE @n_InventoryTagExpected < @n_InventoryTagCurrent
      BEGIN
         INSERT #PHYSICAL (InventoryTag) VALUES (CONVERT(char(18), @n_InventoryTagExpected))
         SELECT @n_InventoryTagExpected = @n_InventoryTagExpected + 1
         IF @n_InventoryTagExpected = @n_InventoryTagCurrent
         BEGIN
            BREAK
         END
      END
      SELECT @n_InventoryTagExpected = @n_InventoryTagExpected + 1
   END
   CLOSE CURSOR_TAG
   DEALLOCATE CURSOR_TAG
   IF @c_ResultMode = "T"
   BEGIN
      IF @c_team = "A"
      BEGIN
         DELETE PHY_missing_tag_a
         INSERT INTO PHY_missing_tag_a (InventoryTag)
         SELECT InventoryTag
         FROM #PHYSICAL
         ORDER BY CONVERT(int, InventoryTag)
      END
      ELSE
      BEGIN
         DELETE PHY_missing_tag_b
         INSERT INTO PHY_missing_tag_b (InventoryTag)
         SELECT InventoryTag
         FROM #PHYSICAL
         ORDER BY CONVERT(int, InventoryTag)
      END
   END
   ELSE
   BEGIN
      SELECT InventoryTag
      FROM #PHYSICAL
      ORDER BY CONVERT(int, InventoryTag)
   END
END


GO