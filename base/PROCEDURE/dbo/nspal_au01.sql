SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/            
/* Stored Procedure: nspAL_AU01                                          */            
/* Creation Date: 24-Sep-2021                                            */            
/* Copyright: LFL                                                        */            
/* Written by: WLChooi                                                   */            
/*                                                                       */            
/* Purpose: WMS-18013 - LFL Australia | UCC Allocation Strategy for      */       
/*          Mosaic and Adidas                                            */     
/*          For UOM 2 & 6                                                */
/*                                                                       */            
/* Called By:                                                            */            
/*                                                                       */            
/* GitLab Version: 1.0                                                   */            
/*                                                                       */            
/* Version: 7.0                                                          */            
/*                                                                       */            
/* Data Modifications:                                                   */            
/*                                                                       */            
/* Updates:                                                              */            
/* Date         Author  Ver.  Purposes                                   */    
/* 24-Sep-2021  WLChooi 1.0   DevOps Script Combine                      */
/* 25-Oct-2023  JihHaur 1.1   JSM186089 0 qty location allocated (JH01)  */
/*************************************************************************/            
CREATE   PROC [dbo].[nspAL_AU01]
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
   @c_OtherParms NVARCHAR(200) = ''
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
           @n_PackQty            INT,
           @c_OtherValue         NVARCHAR(20),
           @c_Wavekey            NVARCHAR(10),
           @c_key1               NVARCHAR(10),    
           @c_key2               NVARCHAR(5),  
           @c_key3               NCHAR(1),
           @n_LotQty             INT,
           @c_DiscreteAlloc      NVARCHAR(10) = 'N',
           @n_UCCQty             INT,
           @c_UCCNo              NVARCHAR(20) = ''  
                        
   EXEC isp_Init_Allocate_Candidates      
          
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0)
   )       
                               
   IF ISNULL(RTRIM(@c_OtherParms) ,'') <> ''          
   BEGIN        
      SET @c_WaveKey = LEFT(@c_OtherParms,10) 
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber             
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave            
      
      IF ISNULL(@c_key2,'') = '' AND ISNULL(@c_key3,'') = '' 
      BEGIN
          SET @c_Wavekey = ''
          SELECT TOP 1 @c_Wavekey = O.Userdefine09
          FROM ORDERS O (NOLOCK) 
          JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
          WHERE O.Loadkey = @c_key1
          AND OD.Sku = @c_SKU
          ORDER BY O.Userdefine09
      END 
       
      IF ISNULL(@c_key2,'') <> ''
      BEGIN
         SELECT TOP 1 @c_Wavekey = O.Userdefine09
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_Key1

         SET @c_DiscreteAlloc = 'Y'
      END       
   END       
   
   --Skip allocate when discrete alloc for UOM 6
   IF @c_DiscreteAlloc = 'Y' AND @c_UOM = '6'  
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN   
   END    

   IF @c_UOM IN ('2')  
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOC.LocationType IN (''CASE'') '
      SELECT @c_OrderBy = ' ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc '

      SELECT @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                      ' SELECT LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                      '        QTYAVAILABLE = UCC.Qty, ' +
                      --'        QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) ' +
                      '        UCC.UCCNo ' +
                      ' FROM LOTATTRIBUTE LA (NOLOCK) ' +
                      ' JOIN LOT (NOLOCK) ON LOT.LOT = LA.LOT ' +
                      ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LA.LOT ' + 
                      --' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +
                      ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                      ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                      ' JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND ' + 
                      '                       UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < ''3'') ' + 
                      ' WHERE LOT.STATUS = ''OK'' ' +
                      ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                      ' AND LOC.LocationFlag = ''NONE'' ' + 
                      ' AND LOC.Facility = @c_facility ' + 
                      ' AND LOTxLOCxID.STORERKEY = @c_storerkey ' +
                      ' AND LOTxLOCxID.SKU = @c_SKU ' +
                      ' AND UCC.Qty > 0  ' +
                      RTRIM(ISNULL(@c_Condition,''))  + 
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
                      --' GROUP BY LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LA.Lottable05 ' +   --, UCC.UCCNo ' +
                      --' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                      ' GROUP BY LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LA.Lottable05, UCC.UCCNo, UCC.Qty ' +    /*JH01*/
                      ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + /*JH01*/
                      RTRIM(ISNULL(@c_OrderBy,''))
   END    
   ELSE   --UOM 6
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOC.LocationType IN (''PICK'') '
      SELECT @c_OrderBy = ' ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc '

      SELECT @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                      ' SELECT LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                      '        QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN), ''1'' ' +
                      --'        CASE WHEN ISNULL(UCC.UCCNo,'''') = '''' THEN ''1'' ELSE UCC.UCCNo END ' +
                      ' FROM LOTATTRIBUTE LA  (NOLOCK) ' +
                      ' JOIN LOT (NOLOCK) ON LOT.LOT = LA.LOT ' +
                      ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LA.LOT ' + 
                      --' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +
                      ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                      ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                      --' LEFT JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND ' + 
                      --'                            UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < ''3'') ' + 
                      ' WHERE LOT.STATUS = ''OK'' ' +
                      ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                      ' AND LOC.LocationFlag = ''NONE'' ' + 
                      ' AND LOC.Facility = @c_facility ' + 
                      ' AND LOTxLOCxID.STORERKEY = @c_storerkey ' +
                      ' AND LOTxLOCxID.SKU = @c_SKU ' +
                      RTRIM(ISNULL(@c_Condition,''))  + 
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
                      ' GROUP BY LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LA.Lottable05 ' +   --', UCC.UCCNo ' +
                      ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                      RTRIM(ISNULL(@c_OrderBy,''))
   END
   
   --PRINT @c_SQL
   EXEC sp_executesql @c_SQL 
      , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(15), @c_Facility NVARCHAR(5), 
          @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
          @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
          @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
          @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
          @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME '
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
   
   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable, @c_OtherValue
      
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
      BEGIN
         IF @c_UOM IN ('1')   
            SET @n_QtyAvailable = 0  
         ELSE  
            SET @n_QtyAvailable = @n_LotQty   
      END

      SET @n_QtyToTake = 0

      IF @c_UOM = '2'
         SET @n_PackQty = @n_QtyAvailable
      ELSE 
         SET @n_PackQty = @n_UOMBase

      --SET @c_OtherValue = '1'

      --IF @c_UOM = '2'
      --BEGIN
      --   SET @c_UCCNo = ''  
      --   SELECT TOP 1   
      --      @n_UCCQty = Qty  --Expect the location have same UCC qty   
      --   FROM UCC (NOLOCK)        
      --   WHERE Storerkey = @c_Storerkey        
      --   AND Sku = @c_Sku        
      --   AND Lot = @c_Lot        
      --   AND Loc = @c_Loc        
      --   AND Id = @c_Id        
      --   AND Status < '3'        
      --   ORDER BY Qty DESC 

      --   IF @n_UCCQty > 0
      --   BEGIN
      --      SET @n_PackQty = @n_UCCQty
      --      --SET @c_OtherValue = @c_UCCNo --'UOM=' + LTRIM(CAST(@n_UCCQty AS NVARCHAR)) --instruct the allocation to take this as casecnt
      --   END
      --END
                                              
      IF @n_QtyAvailable > @n_QtyLeftToFulfill
         SET @n_QtyToTake = CASE WHEN ISNULL(@n_PackQty, 0) = 0 THEN 0 ELSE FLOOR(@n_QtyLeftToFulfill / @n_PackQty) * @n_PackQty END
      ELSE
         SET @n_QtyToTake = CASE WHEN ISNULL(@n_PackQty, 0) = 0 THEN 0 ELSE FLOOR(@n_QtyAvailable / @n_PackQty) * @n_PackQty END                   
        
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

NEXT_LLI:     
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable, @c_OtherValue
   END -- END WHILE FOR CURSOR_AVAILABLE                
         
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
   
   EXIT_SP:
END

GO