SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispALEC05                                          */    
/* Creation Date: 24-May-2018                                           */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 336160 - ECOM Allocate                                      */
/*          Single&Multi order carton from BULK                         */
/*          SkipPreAllocation='1'                                       */
/*                                                                      */
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */    
/* 14-Feb-2020 Wan01    1.1   Dynamic SQL review, impact SQL cache log  */ 
/************************************************************************/    
CREATE PROC [dbo].[ispALEC05]        
   @c_LoadKey    NVARCHAR(10),  
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
   SET NOCOUNT ON 
   --SET QUOTED_IDENTIFIER OFF 
   --SET ANSI_NULLS OFF    

   DECLARE @b_debug        INT  
          ,@c_SQL          NVARCHAR(MAX) 
          ,@c_SQLParm      NVARCHAR(MAX) = ''      --(Wan01)          
          ,@n_CaseCnt      INT  
          ,@n_ShelfLife    INT     
          ,@n_continue     INT    
          ,@c_UOMBase      NVARCHAR(10)    
          ,@c_LimitString  NVARCHAR(255)

   DECLARE @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT, 
           @c_PrevLOT          NVARCHAR(10),
           @n_LotQtyAvailable  INT

   EXEC isp_Init_Allocate_Candidates         --(Wan01) 
     
   SELECT @b_debug = 0  
         ,@c_LimitString = ''                 
         ,@c_SQL = ''
         ,@c_PrevLOT = ''
         ,@c_OtherValue = '1'
         
   SELECT @c_UOMBase = @n_UOMBase    
  
   SELECT @n_CaseCnt  = p.CaseCnt   
   FROM PACK p WITH (NOLOCK)  
   JOIN SKU s WITH (NOLOCK) ON s.PackKey = p.PackKey  
   WHERE s.StorerKey = @c_StorerKey AND  
         s.Sku = @c_SKU  
  
   IF (@c_UOM <> '2' OR @n_CaseCnt = 0 )    
   BEGIN  
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL          
     
      RETURN  
   END     
  
   IF @n_QtyLeftToFulfill < @n_CaseCnt
   BEGIN  
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL          
     
      RETURN  
   END  
       
   SELECT @n_ShelfLife = CASE WHEN ISNUMERIC(ISNULL(SKU.Susr2,'0')) = 1 THEN CONVERT(INT, ISNULL(SKU.Susr2,'0')) ELSE 0 END  
   FROM SKU (NOLOCK)  
   WHERE SKU.Sku = @c_SKU  
   AND SKU.Storerkey = @c_StorerKey     
  
   IF @d_Lottable04='1900-01-01'  
   BEGIN  
       SELECT @d_Lottable04 = NULL  
   END    
     
   IF @d_Lottable05='1900-01-01'  
   BEGIN  
       SELECT @d_Lottable05 = NULL  
   END    
                                  
   IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable01= @c_Lottable01'   
     
   IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable02= @c_Lottable02'
     
   IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable03= @c_Lottable03'
     
   IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE04 = CONVERT( NVARCHAR(20), @d_Lottable04, 106) '


   IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE05 = CONVERT( NVARCHAR(20), @d_Lottable05, 106) '

   IF ISNULL(RTRIM(@c_Lottable06) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable06= @c_Lottable06'   

   IF ISNULL(RTRIM(@c_Lottable07) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable07= @c_Lottable07'   

   IF ISNULL(RTRIM(@c_Lottable08) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable08= @c_Lottable08'   

   IF ISNULL(RTRIM(@c_Lottable09) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable09= @c_Lottable09'   
   IF ISNULL(RTRIM(@c_Lottable10) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable10= @c_Lottable10'   
   IF ISNULL(RTRIM(@c_Lottable11) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable11= @c_Lottable11'   
             
   IF ISNULL(RTRIM(@c_Lottable12) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable12= @c_Lottable12'   

   IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE13 = CONVERT( NVARCHAR(20), @d_Lottable13, 106) '

   IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE14 = CONVERT( NVARCHAR(20), @d_Lottable14, 106) '

   IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE15 = CONVERT( NVARCHAR(20), @d_Lottable15, 106) '

                     
   IF @n_ShelfLife > 0  
       SELECT @c_Limitstring = RTrim(@c_LimitString)+  
              ' AND Lottable04  > DATEADD(DAY ,@n_ShelfLife ,GETDATE())'           
   SELECT @c_SQL =   
             ' DECLARE CURSOR_AVAILABLE SCROLL CURSOR FOR '   
            +' SELECT LOT.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id, '
            -- +' LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED '
            +' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) <  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) '
            +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) ' + 
            +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) ' + 
            +' END AS QtyAvailable ' +             
            +' FROM LOT (NOLOCK) '  
            +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) '   
            +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '   
            +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '+  
             ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) '+  
             ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '   
            +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey '+  
             ' AND LOTxLOCxID.SKU = @c_SKU '+  
             ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' '   
            +' AND LOC.Facility = @c_Facility '+@c_LimitString+' '     
            +' AND (SKUxLOC.LocationType NOT IN (''CASE'',''PICK'')) '   
            +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 '  -- SHONG01            
            +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked) >= @n_CaseCnt '             
            --+' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.LOC '  
            +' ORDER BY LOC.LocLevel, QtyAvailable, LOC.LogicalLocation, LOC.LOC '
            
   --EXEC sp_ExecuteSQL @c_SQL
   SET @c_SQLParm = N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), '+
      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), '+
      '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), '+
      '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), '+
      '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), '+
      '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, '+
      '@n_ShelfLife  INT,          @n_CaseCnt INT '   

   
   EXEC sp_ExecuteSQL @c_SQL
      ,@c_SQLParm
      ,@c_Facility
      ,@c_StorerKey
      ,@c_SKU
      ,@c_Lottable01
      ,@c_Lottable02
      ,@c_Lottable03
      ,@d_Lottable04
      ,@d_Lottable05
      ,@c_Lottable06
      ,@c_Lottable07
      ,@c_Lottable08
      ,@c_Lottable09
      ,@c_Lottable10
      ,@c_Lottable11
      ,@c_Lottable12
      ,@d_Lottable13
      ,@d_Lottable14
      ,@d_Lottable15
      ,@n_ShelfLife
      ,@n_CaseCnt

   SET @c_SQL = ''
   
   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
      IF @c_LOT <> @c_PrevLOT 
      BEGIN
      	 SELECT @n_LotQtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyPreAllocated) -- SHONG01 
      	 FROM LOT (NOLOCK)
      	 WHERE LOT = @c_LOT
      END

      IF @n_LotQtyAvailable < @n_QtyAvailable 
      BEGIN
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
         --(Wan01) - START      	
         --IF ISNULL(@c_SQL,'') = ''
         --BEGIN
         --   SET @c_SQL = N'   
         --         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
         --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
         --         '
         --END
         --ELSE
         --BEGIN
         --   SET @c_SQL = @c_SQL + N'  
         --         UNION ALL
         --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
         --         '
         --END
         SET @c_Lot       = RTRIM(@c_Lot)             
         SET @c_Loc       = RTRIM(@c_Loc)
         SET @c_ID        = RTRIM(@c_ID)

         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue
         --(Wan01) - END

         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake         
         SET @n_LotQtyAvailable = @n_LotQtyAvailable - @n_QtyToTake    
      END

      SET @c_PrevLOT = @c_LOT

      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
   END -- END WHILE FOR CURSOR_AVAILABLE                      
     
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   --(Wan01) - START
   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column
   --IF ISNULL(@c_SQL,'') <> ''
   --BEGIN
   --   EXEC sp_ExecuteSQL @c_SQL
   --END
   --ELSE
   --BEGIN
   --   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   --   SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   --END 
   --(Wan01) - END     
END -- Procedure


GO