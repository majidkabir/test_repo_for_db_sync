SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/            
/* Stored Procedure: nspAL_LEV1                                          */            
/* Creation Date: 15/08/2018                                             */            
/* Copyright: LFL                                                        */            
/* Written by:                                                           */            
/*                                                                       */            
/* Purpose: WMS-5650 CN Livi's B2B allocation                            */            
/*                                                                       */            
/* Called By:                                                            */            
/*                                                                       */            
/* PVCS Version: 1.3                                                     */            
/*                                                                       */            
/* Version: 7.0                                                          */            
/*                                                                       */            
/* Data Modifications:                                                   */            
/*                                                                       */            
/* Updates:                                                              */            
/* Date         Author  Ver.  Purposes                                   */    
/* 05-Dec-2018  NJOW01  1.0   Fix - short allocation                     */
/* 27-DEC-2018  Grick01 1.1   INC0513699 - Check for PendingMoveIn(G01)  */
/* 27-Feb-2020  Wan01   1.2   Dynamic SQL review, impact SQL cache log   */ 
/* 17-Jan-2022  KY01    1.3   JSM-46456-Extend @c_SKU NVARCHAR(20) (KY01)*/ 
/*************************************************************************/            

CREATE PROC [dbo].[nspAL_LEV1]
   @c_DocNo      NVARCHAR(10),  
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
   DECLARE @c_Condition          NVARCHAR(MAX),
            @c_SQL                NVARCHAR(MAX),
            @c_OrderBy            NVARCHAR(1000), 
            @n_QtyToTake          INT,
            @n_QtyAvailable       INT,
            @c_Lot                NVARCHAR(10),
            @c_Loc                NVARCHAR(10), 
            @c_ID                 NVARCHAR(18),
            @c_UCCQty             INT,
            @n_PackQty            INT,
            @c_OtherValue         NVARCHAR(20),
            @n_UCCQty             INT,
            @c_Wavekey            NVARCHAR(10),
    	      @c_key1               NVARCHAR(10),    
            @c_key2               NVARCHAR(5),  
            @c_key3               NCHAR(1),
            @c_WaveType           NVARCHAR(18),
            @n_LotQty             INT --NJOW01  
                        
   EXEC isp_Init_Allocate_Candidates         --(Wan01)                
   --NJOW01        
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                           QtyAvailable INT NULL DEFAULT(0)
                           )       
                               
   IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
   BEGIN        
      SET @c_WaveKey = LEFT(@c_OtherParms,10) 
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	    
      
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' 
      BEGIN
          SET @c_Wavekey = ''
          SELECT TOP 1 @c_Wavekey = O.Userdefine09
          FROM ORDERS O (NOLOCK) 
          JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
          WHERE O.Loadkey = @c_key1
          AND OD.Sku = @c_SKU
          ORDER BY O.Userdefine09
      END 
       
      IF ISNULL(@c_key2,'')<>''
      BEGIN
         SELECT TOP 1 @c_Wavekey = O.Userdefine09
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_Key1
      END       	    
      
      SELECT @c_WaveType = WaveType
      FROM WAVE (NOLOCK)
      WHERE Wavekey = @c_Wavekey                    
   END        
   
   IF @c_WaveType = 'B2C-M' AND @c_UOM = '2'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END
             
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL 
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = CONVERT( NVARCHAR(20), @d_Lottable04, 106) "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = CONVERT( NVARCHAR(20), @d_Lottable05, 106) "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) <> '' AND @c_Lottable06 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE06 = @c_Lottable06 "
   END   	     	  
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) <> '' AND @c_Lottable07 IS NOT NULL
   BEGIN      
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE07 = @c_Lottable07 "
   END   	  
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) <> '' AND @c_Lottable08 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE08 = @c_Lottable08 "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) <> '' AND @c_Lottable09 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE09 = @c_Lottable09 "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) <> '' AND @c_Lottable10 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE10 = @c_Lottable10 "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) <> '' AND @c_Lottable11 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE11 = @c_Lottable11 "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) <> '' AND @c_Lottable12 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE12 = @c_Lottable12 "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> "01/01/1900" AND @d_Lottable13 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE13 = CONVERT( NVARCHAR(20), @d_Lottable13, 106) "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> "01/01/1900" AND @d_Lottable14 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE14 = CONVERT( NVARCHAR(20), @d_Lottable14, 106) "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> "01/01/1900" AND @d_Lottable15 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE15 = CONVERT( NVARCHAR(20), @d_Lottable15, 106) "
   END

   IF @c_UOM IN ('1','2')  
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.LocationType NOT IN ('PICK','DYNPPICK') "
      SELECT @c_OrderBy = " ORDER BY LOTATTRIBUTE.Lottable05, QtyAvailable, LOC.LogicalLocation, LOC.Loc "
   END    
   ELSE
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.LocationType NOT IN ('DYNPPICK') "
      SELECT @c_OrderBy = " ORDER BY CASE WHEN LOC.LocationType = 'PICK' THEN 1 ELSE 2 END, LOTATTRIBUTE.Lottable05, 
                            CASE WHEN LOC.LocationType = 'PICK' THEN LOC.LogicalLocation ELSE '' END, QtyAvailable, LOC.LogicalLocation, LOC.Loc "
   END
   
   SELECT @c_SQL = "DECLARE CURSOR_LEV_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +
          " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
          " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) " +  --G01
          " FROM LOTATTRIBUTE (NOLOCK) " +
          " JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
          " JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " + 
          " JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc " +
          " JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
          " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
          " WHERE LOT.STORERKEY = @c_storerkey " +
          " AND LOT.SKU = @c_SKU " +
          " AND LOT.STATUS = 'OK' " +
          " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
          " AND LOC.LocationFlag = 'NONE' " + 
    	    " AND LOC.Facility = @c_facility " + 
          " AND LOTATTRIBUTE.STORERKEY = @c_storerkey " +
          " AND LOTATTRIBUTE.SKU = @c_SKU " +
          RTRIM(ISNULL(@c_Condition,''))  + 
          " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, LOC.LocationType " +
          " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 " + 
          RTRIM(ISNULL(@c_OrderBy,''))

   EXEC sp_executesql @c_SQL 
      , N'@c_Storerkey  NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5),             --(KY01)
          @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
          @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
          @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
          @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
          @d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME'
             
      , @c_StorerKey
      , @c_Sku
      , @c_Facility
      , @c_Lottable01
      , @c_Lottable02
      , @c_Lottable03
      , @d_Lottable04
      , @d_Lottable05
      , @c_Lottable06
      , @c_Lottable07
      , @c_Lottable08
      , @c_Lottable09
      , @c_Lottable10
      , @c_Lottable11
      , @c_Lottable12
      , @d_Lottable13
      , @d_Lottable14
      , @d_Lottable15
   
   SET @c_SQL = ''
   
   OPEN CURSOR_LEV_AVAILABLE                    
   FETCH NEXT FROM CURSOR_LEV_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable
      
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN           	
      --NJOW01 S
      IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
      BEGIN
         INSERT INTO #TMP_LOT (Lot, QtyAvailable)
         SELECT Lot, Qty - QtyAllocated - QtyPicked
         FROM LOT (NOLOCK)
         WHERE LOT = @c_LOT       	 
      END
      SET @n_LotQty = 0
      
      SELECT @n_LotQty = QtyAvailable
      FROM #TMP_LOT 
      WHERE Lot = @c_Lot   	  
      
      IF @n_LotQty < @n_QtyAvailable
         SET @n_QtyAvailable = @n_LotQty   	  
      --NJOW01 E   
   	  
      SET @n_QtyToTake = 0
            
      SET @n_PackQty = @n_UOMBase
      SET @n_UCCQty = 0
      SET @c_OtherValue = '1'
      
      IF @c_UOM = '2'
      BEGIN
         SELECT TOP 1 @n_UCCQty = Qty  --Expect the location have same UCC qty
         FROM UCC (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku
         AND Lot = @c_Lot
         AND Loc = @c_Loc
         AND Id = @c_Id
         AND Status < '3'     
         ORDER BY Qty DESC
         
         IF @n_UCCQty > 0
         BEGIN
            SET @n_PackQty = @n_UCCQty
            SET @c_OtherValue = 'UOM=' + LTRIM(CAST(@n_UCCQty AS NVARCHAR)) --instruct the allocation to take this as casecnt
         END
      END
                              	     	     
   	IF @n_QtyAvailable > @n_QtyLeftToFulfill
   	   SET @n_QtyToTake = FLOOR(@n_QtyLeftToFulfill / @n_PackQty) * @n_PackQty
   	ELSE
   	   SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_PackQty) * @n_PackQty      	           	  
   	        	 
   	IF @n_QtyToTake > 0       	        	  
   	BEGIN
         --NJOW01
         UPDATE #TMP_LOT
         SET QtyAvailable = QtyAvailable - @n_QtyToTake
         WHERE Lot = @c_Lot

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
         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue
         --(Wan01) - END
      END
   	SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake                	 
             
      FETCH NEXT FROM CURSOR_LEV_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable 
   END -- END WHILE FOR CURSOR_LEV_AVAILABLE                
         
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_LEV_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_LEV_AVAILABLE          
      DEALLOCATE CURSOR_LEV_AVAILABLE          
   END    

   --(Wan01) - START
   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column

   --IF ISNULL(@c_SQL,'') <> ''
   --BEGIN
   --   EXEC sp_ExecuteSQL @c_SQL
   --END
   --ELSE
   --BEGIN
   --   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   --   SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   --END  
   --(Wan01) - END     
   
   EXIT_SP:
END

GO