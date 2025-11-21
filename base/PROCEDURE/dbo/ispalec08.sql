SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/                                                                                                                                                                                     
/* Stored Procedure: ispALEC08                                          */                                                                                                                                                                                     
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
/* PVCS Version: 1.5                                                    */                                                                                                                                                                                       
/*                                                                      */                                                                                                                                                                                       
/* Version: 1.0                                                         */                                                                                                                                                                                       
/*                                                                      */                                                                                                                   
/* Data Modifications:                                                  */                                                                                                                                                                                       
/*                                                                      */                                                                                                                                                                                       
/* Updates:                                                             */                                                                                                                                                                                       
/* Date         Author  Ver.  Purposes                                  */                                                                                                                                                                                       
/* 11-Nov-2015  Shong01 1.1   Bug Fixing                                */                                                                                                                                                                                       
/* 10-Oct-2016  Shong02 1.2   Fixing Overallocation Issues              */                                                                                                                                                                                       
/* 15-Oct-2016  Shong   1.3   Change Sorting Order                      */                                                                                                                                                                                       
/* 24-Jul-2017  TLTING  1.4   Dynamic SQL review, impact SQL cache log  */                                                                                                                                                                                       
/* 12-NOV-2017  WAN01   1.5   Order by Full case lot for UOM = '7'      */                
/* 18-Nov-2022  NJOW01  1.6   WMS-21206 Force lottable06 filter to include*/
/*                            empty lottable by config                  */                
/* 18-Nov-2022  NJOW01  1.6   DEVOPS Combine Script                     */                                                                                                                                                           
/************************************************************************/                                                                                                                                                                                     
CREATE    PROC [dbo].[ispALEC08]                                                                                                                                                                                                                                 
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
   SET QUOTED_IDENTIFIER OFF                                                                                                                                                                                                                                     
   SET ANSI_NULLS OFF                                                                                                                                                                                                                                          
                                                                                                                                                                                                                                                               
   DECLARE @b_debug        INT                                                                                                                                                                                                                                   
          ,@c_SQL          NVARCHAR(MAX)                                                                                                                                                                                                                        
          ,@n_CaseCnt      INT                                                                                                                                                                                                                                   
          ,@n_ShelfLife    INT                                                                                                                                                                                                                                 
          ,@n_continue     INT                                                                                                                                                                                                                                   
          ,@c_UOMBase      NVARCHAR(10)                                                                                                                                                                                                  
          ,@c_LimitString  NVARCHAR(255)                                                                                                                                                                                                                      
          ,@c_SQLParm      NVARCHAR(MAX)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
  
   SELECT @b_debug = 0                                                                                                                                                                                                                                         
         ,@c_LimitString = ''                                                                                                                                                                                                                                  
         ,@c_SQL = ''                                                                                                                                                                                                                                          
         ,@c_SQLParm = ''                                                                                                                                                                                                                                      
         ,@n_CaseCnt = 0                                                                                                                                                                                                                                       
                                                                                                                                                                                                                                                               
   SELECT @c_UOMBase = @n_UOMBase                                                                                                                                                                                                                              
                                                                                                                                                                                                                                                               
   IF @c_UOM = '2'                                                                                                                                                                                                                                             
   BEGIN                                                                                                                                                                                                                                                       
      SELECT @n_CaseCnt  = p.CaseCnt                                                                                                                                                                                                                           
      FROM PACK p WITH (NOLOCK)                                                 
      JOIN SKU s WITH (NOLOCK) ON s.PackKey = p.PackKey                                                                                                                                                                                                       
      WHERE s.StorerKey = @c_StorerKey AND                                                                                                                                                                                                                     
            s.Sku = @c_SKU                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
  
      IF @n_QtyLeftToFulfill < @n_CaseCnt                                                                                                                                                                                                                      
      BEGIN                                                                                                                                                                                                                                                    
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR                                                                                                                                                                                           
         SELECT TOP 0 NULL, NULL, NULL, NULL, NULL                                                                                                                                                                                                             
         RETURN                                                                                                                                                                                                                                                       
      END                                                                                                                                                                                                                                                      
   END                                                                                                                                                                                                                                                         
  
   IF @c_UOM = '6'                                                                                                                                                                                                                                             
   AND NOT EXISTS(SELECT 1 FROM SKUxLOC AS sl WITH(NOLOCK)                                                                                                                                                                                                       
                    WHERE  sl.StorerKey = @c_StorerKey                                                                                                                                                                                                           
                    AND    sl.Sku = @c_SKU                                                                                                                                                                 
                    AND    sl.LocationType = 'PICK')                                                                                                                                                                                                                        
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

   IF ISNULL(RTRIM(@c_Lottable01), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable01= LTrim(RTrim(@c_Lottable01)) '
   
   IF ISNULL(RTRIM(@c_Lottable02), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable02= LTrim(RTrim(@c_Lottable02)) '                                                                                                                                                                                         
                                                                                                           
   IF ISNULL(RTRIM(@c_Lottable03), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable03= LTrim(RTrim(@c_Lottable03)) '

   IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND LOTTABLE04 = @d_Lottable04 '

   IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND LOTTABLE05 = @d_Lottable05 '

   IF ISNULL(RTRIM(@c_Lottable06), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable06= LTrim(RTrim(@c_Lottable06)) '
   ELSE IF EXISTS(SELECT 1 FROM   
                  CODELKUP (NOLOCK)
                  WHERE ListName = 'PKCODECFG'
                  AND Storerkey = @c_Storerkey
                  AND Code = 'ForceLot06Filter'
                  AND Code2 = 'ispALEC08'
                  AND Short <> 'N') --NJOW01          
   BEGIN
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable06= '''' '
   END                 
      
   IF ISNULL(RTRIM(@c_Lottable07), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable07= LTrim(RTrim(@c_Lottable07)) '

   IF ISNULL(RTRIM(@c_Lottable08), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable08= LTrim(RTrim(@c_Lottable08)) '

   IF ISNULL(RTRIM(@c_Lottable09), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable09= LTrim(RTrim(@c_Lottable09)) '

   IF ISNULL(RTRIM(@c_Lottable10), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable10= LTrim(RTrim(@c_Lottable10)) '

   IF ISNULL(RTRIM(@c_Lottable11), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable11= LTrim(RTrim(@c_Lottable11)) '

   IF ISNULL(RTRIM(@c_Lottable12), '') <> ''
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND Lottable12= LTrim(RTrim(@c_Lottable12)) '

   IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND LOTTABLE13 = @d_Lottable13 '

   IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND LOTTABLE14 = @d_Lottable14 '

   IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL
      SELECT @c_LimitString = RTRIM(@c_LimitString) + N' AND LOTTABLE15 = @d_Lottable15 '

   IF @n_ShelfLife > 0
      SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable04  > DATEADD(DAY, @n_ShelfLife, GETDATE()) '

   SELECT @c_SQL =                                                                                                                                                                                                                                             
            N' DECLARE CURSOR_CANDIDATES SCROLL CURSOR FOR '                                                                                                                                                                                                     
            +' SELECT LOT.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id, '                                                                                                                                                                                                 
            +' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated + LOTxLOCxID.PendingMoveIN) < '                                                                                                                                     
            +' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) '                                                                                                                           
            +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated + LOTxLOCxID.PendingMoveIN) ' +                                                                                                                                          
            +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) ' +                                                                                                                    
            +' END AS QtyAvailable, ' +                                                                                                                                                                                                                        
            +' ''1'' '                                                                                                                                                                          
            +' FROM LOT (NOLOCK) '                                                                                                                                                                                                                            
            +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) '                                                                                                                                                                                    
            +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '                                                                                                                                                  
            +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '                                                                                                                                                                                               
            +' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) '                                                                                                                                                                                                   
            +' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '                                                                                                         
            +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey  '                                                                                                                                                                                                    
            +' AND LOTxLOCxID.SKU = @c_SKU '                                                                                                                                                                                                                   
            +' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' '                                                                                                                                        
            +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 '  -- SHONG01                                                                                                                                                        
            +' AND LOC.Facility = @c_Facility '+@c_LimitString+' '                                                                                                                                                                                             
            + CASE WHEN @c_UOM = '2' THEN  ' AND (SKUxLOC.LocationType = ''CASE'') ' ELSE '' END                                                                                                                                                               
            + CASE WHEN @c_UOM = '6' THEN  ' AND (SKUxLOC.LocationType = ''PICK'') ' ELSE '' END                                                                                                                                                               
            + CASE WHEN @c_UOM = '7' THEN  ' AND (SKUxLOC.LocationType <> ''PICK'') ' ELSE '' END                                                                                                                                                              
            + CASE WHEN @c_UOM IN ('6','7') THEN  ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' ELSE '' END                                                    
            + CASE WHEN @c_UOM = '2' THEN  ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) >= @n_CaseCnt '                                                                                                     
              ELSE '' END                                                                                                                                                                                                                                      
            --+' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05, 4, LOC.LogicalLocation, LOC.LOC '                                                                                                                         
            +' ORDER BY '                                                                                                                                                                                                                                      
            + CASE WHEN @c_UOM = '7' THEN  ' (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) % CASE WHEN @n_CaseCnt = 0 THEN 1 ELSE @n_CaseCnt END , ' ELSE '' END  -- (WAN01)                           
            +        ' LOC.LocLevel, QtyAvailable, LOC.LogicalLocation, LOC.LOC '                                                                                                                                                                              
  
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)                                                                                                                                                                                                  
   BEGIN                                                                                                                                                                                                                                                       
      CLOSE CURSOR_AVAILABLE                                                                                                                                                                                                                                   
      DEALLOCATE CURSOR_AVAILABLE                                                                                                                                                                                                                              
   END                                                                                                                                                                                                                                                         
  
   IF ISNULL(@c_SQL,'') <> ''                                                                                                                                                                                                                                  
   BEGIN                                                                                                                                                                                                                                                       
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +                                                                                                                                              
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +                                                                                                                                              
                         '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), ' +                                                                                                                                              
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' +                                                                                                                                              
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' +                                                                                                                                              
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +                                                                                                                                                  
                         '@n_ShelfLife  INT,          @n_CaseCnt INT '                                                                                                                                                                                                                                                                                                                                                                                                                                                        
  
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,                                                                                                                                   
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09,                                                                                                                                              
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,                                                                                                                                             
                         @n_ShelfLife,  @n_CaseCnt                                                                                                                                                                                                                                                                                                                                                                                                                                                              
  
   END                                                                                                                                                                                                                                                         
   ELSE                                              
   BEGIN                                                                                                                                                                                                                                                         
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR                                                                                                                                                                                             
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL                                                                                                                                                                                                                
   END                                                                                                                                                                                                                                                         
END -- Procedure    

GO