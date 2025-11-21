SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: nspAL_SG10                                         */    
/* Creation Date: 25-APR-2023                                           */    
/* Copyright: MAERSK                                                    */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-22418 SG AESOP Allocate                                 */
/*          SkipPreallocation = '1'                                     */
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
/* Date         Author  Ver.  Purposes                                  */   
/* 24-APR-2023  NJOW    1.0   DEVOPS Combine Script                     */
/************************************************************************/    
CREATE   PROC [dbo].[nspAL_SG10]        
   @c_Orderkey    NVARCHAR(10),  
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

   IF @n_UOMBase = 0
     SET @n_UOMBase = 1

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
           @n_cnt              INT,
           @n_LotQtyAvailable  INT = 0,
           --@n_LocQty           INT,
           --@n_NoOfLot          INT, 
           @c_Conditions       NVARCHAR(2000) = '',
           @c_Key1             NVARCHAR(10), 
           @c_Key2             NVARCHAR(5), 
           @c_Key3             NVARCHAR(1), 
           @c_Sorting          NVARCHAR(2000) = '',            
           @c_LocationType     NVARCHAR(10) = '', 
           @c_SUSR1            NVARCHAR(18),
           @n_Days             INT = 0
           

   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0

   EXEC isp_Init_Allocate_Candidates    

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))
         
   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10) 
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	    
      
      IF ISNULL(@c_key2,'')<>'' 
      BEGIN      	 
      	 IF EXISTS(SELECT 1
      	           FROM ORDERDETAIL OD (NOLOCK)
      	           JOIN CODELKUP CL (NOLOCK) ON OD.Storerkey = CL.Storerkey AND CL.ListName = 'LOT03LIST' 
      	                                        AND OD.Lottable03 = CL.Code AND CL.Short = 'B2C'
      	           WHERE OD.Orderkey = @c_Orderkey
      	           AND OD.OrderLineNumber = @c_Key2)
      	    SELECT @c_Conditions = RTRIM(@c_Conditions) + ' AND LOC.LocationType = ''PICK'' '      	           
      END        	              
   END
   
   SELECT @c_Susr1 = Susr1
   FROM SKU (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Sku = @c_Sku
   
   IF @c_Lottable01 = '' AND @c_Susr1 = 'Y'  
   BEGIN
     	SELECT @n_Days = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END
  		FROM CODELKUP CL (NOLOCK)
  		WHERE CL.ListName = 'CUSTPARAM'
  		AND CL.Code = 'SHELFLIFE'
  		AND CL.Storerkey = @c_Storerkey  		

      SELECT @c_Sorting = ' ORDER BY dbo.fnc_GetNumFromString(LA.Lottable01,''AESOP''), LA.Lottable05, LOC.LogicalLocation, LOC.Loc '      
      --SELECT @c_Sorting = ' ORDER BY SUBSTRING(LA.Lottable01,6,2) + SUBSTRING(LA.Lottable01,4,2) + SUBSTRING(LA.Lottable01,1,2), LA.Lottable05, LOC.LogicalLocation, LOC.Loc '      
      
      SELECT @c_Conditions = RTRIM(@c_Conditions) + ' AND DATEDIFF(Day, GETDATE(), DATEADD(day, @n_Days, CONVERT(DATETIME,dbo.fnc_GetNumFromString(LA.Lottable01,''AESOP'')))) > 0 '
      --SELECT @c_Conditions = RTRIM(@c_Conditions) + ' AND DATEDIFF(Day, GETDATE(), DATEADD(Year,2,CONVERT(DATETIME,SUBSTRING(LA.Lottable01,6,2) + SUBSTRING(LA.Lottable01,4,2) + SUBSTRING(LA.Lottable01,1,2))) - 1) >= 0 '
   END
   ELSE
   BEGIN
      SELECT @c_Sorting = ' ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc '      
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
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(KITLLI.ExpectedQty,0))
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      LEFT JOIN (SELECT TD.FromLot, TD.FromLoc, TD.FromID, SUM(TD.FromQty) AS FromQty
                 FROM TRANSFER T (NOLOCK)
                 JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
                 WHERE TD.Status <> ''9''
                 AND TD.FromStorerkey = @c_StorerKey 
                 AND TD.FromSku = @c_Sku 
                 GROUP BY TD.FromLot, TD.FromLoc, TD.FromID) AS TRFLLI ON LOTXLOCXID.Lot = TRFLLI.FromLot 
                                                                          AND LOTXLOCXID.Loc = TRFLLI.FromLoc 
                                                                          AND LOTXLOCXID.ID = TRFLLI.FromID             
      LEFT JOIN (SELECT KD.Lot, KD.Loc, KD.ID, SUM(KD.ExpectedQty) AS ExpectedQty
                 FROM KIT K (NOLOCK)
                 JOIN KITDETAIL KD (NOLOCK) ON K.Kitkey = kD.Kitkey
                 WHERE K.Status <> ''9''
                 AND K.Storerkey = @c_Storerkey
                 AND KD.Type = ''F''
                 AND KD.Lot <> ''''
                 AND KD.Lot IS NOT NULL
                 GROUP BY KD.Lot, KD.Loc, KD.ID) AS KITLLI ON LOTXLOCXID.Lot = KITLLI.Lot 
                                                                          AND LOTXLOCXID.Loc = KITLLI.Loc 
                                                                          AND LOTXLOCXID.ID = KITLLI.ID             
      WHERE LOC.LocationFlag = ''NONE''
      AND LOC.Status = ''OK''
      AND LOT.Status = ''OK''
      AND ID.Status = ''OK''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(KITLLI.ExpectedQty,0)) >= @n_UOMBase
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU ' +
      --CASE WHEN @c_UOM = '1' THEN '  AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QtyReplen + ISNULL(TRFLLI.FromQty,0) - ISNULL(KITLLI.ExpectedQty,0)) = 0 ' ELSE ' ' END + 
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
      --CASE WHEN @c_UOM = '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(KITLLI.ExpectedQty,0)) <= @n_QtyLeftToFulfill ' ELSE ' ' END + 
      --CASE WHEN @c_UOM <> '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(KITLLI.ExpectedQty,0)) >= @n_UOMBase ' ELSE ' ' END  +
      ' ' + RTRIM(ISNULL(@c_Conditions,''))  + 
      ' ' + RTRIM(ISNULL(@c_Sorting,''))

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, @n_Days INT ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_Days

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
      IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
      BEGIN
          INSERT INTO #TMP_LOT (Lot, QtyAvailable)
      	  SELECT Lot, 
      	         SUM(Qty - QtyAllocated - QtyPicked)
      	        - (SELECT ISNULL(SUM(TD.FromQty),0) 
      	           FROM TRANSFER T (NOLOCK)
      	           JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
      	           AND T.FromStorerKey = @c_Storerkey
      	           AND TD.Status <> '9' 
      	           AND TD.FromLot = LOT.Lot)      	         
      	        - (SELECT ISNULL(SUM(KD.ExpectedQty),0) 
      	           FROM KIT K (NOLOCK)
      	           JOIN KITDETAIL KD (NOLOCK) ON K.Kitkey = KD.Kitkey
      	           AND K.Status <> '9' 
      	           AND KD.Type = 'F'
      	           AND K.Storerkey = @c_storerkey
      	           AND KD.Lot = LOT.Lot)      	         
      	  FROM LOT (NOLOCK)
      	  WHERE LOT = @c_LOT
       	  GROUP BY Lot
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
               	                  
      /*IF @c_UOM = '1' --Pallet
      BEGIN     	   
     	   SELECT @n_LocQty = 0, @n_NoOfLot = 0
          	  
         SELECT @n_LocQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen),
                @n_NoOfLot = COUNT(DISTINCT LLI.Lot)
         FROM LOTXLOCXID LLI (NOLOCK)
         WHERE LLI.Loc = @c_LOC
         AND LLI.ID = @c_ID
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku 
         AND LLI.Qty > 0  
                	        	
         IF @n_QtyLeftToFulfill >= @n_QtyAvailable 
            AND @n_NoOfLot = 1 -- if multi lot per sku/loc/id then proceed to next strategy allocation by carton
         BEGIN                	    
            SET @n_QtyToTake = @n_QtyAvailable  
         END
         ELSE
         BEGIN
         	  SET @n_QtyToTake = 0
            --GOTO EXIT_SP
         END
      END*/

      --IF @c_UOM <> '1' --Case/Piece 
      --BEGIN
      	 IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      	 BEGIN
      	 		 SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      	 END
      	 ELSE
      	 BEGIN
      	 	  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      	 END      	 
      --END
      
      IF @n_QtyToTake > 0
      BEGIN
         UPDATE #TMP_LOT
         SET QtyAvailable = QtyAvailable - @n_QtyToTake
         WHERE Lot = @c_Lot
      	
      	 /*IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1'
          	 SET @c_OtherValue = 'FULLPALLET' 
         ELSE
           	 SET @c_OtherValue = '1'*/
           	 
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