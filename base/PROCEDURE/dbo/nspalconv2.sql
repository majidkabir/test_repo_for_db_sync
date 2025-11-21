SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALCONV2                                         */
/* Creation Date: 10-OCT-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6435 - CN Converse BTB PTS                              */
/*          UOM2 - order/conso case from case then pallet loc           */
/*          UOM7 - conso loose from DPP if fulfill all qty else from    */
/*                 case then pallet loc                                 */
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
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[nspALCONV2]
   @c_WaveKey    NVARCHAR(10),   
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,  
   @c_Lottable06 NVARCHAR(30) = '',       
   @c_Lottable07 NVARCHAR(30) = '',       
   @c_Lottable08 NVARCHAR(30) = '',       
   @c_Lottable09 NVARCHAR(30) = '',       
   @c_Lottable10 NVARCHAR(30) = '',       
   @c_Lottable11 NVARCHAR(30) = '',       
   @c_Lottable12 NVARCHAR(30) = '',       
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

   DECLARE @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX),
           @c_SortBy      NVARCHAR(2000),
           @n_PickBalance INT
          
   DECLARE @c_LocationType     NVARCHAR(100),    
           @c_LocationCategory NVARCHAR(100)
  
   DECLARE @c_key1        NVARCHAR(10),    
           @c_key2        NVARCHAR(5),    
           @c_key3        NCHAR(1)    
                           
   IF LEN(@c_OtherParms) > 0  
   BEGIN   	    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	          	    
   END
  
   IF @c_UOM = '7' AND ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''  --Discrete allocation not to allocate piece from DPP, only allocate when wave conso allocation
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END
   
   SET @n_PickBalance = 0
   
   IF @c_UOM = '7' 
   BEGIN
      SET @c_LocationType = '''DYNPPICK'''
      SET @c_LocationCategory = '''SHELVING'''
   	
      SET @c_SQL = N'
         SELECT @n_PickBalance = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)
         FROM LOTxLOCxID (NOLOCK)  
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)  
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')  
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
         WHERE LOC.LocationFlag = ''NONE''  
         AND LOC.Status <> ''HOLD''
         AND LOC.Facility = @c_Facility  
         AND LOTxLOCxID.STORERKEY = @c_StorerKey  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +        
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ''   
              ELSE ' AND LOC.LocationType IN(' + @c_LocationType + ')' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''         
              ELSE ' AND LOC.LocationCategory IN(' + @c_LocationCategory + ')' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +                  
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +         
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END + 
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END 
         
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30), @n_PickBalance INT OUTPUT'  
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                         @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_PickBalance OUTPUT                         
   END 
   
   IF @c_UOM = '2'
   BEGIN
      SET @c_LocationType = '''OTHER'''
      SET @c_LocationCategory = '''BULK'''
      SET @c_SortBy = 'ORDER BY CASE WHEN LOC.LocationHandling = ''2'' THEN 1 WHEN LOC.LocationHandling = ''1'' THEN 2 ELSE 3 END, LA.Lottable05, LOTxLOCxID.Lot, LOC.LogicalLocation, LOC.Loc' 
   END
   ELSE -- @c_UOM = '7'
   BEGIN
      SET @c_LocationType = '''OTHER'',''DYNPPICK'''
      SET @c_LocationCategory = '''BULK'',''SHELVING'''

   	  IF ISNULL(@n_PickBalance,0) >= @n_QtyLeftToFulfill
      BEGIN
      	 --can fulfill, allocate from DPP then case & pallet loc 
         --SET @c_LocationType = '''OTHER'',''DYNPPICK'''
         --SET @c_LocationCategory = '''BULK'',''SHELVING'''
         SET @c_SortBy = 'ORDER BY CASE WHEN LOC.LocationType = ''DYNPPICK'' THEN 1 ELSE 2 END, CASE WHEN PACK.Casecnt > 0 THEN CASE WHEN SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.Casecnt AS INT) <> 0 THEN 1 ELSE 2 END ELSE 9 END, CASE WHEN LOC.LocationHandling = ''2'' THEN 1 WHEN LOC.LocationHandling = ''1'' THEN 2 ELSE 3 END, LA.Lottable05, LOTxLOCxID.Lot, LOC.LogicalLocation, LOC.Loc' 
      END
      ELSE
      BEGIN
      	 --DPP cannot fulfill, allocate from case then pallet loc. if still can't find back to DPP
         --SET @c_LocationType = '''OTHER'''
         --SET @c_LocationCategory = '''BULK'''
         SET @c_SortBy = 'ORDER BY CASE WHEN LOC.LocationType = ''DYNPPICK'' THEN 2 ELSE 1 END, CASE WHEN PACK.Casecnt > 0 THEN CASE WHEN SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.Casecnt AS INT) <> 0 THEN 1 ELSE 2 END ELSE 9 END, CASE WHEN LOC.LocationHandling = ''2'' THEN 1 WHEN LOC.LocationHandling = ''1'' THEN 2 ELSE 3 END, LA.Lottable05, LOTxLOCxID.Lot, LOC.LogicalLocation, LOC.Loc'
      END 
   END         
    
   SET @c_SQL = N'      
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,    
             SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), ''1'' 
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)  
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')  
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
      JOIN SKU (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
      WHERE LOC.LocationFlag = ''NONE''  
      AND LOC.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility  
      AND LOTxLOCxID.STORERKEY = @c_StorerKey  
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +        
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ''   
           ELSE ' AND LOC.LocationType IN(' + @c_LocationType + ')' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''         
           ELSE ' AND LOC.LocationCategory IN(' + @c_LocationCategory + ')' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +                  
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +         
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END + 
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.LogicalLocation, LOC.LOC, LOC.LocationHandling, LOC.LocationType, LA.Lottable05, PACK.Casecnt ' +    
      @c_SortBy
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                      '@c_Lottable12 NVARCHAR(30), @n_UOMBase INT '  

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_UOMBase

END -- Procedure

GO