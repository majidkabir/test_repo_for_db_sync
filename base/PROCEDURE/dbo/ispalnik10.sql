SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispALNIK10                                         */
/* Creation Date: 14-APR-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19078 - CN NIKE PHC Allocation from safetystock         */
/*          Full case by load (UOM2), Piece by Wave (UOM6)              */
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
/* 14-APR-2022  NJOW     1.0  DEVOPS combine script                     */
/* 03-JUL-2023  NJOW01   1.1  WMS-22522 Change loc search logic         */
/************************************************************************/
CREATE   PROC [dbo].[ispALNIK10]
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
   @c_OtherParms NVARCHAR(200)='',
   @c_AllocateStrategyKey NVARCHAR(10)='',
   @c_AllocateStrategyLineNumber NVARCHAR(5) = ''   
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
           @n_RowID            INT,
           --@n_RequestQty       INT = 0,
           @n_AllocatedQty     INT = 0,
           @c_ZoneGroup        NVARCHAR(20) = '',
           @c_LocationTypeOverRideStripe NVARCHAR(10) = '',
           @c_UOMByLoad        NVARCHAR(20) = '',                                                                                                                                   
           @c_FistFindLoc      NVARCHAR(10)  --NJOW01
  
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
   
   IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''  --skip Discrete allocation
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END

   IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')=''   --skip load conso allocation
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END
   
   IF ISNULL(@c_AllocateStrategyKey,'') <> ''
   BEGIN
      SELECT @c_LocationTypeOverRideStripe = LocationTypeOverRideStripe
      FROM ALLOCATESTRATEGYDETAIL (NOLOCK)
      WHERE AllocateStrategyKey = @c_AllocateStrategyKey
      AND AllocateStrategyLineNumber = @c_AllocateStrategyLineNumber

      SELECT @c_ZoneGroup = dbo.fnc_GetParamValueFromString('@L', @c_LocationTypeOverRideStripe, @c_ZoneGroup)
      SELECT @c_UOMByLoad = dbo.fnc_GetParamValueFromString('@G', @c_LocationTypeOverRideStripe, @c_UOMByLoad)
   END   
   
   EXEC isp_Init_Allocate_Candidates
         
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL, QtyAvailable INT NULL DEFAULT(0))                             
   --CREATE TABLE #LOCSORT (RowID INT IDENTITY(1,1), Loc NVARCHAR(10))
   --CREATE TABLE #NUM_OPTIMIZATION_INPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)
	 --CREATE TABLE #NUM_OPTIMIZATION_OUTPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)         	 
	 CREATE TABLE #TMP_INV (ROWID INT IDENTITY(1,1), Lot NVARCHAR(10), Loc NVARCHAR(10), ID NVARCHAR(18), Qty INT)
            
   SET @c_LocationType = ''
   SET @c_LocationCategory = ''
   SET @c_SortBy = 'ORDER BY PZ.Long, LOC.LogicalLocation, LOC.Loc'

   SET @c_SQL = N'      
      INSERT INTO #TMP_INV (Lot, Loc, ID, Qty)
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,    
             LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN ID (NOLOCK) ON LOTxLOCxID.Id = ID.ID
      JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
      CROSS APPLY (SELECT TOP 1 CL.Long FROM CODELKUP CL (NOLOCK) 
                   WHERE CL.Code2 = LOC.PickZone 
                   AND (CL.Long = @c_ZoneGroup OR ISNULL(@c_ZoneGroup,'''')='''')
                   AND CL.Listname = ''NIKEPAPICK'' AND CL.UDF05 = ''Y'') AS PZ
      WHERE LOC.LocationFlag = ''NONE''  
      AND LOC.Status = ''OK''
      AND ID.STATUS = ''OK''
      AND LOT.STATUS = ''OK''
      AND LOC.Facility = @c_Facility  
      AND LOTxLOCxID.STORERKEY = @c_StorerKey  
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LA.Lottable11 <> ''H''
      AND LA.Lottable12 <> ''INACCESSIBLE''      
      AND LOC.LocationRoom = ''SAFETYSTOCK''
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
      + @c_SortBy
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                      '@c_Lottable12 NVARCHAR(30), @n_UOMBase INT, @c_ZoneGroup NVARCHAR(20) '  

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_UOMBase, @c_ZoneGroup                  

/*
   IF ISNULL(@c_key2,'') = '' AND ISNULL(@c_Key3,'') = 'W' AND @c_UOM =' 2'
   BEGIN
   	  --find full case qty of all load plan
   	  SELECT @n_RequestQty = SUM(R.FCQty)
   	  FROM (
            SELECT FLOOR(SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)) / @n_UOMBase) * @n_UOMBase AS FCQty
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
            WHERE WD.Wavekey = @c_Key1
            AND O.Type NOT IN ( 'M', 'I' )         
            AND O.SOStatus <> 'CANC'         
            AND O.Status < '9'         
            AND O.Facility = @c_Facility
            AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)) > 0        
            AND OD.Storerkey  = @c_Storerkey
            AND OD.Sku        = @c_Sku
            AND OD.Lottable01 = @c_Lottable01     
            AND OD.Lottable02 = @c_Lottable02     
            AND OD.Lottable03 = @c_Lottable03     
            --AND OD.Lottable04 = @d_Lottable04     
            --AND OD.Lottable05 = @d_Lottable05     
            AND OD.Lottable06 = @c_Lottable06     
            AND OD.Lottable07 = @c_Lottable07     
            AND OD.Lottable08 = @c_Lottable08     
            AND OD.Lottable09 = @c_Lottable09     
            AND OD.Lottable10 = @c_Lottable10     
            AND OD.Lottable11 = @c_Lottable11     
            AND OD.Lottable12 = @c_Lottable12     
            --AND OD.Lottable13 = @d_Lottable13     
            --AND OD.Lottable14 = @d_Lottable14     
            --AND OD.Lottable15 = @d_Lottable15          
            GROUP BY O.Loadkey                         	 
            HAVING FLOOR(SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)) / @n_UOMBase) > 0     
          ) R         
   END 
   ELSE                                              
      SELECT @n_RequestQty = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
*/
   
   /*
   DECLARE CURSOR_ZONEGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT CL.Long 
      FROM CODELKUP CL (NOLOCK) 
      WHERE CL.Listname = 'NIKEPAPICK' 
      AND CL.UDF05 = 'Y'
      AND ISNULL(CL.Long,'') <> ''
      ORDER BY CL.Long

   OPEN CURSOR_ZONEGROUP         
           
   FETCH NEXT FROM CURSOR_ZONEGROUP INTO @c_ZoneGroup
       
   WHILE (@@FETCH_STATUS <> -1) AND @n_RequestQty > 0
   BEGIN
      DELETE FROM #NUM_OPTIMIZATION_INPUT  
      
      INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount)     
      SELECT I.Loc, FLOOR(SUM(I.Qty) / @n_UOMBase) * @n_UOMBase, 1
      FROM #TMP_INV  I
      JOIN LOC (NOLOCK) ON I.Loc = LOC.Loc                  
      CROSS APPLY (SELECT TOP 1 CL.Long FROM CODELKUP CL (NOLOCK) 
                   WHERE CL.Code2 = LOC.PickZone 
                   AND CL.Listname = 'NIKEPAPICK' AND CL.UDF05 = 'Y'
                   AND CL.Long = @c_ZoneGroup) AS PZ      
      GROUP BY I.Loc 
      ORDER BY MIN(I.ROWID)      	

      INSERT INTO #NUM_OPTIMIZATION_OUTPUT
	    EXEC isp_Num_Optimization 
	         @n_NumRequest = @n_RequestQty
          ,@c_OptimizeMode = '0'	                    

      SET @n_AllocatedQty = 0
      SELECT @n_AllocatedQty = SUM(Num)
      FROM #NUM_OPTIMIZATION_OUTPUT
   
      SELECT @n_RequestQty = @n_RequestQty - @n_AllocatedQty 
   	 
      FETCH NEXT FROM CURSOR_ZONEGROUP INTO @c_ZoneGroup      	
   END
   CLOSE CURSOR_ZONEGROUP
   DEALLOCATE CURSOR_ZONEGROUP
   */
   
   /*
   INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount)     
   SELECT Loc, FLOOR(SUM(Qty) / @n_UOMBase) * @n_UOMBase, 1
   FROM #TMP_INV  
   GROUP BY Loc 
   ORDER BY MIN(ROWID)
                                       
   INSERT INTO #NUM_OPTIMIZATION_OUTPUT
	 EXEC isp_Num_Optimization 
	      @n_NumRequest = @n_RequestQty
       ,@c_OptimizeMode = '0'	                    
       
   INSERT INTO #LOCSORT (Loc)
   SELECT OP.KeyField 
   FROM #NUM_OPTIMIZATION_OUTPUT OP
   ORDER BY OP.RowId
                            
   DECLARE CURSOR_AVAILABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT I.Lot, I.Loc, I.ID, I.Qty
      FROM (SELECT INV.RowID,
                   INV.LOT,    
                   INV.LOC,     
                   INV.ID,    
                   INV.Qty,
                   CASE WHEN LS.RowID IS NOT NULL THEN 0 ELSE 1 END AS OptSort,
                   CASE WHEN LS.RowID IS NOT NULL THEN INV.Qty ELSE 0 END AS OptQty
             FROM #TMP_INV INV
             LEFT JOIN #LOCSORT LS ON INV.Loc = LS.Loc) I
      ORDER BY I.Optsort, I.OptQty DESC, I.RowID*/
                                                     
   SET @n_LotQtyAvailable = 0
   IF @c_UOM = '2' AND @c_UOMByLoad = 'Y'
      SET @c_OtherValue = '@c_UOMBYLOAD=Y'
   ELSE   
      SET @c_OtherValue = ''
         
   /*OPEN CURSOR_AVAILABLE         
              
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN */

      SET @n_QtyLeftToFulfill = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase

      SET @c_FistFindLoc = 'Y' --NJOW01

      WHILE @n_QtyLeftToFulfill > 0  
      BEGIN
      	 SELECT @c_Loc = ''
      	 
      	 /* 
      	 SELECT TOP 1 @c_Loc = INV.Loc 
         FROM #TMP_INV INV
         GROUP BY INV.Loc
         HAVING SUM(INV.Qty) >= @n_QtyLeftToFulfill
         ORDER BY SUM(INV.Qty), MIN(INV.RowID)
         
         IF ISNULL(@c_Loc,'') = ''
         BEGIN
      	    SELECT TOP 1 @c_Loc = INV.Loc 
            FROM #TMP_INV INV
            GROUP BY INV.Loc
            HAVING SUM(INV.Qty) < @n_QtyLeftToFulfill
            ORDER BY SUM(INV.Qty) DESC, MIN(INV.RowID)
         END
         */

         --NJOW01 S
         IF @c_FistFindLoc = 'Y'  --Only first time need to check loc qty = qtylefttofulfill
         BEGIN         
      	    SELECT TOP 1 @c_Loc = INV.Loc 
            FROM #TMP_INV INV
            GROUP BY INV.Loc
            HAVING SUM(INV.Qty) = @n_QtyLeftToFulfill
            ORDER BY MIN(INV.RowID)

            SET @c_FistFindLoc = 'N'            
         END
         
         IF ISNULL(@c_Loc,'') = ''
         BEGIN
      	    SELECT TOP 1 @c_Loc = INV.Loc 
            FROM #TMP_INV INV
            GROUP BY INV.Loc
            ORDER BY SUM(INV.Qty), MIN(INV.RowID)
         END
         --NJOW01 E
                          
         IF ISNULL(@c_Loc,'') = ''
            BREAK   
                   
         WHILE @n_QtyLeftToFulfill > 0         
         BEGIN   
            SELECT @c_Lot = '', @c_ID = '', @n_QtyAvailable = 0, @n_RowID = 0
            
            SELECT TOP 1 @c_LOT = INV.Lot, 
                   --@c_LOC = INV.Loc, 
                   @c_ID = INV.ID, 
                   @n_QtyAvailable = INV.Qty,
                   @n_RowID = INV.RowID
            FROM #TMP_INV INV
            WHERE INV.Qty >= @n_QtyLeftToFulfill
            AND INV.Loc = @c_Loc
            ORDER BY INV.Qty, INV.RowID
            
            IF @n_RowID = 0 
            BEGIN
               SELECT TOP 1 @c_LOT = INV.Lot, 
                      --@c_LOC = INV.Loc, 
                      @c_ID = INV.ID, 
                      @n_QtyAvailable = INV.Qty,
                      @n_RowID = INV.RowID                
               FROM #TMP_INV INV
               WHERE INV.Qty < @n_QtyLeftToFulfill      
               AND INV.Loc = @c_Loc
               ORDER BY INV.Qty DESC, INV.RowID
            END
            
            IF @n_RowID > 0
               DELETE FROM #TMP_INV WHERE RowID = @n_RowID   
            ELSE
               BREAK   
                
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
         END      
         
         IF ISNULL(@c_Loc,'') <> ''
         BEGIN
            DELETE FROM #TMP_INV WHERE Loc = @c_Loc 
         END                     
      END
      
      /*FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE                
   CLOSE CURSOR_AVAILABLE          
   DEALLOCATE CURSOR_AVAILABLE       */
      
 EXIT_SP:

   /*IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END*/    

   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
END -- Procedure

GO