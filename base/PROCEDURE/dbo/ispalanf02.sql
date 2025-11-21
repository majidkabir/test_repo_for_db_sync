SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispALANF02                                         */
/* Creation Date: 07-Feb-2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Allocate Loose from DPP (ALL) UOM:7                         */
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
/* Date         Author  Ver   Purposes                                  */
/* 07-Nov-2014  YTWan   1.1   SOS#324691 - CR on Allocation Strategy for*/
/*                            ANF (Wan01)                               */
/* 2015-02-12   CSCHONG 1.2   New Lottable06 to 15  (CS11)              */
/* 08-Apr-2020  WLChooi 1.3   WMS-12808 - Use Codelkup to control       */
/*                            sorting (WL01)                            */
/************************************************************************/
CREATE PROC [dbo].[ispALANF02]
   @c_LoadKey    NVARCHAR(10),   
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 NVARCHAR(20),    
   @d_Lottable05 NVARCHAR(20), 
   @c_Lottable06 NVARCHAR(30) = '',       --(CS01) 
   @c_Lottable07 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable08 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable09 NVARCHAR(30) = '',       --(CS01) 
   @c_Lottable10 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable11 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable12 NVARCHAR(30) = '',       --(CS01)
   @d_Lottable13 NVARCHAR(20) = NULL,     --(CS01)
   @d_Lottable14 NVARCHAR(20) = NULL,     --(CS01)
   @d_Lottable15 NVARCHAR(20) = NULL,     --(CS01)   
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT     
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @b_debug       INT,      
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @c_LocationType      NVARCHAR(10),    
           @c_LocationCategory  NVARCHAR(10),
           @c_LOT               NVARCHAR(10),
           @c_LOC               NVARCHAR(10),
           @c_ID                NVARCHAR(18) 
         , @c_LocationCategory2 NVARCHAR(10)    --(Wan01) 
         , @c_SortingSQL        NVARCHAR(4000)  --WL01

   SET @c_LocationType = 'DYNPPICK'    
   SET @c_LocationCategory = 'MEZZANINE'  
   SET @c_LocationCategory2= 'MEZZALLOC'    
   SET @c_SortingSQL = 'ORDER BY LOC.LogicalLocation, LOC.LOC '   --WL01

   --WL01 START
   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
              WHERE CL.Storerkey = @c_Storerkey  
              AND CL.Code = 'SORTBY'  
              AND CL.Listname = 'PKCODECFG'  
              AND CL.Long = 'ispALANF02'
              AND ISNULL(CL.Short,'') <> 'N')
   BEGIN
      SELECT @c_SortingSQL = LTRIM(RTRIM(ISNULL(CL.Notes,'')))
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Storerkey = @c_Storerkey
      AND CL.Code = 'SORTBY'
      AND CL.Listname = 'PKCODECFG'
      AND CL.Long = 'ispALANF02'
      AND ISNULL(CL.Short,'') <> 'N'
   END
   --WL01 END

   SET @c_SQL = N'    
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,    
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), ''1''     
      FROM LOTxLOCxID (NOLOCK)     
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)    
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')     
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')       
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT          
      WHERE LOC.LocationFlag <> ''HOLD''     
      AND LOC.LocationFlag <> ''DAMAGE''     
      AND LOC.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0    
      AND LOTxLOCxID.STORERKEY = @c_StorerKey 
      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +      
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
           ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' AND ISNULL(RTRIM(@c_LocationCategory2),'') = '' THEN ''               --(Wan01)   
           WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ' AND LOC.LocationCategory2 = ''' + @c_LocationCategory2 + ''''  --(Wan01) 
           WHEN ISNULL(RTRIM(@c_LocationCategory2),'')= '' THEN ' AND LOC.LocationCategory = '''  + @c_LocationCategory + '''' + CHAR(13) END + --(Wan01)     
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +   
      /*CS01 start*/
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +         
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +                        
      --'ORDER BY LOC.LogicalLocation, LOC.LOC' --WL01
      @c_SortingSQL                             --WL01
    
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                      '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                      '@c_Lottable12 NVARCHAR(30) '     
   
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
    /*CS01 End*/
END -- Procedure

GO