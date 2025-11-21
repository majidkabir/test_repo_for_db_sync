SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALCONV8                                         */
/* Creation Date: 31-OCT-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-18281 - CN Converse Allocation with pickzone sorting by */
/*          consigneekey (one consignee per load)                       */
/*          UOM2 - load conso from bulk                                 */
/*          UOM7 - Load conso loose from pick                           */
/*          UOM6 - Load conso loose from bulk                           */
/*          Enhancement from WMS-14637 for Strategy 1                   */
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
/* 31-OCT-2021  NJOW     1.0  DEVOPS combine script                     */
/* 15-DEC-2021  NJOW01   1.1  WMS-18517 Optimize allocation sequence for*/
/*                            pickzone                                  */
/* 12-JUL-2022  NJOW02   1.2  WMS-20189 return all inventory not based  */
/*                            on qtylefttofulfill cater for channel.    */
/*                            Change pickzone to loclevel and change    */
/*                            loc optimization logic                    */
/* 12-JUL-2022  NJOW02   1.2  DEVOPS Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[nspALCONV8]
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
           @c_Consigneekey     NVARCHAR(15),
           @c_Storererkey      NVARCHAR(15),
           @c_Province         NVARCHAR(10),
           @n_LoadQty          INT,
           @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT,
           @n_LotQtyAvailable  INT                      
  
   DECLARE @c_key1        NVARCHAR(10),    
           @c_key2        NVARCHAR(5),    
           @c_key3        NCHAR(1)    
                           
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
   
   /*    
   IF @c_UOM IN('6','7') AND ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''  --Discrete allocation not to allocate piece, only allocate case 
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END
   */
   
   /*IF @c_UOM IN('6','7') AND ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')=''  --Load conso not to allocate piece, only allocate case
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN       	
   END*/ 
      
   --IF @c_UOM='2' AND ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W'  --Wave conso not to allocate case, only allocate piece
   IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W'  --Wave conso not to allocate due to multiple consigneekey. have to use load conso allocation by consigneekey.
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END

   --NJOW01
   EXEC isp_Init_Allocate_Candidates
         
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))                             
   CREATE TABLE #LOCLEVQTY (LocLevel NVARCHAR(5), Qty INT)
   CREATE TABLE #LOCLEVSORT (RowID INT IDENTITY(1,1), LocLevel NVARCHAR(5))
   --CREATE TABLE #NUM_OPTIMIZATION_INPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)  --NJOW02 Removed
	 CREATE TABLE #NUM_OPTIMIZATION_OUTPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)         
   
   IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''  --By Order
   BEGIN
   	  SELECT @c_Consigneekey = Consigneekey,
   	         @c_Storerkey = Storerkey
   	  FROM ORDERS (NOLOCK)
   	  WHERE Orderkey = @c_Key1
   END 
   
   IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')=''  --By Load
   BEGIN
   	  SELECT TOP 1 @c_Consigneekey = O.Consigneekey,
   	               @c_Storerkey = O.Storerkey   	  
   	  FROM LOADPLANDETAIL LPD (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   	  WHERE LPD.Loadkey = @c_Key1
   END   
   
   SELECT TOP 1 @c_Province = CL.Short
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Storerkey = @c_Storerkey
   AND CL.Code = @c_Consigneekey
   AND CL.Listname = 'CONSIGROUP'
         
   IF @c_UOM IN( '2','6')
   BEGIN
      SET @c_LocationType = '''OTHER'''
      SET @c_LocationCategory = '''BULK'''
      SET @c_SortBy = 'ORDER BY CASE WHEN LV.RowID IS NOT NULL THEN LV.RowID ELSE 99999 END, LA.Lottable05, LOTxLOCxID.Lot, LOC.LogicalLocation, LOC.Loc'
   END         
   
   IF @c_UOM = '7'
   BEGIN
      SET @c_LocationType = '''PICK'''
      SET @c_LocationCategory = '''OTHER'''
      SET @c_SortBy = 'ORDER BY CASE WHEN LV.RowID IS NOT NULL THEN LV.RowID ELSE 99999 END, LA.Lottable05, LOTxLOCxID.Lot, LOC.LogicalLocation, LOC.Loc'
   END         
   
   --NJOW01 S
   SELECT @n_LoadQty = SUM(OD.OpenQty)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON LPD.Orderkey = OD.Orderkey
   WHERE LPD.Loadkey = @c_Key1
   AND OD.Storerkey = @c_Storerkey
   AND OD.Sku = @c_Sku 
   AND OD.Lottable01 = CASE WHEN ISNULL(@c_Lottable01,'') <> '' THEN @c_Lottable01 ELSE OD.Lottable01 END
   
   SET @c_SQL = N'      
      INSERT INTO #LOCLEVQTY (LocLevel, Qty)      
      SELECT CAST(LOC.LocLevel AS NVARCHAR),    
             SUM((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) + ISNULL(LPA.LoadQtyAllocated,0))
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)  
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')  
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
      OUTER APPLY (SELECT SUM(PD.Qty) LoadQtyAllocated
                   FROM LOADPLANDETAIL LPD (NOLOCK)
                   JOIN ORDERDETAIL OD (NOLOCK) ON LPD.Orderkey = OD.Orderkey
                   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
                   WHERE LPD.Loadkey = @c_Key1
                   AND PD.Lot = LOTxLOCxID.Lot
                   AND PD.Loc = LOTxLOCxID.Loc
                   AND PD.ID = LOTxLOCxID.ID
                   ) LPA         
      WHERE LOC.LocationFlag = ''NONE''  
      AND LOC.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility  
      AND LOTxLOCxID.STORERKEY = @c_StorerKey  
      AND ((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) + ISNULL(LPA.LoadQtyAllocated,0)) > 0
      AND LOTxLOCxID.SKU = @c_SKU 
      AND LA.Lottable01 = CASE WHEN ISNULL(@c_Lottable01,'''') <> '''' THEN @c_Lottable01 ELSE LA.Lottable01 END
      GROUP BY CAST(LOC.LocLevel AS NVARCHAR) '     
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +        
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                      '@c_Lottable12 NVARCHAR(30), @c_Key1 NVARCHAR(10)'  

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_key1  
   
   /* --NJOW02 Removed                    
   INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount)     
   SELECT LocLevel, Qty, 1
   FROM #LOCLEVQTY LV
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = @c_Province AND CL.Code =  LV.LocLevel AND CL.Storerkey = @c_Storerkey
   ORDER BY CASE WHEN CL.Short IS NOT NULL THEN CL.Short ELSE 'ZZZ' END, CAST(LV.LocLevel AS INT)
                                            
   INSERT INTO #NUM_OPTIMIZATION_OUTPUT
	 EXEC isp_Num_Optimization 
	      @n_NumRequest = @n_LoadQty
       ,@c_OptimizeMode = '0'	          
   */
   
   --NJOW02 S
   INSERT INTO #NUM_OPTIMIZATION_OUTPUT (KeyField, Num, UnitCount)     
   SELECT TOP 1 LV.LocLevel, LV.Qty, 1
   FROM #LOCLEVQTY LV
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = @c_Province AND CL.Code =  LV.LocLevel AND CL.Storerkey = @c_Storerkey
   WHERE LV.Qty >= @n_LoadQty
   ORDER BY CASE WHEN CL.Short IS NOT NULL THEN CL.Short ELSE 'ZZZ' END, LV.Qty, CAST(LV.LocLevel AS INT)
   --NJOW02 E
       
   INSERT INTO #LOCLEVSORT (LocLevel)
   SELECT OP.KeyField 
   FROM #NUM_OPTIMIZATION_OUTPUT OP
   ORDER BY OP.RowId
   
   INSERT INTO #LOCLEVSORT (LocLevel)
   SELECT CL.Code 
   FROM CODELKUP CL (NOLOCK)
   LEFT JOIN #NUM_OPTIMIZATION_OUTPUT OP ON CL.Code = OP.KeyField  
   WHERE CL.Listname = @c_Province 
   AND CL.Storerkey = @c_Storerkey   
   AND OP.KeyField IS NULL
   AND ISNUMERIC(CL.Code) = 1
   GROUP BY CL.Code, CL.Short
   ORDER BY CL.Short
   --NJOW01 E                   
            
   SET @c_SQL = N'      
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,    
             SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)  
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')  
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
      LEFT JOIN #LOCLEVSORT LV ON CAST(LV.LocLevel AS INT) = LOC.LocLevel
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
      'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.LogicalLocation, LOC.LOC, LA.Lottable05, CASE WHEN LV.RowID IS NOT NULL THEN LV.RowID ELSE 99999 END ' +    
      @c_SortBy
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                      '@c_Lottable12 NVARCHAR(30), @n_UOMBase INT, @c_Province NVARCHAR(10) '  

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_UOMBase, @c_Province                      

   SET @n_LotQtyAvailable = 0
   SET @c_OtherValue = ''
   
   OPEN CURSOR_AVAILABLE         
              
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   --WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)         
   WHILE @@FETCH_STATUS <> -1    --NJOW02
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
               	                  
      --IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      --BEGIN
      		 SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      --END
      --ELSE
      --BEGIN
      --	  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      --END      	 
      
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
               	
         --SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
      END
            
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE                                

 EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
END -- Procedure

GO