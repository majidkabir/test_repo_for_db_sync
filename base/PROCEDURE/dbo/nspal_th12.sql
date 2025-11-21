SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAL_TH12                                         */
/* Creation Date: 17-APR-2023                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22269 - TH Allocation strategy of new DC for PUMA,UA,   */
/*          SKE AND JDSPORTS (modified from nspAL_TH09)                 */
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
/* Date         Author   Ver. Purposes                                  */
/* 17-APR-2023  NJOW     1.0  DEVOPS combine script                     */
/************************************************************************/
CREATE   PROC [dbo].[nspAL_TH12]
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

   DECLARE @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX),
           @c_SortBy      NVARCHAR(2000)
          
   DECLARE @c_LocationType     NVARCHAR(100),    
           @c_LocationCategory NVARCHAR(100),
           @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT,
           @n_LotQtyAvailable  INT,
           @n_RequestQty       INT = 0,
           @c_FilterHostWHCode NVARCHAR(1) = 'N',
           @c_FindSOHMaxLoc    NVARCHAR(1) = 'N',
           @c_B2C              NCHAR(1) = 'N',
           @c_DocType          NCHAR(1) = 'N',
           @c_OrderGroup       NVARCHAR(20) = '',
           @c_LocCategory      NVARCHAR(10) = ''
  
   DECLARE @c_key1        NVARCHAR(10),    
           @c_key2        NVARCHAR(5),    
           @c_key3        NCHAR(1)    
           
   IF @n_UOMBase = 0
      SET @n_UOMBase = 1
                           
   IF LEN(@c_OtherParms) > 0  
   BEGIN   	    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	          	    
   END
   
   IF EXISTS(SELECT 1
             FROM CODELKUP (NOLOCK)
             WHERE ListName  = 'PKCODECFG'
             AND Storerkey = @c_Storerkey
             AND Long = 'nspAL_TH12'
             AND ISNULL(Short,'') <> 'N'
             AND Code = 'FindSOHMaxLoc')                    
   BEGIN
   	 SET @c_FindSOHMaxLoc = 'Y'
   END
   ELSE
   BEGIN
   	 SET @c_FindSOHMaxLoc = 'N'
   END
   
   IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>'' 
   BEGIN
   	  SELECT TOP 1 @c_DocType = DocType,
   	               @c_OrderGroup = OrderGroup
   	  FROM ORDERS (NOLOCK)
   	  WHERE Orderkey = @c_Key1
   END     
   ELSE IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')='' AND ISNULL(@c_Key3,'') = ''
   BEGIN
   	  SELECT TOP 1 @c_DocType = O.DocType,
   	               @c_OrderGroup = O.OrderGroup 
   	  FROM ORDERS O(NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      WHERE LPD.Loadkey = @c_Key1    	  
   END   
   ELSE IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')='' AND ISNULL(@c_Key3,'') = 'W'
   BEGIN
   	  SELECT TOP 1 @c_DocType = O.DocType,
   	               @c_OrderGroup = O.OrderGroup 
   	  FROM ORDERS O(NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
      WHERE WD.Wavekey = @c_Key1    	  
   END
   
   IF (@c_DocType = 'E' OR @c_OrderGroup='ECOM')
      SET @c_B2C = 'Y'
   ELSE
      SET @c_B2C = 'N'	          
               	                
   IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>'' AND @c_FindSOHMaxLoc = 'Y' AND @c_B2C = 'Y' --skip Discrete allocation for B2C
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END

   IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')='' AND @c_FindSOHMaxLoc = 'Y' AND @c_B2C = 'N' --skip conso allocation for B2B
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END
      
   IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE ListName = 'HOSTCODE' AND Storerkey = @c_Storerkey AND ISNULL(Short,'') <> '')
      SET @c_FilterHostWHCode = 'Y'
   ELSE
      SET @c_FilterHostWHCode = 'N'         
         
   EXEC isp_Init_Allocate_Candidates
         
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL, QtyAvailable INT NULL DEFAULT(0))                             
	 CREATE TABLE #TMP_INV (ROWID INT IDENTITY(1,1), Lot NVARCHAR(10), Loc NVARCHAR(10), ID NVARCHAR(18), Qty INT)
            
   SET @c_LocationType = ''
   SET @c_LocationCategory = ''        
      
   IF @c_FindSOHMaxLoc = 'Y'     
      SET @c_SortBy = 'ORDER BY QTYAVAILABLE DESC, LOC.LogicalLocation, LOC.Loc'
   ELSE
      SET @c_SortBy = 'ORDER BY LOC.LogicalLocation, LOC.Loc'
   
   SET @c_SQL = N'      
      INSERT INTO #TMP_INV (Lot, Loc, ID, Qty)
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,    
             QTYAVAILABLE = LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN ID (NOLOCK) ON LOTxLOCxID.Id = ID.ID
      JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
      WHERE LOC.LocationFlag = ''NONE''  
      AND LOC.Status = ''OK''
      AND ID.STATUS = ''OK''
      AND LOT.STATUS = ''OK''
      AND LOC.Facility = @c_Facility  
      AND LOTxLOCxID.STORERKEY = @c_StorerKey  
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +              
      CASE WHEN  @c_FilterHostWHCode = 'Y' THEN
        ' AND LOC.HostWHCode IN (SELECT Short FROM CODELKUP (NOLOCK) WHERE ListName = ''HOSTCODE'' AND Storerkey = @c_Storerkey) '   
      ELSE ' ' END +
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
      + @c_SortBy
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                      '@c_Lottable12 NVARCHAR(30), @n_UOMBase INT '  

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_UOMBase          
                         
   IF @c_FindSOHMaxLoc = 'Y'    
   BEGIN
      /*
      CREATE TABLE #LOCSORT (RowID INT IDENTITY(1,1), Loc NVARCHAR(10))
      CREATE TABLE #NUM_OPTIMIZATION_INPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)
	    CREATE TABLE #NUM_OPTIMIZATION_OUTPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)        
	    */
	    CREATE TABLE #TMP_LOCCAT (RowID INT IDENTITY(1,1), FieldName NVARCHAR(20), Value NVARCHAR(60))
	    
	    
      --SELECT @n_RequestQty = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
	    
	    INSERT INTO #TMP_LOCCAT(FieldName, Value)
	    SELECT FieldName, Value
      FROM   
         (SELECT TOP 1 UDF01, UDF02, UDF03, UDF04, UDF05
          FROM CODELKUP (NOLOCK)
          WHERE Listname = CASE WHEN @c_B2C = 'Y' THEN 'SORTSEQB2C' ELSE 'SORTSEQB2B' END
          AND Storerkey = @c_Storerkey
          --AND Code = @c_DocType
          --AND Short = @c_OrderGroup
         ) p  
      UNPIVOT  
         (Value FOR FieldName IN   
            (UDF01, UDF02, UDF03, UDF04, UDF05)  
      )AS UNPVT
      ORDER BY FieldName 	 

      --INSERT INTO #TMP_LOCCAT (FieldName, Value)
      --VALUES ('OTHER','OTHERCAT')
             	    
	    DECLARE CUR_LOCCAT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	       SELECT Value 
	       FROM #TMP_LOCCAT
	       WHERE Value <> '' 
	       AND Value IS NOT NULL
	       ORDER BY RowID
	       
      OPEN CUR_LOCCAT         
                 
      FETCH NEXT FROM CUR_LOCCAT INTO @c_LocCategory
             
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
      BEGIN    	       
      	 /*
      	 TRUNCATE TABLE #NUM_OPTIMIZATION_INPUT
         INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount)     
         SELECT I.Loc, FLOOR(SUM(I.Qty) / @n_UOMBase) * @n_UOMBase, 1
         FROM #TMP_INV I
         JOIN LOC (NOLOCK) ON I.Loc = LOC.Loc  
         WHERE (LOC.LocationCategory = @c_LocCategory
                --OR (@c_LocCategory='OTHERCAT' AND LOC.LocationCategory NOT IN (SELECT Value FROM #TMP_LOCCAT))
                )
         GROUP BY I.Loc 
         ORDER BY MIN(I.ROWID)
                                             
      	 TRUNCATE TABLE #NUM_OPTIMIZATION_OUTPUT
         INSERT INTO #NUM_OPTIMIZATION_OUTPUT
	       EXEC isp_Num_Optimization 
	            @n_NumRequest = @n_RequestQty
             ,@c_OptimizeMode = '2'	          
         
         TRUNCATE TABLE #LOCSORT    
         INSERT INTO #LOCSORT (Loc)
         SELECT OP.KeyField 
         FROM #NUM_OPTIMIZATION_OUTPUT OP
         ORDER BY OP.RowId
         */

         DECLARE CURSOR_AVAILABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT INV.LOT,    
                   INV.LOC,     
                   INV.ID,    
                   INV.Qty
            FROM #TMP_INV INV
            JOIN LOC (NOLOCK) ON INV.Loc = LOC.Loc              
            --LEFT JOIN #LOCSORT LS ON INV.Loc = LS.Loc
            WHERE (LOC.LocationCategory = @c_LocCategory
                   --OR (@c_LocCategory='OTHERCAT' AND LOC.LocationCategory NOT IN (SELECT Value FROM #TMP_LOCCAT))
                  )            
            ORDER BY INV.RowID                  
            --ORDER BY CASE WHEN LS.RowID IS NOT NULL THEN LS.RowID ELSE 99999 END, INV.RowID
                     
         SET @n_LotQtyAvailable = 0
         SET @c_OtherValue = ''
         
         OPEN CURSOR_AVAILABLE         
                    
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
                
         WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
         BEGIN    
         	  IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
         	  BEGIN
         	  	 INSERT INTO #TMP_LOT (Lot, QtyAvailable)
         	  	 SELECT Lot, (Qty - QtyAllocated - QtyPicked)  
            	 FROM LOT (NOLOCK)      	 
            	 WHERE LOT = @c_LOT       	 
         	  END
            SET @n_LotQtyAvailable = 0
         
            SELECT @n_LotQtyAvailable = QtyAvailable
            FROM #TMP_LOT 
            WHERE Lot = @c_Lot   	  
            
            IF @n_LotQtyAvailable < @n_QtyAvailable 
            BEGIN
            	 --IF @c_UOM = '1' 
            	 --   SET @n_QtyAvailable = 0
            	 --ELSE
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
         
               EXEC isp_Insert_Allocate_Candidates
                    @c_Lot = @c_Lot
                 ,  @c_Loc = @c_Loc
                 ,  @c_ID  = @c_ID
                 ,  @n_QtyAvailable = @n_QtyToTake
                 ,  @c_OtherValue = @c_OtherValue
                     	
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake      
               --SET @n_RequestQty = @n_RequestQty - @n_QtyToTake     
            END
                  
            FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
         END -- END WHILE FOR CURSOR_AVAILABLE                
         CLOSE CURSOR_AVAILABLE          
         DEALLOCATE CURSOR_AVAILABLE           	
      	 
         FETCH NEXT FROM CUR_LOCCAT INTO @c_LocCategory
      END
      CLOSE CUR_LOCCAT
      DEALLOCATE CUR_LOCCAT   	  
   END
   ELSE 
   BEGIN 
      DECLARE CURSOR_AVAILABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT INV.LOT,    
                INV.LOC,     
                INV.ID,    
                INV.Qty
         FROM #TMP_INV INV
         ORDER BY INV.RowID
         --LEFT JOIN #LOCSORT LS ON INV.Loc = LS.Loc
         --ORDER BY CASE WHEN LS.RowID IS NOT NULL THEN LS.RowID ELSE 99999 END, INV.RowID
      
      SET @n_LotQtyAvailable = 0
      SET @c_OtherValue = ''
      
      OPEN CURSOR_AVAILABLE         
                 
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
             
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
      BEGIN    
      	  IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
      	  BEGIN
      	  	 INSERT INTO #TMP_LOT (Lot, QtyAvailable)
      	  	 SELECT Lot, (Qty - QtyAllocated - QtyPicked)  
         	 FROM LOT (NOLOCK)      	 
         	 WHERE LOT = @c_LOT       	 
      	  END
         SET @n_LotQtyAvailable = 0
      
         SELECT @n_LotQtyAvailable = QtyAvailable
         FROM #TMP_LOT 
         WHERE Lot = @c_Lot   	  
         
         IF @n_LotQtyAvailable < @n_QtyAvailable 
         BEGIN
         	 --IF @c_UOM = '1' 
         	 --   SET @n_QtyAvailable = 0
         	 --ELSE
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
      
            EXEC isp_Insert_Allocate_Candidates
                 @c_Lot = @c_Lot
              ,  @c_Loc = @c_Loc
              ,  @c_ID  = @c_ID
              ,  @n_QtyAvailable = @n_QtyToTake
              ,  @c_OtherValue = @c_OtherValue
                  	
            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
         END
               
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
      END -- END WHILE FOR CURSOR_AVAILABLE                
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE        	
   END
                         
   /*                   
   SELECT @n_RequestQty = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase

   IF @c_FindSOHMaxLoc = 'Y'                                                     
   BEGIN   
      INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount)     
      SELECT Loc, FLOOR(SUM(Qty) / @n_UOMBase) * @n_UOMBase, 1
      FROM #TMP_INV  
      GROUP BY Loc 
      ORDER BY MIN(ROWID)
                                          
      INSERT INTO #NUM_OPTIMIZATION_OUTPUT
	    EXEC isp_Num_Optimization 
	         @n_NumRequest = @n_RequestQty
          ,@c_OptimizeMode = '2'	          
          
      INSERT INTO #LOCSORT (Loc)
      SELECT OP.KeyField 
      FROM #NUM_OPTIMIZATION_OUTPUT OP
      ORDER BY OP.RowId
   END
                            
   DECLARE CURSOR_AVAILABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT INV.LOT,    
             INV.LOC,     
             INV.ID,    
             INV.Qty
      FROM #TMP_INV INV
      LEFT JOIN #LOCSORT LS ON INV.Loc = LS.Loc
      ORDER BY CASE WHEN LS.RowID IS NOT NULL THEN LS.RowID ELSE 99999 END, INV.RowID

   SET @n_LotQtyAvailable = 0
   SET @c_OtherValue = ''
   
   OPEN CURSOR_AVAILABLE         
              
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
   	  IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
   	  BEGIN
   	  	 INSERT INTO #TMP_LOT (Lot, QtyAvailable)
   	  	 SELECT Lot, (Qty - QtyAllocated - QtyPicked)  
      	 FROM LOT (NOLOCK)      	 
      	 WHERE LOT = @c_LOT       	 
   	  END
      SET @n_LotQtyAvailable = 0

      SELECT @n_LotQtyAvailable = QtyAvailable
      FROM #TMP_LOT 
      WHERE Lot = @c_Lot   	  
      
      IF @n_LotQtyAvailable < @n_QtyAvailable 
      BEGIN
      	 --IF @c_UOM = '1' 
      	 --   SET @n_QtyAvailable = 0
      	 --ELSE
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

         EXEC isp_Insert_Allocate_Candidates
              @c_Lot = @c_Lot
           ,  @c_Loc = @c_Loc
           ,  @c_ID  = @c_ID
           ,  @n_QtyAvailable = @n_QtyToTake
           ,  @c_OtherValue = @c_OtherValue
               	
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
      END
            
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE                
   CLOSE CURSOR_AVAILABLE          
   DEALLOCATE CURSOR_AVAILABLE     
   */ 
      
 EXIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
END -- Procedure

GO