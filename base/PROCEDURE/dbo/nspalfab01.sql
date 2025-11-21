SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALFAB01                                         */    
/* Creation Date: 26-FBR-2019                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-7840 CN Fabory allocate strategy                        */
/*          - Full pallet by ID                                         */
/*          - Full case by UCC.Qty of same lottable02. Last partial ctn */
/*            pick as full carton. For modulized sku only               */
/*          - inner pick for none modulized sku with innerpack only     */
/*          - Loose pick for none modulized sku without innerpack only  */
/*                                                                      */
/*          allocation from bulk. SkipPreallocation = '1'               */
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
/************************************************************************/    
CREATE PROC [dbo].[nspALFAB01]        
   @c_Orderey    NVARCHAR(10),  
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

   DECLARE @b_debug       INT,      
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @n_QtyAvailable        INT,  
           @c_LOT                 NVARCHAR(10),
           @c_LOC                 NVARCHAR(10),
           @c_ID                  NVARCHAR(18), 
           @c_OtherValue          NVARCHAR(20),
           @n_QtyToTake           INT,
           @n_QtyToTake_LastCtn   INT,
           @c_LogicalLocation     NVARCHAR(18),
           @n_StorerMinShelfLife  INT,
           @n_cnt                 INT,
           @n_LotQtyAvailable     INT,
           @n_LocQty              INT,
           @n_NoOfLot             INT,
           @c_Source              NCHAR(1),
           @c_Modulized           NVARCHAR(30),
           @n_UCCQty              INT,
           @n_RequireQty          INT,
           @n_InnerPack           FLOAT

   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   SET @n_RequireQty = @n_QtyLeftToFulfill
   
   SELECT @c_Source = SUBSTRING(@c_OtherParms, 16, 1)
   
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))

   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1),
          @c_Modulized = SKU.Busr1,
          @n_InnerPack = SKU.InnerPack
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   
   IF @c_UOM ='2' AND ISNULL(@c_Modulized,'') <> 'Y'  --Only modulized sku have case allocation
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL       	
      
      RETURN
   END

   IF @c_UOM ='3' AND (ISNULL(@c_Modulized,'') = 'Y' OR ISNULL(@n_InnerPack,0) = 0)   --Only non-modulized sku have inner allocation and innerpack setup
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL       	
      
      RETURN
   END

   IF @c_UOM ='6' AND (ISNULL(@c_Modulized,'') = 'Y' OR ISNULL(@n_InnerPack,0) > 0)   --Only non-modulized sku have loose allocation and without innerpack setup
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL       	
      
      RETURN
   END
   
   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),
             ISNULL(UCC.Qty,0)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      OUTER APPLY (SELECT MAX(UCC.Qty) AS Qty FROM UCC (NOLOCK)
                   JOIN LOTATTRIBUTE (NOLOCK) ON UCC.Lot = LOTATTRIBUTE.Lot 
                   WHERE UCC.Storerkey = LOTxLOCxID.Storerkey AND UCC.Sku = LOTxLOCxID.Sku AND LOTATTRIBUTE.Lottable02 = LA.Lottable02 AND LOTATTRIBUTE.Lottable02 <> '''') AS UCC
      WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU 
      AND SL.LocationType NOT IN (''PICK'',''CASE'')
      AND LOC.LocationType = ''OTHER'' ' +
      CASE WHEN @c_UOM = '1' THEN ' AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QtyReplen) = 0 ' ELSE ' ' END + --the pallet must be none allocated and none replen
      CASE WHEN @c_UOM = '2' THEN ' AND ISNULL(UCC.Qty,0) > 0 ' ELSE ' ' END +  --full case allocation must have valid ucc info
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
      CASE WHEN @c_UOM = '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) <= @n_QtyLeftToFulfill ' ELSE ' ' END + 
      CASE WHEN @c_UOM <> '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 ' ELSE ' ' END  +
      CASE WHEN @c_UOM = '1' THEN ' ORDER BY LA.Lottable02, LA.Lottable05, CASE WHEN ((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % @n_QtyLeftToFulfill) = 0 THEN 1 ELSE 2 END, QTYAVAILABLE DESC, LA.Lot, LOC.LogicalLocation, LOC.LOC ' ELSE ' ' END +
      CASE WHEN @c_UOM = '2' THEN ' ORDER BY LA.Lottable02, CASE WHEN ISNULL(UCC.Qty,0) > 0 THEN 
                                         CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % UCC.qty = 0 THEN 1 ELSE 2 END ELSE 2 END, 
                                         LA.Lottable05, LA.Lot, LOC.LogicalLocation, LOC.LOC ' ELSE ' ' END +
      CASE WHEN @c_UOM NOT IN('1','2') THEN ' ORDER BY LA.Lottable02, LA.Lottable05, LA.Lot, LOC.LogicalLocation, LOC.LOC ' ELSE ' ' END 

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15

   SET @c_SQL = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UCCQty   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
   	  SET @n_QtyToTake = 0
   	  SET @n_QtyToTake_LastCtn = 0
   	  
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
               	                  
      IF @c_UOM = '1' --Pallet
      BEGIN     	   
     	   SELECT @n_LocQty = 0, @n_NoOfLot = 0
          	  
         SELECT @n_LocQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen),
                @n_NoOfLot = COUNT(DISTINCT LLI.Lot)
         FROM LOTXLOCXID LLI (NOLOCK)
         WHERE LLI.Loc = @c_LOC
         AND LLI.ID = @c_ID
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku 
                	        	
         IF @n_QtyLeftToFulfill >= @n_QtyAvailable 
            AND (@n_NoOfLot = 1 OR @c_modulized = 'Y') -- if multi lot per sku/loc/id of non-modulized sku then proceed to next strategy allocation by carton
            AND @n_LocQty <= @n_RequireQty
         BEGIN                	    
            SET @n_QtyToTake = @n_QtyAvailable  
         END
         ELSE
         BEGIN
         	  SET @n_QtyToTake = 0
         END
      END
      
      IF @c_UOM = '2'
      BEGIN
      	 IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      	 BEGIN
      	 		 SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UCCQty) * @n_UCCQty
      	 END
      	 ELSE
      	 BEGIN
      	 	  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UCCQty) * @n_UCCQty
      	 END      	 
      	 
      	 IF (@n_QtyLeftToFulfill - @n_QtyToTake) >= (@n_QtyAvailable - @n_QtyToTake)  --Last carton is partial but consider as full cartion to pick  
      	 BEGIN
      	 	  SET @n_QtyToTake_LastCtn = @n_QtyAvailable - @n_QtyToTake
      	 END
      END

      IF @c_UOM NOT IN('1','2') 
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
      
      IF @n_QtyToTake > 0 OR @n_QtyToTake_lastctn > 0
      BEGIN
   	  	  UPDATE #TMP_LOT
   	  	  SET QtyAvailable = QtyAvailable - @n_QtyToTake - @n_QtyToTake_lastctn
   	  	  WHERE Lot = @c_Lot
   	  	  
      	 IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1'
          	 SET @c_OtherValue = 'FULLPALLET'
         ELSE IF @c_UOM = '2'
             SET @c_OtherValue = 'UOM=' + LTRIM(CAST(@n_UCCQty AS NVARCHAR(10)))          
         ELSE         
           	 SET @c_OtherValue = '1'       	 
      	
      	 IF @n_QtyToTake > 0
      	 BEGIN 
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
         END

      	 IF @n_QtyToTake_LastCtn > 0
      	 BEGIN 
      	 	  SET @c_OtherValue = 'UOM=' + LTRIM(CAST(@n_QtyToTake_LastCtn AS NVARCHAR(10)))
      	 	      	 	  
            IF ISNULL(@c_SQL,'') = ''
            BEGIN
               SET @c_SQL = N'   
                     DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                     SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake_LastCtn AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                     '
            END
            ELSE
            BEGIN
               SET @c_SQL = @c_SQL + N'  
                     UNION ALL
                     SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake_LastCtn AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                     '
            END
         END
                  
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake - @n_QtyToTake_lastctn      
         SET @n_LotQtyAvailable = @n_LotQtyAvailable - @n_QtyToTake - @n_QtyToTake_lastctn
      END
            
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UCCQty  
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
END -- Procedure

GO