SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispALEC04                                          */    
/* Creation Date: 02-JUNE-2014                                          */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 336160 - ECOM Allocate/overallocate                         */
/*          UOM = 7 Where SKUxLOC have no qty available                 */ 
/*          but LOTxLOCxID Have Available Qty                           */
/*          SkipPreAllocation='1'                                       */
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
/* 03-Nov-2017  Shong   1.0   Initial Version                           */
/************************************************************************/    
CREATE PROC [dbo].[ispALEC04]        
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

   IF @c_UOM <> '7' 
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL          
     
      RETURN        
   END
   IF EXISTS(SELECT 1 FROM SKUxLOC AS sl WITH(NOLOCK)
              INNER JOIN LOC WITH(NOLOCK) ON sl.Loc = LOC. Loc
              WHERE  sl.StorerKey = @c_StorerKey
              AND    sl.SKU = @c_SKU   
			  AND    Loc.Facility = @c_Facility
              AND    sl.LocationType = 'PICK'
              AND    sl.Qty > (sl.QtyPicked + sl.QtyAllocated))
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
              ' AND Lottable01= LTrim(RTrim(@c_Lottable01)) '              
     
   IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable02= LTrim(RTrim(@c_Lottable02)) '              
     
   IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable03= LTrim(RTrim(@c_Lottable03)) '
         
   IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE04 = @d_Lottable04 '


   IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE05 = @d_Lottable05 '
     
     
   IF ISNULL(RTRIM(@c_Lottable06) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable06= LTrim(RTrim(@c_Lottable06)) '

   IF ISNULL(RTRIM(@c_Lottable07) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable07= LTrim(RTrim(@c_Lottable07)) '

   IF ISNULL(RTRIM(@c_Lottable08) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable08= LTrim(RTrim(@c_Lottable08)) '

   IF ISNULL(RTRIM(@c_Lottable09) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable09= LTrim(RTrim(@c_Lottable09)) '
              
   IF ISNULL(RTRIM(@c_Lottable10) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable10= LTrim(RTrim(@c_Lottable10)) '
              
   IF ISNULL(RTRIM(@c_Lottable11) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable11= LTrim(RTrim(@c_Lottable11)) '
             
   IF ISNULL(RTRIM(@c_Lottable12) ,'')<>''  
       SELECT @c_LimitString = RTrim(@c_LimitString)+  
              ' AND Lottable12= LTrim(RTrim(@c_Lottable12)) '

   IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE13 = @d_Lottable13 '

   IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE14 = @d_Lottable14 '

   IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE15 = @d_Lottable15 '

   IF @n_ShelfLife > 0  
       SELECT @c_Limitstring = RTrim(@c_LimitString)+  
              ' AND Lottable04  > DATEADD(DAY, @n_ShelfLife, GETDATE()) '           
      
   SELECT @c_SQL =   
            N' DECLARE CURSOR_CANDIDATES SCROLL CURSOR FOR '   
            +' SELECT LOT.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id, '
            +' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) < ' 
            +' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) '
            +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) ' + 
            +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) ' + 
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
            +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 '   
            +' AND LOC.Facility = @c_Facility ' + @c_LimitString + ' '     
            +' AND (SKUxLOC.LocationType = ''PICK'') '    
            +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) > 0 '   
            +' ORDER BY LOC.LocLevel, QtyAvailable, LOC.LogicalLocation, LOC.LOC '
     
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