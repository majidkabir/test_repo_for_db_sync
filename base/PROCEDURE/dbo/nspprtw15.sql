SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspPRTW15                                           */
/* Creation Date: 27-Jul-2017                                            */
/* Copyright: LFL                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-2429 TW HKL Preallocation strategy                       */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 01-Feb-2023  WLChooi  1.1  WMS-21583 - Add sorting by LocLevel (WL01) */
/* 01-Feb-2023  WLChooi  1.1  DevOps Combine Script                      */
/* 19-May-2023  WLChooi  1.2  WMS-22624 - Rollback WMS-21583 (WL02)      */
/*************************************************************************/
CREATE   PROC [dbo].[nspPRTW15]
   @c_StorerKey        NVARCHAR(15)
 , @c_SKU              NVARCHAR(20)
 , @c_LOT              NVARCHAR(10)
 , @c_Lottable01       NVARCHAR(18)
 , @c_Lottable02       NVARCHAR(18)
 , @c_Lottable03       NVARCHAR(18)
 , @d_Lottable04       DATETIME
 , @d_Lottable05       DATETIME
 , @c_Lottable06       NVARCHAR(30)
 , @c_Lottable07       NVARCHAR(30)
 , @c_Lottable08       NVARCHAR(30)
 , @c_Lottable09       NVARCHAR(30)
 , @c_Lottable10       NVARCHAR(30)
 , @c_Lottable11       NVARCHAR(30)
 , @c_Lottable12       NVARCHAR(30)
 , @d_Lottable13       DATETIME
 , @d_Lottable14       DATETIME
 , @d_Lottable15       DATETIME
 , @c_UOM              NVARCHAR(10)
 , @c_Facility         NVARCHAR(10)
 , @n_UOMBase          INT
 , @n_QtyLeftToFulfill INT
 , @c_OtherParms       NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @n_ConsigneeMinShelfLife INT
         , @c_Condition             NVARCHAR(MAX)
         , @c_UOMBase               NVARCHAR(10)
         , @c_SQL                   NVARCHAR(MAX)

   DECLARE @c_OrderKey          NVARCHAR(10)
         , @c_OrderLineNumber   NVARCHAR(5)
         , @c_Consigneekey      NVARCHAR(15)
         , @n_OrderQty          INT
         , @c_OrderUOM          NVARCHAR(10)
         , @n_OrderMinShelfLife INT

   SET @c_UOMBase = RTRIM(CAST(@n_UOMBase AS NVARCHAR(10)))
   SET @c_Condition = N''
   SET @c_SQL = N''

   IF ISNULL(LTRIM(RTRIM(@c_LOT)), '') <> '' AND LEFT(@c_LOT, 1) <> '*'
   BEGIN
      SELECT @n_ConsigneeMinShelfLife = ((ISNULL(SKU.ShelfLife, 0) * ISNULL(STORER.MinShelfLife, 0) / 100) * -1)
      FROM SKU (NOLOCK)
      JOIN STORER (NOLOCK) ON SKU.StorerKey = STORER.StorerKey
      JOIN LOT (NOLOCK) ON SKU.StorerKey = LOT.StorerKey AND SKU.Sku = LOT.Sku
      WHERE LOT.Lot = @c_LOT

      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.StorerKey
           , LOT.Sku
           , LOT.Lot
           , QTYAVAILABLE = (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated)
      FROM LOT (NOLOCK)
         , LOTATTRIBUTE (NOLOCK)
         , LOTxLOCxID (NOLOCK)
         , LOC (NOLOCK)
      WHERE LOT.Lot = @c_LOT
      AND   LOT.Lot = LOTATTRIBUTE.Lot
      AND   LOTxLOCxID.Lot = LOT.Lot
      AND   LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
      AND   LOTxLOCxID.Loc = LOC.Loc
      AND   LOC.Facility = @c_Facility
      AND   DATEADD(DAY, @n_ConsigneeMinShelfLife, LOTATTRIBUTE.Lottable04) > GETDATE()
      ORDER BY LOTATTRIBUTE.Lottable04
             , LOT.Lot
   END
   ELSE
   BEGIN
      IF LEN(@c_OtherParms) > 0
      BEGIN
         SET @c_OrderKey = LEFT(@c_OtherParms, 10)
         SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)

         SELECT @c_Consigneekey = ORDERS.ConsigneeKey
         FROM ORDERS (NOLOCK)
         WHERE ORDERS.OrderKey = @c_OrderKey

         SELECT @n_OrderQty = ORDERDETAIL.OpenQty
              , @c_OrderUOM = ORDERDETAIL.UOM
              , @n_OrderMinShelfLife = ISNULL(ORDERDETAIL.MinShelfLife, 0)
         FROM ORDERDETAIL (NOLOCK)
         WHERE ORDERDETAIL.OrderKey = @c_OrderKey AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber

         IF ISNULL(@n_OrderMinShelfLife, 0) <> 0
         BEGIN
            SELECT @n_ConsigneeMinShelfLife = @n_OrderMinShelfLife * -1
         END
         ELSE
         BEGIN
            SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife, 0)
            FROM STORER (NOLOCK)
            WHERE StorerKey = @c_Consigneekey

            SELECT @n_ConsigneeMinShelfLife = ((ISNULL(SKU.ShelfLife, 0) * ISNULL(@n_ConsigneeMinShelfLife, 0) / 100)
                                               * -1)
            FROM SKU (NOLOCK)
            WHERE SKU.StorerKey = @c_StorerKey AND SKU.Sku = @c_SKU
         END
      END

      IF @n_ConsigneeMinShelfLife IS NULL
         SELECT @n_ConsigneeMinShelfLife = 0

      IF ISNULL(RTRIM(@c_Lottable01), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOC.HostWhCode = N'" + RTRIM(@c_Lottable01) + "' "
      END
      ELSE
      BEGIN
         IF NOT EXISTS (  SELECT 1
                          FROM CODELKUP CL (NOLOCK)
                          WHERE CL.Storerkey = @c_StorerKey
                          AND   CL.Code = 'NOFILTEREMPTYLOT1'
                          AND   CL.LISTNAME = 'PKCODECFG'
                          AND   CL.Long = 'nspPRTW15'
                          AND   ISNULL(CL.Short, '') <> 'N')
         BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + N' AND Lotattribute.LOTTABLE01 = '''' '
         END
      END

      IF ISNULL(RTRIM(@c_Lottable02), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable02 = N'" + RTRIM(@c_Lottable02) + "' "
      END
      ELSE
      BEGIN
         IF NOT EXISTS (  SELECT 1
                          FROM CODELKUP CL (NOLOCK)
                          WHERE CL.Storerkey = @c_StorerKey
                          AND   CL.Code = 'NOFILTEREMPTYLOT2'
                          AND   CL.LISTNAME = 'PKCODECFG'
                          AND   CL.Long = 'nspPRTW15'
                          AND   ISNULL(CL.Short, '') <> 'N')
         BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + N' AND Lotattribute.LOTTABLE02 = '''' '
         END
      END

      IF ISNULL(RTRIM(@c_Lottable03), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable03 = N'"
                               + RTRIM(ISNULL(@c_Lottable03, '')) + "' "
      END

      IF CONVERT(NVARCHAR(8), @d_Lottable04, 112) <> "19000101" AND @d_Lottable04 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable04, 112) = N'"
                               + RTRIM(CONVERT(NVARCHAR(8), @d_Lottable04, 112)) + "' "
      END
      ELSE IF @n_ConsigneeMinShelfLife <> 0
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEADD(DAY, "
                               + RTRIM(CAST(@n_ConsigneeMinShelfLife AS NVARCHAR))
                               + ", Lotattribute.Lottable04) > GETDATE() "
      END

      IF CONVERT(NVARCHAR(8), @d_Lottable05, 112) <> "19000101" AND @d_Lottable05 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable05, 112) = N'"
                               + RTRIM(CONVERT(NVARCHAR(8), @d_Lottable05, 112)) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable06), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable06 = N'" + RTRIM(@c_Lottable06) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable07), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable07 = N'" + RTRIM(@c_Lottable07) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable08), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable08 = N'" + RTRIM(@c_Lottable08) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable09), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable09 = N'" + RTRIM(@c_Lottable09) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable10), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable10 = N'" + RTRIM(@c_Lottable10) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable11), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable11 = N'" + RTRIM(@c_Lottable11) + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable12), '') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable12 = N'" + RTRIM(@c_Lottable12) + "' "
      END

      IF CONVERT(NVARCHAR(8), @d_Lottable13, 112) <> "19000101" AND @d_Lottable13 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable13, 112) = N'"
                               + RTRIM(CONVERT(NVARCHAR(8), @d_Lottable13, 112)) + "' "
      END

      IF CONVERT(NVARCHAR(8), @d_Lottable14, 112) <> "19000101" AND @d_Lottable14 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable14, 112) = N'"
                               + RTRIM(CONVERT(NVARCHAR(8), @d_Lottable14, 112)) + "' "
      END

      IF CONVERT(NVARCHAR(8), @d_Lottable15, 112) <> "19000101" AND @d_Lottable15 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable15, 112) = N'"
                               + RTRIM(CONVERT(NVARCHAR(8), @d_Lottable15, 112)) + "' "
      END

      IF @c_UOM = '1' --Pallet
      BEGIN
         IF @c_OrderUOM IN ( 'CS', 'EA' ) AND @n_OrderQty < @n_UOMBase
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "
      END
      ELSE IF @c_UOM = '2' --Case
      BEGIN
         IF @c_OrderUOM IN ( 'CS', 'EA' ) AND @n_OrderQty < @n_UOMBase
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "
      END
      ELSE IF @c_UOM = '6' --Each
      BEGIN
         IF @c_OrderUOM IN ( 'CS' )
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "
      END

      SELECT @c_SQL = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR "
                      + " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, "
                      + " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(LOT.QTYPREALLOCATED, 0)) "
                      + " FROM LOTxLOCxID (NOLOCK) " + " JOIN LOT (NOLOCK) ON LOT.LOT = LOTxLOCxID.Lot "
                      + " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT "
                      + " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc "
                      + " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID "
                      + " JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey "
                      + " AND SKUxLOC.SKU = LOTxLOCxID.SKU " + " AND SKUxLOC.LOC = LOTxLOCxID.LOC "
                      + " WHERE LOT.StorerKey = N'" + RTRIM(@c_StorerKey) + "' " + " AND LOT.SKU = N'" + RTRIM(@c_SKU)
                      + "' " + " AND LOT.STATUS = 'OK' " + " AND ID.STATUS <> 'HOLD' " + " AND LOC.Status = 'OK' "
                      + " AND LOC.Facility = N'" + RTRIM(@c_Facility) + "' " + " AND LOC.LocationFlag <> 'HOLD' "
                      + " AND LOC.LocationFlag <> 'DAMAGE' "
                      + " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED >= " + @c_UOMBase
                      + @c_Condition
                      + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable06 "   --WL01   --WL02
                      + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= "
                      + @c_UOMBase + " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot "   --WL01   --WL02

      EXEC (@c_SQL)
   END
END

GO