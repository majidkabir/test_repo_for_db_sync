SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: nspAL_CH04                                         */    
/* Creation Date: 06-APR-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-16759 - CN JinLin Allocate Case by ID from BULK         */
/*          SkipPreAllocation='1'                                       */
/*                                                                      */
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/************************************************************************/    
CREATE PROC [dbo].[nspAL_CH04]        
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
          ,@n_ShelfLife    INT     
          ,@n_continue     INT    
          ,@c_UOMBase      NVARCHAR(10)    
          ,@c_LimitString  NVARCHAR(255)  
          ,@c_SQLParm      NVARCHAR(MAX)  
     
   SELECT @b_debug = 0  
         ,@c_LimitString = ''                 
         ,@c_SQL = ''
         ,@c_SQLParm = ''
         
   SELECT @c_UOMBase = @n_UOMBase    

   IF @c_UOM <> '2'    
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
              ' AND Lottable04  > DATEADD(DAY ,@n_ShelfLife ,GETDATE()) '           
      
   SELECT @c_SQL =   
             '  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR '   
            +' SELECT LOT.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id, '
            +' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) AS QtyAvailable, '
            --+' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) < ' 
            --+' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) '
            --+' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) ' + 
      --+' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) ' +  
      --      +' END AS QtyAvailable, ' + 
            +' ''UOM=''+ RTRIM(LTRIM(CAST(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen AS NVARCHAR))) '
            +' FROM LOT (NOLOCK) '  
            +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) '   
            +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '   
            +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '+  
             ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) '+  
             ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '   
            +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey  '+  
             ' AND LOTxLOCxID.SKU = @c_SKU '+  
             ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' '   
            +' AND LOC.Facility = @c_Facility '+@c_LimitString+' '     
            +' AND (SKUxLOC.LocationType NOT IN (''CASE'',''PICK'')) '   
            --+' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 '                      
            +' AND (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyReplen) = 0 '
            +' AND ISNULL(LOTxLOCxID.ID,'''') <> '''' '
            --+' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) >= @n_UOMBase '
            +' AND LOTxLOCxID.Qty > 0 '
            +' ORDER BY CASE WHEN @n_QtyLeftToFulfill = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) THEN 1 ELSE 2 END, '
            + 'CASE WHEN @n_QtyLeftToFulfill % (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) = 0 THEN 1 ELSE 2 END, ' 
            +' LOC.LocLevel, QtyAvailable, LOC.LogicalLocation, LOC.LOC '
     
   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                         '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), ' +
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
                         '@n_ShelfLife  INT,          @n_UOMBase INT, 						@n_QtyLeftToFulfill INT '     
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                         @n_ShelfLife,  @n_UOMBase, @n_QtyLeftToFulfill                         
   END
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END      
END -- Procedure

GO