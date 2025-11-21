SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALTRF02                                         */    
/* Creation Date: 30-JUN-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-17314 MY Transfer/Adjustment Allocation                 */
/*                                                                      */
/* Called By: Transfer allocation                                       */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */  
/* 25-Feb-2022  WLChooi 1.1   DevOps Combine Script                     */
/* 25-Feb-2022  WLChooi 1.1   WMS-18993 - Disable filter Lott04&05(WL01)*/
/* 23-Jun-2022  NJOW01  1.2   WMS-20049 Cater for Kit allocation and    */
/*                            allow disable lottable02 filter           */          
/************************************************************************/    
CREATE PROC [dbo].[nspALTRF02]        
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
          
   DECLARE @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18),            
           @c_FromID           NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT,
           @c_LogicalLocation  NVARCHAR(18),
           @n_StorerMinShelfLife INT,
           @c_PrevLOT          NVARCHAR(10),
           @n_cnt              INT,
           @n_LotQtyAvailable  INT,
           @c_Source           NCHAR(1),
           @c_DisableLot45Filter NVARCHAR(10) = 'N',   --WL01
           @c_DisableLot2Filter NVARCHAR(10) = 'N'  --NJOW01

   DECLARE @c_key1        NVARCHAR(10)    
          ,@c_key2        NVARCHAR(5)    
          
   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   
   IF @n_UOMBase = 0
     SET @n_UOMBase = 1
   
   EXEC isp_Init_Allocate_Candidates
      
   IF LEN(@c_OtherParms) > 0  
   BEGIN   	    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso), Transferkey
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber, TransferLineNumber      	    
      SET @c_Source = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave, T=Transfer A=Adjustment K-kitting  	               
   END
   
   IF @c_Source = 'T' AND ISNULL(@c_Key2,'') <> ''
   BEGIN
   	  SELECT @c_Id = @c_FromId
   	  FROM TRANSFERDETAIL(NOLOCK) 
   	  WHERE Transferkey = @c_Key1
   	  AND TransferLineNumber = @c_Key2 
   END

   IF @c_Source = 'A' AND ISNULL(@c_Key2,'') <> ''
   BEGIN
   	  SELECT @c_Id = @c_Id
   	  FROM ADJUSTMENTDETAIL(NOLOCK) 
   	  WHERE Adjustmentkey = @c_Key1
   	  AND AdjustmentLineNumber = @c_Key2 
   END

   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   
   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   --NJOW01
   SELECT @c_DisableLot2Filter = ISNULL(CL.Short,'N')
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'PKCODECFG'
   AND CL.Storerkey = @c_StorerKey
   AND CL.Code = 'DisableLot2Filter'
   AND CL.Long = 'nspALTRF02'
   AND (CL.Code2 = '' OR CL.Code2 = @c_Facility)
   ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END 
   
   --WL01 S
   SELECT @c_DisableLot45Filter = ISNULL(CL.Short,'N')
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'PKCODECFG'
   AND CL.Storerkey = @c_StorerKey
   AND CL.Code = 'DisableLot45Filter'
   AND CL.Long = 'nspALTRF02'
   AND (CL.Code2 = '' OR CL.Code2 = @c_Facility)
   ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END 
   --WL01 E

   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(ADJLLI.Qty,0))
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
                 AND TD.FromStorerkey = @c_Storerkey ' +
               ' AND TD.FromSku = @c_Sku ' +
               ' GROUP BY TD.FromLot, TD.FromLoc, TD.FromID) AS TRFLLI ON LOTXLOCXID.Lot = TRFLLI.FromLot 
                                                                          AND LOTXLOCXID.Loc = TRFLLI.FromLoc 
                                                                          AND LOTXLOCXID.ID = TRFLLI.FromID             
      LEFT JOIN (SELECT AD.Lot, AD.Loc, AD.ID, SUM(AD.Qty * -1) AS Qty
                 FROM ADJUSTMENT A (NOLOCK)
                 JOIN ADJUSTMENTDETAIL AD (NOLOCK) ON A.Adjustmentkey = AD.Adjustmentkey
                 WHERE AD.FinalizedFlag = ''N''
                 AND AD.Storerkey = @c_Storerkey ' +
               ' AND AD.Sku = @c_Sku ' +
               ' AND AD.Qty < 0 ' +
               ' GROUP BY AD.Lot, AD.Loc, AD.ID) AS ADJLLI ON LOTXLOCXID.Lot = ADJLLI.Lot 
                                                                          AND LOTXLOCXID.Loc = ADJLLI.Loc 
                                                                          AND LOTXLOCXID.ID = ADJLLI.ID             
      LEFT JOIN (SELECT KD.Lot, KD.Loc, KD.ID, SUM(KD.Qty) AS Qty
                 FROM KIT K (NOLOCK)
                 JOIN KITDETAIL KD (NOLOCK) ON K.KitKey = KD.Kitkey
                 WHERE K.Status < ''9''
                 AND KD.Type = ''F''
                 AND K.Storerkey = @c_Storerkey ' +
               ' AND KD.Sku = @c_Sku ' +
               ' GROUP BY KD.Lot, KD.Loc, KD.ID) AS KITLLI ON LOTXLOCXID.Lot = KITLLI.Lot 
                                                                          AND LOTXLOCXID.Loc = KITLLI.Loc 
                                                                          AND LOTXLOCXID.ID = KITLLI.ID             
      WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(ADJLLI.Qty,0) - ISNULL(KITLLI.Qty,0)) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU 
      AND LOTxLOCxID.Id = CASE WHEN ISNULL(@c_ID,'''') <> '''' THEN @c_ID ELSE LOTxLOCxID.Id END ' +      
      --AND LOC.LocationType = ''OTHER'' ' +
      --CASE WHEN @c_UOM = '1' THEN '  AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QtyReplen + ISNULL(TRFLLI.FromQty,0)) = 0 ' ELSE ' ' END + 
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND @c_DisableLot2Filter = 'N' THEN ' AND LA.Lottable02 = @c_Lottable02 ' ELSE ' ' END +  --NJOW01
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL AND @c_DisableLot45Filter = 'N'    --WL01 
           THEN ' AND CONVERT( NVARCHAR(20), LA.Lottable04, 106) = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +   --WL01
      CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LA.Lottable04) > GetDate() ' ELSE ' ' END + 
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL AND @c_DisableLot45Filter = 'N'    --WL01 
           THEN ' AND CONVERT( NVARCHAR(20), LA.Lottable05, 106) = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +   --WL01
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND CONVERT( NVARCHAR(20), LA.Lottable13, 106) = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND CONVERT( NVARCHAR(20), LA.Lottable14, 106) = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND CONVERT( NVARCHAR(20), LA.Lottable15, 106) = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +      
      ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0) - ISNULL(ADJLLI.Qty,0) - ISNULL(KITLLI.Qty,0)) >= @n_UOMBase '  +
      ' ORDER BY LA.Lottable05, LA.Lot, LOC.LogicalLocation, LOC.LOC ' 

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, @c_ID NVARCHAR(18) ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_ID              
                         
   SET @c_SQL = ''
   SET @c_PrevLOT = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
      IF @c_LOT <> @c_PrevLOT 
      BEGIN
      	 SELECT @n_LotQtyAvailable = SUM(Qty - QtyAllocated - QtyPicked)
      	        - (SELECT SUM(TD.FromQty) 
      	           FROM TRANSFER T (NOLOCK)
      	           JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
      	           AND TD.Status <> '9' 
      	           AND TD.FromLot = LOT.Lot)      	    
      	        - (SELECT SUM(AD.Qty * -1) 
      	           FROM ADJUSTMENT A (NOLOCK)
      	           JOIN ADJUSTMENTDETAIL AD (NOLOCK) ON A.Adjustmentkey = AD.Adjustmentkey
      	           AND AD.Finalizedflag = 'N'
      	           AND AD.Qty < 0 
      	           AND AD.Lot = LOT.Lot)      	    
      	        - (SELECT SUM(KD.Qty)   --NJOW01
      	           FROM KIT K (NOLOCK)
      	           JOIN KITDETAIL KD (NOLOCK) ON K.Kitkey = KD.Kitkey      	           
      	           AND KD.Lot = LOT.Lot
      	           AND KD.Type = 'F'
      	           WHERE K.Status < '9')      	    
      	 FROM LOT (NOLOCK)
      	 WHERE LOT = @c_LOT
       	 GROUP BY Lot
      END
      
      IF @n_LotQtyAvailable < @n_QtyAvailable 
         SET @n_QtyAvailable = @n_LotQtyAvailable
               	                  
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
         SET @c_Lot       = RTRIM(@c_Lot)             
         SET @c_Loc       = RTRIM(@c_Loc)
         SET @c_ID        = RTRIM(@c_ID)

         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue
                  
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
         SET @n_LotQtyAvailable = @n_LotQtyAvailable - @n_QtyToTake    
      END
      
      SET @c_PrevLOT = @c_LOT
      
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE          

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates   
        @n_SkipPreAllocationFlag = 1        
END -- Procedure

GO