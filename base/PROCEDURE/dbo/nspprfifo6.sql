SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRFIFO6                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Pre-Allocation Strategy of Kellogg                          */
/*          Notes: Turn on configkey 'OrderInfo4Preallocation'          */
/*          Sort by Lottable03,Lottable04                               */
/*                                                                      */
/* Called By: nspPrealLOCateOrderProcessing                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 19-May-2011 SPChin   1.1   SOS215166 - Pre-Allocation Strategy of    */
/*                                    Kellogg                           */
/* 02-Jan-2020 Wan01    1.2   Dynamic SQL review, impact SQL cache log  */  
/************************************************************************/

CREATE PROC [dbo].[nspPRFIFO6]
   @c_storerkey NVARCHAR(15),
   @c_sku NVARCHAR(20),
   @c_lot NVARCHAR(10),
   @c_lottable01 NVARCHAR(18),
   @c_lottable02 NVARCHAR(18),
   @c_lottable03 NVARCHAR(18),
   @d_lottable04 datetime,
   @d_lottable05 datetime,
   @c_uom NVARCHAR(10),
   @c_facility NVARCHAR(10),
   @n_uombase int,
   @n_qtylefttofulfill int,
   @c_OtherParms NVARCHAR(200)
AS
BEGIN

   DECLARE
      @b_debug   int,
      @c_SQL     nvarchar(4000)

   SELECT @b_debug = 0
   SELECT @c_SQL = ''

   DECLARE
      @c_LimitString               NVARCHAR(255),
      @c_OrderKey                  NVARCHAR(10),
      @n_SkuShelfLife              int,
      @n_ConsigneeMinShelfLifePerc int, -- STORER.MinShelfLife (store as percentage, eg. 20 means 20%)
      @n_ConsigneeShelfLife        int,
      @n_SkuOutgoingShelfLife      int, -- SKU.SUSR2
      @c_ShelfLife                 int

   DECLARE  @c_SQLParms  NVARCHAR(4000) = ''  --(Wan01) 

   -- Get OrderKey
   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(LTRIM(RTRIM(@c_OtherParms)), 10)
   END

   -- If @c_lot is not null
   IF ISNULL(RTRIM(@c_lot),'') <> ''
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOT.StorerKey, LOT.SKU, LOT.LOT,
            QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0))
         FROM LOTXLOCXID WITH (NOLOCK)
         JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOTATTRIBUTE.LOT)
         JOIN LOC WITH (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC)
         JOIN ID WITH (NOLOCK) ON (LOTXLOCXID.ID = ID.ID)
         LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)
                          FROM   PREALLOCATEPICKDETAIL P WITH (NOLOCK), ORDERS WITH (NOLOCK)
                          WHERE  P.Orderkey = ORDERS.Orderkey
                          AND    P.StorerKey = RTRIM(@c_storerkey)
                          AND    P.SKU = RTRIM(@c_sku)
                          AND    P.Qty > 0
                          GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility
         WHERE LOTXLOCXID.LOT = @c_lot
            AND LOTXLOCXID.Qty > 0
            AND LOT.Status = 'OK'
            AND ID.Status = 'OK'
            AND LOC.Facility = RTRIM(@c_facility)
            AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'
         GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT
         HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0
   END
   ELSE
   BEGIN
      SELECT @c_LimitString = ''

      IF @c_lottable01 <> ' '
         SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND Lottable01= @c_lottable01"

      IF @c_lottable02 <> ' '
         SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable02= @c_lottable02"

      IF @c_lottable03 <> ' '
         SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable03= @c_lottable03"

      IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
         SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable04 = @d_lottable04"

      IF @d_lottable05 IS NOT NULL AND @d_lottable05 <> '1900-01-01'
         SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable05= @d_lottable05"

      -- Get SKU ShelfLife, SKU Outgoing ShelfLife(SKU.SUSR2)
      SELECT @n_SkuShelfLife = ISNULL(SKU.Shelflife, 0) ,
             @n_SkuOutgoingShelfLife = ISNULL(CAST(SKU.SUSR2 as int), 0)
      FROM   SKU WITH (NOLOCK)
      WHERE  SKU.StorerKey = RTRIM(@c_storerkey)
      AND    SKU.SKU = RTRIM(@c_sku)

      -- Get Consignee MinShelfLife (store as int, but calculate in percentage)
      SELECT @n_ConsigneeMinShelfLifePerc = ISNULL( STORER.MinShelfLife, 0)
      FROM   ORDERS WITH (NOLOCK)
      JOIN   STORER WITH (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
      WHERE  OrderKey = @c_OrderKey

      IF ISNULL(RTRIM(@c_LimitString),'') <> ''
      BEGIN
         SET @c_Limitstring = RTRIM(@c_LimitString)
         SET @c_ShelfLife = 1
      END  --Lottables found
      ELSE
      BEGIN
         IF @n_ConsigneeMinShelfLifePerc > 0
         BEGIN
            SELECT @n_ConsigneeShelfLife = (@n_SkuShelfLife * @n_ConsigneeMinShelfLifePerc) / 100
            SET @c_ShelfLife = @n_ConsigneeShelfLife
         END
         ELSE
         BEGIN
            SET @c_ShelfLife = @n_SkuOutgoingShelfLife
         END

         SET @c_Limitstring = RTRIM(@c_LimitString) + " AND(DATEDIFF(Day, GETDATE(), Lottable04)) >= @c_ShelfLife "  
      END

      IF ISNULL(@c_ShelfLife,0) > 0
      BEGIN
         -- For Preallocate cursor
         SELECT @c_SQL = "DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
         " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, " +
         " QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) " +
         " FROM LOTXLOCXID WITH (NOLOCK) " +
         " JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) " +
         " JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOTATTRIBUTE.LOT) " +
         " JOIN LOC WITH (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC) " +
         " JOIN ID WITH (NOLOCK) ON (LOTXLOCXID.ID = ID.ID) " +
         " LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +
         "                FROM   PREALLOCATEPICKDETAIL P WITH (NOLOCK), ORDERS WITH (NOLOCK) " +
         "                WHERE  P.Orderkey = ORDERS.OrderKey " +
         "                AND    P.StorerKey = @c_storerkey " +
         "                AND    P.SKU = @c_sku " +
         "                AND    P.Qty > 0 " +
         "                GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility " +
         " WHERE LOTXLOCXID.StorerKey = @c_storerkey " +
         "   AND LOTXLOCXID.SKU = @c_sku " +
         "   AND LOTXLOCXID.Qty > 0 " +
         "   AND LOT.Status = 'OK' " +
         "   AND LOC.Facility = @c_facility " +
         "   AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE' " +
         "   AND ID.Status = 'OK' " + RTRIM(@c_LimitString) + " " +
         " GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03 " +
         " HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0 " +
         " ORDER BY LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04 "
         --Wan01 - START
         SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                        + ',@c_storerkey  NVARCHAR(15)'
                        + ',@c_SKU        NVARCHAR(20)'
                        + ',@c_Lottable01 NVARCHAR(18)'
                        + ',@c_Lottable02 NVARCHAR(18)'
                        + ',@c_Lottable03 NVARCHAR(18)'
                        + ',@d_lottable04 datetime'
                        + ',@d_lottable05 datetime'
                        + ',@c_ShelfLife  int'
      
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_Storerkey, @c_SKU
                           ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                           ,@c_ShelfLife 
         --Wan01 - END 
      END
      ELSE
      BEGIN
         -- Dummy Cursor when Consignee MinShelfLife and SKU.SUSR2 is zero/blank
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
         FOR
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM LOT WITH (NOLOCK)
         WHERE GetDate() > GetDate()
         ORDER BY Lot.Lot
      END

      --EXEC (@c_SQL)   --(Wan01)

      IF @b_debug = 1
      BEGIN
          SELECT @c_SQL '@c_SQL'
      END

   END
END

GO