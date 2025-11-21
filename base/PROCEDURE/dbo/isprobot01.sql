SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Stored Procedure: ispROBOT01                                         */    
/* Creation Date: 21-JUNE-2018                                          */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-5232 - ECOM ROBOT Allocate/overallocate                 */
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
/* 29/01/2019   NJOW01  1.0   WMS-7506 if B2B No setup pick loc skip    */
/*                            allocation                                */
/************************************************************************/    
CREATE PROC [dbo].[ispROBOT01]        
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
          ,@c_key1         NVARCHAR(10)    
          ,@c_key2         NVARCHAR(5)    
          ,@c_key3         NCHAR(1)
          ,@c_Orderkey     NVARCHAR(10)               
          ,@c_Doctype      NVARCHAR(1)  

   SELECT @b_debug = 0  
         ,@c_LimitString = ''                 
         ,@c_SQL = ''
         ,@c_SQLParm = ''
         ,@n_CaseCnt = 0
         
   SELECT @c_UOMBase = @n_UOMBase    

   IF @c_UOM NOT IN ('6','7')   
   BEGIN  
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL          
     
      RETURN  
   END     
      
   --NJOW01 S
   IF LEN(@c_OtherParms) > 0 
   BEGIN
   	  -- this pickcode can call from wave by discrete / load conso / wave conso
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
      
      SELECT TOP 1 @c_doctype = DocType
      FROM ORDERS O (NOLOCK)
      WHERE O.Orderkey = @c_Orderkey           
   END
   
   IF @c_DocType <> 'E'
   BEGIN  
   	  IF NOT EXISTS(SELECT 1 
   	                FROM SKUXLOC  SL (NOLOCK)
   	                JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc 
   	                WHERE SL.Storerkey = @c_Storerkey 
   	                AND SL.SKU = @c_Sku
   	                AND L.Facility = @c_Facility
   	                AND SL.LocationType = 'PICK')
   	  BEGIN              
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
      
         RETURN
      END
   END    
   --NJOW01 E
    
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
                       
   IF @c_UOM = '6'
   BEGIN
      SELECT @c_SQL =   
               N' DECLARE CURSOR_CANDIDATES SCROLL CURSOR FOR '   
               +' SELECT LOT.Lot, LOC.LOC, LOTxLOCxID.Id, '
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
               +' AND LOC.Facility = @c_Facility '+ @c_LimitString + ' '     
               +' AND (LOC.LocationType = ''DYNPPICK'' ) ' 
               +' AND (LOC.LocationCategory = ''ROBOT'' ) '    
               +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) > 0 '               
               +' ORDER BY LOT.LOT '    	
   END
   ELSE IF @c_UOM = '7'
   BEGIN
      SELECT @c_SQL =   
               N' DECLARE CURSOR_CANDIDATES SCROLL CURSOR FOR '   
               +' SELECT LOT.Lot, LOC.LOC, LOTxLOCxID.Id, '
               +' CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) < ' 
               +' (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) '
               +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) ' + 
               +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) + ISNULL(ROBOTPK.QtyOverAlloc,0) ' + 
               +' END AS QtyAvailable, ' + 
               +' ''1'' '
               +' FROM LOT (NOLOCK) '  
               +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) '   
               +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '   
               +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '  
               +' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) '  
               +' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '
               +' LEFT OUTER JOIN (SELECT LLI2.LOT, LLI2.ID, SUM(LLI2.Qty - LLI2.QtyAllocated - LLI2.QtyPicked) AS QtyOverAlloc '
               +' FROM LOTxLOCxID AS LLI2 WITH(NOLOCK) '
               +' JOIN LOC L2 (NOLOCK) ON L2.Loc = LLI2.Loc '
               +' WHERE LLI2.StorerKey = @c_StorerKey  ' 
               +' AND   LLI2.Sku = @c_SKU '  
               +' AND L2.Facility = @c_Facility '
               +' AND (L2.LocationType=''DYNPPICK'') '
               +' AND (L2.LocationCategory=''ROBOT'') '
               +' GROUP BY LLI2.LOT, LLI2.ID '
               +' HAVING SUM(LLI2.Qty - LLI2.QtyAllocated - LLI2.QtyPicked) < 0 ) ' 
               +' AS ROBOTPK ON ROBOTPK.LOT = LOTxLOCxID.LOT AND ROBOTPK.ID = LOTxLOCxID.ID '
               +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey  '  
               +' AND LOTxLOCxID.SKU = @c_SKU '  
               +' AND LOT.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' 
               +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 ' 
               +' AND LOC.Facility = @c_Facility '+ @c_LimitString + ' '     
               +' AND (LOC.LocationType = ''ROBOTSTG'' ) '
               +' AND (LOC.LocationCategory = ''ROBOT'' ) '    
               +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked - LOTxLOCxID.QtyReplen) + ISNULL(ROBOTPK.QtyOverAlloc,0) > 0 '               
               +' ORDER BY LOT.LOT ' 
   	
   END   
     
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      PRINT @c_SQL
      
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