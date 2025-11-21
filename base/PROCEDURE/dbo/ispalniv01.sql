SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispALNIV01                                         */    
/* Creation Date: 02-JUNE-2014                                          */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 312318 - Allocate pallet/case from level 2 pallet bulk      */
/*                                                                      */
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
/* Date        Author   Ver.  Purposes                                  */    
/* 25-Nov-2014 NJOW01   1.0   Cater for overallocation lot qty available*/
/* 08-APR-2020 Wan01    1.3   Dynamic SQL review, impact SQL cache log  */ 
/************************************************************************/    
CREATE PROC [dbo].[ispALNIV01]        
   @c_LoadKey    NVARCHAR(10),  
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
   --SET QUOTED_IDENTIFIER OFF 
   --SET ANSI_NULLS OFF    

   DECLARE @b_debug       INT,      
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT,
           @c_LogicalLocation  NVARCHAR(18),
           @n_StorerMinShelfLife INT,
           @c_PrevLOT          NVARCHAR(10),
           @n_cnt              INT,
           @n_LotQtyAvailable  INT
           --@n_Level1Qty          INT,
           --@n_LocQty             INT,
           --@n_NoOfLot            INT

   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   
   EXEC isp_Init_Allocate_Candidates   --(Wan01)   

   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   --AND Sku.Facility = @c_facility  
   
   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),
             LA.Lottable02,
             LA.Lottable05,
             LOC.LogicalLocation 
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND SL.LocationType NOT IN (''PICK'',''CASE'')
      AND LOC.LocLevel = 2
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +
      CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, @n_StorerMinShelfLife, LA.Lottable04) > GetDate() ' ELSE ' ' + CHAR(13) END +      --(Wan01) 
      CASE WHEN @c_UOM = '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) <= @n_QtyLeftToFulfill ' ELSE ' ' + CHAR(13) END + 
      CASE WHEN @c_UOM = '2' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase ' ELSE ' ' + CHAR(13) END + CHAR(13) +
      ' ORDER BY LA.Lottable04, 4, LOC.LogicalLocation, LOC.LOC'

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @n_StorerMinShelfLife INT '                --(Wan01)

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03 
                           ,  @n_StorerMinShelfLife                                                                                                   --(Wan01)

   SET @c_SQL = ''
   SET @c_PrevLOT = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_Lottable02, @d_Lottable05, @c_LogicalLocation   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
      IF @c_LOT <> @c_PrevLOT 
      BEGIN
          SELECT @n_LotQtyAvailable = SUM(Qty - QtyAllocated - QtyPicked)
          FROM LOT (NOLOCK)
          WHERE LOT = @c_LOT
      END
      
      IF @n_LotQtyAvailable < @n_QtyAvailable 
      BEGIN
          IF @c_UOM = '1' 
             SET @n_QtyAvailable = 0
          ELSE
            SET @n_QtyAvailable = @n_LotQtyAvailable
      END
                  
        /*
        IF @c_UOM = '1' AND @c_PrevLOT <> '' AND @c_LOT <> @c_PrevLOT
        BEGIN
          --If the previous lot can find remaining full carton in level 1 then deduct the qty allocate from level 2 on the following lot
          --and let next strategy allocate full carton from level 1 to achieve FEFO by 2, 1
         SET @n_Level1Qty = 0
      
         SELECT @n_Level1Qty = SUM(FLOOR((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) /  PACK.CaseCnt) * PACK.CaseCnt)                
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
         JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
         JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku) 
         JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE LOC.LocationFlag <> 'HOLD'
         AND LOC.LocationFlag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOT.Status <> 'HOLD'
         AND ID.Status <> 'HOLD'
         AND SL.LocationType NOT IN ('PICK','CASE')
         AND LOC.LocLevel = 1
         AND LOC.Facility = @c_Facility
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= PACK.CaseCnt
         AND LOTxLOCxID.STORERKEY = @c_StorerKey
         AND LOTxLOCxID.SKU = @c_SKU
         AND LA.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN LA.Lottable01 ELSE @c_Lottable01 END
         AND LA.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN LA.Lottable02 ELSE @c_Lottable02 END
         AND LA.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN LA.Lottable03 ELSE @c_Lottable03 END
         AND (DateAdd(Day, @n_StorerMinShelfLife, LA.Lottable04) > GetDate() OR  @n_StorerMinShelfLife = 0)
         AND LOTXLOCXID.Lot = @c_PrevLOT
         
         IF ISNULL(@n_Level1Qty,0) > 0
            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_Level1Qty   
        END
      */
      
      /*
      IF @c_UOM = '1' AND @c_LOT <> @c_PrevLOT 
      BEGIN      
          --By FEFO, if any lot unable to find full pallet will stop and proceed to next strategy step
         SET @n_cnt = 0
      
         SELECT @n_cnt = COUNT(1) 
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
         JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
         WHERE LOC.LocationFlag <> 'HOLD'
         AND LOC.LocationFlag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOT.Status <> 'HOLD'
         AND ID.Status <> 'HOLD'
         AND SL.LocationType NOT IN ('PICK','CASE')
         AND LOC.LocLevel = 2
         AND LOC.Facility = @c_Facility
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) <= @n_QtyLeftToFulfill 
         AND LOTXLOCXID.Lot = @c_LOT
         
         IF @n_cnt = 0
            GOTO EXIT_SP
      END
      */
                  
      IF @c_UOM = '1' --Pallet
      BEGIN
         /*
         SELECT @n_LocQty = 0, @n_NoOfLot = 0
              
         SELECT @n_LocQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen),
                @n_NoOfLot = COUNT(DISTINCT LLI.Lot)
         FROM LOTXLOCXID LLI (NOLOCK)
         WHERE LLI.Loc = @c_LOC
         AND LLI.ID = @c_ID
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku 
         */            
         
         IF @n_QtyLeftToFulfill >= @n_QtyAvailable 
            --AND @n_NoOfLot = 1 -- if multi lot per sku/loc/id then proceed to next strategy allocation by carton
         BEGIN                       
            SET @n_QtyToTake = @n_QtyAvailable  
         END
         ELSE
         BEGIN
              SET @n_QtyToTake = 0
            GOTO EXIT_SP
         END
      END

      IF @c_UOM = '2' --Case 
      BEGIN
          IF @n_QtyLeftToFulfill >= @n_QtyAvailable
          BEGIN
                SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
          END
          ELSE
          BEGIN
              SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
          END         
      END
      
      IF @n_QtyToTake > 0
      BEGIN
          IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1'
             SET @c_OtherValue = 'FULLPALLET' 
         ELSE
             SET @c_OtherValue = '1'          
         --(Wan01) - START
         --IF ISNULL(@c_SQL,'') = ''
         --BEGIN
         --   SET @c_SQL = N'   
         --         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
         --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
         --         '
         --END
         --ELSE
         --BEGIN
         --   SET @c_SQL = @c_SQL + N'  
         --         UNION ALL
         --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
         --         '
         --END
         
         SET @c_LOT = ISNULL(@c_LOT,'')
         SET @c_LOC = ISNULL(@c_LOC,'')
         SET @c_ID  = ISNULL(@c_ID,'')
         
         EXEC [isp_Insert_Allocate_Candidates] 
               @c_LOT   = @c_LOT 
            ,  @c_LOC   = @c_LOC 
            ,  @c_ID    = @c_ID  
            ,  @n_QtyAvailable = @n_QtyToTake
            ,  @c_OtherValue   = @c_OtherValue 
         --(Wan01) - END
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
         SET @n_LotQtyAvailable = @n_LotQtyAvailable - @n_QtyToTake    
      END
      
      SET @c_PrevLOT = @c_LOT
      
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_Lottable02, @d_Lottable05, @c_LogicalLocation  
   END -- END WHILE FOR CURSOR_AVAILABLE          

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   --(Wan01) - START
   EXEC isp_Cursor_Allocate_Candidates 
      @n_SkipPreAllocationFlag = 1  -- Return Lot 
   --IF ISNULL(@c_SQL,'') <> ''
   --BEGIN
   --   EXEC sp_ExecuteSQL @c_SQL
   --END
   --ELSE
   --BEGIN
   --   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   --   SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   --END
   --(Wan01) - END
END -- Procedure

GO