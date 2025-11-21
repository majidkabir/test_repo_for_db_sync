SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALHNB02                                         */
/* Creation Date: 14-Jun-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-8773 CN HNB Allocation Strategy CR                      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 14-Jun-2022  NJOW    1.0   DEVOPS Combine Script                     */
/* 15-Sep-2022  NJOW02  1.1   WMS-20781 Add lottable09 sorting if       */
/*                            orderdetail.lottable09=''                 */
/************************************************************************/

CREATE PROC [dbo].[nspALHNB02]
   @c_DocumentNo NVARCHAR(10),
   @c_Facility   NVARCHAR(5),
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_Lottable01 NVARCHAR(18),
   @c_Lottable02 NVARCHAR(18),
   @c_Lottable03 NVARCHAR(18),
   @d_Lottable04 DATETIME,
   @d_Lottable05 DATETIME,
   @c_Lottable06 NVARCHAR(30),
   @c_Lottable07 NVARCHAR(30),
   @c_Lottable08 NVARCHAR(30),
   @c_Lottable09 NVARCHAR(30),
   @c_Lottable10 NVARCHAR(30),
   @c_Lottable11 NVARCHAR(30),
   @c_Lottable12 NVARCHAR(30),
   @d_Lottable13 DATETIME,
   @d_Lottable14 DATETIME,
   @d_Lottable15 DATETIME,
   @c_UOM        NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @n_UOMBase    INT,
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @c_SQL                NVARCHAR(MAX),
           @c_SQLParm            NVARCHAR(MAX),
           @c_key1               NVARCHAR(10),
           @c_key2               NVARCHAR(5),
           @c_key3               NCHAR(1),
           @c_Orderkey           NVARCHAR(10),
           @n_QtyAvailable       INT,
           @c_LOT                NVARCHAR(10),
           @c_LOC                NVARCHAR(10),
           @c_ID                 NVARCHAR(18),
           @c_OtherValue         NVARCHAR(20),
           @n_QtyToTake          INT,
           @n_StorerMinShelfLife INT,
           @n_LotQtyAvailable    INT,
           @c_ExtraCondition     NVARCHAR(2000) = '',
           @c_SortingCondition   NVARCHAR(2000) = '',           
           @c_Consigneekey       NVARCHAR(15),
           @c_UDF02_Cond         NVARCHAR(30),
           @c_UDF03_EXPCode      NVARCHAR(30),
           @c_SkuGroup           NVARCHAR(10),
           @n_FromDay            INT = 0,
           @n_ToDay              INT = 99999,
           @c_BUSR6              NVARCHAR(30)

   SET @n_QtyAvailable = 0
   SET @c_OtherValue = '1'
   SET @n_QtyToTake = 0

   IF @n_UOMBase = 0
     SET @n_UOMBase = 1

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))

   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave

      IF ISNULL(@c_key2,'') <> '' --Discrete
      BEGIN
        SELECT @c_Consigneekey = Consigneekey
        FROM ORDERS (NOLOCK)
        WHERE Orderkey = @c_Orderkey        
      END
      ELSE
      BEGIN
      	 SELECT @c_Consigneekey = SUBSTRING(@c_OtherParms, 17, 15)
      END  
   END
   
   SELECT @c_SkuGroup = SkuGroup,
          @c_BUSR6 = BUSR6
   FROM SKU (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Sku = @c_Sku
   
   SELECT TOP 1 @c_UDF02_Cond = UDF02,
                @c_UDF03_EXPCode = UDF03
   FROM CODELKUP (NOLOCK)
   WHERE ListName = 'HBALLOCRUL'
   AND Storerkey = @c_Storerkey
   AND Short = @c_Consigneekey
   AND UDF01 = @c_SkuGroup
   AND UDF04 = @c_BUSR6
   
   IF ISNULL(@c_Lottable02,'') = ''
      SET @c_Lottable02 = ISNULL(@c_UDF02_Cond,'')
   
   IF ISNULL(@c_Lottable09,'') = ''
   BEGIN
      SELECT TOP 1 @n_FromDay = CASE WHEN ISNUMERIC(Short) = 1 THEN CAST(Short AS INT) ELSE 0 END,
                   @n_ToDay = CASE WHEN ISNUMERIC(Long) = 1 THEN CAST(Long AS INT) ELSE 99999 END
      FROM CODELKUP (NOLOCK)
      WHERE ListName = 'HBEXPIRE'
      AND Storerkey = @c_Storerkey
      AND Code = @c_UDF03_EXPCode     
   	 
   	  SET @c_ExtraCondition = ' AND DATEDIFF(Day, GETDATE(), LA.Lottable04) >= @n_FromDay AND DATEDIFF(Day, GETDATE(), LA.Lottable04) <= @n_ToDay '
   
      SET @c_SortingCondition = ' ORDER BY DATEDIFF(Day, GETDATE(), LA.Lottable04), LA.Lottable04,  QTYAVAILABLE, LA.Lottable09, LOC.LogicalLocation, LOC.Loc '   	     	  
   END
   ELSE
   BEGIN
      SET @c_SortingCondition = ' ORDER BY LA.Lottable04,  QTYAVAILABLE, LOC.LogicalLocation, LOC.Loc '   	     	  
   END

   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey

   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   SET @c_SQL = N'
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND (LOC.LocationFlag = ''NONE'') ' +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LA.Lottable04) > GetDate() ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      CHAR(13) + @c_ExtraCondition + CHAR(13) +  @c_SortingCondition

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, ' +
                      '@n_FromDay INT, @n_ToDay INT'

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_FromDay, @n_Today

   SET @c_SQL = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable

   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
   BEGIN

      IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
      BEGIN
        INSERT INTO #TMP_LOT (Lot, QtyAvailable)
        SELECT Lot, Qty - QtyAllocated - QtyPicked
        FROM LOT (NOLOCK)
        WHERE LOT = @c_LOT
      END
      SET @n_LotQtyAvailable = 0

      SELECT @n_LotQtyAvailable = QtyAvailable
      FROM #TMP_LOT
      WHERE Lot = @c_Lot

      IF @n_LotQtyAvailable < @n_QtyAvailable
      BEGIN
        IF @c_UOM = '1'
           SET @n_QtyAvailable = 0
        ELSE
            SET @n_QtyAvailable = @n_LotQtyAvailable
      END

      IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      BEGIN
         SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      END
      ELSE
      BEGIN
        SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      END

      IF @n_QtyToTake > 0
      BEGIN
        UPDATE #TMP_LOT
        SET QtyAvailable = QtyAvailable - @n_QtyToTake
        WHERE Lot = @c_Lot

         IF ISNULL(@c_SQL,'') = ''
         BEGIN
            SET @c_SQL = N'
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + N'
                  UNION ALL
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake
      END

      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
   END -- END WHILE FOR CURSOR_AVAILABLE

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)
   BEGIN
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE
   END

   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
   END
END -- Procedure nspALHNB02

GO