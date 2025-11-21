SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Stored Procedure: nspAL_CH01                                         */    
/* Creation Date: 18-AUG-2020                                           */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-14615 [CN] Hasbro_AllocateStrategy_CR                   */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/************************************************************************/      
CREATE PROC [dbo].[nspAL_CH01]            
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
   @c_OtherParms NVARCHAR(200)=''    
AS        
BEGIN        
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF        
          
   DECLARE @c_SQL                NVARCHAR(MAX),        
           @c_SQLParm            NVARCHAR(MAX),                                       
           --@c_key1               NVARCHAR(10),        
           --@c_key2               NVARCHAR(5),        
           --@c_key3               NCHAR(1),    
           --@c_Orderkey           NVARCHAR(10),         
           @n_QtyAvailable       INT,      
           @c_LOT                NVARCHAR(10),    
           @c_LOC                NVARCHAR(10),    
           @c_ID                 NVARCHAR(18),     
           @c_OtherValue         NVARCHAR(20),    
           @n_QtyToTake          INT,    
           @n_StorerMinShelfLife INT,    
           @n_LotQtyAvailable    INT,    
           @c_ExpireCode         NVARCHAR(30),    
           @c_FromDay            NVARCHAR(10),               
           @c_ToDay              NVARCHAR(10),    
           @c_ShelfLifeRange     NCHAR(1),
           @c_packkey            NVARCHAR(20),
           @n_casecnt            INT,
           @n_LeftQtyToFulfill   INT,
           @n_caseqty            INT       
           
    
   SET @n_QtyAvailable = 0              
   SET @c_OtherValue = '1'     
   SET @n_QtyToTake = 0    
   SET @n_LeftQtyToFulfill = 0
   SET @n_caseqty          = 0
       
   IF @n_UOMBase = 0    
     SET @n_UOMBase = 1    
    
   EXEC isp_Init_Allocate_Candidates           
    
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,    
                          QtyAvailable INT NULL DEFAULT(0))    
                              
   /*    
   IF LEN(@c_OtherParms) > 0     
   BEGIN    
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)    
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber               
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave              
          
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' --call by load conso    
      BEGIN    
         SET @c_Orderkey = ''    
         SELECT TOP 1 @c_Orderkey = O.Orderkey    
         FROM ORDERS O (NOLOCK)     
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey    
         WHERE O.Loadkey = @c_key1    
         AND OD.Sku = @c_SKU    
         ORDER BY O.Orderkey, OD.OrderLineNumber    
      END                  
             
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' --call by wave conso    
      BEGIN    
         SET @c_Orderkey = ''    
         SELECT TOP 1 @c_Orderkey = O.Orderkey    
         FROM ORDERS O (NOLOCK)     
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey    
         JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey    
         WHERE WD.Wavekey = @c_key1    
         AND OD.Sku = @c_SKU    
         ORDER BY O.Orderkey, OD.OrderLineNumber    
      END                                   
   END    
   */    
   --IF @c_UOM = '2'

   --BEGIN

   --   SELECT @n_casecnt = p.casecnt
   --   from sku s (nolock) 
   --   join pack p (nolock) on p.packkey=s.packkey
   --   where s.storerkey = @c_storerkey
   --   and s.sku=@c_sku

   --   IF @n_casecnt > 0 
   --   BEGIN
   --       SET @n_caseqty =  (@n_QtyLeftToFulfill/@n_casecnt)
   --       SET @n_LeftQtyToFulfill =   @n_caseqty *  @n_casecnt
   --       SET @n_QtyLeftToFulfill = @n_LeftQtyToFulfill
   --   END

   --END          
   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)    
   FROM Sku (nolock)    
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey    
   WHERE Sku.Sku = @c_sku    
   AND Sku.Storerkey = @c_storerkey       
       
   IF @n_StorerMinShelfLife IS NULL    
      SELECT @n_StorerMinShelfLife = 0    
       
   SET @c_ExpireCode = @c_Lottable12    
   SET @c_FromDay = ''    
   SET @c_ToDay = ''    
   SET @c_ShelfLifeRange = 'N'    
       
   IF ISNULL(@c_ExpireCode,'') <> '' AND ISNULL(@c_Lottable02,'') = ''    
   BEGIN    
      SELECT @c_FromDay = RTRIM(Short), @c_ToDay = RTRIM(Long)    
      FROM CODELKUP (NOLOCK)    
      WHERE Listname = 'NBEXPIRE'    
      AND Code = @c_Expirecode    
          
      IF ISNUMERIC(@c_FromDay) = 1 AND ISNUMERIC(@c_ToDay) = 1    
      BEGIN    
       SET @c_ShelfLifeRange = 'Y'    
      END    
   END          
                   
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
      WHERE LOC.Status <> ''HOLD''    
      AND LOT.Status <> ''HOLD''    
      AND ID.Status <> ''HOLD''    
      AND LOC.Facility = @c_Facility    
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase    
      AND LOTxLOCxID.STORERKEY = @c_StorerKey    
      AND LOTxLOCxID.SKU = @c_SKU           
      AND LOC.LocationFlag = ''NONE'' 
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= 1 ' +    
            
  --    CASE WHEN @c_ShelfLifeRange = 'Y' THEN ' AND DATEDIFF(day, GETDATE(), LA.Lottable04) >= ' + @c_FromDay + ' AND DATEDIFF(day, GETDATE(), LA.Lottable04) <= ' + @c_ToDay + ' '  ELSE ' ' END +    
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
      --CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +    
     -- CASE WHEN @c_UOM = '2' THEN    
         ' ORDER BY LA.lottable05, (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),LOC.LogicalLocation, LOC.LOC '    
      --ELSE    
      --   ' ORDER BY LA.lottable05,CASE WHEN LOTxLOCxID.LOC LIKE ''HAP%'' OR LOTxLOCxID.LOC LIKE ''BAP%'' THEN 1   
      --                WHEN LOTxLOCxID.LOC LIKE ''QHA%'' THEN 2 END, LOC.LogicalLocation, LOC.LOC '    
      --END          
      --' ORDER BY LA.Lottable04, LA.Lottable05, ' + CASE WHEN @c_UOM IN('6','7') THEN ' CASE WHEN LOC.LocationType = ''DYNPPICK'' THEN 1 ELSE 2 END, ' ELSE ' CASE WHEN LOC.LocationType = ''OTHER'' THEN 1 ELSE 2 END, ' END  +       
      --                'LOC.LogicalLocation, LOC.LOC, QTYAVAILABLE '    
    
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +    
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +    
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +    
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME '     
    
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,    
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,    
                      @d_Lottable13, @d_Lottable14, @d_Lottable15   
   
   --print '@n_QtyLeftToFulfill : ' + CAST(@n_QtyLeftToFulfill as nvarchar(20))
   --print @c_SQL
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
           
         /*    
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
         */    
    
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
         @n_SkipPreAllocationFlag = 1    
             
   /*IF ISNULL(@c_SQL,'') <> ''    
   BEGIN    
      EXEC sp_ExecuteSQL @c_SQL    
   END    
   ELSE    
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR     
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL        
   END*/    
END -- Procedure    
  

SET QUOTED_IDENTIFIER OFF 

GO