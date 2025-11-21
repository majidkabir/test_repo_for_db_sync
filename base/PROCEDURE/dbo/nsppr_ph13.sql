SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nspPR_PH13                                         */
/* Creation Date: 13-MAY-2022                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19584-[PH] RoyalCanin PreAllocation Strategy            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version:                                                             */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 13-MAY-2022  CHONGCS 1.0   Devops Scripts Combine                    */
/************************************************************************/

CREATE PROC [dbo].[nspPR_PH13]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime,
@d_lottable05 datetime,
@c_lottable06 NVARCHAR(30) ,
@c_lottable07 NVARCHAR(30) ,
@c_lottable08 NVARCHAR(30) ,
@c_lottable09 NVARCHAR(30) ,
@c_lottable10 NVARCHAR(30) ,
@c_lottable11 NVARCHAR(30) ,
@c_lottable12 NVARCHAR(30) ,
@d_lottable13 DATETIME ,
@d_lottable14 DATETIME ,
@d_lottable15 DATETIME ,
@c_uom NVARCHAR(10),
@c_facility NVARCHAR(10)  ,
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200)
AS
BEGIN
   SET NOCOUNT ON

   Declare @b_debug INT, @c_sqlorderby   NVARCHAR(4000) = '',@c_sortlogic NVARCHAR(20)
   SELECT @b_debug= 0

    
   SET @c_sortlogic = ''

   IF ISNULL(LTRIM(RTRIM(@c_lot)),'') <> '' AND LEFT(@c_lot, 1) <> '*'
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)
      WHERE LOT.LOT = LOTATTRIBUTE.LOT
      AND LOTXLOCXID.Lot = LOT.LOT
      AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
      AND LOTXLOCXID.LOC = LOC.LOC
      AND LOC.Facility = @c_facility
      AND LOT.LOT = @c_lot
      ORDER BY LOTATTRIBUTE.LOTTABLE04

      IF @b_debug = 1
      BEGIN
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)
         WHERE LOT.LOT = LOTATTRIBUTE.LOT
         AND LOTXLOCXID.Lot = LOT.LOT
         AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
         AND LOTXLOCXID.LOC = LOC.LOC
         AND LOC.Facility = @c_facility
         AND LOT.LOT = @c_lot
         ORDER BY LOTATTRIBUTE.LOTTABLE04
      END
   END
   ELSE
   BEGIN
      -- Get OrderKey and line Number
      DECLARE @c_OrderKey        NVARCHAR(10),
              @c_OrderLineNumber NVARCHAR(5)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_OtherParms' = @c_OtherParms
      END

      IF ISNULL(RTRIM(@c_OtherParms),'') <> ''
      BEGIN
         SELECT @c_OrderKey = LEFT(ISNULL(RTRIM(@c_OtherParms),''), 10)
         SELECT @c_OrderLineNumber = SUBSTRING(ISNULL(RTRIM(@c_OtherParms),''), 11, 5)
      END

      IF @b_debug = 1
      BEGIN
         SELECT '@c_OrderKey' = @c_OrderKey, '@c_OrderLineNumber' = @c_OrderLineNumber
      END
      -- Get MinShelfLife
      DECLARE @n_ConsigneeMinShelfLife int,
              @n_SKUShelfLife          int,
              @c_LimitString           nvarchar(512),
              @c_FindLottable          nvarchar(10),
              @c_Lottable04Label       nvarchar(20)

      SELECT @n_ConsigneeMinShelfLife = 0
      SELECT @c_Limitstring = ''
      SELECT @c_FindLottable = 'N'

      SELECT @c_Lottable04Label = Lottable04Label
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND Sku = @c_Sku

      DECLARE @c_Condition NVARCHAR(2000)

      IF RTrim(LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "
         SELECT @c_FindLottable = 'Y'
      END
      IF RTrim(LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 "
         SELECT @c_FindLottable = 'Y'
      END
      IF RTrim(LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 "
         SELECT @c_FindLottable = 'Y'
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 "
         SELECT @c_FindLottable = 'Y'
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05  "
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = @c_Lottable06 '
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = @c_Lottable07 '
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = @c_Lottable08 '
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = @c_Lottable09 '
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = @c_Lottable10 '
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = @c_Lottable11 '
         SELECT @c_FindLottable = 'Y'
      END

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = @c_Lottable12 '
         SELECT @c_FindLottable = 'Y'
      END

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE13 = @d_Lottable13 "
         SELECT @c_FindLottable = 'Y'
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE14 = @d_Lottable14 "
         SELECT @c_FindLottable = 'Y'
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE15 = @d_Lottable15 "
         SELECT @c_FindLottable = 'Y'
      END

      IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND @c_FindLottable <> 'Y'
      BEGIN
         SET @c_sortlogic = ''
         SELECT @c_sortlogic = ISNULL(STORER.susr2,'FEFO')
         FROM   ORDERS (NOLOCK)
         JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
         WHERE ORDERS.OrderKey = @c_OrderKey
         AND STORER.[type]='2'

        IF ISNULL(@c_sortlogic,'') = ''
        BEGIN
          SET @c_sortlogic='FEFO'
        END

        IF @c_sortlogic = 'LEFO'
        BEGIN
           SET @c_sqlorderby = " ORDER BY LOTATTRIBUTE.LOTTABLE04 DESC,  LOTATTRIBUTE.LOTTABLE05 "
        END
        ELSE  IF @c_sortlogic = 'FEFO'
        BEGIN
           SET @c_sqlorderby = " ORDER BY LOTATTRIBUTE.LOTTABLE04 ,  LOTATTRIBUTE.LOTTABLE05 "
        END
        

         SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0)
         FROM   ORDERS (NOLOCK)
         JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
         WHERE ORDERS.OrderKey = @c_OrderKey

         IF @b_debug = 1
         BEGIN
            SELECT '@n_ConsigneeMinShelfLife' = @n_ConsigneeMinShelfLife
         END

         -- Modified By SHONG on 8th Apr 2003
         -- Change condition greater or equal to..
         IF @n_ConsigneeMinShelfLife > 0
         BEGIN
            SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND ( DATEDIFF(day, GETDATE(), Lottable04) >= "
            +  " @n_ConsigneeMinShelfLife OR Lottable04 IS NULL) "

            IF @b_debug = 1
            BEGIN
               SELECT '@c_Limitstring' = @c_Limitstring
            END
         END
         ELSE
         BEGIN
            SELECT @n_SKUShelfLife = SKU.ShelfLife--ISNULL(SKU.ShelfLife,0)
            FROM  SKU (NOLOCK)
            WHERE StorerKey = @c_storerkey
              AND SKU   = @c_sku

            IF @b_debug = 1
            BEGIN
               SELECT '@n_SKUShelfLife' = @n_SKUShelfLife
            END

            IF ISNULL(@n_SKUShelfLife,0) > 0
            BEGIN
               SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND ( DATEDIFF(day, GETDATE(), Lottable04) >= "
               + " @n_SKUShelfLife OR Lottable04 IS NULL) "

               IF @b_debug = 1
               BEGIN
                  SELECT '@c_Limitstring' = @c_Limitstring
               END
            END

            IF @n_SKUShelfLife IS NULL
            BEGIN
                SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND 1=2 "
            END
         END
      END

      IF @c_Lottable04Label = 'EXP_DATE'
      BEGIN
         SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND ( DATEDIFF(day, GETDATE(), Lottable04) > 0 "
         +  " OR Lottable04 IS NULL) "

         IF @b_debug = 1
         BEGIN
            SELECT '@c_Limitstring' = @c_Limitstring
         END
      END

      IF @c_UOM = '1' --Pallet
      BEGIN
          SELECT @c_Condition = RTrim(@c_Condition) + " AND SKUXLOC.LocationType NOT IN ('PICK','CASE') "
      END


      DECLARE @c_SQLStatement nvarchar(3999)   = '',@c_FullSQLStatement nvarchar(3999)   = ''
      DECLARE @c_SQLParm nvarchar(3999)  = ''

      SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR " +
      " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +
      -- Start : SOS24348
      -- " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)" +
      " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(LOT.QTYONHOLD) " +
      -- End : SOS24348
      " FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), SKUXLOC (NOLOCK) "  +
      " WHERE LOT.LOT = LOTATTRIBUTE.LOT " +
      " AND LOTXLOCXID.Lot = LOT.LOT " +
      " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
      " AND LOTXLOCXID.LOC = LOC.LOC " +
      " AND LOTXLOCXID.Storerkey = SKUXLOC.Storerkey " +
      " AND LOTXLOCXID.Sku = SKUXLOC.Sku " +
      " AND LOTXLOCXID.Loc = SKUXLOC.Loc " +
      " AND LOC.Facility = @c_facility " +
      " AND LOT.STORERKEY = @c_storerkey " +
      " AND LOT.SKU = @c_sku " +
      " AND LOT.STATUS = 'OK' " +
      -- SOS24348
      -- " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +
      ISNULL(RTRIM(@c_Limitstring),'') +  ISNULL(RTRIM(@c_Condition),'') +
      -- Start : SOS24348
      " GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04,LOTATTRIBUTE.LOTTABLE05 " +
      " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(QTYONHOLD) > 0 " 
      -- End : SOS24348
     -- " ORDER BY LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE05"

--      EXECUTE(@c_SQLStatement)

      SET @c_FullSQLStatement = @c_SQLStatement + CHAR(13) + @c_sqlorderby

      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +
         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
            '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
            '@c_Lottable06 NVARCHAR(30), ' +
            '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' +
            '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' +
            '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
            '@n_ConsigneeMinShelfLife INT, @n_SKUShelfLife INT  '

      EXEC sp_ExecuteSQL @c_FullSQLStatement, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,
                        @d_Lottable04, @d_Lottable05,  @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09,
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                         @n_ConsigneeMinShelfLife , @n_SKUShelfLife



      IF @b_debug = 1
      BEGIN
         SELECT '@c_SQLStatement' = @c_SQLStatement
         SELECT '@c_FullSQLStatement' = @c_FullSQLStatement
      END

   END
END

GO