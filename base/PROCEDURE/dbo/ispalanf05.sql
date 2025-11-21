SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispALANF05                                         */
/* Creation Date: 17-Apr-2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Allocate Fullcase from SellOff Area (selloff) UOM:6         */
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
/* Date         Author        Purposes                                  */
/* 2015-02-12   CSCHONG 1.1   New Lottable06 to 15  (CS11)              */
/* 2021-02-08   WLChooi 1.2   WMS-16327 - Use Codelkup to control       */
/*                            sorting (WL01)                            */
/************************************************************************/
CREATE PROC [dbo].[ispALANF05]
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
          
   DECLARE @c_LocationCategory NVARCHAR(10),
           @c_LoadType         NVARCHAR(10),
           @c_SortingSQL       NVARCHAR(4000)  --WL01

   SET @b_debug = 0
   SET @c_LocationCategory = 'ANFOTHERS'
   SET @c_SortingSQL = 'ORDER BY LOC.LogicalLocation, LOC.LOC '   --WL01
   
   --WL01 START
   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
              WHERE CL.Storerkey = @c_Storerkey  
              AND CL.Code = 'SORTBY'  
              AND CL.Listname = 'PKCODECFG'  
              AND CL.Long = 'ispALANF05'
              AND ISNULL(CL.Short,'') <> 'N')
   BEGIN
      SELECT @c_SortingSQL = LTRIM(RTRIM(ISNULL(CL.Notes,'')))
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Storerkey = @c_Storerkey
      AND CL.Code = 'SORTBY'
      AND CL.Listname = 'PKCODECFG'
      AND CL.Long = 'ispALANF05'
      AND ISNULL(CL.Short,'') <> 'N'
   END
   --WL01 END

   -- GET LoadType FROM LoadPlan
   SELECT TOP 1 
      @c_LoadType = O.Type
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
   WHERE LPD.LoadKey = @c_LoadKey

   IF ISNULL(@c_LoadType, '') = 'selloff'
   BEGIN
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
         JOIN UCC (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID  
                               AND UCC.Status < ''3'')  
         WHERE LOC.LocationFlag <> ''HOLD''  
         AND LOC.LocationFlag <> ''DAMAGE''  
         AND LOC.Status <> ''HOLD''
         AND LOC.Facility = @c_Facility  
         AND LOTxLOCxID.STORERKEY = @c_StorerKey  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +  
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''         
              ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +        
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
          'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOTxLOCxID.QTY, LOTxLOCxID.QTYALLOCATED,  
                   LOTxLOCxID.QTYPICKED, LOTxLOCxID.QtyReplen, LOC.LocationHandling, LOC.LogicalLocation, LOC.LOC ' +   --WL01  
          --ORDER BY LOC.LogicalLocation, LOC.LOC'   --WL01
          @c_SortingSQL                              --WL01
         
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +  
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30) '   
   END -- IF ISNULL(@c_LoadType, '') = 'selloff'

   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03 , 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12  
         /*CS01 End*/
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END

END -- Procedure

GO