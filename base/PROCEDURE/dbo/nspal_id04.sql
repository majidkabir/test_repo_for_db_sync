SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/            
/* Stored Procedure: nspAL_ID04                                          */            
/* Creation Date: 24-Aug-2022                                            */            
/* Copyright: LFL                                                        */            
/* Written by: WLChooi                                                   */            
/*                                                                       */            
/* Purpose: WMS-20605 - ID-PUMA-Wave Allocation Strategy                 */            
/*          For UOM 6 - Loose, Overallocation                            */
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
/* 24-Aug-2022  WLChooi 1.0   DevOps Combine Script                      */
/* 06-Jul-2023  WLChooi 1.1   WMS-22939 - WaveConso for B2B (WL01)       */
/*************************************************************************/             
CREATE   PROC [dbo].[nspAL_ID04]
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
   DECLARE @c_Condition             NVARCHAR(MAX),
           @c_SQL                   NVARCHAR(MAX),
           @c_OrderBy               NVARCHAR(1000), 
           @n_QtyToTake             INT,
           @n_QtyAvailable          INT,
           @c_Lot                   NVARCHAR(10),
           @c_Loc                   NVARCHAR(10), 
           @c_ID                    NVARCHAR(18),
           @c_UCCQty                INT,
           @n_PackQty               INT,
           @c_OtherValue            NVARCHAR(20),
           @n_UCCQty                INT,
           @c_Wavekey               NVARCHAR(10),
           @c_key1                  NVARCHAR(10),    
           @c_key2                  NVARCHAR(5),  
           @c_key3                  NCHAR(1),
           @c_WaveType              NVARCHAR(18),
           @n_LotQty                INT,
           @c_UserDefine01          NVARCHAR(50) = '',
           @c_Strategykey           NVARCHAR(50) = '',
           @c_FilterCondition       NVARCHAR(4000) = '',
           @c_LocationTypeOverride  NVARCHAR(100) = '',
           @c_DocType               NVARCHAR(10) = '',
           @c_DiscreteAlloc         NVARCHAR(10) = 'N'   --Discrete for B2B, WaveConso for B2C
   
   IF @n_UOMBase = 0
      SET @n_UOMBase = 1
                           
   IF LEN(@c_OtherParms) > 0  
   BEGIN   	    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	   
      
      IF ISNULL(@c_key2,'') = '' AND ISNULL(@c_key3,'') = ''   --Load
      BEGIN
          SET @c_DocType = ''

          SELECT TOP 1 @c_DocType = O.DocType
          FROM ORDERS O (NOLOCK) 
          JOIN LoadPlanDetail LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
          WHERE LPD.Loadkey = @c_key1

          SET @c_DiscreteAlloc = 'N'
      END 
       
      IF ISNULL(@c_key2,'') <> ''   --Order
      BEGIN
         SET @c_DocType = ''

         SELECT TOP 1 @c_DocType = O.DocType
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_Key1

         SET @c_DiscreteAlloc = 'Y'
      END

      IF ISNULL(@c_key2,'') = '' AND @c_key3 = 'W'   --Wave   --WL01
      BEGIN
         SET @c_DocType = ''

         SELECT TOP 1 @c_DocType = O.DocType
         FROM ORDERS O (NOLOCK)
         WHERE O.UserDefine09 = @c_Key1

         SET @c_DiscreteAlloc = 'N'
      END
   END

   EXEC isp_Init_Allocate_Candidates      
          
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0)
   )       
   
   IF ISNULL(@c_AllocateStrategyKey,'') <> ''
   BEGIN
      SELECT @c_LocationTypeOverride = LocationTypeOverride
      FROM ALLOCATESTRATEGYDETAIL (NOLOCK)
      WHERE AllocateStrategyKey = @c_AllocateStrategyKey
      AND AllocateStrategyLineNumber = @c_AllocateStrategyLineNumber
   END

   --WL01 S
   --WaveConso for B2B & B2C
   IF @c_UOM <> '6' OR (@c_DiscreteAlloc = 'Y')
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL          
     
      RETURN  
   END
   --WL01 E

   IF @c_LocationTypeOverride = 'PICK'
   BEGIN
      SET @c_FilterCondition = ' AND LOC.LocationType IN (''PICK'',''OTHER'') '
      SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK''    THEN 10 ' + CHAR(13)
                     + '               WHEN LOC.LocationType = ''OTHER''   THEN 20 END, ' + CHAR(13)
                     + ' LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.Loc, QtyAvailable '
   END
   ELSE        
   BEGIN
      SET @c_FilterCondition = ' AND LOC.LocationType IN (''PICK'',''DPBULK'') '
      SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK''    THEN 10 ' + CHAR(13)
                     + '               WHEN LOC.LocationType = ''DPBULK''  THEN 20 END, ' + CHAR(13)
                     + ' LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.Loc, QtyAvailable '
   END

   SET @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                ' QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) ' +
                ' FROM LOTATTRIBUTE (NOLOCK) ' +
                ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
                ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
                ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                ' WHERE LOT.STORERKEY = @c_storerkey ' +
                ' AND LOT.SKU = @c_SKU ' +
                ' AND LOT.STATUS = ''OK'' ' +
                ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                ' AND LOC.LocationFlag = ''NONE'' ' + 
                ' AND LOC.Facility = @c_facility ' + 
                ' AND LOTATTRIBUTE.STORERKEY = @c_storerkey ' +
                ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
                --' AND LOC.LocationType IN (''PICK'',''DPBULK'',''OTHER'') ' +
                @c_FilterCondition + 
                --CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END + 
                --CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END + 
                --CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
                --CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END + 
                --CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END + 
                --CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +                                                                                      
                --CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +                                                                                      
                --CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +                                                                                      
                --CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +                                                                                      
                --CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +                                                                                      
                --CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +                                                                                      
                --CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +                                                                                      
                --CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END + 
                --CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END + 
                --CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END + 
                ' GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, LOC.LocationType ' +
                ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                RTRIM(ISNULL(@c_OrderBy,''))
   
   EXEC sp_executesql @c_SQL 
      , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
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
      SET @n_UCCQty = 0
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