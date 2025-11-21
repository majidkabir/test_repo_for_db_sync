SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispALADSDPBulk                                          */
/* Creation Date: 2021-07-08                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17271 - RG - Adidas Allocation Strategy                 */
/*        : Loose Quantity from DPBULK                                  */
/* Called By: ispPRALC06                                                */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-08  Wan      1.0   Created.                                  */
/* 2021-10-08  Wan      1.0   DevOps Combine Script                     */
/* 2022-02-09  Wan01    1.1   CR 1.5. Exclude Lot & ID Hold Inventory   */
/************************************************************************/
CREATE PROC [dbo].[ispALADSDPBulk]
      @c_Wavekey           NVARCHAR(10)  
   ,  @c_Facility          NVARCHAR(5)     
   ,  @c_StorerKey         NVARCHAR(15)     
   ,  @c_SKU               NVARCHAR(20)    
   ,  @c_Lottable01        NVARCHAR(18)    
   ,  @c_Lottable02        NVARCHAR(18)    
   ,  @c_Lottable03        NVARCHAR(18)    
   ,  @dt_Lottable04       DATETIME
   ,  @dt_Lottable05       DATETIME    
   ,  @c_Lottable06        NVARCHAR(30)    
   ,  @c_Lottable07        NVARCHAR(30)    
   ,  @c_Lottable08        NVARCHAR(30)    
   ,  @c_Lottable09        NVARCHAR(30)    
   ,  @c_Lottable10        NVARCHAR(30)    
   ,  @c_Lottable11        NVARCHAR(30)    
   ,  @c_Lottable12        NVARCHAR(30)    
   ,  @dt_Lottable13       DATETIME    
   ,  @dt_Lottable14       DATETIME    
   ,  @dt_Lottable15       DATETIME    
   ,  @c_UOM               NVARCHAR(10)   = '' 
   ,  @c_HostWHCode        NVARCHAR(10)   = '' 
   ,  @n_UOMBase           INT            = 1
   ,  @n_QtyLeftToFulfill  INT            = 0
   ,  @c_OtherParms        NVARCHAR(250)  = ''
   ,  @b_debug             INT = 0
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF

   DECLARE @c_SQL                NVARCHAR(MAX)  = ''
         , @c_SQLParms           NVARCHAR(MAX)  = ''
         , @c_AllocateType       NVARCHAR(1)    = ''
         , @c_fOrderkey          NVARCHAR(10)   = ''

         , @c_LocationType       NVARCHAR(10)   = 'DPBULK'
         , @c_LocationCategory   NVARCHAR(10)   = 'SHELVING'
         , @c_LocationHandling   NVARCHAR(10)   = '3' 
         , @c_OtherValue         NVARCHAR(20)   = '1'   
   
   -- UOM = 2, 1 UCC 1 Order, UOM = 6, 1 UCC Multiple Orders
   SET @c_AllocateType = SUBSTRING(@c_OtherParms,16,1)
   SET @c_fOrderkey    = SUBSTRING(@c_OtherParms,17,10)
   
   IF @b_debug IN (1,2,3)
   BEGIN
      PRINT '@c_AllocateType:' + @c_AllocateType + ', @c_UOM: ' + @c_UOM + ', @c_OtherParms: ' + @c_OtherParms
   END
   
   IF @c_AllocateType NOT IN ('W', 'L') 
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_UOM NOT IN ('7') 
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_SQL = N'SELECT lli.Lot, lli.Loc, lli.ID, QtyAvailable = lli.Qty - lli.QtyAllocated - lli.QtyPicked, ''1'''
              + ' FROM dbo.LOTxLOCxID AS lli WITH (NOLOCK)' 
              + ' JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = lli.Loc AND l.[Status] NOT IN (''HOLD'')'               --(Wan01)
              + ' JOIN dbo.LOTATTRIBUTE AS l2 WITH (NOLOCK) ON l2.Lot = lli.Lot'
              + ' JOIN dbo.LOT AS l3 WITH (NOLOCK) ON l3.Lot = lli.Lot AND l3.[Status] NOT IN (''HOLD'')'            --(Wan01)
              + ' JOIN dbo.ID AS i WITH (NOLOCK) ON i.ID = lli.ID AND i.[Status] NOT IN (''HOLD'')'                  --(Wan01)
              + ' WHERE lli.StorerKey = @c_StorerKey'
              + ' AND lli.Sku = @c_SKU'
              + ' AND l.Facility = @c_Facility'
              + ' AND l.LocationType = @c_LocationType'
              + ' AND l.LocationCategory = @c_LocationCategory'
              + ' AND l.LocationHandling = @c_LocationHandling'              
              + ' AND l.LocationFlag NOT IN (''HOLD'', ''DAMAGE'')'
              + ' AND lli.Qty - lli.QtyAllocated - lli.QtyPicked > 0'
              + CASE WHEN @c_Lottable01 = '' THEN '' ELSE N' AND l2.Lottable01 = @c_Lottable01' END
              + CASE WHEN @c_Lottable02 = '' THEN '' ELSE N' AND l2.Lottable02 = @c_Lottable02' END  
              + CASE WHEN @c_Lottable03 = '' THEN '' ELSE N' AND l2.Lottable03 = @c_Lottable03' END
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable04, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable04 = @dt_Lottable04' END              
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable05, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable05 = @dt_Lottable05' END
              + CASE WHEN @c_Lottable06 = '' THEN '' ELSE N' AND l2.Lottable06 = @c_Lottable06' END              
              + CASE WHEN @c_Lottable07 = '' THEN '' ELSE N' AND l2.Lottable07 = @c_Lottable07' END    
              + CASE WHEN @c_Lottable08 = '' THEN '' ELSE N' AND l2.Lottable08 = @c_Lottable08' END              
              + CASE WHEN @c_Lottable09 = '' THEN '' ELSE N' AND l2.Lottable09 = @c_Lottable09' END  
              + CASE WHEN @c_Lottable10 = '' THEN '' ELSE N' AND l2.Lottable10 = @c_Lottable10' END     
              + CASE WHEN @c_Lottable11 = '' THEN '' ELSE N' AND l2.Lottable11 = @c_Lottable11' END
              + CASE WHEN @c_Lottable12 = '' THEN '' ELSE N' AND l2.Lottable12 = @c_Lottable12' END  
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable13, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable13 = @dt_Lottable13' END
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable14, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable14 = @dt_Lottable14' END              
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable15, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable15 = @dt_Lottable15' END
              + ' ORDER BY l.LogicalLocation'  
              +         ', l.Loc'  
              +         ', l2.Lottable05'  
      
   SET @c_SQLParms = N'@c_Storerkey          NVARCHAR(15)'
                   + ',@c_Sku                NVARCHAR(20)'
                   + ',@c_facility           NVARCHAR(5)' 
                   + ',@c_LocationType       NVARCHAR(10)'
                   + ',@c_LocationCategory   NVARCHAR(10)'  
                   + ',@c_LocationHandling   NVARCHAR(10)'                                     
                   + ',@n_QtyLeftToFulfill   INT'                 
                   + ',@c_Lottable01         NVARCHAR(18)'    
                   + ',@c_Lottable02         NVARCHAR(18)'    
                   + ',@c_Lottable03         NVARCHAR(18)'    
                   + ',@dt_Lottable04        DATETIME'
                   + ',@dt_Lottable05        DATETIME'
                   + ',@c_Lottable06         NVARCHAR(30)'    
                   + ',@c_Lottable07         NVARCHAR(30)'    
                   + ',@c_Lottable08         NVARCHAR(30)'    
                   + ',@c_Lottable09         NVARCHAR(30)'    
                   + ',@c_Lottable10         NVARCHAR(30)'    
                   + ',@c_Lottable11         NVARCHAR(30)'    
                   + ',@c_Lottable12         NVARCHAR(30)'    
                   + ',@dt_Lottable13        DATETIME'
                   + ',@dt_Lottable14        DATETIME'
                   + ',@dt_Lottable15        DATETIME'

   IF @b_debug > 0
   BEGIN
      PRINT @c_SQL  
   END
      
   INSERT INTO #ALLOCATE_CANDIDATES (Lot, Loc, Id, QtyAvailable, OtherValue)
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_Storerkey          
                     , @c_Sku                
                     , @c_facility           
                     , @c_LocationType       
                     , @c_LocationCategory   
                     , @c_LocationHandling   
                     , @n_QtyLeftToFulfill   
                     , @c_Lottable01         
                     , @c_Lottable02         
                     , @c_Lottable03         
                     , @dt_Lottable04       
                     , @dt_Lottable05       
                     , @c_Lottable06         
                     , @c_Lottable07         
                     , @c_Lottable08         
                     , @c_Lottable09         
                     , @c_Lottable10         
                     , @c_Lottable11         
                     , @c_Lottable12         
                     , @dt_Lottable13       
                     , @dt_Lottable14       
                     , @dt_Lottable15 
   QUIT_SP:

   EXEC isp_Cursor_Allocate_Candidates
      @n_SkipPreAllocationFlag = 1   --1: Return Lot Column, 0:Do not return Lot Column  
END -- procedure

GO