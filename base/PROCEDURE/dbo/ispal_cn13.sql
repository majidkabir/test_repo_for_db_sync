SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: ispAL_CN13                                          */
/* Creation Date: 04-AUG-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-23283 - CN Junjiu Allocation                             */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 04-AUG-2023  NJOW01  1.0   DEVOPS combine script                      */
/*************************************************************************/
CREATE   PROC [dbo].[ispAL_CN13]
   @c_WaveKey    NVARCHAR(10),
   @c_Facility   NVARCHAR(5),
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_Lottable01 NVARCHAR(18),
   @c_Lottable02 NVARCHAR(18),
   @c_Lottable03 NVARCHAR(18),
   @d_Lottable04 DATETIME,
   @d_Lottable05 DATETIME,
   @c_Lottable06 NVARCHAR(30) = '',
   @c_Lottable07 NVARCHAR(30) = '',
   @c_Lottable08 NVARCHAR(30) = '',
   @c_Lottable09 NVARCHAR(30) = '',
   @c_Lottable10 NVARCHAR(30) = '',
   @c_Lottable11 NVARCHAR(30) = '',
   @c_Lottable12 NVARCHAR(30) = '',
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

   DECLARE @c_SQL          NVARCHAR(MAX),
           @c_SQLParm      NVARCHAR(MAX),
           @c_SortBy       NVARCHAR(2000),
           @c_Condition    NVARCHAR(4000) = '',
           @n_ExpiryMaxDay INT = 0,
           @n_ShelfLife    INT = 0

   DECLARE @c_LocationType     NVARCHAR(100),
           @c_LocationCategory NVARCHAR(100)

   DECLARE @c_key1        NVARCHAR(10),
           @c_key2        NVARCHAR(5),
           @c_key3        NCHAR(1)

   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave
   END
   
   IF ISNULL(@c_Lottable03,'') = '' AND ISNULL(@c_Lottable02,'') <> '' 
   BEGIN
   	  SELECT TOP 1 @n_ExpiryMaxDay = CASE WHEN ISNUMERIC(CL2.Short) = 1 THEN CAST(CL2.Short AS INT) ELSE 0 END
   	  FROM CODELKUP CL (NOLOCK)
   	  JOIN CODELKUP CL2 (NOLOCK) ON CL2.ListName = 'JUNJEXPIRY' AND CL.UDF03 = CL2.Code AND CL.Storerkey = CL2.Storerkey
   	  WHERE CL.ListName = 'JJALLOCRUL'
   	  AND CL.Short = @c_Lottable02
   	  AND CL.Storerkey = @c_Storerkey
   	  
   	  IF @@ROWCOUNT > 0
   	  BEGIN
   	     SELECT @n_ShelfLife = ShelfLife
   	     FROM SKU (NOLOCK)
   	     WHERE Storerkey = @c_Storerkey
   	     AND Sku = @c_sku
   	        	     
   	     SELECT @n_ShelfLife = ISNULL(@n_Shelflife,0) - ISNULL(@n_ExpiryMaxDay,0)   	     
   	     
   	     SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND DATEDIFF(Day, GETDATE(), DATEADD(Day,' + CAST(@n_ShelfLife AS NVARCHAR) + ',LA.Lottable04)) > 0 '    	     
   	  END   	     	  
   END
      
   SET @c_LocationType = ''
   SET @c_LocationCategory = ''
   SET @c_SortBy = 'ORDER BY LA.Lottable04, LOC.LogicalLocation, LOC.Loc'

   SET @c_SQL = N'
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), ''1''
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      WHERE LOC.LocationFlag = ''NONE''
      AND LOC.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ''
           ELSE ' AND LOC.LocationType IN(' + @c_LocationType + ')' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''
           ELSE ' AND LOC.LocationCategory IN(' + @c_LocationCategory + ')' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      ISNULL(@c_Condition,'') +
    ' GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.LogicalLocation, LOC.LOC, LA.Lottable05, LA.Lottable04 ' +
      @c_SortBy

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' +
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +
                      '@c_Lottable12 NVARCHAR(30), @n_UOMBase INT '

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_UOMBase

END -- Procedure

GO