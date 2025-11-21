SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/            
/* Stored Procedure: nspAL_TH10                                          */            
/* Creation Date: 30-Sep-2022                                            */            
/* Copyright: LFL                                                        */            
/* Written by: WLChooi                                                   */            
/*                                                                       */            
/* Purpose: WMS-20901 - TH-UA customize Allocate sequence                */            
/*          For UOM 6                                                    */
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
/* 30-Sep-2022  WLChooi 1.0   DevOps Combine Script                      */
/*************************************************************************/            
CREATE PROC [dbo].[nspAL_TH10]
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
   @c_OtherParms NVARCHAR(200)='',
   @c_AllocateStrategyKey NVARCHAR(10)='',
   @c_AllocateStrategyLineNumber NVARCHAR(5) = ''
AS
BEGIN   
   DECLARE @c_Condition          NVARCHAR(MAX),
           @c_SQL                NVARCHAR(MAX),
           @c_OrderBy            NVARCHAR(1000) = '', 
           @n_QtyToTake          INT,
           @n_QtyAvailable       INT,
           @c_Lot                NVARCHAR(10),
           @c_Loc                NVARCHAR(10), 
           @c_ID                 NVARCHAR(18),
           @c_UCCQty             INT,
           @n_PackQty            INT,
           @c_OtherValue         NVARCHAR(20),
           @c_Wavekey            NVARCHAR(10),
           @c_key1               NVARCHAR(10),    
           @c_key2               NVARCHAR(5),  
           @c_key3               NCHAR(1),
           @c_WaveType           NVARCHAR(18),
           @n_LotQty             INT,
           @c_UserDefine01       NVARCHAR(50) = '',
           @c_Strategykey        NVARCHAR(50) = '',
           @c_Orderkey           NVARCHAR(10),
           @c_FilterHOSTWHCode   NVARCHAR(10) = 'N',
           @c_Loadkey            NVARCHAR(10),
           @c_Load_Userdef1      NVARCHAR(30),
           @c_OrderGroup         NVARCHAR(30),
           @c_PickzoneList       NVARCHAR(MAX) = '',
           @c_ColValue           NVARCHAR(50),
           @c_GroupBy            NVARCHAR(1000) = '',
           @n_Count              INT = 10

   IF @n_UOMBase = 0
      SET @n_UOMBase = 1
    
   IF EXISTS (SELECT 1  
              FROM CODELKUP (NOLOCK)
              WHERE Listname = 'PKCODECFG'
              AND Storerkey = @c_Storerkey
              AND Code = 'FILTERHOSTWHCODE'
              AND (Code2 = @c_Facility OR ISNULL(Code2,'') = '')
              AND Long IN ('nspAL_TH10')
              AND Short <> 'N')
   BEGIN           
      SET @c_FilterHOSTWHCode = 'Y'
   END 

   IF LEN(@c_OtherParms) > 0
   BEGIN   	    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	          	
      
      IF @c_Key2 <> ''
      BEGIN
      	  SELECT @c_Loadkey = Loadkey
                , @c_OrderGroup = OrderGroup
      	  FROM ORDERS (NOLOCK)
      	  WHERE Orderkey = @c_key1
      END 

      IF @c_key2 = '' AND @c_key3 = ''
      BEGIN
      	  SELECT TOP 1 @c_Loadkey = LPD.Loadkey
                      , @c_OrderGroup = O.OrderGroup
      	  FROM LOADPLANDETAIL LPD (NOLOCK)
           JOIN ORDERS O (NOLOCK) ON O.OrderKey = LPD.OrderKey
      	  WHERE LPD.Loadkey = @c_Key1
      END
   
      IF @c_key2 = '' AND @c_key3 = 'W'
      BEGIN
      	  SELECT TOP 1 @c_Loadkey = O.Loadkey
                      , @c_OrderGroup = O.OrderGroup
      	  FROM WAVEDETAIL WD (NOLOCK)
      	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
      	  WHERE WD.Wavekey = @c_Key1
      END
      
      SELECT @c_Load_Userdef1 = Load_Userdef1
      FROM LOADPLAN (NOLOCK)
      WHERE Loadkey = @c_Loadkey  
   END

   EXEC isp_Init_Allocate_Candidates      
          
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0)
   )        
   
   IF @c_UOM <> '6'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL          
     
      RETURN  
   END

   SET @c_OrderBy = ''

   SELECT TOP 1 @c_PickzoneList = TRIM(ISNULL(UDF01,'')) + ',' 
                                + TRIM(ISNULL(UDF02,'')) + ',' 
                                + TRIM(ISNULL(UDF03,'')) + ',' 
                                + TRIM(ISNULL(UDF04,'')) + ',' 
                                + TRIM(ISNULL(UDF05,''))
   FROM CODELKUP (NOLOCK)
   WHERE LISTNAME = 'UAORDGroup'
   AND Storerkey = @c_StorerKey
   AND Code = @c_OrderGroup

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(FDS.ColValue)
   FROM dbo.fnc_DelimSplit(',', @c_PickzoneList) FDS
   ORDER BY FDS.SeqNo

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_ColValue

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF TRIM(@c_ColValue) <> ''
      BEGIN
         IF ISNULL(@c_OrderBy,'') = ''
         BEGIN
            SET @c_OrderBy += 'CASE WHEN LOC.Pickzone = ''' + @c_ColValue + ''' THEN ' + CAST(@n_Count AS NVARCHAR)
         END
         ELSE
         BEGIN
            SET @n_Count += 10
            SET @c_OrderBy += ' WHEN LOC.Pickzone = ''' + @c_ColValue + ''' THEN ' + CAST(@n_Count AS NVARCHAR)
         END
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_ColValue
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   IF ISNULL(@c_OrderBy,'') <> ''
   BEGIN
      SET @n_Count += 10
      SET @c_OrderBy += ' ELSE ' + CAST(@n_Count AS NVARCHAR) + ' END '
      SET @c_OrderBy = ' ORDER BY ' + TRIM(@c_OrderBy) + ' ,LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.Loc, QtyAvailable '
      SET @c_GroupBy = ' GROUP BY LOC.Pickzone, LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, LOC.LocationType '
   END
   ELSE
   BEGIN
      SET @c_OrderBy = ' ORDER BY LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.Loc, QtyAvailable '
      SET @c_GroupBy = ' GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, LOC.LocationType '
   END

   SET @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                ' QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) ' +
                ' FROM LOTATTRIBUTE (NOLOCK) ' +
                ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
                ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
                ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                ' WHERE LOT.STATUS = ''OK'' ' +
                ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                ' AND LOC.LocationFlag NOT IN (''HOLD'', ''DAMAGE'') ' + 
                ' AND ID.Status NOT IN (''HOLD'') ' + 
                ' AND LOC.Facility = @c_facility ' + 
                ' AND LOTATTRIBUTE.STORERKEY = @c_Storerkey ' +
                ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
                CASE WHEN ISNULL(@c_Load_Userdef1,'') = '' THEN '' ELSE ' AND LOC.HOSTWHCode = @c_Load_Userdef1 ' END +
                CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END + 
                CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END + 
                CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END + 
                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END + 
                CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +                                                                                      
                CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +                                                                                      
                CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +                                                                                      
                CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +                                                                                      
                CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +                                                                                      
                CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +                                                                                      
                CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +                                                                                      
                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END + 
                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END + 
                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END + 
                @c_GroupBy +
                ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                RTRIM(ISNULL(@c_OrderBy,''))

   EXEC sp_executesql @c_SQL 
      , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
          @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
          @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
          @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
          @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
          @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME,
          @c_Load_Userdef1 NVARCHAR(30)'
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
      , @c_Load_Userdef1
   
   SET @c_SQL = ''
   
   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable
      
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
      SET @c_OtherValue = '1'
                                                
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

      NEXT_LLI:     
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable 
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