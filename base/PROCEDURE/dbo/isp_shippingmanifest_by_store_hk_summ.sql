SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_ShippingManifest_By_Store_HK_Summ]
@c_LoadKey1  NVARCHAR(10) = '' ,
@c_LoadKey2  NVARCHAR(10) = '' ,
@c_LoadKey3  NVARCHAR(10) = '' ,
@c_LoadKey4  NVARCHAR(10) = '' ,
@c_LoadKey5  NVARCHAR(10) = '' ,
@c_LoadKey6  NVARCHAR(10) = '' ,
@c_LoadKey7  NVARCHAR(10) = '' ,
@c_LoadKey8  NVARCHAR(10) = '' ,
@c_LoadKey9  NVARCHAR(10) = '' ,
@c_LoadKey10 NVARCHAR(10) = '' ,
@c_Store     NVARCHAR(15) = '' 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_SQL NVARCHAR(max)

	SELECT @c_SQL = 
	"SELECT LP.LoadKey, " + 
	"	od.OriginalQty as QtyOrdered, " + 
	"	od.Qtypicked + od.Shippedqty as QtyShipped, " + 
	"	(od.Qtypicked + od.Shippedqty) * s.Price as ValueHKD " + 
	"FROM ORDERS O (NOLOCK)  " + 
	"JOIN ORDERDETAIL OD (NOLOCK) ON (O.ORDERKEY = OD.ORDERKEY) " +
	"JOIN LOADPLANDETAIL LP (NOLOCK)  ON O.OrderKey = LP.OrderKey " +
	"JOIN SKU S (NOLOCK)	ON OD.STORERKEY = S.STORERKEY	AND OD.SKU = S.SKU " 

   IF dbo.fnc_RTrim(@c_LoadKey1) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey1) <> '' 
   BEGIN
      IF (dbo.fnc_RTrim(@c_LoadKey2) IS NULL OR dbo.fnc_RTrim(@c_LoadKey2) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey3) IS NULL OR dbo.fnc_RTrim(@c_LoadKey3) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey4) IS NULL OR dbo.fnc_RTrim(@c_LoadKey4) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey5) IS NULL OR dbo.fnc_RTrim(@c_LoadKey5) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey6) IS NULL OR dbo.fnc_RTrim(@c_LoadKey6) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey7) IS NULL OR dbo.fnc_RTrim(@c_LoadKey7) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey8) IS NULL OR dbo.fnc_RTrim(@c_LoadKey8) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey9) IS NULL OR dbo.fnc_RTrim(@c_LoadKey9) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey10) IS NULL OR dbo.fnc_RTrim(@c_LoadKey10) = '' ) 
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " WHERE LP.LoadKey = N'" + dbo.fnc_RTrim(@c_LoadKey1) + "' "
      END 
      ELSE
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " WHERE LP.LoadKey IN (N'" + dbo.fnc_RTrim(@c_LoadKey1) + "'"

         IF (dbo.fnc_RTrim(@c_LoadKey2) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey2) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey2) + "'"
         END 

         IF (dbo.fnc_RTrim(@c_LoadKey3) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey3) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey3) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey4) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey4) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey4) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey5) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey5) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey5) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey6) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey6) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey6) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey7) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey7) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey7) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey8) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey8) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey8) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey9) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey9) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey9) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey10) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey10) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey10) + "'"
         END 
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ") "

      END

      IF (dbo.fnc_RTrim(@c_Store) IS NOT NULL AND dbo.fnc_RTrim(@c_Store) <> '' )
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " AND O.Consigneekey = N'" + dbo.fnc_RTrim(@c_Store) + "'"
      END 
   END 
   ELSE
   BEGIN
      IF (dbo.fnc_RTrim(@c_Store) IS NOT NULL AND dbo.fnc_RTrim(@c_Store) <> '' )
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " WHERE O.Consigneekey = N'" + dbo.fnc_RTrim(@c_Store) + "'"
      END 
   END

   EXEC( @c_SQL) 
END 

GO