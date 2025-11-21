SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPRTWPG8                                         */
/* Creation Date:                                                       */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Sort by Lottable04, Lottable05                              */
/*          Getting from Location with Min Qty, and Logical Loaction    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 20-11-2013   Shong   1.0   SOS#291875 - Design For TW P&G Requirement*/
/* 27-12-2013   Leong   1.1   SOS#299047 - Include LOT.QtyPreAllocated  */
/* 24-01-2014   Shong   1.2   Fixing Issues caused by SOS#299047        */
/* 25-02-2014   audrey  1.3   SOS#304394 - Bug fixed             (ang01)*/
/* 22-09-2021   WLChooi 1.4   DEVOPS Combine Script                     */
/* 22-09-2021   WLChooi 1.5   WMS-18018 - Filter LocationCategory based */
/*                            on Codelkup (WL01)                        */
/************************************************************************/
CREATE PROC [dbo].[nspPRTWPG8] (   
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_LOT        NVARCHAR(10),
   @c_Lottable01 NVARCHAR(18),
   @c_Lottable02 NVARCHAR(18),
   @c_Lottable03 NVARCHAR(18),
   @d_Lottable04 DATETIME,
   @d_Lottable05 DATETIME,
   @c_UOM        NVARCHAR(10),
   @c_Facility   NVARCHAR(10),  -- added By Ricky for IDSV5
   @n_UOMBase    INT,
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_ConsigneeMinShelfLife INT,
           @c_Condition    NVARCHAR(MAX) = '',   --WL01
           @c_UOMBase      NVARCHAR(10),
           @n_CaseCnt      INT,
           @n_QtyAvailable INT,
           @c_SelectedLOT  NVARCHAR(10),
           @d_SelectedLot4 DATETIME,
           @c_LOC          NVARCHAR(10),
           @n_Qty          INT,
           @c_ID           NVARCHAR(18),
           @c_CursorStmnt  NVARCHAR(MAX),
           @c_CaseCnt      NVARCHAR(10),
           @n_LotQtyAvail  INT

   SET @c_UOMBase = RTRIM(CAST ( @n_uombase AS NVARCHAR(10)))

   DECLARE @t_LOTXLOCXID AS TABLE (LOT NVARCHAR(10), LOC NVARCHAR(10), ID NVARCHAR(18), Qty INT)

   --WL01 S
   DECLARE @c_LocationCategory       NVARCHAR(255) = ''
   
   SELECT @c_LocationCategory = ISNULL(CL.Code2,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'PKCODECFG'
   AND CL.Code = 'FILTERLOCCATEGRY'
   AND CL.Short = 'Y'
   AND CL.Storerkey = @c_StorerKey
   --WL01 E 

   IF ISNULL(LTRIM(RTRIM(@c_LOT)) ,'') <> '' AND LEFT(@c_LOT ,1) <> '*'
   BEGIN

      /* Get Storer Minimum Shelf Life */
      SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)
      FROM   STORER (NOLOCK)
      WHERE  StorerKey = @c_Lottable03

      SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1),
             @n_CaseCnt = PACK.Pallet,
             @c_CaseCnt = CAST(PACK.Pallet AS VARCHAR(10))
      FROM  Sku (NOLOCK)
      JOIN PACK (NOLOCK) ON PACK.PACKKey = Sku.PACKKey
      WHERE Sku.Sku = @c_SKU
      AND   Sku.StorerKey = @c_StorerKey

      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR
      SELECT LOT.StorerKey, LOT.SKU, LOT.LOT,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), Lotattribute (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK)
      WHERE LOT.LOT = @c_LOT
      AND Lot.Lot = Lotattribute.Lot
      AND LOTxLOCxID.Lot = LOT.LOT
      AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
      AND LOTxLOCxID.LOC = LOC.LOC
      AND LOC.Facility = @c_Facility
      AND DATEADD(Day, @n_ConsigneeMinShelfLife, Lotattribute.Lottable04) > GETDATE()

      GOTO EXIT_SP
   END
   ELSE
   BEGIN
      SELECT @n_CaseCnt = PACK.CaseCnt,
             @c_CaseCnt = CAST(PACK.CaseCnt AS VARCHAR(10))
      FROM  Sku (NOLOCK)
      JOIN PACK (NOLOCK) ON PACK.PACKKey = Sku.PACKKey
      WHERE Sku.Sku = @c_SKU
      AND   Sku.StorerKey = @c_StorerKey

      IF @c_UOM = '7' AND LEFT(RTRIM(@c_LOT),1) <> '*'
      BEGIN
         DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, 0
         FROM LOT WITH (NOLOCK)
         WHERE 1=2

         GOTO EXIT_SP
      END

      DECLARE @c_OrderKey  NVARCHAR(10),
              @c_OrderType NVARCHAR(10)

      IF LEN(@c_OtherParms) > 0
      BEGIN
         SET @c_OrderKey = LEFT(@c_OtherParms,10)

         SET @c_OrderType = ''
         SELECT @c_OrderType = TYPE
         FROM   ORDERS WITH (NOLOCK)
         WHERE  OrderKey = @c_OrderKey

         IF @c_OrderType = 'VAS'
         BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND RIGHT(RTRIM(Lotattribute.Lottable02),1) <> 'Z' "
         END
      END

      --WL01 S
      IF ISNULL(@c_LocationCategory,'') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) +
                               ' AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit ('','', N''' + @c_LocationCategory + ''') ) '
      END
      --WL01 E

      IF LEN(ISNULL(RTRIM(@c_LOT),'')) > 1 AND LEFT(@c_LOT,1) = '*'
      BEGIN
         -- Minimum Shelf Life provided
         SELECT @n_ConsigneeMinShelfLife = CASE WHEN ISNUMERIC(RIGHT(RTRIM(@c_LOT), LEN(RTRIM(@c_LOT)) - 1)) = 1
                                                   THEN CAST(RIGHT(RTRIM(@c_LOT), LEN(RTRIM(@c_LOT)) - 1) AS INT) * -1
                                                ELSE 0
                                           END
      END
      IF ISNULL(@n_ConsigneeMinShelfLife,0) = 0
      BEGIN
         /* Get Storer Minimum Shelf Life */
         /* Lottable03 = Consignee Key */
         SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)
         FROM   STORER (NOLOCK)
         WHERE  StorerKey = RTRIM(@c_Lottable03)

         SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)
         FROM  Sku (NOLOCK)
         WHERE Sku.Sku = @c_SKU
         AND   Sku.StorerKey = @c_StorerKey

         IF @n_ConsigneeMinShelfLife IS NULL
            SELECT @n_ConsigneeMinShelfLife = 0
      END

      -- Lottable01 is used for loc.HostWhCode -- modified by Jeff
      IF ISNULL(RTRIM(@c_Lottable01),'') <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN           SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.HostWhCode = N'" + ISNULL(RTRIM(@c_Lottable01),'') + "' "
      END

      IF ISNULL(RTRIM(@c_Lottable02),'') <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND Lottable02 = N'" + ISNULL(RTRIM(@c_Lottable02),'') + "' "
      END

      IF CONVERT(CHAR(8), @d_Lottable04, 112) <> '19000101' AND @d_Lottable04 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND (Lotattribute.Lottable04 >= N'" + RTRIM(CONVERT(CHAR(8), @d_Lottable04, 112)) + "') "
      END
      ELSE
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND (DATEADD(Day, " + CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GETDATE() "
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " OR Lotattribute.Lottable04 IS NULL) "
      END

      SELECT @c_condition = ISNULL(RTRIM(@c_Condition),'') + " GROUP BY LOT.StorerKey, LOT.Sku, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.LOT "
      --SELECT @c_condition = ISNULL(RTRIM(@c_Condition),'') + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= " + RTRIM(CAST ( @n_uombase AS NVARCHAR(10))) + " "  (ang01)

      SELECT @c_condition = ISNULL(RTRIM(@c_Condition),'') + " HAVING CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
      "      THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "      WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
      " THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "      ELSE   " +
      "        SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "        - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
      "      END  >= " + RTRIM(CAST ( @n_uombase AS NVARCHAR(10))) + " " --(ang01)

      IF @n_ConsigneeMinShelfLife = 0
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                             " ORDER BY LOTATTRIBUTE.Lottable04, " +
                       " LOTATTRIBUTE.Lottable05, MIN(LOC.LOC) "
      END
      ELSE
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                             " ORDER BY  " +
                             " LOTATTRIBUTE.Lottable04, "  +
                             " LOTATTRIBUTE.Lottable05, MIN(LOC.LOC) "
      END

      EXEC (" DECLARE  LOT_CURSOR CURSOR FAST_FORWARD READ_ONLY FOR " +
         " SELECT LOT.LOT, LOTATTRIBUTE.Lottable04, "  +
         " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
         "      THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
         "      WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
         " THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
         "      ELSE   " +
         "        SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
         "        - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
         "      END " +
         " FROM LOTxLOCxID (NOLOCK) " +
         " JOIN LOT (NOLOCK) ON LOT.LOT = LOTxLOCxID.Lot " +
         " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
         " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " +
         " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
         " JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +
         " AND SKUxLOC.SKU = LOTxLOCxID.SKU " +
         " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +
         " LEFT OUTER JOIN (SELECT PP.lot, ORDERS.facility, QtyPreallocated = SUM(PP.Qty) " +
         "                   FROM PreallocatePickdetail PP (NOLOCK), ORDERS (NOLOCK) " +
         "                   WHERE PP.Orderkey = ORDERS.Orderkey " +
         "                   AND   PP.Storerkey = N'" + @c_StorerKey + "' " +
         "                   AND   PP.SKU = N'" + @c_SKU + "' " +
         "                   GROUP BY PP.Lot, ORDERS.Facility) p ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility " +
         " LEFT OUTER JOIN (SELECT DISTINCT LLI.Lot FROM LOTXLOCXID LLI (NOLOCK) JOIN SKUXLOC SL ON LLI.Storerkey = SL.Storerkey " +
         "                                                              AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc " +
         "                  WHERE SL.Locationtype NOT IN ('PICK','CASE') " +
         "                  AND LLI.Storerkey = N'" + @c_StorerKey + "' " +
  "                  AND LLI.Sku = N'" + @c_SKU + "' "+
         "                  AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0) bulkloc ON LOTXLOCXID.Lot = bulkloc.lot "  +
         " WHERE LOT.StorerKey = N'" + @c_StorerKey + "' " +
         " AND LOT.SKU = N'" + @c_SKU + "' " +
         " AND LOT.STATUS = 'OK' " +
         " AND ID.STATUS <> 'HOLD' " +
         " AND LOC.Status = 'OK' " +
         " AND LOC.Facility = N'" + @c_Facility + "' " +
         " AND LOC.LocationFlag <> 'HOLD' " +
         " AND LOC.LocationFlag <> 'DAMAGE' " +
         " AND LOTxLOCxID.StorerKey = N'" + @c_StorerKey + "' " +
         " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " +
         " AND LOTATTRIBUTE.StorerKey = N'" + @c_StorerKey + "' " +
         @c_Condition )

      OPEN LOT_CURSOR

      SET @c_CursorStmnt = ' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13) +
                           ' SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, 0 AS Qty ' + CHAR(13) +
                           ' FROM LOT WITH (NOLOCK) ' +  CHAR(13) +
                           ' WHERE 1=2 ' + CHAR(13)

      FETCH NEXT FROM LOT_CURSOR INTO @c_SelectedLOT, @d_SelectedLot4, @n_QtyAvailable
      WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFulfill > 0
      BEGIN
         -- Find the exact match qty location
         SET @n_Qty = 0
         SET @c_LOC = ''
         SET @c_ID  = ''

         DECLARE CUR_LOTxLOCxID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Loc,
                LLI.Id,
                LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC L WITH (NOLOCK) ON L.Loc = LLI.Loc AND L.LocationFlag NOT IN ('HOLD','DAMAGE') AND L.Status = 'OK'
         JOIN ID WITH (NOLOCK) ON ID.Id = LLI.Id AND ID.[Status] = 'OK'
         WHERE LLI.Lot = @c_SelectedLOT
         AND NOT EXISTS(SELECT 1 FROM @t_LOTXLOCXID TB WHERE LLI.Lot = TB.Lot AND LLI.Loc = TB.Loc AND LLI.Id = TB.Id)
         AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
         ORDER BY LLI.Qty, L.LogicalLocation, L.Loc

         OPEN CUR_LOTxLOCxID

         FETCH NEXT FROM CUR_LOTxLOCxID INTO @c_LOC, @c_ID, @n_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_LotQtyAvail = 0

            SELECT @n_LotQtyAvail = (Qty - QtyAllocated - QtyPicked - QtyPreAllocated)
            FROM LOT WITH (NOLOCK)
            WHERE LOT = @c_SelectedLOT

            IF @n_Qty < @n_LotQtyAvail
            BEGIN
               IF @n_LotQtyAvail > 0
                  SET @n_Qty = @n_LotQtyAvail
               ELSE
                  BREAK
            END

            IF @n_QtyAvailable < @n_Qty AND @n_QtyAvailable > 0
               SET @n_Qty = @n_QtyAvailable

            IF @n_Qty > 0
            BEGIN
               SET @c_CursorStmnt = RTRIM(@c_CursorStmnt) + ' UNION ALL SELECT ''' + @c_StorerKey + ''', ''' + @c_SKU + ''', ''' +
                                    @c_SelectedLOT + ''', ' + CAST(@n_Qty AS VARCHAR(10)) +  CHAR(13)
               INSERT INTO @t_LOTXLOCXID VALUES (@c_SelectedLOT, @c_LOC, @c_ID, @n_Qty)

               SET @n_QtyAvailable = @n_QtyAvailable - @n_Qty
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_Qty
            END

            IF @n_QtyLeftToFulfill = 0 OR @n_QtyAvailable = 0
            BREAK

            FETCH NEXT FROM CUR_LOTxLOCxID INTO @c_LOC, @c_ID, @n_Qty
         END
         CLOSE CUR_LOTxLOCxID
         DEALLOCATE CUR_LOTxLOCxID

         FETCH_NEXT:

         FETCH NEXT FROM LOT_CURSOR INTO @c_SelectedLOT, @d_SelectedLot4, @n_QtyAvailable
      END
      CLOSE LOT_CURSOR
      DEALLOCATE LOT_CURSOR

      --PRINT @c_CursorStmnt
      EXEC( @c_CursorStmnt )
   END
   EXIT_SP:
END


GO