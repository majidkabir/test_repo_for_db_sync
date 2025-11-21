SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/            
/* Stored Procedure: ispAL_CN08                                          */            
/* Creation Date: 2021-05-25                                             */            
/* Copyright: LFL                                                        */            
/* Written by: WLChooi                                                   */            
/*                                                                       */            
/* Purpose: WMS-17088 - [CN] Coach - Exceed Allocation Strategy          */            
/*          For UOM 7 (OverAllocation)                                   */
/*                                                                       */            
/* Called By:                                                            */            
/*                                                                       */            
/* GitLab Version: 1.3                                                   */            
/*                                                                       */            
/* Version: 7.0                                                          */            
/*                                                                       */            
/* Data Modifications:                                                   */            
/*                                                                       */            
/* Updates:                                                              */            
/* Date         Author  Ver.  Purposes                                   */
/* 2021-09-30   WLChooi 1.1   Bug Fix - Extend SKU to NVARCHAR(20) (WL01)*/   
/* 2021-10-25   SYChua  1.2   Bug Fix - Change LA to LOTATTRIBUTE (SY01) */
/* 2021-09-30   WLChooi 1.3   DevOps Combine Script                      */   
/* 2021-09-06   WLChooi 1.3   WMS-17878 - Overallocate from PA LOC and   */
/*                            Load Conso for UOM 2 only (WL02)           */ 
/*************************************************************************/            
CREATE PROC [dbo].[ispAL_CN08]
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
           @n_LotQty             INT,
           @c_UserDefine01       NVARCHAR(50) = '',
           @c_PALoc              NVARCHAR(50) = '',  --WL02  
           @c_Strategykey        NVARCHAR(50) = ''   --WL02
                        
   EXEC isp_Init_Allocate_Candidates      
          
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
      
      SELECT @c_WaveType    = WaveType
           , @c_Strategykey = Strategykey   --WL02
      FROM WAVE (NOLOCK)
      WHERE Wavekey = @c_Wavekey  
      
      SELECT TOP 1 @c_UserDefine01 = UserDefine01     
      FROM ORDERS (NOLOCK)
      WHERE UserDefine09 = @c_Wavekey                     
   END    
   
   --WL02 S
   IF @c_key3 <> 'W' AND @c_UOM IN ('7') AND @c_Strategykey <> 'COACH2B'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN   
   END     
   --WL02 E   

   IF @c_UOM IN ('7')  
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOC.LocationType IN (''OTHER'') '
      SELECT @c_OrderBy = ' ORDER BY LOTATTRIBUTE.Lottable05, LOC.LOCLevel, LOC.LogicalLocation, LOC.Loc '
   END    
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END

   --WL02 S
   SELECT @c_PALoc = ISNULL(CL.Short,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'COHLOC'
   AND CL.Storerkey = @c_StorerKey
   AND CL.Code = 'PUTAWAY'

   IF ISNULL(@c_PALoc,'') <> ''
      SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LOC = @c_PALoc THEN 1 ELSE 2 END, LOTATTRIBUTE.Lottable05, LOC.LOCLevel, LOC.LogicalLocation, LOC.Loc '
   --WL02 E
   
   SELECT @c_SQL = ' DECLARE CURSOR_COACH_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                   ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                   ' QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) ' +
                   ' FROM LOTATTRIBUTE (NOLOCK) ' +
                   ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
                   ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
                   ' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +
                   ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                   ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                   ' JOIN UCC U WITH (NOLOCK) ON U.SKU = LOTxLOCxID.SKU AND U.LOT = LOTxLOCxID.LOT AND U.LOC = LOTxLOCxID.LOC AND U.ID = LOTxLOCxID.ID AND U.Status < ''3'' ' + 
                   ' WHERE LOT.STORERKEY = @c_storerkey ' +
                   ' AND LOT.SKU = @c_SKU ' +
                   ' AND LOT.STATUS = ''OK'' ' +
                   ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                   ' AND LOC.LocationFlag = ''NONE'' ' + 
                   ' AND LOC.Facility = @c_facility ' + 
                   ' AND LOTATTRIBUTE.STORERKEY = @c_storerkey ' +
                   ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
                   RTRIM(ISNULL(@c_Condition,''))  + 
                   CASE WHEN ISNULL(RTRIM(@c_UserDefine01),'') = '' THEN '' ELSE ' AND LOC.HostWHCode = @c_UserDefine01 ' END +
                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END +  --SY01
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +  --SY01
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +  --SY01
                   CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +  --SY01
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +  --SY01
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +  --SY01
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +  --SY01
                   ' GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, LOC.LocLevel ' +
                   ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                   RTRIM(ISNULL(@c_OrderBy,''))

   EXEC sp_executesql @c_SQL 
      , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
          @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
          @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
          @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
          @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
          @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME,
          @c_UserDefine01  NVARCHAR(50), @c_PALoc      NVARCHAR(50) '   --WL01   --WL02  
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
      , @c_UserDefine01
      , @c_PALoc   --WL02
   
   SET @c_SQL = ''
   
   OPEN CURSOR_COACH_AVAILABLE                    
   FETCH NEXT FROM CURSOR_COACH_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable
      
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN           	
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
         UPDATE #TMP_LOT
         SET QtyAvailable = QtyAvailable - @n_QtyToTake
         WHERE Lot = @c_Lot

         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue

      END
   	SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake                	 
             
      FETCH NEXT FROM CURSOR_COACH_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable 
   END -- END WHILE FOR CURSOR_COACH_AVAILABLE                
         
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_COACH_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_COACH_AVAILABLE          
      DEALLOCATE CURSOR_COACH_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
   
   EXIT_SP:
END

GO