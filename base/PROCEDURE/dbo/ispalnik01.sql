SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispALNIK01                                         */
/* Creation Date: 28-Feb-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1106 - CN-Nike SDC WMS Allocation Strategy              */
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
/* Date        Author  Ver   Purposes                                   */
/* 30-Jun-2017 Wan01   1.1   WMS-2295 - CN-Nike SDC WMS Allocation      */
/*                           Strategy CR                                */
/************************************************************************/
CREATE PROC [dbo].[ispALNIK01]
   @c_WaveKey    NVARCHAR(10)   
,  @c_Facility   NVARCHAR(5)      
,  @c_StorerKey  NVARCHAR(15)     
,  @c_SKU        NVARCHAR(20)    
,  @c_Lottable01 NVARCHAR(18)    
,  @c_Lottable02 NVARCHAR(18)    
,  @c_Lottable03 NVARCHAR(18)    
,  @d_Lottable04 NVARCHAR(20)    
,  @d_Lottable05 NVARCHAR(20) 
,  @c_Lottable06 NVARCHAR(30) = ''       
,  @c_Lottable07 NVARCHAR(30) = ''       
,  @c_Lottable08 NVARCHAR(30) = ''       
,  @c_Lottable09 NVARCHAR(30) = ''       
,  @c_Lottable10 NVARCHAR(30) = ''       
,  @c_Lottable11 NVARCHAR(30) = ''       
,  @c_Lottable12 NVARCHAR(30) = ''       
,  @d_Lottable13 NVARCHAR(20) = NULL     
,  @d_Lottable14 NVARCHAR(20) = NULL     
,  @d_Lottable15 NVARCHAR(20) = NULL     
,  @c_UOM        NVARCHAR(10)    
,  @c_HostWHCode NVARCHAR(10)    
,  @n_UOMBase    INT    
,  @n_QtyLeftToFulfill INT     
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @b_debug           INT     
        ,  @c_SQL             NVARCHAR(MAX)     
        ,  @c_SQLParm         NVARCHAR(MAX)    
          
   DECLARE @c_WaveType         NVARCHAR(10) 
        ,  @c_LocationType     NVARCHAR(10)     
        ,  @c_LocationCategory NVARCHAR(10) 
        ,  @n_QtyAvailable     INT

   SET @c_LocationType = 'DYNPPICK'    
   SET @c_LocationCategory = 'SHELVING'  
   SET @n_QtyAvailable = 0

   SELECT @c_WaveType = DispatchPiecePickMethod
   FROM WAVE (NOLOCK)
   WHERE Wavekey = @c_Wavekey
   
   IF ISNULL(@c_WaveType,'') IN ( 'INLINE', 'DTC')       --(Wan01)
   BEGIN
   SET @c_SQL = N'DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR '
              +  'SELECT LOTxLOCxID.Lot '
              +  ',LOTxLOCxID.Loc '
              +  ',LOTxLOCxID.ID '
              +  ',QtyAvailable = (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) '
              +  ',''1'' '
              +  'FROM LOTxLOCxID WITH (NOLOCK) '     
              +  'JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC AND LOC.Status <> ''HOLD'') '     
              +  'JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'') '      
              +  'JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'') '         
              +  'JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LOT.LOT = LA.LOT) '           
              +  'WHERE LOC.LocationFlag <> ''HOLD'' '      
              +  'AND LOC.LocationFlag <> ''DAMAGE'' '      
              +  'AND LOC.Facility = @c_Facility '   
              +  'AND LOTxLOCxID.Storerkey = @c_StorerKey '
              +  'AND LOTxLOCxID.Sku = @c_SKU ' 
              +  'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) > 0 '    
              + CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ' ' 
                     ELSE 'AND LOC.LocationType = ''' + @c_LocationType + ''' ' END      
              + CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ' '       
                     ELSE 'AND LOC.LocationCategory = ''' + @c_LocationCategory + ''' '  END       
              + CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END       
              + CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END       
              + CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END  
              + CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END  
              + 'ORDER BY LOC.LogicalLocation, LOC.Loc'                             

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20) '      
                     +  ',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '  
                     +  ',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30) ' 
                     +  ',@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30) '  
                     +  ',@c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03 
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08
                        ,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12  
  
   END
   ELSE
   BEGIN   
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,
             QTYAVAILABLE=0,
             '1'
      FROM LOTxLOCxID (NOLOCK) WHERE 1=2    
   END 
END -- Procedure

GO