SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALMYNK1                                         */    
/* Creation Date: 22-AUG-2023                                           */    
/* Copyright: MAERSK                                                    */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-23252 MY&SG Nike allocation                             */
/*          SkipPreallocation = '1'                                     */
/*                                                                      */
/* Called By: Wave                                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/* 22-AUG-2023  NJOW    1.0   DEVOPS Combine Script                     */
/* 31-OCT-2023  NJOW01  1.1   WMS-23899 remove bundle sku checking. Add */
/*                            lottable02 = '01PMO' as bonded            */
/************************************************************************/    
CREATE   PROC [dbo].[nspALMYNK1]        
   @c_DocumentNo NVARCHAR(10),  
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
   @c_OtherParms NVARCHAR(200)='',
   @c_AllocateStrategyKey NVARCHAR(10)='',
   @c_AllocateStrategyLineNumber NVARCHAR(5)=''
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    
      
   DECLARE @c_SQL                NVARCHAR(MAX),    
           @c_SQLParm            NVARCHAR(MAX),                                   
           @c_key1               NVARCHAR(10),    
           @c_key2               NVARCHAR(5),    
           @c_key3               NCHAR(1),
           @c_Orderkey           NVARCHAR(10),     
           @n_QtyAvailable       INT = 0,  
           @c_LOT                NVARCHAR(10),
           @c_LOC                NVARCHAR(10),
           @c_ID                 NVARCHAR(18), 
           @c_OtherValue         NVARCHAR(20) = '',
           @n_QtyToTake          INT = 0,
           @n_LotQtyAvailable    INT,
           @c_Stop               NVARCHAR(10)='',
           @c_Orderby            NVARCHAR(MAX)='',
           @c_Condition          nvarchar(MAX)=''
                        
   IF @n_UOMBase = 0
     SET @n_UOMBase = 1
     
   EXEC isp_Init_Allocate_Candidates         

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))
   
   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber             
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave                
      
      IF ISNULL(@c_Key2,'') <> ''
      BEGIN
      	 SELECT @c_Stop = O.Stop
      	 FROM ORDERS O (NOLOCK)
      	 WHERE O.Orderkey = @c_Key1      	 
      END
      ELSE IF ISNULL(@c_Key2,'') = '' AND ISNULL(@c_key3,'') = ''
      BEGIN
         SELECT TOP 1 @c_Stop = O.Stop
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         WHERE LPD.Loadkey = @c_key1
      END
      ELSE IF ISNULL(@c_Key2,'') = '' AND ISNULL(@c_key3,'') = 'W'
      BEGIN
         SELECT TOP 1 @c_Stop = O.Stop
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         WHERE WD.Wavekey = @c_key1
      END            
   END
   
   IF @c_Lottable02 IN('01000','01PMO') --Bonded --NJOW01
   BEGIN
   	  IF @c_Stop IN('20')  --Footwear
   	  BEGIN
   	  	 SET @c_Condition = RTRIM(ISNULL(@c_Condition,'')) +  ' AND ((LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''SHELVING'' AND LOC.LoseId IN(''0'',''1'')) OR 
   	  	                                                             (LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel = 1) OR
   	  	                                                             (LOC.LocationType = ''OTHER'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel <> 1)) ' --High bay, Mezzanine, Selective rack pick face(lv=1), selective rack (lv=2-10)
   	  	                                                             
   	  	 SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''SHELVING'' AND LOC.LoseId IN(''0'',''1'') THEN 1
   	  	                                  WHEN LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel = 1 THEN 2 
   	  	                                  WHEN LOC.LocationType = ''OTHER'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel <> 1 THEN 3
   	  	                                       ELSE 4 END, LOC.LogicalLocation, LOC.Loc '   	  	                                          	  	  
   	  END
   	  
   	  IF @c_Stop IN('10','30')  --Apparel & Equipment
   	  BEGIN
   	  	 SET @c_Condition = RTRIM(ISNULL(@c_Condition,'')) +  ' AND ((LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''SHELVING'' AND LOC.LoseId IN(''1'')) OR 
   	  	                                                             (LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel = 1)) ' --Mezzanine, Selective rack pick face(lv=1)

   	  	 SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''SHELVING'' AND LOC.LoseId IN(''1'') THEN 1
   	  	                                  WHEN LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel = 1 THEN 2    	  	                                   
   	  	                                       ELSE 3 END, LOC.LogicalLocation, LOC.Loc '   	  	                                          	  	     	  	                                                             
   	  END
   END
   ELSE --'01RTN' Non-Bonded
   BEGIN
   	  IF @c_Stop IN('20')  --Footwear
   	  BEGIN
   	  	 SET @c_Condition = RTRIM(ISNULL(@c_Condition,'')) +  ' AND ((LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel = 1) OR
   	  	                                                             (LOC.LocationType = ''OTHER'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel <> 1)) ' --Selective rack pick face(lv=1), selective rack (lv=2-10)

   	  	 SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''PACK'' AND LOC.LocLevel = 1 THEN 1
   	  	                                  WHEN LOC.LocationType = ''OTHER'' AND LOC.LocationCategory = ''RACK'' AND LOC.LocLevel <> 1 THEN 2    	  	                                   
   	  	                                       ELSE 3 END, LOC.LogicalLocation, LOC.Loc '   	  	                                          	  	     	  	                                                             
   	  END

   	  IF @c_Stop IN('10','30')  --Apparel & Equipment
   	  BEGIN
   	  	 SET @c_Condition = RTRIM(ISNULL(@c_Condition,'')) +  ' AND LOC.LocationType = ''PICK'' AND LOC.LocationCategory = ''SHELVING'' AND LOC.LoseId IN(''1'') ' --Mezzanine

   	  	 SET @c_OrderBy = ' ORDER BY LOC.LogicalLocation, LOC.Loc '   	  	                                          	  	     	  	                                                             
   	  END
   END
   
   IF @c_OrderBy = ''
      SET @c_OrderBy  = ' ORDER BY LOC.LogicalLocation, LOC.Loc '
         
   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      JOIN SKU (NOLOCK) ON (SKU.StorerKey = SL.StorerKey AND SKU.Sku = SL.Sku)
      WHERE LOC.Status = ''OK''
      AND LOT.Status = ''OK''
      AND ID.Status = ''OK''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU       
      AND LOC.LocationFlag = ''NONE'' ' +
      --AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % SKU.PackQtyIndicator = 0 ' +  --NJOW01 Removed
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
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
      RTRIM(@c_Condition) + ' ' +
      RTRIM(@c_OrderBy) 
      
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
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
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