SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispALEC07                                          */
/* Creation Date: 02-JUNE-2014                                          */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 336160 - ECOM Allocate/overallocate                         */
/*          UOM 2 - CASE, 6 - PICK, 7 - BULK & CASE                     */
/*          SkipPreAllocation='1'                                       */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver. Purposes                                   */
/* 11-Nov-2015 Shong01  1.1  Bug Fixing                                 */
/* 13-Feb-2020 Wan01    1.2  Dynamic SQL review, impact SQL cache log   */ 
/************************************************************************/
CREATE PROC [dbo].[ispALEC07]                                            
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
   @c_OtherParms NVARCHAR(200)=''                                       
AS                                                                        
BEGIN
   SET NOCOUNT ON                                                         
   --SET QUOTED_IDENTIFIER OFF                                              
   --SET ANSI_NULLS OFF                                                     
    
   DECLARE @b_debug           INT
         ,@c_SQL             NVARCHAR(MAX)
         ,@n_CaseCnt         INT
         ,@n_ShelfLife       INT
         ,@n_continue        INT
         ,@c_UOMBase         NVARCHAR(10)
         ,@c_LimitString     NVARCHAR(255)
         ,@c_SQLParm         NVARCHAR(MAX)
         ,@n_QtyAvailable    INT = 0
         ,@c_LOT             NVARCHAR(10)
         ,@c_LOC             NVARCHAR(10)
         ,@c_ID              NVARCHAR(18)
         ,@n_Qty             INT = 0                               
    
   SELECT @b_debug = 0
         ,@c_LimitString     = ''
         ,@c_SQL             = ''
         ,@c_SQLParm         = ''
         ,@n_CaseCnt         = 0                                                  
    
   EXEC isp_Init_Allocate_Candidates         --(Wan01) 
        
   SELECT @c_UOMBase = @n_UOMBase  
           
   IF @c_UOM <> '6' 
   BEGIN
   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 0 NULL ,NULL ,NULL ,NULL ,NULL 
      
   RETURN
   END

   IF NOT EXISTS(
      SELECT 1
      FROM CODELKUP WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND LISTNAME  = 'REPLSWAP' 
      AND UDF01 = '1'
      AND Short = @c_Lottable02 )
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TOP 0 NULL ,NULL ,NULL ,NULL ,NULL 
      RETURN
   END
    
   IF NOT EXISTS(
      SELECT 1
      FROM  SKUxLOC AS sl WITH(NOLOCK)
      WHERE sl.StorerKey = @c_StorerKey
      AND sl.Sku = @c_SKU
      AND sl.LocationType = 'PICK' 
      AND sl.Qty > (sl.QtyAllocated + sl.QtyPicked) )
   BEGIN
   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 0 NULL ,NULL ,NULL ,NULL ,NULL 
      
   RETURN
   END
    
   SELECT @n_ShelfLife = CASE 
                              WHEN ISNUMERIC(ISNULL(SKU.Susr2 ,'0'))=1 THEN CONVERT(INT ,ISNULL(SKU.Susr2 ,'0'))
                              ELSE 0
                        END
   FROM  SKU(NOLOCK)
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
    
   SET @c_Lottable01 = ISNULL(RTRIM(@c_Lottable01) ,'')
   SET @c_Lottable02 = ISNULL(RTRIM(@c_Lottable02) ,'')
   SET @c_Lottable03 = ISNULL(RTRIM(@c_Lottable03) ,'')
   SET @c_Lottable06 = ISNULL(RTRIM(@c_Lottable06) ,'')
   SET @c_Lottable07 = ISNULL(RTRIM(@c_Lottable07) ,'')
   SET @c_Lottable08 = ISNULL(RTRIM(@c_Lottable08) ,'')
   SET @c_Lottable09 = ISNULL(RTRIM(@c_Lottable09) ,'')
   SET @c_Lottable10 = ISNULL(RTRIM(@c_Lottable10) ,'')
   SET @c_Lottable11 = ISNULL(RTRIM(@c_Lottable11) ,'')
   SET @c_Lottable12 = ISNULL(RTRIM(@c_Lottable12) ,'')
    
   IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable01= @c_Lottable01 '             
             
   IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable03 = @c_Lottable03 '             
    
   IF CONVERT(NVARCHAR(10) ,@d_Lottable04 ,103)<>'01/01/1900'
      AND @d_Lottable04 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString)+' AND LOTTABLE04 = @d_Lottable04 '                                                                                                                                                                    
    
   IF CONVERT(NVARCHAR(10) ,@d_Lottable05 ,103)<>'01/01/1900'
      AND @d_Lottable05 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString)+' AND LOTTABLE05 = @d_Lottable05 '                                                                                                                                                              
    
   IF ISNULL(RTRIM(@c_Lottable06) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable06= @c_Lottable06 '
    
   IF ISNULL(RTRIM(@c_Lottable07) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable07= @c_Lottable07 '             
    
   IF ISNULL(RTRIM(@c_Lottable08) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable08= @c_Lottable08 '             
    
   IF ISNULL(RTRIM(@c_Lottable09) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable09= @c_Lottable09 '             
    
   IF ISNULL(RTRIM(@c_Lottable10) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable10= @c_Lottable10 '                                                                                           
    
   IF ISNULL(RTRIM(@c_Lottable11) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable11= @c_Lottable11 '             
    
   IF ISNULL(RTRIM(@c_Lottable12) ,'')<>''
      SELECT @c_LimitString = RTRIM(@c_LimitString)+
            ' AND Lottable12 @c_Lottable12 '             
    
   IF CONVERT(NVARCHAR(10) ,@d_Lottable13 ,103)<>'01/01/1900'
      AND @d_Lottable13 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString)+' AND LOTTABLE13 = @d_Lottable13 '                                                                                                                                                                    
    
   IF CONVERT(NVARCHAR(10) ,@d_Lottable14 ,103)<>'01/01/1900'
      AND @d_Lottable14 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString)+' AND LOTTABLE14 = @d_Lottable14 '                                                                                                                                                                    
    
   IF CONVERT(NVARCHAR(10) ,@d_Lottable15 ,103)<>'01/01/1900'
      AND @d_Lottable15 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString)+' AND LOTTABLE15 = @d_Lottable15 '                                                                                                                                                                    
    
   IF @n_ShelfLife>0
      SELECT @c_Limitstring = RTRIM(@c_LimitString)+
            ' AND Lottable04  > DATEADD(DAY, @n_ShelfLife, GETDATE()) ' 

   SELECT @c_SQL = N' SELECT @n_QtyAvailable =  ' 
         +' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) < '            
         +' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) ' 
         +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) '+
         +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) '+
         +' END ' 
         +' FROM LOT (NOLOCK) ' 
         +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' 
         +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' 
         +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' 
         +' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' 
         +' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' 
         +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey  ' 
         +' AND LOTxLOCxID.SKU = @c_SKU ' 
         +' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' ' 
         +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 '                                                                                                                                                       
         +' AND LOC.Facility = @c_Facility ' + @c_LimitString + ' ' 
         +' AND (SKUxLOC.LocationType = ''PICK'') '
         +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) > 0 '
         +' AND EXISTS( SELECT 1 FROM CODELKUP CLK WITH (NOLOCK) '
         +' WHERE CLK.StorerKey = LOTxLOCxID.StorerKey '
         +' AND CLK.Short = LOTATTRIBUTE.Lottable02 '
         +' AND LISTNAME  = ''REPLSWAP'' '
         +' AND UDF01 = ''0'') '           
         +' AND Lottable02 <> @c_Lottable02 '        


   IF ISNULL(@c_SQL ,'')<>''
   BEGIN    	
      SET @c_SQLParm = N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), '+
         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), '+
         '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), '+
         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), '+
         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), '+
         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, '+
         '@n_ShelfLife  INT,          @n_QtyAvailable INT OUTPUT '    
        
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
         ,@n_QtyAvailable OUTPUT
   END
   ELSE 
   BEGIN
      SET @n_QtyAvailable = 0 
   END
    
   IF @n_QtyAvailable = 0 
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
      FOR
         SELECT TOP 0 NULL
               ,NULL
               ,NULL
               ,NULL
               ,NULL
        
      RETURN
   END
    
   IF @n_QtyAvailable > @n_QtyLeftToFulfill
      SET @n_QtyAvailable = @n_QtyLeftToFulfill 
                             
   SELECT @c_SQL = N' DECLARE CURSOR_LOT_LOOKUP SCROLL CURSOR FOR ' 
         +' SELECT LOT.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id, ' 
         +' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) < '            
         +' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) ' 
         +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) '+
         +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) '+
         +' END AS QtyAvailable '+
         +' FROM LOT (NOLOCK) ' 
         +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' 
         +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' 
         +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' 
         +' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' 
         +' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' 
         +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey  ' 
         +' AND LOTxLOCxID.SKU = @c_SKU ' 
         +' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' ' 
         +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 '                                                                                                                                                       
         +' AND LOC.Facility = @c_Facility ' + @c_LimitString + ' ' 
         +' AND (SKUxLOC.LocationType <> ''PICK'') '
         +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) > 0 '
         +' AND Lottable02 = @c_Lottable02 '          
         +' ORDER BY ' 
         +' (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) % CASE WHEN @n_CaseCnt = 0 THEN 1 ELSE @n_CaseCnt END, '
         +' LOC.LocLevel, QtyAvailable, LOC.LogicalLocation, LOC.LOC '
           
    
   IF ISNULL(@c_SQL ,'')<>''
   BEGIN 
            	
      SET @c_SQLParm = N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), '+
         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), '+
         '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), '+
         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), '+
         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), '+
         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, '+
         '@n_ShelfLife  INT,          @n_CaseCnt INT '    

      IF CURSOR_STATUS('GLOBAL' ,'CURSOR_LOT_LOOKUP') IN (0 ,1)
      BEGIN
         CLOSE CURSOR_LOT_LOOKUP 
         DEALLOCATE CURSOR_LOT_LOOKUP
      END
            
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
       
      SET @c_SQL = N''
       
      OPEN CURSOR_LOT_LOOKUP
      FETCH NEXT FROM CURSOR_LOT_LOOKUP INTO @c_LOT, @c_LOC, @c_ID, @n_Qty 
       
      WHILE @@FETCH_STATUS = 0 
      BEGIN
       	IF @n_QtyAvailable > @n_Qty
       	SET @n_Qty = @n_QtyAvailable
       	   
       	--IF LEN(@c_SQL) = 0 
       	--BEGIN
       	-- 	SET @c_SQL = N' DECLARE CURSOR_CANDIDATES SCROLL CURSOR FOR ' +
       	-- 	            ' SELECT ''' + @c_LOT + ''',''' + @c_LOC + ''',''' + @c_ID + ''', ' + CAST(@n_Qty AS VARCHAR(10)) + ',1'
       	--END
       	--ELSE
       	--BEGIN
       	-- 	SET @c_SQL = @c_SQL + N' UNION ALL ' + 
       	-- 	            ' SELECT ''' + @c_LOT + ''',''' + @c_LOC + ''',''' + @c_ID + ''', ' + CAST(@n_Qty AS VARCHAR(10)) + ',1'
       	--END
           
         SET @c_Lot       = RTRIM(@c_Lot)             
         SET @c_Loc       = RTRIM(@c_Loc)
         SET @c_ID        = RTRIM(@c_ID)

         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_Qty
         ,  @c_OtherValue = '1'

       	SET @n_QtyAvailable = @n_QtyAvailable - @n_Qty

       	IF @n_QtyAvailable = 0 
       	   BREAK 
       	 
       	FETCH NEXT FROM CURSOR_LOT_LOOKUP INTO @c_LOT, @c_LOC, @c_ID, @n_Qty
      END

      IF CURSOR_STATUS('GLOBAL' ,'CURSOR_LOT_LOOKUP') IN (0 ,1)
      BEGIN
         CLOSE CURSOR_LOT_LOOKUP 
         DEALLOCATE CURSOR_LOT_LOOKUP
      END
                
      --IF LEN(@c_SQL) > 0 
      --BEGIN
      -- 	EXEC sp_ExecuteSQL @c_SQL
      --END          
      --ELSE 
      --BEGIN
      --   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
      --   FOR SELECT TOP 0 NULL,NULL,NULL,NULL,NULL       	
      --END
      --(Wan01) - END 
   END
   --(Wan01) - START
   --ELSE
   --BEGIN
   --   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
   --   FOR SELECT TOP 0 NULL,NULL,NULL,NULL,NULL
   --END
   EXEC isp_Cursor_Allocate_Candidates   
      @n_SkipPreAllocationFlag = 1    --Return Lot column
   --(Wan01) - END 
END -- Procedure

GO