SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispALVF002                                         */    
/* Creation Date: 30-Sep-2012                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Step 2 - Pick Full Case from Bulk (Oddsize/Case/Pallet)     */
/*                   UOM:6                                              */  
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/************************************************************************/    
CREATE PROC [dbo].[ispALVF002]       
   @c_WaveKey    NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 NVARCHAR(20),    
   @d_Lottable05 NVARCHAR(20),    
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT     
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF      

   DECLARE @b_debug       INT,
           @n_count       INT,
           @n_currentRow  INT,
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @c_LocationType     NVARCHAR(10),    
           @c_LocationCategory NVARCHAR(10),
           @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18)

   IF OBJECT_ID('tempdb..#AvailableItems','u') IS NOT NULL
      DROP TABLE #AvailableItems;

   -- Store all OrderDetail in Wave
   CREATE TABLE #AvailableItems (  
     RowID        INT IDENTITY(1,1),
     LOT          NVARCHAR(10),
     LOC          NVARCHAR(10),
     ID           NVARCHAR(18),
     QTYAVAILABLE INT,
     UOMBASE      INT
   )

   SET @n_QtyAvailable = 0  
   SET @n_currentRow = 1
   SET @n_count = 0        
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'VNA'
   SET @c_Lottable01 = ISNULL(RTRIM(@c_Lottable01),'')
   SET @c_Lottable02 = ISNULL(RTRIM(@c_Lottable02),'')
   SET @c_Lottable03 = ISNULL(RTRIM(@c_Lottable03),'')
  
   -- IF SINGLE LOCATION (SAME PACK SIZE) CAN PICK ALL REMAINING QTY IN FULL CASE, PICK FROM THERE,
   -- ELSE PICK FULL CARTON BY LOGICALLOCATION
   SET @c_SQL = N'  
      INSERT INTO #AvailableItems
      SELECT TOP 1 
         LOTxLOCxID.LOT,      
         LOTxLOCxID.LOC,       
         LOTxLOCxID.ID,      
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), 
         UCC.Qty      
      FROM LOTxLOCxID (NOLOCK)       
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT            
      LEFT OUTER JOIN UCC (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID
                                       AND UCC.Status < ''4'')            
      WHERE LOC.LocationFlag <> ''HOLD''      
      AND LOC.LocationFlag <> ''DAMAGE''       
      AND LOC.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.STORERKEY = @c_StorerKey 
      AND LOTxLOCxID.SKU = @c_SKU 
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_QtyLeftToFulfill
      AND @n_QtyLeftToFulfill > 0
      AND @n_QtyLeftToFulfill % UCC.Qty = 0 ' + CHAR(13) +
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ''
           ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''
           ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +
      'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOTxLOCxID.QTY, LOTxLOCxID.QTYALLOCATED, LOTxLOCxID.QTYPICKED, 
                LOTxLOCxID.QtyReplen, UCC.Qty, LOC.LocationHandling, Loc.LogicalLocation, LOC.LOC
      ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOC.LOC'

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '
         
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03 

   SELECT @n_count = COUNT(1) FROM #AvailableItems WITH (NOLOCK)
   IF @n_count = 0
   BEGIN
      SET @c_SQL = N'   
         DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR   
         SELECT 
            LOTxLOCxID.LOT,      
            LOTxLOCxID.LOC,       
            LOTxLOCxID.ID,      
            QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), 
            UCC.Qty      
         FROM LOTxLOCxID (NOLOCK)       
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT            
         LEFT OUTER JOIN UCC (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID
                                          AND UCC.Status < ''4'')        
         WHERE LOC.LocationFlag <> ''HOLD''       
         AND LOC.LocationFlag <> ''DAMAGE''       
         AND LOC.Status <> ''HOLD''       
         AND LOC.Facility = @c_Facility     
         AND LOTxLOCxID.STORERKEY = @c_StorerKey 
         AND LOTxLOCxID.SKU = @c_SKU 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= UCC.Qty ' + CHAR(13) +    
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
              ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
              ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
         'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOTxLOCxID.QTY, LOTxLOCxID.QTYALLOCATED, LOTxLOCxID.QTYPICKED, 
                   LOTxLOCxID.QtyReplen, UCC.Qty, LOC.LocationHandling, Loc.LogicalLocation, LOC.LOC
         ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOC.LOC'

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) ' 
            
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03 

      SET @c_SQL = ''

      OPEN CURSOR_AVAILABLE                 
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UOMBASE 
             
      WHILE (@@FETCH_STATUS <> -1)          
      BEGIN    
         IF @n_QtyLeftToFulfill >= @n_UOMBASE 
         BEGIN
            SET @n_QtyAvailable = CASE WHEN @n_QtyAvailable < @n_QtyLeftToFulfill THEN @n_QtyAvailable ELSE @n_QtyLeftToFulfill END
            SET @n_QtyAvailable = FLOOR(@n_QtyAvailable/@n_UOMBASE) * @n_UOMBASE
            INSERT INTO #AvailableItems VALUES (@c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UOMBASE) 
            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyAvailable
         END

         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UOMBASE  
      END -- END WHILE FOR CURSOR_AVAILABLE      

      IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
      BEGIN          
         CLOSE CURSOR_AVAILABLE          
         DEALLOCATE CURSOR_AVAILABLE          
      END
   END -- IF @n_count = 0
  
   -- Create CURSOR_CANDIDATES
   SELECT @n_count = COUNT(1) FROM #AvailableItems WITH (NOLOCK)
   WHILE (@n_currentRow<=@n_count)
   BEGIN
      SELECT 
         @c_LOT = LOT, 
         @c_LOC = LOC, 
         @c_ID = ID, 
         @n_QtyAvailable = QTYAVAILABLE, 
         @n_UOMBASE = UOMBASE
      FROM #AvailableItems WITH (NOLOCK)
      WHERE RowID = @n_currentRow

    IF @n_currentRow = 1
    BEGIN
         SET @c_SQL = N'   
               DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
               SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
               '
      END
      ELSE
      BEGIN
         SET @c_SQL = @c_SQL + N'  
               UNION
               SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
               '
      END
      SET @n_currentRow = @n_currentRow + 1
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

   IF OBJECT_ID('tempdb..#AvailableItems','u') IS NOT NULL
      DROP TABLE #AvailableItems;

END -- Procedure

GO